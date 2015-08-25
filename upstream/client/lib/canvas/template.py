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

from canvas.package import Package, Repository

from json import dumps as json_encode
from json import loads as json_decode

#
# CONSTANTS
#

TEMPLATE_USER_DEFAULT = "firnsy"

#
# CLASS DEFINITIONS / IMPLEMENTATIONS
#

class Template(object):
  def __init__(self, template=None, user=None):
    self._name = None
    self._user = user
    self._id = None
    self._title = ''
    self._description = ''

    self._includes = []
    self._meta = {}

    self._repos = []
    self._packages = []

    self._parse_template(template)

  def __str__(self):
    return 'Template: %s (owner: %s) - R: %d, P: %d' % (self._name, self._user, len(self._repos), len(self._packages))

  def _parse_template(self, template):
    if isinstance(template, str):
      parts = template.split(':')

      if len(parts) == 1:
        self._name = parts[0]

      elif len(parts) == 2:
        self._user = parts[0]
        self._name = parts[1]

    if isinstance(template, dict):
      self._id = template.get('id', None)
      self._user = template.get('user', template.get('username', None))
      self._name = template.get('stub', None)
      self._title = template.get('name', self._name)
      self._description = template.get('description', None)

      self._includes = template.get('includes', [])
      self._meta = template.get('meta', {})

      self._repos = [Repository(r) for r in template.get('repos', [])]
      self._packages = [Package(p) for p in template.get('packages', [])]

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
  def id(self):
    return self._id

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
    return self._packages

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
    return self._repos

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
    if not isinstance( package, Package ):
      raise TypeError('Not a Package object')

    self._packages.append( package )

  def add_repo(self, repo):
    if not isinstance(repo, Repository):
      raise TypeError('Not a Repository object')

    self._repos.append( repo )

  def package(self, name):
    for p in self._packages:
      if p.name == name:
        return p

    return None

  def parse(self, template):
    self._parse_template(template)

  def union(self, template):
    if not isinstance(template, Template):
      TypeError('template is not of type Template')

    if self._id is None:
      self._id = template.id

    if self._name is None:
      self._name = template.name

    if self._user is None:
      self._user = template.user

    if self._description is None:
      self._description = template.description

    r = set(self.repos)
    p = set(self.packages)

    r.update(template.repos)
    p.update(template.packages)

    self._repos = list(r)
    self._packages = list(p)

  def difference(self, template):
    if not isinstance(template, Template):
      TypeError('template is not of type Template')

    if self._id is None:
      self._id = template.id

    if self._name is None:
      self._name = template.name

    if self._user is None:
      self._user = template.user

    if self._description is None:
      self._description = template.description

    r = set(self.repos)
    p = set(self.packages)

    r_remove = set(template.repos)
    p_remove = set(template.packages)

    r = r.difference(r_remove)
    p = p.difference(p_remove)

    self._repos = list(r)
    self._packages = list(p)


  def toObject(self):
    return { 'name': self._name,
             'user': self._user,
             'title': self._title,
             'description': self._description,
             'includes': self._includes,
             'meta':     self._meta,
             'packages': [p.toObject() for p in self._packages],
             'repos':    [r.toObject() for r in self._repos]
           }

  def toJSON(self):
    return json_encode(self.toObject(), separators=(',',':'))


  def writeCanvasRepo(self):
    pass


