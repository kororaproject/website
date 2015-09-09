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

import argcomplete
import argparse
import logging
import os
import sys

logger = logging.getLogger('canvas')

PROG_VERSION='1.0'
PROG_NAME='Canvas';

CANVAS_HOST='https://canvas.kororaproject.org'
#CANVAS_HOST='http://localhost:3000'

# establish invoking user
CANVAS_USER = os.environ.get('SUDO_USER', os.getlogin())

class ArgumentParserError(Exception):
  pass


class ErrorRaisingArgumentParser(argparse.ArgumentParser):
  def error(self, message):
    raise ArgumentParserError(message)

def buildCommandLineParser(config):
  parser = ErrorRaisingArgumentParser(prog='cnvs', add_help=False)
  subparsers = parser.add_subparsers(dest='command')

  # general arguments
  general_parser = argparse.ArgumentParser(add_help=False)
  general_parser.add_argument('-h', '--help', '-?', action='store_true', dest='help')
  general_parser.add_argument('-U', '--user', type=str, dest='username', default=config.get('user', 'name', CANVAS_USER))
  general_parser.add_argument('-H', '--host', type=str, dest='host', default=config.get('core', 'host', CANVAS_HOST))
  general_parser.add_argument('-v', '--verbose', action='store_true', dest='verbose')
  general_parser.add_argument('-V', '--version', action='version', version='{0} - {1}'.format(PROG_NAME, PROG_VERSION))

  #
  # CONFIG COMMANDS
  #

  config_parser = subparsers.add_parser('config', add_help=False, parents=[general_parser])
  config_parser.add_argument('--unset', action='store_true', dest='unset')
  config_parser.add_argument('name')
  config_parser.add_argument('value', nargs='?')

  #
  # TEMPLATE COMMANDS
  #

  template_parser = subparsers.add_parser('template', add_help=False, parents=[general_parser])
  subparsers_template = template_parser.add_subparsers(dest='action')

  template_parser.add_argument('-n', '--dry-run', action="store_true", dest='dry_run')

  # template add arguments
  template_add_parser = subparsers_template.add_parser('add', add_help=False, parents=[general_parser])
  template_add_parser.add_argument('template', type=str)
  template_add_parser.add_argument('--title', type=str)
  template_add_parser.add_argument('--description', type=str)
  template_add_parser.add_argument('--includes', type=str)
  template_add_parser.add_argument('--public', type=str, choices=['0', '1', 'false', 'true'])

  # template update arguments
  template_update_parser = subparsers_template.add_parser('update', add_help=False, parents=[general_parser])
  template_update_parser.add_argument('template', type=str)
  template_update_parser.add_argument('--title', type=str)
  template_update_parser.add_argument('--description', type=str)
  template_update_parser.add_argument('--includes', type=str)
#  template_update_parser.add_argument('--name', type=str)
  template_update_parser.add_argument('--public', type=str, choices=['0', '1', 'false', 'true'])

  # template list arguments
  template_list_parser = subparsers_template.add_parser('list', add_help=False, parents=[general_parser])
  template_list_parser.add_argument('filter_user', type=str, nargs='?')
  template_list_parser.add_argument('--public', action='store_true', dest='public_only')
  template_list_parser.add_argument('--filter-name', type=str, dest='filter_name')
  template_list_parser.add_argument('--filter-description', type=str, dest='filter_description')

  # template remove arguments
  template_remove_parser = subparsers_template.add_parser('rm', add_help=False, parents=[general_parser])
  template_remove_parser.add_argument('template', type=str)

  # template pull arguments
  template_pull_parser = subparsers_template.add_parser('pull', add_help=False, parents=[general_parser])
  template_pull_parser.add_argument('template', type=str)
  template_pull_parser.add_argument('--clean', action='store_true', dest='pull_clean')

  # template push arguments
  template_push_parser = subparsers_template.add_parser('push', add_help=False, parents=[general_parser])
  template_push_parser.add_argument('template', type=str)
  template_push_parser.add_argument('--all', action='store_true', dest='push_all')

  # template diff arguments
  template_diff_parser = subparsers_template.add_parser('diff', add_help=False, parents=[general_parser])
  template_diff_parser.add_argument('template_from', type=str)
  template_diff_parser.add_argument('template_to', type=str, nargs='?')
  template_diff_parser.add_argument('--output', type=str)

  # template copy arguments
  template_copy_parser = subparsers_template.add_parser('copy', add_help=False, parents=[general_parser])
  template_copy_parser.add_argument('template_from', type=str)
  template_copy_parser.add_argument('template_to', type=str, nargs='?')

  # template dump arguments
  template_dump_parser = subparsers_template.add_parser('dump', add_help=False, parents=[general_parser])
  template_dump_parser.add_argument('template', type=str)
  template_dump_parser.add_argument('--json', action='store_true')
  template_dump_parser.add_argument('--yaml', action='store_true')

  #
  # PACKAGE COMMANDS
  #

  package_parser = subparsers.add_parser('package', add_help=False, parents=[general_parser])
  subparsers_package = package_parser.add_subparsers(dest='action', title='Package Commands')

  package_parser.add_argument('-n', '--dry-run', action="store_true", dest='dry_run')

  # package add arguments
  package_add_parser = subparsers_package.add_parser('add', add_help=False, parents=[general_parser])
  package_add_parser.add_argument('template', type=str)
  package_add_parser.add_argument('package', type=str, nargs='+')
  package_add_parser.add_argument('--with-deps', type=str)

  package_update_parser = subparsers_package.add_parser('update', add_help=False, parents=[general_parser])
  package_update_parser.add_argument('template', type=str)
  package_update_parser.add_argument('package', type=str, nargs='+')

  # package list arguments
  package_list_parser = subparsers_package.add_parser('list', add_help=False, parents=[general_parser])
  package_list_parser.add_argument('template', type=str)
  package_list_parser.add_argument('--output', type=str)

  # package remove arguments
  package_remove_parser = subparsers_package.add_parser('rm', add_help=False, parents=[general_parser])
  package_remove_parser.add_argument('template', type=str)
  package_remove_parser.add_argument('package', type=str, nargs='+')

  #
  # REPO COMMANDS
  #

  repo_parser = subparsers.add_parser('repo', add_help=False, parents=[general_parser])
  subparsers_repo = repo_parser.add_subparsers(dest='action', title='repo Commands')

  repo_parser.add_argument('-n', '--dry-run', action="store_true", dest='dry_run')

  # repo add arguments
  repo_add_parser = subparsers_repo.add_parser('add', add_help=False, parents=[general_parser])
  repo_add_parser.add_argument('template', type=str)
  repo_add_parser.add_argument('repo', type=str)
  repo_add_parser.add_argument('--name', type=str)
  repo_add_parser.add_argument('--cost', type=int)
  repo_add_parser.add_argument('--baseurl', type=str, nargs='+')
  repo_add_parser.add_argument('--enabled', type=str, choices=['0', '1', 'false', 'true'])
  repo_add_parser.add_argument('--gpgkey', type=str, nargs='+')
  repo_add_parser.add_argument('--metalink', type=str, nargs='+')
  repo_add_parser.add_argument('--mirrorlist', type=str, nargs='+')
  repo_add_parser.add_argument('--gpgcheck', type=bool)
  repo_add_parser.add_argument('--priority', type=int)
  repo_add_parser.add_argument('--exclude', type=str, nargs='+')
  repo_add_parser.add_argument('--skip-if-unavailable', type=bool, dest='skip')

  # repo update arguments
  repo_update_parser = subparsers_repo.add_parser('update', add_help=False, parents=[general_parser])
  repo_update_parser.add_argument('template', type=str)
  repo_update_parser.add_argument('repo', type=str)
  repo_update_parser.add_argument('--name', type=str)
  repo_update_parser.add_argument('--cost', type=int)
  repo_update_parser.add_argument('--baseurl', type=str, nargs='+')
  repo_update_parser.add_argument('--enabled', type=str, choices=['0', '1', 'false', 'true'])
  repo_update_parser.add_argument('--gpgkey', type=str, nargs='+')
  repo_update_parser.add_argument('--metalink', type=str, nargs='+')
  repo_update_parser.add_argument('--mirrorlist', type=str, nargs='+')
  repo_update_parser.add_argument('--gpgcheck', type=bool)
  repo_update_parser.add_argument('--priority', type=int)
  repo_update_parser.add_argument('--exclude', type=str, nargs='+')
  repo_update_parser.add_argument('--skip-if-unavailable', type=bool, dest='skip')

  # repo list arguments
  repo_list_parser = subparsers_repo.add_parser('list', add_help=False, parents=[general_parser])
  repo_list_parser.add_argument('template', type=str)

  # repo remove arguments
  repo_remove_parser = subparsers_repo.add_parser('rm', add_help=False, parents=[general_parser])
  repo_remove_parser.add_argument('template', type=str)
  repo_remove_parser.add_argument('repo', type=str, nargs='+')

  #
  # MACHINE COMMANDS
  #

  #
  # machine general arguments
  machine_parser = subparsers.add_parser('machine', add_help=False, parents=[general_parser], usage='')
  subparsers_machine = machine_parser.add_subparsers(dest='action', title='Machine Commands')

  # machine add arguments
  machine_add_parser = subparsers_machine.add_parser('add', add_help=False, parents=[general_parser])
  machine_add_parser.add_argument('machine', type=str)
  machine_add_parser.add_argument('--description', type=str)
  machine_add_parser.add_argument('--location', type=str)
  machine_add_parser.add_argument('--template', type=str)

  # machine update arguments
  machine_update_parser = subparsers_machine.add_parser('update', add_help=False, parents=[general_parser])
  machine_update_parser.add_argument('machine', type=str)
  machine_update_parser.add_argument('--description', type=str)
  machine_update_parser.add_argument('--location', type=str)
  machine_update_parser.add_argument('--template', type=str)

  # machine remove arguments
  machine_remove_parser = subparsers_machine.add_parser('rm', add_help=False, parents=[general_parser])
  machine_remove_parser.add_argument('machine', type=str)

  # machine diff arguments
  machine_diff_parser = subparsers_machine.add_parser('diff', add_help=False, parents=[general_parser])
  machine_diff_parser.add_argument('machine', type=str)
  machine_diff_parser.add_argument('--output', type=str)

  # machine sync arguments
  machine_sync_parser = subparsers_machine.add_parser('sync', add_help=False, parents=[general_parser])
  machine_sync_parser.add_argument('machine', type=str)
  machine_sync_parser_group = machine_sync_parser.add_mutually_exclusive_group()
  machine_sync_parser_group.add_argument('pull', type=str, nargs='?')
  machine_sync_parser_group.add_argument('push', type=str, nargs='?')

  # machine command arguments
  machine_command_parser = subparsers_machine.add_parser('cmd', add_help=False, parents=[general_parser])
  machine_command_parser.add_argument('machine', type=str)
  machine_command_parser.add_argument('cmd', type=str)
  machine_command_parser.add_argument('args', type=str, nargs='*')

  return parser

def parseCommandLine(config):
  parser = buildCommandLineParser(config)

  args = None
  args_extra = None

  # parse known commands printing general usage on any error
  try:
    argcomplete.autocomplete(parser)
    args, args_extra = parser.parse_known_args()

  except:
    # TODO: determine best help instead of general
    args = argparse.Namespace()
    args.command = sys.argv[1]
    args.action  = sys.argv[2]
    args.host = config.get('core', 'host', CANVAS_HOST)
    args.username = config.get('user', 'name', CANVAS_USER)
    args.help = True

  return (args, args_extra)


def general_usage(prog_name='canvas'):
  print("usage: {0} [--version] [--help] [--verbose] <command> [<args>]\n"
        "\n"
        "The available canvas commands are:\n"
        "  template  Add file contents to the index\n"
        "  package   Find by binary search the change that introduced a bug\n"
        "  repo      List, create, or delete branches\n"
        "  machine   Checkout a branch or paths to the working tree\n"
        "  config    Clone a repository into a new directory\n".format(prog_name))


class Command(object):
  def __init__(self, prog_name='canvas'):
    self.prog_name = prog_name

  def configure(self, config, args, args_extra):
    pass

  def help(self):
    pass

  def run(self):
    pass
