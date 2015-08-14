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

from json import dumps as json_encode
from json import loads as json_decode

#
# CONSTANTS
#

ACTION_PIN     = 0x80
ACTION_EXCLUDE = 0x02
ACTION_INCLUDE = 0x01

#
# CLASS DEFINITIONS / IMPLEMENTATIONS
#

class Package(object):
  def __init__(self, *args, **kwargs):
    self.name     = kwargs.get('name', None)
    self.epoch    = kwargs.get('epoch', None)
    self.version  = kwargs.get('version', None)
    self.release  = kwargs.get('release', None)
    self.arch     = kwargs.get('arch', None)
    self.action   = kwargs.get('action', ACTION_INCLUDE)

    for arg in args:
      if isinstance(arg, dnf.package.Package):
        self.name    = arg.name
        self.epoch   = arg.epoch
        self.version = arg.version
        self.release = arg.release
        self.arch    = arg.arch

      elif isinstance(arg, dict):
        self.name    = arg.get('n', None)
        self.epoch   = arg.get('e', None)
        self.version = arg.get('v', None)
        self.release = arg.get('r', None)
        self.arch    = arg.get('a', None)
        self.action  = arg.get('z', ACTION_INCLUDE)

      elif isinstance(arg, str):
        parts = arg.split(':')

        if len(parts) == 1:
          self.name = parts[0]

        elif len(parts) == 2:
          self.name = parts[0]
          self.version = parts[1]

        elif len(parts) == 3:
          self.name = parts[0]
          self.version = parts[1]
          self.release = parts[2]
          self.arch = parts[3]

  def __eq__(self, other):
    if isinstance(other, Package):
      return (self.name == other.name)
    else:
      return False

  def __hash__(self):
    return hash(self.name)

  def __ne__(self, other):
    return (not self.__eq__(other))

  def __repr__(self):
    return 'Package: %s' % (self.name)

  def __str__(self):
    return 'Package: %s ' % ( json_encode( self.toObject(), separators=(',',':') ) )

  def toObject(self):
    o = {
      "n": self.name,
      "e": self.epoch,
      "v": self.version,
      "r": self.release,
      "a": self.arch,
      "z": self.action,
    }

    return {k: v for k, v in o.items() if v != None}

  def isPinned(self):
    return self.action & (ACTION_PIN)

  def isIncluded(self):
    return self.action & (ACTION_INCLUDE)

  def isExcluded(self):
    return self.action & (ACTION_EXCLUDE)

  def toJSON(self):
    return json_encode( self.toObject(), separators=(',',':') )



class Repository(object):
  def __init__(self, *args, **kwargs):
    self.name     = kwargs.get('name', None)
    self.stub     = kwargs.get('stub', None)

    self.baseurl    = kwargs.get('baseurl', None)
    self.mirrorlist = kwargs.get('mirrorlist', None)
    self.metalink   = kwargs.get('metalink', None)

    self.gpgkey     = kwargs.get('gpg_key', None)
    self.enabled    = kwargs.get('enabled', None)
    self.gpgcheck   = kwargs.get('gpg_check', None)
    self.cost       = kwargs.get('cost', None)
    self.exclude    = kwargs.get('exclude', None)

    self.meta_expired = kwargs.get('meta_expired', None)

    for arg in args:
      if isinstance(arg, dnf.repo.Repo):
        self.name     = arg.name
        self.stub     = arg.id

        self.baseurl    = arg.baseurl
        self.mirrorlist = arg.mirrorlist
        self.metalink   = arg.metalink

        self.gpgkey     = arg.gpgkey
        self.enabled    = arg.enabled
        self.gpgcheck   = arg.gpgcheck
        self.cost       = arg.cost
        self.exclude    = arg.exclude

#        self.meta_expired = arg.meta_expired

      elif isinstance(arg, dict):
        self.name     = arg.get('n', None)
        self.stub     = arg.get('s', None)

        self.baseurl    = arg.get('bu', None)
        self.mirrorlist = arg.get('ml', None)
        self.metalink   = arg.get('ma', None)

        self.gpgkey     = arg.get('gk', None)
        self.enabled    = arg.get('e', None)
        self.gpgcheck   = arg.get('gc', None)
        self.cost       = arg.get('c', None)
        self.exclude    = arg.get('x', None)

        self.meta_expired = arg.get('me', None)

  def __eq__(self, other):
    if isinstance(other, Repository):
      return (self.name == other.name)
    else:
      return False

  def __hash__(self):
    return hash(self.name)

  def __ne__(self, other):
    return (not self.__eq__(other))

  def __str__(self):
    return 'Repository: %s ' % ( json_encode( self.toObject(), separators=(',',':') ) )

  def toObject(self):
    o = {
      's':  self.stub,
      'n':  self.name,
      'bu': self.baseurl,
      'ml': self.mirrorlist,
      'ma': self.metalink,
      'e':  self.enabled,
      'gc': self.gpgcheck,
      'gk': self.gpgkey,
      'me': self.meta_expired,
      'c':  self.cost,
      'x':  self.exclude,
    }

    return {k: v for k, v in o.items() if v != None}

  def toJSON(self):
    return json_encode(self.toObject(), separators=(',',':'))

