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
from canvas.service import CanvasService
from canvas.template import Template

logger = logging.getLogger('canvas')

class TemplateCommand(Command):
  def configure(self, config, args, args_extra):
    # store loaded config
    self.config = config

    # create our canvas service object
    self.cs = CanvasService(host=args.host)

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
          "\n".format(self.PROG_NAME))

  def run(self):
    print("TEMPLATE RUN")

    # search for our function based on the specified action
    command = getattr(self, 'run_{0}'.format(self.args.action))

    if not command:
      return

    return command()

  def run_add(self):
    print("TEMPLATE ADD")

  def run_update(self):
    print("TEMPLATE UPDATE")

  def run_remove(self):
    print("TEMPLATE RM")

  def run_push(self):
    print("TEMPLATE PUSH")

  def run_pull(self):
    print("TEMPLATE PULL")

  def run_diff(self):
    print("TEMPLATE DIFF")

  def run_copy(self):
    print("TEMPLATE COPY")

  def run_list(self):
    # authentication is optional
    if self.args.username:
      self.cs.authenticate(self.args.username, getpass.getpass('Password ({0}): '.format(self.args.username)))

    tl = self.cs.template_list()

    if len(tl):
      print('Templates:')

      for t in tl:
        print('  - {0} ({1}) - {2}'.format(t['stub'], t['username'], t['name']))

      print
      print('%d template(s) found.' % ( len(tl) ))

    else:
      print('0 templates found.')

