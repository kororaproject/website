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

import logging

from canvas.cli.commands import Command

logger = logging.getLogger('canvas')

class ConfigCommand(Command):
  def configure(self, config, args, args_extra):
    # store loaded config
    self.config = config

    # store args for additional processing
    self.args = args

    # return false if any error, help, or usage needs to be shown
    return not args.help

  def help(self):
    print("General usage: {0} [--version] [--help] [--verbose] [--unset] name [value]\n"
          "\n"
          "\n".format(self.PROG_NAME))

  def run(self):
    parts = self.args.name.split('.')

    # one part indicates a key without section
    if len(parts) == 1:
      print("error: key does not contain a section: {0}".format(parts[0]))
      return 1

    # user needs some help
    elif len(parts) != 2:
      self.help()
      return 1

    if self.args.unset:
      # save if key was unset
      if self.config.unset(parts[0], parts[1])
        self.config.save()

    elif self.args.value is not None:
      self.config.set(parts[0], parts[1], self.args.value)
      self.config.save()

    else:
      value = self.config.get(parts[0], parts[1])
      if value is not None:
        print(value)

    return 0
