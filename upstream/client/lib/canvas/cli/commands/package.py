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
import prettytable

from canvas.cli.commands import Command
from canvas.package import Package, Repository
from canvas.service import Service, ServiceException
from canvas.template import Template

logger = logging.getLogger('canvas')

class PackageCommand(Command):
  def configure(self, config, args, args_extra):
    # store loaded config
    self.config = config

    # create our canvas service object
    self.cs = Service(host=args.host, username=args.username)

    # store args for additional processing
    self.args = args

    # return false if any error, help, or usage needs to be shown
    return not args.help

  def run(self):
    # search for our function based on the specified action
    command = getattr(self, 'run_{0}'.format(self.args.action))

    if not command:
      print('error: action is not reachable.')
      return

    return command()

  def run_add(self):
    t = Template(self.args.template, user=self.args.username)

    try:
      t = self.cs.template_get(t)

    except ServiceException as e:
      print(e)
      return 1

    for p in self.args.package:
      t.add_package(Package(p))

    packages = list(t.packages_delta)
    packages.sort(key=lambda x: x.name)

    # describe process for dry runs
    if self.args.dry_run:
      if len(packages):
        print('The following would be added to the template: {0}'.format(t.name))

        for p in packages:
          print('  - ' + str(p))

        print()
        print('Summary:')
        print('  - Package(s): %d' % ( len(packages) ))
        print()

      else:
        print('No template changes required.')

      print('No action peformed during this dry-run.')
      return 0

    if not len(packages):
      print('info: no changes detected, template up to date.')
      return 0

    # push our updated template
    try:
      res = self.cs.template_update(t)

    except ServiceException as e:
      print(e)
      return 1

  def run_list(self):
    t = Template(self.args.template, user=self.args.username)

    try:
      t = self.cs.template_get(t)

    except ServiceException as e:
      print(e)
      return 1

    packages = list(t.packages_all)
    packages.sort(key=lambda x: x.name)

    repos = list(t.repos_all)
    repos.sort(key=lambda x: x.name)

    if len(packages):
      l = prettytable.PrettyTable(["package", "arch"])
      l.hrules = prettytable.HEADER
      l.vrules = prettytable.NONE
      l.align = 'l'
      l.padding_witdth = 1

      for p in packages:
        l.add_row([p.name, p.arch])

      print(l)
      print()

    else:
      print('0 packages defined.')

  def run_rm(self):
    t = Template(self.args.template, user=self.args.username)

    try:
      t = self.cs.template_get(t)

    except ServiceException as e:
      print(e)
      return 1

    packages = []

    for p in self.args.package:
      p = Package(p)
      if t.remove_package(p):
        packages.append(p)

    packages.sort(key=lambda x: x.name)

    # describe process for dry runs
    if self.args.dry_run:
      if len(packages):
        print('The following would be removed from the template: {0}'.format(t.name))

        for p in packages:
          print('  - ' + str(p))

        print()
        print('Summary:')
        print('  - Package(s): %d' % ( len(packages) ))
        print()

      else:
        print('No template changes required.')

      print('No action peformed during this dry-run.')
      return 0

    if not len(packages):
      print('info: no changes detected, template up to date.')
      return 0

    # push our updated template
    try:
      res = self.cs.template_update(t)

    except ServiceException as e:
      print(e)
      return 1

  def run_update(self):
    print('PACKAGE UPDATE')
    print(self.args)
