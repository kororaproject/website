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
          "{0} machine list\n"
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

    if self.args.username:
      try:
        self.cs.authenticate(self.args.username)

      except ServiceException as e:
        print(e)
        return 1

    t = Template(self.args.template, user=self.args.username)

    # grab the template we're associating to the machine
    try:
      t = self.cs.template_get(t)

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

    print('info: machine added.')
    return 0

  def run_cmd(self):
    print('MACHINE CMD')

  def run_diff(self):
    print('MACHINE DIFF')

  def run_list(self):
    # always auth
    try:
      self.cs.authenticate()

    except ServiceException as e:
      print(e)
      return 1

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
    print('MACHINE REMOVE')

  def run_sync(self):
    print('MACHINE SYNC')

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

