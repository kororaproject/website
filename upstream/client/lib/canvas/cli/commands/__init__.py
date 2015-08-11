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

logger = logging.getLogger('canvas')


def general_usage(prog_name='canvas'):
  print("usage: {0} [--version] [--help] [--verbose] <command> [<args>]\n"
        "\n"
        "The available canvas commands are:\n"
        "   template   Add file contents to the index\n"
        "   package    Find by binary search the change that introduced a bug\n"
        "   repo       List, create, or delete branches\n"
        "   machine    Checkout a branch or paths to the working tree\n"
        "   config     Clone a repository into a new directory\n".format(prog_name))

class Command(object):
  def __init__(self):
    pass

  def configure(self, args):
    return True

  def help(self):
    pass

  def run(self):
    pass
