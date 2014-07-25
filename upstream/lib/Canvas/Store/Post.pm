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
package Canvas::Store::Post;

use strict;
use base 'Canvas::Store';

#
# PERL INCLUDES
#
use Data::Dumper;
use Digest::MD5 qw(md5);
use POSIX qw(ceil);
use Sort::Versions qw(versioncmp);

#
# MODEL DEFINITION
#
__PACKAGE__->table('canvas_post');
__PACKAGE__->columns(All => qw/id author_id parent_id password type status name title excerpt content reply_status reply_count menu_order created updated/);

#
# 1:N MAPPINGS
#
__PACKAGE__->has_a( parent_id => __PACKAGE__ );
__PACKAGE__->has_a( author_id => 'Canvas::Store::User' );

#
# N:N MAPPINGS
#
__PACKAGE__->has_many(post_tags => 'Canvas::Store::PostTag'   => 'post_id');
__PACKAGE__->has_many(tags      => [ 'Canvas::Store::PostTag' => 'tag_id' ] );
__PACKAGE__->has_many(meta      => 'Canvas::Store::PostMeta'  => 'post_id');

__PACKAGE__->has_many(children  => [__PACKAGE__, 'parent_id']);

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
# REPLY HELPERS
#
sub latest_reply {
  my $self = shift;

  my $dbh = $self->db_Main();
  my $sth = $dbh->prepare_cached("SELECT * FROM canvas_post WHERE parent_id=? ORDER BY created DESC");

  $sth->execute( $self->id );
  my( $reply ) = $self->sth_to_objects($sth);

  return $reply if defined $reply;

  return $self;
}

sub accepted_reply {
  my $self = shift;

  my $dbh = $self->db_Main();
  my $sth = $dbh->prepare_cached("SELECT * FROM canvas_post WHERE parent_id=? AND status='accepted'");

  $sth->execute( $self->id );
  my( $reply ) = $self->sth_to_objects($sth);

  return $reply;
}

sub search_replies {
  my $self = shift;
  my %params = @_ > 1 ? @_ : ref $_[0] eq 'HASH' ? %{ $_[0] } : ();

  my $dbh = $self->db_Main();

  # reply order
  my $order = ( $params{order} // '' ) eq 'newest' ? 'DESC' : 'ASC';

  # pagination
  my $page_size = $params{page_size}  //= 5;
  my $page      = $params{page}       //= 1;
  $page = 1 if $page < 1;

  my $offset = ( $page_size * ( $page - 1 ) );

  my $count_sql = sprintf "SELECT COUNT(id) FROM canvas_post WHERE parent_id=? ORDER BY created DESC";

  my $sql = sprintf "SELECT * FROM canvas_post WHERE parent_id=? ORDER BY created %s LIMIT %d OFFSET %d", $order, $page_size, $offset;

  # fetch the item count
  my $sth = $dbh->prepare_cached($count_sql);
  $sth->execute( $self->id );
  my( $item_count ) = $sth->fetchrow_array;
  $sth->finish;

  # fetch the paginated items

  $sth = $dbh->prepare_cached($sql);
  $sth->execute( $self->id );
  my @results = $self->sth_to_objects($sth);

  return {
    items       => \@results,
    item_count  => $item_count,
    page_size   => $page_size,
    page        => $page,
    page_last   => ceil($item_count / $page_size),
  }
}

#
# TAG HELPERS
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
  my $page_size = $params{page_size}  //= 10;
  my $page      = $params{page}       //= 1;

  $page = 1 if $page < 1;

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
    my @tags = split /[ ,]+/, $params{tags};

    foreach my $t ( @tags ) {
      my $lt = $dbh->quote( '%' . $t . '%' );
      push @filter, '(p.title LIKE ' . $lt . ' OR p.content LIKE ' . $lt . ' OR t.name LIKE ' . $lt . ' OR r.content LIKE ' . $lt . ')';
    }
  }

  # build total count query
  my $raw_count_sql = 'SELECT COUNT(DISTINCT(p.id)) FROM canvas_post_tag pt LEFT JOIN canvas_post p ON (p.id=pt.post_id) LEFT JOIN canvas_tag t ON (t.id=pt.tag_id) LEFT JOIN canvas_post r ON (r.parent_id=p.id) WHERE (' . join( ') AND (', @filter ) . ')' ;

  # build paginated query
  my $raw_sql = 'SELECT p.id FROM canvas_post_tag pt LEFT JOIN canvas_post p ON (p.id=pt.post_id) LEFT JOIN canvas_tag t ON (t.id=pt.tag_id) LEFT JOIN canvas_post r ON (r.parent_id=p.id) WHERE (' . join( ') AND (', @filter ) . ') GROUP BY p.id ORDER BY p.updated DESC' ;

  $raw_sql .= ' LIMIT ' . $page_size . ' OFFSET ' . ( $page_size * ( $page - 1 ) );

  # fetch the total item count
  my $sth = $dbh->prepare_cached($raw_count_sql);
  $sth->execute;
  my( $item_count ) = $sth->fetchrow_array;
  $sth->finish;

  # fetch the paginated items
  $sth = $dbh->prepare_cached($raw_sql);
  $sth->execute;
  my @results = $self->sth_to_objects($sth);

  return {
    items       => \@results,
    item_count  => $item_count,
    page_size   => $page_size,
    page        => $page,
    page_last   => ceil($item_count / $page_size),
  }
}

#
# DOCUMENT HELPERS
#

sub documentation_index() {
  my $self = shift;
  my $dbh = $self->db_Main();

  # fetch the paginated items
  my $sth = $dbh->prepare_cached("SELECT ho.meta_value AS ho, hd.meta_value, parent_id, name, title, id FROM canvas_post JOIN canvas_postmeta AS ho ON (ho.post_id=canvas_post.id AND ho.meta_key='hierarchy_order') JOIN canvas_postmeta AS hd ON (hd.post_id=canvas_post.id AND hd.meta_key='hierarchy_depth') WHERE type='document' ORDER BY ho*1");
  $sth->execute;

  my $index = [];

  while( my $row = $sth->fetchrow_arrayref ) {
    push @{ $index }, {
      order  => $row->[0],
      depth  => $row->[1],
      parent => $row->[2],
      name   => $row->[3],
      title  => $row->[4],
      id     => $row->[5],
    };
  }
  $sth->finish;

  return $index;
}

#
# METADATA HELPERS
#
sub metadata_clear($$) {
  my( $self, $key ) = @_;

  my @meta = grep { $key eq $_->meta_key } $self->meta;

  return ( @meta ) ? $meta[0]->delete : undef;
}

sub metadata($$) {
  my( $self, $key ) = @_;

  my @meta = grep { $key eq $_->meta_key } $self->meta;

  return ( @meta ) ? $meta[0]->meta_value : undef;
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
