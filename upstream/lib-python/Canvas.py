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

import cookielib
import json
import urllib
import urllib2
import yum

from urlgrabber.progress import TextMeter

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
    self._package_list_remove = PackageList()
    self._repo_list = RepoList()
    self._repo_list_remove = RepoList()

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

      if 'name' in template:
        self._name = template['name']

      if 'account' in template:
        self._user = template['account']

      if 'description' in template:
        self._name = template['description']

      if 'r' in template:
        if isinstance(template['r'], list):
          for r in template['r']:
            self._repo_list.add( Repo( repo=r ) )

      if 'p' in template:
        if isinstance(template['p'], list):
          for p in template['p']:
            self._package_list.add( Package( package=p ) )


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

  def merge(self, template, clean=False):
    if not isinstance( template, Template ):
      TypeError('template is not of template Template')

    if template.name is not None:
      self._name = template.name

    if template.user is not None:
      self._user = template.user

    if template.description is not None:
      self._description = template.description

    pl_install = PackageList()
    pl_remove = PackageList()
    rl_enable = RepoList()

    # look for packages in our template and not in the template being merged
    for op in self._package_list.packages():

      found = False

      for tp in template.getPackageList().packages():
        # match on name only
        if op.name != tp.name:
          continue

        # TODO
        if tp.isPinned():
          pl_install.add( tp )

        found = True

      # a package exists in ours but not in the template being merged
      # remove if we're doing a clean merge
      if not found and clean:
        pl_remove.add( tp )


    # look for package in the merge template and not in our template
    for tp in self._package_list.packages():

      found = False

      for op in template.getPackageList().packages():
        # match on name only
        if op.name != tp.name:
          continue

        # TODO
        if tp.isPinned():
          pl_install.add( tp )

        found = True

      # package is in the merged template but not in our template so let's add
      if not found:
        pl_install.add( tp )


    # look for repos in our template and not in the template being merged
    for tr in template.getRepoList().repos():

      found = False

      for r in self._repo_list.repos():
        # match on name only
        if r.name != tr.name:
          continue

        found = True

      # repo is in the merged template but not in our template so let's add
      if not found:
        rl_enable.add( tr )


    self._package_list = pl_install
    self._package_list_remove = pl_remove
    self._repo_list = rl_enable

  def getPackageList(self):
    return self._package_list

  def getPackageListRemove(self):
    return self._package_list_remove

  def setPackageList(self, package_list):
    if not isinstance(package_list, PackageList):
      TypeError('list is not of type PackageList')

    self._package_list = package_list

  def getRepoList(self):
    return self._repo_list

  def getRepoListRemove(self):
    return self._repo_list_remove

  def setRepoList(self, repo_list):
    if not isinstance(repo_list, RepoList):
      TypeError('list is not of type RepoList')

    self._repo_list = repo_list

  def toObject(self):
    return { 'n': self._name,
             'u': self._user,
             'r': self._repo_list.toObject(),
             'p': self._package_list.toObject() }

  def toJSON(self):
    return json.dumps( self.toObject(), separators=(',',':') )

  def __str__(self):
    return 'Template: %s (owner: %s)' % (self._name, self._user)


class Package(object):
  def __init__(self, name=None, epoch=None, version=None, release=None, arch=None, summary=None, description=None, license=None, url=None, install_size=None, package_size=None, build_time=None, file_time=None, src_package=None, provides=None, files=None, files_in_provides=False):
    self.name = name
    self.epoch = epoch
    self.version = version
    self.release = release
    self.arch = arch

    self.summary = summary
    self.description = description
    self.license = license
    self.url = url

    self.install_size = install_size
    self.package_size = package_size

    self.build_time = build_time
    self.file_time = file_time

    self.repo_id = 1

    self.details = []

    # parse the name if it contains field separators
    if isinstance(name, Package):
      self._parse_package( name )

    elif name.find(':') != -1:
      self._parse_package( name )

    else:
      self.name = name

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
        self._arch = package['a']


  def addDetails(self, details):
    if not isinstance(details, RepositoryDetails):
      raise TypeError('Not a RepositoryDetails object')

    # TODO: check for duplicates before inserting

    self.details.append( details )


  def hasDetails(self):
    return len( self.details ) > 0


  def set(self, package):
    self._parse_package(package)

  def pin(self, state=False):
    self._pin = state

  def isPinned(self):
    return self._pin

  def toObject(self):
    details = []

    # add all details objects before returning
    for d in self.details:
      details.append( d.toObject() )

    return {
      "n": self.name,
      "s": self.summary,
      "sx": self.description,
      "l": self.license,
      "u": self.url,

      "d": details
    }

  def toJSON(self):
    return json.dumps( self.toObject(), separators=(',',':') )

  def __str__(self):
    return 'Package: %s (e:%s, v:%s, r:%s, a:%s)' % (self._name, self._epoch, self._version, self._release, self._arch)


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
    return json.dumps( self.toObject(), separators=(',',':') )

  def count(self):
    return len(self._packages)

  def __str__(self):
    return 'PackageList: %d package.' % ( len(self._packages) )

class Repository(object):
  def __init__(self, stub=None, enabled=None, gpg_key=None, gpg_check=None, meta_expired=None, cost=None, exclude=None, id=None):
    self.stub = stub

    self.id = id
    self.gpgkey = gpg_key
    self.enabled = enabled
    self.gpgcheck = gpg_check
    self.cost = cost

    self.meta_expired = meta_expired
    self.exclude = exclude

    # no details indicates a general repo only
    self.has_details = False

    self.details = []

    self.packages = []

  def fromObject(self, repo, clear=False):
    if isinstance(repo, dict):
      self.has_details = False

      if 'id' in repo:
        self.id = repo['id']

      if 's' in repo:
        self.stub = repo['s']

      if 'n' in repo:
        self.name = repo['n']

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

      if 'd' in repo:
        if isinstance(repo['d'], list):
          for d in repo['d']:
            rd = RepositoryDetails()
            rd.fromObject( d )

            self.details.append( rd )

        else:
          raise Exception('Object details are not in list form.')


    else:
      raise Exception("Can't read from %s object" % ( type(repo) ) )

  def addDetails(self, details):
    if not isinstance(details, RepositoryDetails):
      raise TypeError('Not a RepositoryDetails object')

    # TODO: check for duplicates before inserting

    self.details.append( details )


  def hasDetails(self):
    return len( self.details ) > 0

  def blessPackage(self, package, arch=None, version=None):
    if not isinstance(package, Package):
      raise TypeError('Not a Package object')

    if len( self.details ) == 0:
      raise Exception('Unable to bless package from a general repo')
    elif len( self.details ) > 1 and ( arch == None and version == None ):
      raise Exception('Unable to bless package with multiple details and no filter.')

    for d in self.details:
      if arch is not None and not d.arch == arch:
        continue

      if version is not None and not d.version == version:
        continue

      # set the repo identifier
      package.repo_id = self.id

      # only set the id once
      break

    return package

  def toObject(self):
    details = []

    # add all details objects before returning
    for d in self.details:
      details.append( d.toObject() )

    return {
      'id': self.id,
      's':  self.stub,
      'e':  self.enabled,
      'gc': self.gpgcheck,
      'gk': self.gpgkey,
      'me': self.meta_expired,
      'c':  self.cost,
      'x':  self.exclude,
      'd':  details
    }

  def toJSON(self):
    return json.dumps( self.toObject(), separators=(',',':') )

  def __str__(self):
    return self.toJSON()

# TODO: REMOVE
class Repo(Repository):
  pass


class RepositoryDetails(object):
  def __init__(self, name=None, arch=None, version=None, url=None):

    self.id = None

    self.name = name
    self.arch = arch
    self.version = version
    self.url = url

  def fromObject(self, details):
    if isinstance(details, dict):
      if 'id' in details:
        self.id = details['id']

      if 'n' in details:
        self.name = details['n']

      if 'a' in details:
        self.arch = details['a']

      if 'v' in details:
        self.version = details['v']

      if 'u' in details:
        self.url = details['u']

    else:
      raise Exception("Can't read from %s object" % ( type(repo) ) )


  def toObject(self):
    return {
      'id': self.id,
      'n':  self.name,
      'a':  self.arch,
      'v':  self.version,
      'u':  self.url,
    }



class RepoList(object):
  def __init__(self, repos=[]):
    self._repos = []

    self._parse_repos( repos )

  def _parse_repos(self, repos ):
    for r in repos:
      if isinstance(r, yum.yumRepo.YumRepository):
        self._repos.append( Repo( r.id, r.name, r.baseurl, r.mirrorlist, r.enabled, r.gpgcheck, r.gpgkey, r.metadata_expire, r.cost, r.exclude ) )

  def add(self, repo):
    if not isinstance( repo, Repo ):
      raise TypeError('Not a Repo object')

    self._repos.append( repo )

  def repos(self):
    return self._repos

  def toObject(self):
    return [r.toObject() for r in self._repos]

  def toJSON(self):
    return json.dumps( self.toObject(), separators=(',',':') )


class CanvasService(object):
  def __init__(self, host='https://canvas.kororaproject.org'):
    self._host = host
    self._urlbase = host

    self._cookiejar = cookielib.CookieJar()
    self._opener = urllib2.build_opener(urllib2.HTTPCookieProcessor(self._cookiejar))

    self._authenticated = False

  def authenticate(self, username='', password='', force=False):

    print('Authenticating to %s' % ( self._urlbase ))

    if self._authenticated and not self._force:
      return self._authenticated

    auth = json.dumps( { 'u': username, 'p': password }, separators=(',',':') )

    self._authenticated = False

    try:
      r = urllib2.Request(self._urlbase + '/authenticate.json', auth)
      u = self._opener.open(r)
      self._authenticated = True

    except urllib2.URLError, e:
      print e
    except urllib2.HTTPError, e:
      print e

    return self._authenticated

  def deauthenticate(self, username='', password='', force=False):
    if not self._authenticated and not self._force:
      return self._authenticated

    try:
      r = urllib2.Request('%s/deauthenticate.json' % ( self._urlbase ))
      u = self._opener.open(r)

    except urllib2.URLError, e:
      print e
    except urllib2.HTTPError, e:
      print e

    #
    self._authenticated = False

    return self._authenticated


  def template_create(self, template):

    if not isinstance(template, Template):
      TypeError('template is not of type Template')

    try:
      r = urllib2.Request('%s/api/templates.json' % ( self._urlbase ), template.toJSON())
      u = self._opener.open(r)
      print u.read()

      return True

    except urllib2.URLError, e:
      print e
    except urllib2.HTTPError, e:
      print e

    return False


  def template_delete(self, template_id):

    try:
      r = urllib2.Request('%s/api/template/%d.json' % ( self._urlbase, template_id ))
      r.get_method = lambda: 'DELETE'
      u = self._opener.open(r)
      o = json.loads( u.read() )

      return True

    except urllib2.URLError, e:
      print e
    except urllib2.HTTPError, e:
      print e

    return False


  def template_add(self, template):

    if not isinstance(template, Template):
      TypeError('template is not of type Template')

    try:
      r = urllib2.Request('%s/api/templates.json' % ( self._urlbase ), template.toJSON())
      r.get_method = lambda: 'PUT'
      u = self._opener.open(r)
      print u.read()

      return True

    except urllib2.URLError, e:
      print e
    except urllib2.HTTPError, e:
      print e

    return False


  def template_get(self, template):

    if not isinstance(template, Template):
      TypeError('template is not of type Template')

    query = { 'account': template.user, 'name': template.name }
    try:
      r = urllib2.Request('%s/api/templates.json?%s' % ( self._urlbase, urllib.urlencode(query) ))
      u = self._opener.open(r)

      template_summary = json.loads( u.read() )

      if len( template_summary ):
        # we only have one returned since template names are unique per account
        r = urllib2.Request('%s/api/template/%d.json' % ( self._urlbase, template_summary[0]['id'] ))
        u = self._opener.open(r)

        return Template( template=json.loads( u.read() ) )

    except urllib2.URLError, e:
      print e
    except urllib2.HTTPError, e:
      print e

    return None

  def template_list(self):
    """ Check if the korora template exists
    """
    try:
      r = urllib2.Request('%s/api/templates.json' % ( self._urlbase ))
      u = self._opener.open(r)

      return json.loads( u.read() )

    except urllib2.URLError, e:
      print e
    except urllib2.HTTPError, e:
      print e

    return []

  def template_remove(self, template):

    if not isinstance(template, Template):
      TypeError('template is not of type Template')


  def repository_find(self, stub=None, arch=None, version=None, url=None):

    query = {}

    if stub is not None:
      query['s'] = stub

    try:
      r = urllib2.Request('%s/api/repositories.json?%s' % ( self._urlbase, urllib.urlencode(query) ))
      u = self._opener.open(r)

      repo_summary = json.loads( u.read() )

      if len( repo_summary ):
        query = {}
        if arch is not None:
          query['a'] = arch

        if version is not None:
          query['v'] = version

        if url is not None:
          query['u'] = url

        r = urllib2.Request('%s/api/repository/%d.json?%s' % ( self._urlbase, repo_summary[0]['id'], urllib.urlencode(query) ))
        u = self._opener.open(r)

        repo = Repository()
        repo.fromObject( json.loads( u.read() ) )

        return repo

    except urllib2.URLError, e:
      print e
    except urllib2.HTTPError, e:
      print e

    return None


  def repository_create(self, repo):

    if not isinstance(repo, Repository):
      TypeError('repo is not of type Repository')

    try:
      r = urllib2.Request('%s/api/repositories.json' % ( self._urlbase ), repo.toJSON())
      u = self._opener.open(r)
      print u.read()

      repo = Repository()
      repo.fromObject( json.loads( u.read() ) )

      return repo

    except urllib2.URLError, e:
      print e
    except urllib2.HTTPError, e:
      print e

    return None


  def package_create(self, package):

    if not isinstance(package, Package):
      TypeError('package is not of type Package')

    try:
      r = urllib2.Request('%s/api/packages.json' % ( self._urlbase ), package.toJSON())
      u = self._opener.open(r)
      print u.read()

      return True

    except urllib2.URLError, e:
      print e
    except urllib2.HTTPError, e:
      print e


