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
package Canvas::Store::Template;

use strict;
use base 'Canvas::Store';

#
# TABLE DEFINITION
#
__PACKAGE__->table('canvas_template');
__PACKAGE__->columns(All => qw/id user_id name description private parent_id created updated/);

#
# N:N MAPPINGS
#
__PACKAGE__->has_many(template_packages     => 'Canvas::Store::TemplatePackage'     => 'template_id');
__PACKAGE__->has_many(template_repositories => 'Canvas::Store::TemplateRepository'  => 'template_id');

#
# 1:N MAPPINGS
#
__PACKAGE__->has_a(user_id    => 'Canvas::Store::User');
__PACKAGE__->has_a(parent_id  => 'Canvas::Store::Template');

#
# INFLATOR/DEFLATORS
#
__PACKAGE__->has_a(
  created => 'Time::Piece',
  inflate => sub { my $t = shift; ( $t eq "0000-00-00 00:00:00" ) ? gmtime(0) : Time::Piece->strptime($t, "%Y-%m-%d %H:%M:%S") },
  deflate => sub { shift->strftime("%Y-%m-%d %H:%M:%S") }
);

__PACKAGE__->has_a(
  updated => 'Time::Piece',
  inflate => sub { my $t = shift; ( $t eq "0000-00-00 00:00:00" ) ? gmtime(0) : Time::Piece->strptime($t, "%Y-%m-%d %H:%M:%S") },
  deflate => sub { shift->strftime("%Y-%m-%d %H:%M:%S") }
);


#
# UPDATE HELPER
#
__PACKAGE__->set_sql(update => qq{
 UPDATE __TABLE__
  SET updated=UTC_TIMESTAMP(), %s
   WHERE  __IDENTIFIER__
});

1;
