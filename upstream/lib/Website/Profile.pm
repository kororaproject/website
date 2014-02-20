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
package Website::Profile;

use warnings;
use strict;

use Mojo::Base 'Mojolicious::Controller';

#
# PERL INCLUDES
#
use Data::Dumper;
use POSIX qw(ceil);


#
# CONTROLLER HANDLERS
#

sub profile_get {
  my $self = shift;

  return $self->redirect_to('/') unless $self->is_user_authenticated;

  my $u = Canvas::Store::User->search({
    username  => $self->param('name'),
  })->first;

  return $self->redirect_to('/') unless defined $u;

  $self->stash( user => $u );
  $self->render('website/profile');
}

sub profile_reset_password_get {
  my $self = shift;

  my $user = $self->param('name');

  # lookup the requested account for activation
  my $u = Canvas::Store::User->search({ username => $user })->first;

  my $token = $u->metadata('password_reset_token');

  # redirect to home unless account and activation token suffix exists
  return $self->redirect_to('/') unless(
    defined $u &&
    defined $token &&
    $token eq $self->param('token')
  );

  $self->stash(
    values  => { user => $user },
  );

  $self->render('website/forgot-password');
}

sub profile_reset_password_post {
  my $self = shift;

  # extract the redirect url and fall back to the index
  my $url           = $self->param('redirect_to') // '/';

  # grab reset details
  my $user          = $self->param('name');
  my $pass          = $self->param('pass');
  my $pass_confirm  = $self->param('confirm');

  # flash the redirect and previous values for future redirects
  $self->flash(
    redirect_to => $url,
    values      => { user => $user },
  );

  # lookup the requested account for activation
  my $u = Canvas::Store::User->search({ username => $user })->first;

  # check for token for if we're not logged on
  # indicates a "forgot password" invocation
  my $token;

  unless( $self->profile_can_change_password( $u ) ) {
    $token = $u->metadata('password_reset_token');

    # redirect unless account and activation token prefix/suffix exists
    return $self->redirect_to( $url ) unless(
      defined $u &&
      defined $token
    );
  }

  # build the supplied token and fetch the stored token
  my $token_supplied = $self->param('token') // '';

  # redirect to same page unless supplied and stored tokens match
  unless( $token eq $token_supplied ) {
    $self->flash( page_errors => 'Your token is invalid.' );

    return $self->redirect_to( $self->url_with );
  };

  # validate passwords have sufficient length
  if( length $pass < 8 ) {
    $self->flash( page_errors => 'Your password must be at least 8 characters long.');

    return $self->redirect_to( $self->url_with );
  }

  # validate passwords match
  if( $pass ne $pass_confirm ) {
    $self->flash( page_errors => 'Your passwords don\'t match.' );

    return $self->redirect_to( $self->url_with );
  };

  # update the password
  $u->password( $u->hash_password( $pass ) );
  $u->update;

  # clear token if it exists
  $u->metadata_clear('password_reset_token');

  $self->flash( page_success => 'Your password has been reset.' );

  $self->redirect_to( $url );
}

sub profile_status_post {
  my $self = shift;

  my $username = $self->param('name')   // '';
  my $email    = $self->param('email')  // '';

  my $result = {};

  if( length $username ) {
    my $u = Canvas::Store::User->search({
      username  => $username,
    })->first;

    $result->{username} = {
      key     => $username,
      status  => defined $u ? 1 : 0,
    };
  }

  if( length $email ) {
    my $e = Canvas::Store::User->search({
      email  => $email,
    })->first;

    $result->{email} = {
      key     => $email,
      status  => defined $e ? 1 : 0,
    }
  }


  $self->render( json => $result );
}

sub profile_admin_get {
  my $self = shift;

  # only allow authenticated and authorised users
  return $self->redirect_to('/') unless (
    $self->profile_user_can_add ||
    $self->profile_user_can_delete
  );

  my $pager = Canvas::Store::User->pager(
    order_by          => 'created DESC',
    entries_per_page  => 20,
    current_page      => ( $self->param('page') // 1 ) - 1,
  );

  my $profiles = {
    items       => [ $pager->search_where ],
    item_count  => $pager->total_entries,
    page_size   => $pager->entries_per_page,
    page        => $pager->current_page + 1,
    page_last   => ceil($pager->total_entries / $pager->entries_per_page),
  };

  $self->stash( profiles => $profiles );

  $self->render('website/profiles-admin');
}


1;
