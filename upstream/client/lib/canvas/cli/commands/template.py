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
import getpass
import logging
import prettytable
from functools import reduce

from canvas.cli.commands import Command
from canvas.package import Package, Repository
from canvas.service import Service, ServiceException
from canvas.template import Template

logger = logging.getLogger('canvas')

class TemplateCommand(Command):
  def configure(self, config, args, args_extra):
    # store loaded config
    self.config = config

    # create our canvas service object
    self.cs = Service(host=args.host)

    try:
      # expand includes
      if args.includes is not None:
        args.includes = args.includes.split(',')
    except:
      pass

    # eval public
    try:
      if args.public is not None:
        args.public = (args.public in ['1', 'true'])
    except:
      pass

    # store args for additional processing
    self.args = args

    # return false if any error, help, or usage needs to be shown
    return not args.help

  def help(self):
    print("General usage: {0} [--version] [--help] [--verbose] template [<args>]\n"
          "\n"
          "Specific usage:\n"
          "{0} template add [user:]template [--name] [--description] [--includes] [--public]\n"
          "{0} template update [user:]template [--name] [--description] [--includes] [--public]\n"
          "{0} template rm [user:]template\n"
          "{0} template push [user:]template [--all]\n"
          "{0} template pull [user:]template [--clean]\n"
          "{0} template diff [user:]template\n"
          "{0} template copy [user_from:]template_from [[user_to:]template_to]\n"
          "{0} template list\n"
          "\n".format(self.prog_name))

  def run(self):
    # search for our function based on the specified action
    command = getattr(self, 'run_{0}'.format(self.args.action))

    if not command:
      print('error: action is not reachable.')
      return

    return command()

  def run_add(self):
    t = Template(self.args.template, user=self.args.username)

    if self.args.username:
      if not self.cs.authenticate(self.args.username, getpass.getpass('Password ({0}): '.format(self.args.username))):
        print('error: unable to authenticate with canvas service.')
        return 1

    # add template bits that are specified
    if self.args.title is not None:
      t.title = self.args.title

    if self.args.description is not None:
      t.description = self.args.description

    if self.args.includes is not None:
      t.includes = self.args.includes

    if self.args.public is not None:
      t.public = self.args.public

    try:
      res = self.cs.template_create(t)

    except ServiceException as e:
      print(e)
      return 1

    print('info: template added.')
    return 0

  def run_copy(self):
    t = Template(self.args.template_from, user=self.args.username)

    if self.args.username:
      if not self.cs.authenticate(self.args.username, getpass.getpass('Password ({0}): '.format(self.args.username))):
        print('error: unable to authenticate with canvas service.')
        return 1

    try:
      t = self.cs.template_get(t)

    except ServiceException as e:
      print(e)
      return 1

    # reparse for template destination
    t.parse(self.args.template_to)

    try:
      res = self.cs.template_create(t)

    except ServiceException as e:
      print(e)
      return 1

    print('info: template copied.')
    return 0

  def run_diff(self):
    print("TEMPLATE DIFF NOT YET IMPLEMENTED")

  def run_list(self):
    # authentication is optional
    if self.args.username:
      self.cs.authenticate(self.args.username, getpass.getpass('Password ({0}): '.format(self.args.username)))

    try:
      templates = self.cs.template_list()

    except ServiceException as e:
      print(e)
      return 1

    if len(templates):
      l = prettytable.PrettyTable(["user:name", "title"])
      l.hrules = prettytable.HEADER
      l.vrules = prettytable.NONE
      l.align = 'l'
      l.padding_witdth = 1

      # add table items and print
      for t in templates:
        l.add_row(["{0}:{1}".format(t['username'], t['stub']), t['name']])

      print(l)

      # print summary
      print('\n{0} template(s) found.'.format(len(templates)))

    else:
      print('0 templates found.')

  def run_pull(self):
    t = Template(self.args.template, user=self.args.username)

    if self.args.username:
      if not self.cs.authenticate(self.args.username, getpass.getpass('Password ({0}): '.format(self.args.username))):
        print('error: unable to authenticate with canvas service.')
        return 1

    try:
      t = self.cs.template_get(t)

    except ServiceException as e:
      print(e)
      return 1

    # prepare dnf
    print('info: analysing system ...')
    db = dnf.Base()

    # install repos from template
    for r in t.repos_all:
      dr = r.to_repo()
      dr.load()
      db.repos.add(dr)

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

  def run_push(self):
    t = Template(self.args.template, user=self.args.username)

    if self.args.username:
      if not self.cs.authenticate(self.args.username, getpass.getpass('Password ({0}): '.format(self.args.username))):
        print('error: unable to authenticate with canvas service.')
        return 1

    # grab the template we're pushing to
    try:
      t = self.cs.template_get(t)

    except ServiceException as e:
      print(e)
      return 1

    # prepare dnf
    print('info: analysing system ...')
    db = dnf.Base()
    db.read_all_repos()
    db.read_comps()

    try:
      db.fill_sack()

    except OSError as e:
      pass

    db_list = db.iter_userinstalled()

    if self.args.push_all:
      db_list = db.sack.query().installed()

    # add our user installed packages
    for p in db_list:
      # no need to store versions
      t.add_package(Package(p, evr=False))

    # add only enabled repos
    for r in db.repos.enabled():
      t.add_repo(Repository(r))

    packages = list(t.packages_delta)
    packages.sort(key=lambda x: x.name)

    repos = list(t.repos_delta)
    repos.sort(key=lambda x: x.name)

    # describe process for dry runs
    if self.args.dry_run:
      if len(packages) or len(repos):
        print('The following would be added to the template: {0}'.format(t.name))

        for p in packages:
          print('  - ' + str(p))

        for r in repos:
          print('  - ' + str(r))

        print()
        print('Summary:')
        print('  - Package(s): %d' % ( len(packages) ))
        print('  - Repo(s): %d' % ( len(repos) ))
        print()

      else:
        print('No template changes required.')

      print('No action peformed during this dry-run.')
      return 0

    if not len(packages) and not len(repos):
      print('info: no changes detected, template up to date.')
      return 0

    # push our updated template
    try:
      res = self.cs.template_update(t)

    except ServiceException as e:
      print(e)
      return 1

    print('info: template pushed.')
    return 0

  def run_rm(self):
    t = Template(self.args.template, user=self.args.username)

    if not self.cs.authenticate(self.args.username, getpass.getpass('Password ({0}): '.format(self.args.username))):
      print('error: unable to authenticate with canvas service.')
      return 1

    try:
      res = self.cs.template_delete(t)

    except ServiceException as e:
      print(e)
      return 1

    print('info: template removed.')
    return 0

  def run_update(self):
    t = Template(self.args.template, user=self.args.username)

    if self.args.username:
      if not self.cs.authenticate(self.args.username, getpass.getpass('Password ({0}): '.format(self.args.username))):
        print('error: unable to authenticate with canvas service.')
        return 1

    try:
      t = self.cs.template_get(t)

    except ServiceException as e:
      print(e)
      return 1

    # add template bits that are specified for update
    if self.args.title is not None:
      t.title = self.args.title

    if self.args.description is not None:
      t.description = self.args.description

    if self.args.includes is not None:
      t.includes = self.args.includes

    if self.args.public is not None:
      t.public = self.args.public

    try:
      res = self.cs.template_update(t)

    except ServiceException as e:
      print(e)
      return 1

    print('info: template updated.')
    return 0
