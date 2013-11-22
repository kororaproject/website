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
package Canvas::Response;

use warnings;
use strict;

#
# PERL INCLUDES
#
use Data::Dumper;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw(trim);
use Time::Piece;

#
# LOCAL INCLUDES
#
use Canvas::Store::Post;

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

  my $pager = Canvas::Store::Post->pager(
    where             => { type => ['idea', 'thank', 'question', 'problem'] },
    order_by          => 'updated DESC',
    entries_per_page  => 10,
    current_page      => $self->param('page') // 0,
  );

  $cache->{items} = [ $pager->search_where ];
  $cache->{item_count} = $pager->total_entries;
  $cache->{page_size} = $pager->entries_per_page;
  $cache->{page} = $pager->current_page;
  $cache->{page_last} = ($pager->total_entries / $pager->entries_per_page) - 1;

  $self->stash( responses => $cache );
  $self->render('response');
}

sub response_prepare {
  my $self = shift;

  my $type = $self->param('type');
  my $title = $self->param('title');

  # ensure it's a valid type
  return $self->redirect_to('/support/response') unless grep { $_ eq $type } qw(idea problem question thank);

  # only allow authenticated and authorised users
  return $self->redirect_to('/support/response') unless (
    $self->is_user_authenticated()
  );

  my $map = {
    idea      => {
      name  => 'idea',
      title => 'Share a New Idea',
      icon  => 'fa-lightbulb-o',
    },
    problem   => {
      name  => 'problem',
      title => 'Add a New Problem',
      icon  => 'fa-bug',
    },
    question  => {
      name  => 'question',
      title => 'Ask a New Question',
      icon  => 'fa-question',
    },
    thank     => {
      name  => 'thank',
      title => 'Say Thanks',
      icon  => 'fa-trophy',
    }
  };

  $self->stash(
    type  => $map->{ $type },
    title => $title
  );

  $self->render('response-new');
}

sub detail {
  my $self = shift;
  my $stub = $self->param('stub');

  my $p = Canvas::Store::Post->search({ name => $stub })->first;
  my @r = Canvas::Store::Post->replies( $stub );

  # check we found the post
  return $self->redirect_to('/support/response') unless defined $p;

#    created       => $p->created->strftime('%e %B, %Y'),
#    updated       => $p->updated->strftime('%e %B, %Y'),

  $self->stash( response => $p, replies => \@r );
  $self->render('response-detail');
}

sub post_edit {
  my $self = shift;

  # only allow authenticated and authorised users
  return $self->redirect_to('/support/response') unless (
    $self->is_user_authenticated() &&
    $self->auth_user->{wpu}->is_admin
  );

  my $stub = $self->param('stub');

  my $p = Canvas::Store::WPPost->search({ post_name => $stub })->first;

  # check we found the post
  return $self->redirect_to('/support/response') unless defined $p;

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

sub add {
  my $self = shift;

  # only allow authenticated and authorised users
  return $self->redirect_to('/support/response') unless (
    $self->is_user_authenticated()
  );

  my $type = $self->param('type');
  my $stub = sanitise_with_dashes( $self->param('title') );

  my $content = $self->param('content');
  return $self->redirect_to( 'supportresponsetypestub', type => $type, stub => $stub ) unless length trim $content;

  # ensure it's a valid type
  return $self->redirect_to('/support/response') unless grep { $_ eq $type } qw(idea problem question thank);

  my $now = gmtime;

  my $p = Canvas::Store::Post->create({
    name         => $stub,
    type         => $type,
    title        => $self->param('title'),
    content      => $self->param('content'),
    author       => $self->auth_user->{u}->id,
    created      => $now,
    updated      => $now,
  });

  # redirect to the detail
  $self->redirect_to( 'supportresponsetypestub', type => $type, stub => $stub );
}


sub reply_get {
  my $self = shift;
  my $type = $self->param('type');
  my $stub = $self->param('stub');

  $self->redirect_to( 'supportresponsetypestub', type => $type, stub => $stub );
}

sub reply {
  my $self = shift;

  # only allow authenticated and authorised users
  return $self->redirect_to('/support/response') unless(
    $self->is_user_authenticated && defined $self->auth_user
  );

  my $type = $self->param('type');
  my $stub = $self->param('stub');

  # ensure we have content
  my $content = $self->param('content');
  return $self->redirect_to( 'supportresponsetypestub', type => $type, stub => $stub ) unless length( trim $content ) > 0;

  my $p = Canvas::Store::Post->search({ name => $stub })->first;

  # check we found the post
  return $self->redirect_to('/support/response') unless defined $p;

  my $now = gmtime;

  my $r = Canvas::Store::Post->create({
    name         => $stub,
    type         => 'reply',
    content      => $content,
    author       => $self->auth_user->{u}->id,
    created      => $now,
    updated      => $now,
    parent_id    => $p->id
  });

  # TODO: optimise with an increment
  my @c = Canvas::Store::Post->search({ parent_id => $p->id });
  $p->reply_count( scalar @c );
  $p->update;

  # redirect to the detail
  $self->redirect_to( 'supportresponsetypestub', type => $type, stub => $stub );
}

sub response_delete {
  my $self = shift;

  # only allow authenticated and authorised users
  $self->redirect_to('/') unless (
    $self->is_user_authenticated() &&
    $self->auth_user->{wpu}->is_admin
  );

  my $stub = $self->param('id');

  my $p = Canvas::Store::Post->search({ name => $stub })->first;

  # check we found the post
  if( $p ) {
    $p->delete;
  }

  $self->redirect_to('support');
}

1;
