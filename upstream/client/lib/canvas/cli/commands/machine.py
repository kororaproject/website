#
# Copyright (C) 2013-2015   Ian Firns   <firnsy@kororaproject.org>
#                           Chris Smart <csmart@kororaproject.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

import dnf
import json
import logging
import prettytable
import yaml

from canvas.cli.commands import Command
from canvas.package import Package, Repository
from canvas.service import Service, ServiceException
from canvas.template import Machine, Template

logger = logging.getLogger('canvas')

class MachineCommand(Command):
  def configure(self, config, args, args_extra):
    # store loaded config
    self.config = config

    # create our canvas service object
    self.cs = Service(host=args.host, username=args.username)

    # store args for additional processing
    self.args = args

    # return false if any error, help, or usage needs to be shown
    return not args.help

  def help(self):
    # check for action specific help first
    if self.args.action is not None:
      try:
        command = getattr(self, 'help_{0}'.format(self.args.action))

        # show action specific if available
        if command:
          return command()

      except:
        pass

    # fall back to general usage
    print("General usage: {0} [--version] [--help] [--verbose] machine [<args>]\n"
          "{0} machine add [user:]name [--description=] [--location=] [--name=] [--template=]\n"
          "{0} machine update [user:]name [--description=] [--location=] [--name=] [--template=]\n"
          "{0} machine list [user] [--filter-name] [--filter-description]\n"
          "{0} machine rm [user:]name\n"
          "{0} machine diff [user:]name [--output=path]\n"
          "{0} machine connect [user:]name\n"
          "{0} machine cmd [user:]name command arg1 arg2 ... argN\n"
          "{0} machine sync [user:]name [--pull [[user:]template]] | --push [user:]template]\n"
          "{0} machine disconnect [user:]name\n"
          "\n".format(self.prog_name))

  def help_add(self):
    print("Usage: {0} machine add [user:]machine [user:]template [--title] [--description]\n"
          "\n".format(self.prog_name))

  def run(self):
    command = None

    # search for our function based on the specified action
    try:
      command = getattr(self, 'run_{0}'.format(self.args.action))

    except:
      print('command: not implemented')
      return 1

    if not command:
      print('error: action is not reachable.')
      return

    return command()

  def run_add(self):
    m = Machine(self.args.machine, user=self.args.username)
    t = Template(self.args.template, user=self.args.username)

    # grab the template we're associating to the machine
    try:
      t = self.cs.template_get(t, auth=True)

    except ServiceException as e:
      print(e)
      return 1

    # add template uuid to machine
    m.template = t.uuid

    # add machine bits that are specified
    if self.args.description is not None:
      m.description = self.args.description

    try:
      res = self.cs.machine_create(m)

    except ServiceException as e:
      print(e)
      return 1

    print(res)

    # update config with our newly added (registered) machine
    self.config.set('machine', 'uuid', res['uuid'])
    self.config.set('machine', 'key', res['key'])
    self.config.save()

    print('info: machine added.')
    return 0

  def run_cmd(self):
    print('MACHINE CMD')

  def run_diff(self):
    uuid = self.config.get('machine', 'uuid')
    key = self.config.get('machine', 'key')

    try:
      res = self.cs.machine_sync(uuid, key, template=True)

    except ServiceException as e:
      print(e)
      return 1

    m = Machine(res['template'])
    t = Template(res['template'])

    ts = Template('system')
    ts.from_system()

    (l_r, r_l) = t.package_diff(ts.packages_all)

    print("In template not in system:")

    for p in l_r:
      print(" - {0}".format(p.name))

    print()
    print("On system not in template:")

    for p in r_l:
      print(" + {0}".format(p.name))

    print()

  def run_list(self):
    # fetch all accessible/available templates
    try:
      machines = self.cs.machine_list(
        user=self.args.filter_user,
        name=self.args.filter_name,
        description=self.args.filter_description
      )

    except ServiceException as e:
      print(e)
      return 1

    if len(machines):
      l = prettytable.PrettyTable(["user:name", "title"])
      l.hrules = prettytable.HEADER
      l.vrules = prettytable.NONE
      l.align = 'l'
      l.padding_witdth = 1

      # add table items and print
      for m in machines:
        l.add_row(["{0}:{1}".format(m['username'], m['stub']), m['name']])

      print(l)

      # print summary
      print('\n{0} machine(s) found.'.format(len(machines)))

    else:
      print('0 machines found.')

  def run_rm(self):
    m = Machine(self.args.machine, user=self.args.username)

    try:
      res = self.cs.machine_delete(m)

    except ServiceException as e:
      print(e)
      return 1

    self.config.unset('machine', 'uuid')
    self.config.unset('machine', 'key')
    self.config.save()

    print('info: machine removed.')
    return 0

  def run_sync(self):
    uuid = self.config.get('machine', 'uuid')
    key = self.config.get('machine', 'key')

    try:
      res = self.cs.machine_sync(uuid, key, template=True)

    except ServiceException as e:
      print(e)
      return 1

    m = Machine(res['template'])
    t = Template(res['template'])

    # prepare dnf
    print('info: analysing system ...')
    db = dnf.Base()

    # install repos from template
    for r in t.repos_all:
      dr = r.to_repo()
      try:
        dr.load()
        db.repos.add(dr)

      except dnf.exceptions.RepoError as e:
        print(e)
        return 1

    db.read_comps()

    try:
      db.fill_sack()

    except OSError as e:
      pass

    multilib_policy = db.conf.multilib_policy
    clean_deps = db.conf.clean_requirements_on_remove

    # process all packages in template
    for p in t.packages_all:
      if p.included():
        #
        # stripped from dnf.base install() in full and optimesd
        # for canvas usage

        subj = dnf.subject.Subject(p.to_pkg_spec())
        if multilib_policy == "all" or subj.is_arch_specified(db.sack):
          q = subj.get_best_query(db.sack)

          if not q:
            continue

          already_inst, available = db._query_matches_installed(q)

          for a in available:
            db._goal.install(a, optional=False)

        elif multilib_policy == "best":
          sltrs = subj.get_best_selectors(db.sack)
          match = reduce(lambda x, y: y.matches() or x, sltrs, [])

          if match:
            for sltr in sltrs:
              if sltr.matches():
                db._goal.install(select=sltr, optional=False)

      else:
        #
        # stripped from dnf.base remove() in full and optimesd
        # for canvas usage
        matches = dnf.subject.Subject(p.to_pkg_spec()).get_best_query(db.sack)

        for pkg in matches.installed():
          db._goal.erase(pkg, clean_deps=clean_deps)

    db.resolve()

    # describe process for dry runs
    if self.args.dry_run:
      packages_install = list(db.transaction.install_set)
      packages_install.sort(key=lambda x: x.name)

      packages_remove = list(db.transaction.remove_set)
      packages_remove.sort(key=lambda x: x.name)

      if len(packages_install) or len(packages_remove):
        print('The following would be installed to (+) and removed from (-) the system:')

        for p in packages_install:
          print('  + ' + str(p))

        for p in packages_remove:
          print('  - ' + str(p))

        print()
        print('Summary:')
        print('  - Package(s): %d' % (len(packages_install)+len(packages_remove)))
        print()

      else:
        print('No system changes required.')

      print('No action peformed during this dry-run.')
      return 0

    # TODO: progress for download, install and removal
    db.download_packages(list(db.transaction.install_set))
    return db.do_transaction()

    print('info: machine synced.')

    return 0

  def run_update(self):
    m = Machine(self.args.machine, user=self.args.username)

    try:
      m = self.cs.machine_get(m)

    except ServiceException as e:
      print(e)
      return 1

    # add machine bits that are specified for update
    if self.args.template:
      t = Template(self.args.template, user=self.args.username)

      try:
        t = self.cs.template_get(t)

      except ServiceException as e:
        print(e)
        return 1

      m.template = t.uuid

    if self.args.name is not None:
      m.name = self.args.name

    if self.args.title is not None:
      m.title = self.args.title

    if self.args.title is not None:
      m.title = self.args.title

    if self.args.description is not None:
      m.description = self.args.description

    try:
      res = self.cs.machine_update(m)

    except ServiceException as e:
      print(e)
      return 1

    print('info: machine updated.')
    return 0

