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
package Website::News;

use warnings;
use strict;

#
# PERL INCLUDES
#
use Data::Dumper;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Pg;
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

sub list_status_for_post {
  my $type = shift;
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
# NEWS
#

sub index {
  my $c = shift;

  my $page_size = 10;
  my $page = ($c->param('page') // 1);

  $c->render_steps('website/news', sub {
    my $delay = shift;

    # get total count
    $c->pg->db->query("SELECT COUNT(id) FROM canvas_post WHERE type='news' AND status='publish'" => $delay->begin);

    # get paged items with username and email associated
    $c->pg->db->query("SELECT p.*, EXTRACT(EPOCH FROM p.created) AS created_epoch, EXTRACT(EPOCH FROM p.updated) AS updated_epoch, ARRAY_AGG(t.name) AS tags, u.username, u.email FROM canvas_post p JOIN canvas_user u ON (u.id=p.author_id) LEFT JOIN canvas_post_tag pt ON (pt.post_id=p.id) LEFT JOIN canvas_tag t ON (t.id=pt.tag_id) WHERE p.type='news' AND p.status='publish' GROUP BY p.id, u.username, u.email ORDER BY p.created DESC LIMIT ? OFFSET ?" => ($page_size, ($page-1) * $page_size) => $delay->begin);
  },
  sub {
    my ($delay, $count_err, $count_res, $err, $res) = @_;

    my $count = $count_res->array->[0];
    my $re = $res->hashes;
    say Dumper $re;

    $c->stash(news => {
      items       => $re,
      item_count  => $count,
      page_size   => $page_size,
      page        => $page,
      page_last   => ceil($count / $page_size),
    });
  });
}

sub rss_get {
  my $c = shift;

  # get latest items paged items with username and email associated
  my $res = $c->pg->db->query("SELECT title, name, excerpt, EXTRACT(EPOCH FROM created) AS created_epoch, EXTRACT(EPOCH FROM updated) AS updated_epoch FROM canvas_post WHERE type='news' AND status='publish' ORDER BY created DESC LIMIT 10");

  my $rss = '<?xml version="1.0" ?><rss version="2.0"><channel>' .
            '<title>Korora Project - News</title>' .
            '<link>http://kororaproject.org/about/news</link>';

  foreach my $n (@{$res->hashes}) {
    $rss .= '<item>' .
            '<title>' . $n->{title} . '</title>' .
            '<link>http://kororaproject.org/about/news/' . $n->{name} . '</link>' .
            '<description>' . $n->{excerpt} . '</description>' .
            '<pubDate>' . $n->{created} . '</pubDate>' .
            '</item>';
  }

  $rss .= '</channel></rss>';

  $c->render(text => $rss, format => 'xml');
}

sub news_post_get {
  my $c = shift;
  my $stub = $c->param('id');

  $c->render_steps('website/news-post', sub {
    my $delay = shift;

    $c->pg->db->query("SELECT p.*, EXTRACT(EPOCH FROM p.created) AS created_epoch, EXTRACT(EPOCH FROM p.updated) AS updated_epoch, ARRAY_AGG(t.name) AS tags, u.username, u.email FROM canvas_post p JOIN canvas_user u ON (u.id=p.author_id) LEFT JOIN canvas_post_tag pt ON (pt.post_id=p.id) LEFT JOIN canvas_tag t ON (t.id=pt.tag_id) WHERE p.type='news' AND p.name=? GROUP BY p.id, u.username, u.email" => ($stub) => $delay->begin);
  }, sub {
    my ($delay, $err, $res) = @_;

    # check we found the post
    my $post = $res->hash;

    $delay->emit(redirect => 'aboutnews') unless $c->news->can_view($post);

    $c->stash(post => $post);
  });
}

sub news_add_get {
  my $c = shift;

  # only allow authenticated and authorised users
  return $c->redirect_to('/') unless $c->news->can_add;

  $c->stash(
    statuses => list_status_for_post('news', 'draft')
  );
  $c->render('website/news-post-new');
}

sub news_post_edit_get {
  my $c = shift;

  my $stub    = $c->param('id');

  $c->render_steps('website/news-post-edit', sub {
    my $delay = shift;

    $c->pg->db->query("SELECT p.*, EXTRACT(EPOCH FROM p.created) AS created_epoch, EXTRACT(EPOCH FROM p.updated) AS updated_epoch, ARRAY_AGG(t.name) AS tags, u.username, u.email FROM canvas_post p JOIN canvas_user u ON (u.id=p.author_id) LEFT JOIN canvas_post_tag pt ON (pt.post_id=p.id) LEFT JOIN canvas_tag t ON (t.id=pt.tag_id) WHERE p.type='news' AND p.name=? GROUP BY p.id, u.username, u.email" => ($stub) => $delay->begin);
  }, sub {
    my ($delay, $err, $res) = @_;

    # check we found the post
    $delay->emit(redirect => 'aboutnews') unless $c->news->can_edit;

    my $p = $res->hash;
    $c->stash(
      post     => $p,
      statuses => list_status_for_post('news', $p->{status})
    );
  });
}

sub news_post {
  my $c = shift;

  my $author    = $c->param('author');
  my $content   = $c->param('content');
  my $excerpt   = $c->param('excerpt');
  my $status    = $c->param('status');
  my $stub      = $c->param('post_id');
  my $title     = $c->param('title');
  my $tag_list  = trim $c->param('tags');

  my $now = gmtime;

  my $created = $c->param('created');

  if ($stub ne '' && $c->news->can_edit) {
    my $p = $c->pg->db->query("SELECT p.id, title, excerpt, content, EXTRACT(EPOCH FROM p.created) AS created_epoch, EXTRACT(EPOCH FROM p.updated) AS updated_epoch, author_id, username, email FROM canvas_post p JOIN canvas_user u ON (u.id=p.author_id) WHERE type='news' AND name=?", $stub)->hash;

    # update author if changed
    if ($author ne $p->{username}) {
      my $u = $c->pg->db->query("SELECT id, username WHERE username=?", $author)->hash;

      $p->{author_id} = $u->{id} if $u->{id};
    }

    # TODO: update created if changed
    #my $t = Time::Piece->strptime($created, '%d/%m/%Y %H:%M:%S');

    my $db = $c->pg->db;
    my $tx = $db->begin;

    $db->query("UPDATE canvas_post SET status=?, title=?, excerpt=?, content=?, author_id=?, created=?, updated=? WHERE type='news' AND name=?", $status, $title, $excerpt, $content, $p->{author_id}, $created, $now, $stub);

    # update tags
    my $tt = $db->query("SELECT ARRAY_AGG(t.name) AS tags FROM canvas_post p LEFT JOIN canvas_post_tag pt ON (pt.post_id=p.id) LEFT JOIN canvas_tag t ON (t.id=pt.tag_id) WHERE p.id=? GROUP BY p.id", $p->{id})->hash;

    my @tags_old = $tt->{tags};
    my @tags_new = @{$c->sanitise_taglist($tag_list)};

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

    $tx->commit;
  }
  # otherwise create a new entry
  elsif ($c->news->can_add) {
    $stub = $c->sanitise_with_dashes($title);

    my $db = $c->pg->db;
    my $tx = $db->begin;

    # check for existing stubs and append the ID + 1 of the last
    my $e = $db->query("SELECT id FROM canvas_post WHERE type='news' AND name=? ORDER BY id DESC LIMIT 1", $stub)->array;
    $stub .= '-' . ($e->[0] + 1) if $e;

    $created = $now;

    my $post_id = $c->pg->db->query('INSERT INTO canvas_post (type, name, status, title, content, excerpt, author_id, created, updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING ID', 'news', $stub, $status, $title, $content, $excerpt, $c->auth_user->{id}, $created, $now)->array->[0];

    # create the tags
    foreach my $tag (@{$c->sanitise_taglist($tag_list)}) {
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
    return $c->redirect_to('aboutnewsadmin');
  }

  $c->redirect_to('aboutnewsid', id => $stub);
}

sub news_post_delete_any {
  my $c = shift;

  # only allow authenticated users
  if ($c->news->can_delete) {
    my $stub = $c->param('id');

    my $r = $c->pg->db->query("DELETE FROM canvas_post WHERE type='news' AND name=?", $stub);
  };

  $c->redirect_to('aboutnews');
}

sub news_admin_get {
  my $c = shift;

  # only allow authenticated and authorised users
  return $c->redirect_to('aboutnews') unless (
    $c->news->can_add || $c->news->can_delete
  );

  my $page_size = 20;
  my $page = ($c->param('page') // 1);

  $c->render_steps('website/news-admin', sub {
    my $delay = shift;

    # get total count
    $c->pg->db->query("SELECT COUNT(id) FROM canvas_post WHERE type='news'" => $delay->begin);

    # get paged items with username and email associated
    $c->pg->db->query("SELECT name, p.status, title, excerpt, EXTRACT(EPOCH FROM p.created) AS created_epoch, EXTRACT(EPOCH FROM p.updated) AS updated_epoch, username, email FROM canvas_post p JOIN canvas_user u ON (u.id=p.author_id) WHERE p.type='news' ORDER BY p.created DESC LIMIT ? OFFSET ?" => ($page_size, ($page-1) * $page_size) => $delay->begin);
  },
  sub {
    my ($delay, $err, $count_res, $err_res, $res) = @_;

    my $count = $count_res->array->[0];

    $c->stash(news => {
      items       => $res->hashes,
      item_count  => $count,
      page_size   => $page_size,
      page        => $page,
      page_last   => ceil($count / $page_size),
    });
  });
}

1;
