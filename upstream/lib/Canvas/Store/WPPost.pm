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
package Canvas::Store::WPPost;

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
__PACKAGE__->table('kwp_posts');
__PACKAGE__->columns(All => qw/ID post_author post_date post_date_gmt post_content post_title post_excerpt post_status comment_status ping_status post_password post_name to_ping pinged post_modified post_modified_gmt post_content_filtered post_parent guid menu_order post_type post_mime_type comment_count/);


__PACKAGE__->has_a( post_parent => __PACKAGE__ );
__PACKAGE__->has_a( post_author => 'Canvas::Store::WPUser' );


__PACKAGE__->has_a(
  post_date_gmt => 'Time::Piece',
  inflate => sub { my $t = shift; ( $t eq "0000-00-00 00:00:00" ) ? gmtime(0) : Time::Piece->strptime($t, "%Y-%m-%d %H:%M:%S") },
  deflate => sub { shift->strftime("%Y-%m-%d %H:%M:%S") }
);
__PACKAGE__->has_a(
  post_modified_gmt => 'Time::Piece',
  inflate => sub { my $t = shift; ( $t eq "0000-00-00 00:00:00" ) ? gmtime(0) : Time::Piece->strptime($t, "%Y-%m-%d %H:%M:%S") },
  deflate => sub { shift->strftime("%Y-%m-%d %H:%M:%S") }
);

#
# FORUMS
__PACKAGE__->add_constructor( forum_name => qq{ post_type='forum' AND post_name=? } );

__PACKAGE__->add_constructor( forums => qq{ post_type='forum' AND post_parent=? ORDER BY menu_order,post_name } );

#
# TOPICS
__PACKAGE__->add_constructor( topic_name => qq{ post_type='topic' AND post_name=? } );
__PACKAGE__->add_constructor( topics_newest => qq{ post_type='topic' AND post_parent=? ORDER BY post_modified_gmt DESC,post_name } );
__PACKAGE__->add_constructor( topics => qq{ post_type='topic' AND post_parent=? ORDER BY post_date_gmt DESC,post_name } );


#
# REPLIES
__PACKAGE__->add_constructor( replies => qq{ post_type='reply' AND post_parent=? ORDER BY post_date_gmt } );

sub freshness {
  my $self = shift;

  # post_parent=? ORDER BY post_modified_gmt DESC LIMIT 1
}
1;

