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
package Canvas::Store::Post;

use strict;
use base 'Canvas::Store';

#
# PERL INCLUDES
#
use Digest::MD5 qw(md5);
use Data::Dumper;

#
# MODEL DEFINITION
#
__PACKAGE__->table('canvas_post');
__PACKAGE__->columns(All => qw/id author_id parent_id password type status name title excerpt content reply_status reply_count created updated/);

#
# 1:N MAPPINGS
#
__PACKAGE__->has_a( parent_id => __PACKAGE__ );
__PACKAGE__->has_a( author_id => 'Canvas::Store::User' );

#
# N:N MAPPINGS
#
__PACKAGE__->has_many(post_tags => 'Canvas::Store::PostTag' => 'post_id');
__PACKAGE__->has_many(tags => [ 'Canvas::Store::PostTag' => 'tag_id' ] );

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
# DECORATORS
#

# GROUPS (ideas, questions, problems and thanks)
__PACKAGE__->add_constructor( ideas => qq{ type='idea' AND parent=? ORDER BY name } );
__PACKAGE__->add_constructor( questions => qq{ type='question' AND parent=? ORDER BY name } );
__PACKAGE__->add_constructor( problems => qq{ type='problem' AND parent=? ORDER BY name } );
__PACKAGE__->add_constructor( thanks => qq{ type='thank' AND parent=? ORDER BY name } );

# REPLY STREAM
__PACKAGE__->add_constructor( replies => qq{ name=? AND parent_id != 0 ORDER BY created ASC } );

#
# UPDATE HELPER
#

sub tag_list {
  return join ', ', map { $_->name } shift->tags;
}

sub tag_list_array {
  return map { $_->name } shift->tags;
}

#
# UPDATE HELPER
#
__PACKAGE__->set_sql(update => qq{
 UPDATE __TABLE__
  SET updated=UTC_TIMESTAMP(), %s
   WHERE  __IDENTIFIER__
});

1;

