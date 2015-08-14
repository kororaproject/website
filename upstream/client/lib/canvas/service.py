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
import http.cookiejar
import json
import urllib.request, urllib.parse, urllib.error

from canvas.template import Template

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

    auth = json.dumps({'u':username, 'p':password}, separators=(',',':')).encode('utf-8')

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


  def template_delete(self, template):
    if not isinstance(template, Template):
      TypeError('template is not of type Template')

    try:
      print(template)

      r = urllib.request.Request('%s/api/template/%d.json' % ( self._urlbase, template.id ))
      r.get_method = lambda: 'DELETE'
      u = self._opener.open(r)
      o = json.loads( u.read().decode('utf-8') )

      return True

    except urllib.error.URLError as e:
      print(e)
    except urllib.error.HTTPError as e:
      print(e)

    return False


  def template_update(self, template):
    if not isinstance(template, Template):
      TypeError('template is not of type Template')

    try:
      r = urllib.request.Request('%s/api/template/%d.json' % (self._urlbase, template.id), template.toJSON().encode('utf-8'))
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

    query = {'user': template.user, 'name': template.name}

    try:
      r = urllib.request.Request('%s/api/templates.json?%s' % (self._urlbase, urllib.parse.urlencode(query)))
      u = self._opener.open(r)

      template_summary = json.loads( u.read().decode('utf-8') )

      if len(template_summary):
        # we only have one returned since template names are unique per account
        r = urllib.request.Request('%s/api/template/%s.json' % (self._urlbase, template_summary[0]['id']))
        u = self._opener.open(r)
        data = json.loads(u.read().decode('utf-8'))

        return Template(template=data)

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

      return json.loads(u.read().decode('utf-8'))

    except urllib.error.URLError as e:
      print(e)
    except urllib.error.HTTPError as e:
      print(e)

    return []

  def template_remove(self, template):
    if not isinstance(template, Template):
      TypeError('template is not of type Template')


