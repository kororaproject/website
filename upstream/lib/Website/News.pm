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
    $c->pg->db->query("SELECT name, title, excerpt, TO_CHAR(p.created, 'Dy, DD Month YYYY') AS created, username, email FROM canvas_post p JOIN canvas_user u ON (u.id=p.author_id) WHERE p.type='news' AND p.status='publish' ORDER BY p.created DESC LIMIT ? OFFSET ?" => ($page_size, ($page-1) * $page_size) => $delay->begin);
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

sub rss_get {
  my $c = shift;

  # get latest items paged items with username and email associated
  my $res = $c->pg->db->query("SELECT title, name, excerpt, TO_CHAR(created, 'Dy, DD Mon YYYY HH24:MI:SS GMT') AS created FROM canvas_post WHERE type='news' AND status='publish' ORDER BY created DESC LIMIT 10");

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

    $c->pg->db->query("SELECT title, excerpt, content, TO_CHAR(p.created, 'Dy, DD Month YYYY') AS created, username, email FROM canvas_post p JOIN canvas_user u ON (u.id=p.author_id) WHERE type='news' AND name=?" => ($stub) => $delay->begin);
  }, sub {
    my ($delay, $err, $res) = @_;

    # check we found the post
    my $post = $res->hash;

    $delay->emit(redirect => 'aboutnews') unless $c->news_post_can_view($post);

    $c->stash(post => $post);
  });
}

sub news_add_get {
  my $c = shift;

  # only allow authenticated and authorised users
  return $c->redirect_to('/') unless $c->news_post_can_add;

  $c->stash(
    statuses => list_status_for_post('news', 'draft')
  );
  $c->render('website/news-post-new');
}

sub news_post_edit_get {
  my $c = shift;

  my $stub = $c->param('id');

  $c->render_steps('website/news-post-edit', sub {
    my $delay = shift;

    $c->pg->db->query("SELECT title, excerpt, content, TO_CHAR(p.created, 'YYYY-MM-DD HH24:MI:SS') AS created, username, email FROM canvas_post p JOIN canvas_user u ON (u.id=p.author_id) WHERE type='news' AND name=?" => ($stub) => $delay->begin);
  }, sub {
    my ($delay, $err, $res) = @_;

    # check we found the post
    $delay->emit(redirect => 'aboutnews') unless $res->rows > 0; #$self->news_post_can_edit( $p );

    $c->stash(post => $res->hash);
  });
}

sub news_post {
  my $self = shift;

  my $stub = $self->param('post_id');

  if( $stub ne '' ) {
    my $p = Canvas::Store::Post->search({ name => $stub, type => 'news' })->first;

    # update if we found the object
    if( $self->news_post_can_edit( $p ) ) {
      $p->title( $self->param('title') );
      $p->content( $self->param('content') );
      $p->excerpt( $self->param('excerpt') );
      $p->status( $self->param('status') );

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

      $p->update;
    }
    else {
      return $self->redirect_to('aboutnewsadmin');
    }
  }
  # otherwise create a new entry
  elsif( $self->news_post_can_add ) {
    $stub = $self->sanitise_with_dashes( $self->param('title') );

    my $now = gmtime;

    my $p = Canvas::Store::Post->create({
      name         => $stub,
      type         => 'news',
      status       => $self->param('status'),
      title        => $self->param('title'),
      content      => $self->param('content'),
      excerpt      => $self->param('excerpt'),
      author_id    => $self->auth_user->id,
      created      => $now,
      updated      => $now,
    });
  }
  else {
    return $self->redirect_to('aboutnewsadmin');
  }

  $self->redirect_to( 'aboutnewsid', id => $stub );
}

sub news_post_delete_any {
  my $self = shift;

  my $stub = $self->param('id');

  my $p = Canvas::Store::Post->search({ name => $stub, type => 'news' })->first;

  # only allow authenticated users
  return $self->redirect_to('aboutnews') unless $self->news_post_can_delete( $p );

  # check we found the post
  if( $self->news_post_can_delete( $p ) ) {
    $p->delete;
  }

  $self->redirect_to('aboutnews');
}

sub news_admin_get {
  my $self = shift;

  # only allow authenticated and authorised users
  return $self->redirect_to('aboutnews') unless (
    $self->news_post_can_add ||
    $self->news_post_can_delete
  );

  my $pager = Canvas::Store::Post->pager(
    where             => { type => 'news' },
    order_by          => 'created DESC',
    entries_per_page  => 20,
    current_page      => ( $self->param('page') // 1 ) - 1,
  );

  my $news = {
    items       => [ $pager->search_where ],
    item_count  => $pager->total_entries,
    page_size   => $pager->entries_per_page,
    page        => $pager->current_page + 1,
    page_last   => ceil($pager->total_entries / $pager->entries_per_page),
  };

  $self->stash( news => $news );

  $self->render('website/news-admin');
}


1;
