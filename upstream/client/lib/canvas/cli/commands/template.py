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

import getpass
import logging

from canvas.cli.commands import Command
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
          "{0} template push [user:]template\n"
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

  def run_push(self):
    print("TEMPLATE PUSH NOT YET IMPLEMENTED")

#    if self.args.system:
#      print('Adding current system packages to template ...')
#
#      db = dnf.Base()
#      db.read_all_repos()
#      db.read_comps()
#      try:
#        db.fill_sack()
#      except OSError as e:
#        pass
#
#      db_query = db.sack.query()
#      pkgs = db_query.installed()
#
#      for p in pkgs:
#        t.packages.append(Package(p))
#
#      # TODO: repos are statically set for now
#      if 0:
#        for r in db.repos.enabled():
#          t.repos.append(Repository(r))
#
#    for p in args.packages:
#      t.packages.append(Package(p))
#
#
#    if self.args.dryrun:
#      print('The following would be added to the template %s:' % ( str(t) ))
#
#      packages = t.getPackageList().packages()
#      packages.sort( key=lambda x: x.name )
#
#      for p in packages:
#        print('  - ' + str(p))
#
#      repos = t.getRepositoryList().repos()
#      repos.sort( key=lambda x: x.name )
#      for r in repos:
#        print('  - ' + str(r))
#
#      print
#      print('Summary:')
#      print('  - Package(s): %d' % ( len(packages) ))
#      print('  - Repo(s): %d' % ( len(repos) ))
#      print
#      print('No action peformed during this dry-run.')

  def run_pull(self):
    print("TEMPLATE PULL NOT YET IMPLEMENTED")

  def run_diff(self):
    print("TEMPLATE DIFF NOT YET IMPLEMENTED")

  def run_copy(self):
    print("TEMPLATE COPY NOT YET IMPLEMENTED")

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
      print('Templates:')

      for t in templates:
        print('  - {0} ({1}) - {2}'.format(t['stub'], t['username'], t['name']))

      print('\n{0} template(s) found.'.format(len(templates)))

    else:
      print('0 templates found.')

