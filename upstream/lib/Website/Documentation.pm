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
  my $c    = shift;
  my $t    = shift;
  my $p_id = shift // 0;
  my $depth = shift // 0;

  my $docs = $c->pg->db->query("SELECT id, menu_order, title FROM canvas_post WHERE type='document' AND parent_id=?", $p_id)->hashes;

  foreach my $d (sort { $a->{menu_order} <=> $b->{menu_order} or $a->{title} cmp $b->{title} } @{$docs}) {
    push @{$t}, { data => $d, depth => $depth };
    _tree($c, $t, $d->{id}, $depth+1);
  }
}

sub rebuild_index {
  my $c    = shift;
  my $documents = [];

  # recursively rebuild the doc index
  _tree($c, $documents);

  # update documenation metadata
  {
    my $db = $c->pg->db;
    my $tx = $db->begin;
    my $order = 0;

    for my $d (@{$documents}) {
      $order++;

      # find hierarchy order
      my $ho = $db->query("SELECT meta_id FROM canvas_postmeta WHERE post_id=? AND meta_key='hierarchy_order'", $d->{data}{id})->hash;

      # create or update
      if ($ho) {
        $db->query("UPDATE canvas_postmeta SET meta_value=? WHERE post_id=?", $order, $ho->{meta_id});
      }
      else {
        $db->query("INSERT INTO canvas_postmeta (post_id, meta_key, meta_value) VALUES (?, 'hierarchy_order', ?)", $d->{data}{id}, $order);
      }

      # find hierarchy depth
      my $hd = $db->query("SELECT meta_id FROM canvas_postmeta WHERE post_id=? AND meta_key='hierarchy_depth'", $d->{data}{id})->hash;

      # create or update
      if ($hd) {
        $db->query("UPDATE canvas_postmeta SET meta_value=? WHERE meta_id=?", $d->{depth}, $hd->{meta_id});
      }
      else {
        $db->query("INSERT INTO canvas_postmeta (post_id, meta_key, meta_value) VALUES (?, 'hierarchy_depth', ?)", $d->{data}{id}, $hd->{depth});
      }
    }

    $tx->commit;
  }
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

sub document_post {
  my $c = shift;

  my $author    = $c->param('author');
  my $created   = $c->param('created');
  my $content   = $c->param('content');
  my $excerpt   = $c->param('excerpt');
  my $order     = $c->param('order');
  my $parent_id = $c->param('parent');
  my $status    = $c->param('status');
  my $stub      = $c->param('stub') // '';
  my $title     = $c->param('title');
  my $tag_list  = trim $c->param('tags');

  my $now = gmtime;

  # edit existing post
  if ($stub ne '' && $c->document->can_edit) {
    my $p = $c->pg->db->query("SELECT p.id, title, excerpt, content, TO_CHAR(p.created, 'YYYY-MM-DD HH24:MI:SS') AS created, author_id, username, email FROM canvas_post p JOIN canvas_user u ON (u.id=p.author_id) WHERE type='document' AND name=?", $stub)->hash;

    # update author if changed
    if ($author ne $p->{username}) {
      my $u = $c->pg->db->query("SELECT id, username WHERE username=?", $author)->hash;

      $p->{author_id} = $u->{id} if $u->{id};
    }

    # TODO: update created if changed
    #my $t = Time::Piece->strptime($created, '%d/%m/%Y %H:%M:%S');

    my $db = $c->pg->db;
    my $tx = $db->begin;

    my $r = $db->query("UPDATE canvas_post SET status=?, title=?, excerpt=?, content=?, author_id=?, parent_id=?, menu_order=?, created=?, updated=? WHERE type='document' AND name=?", $status, $title, $excerpt, $content, $p->{author_id}, $parent_id, $order, $created, $now, $stub);

    # update tags
    my $tt = $db->query("SELECT ARRAY_AGG(t.name) AS tags FROM canvas_post p LEFT JOIN canvas_post_tag pt ON (pt.post_id=p.id) LEFT JOIN canvas_tag t ON (t.id=pt.tag_id) WHERE p.id=? GROUP BY p.id", $p->{id})->hash;
    say Dumper "FOO", $tt;
    my @tags_old = $tt->{tags};
    my @tags_new = map { $c->sanitise_with_dashes($_) } split /[ ,]+/, $tag_list;

    my %to = map { $_ => 1 } @tags_old;
    my %tn = map { $_ => 1 } @tags_new;

    # add tags
    foreach my $ta ( grep( ! defined $to{$_}, @tags_new ) ) {
      # find or create tag
      my $t = $db->query("SELECT id FROM canvas_tag WHERE name=?", $ta)->hash;
      unless ($t) {
        $t = { id => $db->query("INSERT INTO canvas_tag (name) VALUES (?) RETURNING ID", $ta)->array->[0] };
      }

      # find or create post/tag reference
      my $pt = $db->query("SELECT * FROM canvas_post_tag WHERE post_id=? AND tag_id=?", $p->{id}, $t->{id})->hash;
      unless ($pt) {
        $db->query("INSERT INTO canvas_post_tag (post_id, tag_id) VALUES (?, ?)", $p->{id}, $t->{id});
      }
    }

    # remove tags
    foreach my $td ( grep( ! defined $tn{$_}, @tags_old ) ) {
      $db->query("DELETE FROM canvas_post_tag WHERE tag_id IN (SELECT id FROM canvas_tag WHERE name=?) AND post_id=?", $td, $p->{id});
    }

    $tx->commit;
  }
  # otherwise create a new entry
  elsif ($c->document->can_add) {
    my $stub = $c->sanitise_with_dashes($title);

    my $db = $c->pg->db;
    my $tx = $db->begin;

    # check for existing stubs and append the ID + 1 of the last
    my $e = $db->query("SELECT id FROM canvas_post WHERE type='document' AND name=? ORDER BY id DESC LIMIT 1", $stub)->array;
    $stub .= '-' . ($e->[0] + 1) if $e;

    $created = $now;

    my $post_id = $db->query("INSERT INTO canvas_post (type, name, status, title, excerpt, content, author_id, parent_id, menu_order, created, updated) VALUES ('document', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING ID", $stub, $status, $title, $excerpt, $content, 1, $parent_id, $order, $created, $now)->array->[0];

    # ensure we only insert sanitised and unique tags
    my %tags = map  { trim($_) => 1 }
                 grep { $_ }
                   map  { $c->sanitise_with_dashes($_) }
                     split /[ ,]+/, $tag_list;

    # create the tags
    foreach my $tag (keys %tags) {
      # find or create tag
      my $t = $db->query("SELECT id FROM canvas_tag WHERE name=?", $tag)->hash;

      unless ($t) {
        $t->{id} = $db->query("INSERT INTO canvas_tag (name) VALUES (?) RETURNING ID", $tag)->array->[0];
      }

      # insert the link
      my $pt = $db->query("INSERT INTO canvas_post_tag (post_id, tag_id) VALUES (?, ?) ", $post_id, $t->{id});
    }

    $tx->commit;
  }
  else {
    return $c->redirect_to('aboutdocumentadmin');
  }

  rebuild_index($c);

  $c->redirect_to('supportdocumentationid', id => $stub);
}

sub document_delete_any {
  my $c = shift;

  my $stub = $c->param('id');

  # only allow authenticated users
  return $c->redirect_to('supportdocumentation') unless $c->document->can_delete;

  $c->pg->db->query("DELETE FROM canvas_post WHERE name=? AND type='document'");

  rebuild_index($c);

  $c->redirect_to('supportdocumentation');
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
