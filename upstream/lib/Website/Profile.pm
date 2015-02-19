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
  my $c = shift;

  # TODO: what aspect of the profile should be public?
#  return $c->redirect_to('/') unless $c->is_user_authenticated;

  $c->render_steps('website/profile', sub {
    my $delay = shift;

    my $username = $c->param('name');

    # get paged items with username and email associated
    $c->pg->db->query("SELECT * FROM canvas_user WHERE username=?" => ($username) => $delay->begin);
  },
  sub {
    my ($delay, $err, $res) = @_;

    my $u = $res->hash;

    $delay->emit(redirect => '/') unless defined $u;

    $c->stash(user => $u);
  });
}

sub profile_reset_password_get {
  my $c = shift;

  my $user = $c->param('name');
  my $token = $c->param('token');

  # lookup the requested account for activation
  my $u = $c->pg->db->query("SELECT u.*, meta_key AS key FROM canvas_user u JOIN canvas_usermeta um ON (u.id=um.user_id) WHERE u.username=? AND key='password_reset_token'", $user)->hash;

  # redirect to home unless account and activation token suffix exists
  return $c->redirect_to('/') unless defined $u && $u->{token} eq $token;

  $c->stash(values => { user => $user });

  $c->render('website/forgot-password');
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
  my $c = shift;

  my $username = $c->param('name')   // '';
  my $email    = $c->param('email')  // '';

  my $result = {};

  my $r = $c->pg->db->query("SELECT id FROM canvas_user WHERE username=?", $username);

  $result->{username} = {
    key     => $username,
    status  => $r->rows,
  };

  say Dumper $result;

  $c->render(json => $result);
}

sub profile_admin_get {
  my $c = shift;

  # only allow authenticated and authorised users
  return $c->redirect_to('/') unless (
    $c->profile->can_add ||
    $c->profile->can_delete
  );

  my $page_size = 100;
  my $page = ($c->param('page') // 1);

  $c->render_steps('website/profiles-admin', sub {
    my $delay = shift;

    # get total count
    $c->pg->db->query("SELECT COUNT(id) FROM canvas_user" => $delay->begin);

    # get paged items with username and email associated
    $c->pg->db->query("SELECT id, username, email, status, created FROM canvas_user ORDER BY created DESC LIMIT ? OFFSET ?" => ($page_size, ($page-1) * $page_size) => $delay->begin);
  },
  sub {
    my ($delay, $count_err, $count_res, $err, $res) = @_;

    my $count = $count_res->array->[0];

    $c->stash(profiles => {
      items       => $res->hashes,
      item_count  => $count,
      page_size   => $page_size,
      page        => $page,
      page_last   => ceil($count / $page_size),
    });
  });
}

1;
