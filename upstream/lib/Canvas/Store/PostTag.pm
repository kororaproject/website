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
package Canvas::Store::PostTag;

use strict;
use base 'Canvas::Store';

#
# CONSTANTS
#
use constant {
  # bit 7: 0 = not pinned, 1 = pinned
  ACTION_PINNED     => 128,

  # bit 1: 0 = removed, 1 = installed
  ACTION_INSTALLED  =>   1,
};

#
# TABLE DEFINITION
#
__PACKAGE__->table('canvas_post_tag');
__PACKAGE__->columns(Primary => qw/post_id tag_id/);
__PACKAGE__->columns(Essential => qw/created/);

#
# 1:N MAPPINGS
#
__PACKAGE__->has_a(post_id  => 'Canvas::Store::Post');
__PACKAGE__->has_a(tag_id   => 'Canvas::Store::Tag');

#
# EXTENDED ATTRIBUTES
#

sub is_pinned {
  my $action = shift->action;

  return( $action & ACTION_PINNED )
}

#
# is_installed()
#
# is the package explicitly installed by the template
#
sub is_installed {
  my $action = shift->action;

  return( $action & ACTION_INSTALLED )
}

#
# is_removed()
#
# is the package explicitly removed by the template
#
sub is_removed {
  return not shift->is_installed;
}

1;
