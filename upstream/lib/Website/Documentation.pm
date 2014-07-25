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
package Website::Documentation;

use warnings;
use strict;

#
# PERL INCLUDES
#
use Data::Dumper;
use Mojo::Base 'Mojolicious::Controller';
use POSIX qw(ceil);
use Time::Piece;

#
# LOCAL INCLUDES
#
use Canvas::Store::Post;
use Canvas::Store::Pager;

#
# CONSTANTS
#

use constant POST_STATUS_MAP => (
  [ 'In Draft'  => 'draft' ],
  [ 'Review'    => 'review'  ],
  [ 'Published' => 'publish' ],
);


#
# HELPERS
#

sub _tree {
  my $t    = shift;
  my $p_id = shift // 0;
  my $depth = shift // 0;

  my( @docs ) = Canvas::Store::Post->search({
    type      => 'document',
    parent_id => $p_id,
  });

  foreach my $d ( sort { $a->menu_order <=> $b->menu_order } @docs ) {
    push @{ $t }, {
      data => $d,
      depth => $depth
    };
    _tree( $t, $d->id, $depth+1 );
  }
}


sub rebuild_index() {
  my $documents = [];

  # recursively rebuild the doc index
  _tree( $documents );

  # update documenation metadata
  my $order = 0;
  Canvas::Store->do_transaction(sub {
    for my $d ( @{ $documents } ) {
      $order++;

      my $do = Canvas::Store::PostMeta->find_or_create({
        post_id     => $d->{data}->id,
        meta_key    => 'hierarchy_order',
      });
      $do->meta_value( $order );
      $do->update;

      my $dd = Canvas::Store::PostMeta->find_or_create({
        post_id     => $d->{data}->id,
        meta_key    => 'hierarchy_depth',
      });
      $dd->meta_value( $d->{depth} );
      $dd->update;
    }
  });
}

sub sanitise_with_dashes($) {
  my $stub = shift;

  # preserve escaped octets
  $stub =~ s|%([a-fA-F0-9][a-fA-F0-9])|---$1---|g;
  # remove percent signs that are not part of an octet
  $stub =~ s/%//g;
  # restore octets.
  $stub =~ s|---([a-fA-F0-9][a-fA-F0-9])---|%$1|g;

  $stub = lc $stub;

  # kill entities
  $stub =~ s/&.+?;//g;
  $stub =~ s/\./-/g;

  $stub =~ s/[^%a-z0-9 _-]//g;
  $stub =~ s/\s+/-/g;
  $stub =~ s|-+|-|g;
  $stub =~ s/-+$//g;

  return $stub;
}

sub list_parents_for_post {
  my $selected = shift;

  my $parents = [];

  push @{ $parents }, [ ( defined $selected && $selected == 0 ) ?
    ( "None", 0, 'selected', 'selected' ) :
    ( "None", 0, )
  ];

  my $documents = Canvas::Store::Post->documentation_index;
  foreach my $d ( @{ $documents } ) {
    my $title = ( "-" x $d->{depth} ) . " " . $d->{title};
    push @{ $parents }, [ ( defined $selected && $selected == $d->{id} ) ?
      ( $title, $d->{id}, 'selected', 'selected' ) :
      ( $title, $d->{id} )
    ]
  }

  return $parents;
}

sub list_status_for_post {
  my $selected = shift;

  my $status = [];

  foreach my $s ( POST_STATUS_MAP ) {
    push @$status, [ ( defined $selected && grep { m/$selected/ } @$s) ?
      ( @$s, 'selected', 'selected' ) :
      ( @$s )
    ]
  }

  return $status;
}


#
# DOCUMENTATION
#

sub index_get {
  my $self = shift;

  my $documents = Canvas::Store::Post->documentation_index;

  $self->stash( documents => $documents );

  $self->render('website/document');
}


sub document_detail_get {
  my $self = shift;
  my $stub = $self->param('id');

  my $p = Canvas::Store::Post->search({ name => $stub, type => 'document' })->first;

  # check we found the post
  return $self->redirect_to('supportdocumentation') unless $self->document_can_view( $p );

  $self->stash( document => $p );

  $self->render('website/document-detail');
}

sub document_add_get {
  my $self = shift;

  # only allow authenticated and authorised users
  return $self->redirect_to('/') unless $self->document_can_add;

  $self->stash(
    statuses  => list_status_for_post( 'draft' ),
    parents  => list_parents_for_post( 0 ),
  );
  $self->render('website/document-new');
}

sub document_edit_get {
  my $self = shift;

  my $stub = $self->param('id');

  my $p = Canvas::Store::Post->search({ name => $stub, type => 'document' })->first;

  # only allow those who are authorised to edit posts
  return $self->redirect_to('supportdocumentation') unless $self->document_can_edit( $p );

  $self->stash(
    document => $p,
    statuses => list_status_for_post( $p->status ),
    parents  => list_parents_for_post( $p->parent_id ),
  );

  $self->render('website/document-edit');
}

sub document_add_post {
  my $self = shift;

  # ensure we can add pages
  unless( $self->document_can_add ) {
    return $self->redirect_to( 'supportdocumentation' );
  }

  my $stub = sanitise_with_dashes( $self->param('title') );

  # enforce max stub size
  $stub = substr $stub, 0, 128 if length( $stub ) > 128;

  my( @e ) = Canvas::Store::Post->search({ type => 'document', name => $stub });

  # check for existing stubs and append the ID + 1 of the last
  $stub .= '-' . ( $e[-1]->id + 1 ) if @e;

  my $now = gmtime;

  my $p = Canvas::Store::Post->create({
    name       => $stub,
    type       => 'document',
    menu_order => $self->param('order'),
    status     => $self->param('status'),
    title      => $self->param('title'),
    excerpt    => $self->param('excerpt'),
    content    => $self->param('content'),
    parent_id  => $self->param('parent'),
    author_id  => $self->auth_user->id,
    created    => $now,
    updated    => $now,
  });

  rebuild_index();

  $self->redirect_to( 'supportdocumentationid', id => $stub );
}

sub document_edit_post {
  my $self = shift;

  my $stub = $self->param('id');

  # find the post
  my $p = Canvas::Store::Post->search({ name => $stub, type => 'document' })->first;

  # ensure we can edit
  unless( $self->document_can_edit( $p ) ) {
    return $self->redirect_to( 'supportdocumentation' );
  }

  # update the fields
  $p->title( $self->param('title') );
  $p->content( $self->param('content') );
  $p->excerpt( $self->param('excerpt') );
  $p->status( $self->param('status') );
  $p->parent_id( $self->param('parent') );
  $p->menu_order( $self->param('order') );

  # update author if changed
  if( $self->param('author') ne $p->author_id->username ) {
    my $u = Canvas::Store::User->search({ username => $self->param('author') } )->first;

    if( $u ) {
      $p->author_id( $u->id );
    }
  }

  # update created if changed
  my $t = Time::Piece->strptime( $self->param('created'), "%d/%m/%Y %H:%M:%S" );

  if( $t ne $p->created ) {
    $p->created( $t );
  }

  # commit the updates
  $p->update;

  rebuild_index();

  $self->redirect_to( 'supportdocumentationid', id => $stub );
}

sub document_delete_any {
  my $self = shift;

  my $stub = $self->param('id');

  my $p = Canvas::Store::Post->search({ name => $stub, type => 'document' })->first;

  # only allow authenticated users
  return $self->redirect_to('supportdocumentation') unless $self->document_can_delete( $p );

  # check we found the post
  if( $self->document_can_delete( $p ) ) {
    $p->delete;
  }

  $self->redirect_to('supportdocumentation');
}

sub document_admin_get {
  my $self = shift;

  # only allow authenticated and authorised users
  return $self->redirect_to('supportdocumentation') unless (
    $self->document_can_add ||
    $self->document_can_delete
  );

  my $pager = Canvas::Store::Post->pager(
    where             => { type => 'document' },
    order_by          => 'menu_order, title',
    entries_per_page  => 20,
    current_page      => ( $self->param('page') // 1 ) - 1,
  );

  my $documents = {
    items       => [ $pager->search_where ],
    item_count  => $pager->total_entries,
    page_size   => $pager->entries_per_page,
    page        => $pager->current_page + 1,
    page_last   => ceil($pager->total_entries / $pager->entries_per_page),
  };

  $self->stash( documents => $documents );

  $self->render('website/document-admin');
}


1;
