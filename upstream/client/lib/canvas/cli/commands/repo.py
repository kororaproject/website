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

class RepoCommand(Command):
  def configure(self, config, args, args_extra):
    # store loaded config
    self.config = config

    # create our canvas service object
    self.cs = Service(host=args.host)

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
    print('REPO ADD')

  def run_update(self):
    print('REPO UPDATE')

  def run_list(self):
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

    packages = list(t.packages_all)
    packages.sort(key=lambda x: x.name)

    repos = list(t.repos_all)
    repos.sort(key=lambda x: x.name)

    if len(repos):
      l = prettytable.PrettyTable(['repo', 'priority', 'cost', 'enabled'])
      l.hrules = prettytable.HEADER
      l.vrules = prettytable.NONE
      l.align = 'l'
      l.padding_witdth = 1

      for r in repos:
        l.add_row([r.name, r.priority, r.cost, r.enabled])

      print(l)
      print()

    else:
      print('0 repos defined.')

  def run_rm(self):
    print('REPO REMOVE')
