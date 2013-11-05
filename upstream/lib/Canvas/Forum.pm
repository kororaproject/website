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
package Canvas::Forum;

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

#
# FORUMS
#

sub forums {
  my $self = shift;

  my $cache = [];

  foreach my $f ( Canvas::Store::WPPost->forums( 0 ) ) {
    my $forum = {
      id            => $f->ID,
      created       => $f->post_date_gmt,
      updated       => $f->post_modified_gmt,
      title         => $f->post_title,
      content       => $f->post_content,
      name          => $f->post_name,
      author        => $f->post_author->user_nicename,
      subforums     => [],
      topics        => [],
      replies       => [],
      total_topics  => undef,
      total_posts   => undef,
    };

    foreach my $sf ( Canvas::Store::WPPost->forums( $f->ID ) ) {
      push @{ $forum->{subforums} }, {
        id            => $sf->ID,
        created       => $sf->post_date_gmt,
        updated       => $sf->post_modified_gmt,
        title         => $sf->post_title,
        content       => $sf->post_content,
        name          => $sf->post_name,
        author        => $sf->post_author->user_nicename,
      };
    }

    foreach my $t ( Canvas::Store::WPPost->topics( $f->ID ) ) {
      push @{ $forum->{topics} }, {
        id            => $t->ID,
        created       => $t->post_date_gmt,
        updated       => $t->post_modified_gmt,
        title         => $t->post_title,
        content       => $t->post_content,
        name          => $t->post_name,
        author        => $t->post_author->user_nicename,
      };
    }

    push @$cache, $forum;
  }

  $self->stash( forums => $cache );
  $self->render('support-forums');
}


#get '/forum/:name' => sub {
sub forum_name {
  my $self = shift;
  my $name = $self->param('name');

  my $cache = [];
  my $breadcrumbs = [];

  my( $f ) = Canvas::Store::WPPost->forum_name( $name );

  # calculate breadcrumbs
  my $b = $f;
  while( $b->post_parent->ID ne 0 ) {
    unshift @$breadcrumbs, {
      url => $b->post_parent->post_name,
      title => $b->post_parent->post_title,
    };
    $b = $b->post_parent;
  }

  my $forum = {
    id            => $f->ID,
    created       => $f->post_date_gmt,
    updated       => $f->post_modified_gmt,
    title         => $f->post_title,
    content       => $f->post_content,
    name          => $f->post_name,
    author        => $f->post_author->user_nicename,
    subforums     => [],
    topics        => [],
    posts         => [],
    total_topics  => undef,
    total_posts   => undef,
  };

  foreach my $sf ( Canvas::Store::WPPost->forums( $f->ID ) ) {
    push @{ $forum->{subforums} }, {
      id            => $sf->ID,
      created       => $sf->post_date_gmt,
      updated       => $sf->post_modified_gmt,
      title         => $sf->post_title,
      content       => $sf->post_content,
      name          => $sf->post_name,
      author        => $sf->post_author->user_nicename,
    };
  }

  foreach my $t ( Canvas::Store::WPPost->topics_newest( $f->ID ) ) {

    # collect all replies
    my @replies = Canvas::Store::WPPost->replies( $t->ID );

    # determine unique voices
    my %voices;
    my @unique_voices = grep { ! $voices{$_->post_author->user_nicename}++ } ( $t, @replies );

    # determine freshness
    my $now = gmtime;
    my $freshness = $t->post_modified_gmt;
    my $freshness_author = $t->post_author->user_nicename;

    if( @replies ) {
      $freshness_author = $replies[-1]->post_author->user_nicename;
    }

    push @{ $forum->{topics} }, {
      id                => $t->ID,
      created           => $t->post_date_gmt,
      updated           => $t->post_modified_gmt,
      title             => $t->post_title,
      content           => $t->post_content,
      name              => $t->post_name,
      author            => $t->post_author->user_nicename,
      total_posts       => scalar @replies + 1,
      unique_voices     => scalar @unique_voices,
      freshness         => $freshness,
      freshness_author  => $freshness_author
    };
  }

  push @$cache, $forum;

  $self->stash( forum => $forum, breadcrumbs => $breadcrumbs );
  $self->render('support-forum');
}

#get '/topic/:name' => sub {
sub topic_name {
  my $self = shift;
  my $name = $self->param('name');

  my $cache = [];
  my $breadcrumbs = [];

  my( $t ) = Canvas::Store::WPPost->topic_name( $name );

  # calculate breadcrumbs
  my $b = $t;
  while( $b->post_parent->ID ne 0 ) {
    unshift @$breadcrumbs, {
      url => $b->post_parent->post_name,
      title => $b->post_parent->post_title,
    };
    $b = $b->post_parent;
  }

  my $topic = {
    id            => $t->ID,
    created       => $t->post_date_gmt->strftime('%e %B, %Y at %H:%M'),
    updated       => $t->post_modified_gmt->strftime('%e %B, %Y at %H:%M'),
    title         => $t->post_title,
    content       => $t->post_content,
    name          => $t->post_name,
    author        => $t->post_author->user_nicename,
    replies       => [],
  };

  foreach my $r ( Canvas::Store::WPPost->replies( $t->ID ) ) {
    push @{ $topic->{replies} }, {
      id            => $r->ID,
      created       => $r->post_date_gmt->strftime('%e %B, %Y at %H:%M'),
      updated       => $r->post_modified_gmt->strftime('%e %B, %Y at %H:%M'),
      title         => $r->post_title,
      content       => $r->post_content,
      name          => $r->post_name,
      author        => $r->post_author->user_nicename,
    };
  }

  push @$cache, $topic;

  $self->stash( topic => $topic, breadcrumbs => $breadcrumbs );
  $self->render('support-forum-topic');
}

1;
