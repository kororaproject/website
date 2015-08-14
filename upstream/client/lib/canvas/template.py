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
  def __init__(self, template=''):
    self._name = None
    self._user = None
    self._id = None
    self._description = None

    self._meta = {}

    self._repos = []
    self._packages = []

    self._parse_template(template)

  def __str__(self):
    return 'Template: %s (owner: %s) - R: %d, P: %d' % (self._name, self._user, len(self._repos), len(self._packages))

  def _parse_template(self, template):
    if isinstance( template, str ):
      parts = template.split(':')

      if len(parts) == 1:
        self._user = TEMPLATE_USER_DEFAULT
        self._name = parts[0]

      elif len(parts) == 2:
        self._user = parts[0]
        self._name = parts[1]

    if isinstance(template, dict):
      self._id = template.get('id', None)
      self._user = template.get('user', template.get('owner', None))
      self._name = template.get('name', None)
      self._description = template.get('description', None)

      self._meta = template.get('meta', {})

      self._repos = [Repository(r) for r in template.get('repos', [])]
      self._packages = [Package(p) for p in template.get('packages', [])]

      if self._id is not None:
        self._id = int(self._id)

  def set(self, template):
    self._parse_template(template)

  @property
  def id(self):
    return self._id

  @property
  def name(self):
    return self._name

  @property
  def user(self):
    return self._user

  @property
  def description(self):
    return self._description

  @property
  def packages(self):
    return self._packages

  @property
  def repos(self):
    return self._repos

  def addPackage(self, package):
    if not isinstance( package, Package ):
      raise TypeError('Not a Package object')

    self._packages.append( package )

  def addRepo(self, repo):
    if not isinstance(repo, Repository):
      raise TypeError('Not a Repository object')

    self._repos.append( repo )

  def package(self, name):
    for p in self._packages:
      if p.name == name:
        return p

    return None

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
             'repos':    [r.toObject() for r in self._repos],
             'packages': [p.toObject() for p in self._packages]
           }

  def toJSON(self):
    return json_encode(self.toObject(), separators=(',',':'))


  def writeCanvasRepo(self):
    pass


