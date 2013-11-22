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
__PACKAGE__->columns(All => qw/id author parent_id password type status name title excerpt content reply_status reply_count created updated/);

__PACKAGE__->has_a( parent_id => __PACKAGE__ );
__PACKAGE__->has_a( author => 'Canvas::Store::User' );


#
# IDEAS
__PACKAGE__->add_constructor( forum_name => qq{ post_type='forum' AND post_name=? } );

__PACKAGE__->add_constructor( ideas => qq{ type='idea' AND parent=? ORDER BY name } );
__PACKAGE__->add_constructor( questions => qq{ type='question' AND parent=? ORDER BY name } );
__PACKAGE__->add_constructor( problems => qq{ type='problem' AND parent=? ORDER BY name } );
__PACKAGE__->add_constructor( thanks => qq{ type='thank' AND parent=? ORDER BY name } );

#
# TOPICS
__PACKAGE__->add_constructor( topic_name => qq{ post_type='topic' AND post_name=? } );
__PACKAGE__->add_constructor( topics_newest => qq{ post_type='topic' AND post_parent=? ORDER BY post_modified_gmt DESC,post_name } );
__PACKAGE__->add_constructor( topics => qq{ post_type='topic' AND post_parent=? ORDER BY post_date_gmt DESC,post_name } );


#
# STREAM
__PACKAGE__->add_constructor( replies => qq{ name=? AND parent_id != 0 ORDER BY created ASC } );

sub freshness {
  my $self = shift;

  # post_parent=? ORDER BY post_modified_gmt DESC LIMIT 1
}

#
# DATETIME FIELDS
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
  SET updated=NOW(), %s
   WHERE  __IDENTIFIER__
});

1;

