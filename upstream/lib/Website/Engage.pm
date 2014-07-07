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
package Website::Engage;

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
# CONSTANTS
#
use constant TYPE_MAP => {
  '' => {
    status => {
      ''  => 'All Responses'
    }
  },
  idea      => {
    name  => 'idea',
    title => 'Share a New Idea',
    icon  => 'fa-lightbulb-o',
    status  => {
      ''                    => 'All Ideas',
      'under-consideration' => 'Ideas - Under Consideration',
      'declined'            => 'Ideas - Declined',
      'planned'             => 'Ideas - Planned',
      'in-progress'         => 'Ideas - In Progress',
      'completed'           => 'Ideas - Completed',
      'gathering-feedback'  => 'Ideas - Gathering Feedback',
    },
  },
  problem   => {
    name  => 'problem',
    title => 'Add a New Problem',
    icon  => 'fa-bug',
    status  => {
      ''              => 'All Problems',
      'known-problem' => 'Problems - Known Problem',
      'declined'      => 'Problems - Declined',
      'solved'        => 'Problems - Solved',
      'in-progress'   => 'Problems - In Progress',
    },
  },
  question  => {
    name  => 'question',
    title => 'Ask a New Question',
    icon  => 'fa-question',
    status  => {
      ''            => 'All Questions',
      'need-answer' => 'Questions - Need Answer',
      'answered'    => 'Questions - Answered',
    },
  },
  thank     => {
    name  => 'thank',
    title => 'Say Thanks',
    icon  => 'fa-trophy',
    status  => {
      ''      => 'All Thanks',
      'noted' => 'Thanks - Noted',
    },
  },
};



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
# ENGAGE
#

sub index {
  my $self = shift;

  my $type = $self->param('type') // '';
  my $status = $self->param('status') // '';

  my $cache = Canvas::Store::Post->search_type_status_and_tags(
    type      => filter_valid_types( $self->param('type') ),
    status    => $self->param('status') // '',
    tags      => $self->param('tags')   // '',
    page_size => 20,
    page      => $self->param('page'),
  );

  $self->stash(
    responses => $cache,
    filter    => TYPE_MAP->{ $type }{ status }{ $status },
  );
  $self->render('website/engage');
}

sub engage_syntax_get {
  my $self = shift;

  $self->render('website/engage-syntax-help');
}

sub engage_post_prepare_add_get {
  my $self = shift;

  my $type = $self->param('type');
  my $title = $self->param('title') // $self->flash('title') // '';
  my $content = $self->flash('content') // '';
  my $tags = $self->flash('tags') // '';

  # ensure it's a valid type
  return $self->redirect_to('/support/engage') unless grep { $_ eq $type } qw(idea problem question thank);

  # only allow authenticated and authorised users
  return $self->redirect_to('/support/engage') unless (
    $self->is_user_authenticated()
  );

  $self->stash(
    type    => TYPE_MAP->{ $type },
    title   => $title,
    content => $content,
    tags    => $tags,
  );

  $self->render('website/engage-new');
}
sub engage_post_add_post {
  my $self = shift;

  # only allow authenticated and authorised users
  return $self->redirect_to('/support/engage') unless $self->is_user_authenticated;

  my $type      = $self->param('type');
  my $title     = trim $self->param('title');
  my $content   = trim $self->param('content');
  my $tag_list  = trim $self->param('tags');

  $self->flash(
    title   => $title,
    content => $content,
    tags    => $tag_list,
  );

  # ensure it's a valid type
  unless( grep { $_ eq $type } qw(idea problem question thank) ) {
    return $self->redirect_to('/support/engage')
  }

  # ensure we have some sane title (at least 16 characters)
  unless( length $title >= 16 ) {
    $self->flash( page_errors => 'Your title lacks a little description. Pleast use at least least 16 characters.' );
    return $self->redirect_to( 'supportengagetypeadd', type => $type );
  }

  # ensure we have some sane content (at least 16 characters)
  unless( length $content >= 16 ) {
    $self->flash( page_errors => 'Your content lacks a little description. Pleast use at least least 16 characters to convey something meaningful.' );
    return $self->redirect_to( 'supportengagetypeadd', type => $type );
  }

  my %tags = map { sanitise_with_dashes( trim $_ ) => 1 } split /[ ,]+/, $tag_list;

  # ensure we have some at least one tag
  unless( keys %tags ) {
    $self->flash( page_errors => 'Your post will be a lot easier to find with tags added. Please add at least one tag.' );
    return $self->redirect_to( 'supportengagetypeadd', type => $type );
  }


  my $now = gmtime;
  my $stub = sanitise_with_dashes( $title );

  # enforce max stub size
  $stub = substr $stub, 0, 128 if length( $stub ) > 128;

  # check for existing stubs and append the ID + 1 of the last
  my( @e ) = Canvas::Store::Post->search({ type => $type, name => $stub });

  $stub .= '-' . ( $e[-1]->id + 1 ) if @e;

  # create the post
  my $p = Canvas::Store::Post->create({
    name         => $stub,
    type         => $type,
    status       => ( $type eq 'question' ) ? 'need-answer' : '',
    title        => $title,
    content      => $content,
    author_id    => $self->auth_user->id,
    created      => $now,
    updated      => $now,
  });

  # create the tags
  foreach my $tag ( keys %tags ) {
    $tag = trim $tag;
    my $t  = Canvas::Store::Tag->find_or_create({ name => $tag });
    my $pt = Canvas::Store::PostTag->find_or_create({
      post_id => $p->id,
      tag_id  => $t->id
    });
  }

  # undo our flash since we succeeded
  $self->flash(
    content => '',
  );

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

sub engage_post_detail_get {
  my $self = shift;
  my $stub = $self->param('stub');
  my $type = $self->param('type');

  # could have flashed 'content' from an attempted reply
  my $content = $self->flash('content') // '';

  my $p = Canvas::Store::Post->search({ type => $type, name => $stub })->first;

  # check we found the post
  return $self->redirect_to('/support/engage') unless defined $p;

  my $a = $p->accepted_reply;

  my $r = $p->search_replies(
    page_size => 20,
    page      => $self->param('page'),
  );

  # allow path to get back here
  $self->flash( redirect_url => $self->url_with );

  $self->stash( response => $p, accepted => $a, replies => $r, content => $content );
  $self->render('website/engage-detail');
}

sub engage_post_edit_get {
  my $self = shift;

  my $stub = $self->param('stub');
  my $type = $self->param('type');
  my $p = Canvas::Store::Post->search({ type => $type, name => $stub })->first;

  # check we found the post
  return $self->redirect_to('/support/engage') unless defined $p;

  # only allow authenticated and authorised users
  return $self->redirect_to('/support/engage') unless (
    $self->engage_post_can_edit( $p )
  );

  my @r = Canvas::Store::Post->replies( $stub );

  $self->stash( post => $p, replies => \@r );

  $self->render('website/engage-edit');
}

sub engage_post_edit_post {
  my $self = shift;

  my $stub = $self->param('stub');
  my $type = $self->param('type');
  my $p = Canvas::Store::Post->search({ type => $type, name => $stub })->first;

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

  $self->redirect_to( 'supportengagetypestub', type => $type, stub => $stub );
}

sub engage_post_subscribe_any {
  my $self = shift;

  my $stub = $self->param('stub');
  my $type = $self->param('type');

  my $url = $self->url_for('supportengagetypestub', type => $type, stub => $stub);

  # redirect unless we're actively auth'd
  return $self->redirect_to( $url ) unless $self->is_active_auth;

  my $p = Canvas::Store::Post->search({ type => $type, name => $stub })->first;

  # check we found the post
  return $self->redirect_to('/support/engage') unless defined $p;

  # subscribe (engage_subscriptions)
  Canvas::Store::UserMeta->find_or_create({
    user_id     => $self->auth_user->id,
    meta_key    => 'engage_subscriptions',
    meta_value  => $p->id,
  });

  $self->redirect_to( $url );
}

sub engage_post_unsubscribe_any {
  my $self = shift;

  my $stub = $self->param('stub');
  my $type = $self->param('type');


  my $url = $self->url_for('supportengagetypestub', type => $type, stub => $stub);

  # redirect unless we're actively auth'd
  return $self->redirect_to( $url ) unless $self->is_active_auth;

  my $p = Canvas::Store::Post->search({ type => $type, name => $stub })->first;

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

  $self->redirect_to( $url );
}


sub engage_reply_post {
  my $self = shift;

  my $type = $self->param('type');
  my $stub = $self->param('stub');
  my $redirect_url = $self->param('redirect_url') // $self->url_for('supportengagetypestub', type => $type, stub => $stub);

  # only allow authenticated and authorised users
  return $self->redirect_to('/support/engage') unless(
    $self->is_user_authenticated && defined $self->auth_user
  );

  my $subscribe = $self->param('subscribe') // 0;
  my $content = $self->param('content') // '';

  # ensure we have content
  unless( length( trim $content ) >= 16 ) {
    $self->flash( content => $content );

    $self->flash( page_errors => 'Your reply lacks a little description. Pleast use at least least 16 characters to convey something meaningful.' );
    return $self->redirect_to( $redirect_url );
  }

  my $p = Canvas::Store::Post->search({ type => $type, name => $stub })->first;

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
      # don't send a notification to the author of the reply
      next if( $_um->user_id->username eq $r->author_id->username);

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
  $self->redirect_to( $redirect_url );
}

sub engage_reply_accept_any {
  my $self = shift;

  my $type    = $self->param('type');
  my $stub    = $self->param('stub');
  my $id      = $self->param('id');
  my $content = $self->param('content');

  my $r = Canvas::Store::Post->search({
    type  => 'reply',
    id    => $id,
  })->first;

  # ensure we have edit capabilities
  return $self->redirect_to( 'supportengagetypestub', type => $type, stub => $stub ) unless $self->engage_post_can_accept( $r );

  $r->status( 'accepted' );
  $r->update;

  # redirect to the detail
  $self->redirect_to( 'supportengagetypestub', type => $type, stub => $stub );
}

sub engage_reply_unaccept_any {
  my $self = shift;

  my $type    = $self->param('type');
  my $stub    = $self->param('stub');
  my $id      = $self->param('id');
  my $content = $self->param('content');

  my $r = Canvas::Store::Post->search({
    type  => 'reply',
    id    => $id,
  })->first;

  # ensure we have edit capabilities
  return $self->redirect_to( 'supportengagetypestub', type => $type, stub => $stub ) unless $self->engage_post_can_unaccept( $r );

  $r->status( '' );
  $r->update;

  # redirect to the detail
  $self->redirect_to( 'supportengagetypestub', type => $type, stub => $stub );
}

sub engage_reply_edit_get {
  my $self = shift;

  my $id = $self->param('id');
  my $type = $self->param('type');
  my $stub = $self->param('stub');
  my $redirect_url = $self->flash('redirect_url') // $self->url_for('supportengagetypestub', type => $type, stub => $stub);


  my $r = Canvas::Store::Post->search({
    type  => 'reply',
    id    => $id,
  })->first;

  return $self->redirect_to( $redirect_url ) unless $self->engage_post_can_edit( $r );

  my $content = $self->flash('content') // $r->content;

  $self->stash( reply => $r, content => $content, redirect_url => $redirect_url );

  $self->render('website/engage-reply-edit');
}

sub engage_reply_edit_post {
  my $self = shift;

  my $content = $self->param('content');
  my $id      = $self->param('id');
  my $type    = $self->param('type');
  my $stub    = $self->param('stub');

  my $redirect_url = $self->param('redirect_url') // $self->url_for('supportengagetypestub', type => $type, stub => $stub);


  # ensure edits maintain some context
  unless( length( trim $content ) >= 16 ) {
    $self->flash( content => $content,);
    $self->flash( page_errors => 'Your editted reply lacks a little description. Pleast use at least least 16 characters to convey something meaningful.' );
    return $self->redirect_to( $self->url_with );
  }

  my $r = Canvas::Store::Post->search({
    type  => 'reply',
    id    => $id,
  })->first;

  # ensure we have edit capabilities
  return $self->redirect_to( $redirect_url ) unless $self->engage_post_can_edit( $r );

  $r->content( $content );
  $r->update;

  # redirect to the detail
  $self->redirect_to( $redirect_url );
}

sub engage_post_delete_any {
  my $self = shift;

  my $type = $self->param('type');
  my $stub = $self->param('stub');

  my $p = Canvas::Store::Post->search({ type => $type, name => $stub })->first;

  # only allow authenticated and authorised users
  return $self->redirect_to('/support/engage') unless $self->engage_post_can_delete( $p );

  $p->delete;

  $self->redirect_to('/support/engage');
}

sub engage_reply_any {
  my $self = shift;

  my $quote = {};

  if( $self->is_user_authenticated ) {
    my $type = $self->param('type');
    my $stub = $self->param('stub');
    my $id   = $self->param('id');

    my $r = Canvas::Store::Post->search({ id => $id })->first;

    if( grep { $_ eq $r->type } qw(reply thank idea question problem) ) {
      $quote = {
        author  => $r->author_id->username,
        content => $r->content,
      };
    }
  }

  $self->render( json => $quote );
}


sub engage_reply_delete_any {
  my $self = shift;

  my $type = $self->param('type');
  my $stub = $self->param('stub');
  my $id   = $self->param('id');

  my $r = Canvas::Store::Post->search({ type => 'reply', id => $id, })->first;

  # only allow authenticated and authorised users
  return $self->redirect_to('/support/engage') unless $self->engage_post_can_delete( $r );

  $r->delete;

  # redirect to the detail
  $self->redirect_to( 'supportengagetypestub', type => $type, stub => $stub );
}

1;
