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
use Data::Dumper;
use Digest::MD5 qw(md5);
use POSIX qw(floor);

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

sub search_type_status_and_tags {
  my $self = shift;
  my %params = @_ > 1 ? @_ : ref $_[0] eq 'HASH' ? %{ $_[0] } : ();

  my $dbh = $self->db_Main();

  # pagination
  my $items_per_page = $params{items_per_page}  //= 10;
  my $current_page   = $params{current_page}    //= 1;

  # filters
  my $type_filter    = '';
  my $status_filter  = '';
  my $tags_filter    = '';
  my @filter = ();

  # filter on type
  if( length $params{type} > 0 ) {
    push @filter, ' p.type IN (' . join(',', map { $dbh->quote( $_ )} @{ $params{type} }) . ')';
  }

  # filter on type
  if( length $params{status} > 0 ) {
    push @filter, ' p.status=' . $dbh->quote( $params{status} );
  }

  # filter on tags
  if( length $params{tags} > 0 ) {
    push @filter, 'pt.tag_id=t.id AND (t.name IN (' . join( ',', map { $dbh->quote( $_ ) } split(/[ ,]/, $params{tags})) . ')) AND p.id=pt.post_id';
  }

  # filter on full text
  if( length $params{text} > 0 ) {
    push @filter, 'p.title LIKE %% OR p.content LIKE %%';
  };

  # build total count query
  my $raw_count_sql = 'SELECT COUNT(DISTINCT(p.id)) FROM canvas_post_tag pt, canvas_post p, canvas_tag t WHERE (' . join( ') AND (', @filter ) . ')' ;

  # build paginated query
  my $raw_sql = 'SELECT p.id FROM canvas_post_tag pt, canvas_post p, canvas_tag t WHERE (' . join( ') AND (', @filter ) . ') GROUP BY p.id ORDER BY updated DESC' ;

  $raw_sql .= ' LIMIT ' . $items_per_page . ' OFFSET ' . ( $items_per_page * ( $current_page - 1 ) );

  # fetch the total item count
  my $sth = $dbh->prepare_cached($raw_count_sql);
  $sth->execute;
  my( $total_items ) = $sth->fetchrow_array;
  $sth->finish;

  # fetch the paginated items
  $sth = $dbh->prepare_cached($raw_sql);
  $sth->execute;
  my @results = $self->sth_to_objects($sth);

  return {
    items       => \@results,
    item_count  => $total_items,
    page_size   => $items_per_page,
    page        => $current_page,
    page_last   => floor($total_items / $items_per_page),
  }
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

