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
package Canvas::Engage;

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
use Canvas::Store::PostTag;
use Canvas::Store::Tag;

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

sub validate_types($) {
  my $types_valid_map =  {
    idea => 1,
    problem => 1,
    question => 1,
    thank => 1,
  };

  my $types = shift // [ keys %$types_valid_map ];
  $types = [ $types ] unless ref $types eq 'ARRAY';

  my $v = [ grep { $types_valid_map->{$_} } @$types ];

  $v = [ keys %$types_valid_map ] unless @$v;

  return $v;
}

#
# NEWS
#

sub index {
  my $self = shift;

  my $filter_type = validate_types( $self->param('t') );
  my $filter_tags = validate_types( $self->param('s') );

  my $cache = {};

  my $pager = Canvas::Store::Post->pager(
    where             => { type => $filter_type },
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
  $self->render('engage');
}

sub engage_prepare {
  my $self = shift;

  my $type = $self->param('type');
  my $title = $self->param('title');

  # ensure it's a valid type
  return $self->redirect_to('/support/engage') unless grep { $_ eq $type } qw(idea problem question thank);

  # only allow authenticated and authorised users
  return $self->redirect_to('/support/engage') unless (
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

  $self->render('engage-new');
}

sub detail {
  my $self = shift;
  my $stub = $self->param('stub');

  my $p = Canvas::Store::Post->search({ name => $stub })->first;
  my @r = Canvas::Store::Post->replies( $stub );

  # check we found the post
  return $self->redirect_to('/support/engage') unless defined $p;

  $self->stash( response => $p, replies => \@r );
  $self->render('engage-detail');
}

sub post_edit {
  my $self = shift;

  # only allow authenticated and authorised users
  return $self->redirect_to('/support/engage') unless (
    $self->is_user_authenticated() &&
    $self->auth_user->is_admin
  );

  my $stub = $self->param('stub');

  my $p = Canvas::Store::WPPost->search({ post_name => $stub })->first;

  # check we found the post
  return $self->redirect_to('/support/engage') unless defined $p;

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
  return $self->redirect_to('/support/engage') unless (
    $self->is_user_authenticated()
  );

  my $type = $self->param('type');
  my $stub = sanitise_with_dashes( $self->param('title') );

  my $content = $self->param('content');
  return $self->redirect_to( 'supportengagetypestub', type => $type, stub => $stub ) unless length trim $content;

  # ensure it's a valid type
  return $self->redirect_to('/support/engage') unless grep { $_ eq $type } qw(idea problem question thank);

  my $now = gmtime;

  # create the post
  my $p = Canvas::Store::Post->create({
    name         => $stub,
    type         => $type,
    title        => $self->param('title'),
    content      => $self->param('content'),
    author       => $self->auth_user->{u}->id,
    created      => $now,
    updated      => $now,
  });

  # create the tags
  foreach my $tag ( split /,/, $self->param('tags') ) {
    $tag = trim $tag;
    my $t  = Canvas::Store::Tag->find_or_create({ name => $tag });
    my $pt = Canvas::Store::PostTag->find_or_create({ post_id => $p->id, tag_id => $t->id })
  }

  # redirect to the detail
  $self->redirect_to( 'supportengagetypestub', type => $type, stub => $stub );
}

sub edit_get {
  my $self = shift;

  my $stub = $self->param('stub');
  my $p = Canvas::Store::Post->search({ name => $stub })->first;

  # check we found the post
  return $self->redirect_to('/support/engage') unless defined $p;

  # only allow authenticated and authorised users
  return $self->redirect_to('/support/engage') unless (
    $self->post_can_edit( $p )
  );

  my $status;
  given( $p->type ) {
    when('idea') {
      $status = [
        [ 'Under Consideration' => 'consider' ],
        [ 'Declined'            => 'declined' ],
        [ 'Planned'             => 'planned'  ],
        [ 'In Progress'         => 'progress' ],
        [ 'Completed'           => 'complete' ],
        [ 'Gathering Feedback'  => 'feedback' ],
      ];

      $self->param( status => 'consider' );
    }
    when('problem') {
      $status = [
        [ 'Known Problem' => 'known'     ],
        [ 'Declined'      => 'noproblem' ],
        [ 'Solved'        => 'solved'    ],
        [ 'In Progress'   => 'progress'  ],
      ];
    }
    when('question') {
      $status = [
        [ 'Answered'    => 'answered'   ],
        [ 'Need Answer' => 'unanswered' ],
      ];

      $self->param( 'status' => 'unanswered' );
    }
    default {
      $status = [];
    }
  }

  my @r = Canvas::Store::Post->replies( $stub );

  $self->stash( response => $p, statuses => $status, replies => \@r );

  $self->render('engage-edit');
}

sub edit {
  my $self = shift;

  my $stub = $self->param('stub');
  my $type = $self->param('type');
  my $p = Canvas::Store::Post->search({ name => $stub })->first;

  # check we found the post
  return $self->redirect_to('/support/engage') unless defined $p;

  # only allow authenticated and authorised users
  return $self->redirect_to('/support/engage') unless (
    $self->post_can_edit( $p )
  );

  # update title, content and status
  my $title = $self->param('title');
  my $content= $self->param('content');
  my $status = $self->param('status');


  Canvas::Store->do_transaction( sub {
    $p->status( $status );
    $p->title( $title ) if length trim $title;
    $p->content( $content ) if length trim $content;
    $p->update;

    # find tags to add and remove
    my @tags_old = $p->tag_list_array;
    my @tags_new = map { trim $_ } split( ',', $self->param('tags') ); 

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

  $self->redirect_to( 'supportengagetypestub', type => $type, stub => $stub );
}

sub reply_get {
  my $self = shift;

  my $type = $self->param('type');
  my $stub = $self->param('stub');

  $self->redirect_to( 'supportengagetypestub', type => $type, stub => $stub );
}

sub reply {
  my $self = shift;

  # only allow authenticated and authorised users
  return $self->redirect_to('/support/engage') unless(
    $self->is_user_authenticated && defined $self->auth_user
  );

  my $type = $self->param('type');
  my $stub = $self->param('stub');

  # ensure we have content
  my $content = $self->param('content');
  return $self->redirect_to( 'supportengagetypestub', type => $type, stub => $stub ) unless length( trim $content ) > 0;

  my $p = Canvas::Store::Post->search({ name => $stub })->first;

  # check we found the post
  return $self->redirect_to('/support/engage') unless defined $p;

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
  $self->redirect_to( 'supportengagetypestub', type => $type, stub => $stub );
}

sub engage_delete {
  my $self = shift;

  # only allow authenticated and authorised users
  $self->redirect_to('/') unless (
    $self->is_user_authenticated() &&
    $self->auth_user->is_admin
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
