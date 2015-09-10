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
import codecs
import getpass
import hmac
import http.cookiejar
import json
import urllib.request, urllib.parse, urllib.error

from canvas.template import Machine, Template

class ServiceException(Exception):
  def __init__(self, reason, code=0):
    self.reason = reason.lower()
    self.code = code

  def __repr__(self):
    return str(self)

  def __str__(self):
    return 'error: {0}'.format(str(self.reason))


class Service(object):
  def __init__(self, host='https://canvas.kororaproject.org', username=None):
    self._host = host
    self._urlbase = host

    self._username = username

    self._cookiejar = http.cookiejar.CookieJar()
    self._opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(self._cookiejar))

    self._authenticated = False

  def authenticate(self, username=None, password=None, prompt=None, force=False):
    #print('debug: authenticating to {0}'.format(self._urlbase))

    if self._authenticated and not force:
      return self._authenticated

    # set default user
    if username is None:
      username = self._username

    if password is None:
      if prompt is None:
        prompt = 'Password ({0}): '.format(username)

      password = getpass.getpass(prompt)

    auth = json.dumps({'u':username, 'p':password}, separators=(',',':')).encode('utf-8')

    self._authenticated = False

    try:
      r = urllib.request.Request('{0}/authenticate.json'.format(self._urlbase), auth)
      u = self._opener.open(r)

      self._authenticated = True
      return self._authenticated

    except urllib.error.URLError as e:
      pass
    except urllib.error.HTTPError as e:
      pass

    raise ServiceException('unable to authenticate')

  def deauthenticate(self, username='', password='', force=False):
    if not self._authenticated and not self._force:
      return self._authenticated

    try:
      r = urllib.request.Request('%s/deauthenticate.json' % (self._urlbase))
      u = self._opener.open(r)

    except urllib.error.URLError as e:
      print(e)
    except urllib.error.HTTPError as e:
      print(e)

    #
    self._authenticated = False

    return self._authenticated

  #
  # MACHINE METHODS
  def machine_create(self, machine):
    if not isinstance(machine, Machine):
      TypeError('machine is not of type Machine')

    # always auth
    self.authenticate()

    try:
      r = urllib.request.Request('{0}/api/machines.json'.format(self._urlbase), machine.to_json().encode('utf-8'))
      u = self._opener.open(r)
      res = json.loads(u.read().decode('utf-8'))

      return res

    except urllib.error.URLError as e:
      res = json.loads(e.fp.read().decode('utf-8'))
      raise ServiceException('{0}'.format(res.get('error', 'unknown')))

    except urllib.error.HTTPError as e:
      print(e.fp.read())
      raise ServiceException('unknown service response')

    raise ServiceException('unable to add machine.')

  def machine_delete(self, machine):
    if not isinstance(machine, Machine):
      TypeError('machine is not of type Machine')

    query = {'user': machine.user, 'name': machine.name}

    # always auth
    self.authenticate()

    try:
      r = urllib.request.Request('{0}/api/machines.json?{1}'.format(self._urlbase, urllib.parse.urlencode(query)))
      u = self._opener.open(r)

      machine_summary = json.loads(u.read().decode('utf-8'))

      if len(machine_summary):
        r = urllib.request.Request('{0}/api/machine/{1}.json'.format(self._urlbase, machine_summary[0]['uuid']))
        r.get_method = lambda: 'DELETE'
        u = self._opener.open(r)
        res = json.loads(u.read().decode('utf-8'))

        return res

    except urllib.error.URLError as e:
      res = json.loads(e.fp.read().decode('utf-8'))
      raise ServiceException('{0}'.format(res.get('error', 'unknown')))

    except urllib.error.HTTPError as e:
      print(e)
      raise ServiceException('unknown service response')

    raise ServiceException('unable to delete machine.')

  def machine_get(self, machine):
    if not isinstance(machine, Machine):
      TypeError('machine is not of type Machine')

    query = {'user': machine.user, 'name': machine.name}
    r = urllib.request.Request('{0}/api/machines.json?{1}'.format(self._urlbase, urllib.parse.urlencode(query)))

    try:
      u = self._opener.open(r)
      machine_summary = json.loads(u.read().decode('utf-8'))

      # nothing returned, so authenticate and retry
      if len(machine_summary) == 0 and not self._authenticated:
        self.authenticate()

        u = self._opener.open(r)
        machine_summary = json.loads(u.read().decode('utf-8'))

      if len(machine_summary):
        # we only have one returned since machine names are unique per account
        r = urllib.request.Request('{0}/api/machine/{1}.json'.format(self._urlbase, machine_summary[0]['uuid']))
        u = self._opener.open(r)
        data = json.loads(u.read().decode('utf-8'))

        return Machine(machine=data)

      raise ServiceException('unable to get machine')

    except urllib.error.URLError as e:
      res = json.loads(e.fp.read().decode('utf-8'))
      raise ServiceException('{0}'.format(res.get('error', 'unknown')))

    except urllib.error.HTTPError as e:
      print(e)
      raise ServiceException('unknown service response')

  def machine_list(self, user=None, name=None, description=None):
    params = {
      'user': user,
      'name': name,
      'description': description
    }

    params = urllib.parse.urlencode({k: v for k, v in params.items() if v != None})

    # always auth
    self.authenticate()

    try:
      r = urllib.request.Request('{0}/api/machines.json?{1}'.format(self._urlbase, params))
      u = self._opener.open(r)

      res = json.loads(u.read().decode('utf-8'))

      return res

    except urllib.error.URLError as e:
      res = json.loads(e.fp.read().decode('utf-8'))
      raise ServiceException('{0}'.format(res.get('error', 'unknown')))

    except urllib.error.HTTPError as e:
      print(e)
      raise ServiceException('unknown service response')

    return []

  def machine_sync(self, uuid=None, key=None, data=None):
    # generate nonce and hmac with
    nonce = 'foo'

    m = nonce + uuid
    h = hmac.new(codecs.decode(key, 'hex'), msg=m.encode('utf-8'), digestmod='sha512')


    try:
      r = urllib.request.Request('{0}/api/machine/{1}/sync.json'.format(self._urlbase, uuid))
      r.add_header('x-canvas-nonce', nonce)
      r.add_header('x-canvas-uuid', uuid)
      r.add_header('x-canvas-hash', h.hexdigest())
      u = self._opener.open(r)
      res = json.loads(u.read().decode('utf-8'))

      return res

    except urllib.error.URLError as e:
      res = json.loads(e.fp.read().decode('utf-8'))
      raise ServiceException('{0}'.format(res.get('error', 'unknown')))

    except urllib.error.HTTPError as e:
      print(e)
      raise ServiceException('unknown service response')

    raise ServiceException('unable to update machine.')

  def machine_update(self, machine):
    if not isinstance(machine, Machine):
      TypeError('machine is not of type Machine')

    # always auth
    self.authenticate()

    try:
      r = urllib.request.Request('{0}/api/machine/{1}.json'.format(self._urlbase, machine.uuid), machine.to_json().encode('utf-8'))
      r.get_method = lambda: 'PUT'
      u = self._opener.open(r)
      res = json.loads(u.read().decode('utf-8'))

      return res

    except urllib.error.URLError as e:
      res = json.loads(e.fp.read().decode('utf-8'))
      raise ServiceException('{0}'.format(res.get('error', 'unknown')))

    except urllib.error.HTTPError as e:
      print(e)
      raise ServiceException('unknown service response')

    raise ServiceException('unable to update machine.')

  #
  # TEMPLATE METHODS
  def template_create(self, template):
    if not isinstance(template, Template):
      TypeError('template is not of type Template')

    if not self.authenticate():
      raise ServiceException('unable to authenticate')

    try:
      r = urllib.request.Request('{0}/api/templates.json'.format(self._urlbase), template.to_json().encode('utf-8'))
      u = self._opener.open(r)
      res = json.loads(u.read().decode('utf-8'))

      return res

    except urllib.error.URLError as e:
      res = json.loads(e.fp.read().decode('utf-8'))
      raise ServiceException('{0}'.format(res.get('error', 'unknown')))

    except urllib.error.HTTPError as e:
      print(e.fp.read())
      raise ServiceException('unknown service response')

    raise ServiceException('unable to add template.')

  def template_delete(self, template):
    if not isinstance(template, Template):
      TypeError('template is not of type Template')

    query = {'user': template.user, 'name': template.name}

    try:
      r = urllib.request.Request('%s/api/templates.json?%s' % (self._urlbase, urllib.parse.urlencode(query)))
      u = self._opener.open(r)

      template_summary = json.loads(u.read().decode('utf-8'))

      if len(template_summary):
        r = urllib.request.Request('%s/api/template/%s.json' % (self._urlbase, template_summary[0]['id']))
        r.get_method = lambda: 'DELETE'
        u = self._opener.open(r)
        res = json.loads(u.read().decode('utf-8'))

        return res

    except urllib.error.URLError as e:
      res = json.loads(e.fp.read().decode('utf-8'))
      raise ServiceException('{0}'.format(res.get('error', 'unknown')))

    except urllib.error.HTTPError as e:
      print(e)
      raise ServiceException('unknown service response')

    raise ServiceException('unable to delete template.')

  def template_get(self, template, auth=False):
    if not isinstance(template, Template):
      TypeError('template is not of type Template')

    # check of force auth
    if auth:
      self.authenticate()

    query = {'user': template.user, 'name': template.name}

    r = urllib.request.Request('%s/api/templates.json?%s' % (self._urlbase, urllib.parse.urlencode(query)))

    try:
      u = self._opener.open(r)
      template_summary = json.loads(u.read().decode('utf-8'))

      # nothing returned, so authenticate and retry
      if len(template_summary) == 0 and not self._authenticated:
        self.authenticate()

        u = self._opener.open(r)
        template_summary = json.loads(u.read().decode('utf-8'))

      if len(template_summary):
        # we only have one returned since template names are unique per account
        r = urllib.request.Request('{0}/api/template/{1}.json'.format(self._urlbase,
          template_summary[0]['uuid']))
        u = self._opener.open(r)
        data = json.loads(u.read().decode('utf-8'))

        return Template(template=data)

      raise ServiceException('unable to get template')

    except urllib.error.URLError as e:
      res = json.loads(e.fp.read().decode('utf-8'))
      raise ServiceException('{0}'.format(res.get('error', 'unknown')))

    except urllib.error.HTTPError as e:
      print(e)
      raise ServiceException('unknown service response')

  def template_list(self, user=None, name=None, description=None):
    params = {
      'user': user,
      'name': name,
      'description': description
    }

    params = urllib.parse.urlencode({k: v for k, v in params.items() if v != None})
    print(params)

    try:
      r = urllib.request.Request('{0}/api/templates.json?{1}'.format(self._urlbase, params))
      u = self._opener.open(r)

      res = json.loads(u.read().decode('utf-8'))

      return res

    except urllib.error.URLError as e:
      res = json.loads(e.fp.read().decode('utf-8'))
      raise ServiceException('{0}'.format(res.get('error', 'unknown')))

    except urllib.error.HTTPError as e:
      print(e)
      raise ServiceException('unknown service response')

    return []

  def template_update(self, template):
    if not isinstance(template, Template):
      TypeError('template is not of type Template')

    if not self.authenticate():
      raise ServiceException('unable to authenticate')

    try:
      r = urllib.request.Request('{0}/api/template/{1}.json'.format(self._urlbase, template.uuid), template.to_json().encode('utf-8'))
      r.get_method = lambda: 'PUT'
      u = self._opener.open(r)
      res = json.loads(u.read().decode('utf-8'))

      return res

    except urllib.error.URLError as e:
      res = json.loads(e.fp.read().decode('utf-8'))
      raise ServiceException('{0}'.format(res.get('error', 'unknown')))

    except urllib.error.HTTPError as e:
      print(e)
      raise ServiceException('unknown service response')

    raise ServiceException('unable to update template.')
