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
use POSIX qw(floor);
use Time::Piece;

#
# LOCAL INCLUDES
#
use Canvas::Store::Post;
use Canvas::Store::PostTag;
use Canvas::Store::Tag;

#
# CONSTANTS
#


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

sub filter_valid_types($) {
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

  my $cache = Canvas::Store::Post->search_type_status_and_tags(
    type            => filter_valid_types( $self->param('type') ),
    status          => $self->param('status') // '',
    tags            => $self->param('tags')   // '',
    items_per_page  => 20,
    current_page    => $self->param('page'),
  );

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

  # check for existing stubs and append the ID + 1 of the last
  my( @e ) = Canvas::Store::Post->search({
      name => $stub,
      type => $type,
  });

  $stub .= '-' . ( $e[-1]->id + 1 ) if @e;

  # create the post
  my $p = Canvas::Store::Post->create({
    name         => $stub,
    type         => $type,
    status       => '',
    title        => $self->param('title'),
    content      => $self->param('content'),
    author_id    => $self->auth_user->id,
    created      => $now,
    updated      => $now,
  });

  # create the tags
  my %tags = map { sanitise_with_dashes( trim $_ ) => 1 } split /,/, $self->param('tags');
  foreach my $tag ( keys %tags ) {
    $tag = trim $tag;
    my $t  = Canvas::Store::Tag->find_or_create({ name => $tag });
    my $pt = Canvas::Store::PostTag->find_or_create({ post_id => $p->id, tag_id => $t->id })
  }

  # auto-subscribe the creator (engage_subscriptions)
  Canvas::Store::UserMeta->find_or_create({
    user_id     => $self->auth_user->id,
    meta_key    => 'engage_subscriptions',
    meta_value  => $p->id,
  });

  # mail all admins with "notify new engage items" checked
  my @um = Canvas::Store::UserMeta->search({
    meta_key   => 'engage_notify_on_new',
    meta_value => 1,
  });

  if( @um ) {
    my $subject = 'Korora Project - New Engage Item: ' . $p->title;
    my $message = join "",
      "G'day,\n\n",
      "A new engage item has been posted by " . $p->author_id->username . "\n\n",
      "URL: https://kororaproject.org" . $self->url_for( 'supportengagetypestub', type=> $type, stub => $stub ) . "\n",
      "Type: " . $p->type .. "\n",
      "Status: " . $p->type .. "\n",
      "Excerpt:\n",
      $p->content . "\n\n",
      "Regards,\n",
      "The Korora Team.\n";

    foreach my $_um ( @um ) {
      # send the activiation email
      $self->mail(
        from    => 'engage@kororaproject.org',
        to      => $_um->user_id->email,
        subject => $subject,
        data    => $message,
      );
    }
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
    $self->engage_post_can_edit( $p )
  );

  my @r = Canvas::Store::Post->replies( $stub );

  $self->stash( post => $p, replies => \@r );

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
    $self->engage_post_can_edit( $p )
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
    my @tags_new = map { sanitise_with_dashes( trim $_ ) } split( ',', $self->param('tags') );

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

sub subscribe {
  my $self = shift;

  my $stub = $self->param('stub');
  my $type = $self->param('type');

  my $url = $self->url_for('supportengagetypestub', type => $type, stub => $stub);

  # redirect unless we're actively auth'd
  return $self->redirect_to( $url ) unless $self->is_active_auth;

  my $p = Canvas::Store::Post->search({
    type => $type,
    name => $stub
  })->first;

  # check we found the post
  return $self->redirect_to('/support/engage') unless defined $p;

  # subscribe (engage_subscriptions)
  Canvas::Store::UserMeta->find_or_create({
    user_id     => $self->auth_user->id,
    meta_key    => 'engage_subscriptions',
    meta_value  => $p->id,
  });

  return $self->redirect_to( $url );
}

sub unsubscribe {
  my $self = shift;

  my $stub = $self->param('stub');
  my $type = $self->param('type');


  my $url = $self->url_for('supportengagetypestub', type => $type, stub => $stub);

  # redirect unless we're actively auth'd
  return $self->redirect_to( $url ) unless $self->is_active_auth;

  my $p = Canvas::Store::Post->search({
    type => $type,
    name => $stub
  })->first;

  # check we found the post
  return $self->redirect_to('/support/engage') unless defined $p;

  # only allow authenticated and authorised users
  return $self->redirect_to('/support/engage') unless (
    $self->engage_post_can_edit( $p )
  );

  # find metadata (engage_subscriptions)
  my $um = Canvas::Store::UserMeta->search({
    user_id     => $self->auth_user->id,
    meta_key    => 'engage_subscriptions',
    meta_value  => $p->id,
  })->first;

  $um->delete if defined $um;

  return $self->redirect_to( $url );
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
  my $subscribe = $self->param('subscribe') // 0;

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
    author_id    => $self->auth_user->id,
    created      => $now,
    updated      => $now,
    parent_id    => $p->id
  });

  # TODO: optimise with an increment
  my @c = Canvas::Store::Post->search({ parent_id => $p->id });
  $p->reply_count( scalar @c );
  $p->update;

  # auto-subscribe participants (engage_subscriptions)
  Canvas::Store::UserMeta->find_or_create({
    user_id     => $self->auth_user->id,
    meta_key    => 'engage_subscriptions',
    meta_value  => $p->id,
  });

  # mail all subscribers
  my @um = Canvas::Store::UserMeta->search({
    meta_key   => 'engage_subscriptions',
    meta_value => $p->id,
  });

  if( @um ) {
    my $subject = 'Korora Project - Engage Reply: ' . $p->title;
    my $message = join "",
      "G'day,\n\n",
      "A new reply has been posted by " . $r->author_id->username . "\n\n",
      "URL: https://kororaproject.org" . $self->url_for( 'supportengagetypestub', type=> $type, stub => $stub ) . '#reply-' . $r->id . "\n",
      "Type: " . $p->type .. "\n",
      "Status: " . $p->type .. "\n",
      "Excerpt:\n",
      $r->content . "\n\n",
      "Regards,\n",
      "The Korora Team.\n";

    foreach my $_um ( @um ) {
      # send the activiation email
      $self->mail(
        from    => 'engage@kororaproject.org',
        to      => $_um->user_id->email,
        subject => $subject,
        data    => $message,
      );
    }
  }

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
