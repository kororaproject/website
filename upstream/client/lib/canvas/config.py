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

import configparser
import os

class Config(object):
  def __init__(self):
    self.config = configparser.ConfigParser()

    # look for local user config
    self.home_config_path = os.path.join(os.path.expanduser('~'), '.config', 'canvas.conf')
    if os.path.exists(self.home_config_path):
      self.config.read(self.home_config_path)

    # also check for system config
    elif os.path.exists("/etc/canvas/canvas.conf"):
      self.config.read("/etc/canvas/canvas.conf")

  def __repr__(self):
    print(self.config)

  def __str__(self):
    print(self.config)

  def get(self, section, key, default=None):
    if not section in self.config.sections():
      return default

    return self.config[section].get(key, default)

  def save(self):
    # always write to local config
    with open(self.home_config_path, 'w+') as configfile:
      self.config.write(configfile)

  def sections(self):
    return self.config.sections()

  def set(self, section, key, value):
    if not section in self.config.sections():
      self.config[section] = {}

    self.config[section][key] = value

  def unset(self, section, key):
    if not section in self.config.sections():
      return False

    return self.config.remove_option(section, key)
