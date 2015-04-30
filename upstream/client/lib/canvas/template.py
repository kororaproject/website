#!/usr/bin/python
#
# Copyright (C) 2013    Ian Firns   <firnsy@kororaproject.org>
#                       Chris Smart <csmart@kororaproject.org>
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
import http.cookiejar
import urllib.request, urllib.parse, urllib.error
import urllib.request, urllib.error, urllib.parse

from json import dumps as json_encode
from json import loads as json_decode

#
# CONSTANTS
#

# bit 7: 0 = not pinned, 1 = pinned
ACTION_PINNED    = 0x80
# bit 1: 0 = removed, 1 = installed
ACTION_INSTALLED = 0x01

#
# CLASS DEFINITIONS / IMPLEMENTATIONS
#

class Template(object):
  def __init__(self, template=''):
    self._name = None
    self._user = None
    self._id = None
    self._description = None

    self._package_list = PackageList()
    self._repo_list = RepositoryList()

    self._parse_template( template )

  def _parse_template(self, template):
    if isinstance( template, str ):
      parts = template.split(':')

      if len(parts) == 1:
        self._name = parts[0]

      elif len(parts) == 2:
        self._user = parts[0]
        self._name = parts[1]

    if isinstance(template, dict):
      if 'id' in template:
        self._id = template['id']

      if 'user' in template:
        self._user = template['user']

      if 'name' in template:
        self._name = template['name']

      if 'account' in template:
        self._user = template['account']

      if 'description' in template:
        self._description = template['description']

      if 'repos' in template:
        if isinstance(template['repos'], list):
          for r in template['repos']:
            _r = Repository()
            _r.fromObject(r)
            self._repo_list.add( _r )

      if 'packages' in template:
        if isinstance(template['packages'], list):
          for p in template['packages']:
            _p = Package()
            _p.fromObject(p)
            self._package_list.add( _p )


  def set(self, template):
    self._parse_template(template)

  @property
  def id(self):
    return self._id

  @property
  def name(self):
    return self._name

  @property
  def account(self):
    return self._user

  @property
  def user(self):
    return self._user

  @property
  def description(self):
    return self._description

  def getPackageList(self):
    return self._package_list

  def setPackageList(self, package_list):
    if not isinstance(package_list, PackageList):
      TypeError('list is not of type PackageList')

    self._package_list = package_list

  def getRepositoryList(self):
    return self._repo_list

  def setRepositoryList(self, repo_list):
    if not isinstance(repo_list, RepositoryList):
      TypeError('list is not of type RepositoryList')

    self._repo_list = repo_list

  def toObject(self):
    return { 'name': self._name,
             'user': self._user,
             'repos': self._repo_list.toObject(),
             'packages': self._package_list.toObject() }

  def toJSON(self):
    return json_encode( self.toObject(), separators=(',',':') )

  def __str__(self):
    return 'Template: %s (owner: %s)' % (self._name, self._user)


class Package(object):
  def __init__(self, name=None, epoch=None, version=None, release=None, arch=None, action=None):
    self.name = name
    self.epoch = epoch
    self.version = version
    self.release = release
    self.arch = arch
    self.action = action

  def fromObject(self, package):
    if isinstance(package, str):
      parts = package.split(':')

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

    if isinstance(package, dict):
      if 'n' in package:
        self.name = package['n']

      if 'e' in package:
        self.epoch = package['e']

      if 'v' in package:
        self.version = package['v']

      if 'r' in package:
        self.release = package['r']

      if 'a' in package:
        self.arch = package['a']

      if 'z' in package:
        self.action = int( package['z'] )

  def toObject(self):
    return {
      "n": self.name,
      "e": self.epoch,
      "v": self.version,
      "r": self.release,
      "a": self.arch,
      "z": self.action,
    }

  def isPinned(self):
    return self.action & ( 0x3c );

  def actionInstall(self):
    return self.action & ( 1 );

  def actionUninstall(self):
    return self.action & ( 2 );

  def toJSON(self):
    return json_encode( self.toObject(), separators=(',',':') )

  def __str__(self):
    return 'Package: %s ' % ( json_encode( self.toObject(), separators=(',',':') ) )


class PackageList(object):
  def __init__(self, packages=[]):
    self._packages = []

    self._parse_packages( packages )

  def _parse_packages(self, packages ):
    if isinstance(packages, list):
      for p in packages:
        self._packages.append( Package( p ) )

  def add(self, package):
    if not isinstance( package, Package ):
      raise TypeError('Not a Package object')

    self._packages.append( package )

  def packages(self):
    return self._packages

  def toObject(self):
    return [p.toObject() for p in self._packages]

  def toJSON(self):
    return json_encode( self.toObject(), separators=(',',':') )

  def count(self):
    return len(self._packages)

  def __str__(self):
    return 'PackageList: %d package.' % ( len(self._packages) )

class Repository(object):
  def __init__(self, name=None, stub=None, baseurl=None, mirrorlist=None, metalink=None, enabled=None, gpg_key=None, gpg_check=None, meta_expired=None, cost=None, exclude=None):
    self._name = name
    self._stub = stub

    self.baseurl = baseurl
    self.mirrorlist = mirrorlist
    self.metalink = metalink

    self.gpgkey = gpg_key
    self.enabled = enabled
    self.gpgcheck = gpg_check
    self.cost = cost

    self.meta_expired = meta_expired
    self.exclude = exclude

  @property
  def name(self):
    return self._name

  @property
  def stub(self):
    return self._stub

  def fromObject(self, repo, clear=False):
    if isinstance(repo, dict):
      self.has_details = False

      if 's' in repo:
        self._stub = repo['s']

      if 'bu' in repo:
        self.baseurl = repo['bu']

      if 'ml' in repo:
        self.mirrorlist = repo['ml']

      if 'ma' in repo:
        self.metalink = repo['ma']

      if 'n' in repo:
        self._name = repo['n']

      if 'gk' in repo:
        self.gpgkey = repo['gk']

      if 'me' in repo:
        self.meta_expired = repo['me']

      if 'gc' in repo:
        self.gpgcheck = repo['gc']

      if 'e' in repo:
        self.enabled = repo['e']

      if 'c' in repo:
        self.cost = repo['c']

    else:
      raise Exception("Can't read from %s object" % ( type(repo) ) )

  def toObject(self):
    return {
      's':  self._stub,
      'n':  self._name,
      'bu':  self.baseurl,
      'ml':  self.mirrorlist,
      'ma':  self.metalink,
      'e':  self.enabled,
      'gc': self.gpgcheck,
      'gk': self.gpgkey,
      'me': self.meta_expired,
      'c':  self.cost,
      'x':  self.exclude,
    }

  def toJSON(self):
    return json_encode( self.toObject(), separators=(',',':') )

  def __str__(self):
    return 'Repository: %s ' % ( json_encode( self.toObject(), separators=(',',':') ) )


class RepositoryList(object):
  def __init__(self, repos=[]):
    self._repos = []

    self._parse_repos( repos )

  def _parse_repos(self, repos ):
    for r in repos:
      self._repos.append( Repository( r.id, r.name, r.baseurl, r.mirrorlist, r.metalink, r.enabled, r.gpgkey, r.gpgcheck, r.metadata_expire, r.cost, r.exclude ) )

  def add(self, repo):
    if not isinstance( repo, Repository ):
      raise TypeError('Not a Repository object')

    self._repos.append( repo )

  def repos(self):
    return self._repos

  def toObject(self):
    return [r.toObject() for r in self._repos]

  def toJSON(self):
    return json_encode( self.toObject(), separators=(',',':') )


class CanvasService(object):
  def __init__(self, host='https://canvas.kororaproject.org'):
    self._host = host
    self._urlbase = host

    self._cookiejar = http.cookiejar.CookieJar()
    self._opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(self._cookiejar))

    self._authenticated = False

  def authenticate(self, username='', password='', force=False):

    print(('Authenticating to %s' % ( self._urlbase )))

    if self._authenticated and not self._force:
      return self._authenticated

    auth = json_encode( { 'u': username, 'p': password }, separators=(',',':') ).encode('utf-8')

    self._authenticated = False

    try:
      r = urllib.request.Request(self._urlbase + '/authenticate.json', auth)
      u = self._opener.open(r)
      self._authenticated = True

    except urllib.error.URLError as e:
      print(e)
    except urllib.error.HTTPError as e:
      print(e)

    return self._authenticated

  def deauthenticate(self, username='', password='', force=False):
    if not self._authenticated and not self._force:
      return self._authenticated

    try:
      r = urllib.request.Request('%s/deauthenticate.json' % ( self._urlbase ))
      u = self._opener.open(r)

    except urllib.error.URLError as e:
      print(e)
    except urllib.error.HTTPError as e:
      print(e)

    #
    self._authenticated = False

    return self._authenticated


  def template_create(self, template):

    if not isinstance(template, Template):
      TypeError('template is not of type Template')

    try:
      r = urllib.request.Request('%s/api/templates.json' % ( self._urlbase ), template.toJSON().encode('utf-8'))
      u = self._opener.open(r)
      print(( u.read() ))

      return True

    except urllib.error.URLError as e:
      print(e)
    except urllib.error.HTTPError as e:
      print(e)

    return False


  def template_delete(self, template_id):

    try:
      r = urllib.request.Request('%s/api/template/%d.json' % ( self._urlbase, template_id ))
      r.get_method = lambda: 'DELETE'
      u = self._opener.open(r)
      o = json_decode( u.read().decode('utf-8') )

      return True

    except urllib.error.URLError as e:
      print(e)
    except urllib.error.HTTPError as e:
      print(e)

    return False


  def template_add(self, template):

    if not isinstance(template, Template):
      TypeError('template is not of type Template')

    try:
      r = urllib.request.Request('%s/api/templates.json' % ( self._urlbase ), template.toJSON())
      r.get_method = lambda: 'PUT'
      u = self._opener.open(r)
      print(( u.read() ))

      return True

    except urllib.error.URLError as e:
      print(e)
    except urllib.error.HTTPError as e:
      print(e)

    return False


  def template_get(self, template):

    if not isinstance(template, Template):
      TypeError('template is not of type Template')

    query = { 'account': template.user, 'name': template.name }
    try:
      r = urllib.request.Request('%s/api/templates.json?%s' % ( self._urlbase, urllib.parse.urlencode(query) ))
      u = self._opener.open(r)

      template_summary = json_decode( u.read().decode('utf-8') )

      if len( template_summary ):
        # we only have one returned since template names are unique per account
        r = urllib.request.Request('%s/api/template/%d.json' % ( self._urlbase, template_summary[0]['id'] ))
        u = self._opener.open(r)

        return Template( template=json_decode( u.read().decode('utf-8') ) )

    except urllib.error.URLError as e:
      print(e)
    except urllib.error.HTTPError as e:
      print(e)

    return None

  def template_list(self):
    """ Check if the korora template exists
    """
    try:
      r = urllib.request.Request('%s/api/templates.json' % ( self._urlbase ))
      u = self._opener.open(r)

      return json_decode( u.read().decode('utf-8') )

    except urllib.error.URLError as e:
      print(e)
    except urllib.error.HTTPError as e:
      print(e)

    return []

  def template_remove(self, template):

    if not isinstance(template, Template):
      TypeError('template is not of type Template')


  def repository_find(self, stub=None, arch=None, version=None, url=None):

    query = {}

    if stub is not None:
      query['s'] = stub

    try:
      r = urllib.request.Request('%s/api/repositories.json?%s' % ( self._urlbase, urllib.parse.urlencode(query) ))
      u = self._opener.open(r)

      repo_summary = json_decode( u.read().decode('utf-8') )

      if len( repo_summary ):
        query = {}
        if arch is not None:
          query['a'] = arch

        if version is not None:
          query['v'] = version

        if url is not None:
          query['u'] = url

        r = urllib.request.Request('%s/api/repository/%d.json?%s' % ( self._urlbase, repo_summary[0]['id'], urllib.parse.urlencode(query) ))
        u = self._opener.open(r)

        repo = Repository()
        repo.fromObject( json_decode( u.read().decode('utf-8') ) )

        return repo

    except urllib.error.URLError as e:
      print(e)
    except urllib.error.HTTPError as e:
      print(e)

    return None
