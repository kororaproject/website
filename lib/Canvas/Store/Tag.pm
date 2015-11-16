#
# Copyright (C) 2013-2014   Ian Firns   <firnsy@kororaproject.org>
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
package Canvas::Store::Tag;

use strict;
use base 'Canvas::Store';

#
# PERL INCLUDES
#
use Data::Dumper;

#
# MODEL DEFINITION
#
__PACKAGE__->table('canvas_tag');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/name created/);


#
# N:N MAPPINGS
#
__PACKAGE__->has_many(post_tags => 'Canvas::Store::PostTag' => 'tag_id');
__PACKAGE__->has_many(posts => [ 'Canvas::Store::PostTag' => 'post_id' ] );

#
# INFLATOR/DEFLATORS
#
__PACKAGE__->has_a(
  created => 'Time::Piece',
  inflate => sub { my $t = shift; ( $t eq "0000-00-00 00:00:00" ) ? gmtime(0) : Time::Piece->strptime($t, "%Y-%m-%d %H:%M:%S") },
  deflate => sub { shift->strftime("%Y-%m-%d %H:%M:%S") }
);

1;
