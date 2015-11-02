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
import json
import yaml

from canvas.package import Package, Repository

#
# CLASS DEFINITIONS / IMPLEMENTATIONS
#

class Template(object):
  def __init__(self, template=None, user=None):
    self._name = None
    self._user = user
    self._uuid = None
    self._title = ''
    self._description = ''

    self._includes = []             # includes in template
    self._includes_resolved = []    # data structs for all includes in template
    self._meta = {}

    self._repos = set()             # repos in template
    self._includes_repos = set()    # repos from includes in template
    self._delta_repos = set()       # repos to add/remove in template

    self._packages = set()          # packages in template
    self._includes_packages = set() # packages from includes in template
    self._delta_packages = set()    # packages to add/remove in template

    self._stores   = []             # remote stores for machine
    self._archives = []             # archive definitions in machine

    self._parse_template(template)

  def __str__(self):
    return 'Template: %s (owner: %s) - R: %d, P: %d' % (self._name, self._user, len(self.repos_all), len(self.packages_all))

  def _flatten(self):
    for tr in self._includes_resolved:
      t = Template(tr)

      self._includes_repos.update(t.repos_all)
      self._includes_packages.update(t.packages_all)

  def _parse_template(self, template):
    # parse the string short form
    if isinstance(template, str):
      parts = template.split(':')

      if len(parts) == 1:
        self._name = parts[0]

      elif len(parts) == 2:
        self._user = parts[0]
        self._name = parts[1]

    # parse the dict form, the most common form and directly
    # relates to the json structures returned by canvas server
    elif isinstance(template, dict):
      self._uuid = template.get('uuid', None)
      self._user = template.get('user', template.get('username', None))
      self._name = template.get('stub', None)
      self._title = template.get('name', self._name)
      self._description = template.get('description', None)

      self._includes = template.get('includes', [])
      self._includes_resolved = template.get('includes_resolved', [])

      self._repos = {Repository(r) for r in template.get('repos', [])}
      self._packages = {Package(p) for p in template.get('packages', [])}

      self._stores   = template.get('stores', [])
      self._archives = template.get('archives', [])

      self._meta = template.get('meta', {})

      # resolve includes
      self._flatten()

  #
  # PROPERTIES
  @property
  def description(self):
    return self._description

  @description.setter
  def description(self, value):
    if value is None or len(str(value)) == 0:
      return

    self._description = str(value)

  @property
  def uuid(self):
    return self._uuid

  @property
  def includes(self):
    return self._includes

  @includes.setter
  def includes(self, value):
    if ',' in value:
      value = value.split(',')

    self._includes = value

  @property
  def name(self):
    return self._name

  @property
  def packages(self):
    return self._packages.union(self._delta_packages)

  @property
  def packages_all(self):
    return self._packages.union(self._includes_packages).union(self._delta_packages)

  @property
  def packages_delta(self):
    return self._delta_packages

  @property
  def public(self):
    return self._meta.get('public', False)

  @public.setter
  def public(self, state):
    if state:
      self._meta['public'] = True

    else:
      self._meta.pop('public', None)

  @property
  def repos(self):
    return self._repos.union(self._delta_repos)

  @property
  def repos_all(self):
    return self._repos.union(self._includes_repos).union(self._delta_repos)

  @property
  def repos_delta(self):
    return self._delta_repos

  @property
  def title(self):
    return self._title

  @title.setter
  def title(self, value):
    self._title = value

  @property
  def user(self):
    return self._user

  #
  # PUBLIC METHODS
  def add_package(self, package):
    if not isinstance(package, Package):
      raise TypeError('Not a Package object')

    if package not in self.packages_all:
      self._delta_packages.add(package)

  def add_repo(self, repo):
    if not isinstance(repo, Repository):
      raise TypeError('Not a Repository object')

    if repo not in self.repos_all:
      self._delta_repos.add(repo)

  def find_package(self, name):
    return [p for p in self.packages if p.name == name]

  def find_repo(self, repo_id):
    return [r for r in self.repos if r.stub == repo_id]

  def from_system(self, all=False):
    db = dnf.Base()
    try:
      db.fill_sack()

    except OSError as e:
      pass

    p_list = db.iter_userinstalled()

    if all:
      p_list = db.sack.query().installed()

    for p in p_list:
      self.add_package(Package(p, evr=False))

    for r in db.repos.enabled():
      self.add_repo(Repository(r))

  def package_diff(self, packages):
    l_packages = self.packages_all
    r_packages = set(packages)

    return (
      l_packages.difference(set(r_packages)),
      r_packages.difference(set(l_packages))
    )

  def parse(self, template):
    self._parse_template(template)

  def repo_diff(self, repos):
    return self.repos_all.difference(set(repos))

  def repos_to_repodict(self, cache_dir=None):
    rd = dnf.repodict.RepoDict()

    if cache_dir is None:
      cli_cache = dnf.conf.CliCache('/var/tmp')
      cache_dir = cli_cache.cachedir

    for r in self.repos_all:
      dr = r.to_repo(cache_dir)

      # load the repo
      dr.load()

      # add it to the dict
      rd.add(dr)

    return rd

  def remove_package(self, package):
    if not isinstance(package, Package):
      raise TypeError('Not a Package object')

    if package in self._delta_packages:
      self._packages.remove(package)
      return True

    elif package in self._packages:
      self._packages.remove(package)
      return True

    return False

  def remove_repo(self, repo):
    if not isinstance(repo, Repository):
      raise TypeError('Not a Repository object')

    if repo in self._delta_repos:
      self._delta_repos.remove(repo)
      return True

    elif repo in self._repos:
      self._repos.remove(repo)
      return True

    return False

  def update_package(self, package):
    if not isinstance(package, Package):
      raise TypeError('Not a Package object')

    if package in self._delta_packages:
      self._delta_packages.remove(package)
      self._delta_packages.add(package)
      return True

    elif package in self._packages:
      self._packages.remove(package)
      self._packages.add(package)
      return True

    return False

  def update_repo(self, repo):
    if not isinstance(repo, Repository):
      raise TypeError('Not a Repository object')

    if repo in self._delta_repos:
      self._delta_repos.remove(repo)
      self._delta_repos.add(repo)
      return True

    elif repo in self._repos:
      self._repos.remove(repo)
      self._repos.add(repo)
      return True

    return False

  def union(self, template):
    if not isinstance(template, Template):
      TypeError('template is not of type Template')

    if self._name is None:
      self._name = template.name

    if self._user is None:
      self._user = template.user

    if self._description is None:
      self._description = template.description

    self._repos.update(template.repos)
    self._packages.update(template.packages)

  def to_json(self):
    return json.dumps(self.to_object(), separators=(',',':'))

  def to_object(self):
    # sort packages and repos
    packages = list(self.packages)
    packages.sort(key=lambda x: x.name)

    repos = list(self.repos)
    repos.sort(key=lambda x: x.stub)

    return {
      'uuid':        self._uuid,
      'name':        self._name,
      'user':        self._user,
      'title':       self._title,
      'description': self._description,
      'includes':    self._includes,
      'packages':    [p.to_object() for p in packages],
      'repos':       [r.to_object() for r in repos],
      'stores':      self._stores,
      'archives':    self._archives,
      'meta':        self._meta
    }

  def to_yaml(self):
    return yaml.dump(self.to_object())



class Machine(object):
  def __init__(self, machine=None, user=None, key=None):
    self._name        = None
    self._user        = user
    self._template    = None
    self._uuid        = None
    self._title       = ''
    self._description = ''
    self._key         = key

    self._stores   = []       # remote stores for machine
    self._archives = []       # archive definitions in machine
    self._history  = []       # history of machine
    self._meta     = {}

    self._parse_machine(machine)

  def __str__(self):
    return 'Machine: {0} (owner: {1})- S:{2}, A:{3}, H:{4}'.format(
        self._name,
        self._user,
        len(self._stores),
        len(self._archives),
        len(self._history)
      )

  def _parse_machine(self, machine):
    # parse the string short form
    if isinstance(machine, str):
      parts = machine.split(':')

      if len(parts) == 1:
        self._name = parts[0]

      elif len(parts) == 2:
        self._user = parts[0]
        self._name = parts[1]

    # parse the dict form, the most common form and directly
    # relates to the json structures returned by canvas server
    elif isinstance(machine, dict):
      self._uuid = machine.get('uuid', self._uuid)
      self._template = machine.get('template', self._template)
      self._user = machine.get('user', machine.get('username', None))
      self._name = machine.get('stub', self._name)
      self._title = machine.get('name', self._title)
      self._description = machine.get('description', None)

      self._stores   = machine.get('stores', [])
      self._archives = machine.get('archives', [])
      self._history  = machine.get('history', [])
      self._meta = machine.get('meta', {})

  #
  # PROPERTIES
  @property
  def archives(self):
    return self._archives

  @property
  def description(self):
    return self._description

  @description.setter
  def description(self, value):
    if value is None or len(str(value)) == 0:
      return

    self._description = str(value)

  @property
  def history(self):
    return self._history

  @property
  def name(self):
    return self._name

  @name.setter
  def name(self, value):
    self._name = value

  @property
  def stores(self):
    return self._stores

  @property
  def template(self):
    return self._template

  @template.setter
  def template(self, value):
    self._template = value

  @property
  def title(self):
    return self._title

  @title.setter
  def title(self, value):
    self._title = value

  @property
  def user(self):
    return self._user

  @property
  def uuid(self):
    return self._uuid

  @uuid.setter
  def uuid(self, value):
    self._uuid = value

  #
  # PUBLIC METHODS

  def to_json(self):
    return json.dumps(self.to_object(), separators=(',',':'))

  def to_object(self):
    return {
      'uuid':        self._uuid,
      'template':    self._template,
      'name':        self._name,
      'user':        self._user,
      'title':       self._title,
      'description': self._description,
      'stores':      self._stores,
      'archives':    self._archives,
      'history':     self._history,
      'meta':        self._meta,
    }

  def to_yaml(self):
    return yaml.dump(self.to_object())
