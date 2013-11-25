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
use Time::Piece;

#
# LOCAL INCLUDES
#
use Canvas::Store::WPPost;
use Canvas::Store::Pager;

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


#
# NEWS
#

sub index {
  my $self = shift;

  my $cache = {};

  my $pager = Canvas::Store::WPPost->pager(
    where             => { post_type => 'post' },
    order_by          => 'post_modified_gmt DESC',
    entries_per_page  => 5,
    current_page      => $self->param('page') // 0,
  );

  $cache->{items} = [ $pager->search_where ];
  $cache->{item_count} = $pager->total_entries;
  $cache->{page_size} = $pager->entries_per_page;
  $cache->{page} = $pager->current_page;
  $cache->{page_last} = ($pager->total_entries / $pager->entries_per_page) - 1;

#  my foreach my $p ( @posts ) {
#    push @$cache, {
#      id            => $p->ID,
#      created       => $p->post_date_gmt,
#      updated       => $p->post_modified_gmt,
#      title         => $p->post_title,
#      content       => $p->post_content,
#      excerpt       => $p->post_excerpt,
#      name          => $p->post_name,
#      author        => $p->post_author->user_nicename,
#    };
#  }

  $self->stash( news => $cache );
  $self->render('news');
}

sub post {
  my $self = shift;
  my $post = $self->param('id');

  my $p = Canvas::Store::WPPost->search({ post_name => $post })->first;

  # check we found the post
  $self->redirect_to('/') unless defined $p;

  my $cache = {
    id            => $p->ID,
    created       => $p->post_date_gmt->strftime('%e %B, %Y'),
    updated       => $p->post_modified_gmt->strftime('%e %B, %Y'),
    title         => $p->post_title,
    content       => $p->post_content,
    excerpt       => $p->post_excerpt,
    name          => $p->post_name,
    author        => $p->post_author->user_nicename,
  };

  $self->stash( post => $cache );
  $self->render('news-post');
}

sub post_create {
  my $self = shift;

  # only allow authenticated and authorised users
  $self->redirect_to('/') unless (
    $self->is_user_authenticated() &&
    $self->auth_user->is_admin
  );

  my $cache = {
    id            => '',
    created       => '',
    updated       => '',
    title         => '',
    content       => '',
    excerpt       => '',
    name          => '',
    author        => '',
  };

  $self->stash( mode => 'create', post => $cache );
  $self->render('news-post-new');
}

sub post_edit {
  my $self = shift;

  my $stub = $self->param('id');

  my $p = Canvas::Store::WPPost->search({ post_name => $stub })->first;

  # only allow authenticated and authorised users
  $self->redirect_to('/') unless $self->post_can_edit( $p );

  # check we found the post
  $self->redirect_to('/') unless defined $p;

  my $cache = {
    id            => $p->ID,
    created       => $p->post_date_gmt->strftime('%e %B, %Y at %H:%M'),
    updated       => $p->post_modified_gmt->strftime('%e %B, %Y at %H:%M'),
    title         => $p->post_title,
    content       => $p->post_content,
    excerpt       => $p->post_excerpt,
    stub          => $p->post_name,
    author        => $p->post_author->user_nicename,
  };

  # build the cancel path

  $self->stash( mode => 'edit', post => $cache );
  $self->render('news-post-new');
}

sub post_update {
  my $self = shift;

  # only allow authenticated and authorised users
  $self->redirect_to('/') unless (
    $self->is_user_authenticated() &&
    $self->auth_user->is_admin
  );

  my $stub = $self->param('post_id');

  if( $stub ne '' ) {
    my $p = Canvas::Store::WPPost->search({ post_name => $stub })->first;

    # update if we found the object
    if( $p ) {
      $p->post_title( $self->param('post_title') // '' );
      $p->post_content( $self->param('post_content') // '' );
      $p->post_excerpt( $self->param('post_excerpt') // '' );

      $p->update;
    }
  }
  # otherwise create a new entry
  else {
    $stub = sanitise_with_dashes( $self->param('post_title') );

    my $now = gmtime;

    my $p = Canvas::Store::WPPost->create({
      post_name         => $stub,
      post_title        => $self->param('post_title'),
      post_content      => $self->param('post_content'),
      post_excerpt      => $self->param('post_excerpt'),
      post_author       => $self->auth_user->id,
      post_date_gmt     => $now,
      post_modified_gmt => $now,
    });
  }

  $self->redirect_to( 'newsid', id => $stub );
}

sub post_delete {
  my $self = shift;

  # only allow authenticated and authorised users
  $self->redirect_to('/') unless (
    $self->is_user_authenticated() &&
    $self->auth_user->is_admin
  );

  my $stub = $self->param('id');

  my $p = Canvas::Store::WPPost->search({ post_name => $stub })->first;

  # check we found the post
  if( $p ) {
    $p->delete;
  }

  $self->redirect_to('/news');
}

1;
