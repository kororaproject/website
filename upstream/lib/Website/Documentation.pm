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
use Mojo::Util qw(trim);
use POSIX qw(ceil);
use Time::Piece;

#
# LOCAL INCLUDES
#
#use Canvas::Store::Post;
#use Canvas::Store::Pager;

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

  foreach my $d ( sort { $a->menu_order <=> $b->menu_order or $a->title cmp $b->title } @docs ) {
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

sub index {
  my $c = shift;

  $c->render_steps('website/document', sub {
    my $delay = shift;

    # get paged items with username and email associated
    $c->pg->db->query("SELECT pm.meta_value::integer AS ho, hd.meta_value::integer AS depth, parent_id, name, title, id FROM canvas_post JOIN canvas_postmeta AS pm ON (pm.post_id=canvas_post.id AND pm.meta_key='hierarchy_order') JOIN canvas_postmeta AS hd ON (hd.post_id=canvas_post.id AND hd.meta_key='hierarchy_depth') WHERE type='document'  AND status='publish' ORDER BY ho" => $delay->begin);
  },
  sub {
    my ($delay, $err, $res) = @_;

    $c->stash(documents => $res->hashes);
  });
}


sub document_detail_get {
  my $c = shift;
  my $stub = $c->param('id');

  $c->render_steps('website/document-detail', sub {
    my $delay = shift;

    $c->pg->db->query("SELECT p.*, ARRAY_AGG(t.name) AS tags, u.username, u.email FROM canvas_post p JOIN canvas_user u ON (u.id=p.author_id) LEFT JOIN canvas_post_tag pt ON (pt.post_id=p.id) LEFT JOIN canvas_tag t ON (t.id=pt.tag_id) WHERE p.type='document' AND p.name=? GROUP BY p.id, u.username, u.email" => ($stub) => $delay->begin);
  }, sub {
    my ($delay, $err, $res) = @_;

    # check we found the post
    my $post = $res->hash;

    $delay->emit(redirect => 'supportdocumentation') unless $c->document->can_view($post);

    $c->stash(document => $post);
  });
}

sub document_add_get {
  my $c = shift;

  # only allow authenticated and authorised users
  return $c->redirect_to('/') unless $c->document->can_add;

  $c->stash(
    statuses  => list_status_for_post('draft'),
    parents  =>  $c->document->parents(0),
  );

  $c->render('website/document-new');
}

sub document_edit_get {
  my $c = shift;

  my $stub = $c->param('id');

  $c->render_steps('website/document-edit', sub {
    my $delay = shift;

    $c->pg->db->query("SELECT p.*, ARRAY_AGG(t.name) AS tags, u.username, u.email FROM canvas_post p JOIN canvas_user u ON (u.id=p.author_id) LEFT JOIN canvas_post_tag pt ON (pt.post_id=p.id) LEFT JOIN canvas_tag t ON (t.id=pt.tag_id) WHERE p.type='document' AND p.name=? GROUP BY p.id, u.username, u.email" => ($stub) => $delay->begin);
  }, sub {
    my ($delay, $err, $res) = @_;

    # check we found the post
    $delay->emit(redirect => 'supportdocumentation') unless $c->document->can_edit;

    my $d = $res->hash;
    $c->stash(
      document => $d,
      statuses => list_status_for_post($d->{status}),
      parents  => $c->document->parents($d->{parent_id}),
    );
  });
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

  my $tag_list  = trim $self->param('tags');
  my %tags = map  { $_ => 1 }
             grep { $_ }
             map  { sanitise_with_dashes( trim $_ ) } split /[ ,]+/, $tag_list;

  Canvas::Store->do_transaction( sub {
    # create the tags
    foreach my $tag ( keys %tags ) {
      $tag = trim $tag;
      my $t  = Canvas::Store::Tag->find_or_create({ name => $tag });
      my $pt = Canvas::Store::PostTag->find_or_create({
        post_id => $p->id,
        tag_id  => $t->id
      });
    }
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

  Canvas::Store->do_transaction( sub {
    $p->update;

    # find tags to add and remove
    my @tags_old = $p->tag_list_array;
    my @tags_new = map { sanitise_with_dashes( trim $_ ) } split /[ ,]+/, $self->param('tags');

    my %to = map { $_ => 1 } @tags_old;
    my %tn = map { $_ => 1 } @tags_new;

    # add tags
    foreach my $ta ( grep( ! defined $to{$_}, @tags_new ) ) {
      my $t  = Canvas::Store::Tag->find_or_create({ name => $ta });
      my $pt = Canvas::Store::PostTag->find_or_create({ post_id => $p->id, tag_id => $t->id })
    }

    # remove tags
    foreach my $td ( grep( ! defined $tn{$_}, @tags_old ) ) {
      my $t  = Canvas::Store::Tag->search({ name => $td })->first;
      Canvas::Store::PostTag->search({ post_id => $p->id, tag_id => $t->id })->first->delete;
    }
  });

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
  my $c = shift;

  # only allow authenticated and authorised users
  return $c->redirect_to('supportdocumentation') unless (
    $c->document->can_add || $c->document->can_delete
  );

  my $page_size = 20;
  my $page = ($c->param('page') // 1);

  $c->render_steps('website/document-admin', sub {
    my $delay = shift;

    # get total count
    $c->pg->db->query("SELECT COUNT(id) FROM canvas_post WHERE type='document'" => $delay->begin);

    # get paged items with username and email associated
    $c->pg->db->query("SELECT name, p.status, title, excerpt, TO_CHAR(p.created, 'DD/MM/YYYY') AS created, username, email, pm.meta_value::integer AS ho, hd.meta_value::integer AS depth FROM canvas_post p JOIN canvas_user u ON (u.id=p.author_id) JOIN canvas_postmeta AS pm ON (pm.post_id=p.id AND pm.meta_key='hierarchy_order') JOIN canvas_postmeta AS hd ON (hd.post_id=p.id AND hd.meta_key='hierarchy_depth') WHERE p.type='document' ORDER BY ho, p.title, p.created DESC LIMIT ? OFFSET ?" => ($page_size, ($page-1) * $page_size) => $delay->begin);
  },
  sub {
    my ($delay, $err, $count_res, $err_res, $res) = @_;

    my $count = $count_res->array->[0];

    $c->stash(documents => {
      items       => $res->hashes,
      item_count  => $count,
      page_size   => $page_size,
      page        => $page,
      page_last   => ceil($count / $page_size),
    });
  });
}


1;
