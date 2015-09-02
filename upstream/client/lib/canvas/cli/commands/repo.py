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
    self.cs = Service(host=args.host, username=args.username)

    # eval enabled
    try:
      if args.enabled is not None:
        args.enabled = (args.enabled.lower() in ['1', 'true'])

    except:
      pass

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

    # default enabled
    if self.args.enabled is None:
      self.args.enabled = True

    r = Repository(
      stub        = self.args.repo,
      name        = self.args.name,
      baseurl     = self.args.baseurl,
      mirrorlist  = self.args.mirrorlist,
      metalink    = self.args.metalink,
      enabled     = self.args.enabled,
      cost        = self.args.cost,
      priority    = self.args.priority,
      gpgkey      = self.args.gpgkey,
      gpgcheck    = self.args.gpgcheck,
      exclude     = self.args.exclude
    )

    t.add_repo(r)

    # push our updated template
    try:
      res = self.cs.template_update(t)

    except ServiceException as e:
      print(e)
      return 1

    print('info: repo added.')
    return 0


  def run_update(self):
    t = Template(self.args.template, user=self.args.username)

    try:
      t = self.cs.template_get(t)

    except ServiceException as e:
      print(e)
      return 1

    r = t.find_repo(self.args.repo)

    if len(r) != 1:
      print('error: repo is not defined in template.')
      return 1

    r = r[0]
    o = {
      'n':  self.args.name,
      'bu': self.args.baseurl,
      'ml': self.args.mirrorlist,
      'ma': self.args.metalink,
      'e':  self.args.enabled,
      'c':  self.args.cost,
      'p':  self.args.priority,
      'gc': self.args.gpgcheck,
      'gk': self.args.gpgkey,
      'sk': self.args.skip,
      'x':  self.args.exclude
    }

    o = {k: v for k, v in o.items() if v != None}

    r.parse(o)

    if not t.update_repo(r):
      print('error: no changes detected.')
      return 0

    # push our updated template
    try:
      res = self.cs.template_update(t)

    except ServiceException as e:
      print(e)
      return 1

    print('info: repo updated.')
    return 0

  def run_list(self):
    t = Template(self.args.template, user=self.args.username)

    try:
      t = self.cs.template_get(t)

    except ServiceException as e:
      print(e)
      return 1

    repos = list(t.repos_all)
    repos.sort(key=lambda x: x.stub)

    if len(repos):
      l = prettytable.PrettyTable(['id', 'repo', 'priority', 'cost', 'enabled'])
      l.hrules = prettytable.HEADER
      l.vrules = prettytable.NONE
      l.align = 'l'
      l.padding_witdth = 1

      for r in repos:
        if r.cost is None:
          r.cost = '-';

        if r.priority is None:
          r.priority = '-';

        if r.enabled:
          r.enabled = 'Y'

        else:
          r.enabled = 'N'

        l.add_row([r.stub, r.name, r.priority, r.cost, r.enabled])

      print(l)
      print()

    else:
      print('0 repos defined.')

  def run_rm(self):
    t = Template(self.args.template, user=self.args.username)

    try:
      t = self.cs.template_get(t)

    except ServiceException as e:
      print(e)
      return 1

    repos = []

    for r in self.args.repo:
      r = Repository(r)
      if t.remove_repo(r):
        repos.append(r)

    repos.sort(key=lambda x: x.stub)

    # describe process for dry runs
    if self.args.dry_run:
      if len(repos):
        print('The following would be removed from the template: {0}'.format(t.name))

        for r in repos:
          print('  - ' + str(r))

        print()
        print('Summary:')
        print('  - Repo(s): %d' % ( len(repos) ))
        print()

      else:
        print('No template changes required.')

      print('No action peformed during this dry-run.')
      return 0

    if not len(repos):
      print('info: no changes detected, template up to date.')
      return 0

    # push our updated template
    try:
      res = self.cs.template_update(t)

    except ServiceException as e:
      print(e)
      return 1

