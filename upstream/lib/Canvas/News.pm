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
package Canvas::News;

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
  my $self = shift;


  my $pager = Canvas::Store::Post->pager(
    where             => { type => 'news', status => 'publish' },
    order_by          => 'created DESC',
    entries_per_page  => 5,
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

  $self->render('news');
}

sub rss_get {
  my $self = shift;

  my $pager = Canvas::Store::Post->pager(
    where             => { type => 'news', status => 'publish' },
    order_by          => 'created DESC',
    entries_per_page  => 10,
    current_page      => 0,
  );

  my $rss = '<?xml version="1.0" ?><rss version="2.0"><channel>';
  $rss .= '<title>KororaProject - News</title>';
  $rss .= '<link>http://kororaproject.org/news</link>';

  foreach my $n ( $pager->search_where ) {
    $rss .= '<item>';
    $rss .= '<title>' . $n->title . '</title>';
    $rss .= '<link>http://kororaproject.org/news/' . $n->name . '</link>';
    $rss .= '<description>' . $n->excerpt . '</description>';
    $rss .= '<pubDate>' . $n->created->strftime('%a, %d %b %Y %H:%M:%S GMT') . '</pubDate>';
    $rss .= '</item>';
  }

  $rss .= '</channel></rss>';

  $self->render( text => $rss, format => 'xml' );
}

sub news_post_get {
  my $self = shift;
  my $stub = $self->param('id');

  my $p = Canvas::Store::Post->search({ name => $stub })->first;

  # check we found the post
  return $self->redirect_to('news') unless $self->news_post_can_view( $p );

  $self->stash( post => $p );

  $self->render('news-post');
}

sub news_add_get {
  my $self = shift;

  # only allow authenticated and authorised users
  return $self->redirect_to('/') unless $self->news_post_can_add;

  $self->stash(
    statuses  => list_status_for_post( 'news', 'draft' )
  );
  $self->render('news-post-new');
}

sub news_post_edit_get {
  my $self = shift;

  my $stub = $self->param('id');

  my $p = Canvas::Store::Post->search({ name => $stub })->first;

  # only allow those who are authorised to edit posts
  return $self->redirect_to('/news') unless $self->news_post_can_edit( $p );

  $self->stash(
    post      => $p,
    statuses  => list_status_for_post( $p->type, $p->status )
  );

  $self->render('news-post-edit');
}

sub news_post {
  my $self = shift;

  my $stub = $self->param('post_id');

  if( $stub ne '' ) {
    my $p = Canvas::Store::Post->search({ name => $stub })->first;

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
      return $self->redirect_to('/');
    }
  }
  # otherwise create a new entry
  elsif( $self->news_post_can_add ) {
    $stub = sanitise_with_dashes( $self->param('post_title') );

    my $now = gmtime;

    my $p = Canvas::Store::Post->create({
      name         => $stub,
      title        => $self->param('post_title'),
      content      => $self->param('post_content'),
      excerpt      => $self->param('post_excerpt'),
      author       => $self->auth_user->id,
      created      => $now,
      updated      => $now,
    });
  }
  else {
    return $self->redirect_to('/');
  }

  $self->redirect_to( 'newsid', id => $stub );
}

sub news_post_delete_any {
  my $self = shift;

  # only allow authenticated users
  return $self->redirect_to('/') unless $self->is_user_authenticated;

  my $stub = $self->param('id');

  my $p = Canvas::Store::Post->search({ name => $stub })->first;

  # check we found the post
  if( $self->news_post_can_delete( $p ) ) {
    $p->delete;
  }

  $self->redirect_to('/news');
}



sub news_admin_get {
  my $self = shift;

  # only allow authenticated and authorised users
  return $self->redirect_to('/news') unless (
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

  $self->render('news-admin');
}


1;
