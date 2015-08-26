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
import hawkey

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

    # parse all args package defined objects
    for arg in args:
      if isinstance(arg, dnf.package.Package) or \
         isinstance(arg, hawkey.Package):
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

    # strip evr information as appropriate
    if not kwargs.get('evr', True):
      self.epoch = None
      self.version = None
      self.release = None

  def __eq__(self, other):
    if isinstance(other, Package):
      return (self.name == other.name)
    else:
      return False

  def __hash__(self):
    # package uniqueness is based on name and arch
    # this allows packages with different archs to be
    # specified in a template
    if self.arch is None:
      return hash(self.name)

    return hash('{0}.{1}'.format(self.name, self.arch))

  def __ne__(self, other):
    return (not self.__eq__(other))

  def __repr__(self):
    return 'Package: %s' % (self.name)

  def __str__(self):
    return 'Package: %s ' % ( json_encode( self.to_object(), separators=(',',':') ) )

  def excluded(self):
    return self.action & (ACTION_EXCLUDE)

  def included(self):
    return self.action & (ACTION_INCLUDE)

  def pinned(self):
    return self.action & (ACTION_PIN)

  def to_pkg_spec(self):
    # return empty string if no name (should never happen)
    if self.name is None:
      return ''

    f = self.name

    # calculate evr
    evr = None

    if self.epoch is not None:
      evr = self.epoch + ':'

    if self.version is not None and self.release is not None:
      evr += '{0}-{1}'.format(self.version, self.release)
    elif self.version is not None:
      evr += self.version

    # append evr if appropriate
    if evr is not None:
      f += evr

    # append arch if appropriate
    if self.arch is not None:
      f += '.' + self.arch

    return f

  def to_json(self):
    return json_encode( self.to_object(), separators=(',',':') )

  def to_object(self):
    o = {
      "n": self.name,
      "e": self.epoch,
      "v": self.version,
      "r": self.release,
      "a": self.arch,
      "z": self.action,
    }

    # only build with non-None values
    return {k: v for k, v in o.items() if v != None}



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
    return hash(self.stub)

  def __ne__(self, other):
    return (not self.__eq__(other))

  def __str__(self):
    return 'Repository: %s ' % ( json_encode( self.to_object(), separators=(',',':') ) )

  def to_json(self):
    return json_encode(self.to_object(), separators=(',',':'))

  def to_object(self):
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

    # only build with non-None values
    return {k: v for k, v in o.items() if v != None}

  def to_repo(self, cache_dir=None):
    print(cache_dir)
    if cache_dir is None:
      cli_cache = dnf.conf.CliCache('/var/tmp')
      cache_dir = cli_cache.cachedir

    r = dnf.repo.Repo('canvas_{0}'.format(self.stub), cache_dir)

    if self.name is not None:
      r.name = self.name

    if self.baseurl is not None:
      r.baseurl = self.baseurl

    if self.mirrorlist is not None:
      r.mirrorlist = self.mirrorlist

    if self.metalink is not None:
      r.metalink = self.metalink

    if self.gpgcheck is not None:
      r.gpgcheck = self.gpgcheck

    if self.gpgkey is not None:
      r.gpgkey = self.gpgkey

    if self.cost is not None:
      r.cost = self.cost

    if self.exclude is not None:
      r.exclude = self.exclude

    if self.meta_expired is not None:
      r.meta_expired = self.meta_expired

    if self.enabled is not None and not self.enabled:
      r.disable()

    return r
