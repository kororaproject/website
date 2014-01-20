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
package Canvas::Site;

use warnings;
use strict;

use Mojo::Base 'Mojolicious::Controller';

#
# PERL INCLUDES
#
use Data::Dumper;
use Mojo::Util qw(b64_encode url_escape url_unescape);
use Time::Piece;
use Time::HiRes qw(gettimeofday);
use Digest::SHA qw(sha512 sha256_hex);

#
# LOCAL INCLUDES
#
use Canvas::Store::User;
use Canvas::Store::UserMeta;
use Canvas::Store::WPUser;
use Canvas::Util qw(get_random_bytes);

#
# INTERNAL HELPERS
#

#
# create_auth_token()
#
sub create_auth_token {
  my $bytes = get_random_bytes(48);

  return sha256_hex( $bytes );
}


#
# controller handlers
#
sub index {
  my $self = shift;

  #return $self->redirect_to('login') unless( $self->is_user_authenticated );

  $self->render('index');
}

sub exception_get {
  return shift->render_exception('render_only');
}

sub not_found_get {
  return shift->render_not_found;
}

sub forums_get {
  shift->redirect_to('/support/engage');
}

sub discover {
  my $self = shift;

  $self->render('discover');
}

sub login {
  my $self = shift;

  $self->render('login');
}

sub authenticate_any {
  my $self = shift;
  my $json = Mojo::JSON->new;
  my $data = $json->decode($self->req->body);

  # collect first out of the parameters and then json decoded body
  my $user = $self->param('u') // $data->{u} // '';
  my $pass = $self->param('p') // $data->{p} // '';

  # extract the redirect url and fall back to the index
  my $url = $self->param('redirect_to') // $data->{redirect_to} // '/';

  # TODO: remove after 2 months and 2 weeks of live

  # attempt to find new backend user
  my $u = Canvas::Store::User->search({ username => $user })->first;

  # if now found fallback to WP backend detection
  unless( defined $u ) {
    my $wp = Canvas::Store::WPUser->search({ user_login => $user })->first;

    # start migration if a WP user is found and the password is valid
    if( defined $wp && $wp->validate_password( $pass ) ) {

      # create new user based on WP details
      $u = Canvas::Store::User->create({
        username  => $user,
        password  => $wp->user_pass,
        email     => $wp->user_email,
      });

      # generate activiation token
      my $token = create_auth_token;

      my $um = Canvas::Store::UserMeta->create({
        user_id     => $u->id,
        meta_key    => 'activation_token',
        meta_value  => $token,
      });

      my $activation_key = substr( $token, 0, 32 );
      my $activation_url = 'https://kororaproject.org/activate/' . $user . '?token=' . url_escape substr( $token, 32 );

      my $message = "" .
        "G'day,\n\n" .
        "Thank you for continuing to be a part of our Korora community.\n\n".
        "Your activiation key is: " . $activation_key . "\n\n" .
        "In order to activate your migrated Korora Prime account, copy your activation key and follow the prompts at: " . $activation_url . "\n\n" .
        "Please note that you must activate your account within 24 hours.\n\n" .
        "Regards,\n" .
        "The Korora Team.\n";

      # send the activiation email
      $self->mail(
        to      => $u->email,
        from    => 'admin@kororaproject.org',
        subject => 'Korora Project - Prime Registration',
        data    => $message,
      );

      # subscribed "new registration event" notifications
      $self->notify_users(
        'user_notify_on_register',
        'admin@kororaproject.org',
        'Korora Project - New Prime Registration/Transfer',
        "The following Prime account has just been registered and converted from the existing WordPress database:\n" .
        " - username: " . $u->username . "\n" .
        " - email:    " . $u->email . "\n\n" .
        "Regards,\n" .
        "The Korora Team.\n"
      );

      $self->flash( redirect_to => $url );

      return $self->redirect_to('/registered');
    }
  }

  # TODO: END

  unless( $self->authenticate($user, $pass) ) {
    $self->flash( page_errors => 'The username or password was incorrect. Perhaps your account has not been activated?' );
  }

  return $self->redirect_to( $url );
};

sub deauthenticate_any {
  my $self = shift;

  $self->logout;

  # extract the redirect url and fall back to the index
  my $url = $self->param('redirect_to') // '/';

  return $self->redirect_to( $url );
};

sub activated {
  my $self = shift;

  my $username = $self->flash('username');

  return $self->redirect_to( '/' ) unless defined $username;

  $self->stash( username => $username );
  $self->render('activated');
}

sub activate_get {
  my $self = shift;

  my $suffix = $self->param('token');
  my $username = $self->param('username');

  # lookup the requested account for activation
  my $u = Canvas::Store::User->search({ username => $username })->first;

  # redirect to home unless account and activation token suffix exists
  return $self->redirect_to('/') unless(
    defined $u &&
    defined $suffix
  );

  my $error = $self->flash('error') // { code => 0, message => '' };

  $self->stash(
    username    => $username,
    error       => $error
  );

  $self->render('activate');
}

sub activate_post {
  my $self = shift;

  my $username = $self->param('username');
  my $prefix = $self->param('prefix');
  my $suffix = $self->param('token');
  my $url = $self->param('redirect_to') // '/';

  # lookup the requested account for activation
  my $u = Canvas::Store::User->search({ username => $username })->first;

  # redirect unless account and activation token prefix/suffix exists
  return $self->redirect_to( $url ) unless(
    defined $u &&
    defined $prefix &&
    defined $suffix
  );

  # build the supplied token and fetch the stored token
  my $token_supplied = $prefix . url_unescape( $suffix );
  my $token = $u->metadata('activation_token') // '';

  # redirect to same page unless supplied and stored tokens match
  unless( $token eq $token_supplied ) {
    $self->flash( page_errors => 'Your token is invalid.' );
    return $self->redirect_to( $self->url_with('current') );
  };

  # remove activation if account age is more than 24 hours
  # and then return to redirect or home
  my $now = gmtime;
  if( ($now - $u->updated) > 86400 ) {
    $self->flash( page_errors => 'Activation of this account has been over 24 hours.' );

    # store username and email for notification before we delete
    my $username = $u->username;
    my $email = $u->email;

    $u->metadata_clear('activation_token');
    $u->delete;

    # subscribed "registration event" notifications
    $self->notify_users(
      'user_notify_on_activate',
      'admin@kororaproject.org',
      'Korora Project - Prime Activation - Time Expiry',
      "The following Prime account has exceeded it's activation time limit:\n" .
      " - username: " . $username . "\n" .
      " - email:    " . $email . "\n\n" .
      "The account has been deleted.\n\n" .
      "Regards,\n" .
      "The Korora Team.\n"
    );

    return $self->redirect_to( $url );
  }

  my $status = $u->status;

  $u->status('active');
  $u->update;

  $u->metadata_clear('activation_token');

  # subscribed "registration event" notifications
  $self->notify_users(
    'user_notify_on_activate',
    'admin@kororaproject.org',
    'Korora Project - Prime Activation - Success',
    "The following Prime account has successfully been activated:\n" .
    " - username: " . $u->username . "\n" .
    " - email:    " . $u->email . "\n\n" .
    "Regards,\n" .
    "The Korora Team.\n"
  );

  $self->flash( username => $username );

  $self->redirect_to('/activated');
}

sub forgot_post {
  my $self = shift;

  my $email = $self->param('email');

  # extract the redirect url and fall back to the index
  my $url = $self->param('redirect_to') // '/';

  # validate email address
  unless( $email =~ m/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/ ) {
    $self->flash( page_errors => 'Your email address is invalid.' );

    return $self->redirect_to( $url );
  }

  my $u = Canvas::Store::User->search({ email => $email })->first;

  # validate email is available, don't reveal email account information
  unless( defined $u ) {
    $self->flash( page_info => 'An email with further instructions has been sent to: ' . $email );

    return $self->redirect_to( $url );
  }

  # validate account is active, don't reveal email account information
  unless( $u->is_active_account ) {
    $self->flash( page_info => 'An email with further instructions has been sent to: ' . $email );

    return $self->redirect_to( $url );
  }

  # erase existing tokens
  $u->metadata_clear('password_reset_token');

  # generate activiation token
  my $token = create_auth_token;

  my $um = Canvas::Store::UserMeta->create({
    user_id     => $u->id,
    meta_key    => 'password_reset_token',
    meta_value  => $token,
  });

  my $activation_url = 'https://kororaproject.org/profile/' . $u->username . '/reset?token=' . url_escape $token;

  my $message = "" .
    "G'day,\n\n" .
    "You (or someone else) entered this email address when trying to change the password of a Korora Prime account.\n\n".
    "In order to reset the password for your Korora Prime account, continue on and follow the prompts at: " . $activation_url . "\n\n" .
    "Regards,\n" .
    "The Korora Team.\n";

  # send the activiation email
  $self->mail(
    to      => $email,
    from    => 'admin@kororaproject.org',
    subject => 'Korora Project - Prime Re-activation / Lost Password',
    data    => $message,
  );

  # subscribed "new registration event" notifications
  $self->notify_users(
    'user_notify_on_lostpass',
    'admin@kororaproject.org',
    'Korora Project - Prime Account - Lost Password',
    "The following Prime account has just been requested lost password re-activation:\n" .
    " - username: " . $u->username . "\n" .
    " - email:    " . $u->email . "\n\n" .
    "Regards,\n" .
    "The Korora Team.\n"
  );

  $self->flash( page_info => 'An email with further instructions has been sent to: ' . $email );
  $self->redirect_to( $url );
}

sub registered_get {
  my $self = shift;

  my $url  = $self->flash('redirect_to');

  return $self->redirect_to( '/' ) unless defined $url;

  $self->stash( redirect_to => $url );
  $self->render('registered');
}

sub register_get {
  my $self = shift;

  my $error = $self->flash('error') // { code => 0, message => '' };
  my $values = $self->flash('values') // { user => '', email => '' };
  my $url = $self->param('redirect_to') // ( $self->flash('redirect_to') // '' );

  $self->stash( error => $error, values => $values, redirect_to => $url );

  $self->render('register');
}

sub register_post {
  my $self = shift;

  # extract the redirect url and fall back to the index
  my $url = $self->param('redirect_to') // '/';

  # grab registration details
  my $user = $self->param('user');
  my $pass = $self->param('pass');
  my $pass_confirm = $self->param('confirm');
  my $email = $self->param('email');

  # flash the redirect and previous values for future redirects
  $self->flash(
    redirect_to => $url,
    values      => { user => $user, email => $email }
  );

  # validate username
  unless( $user =~ m/^[a-zA-Z0-9_]+$/ ) {
    $self->flash( error => { code => 1, message => 'Your username can only consist of alphanumeric characters and underscores only [A-Z, a-z, 0-9, _].' });

    return $self->redirect_to('/register');
  }

  # validate user name is available
  my $u = Canvas::Store::User->search({
    username => $user,
  })->first;

  if( defined $u ) {
    $self->flash( error => { code => 2, message => 'That username already exists.' } );

    return $self->redirect_to('/register');
  }

  # validate email address
  unless( $email =~ m/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/ ) {
    $self->flash( error => { code => 3, message => 'Your email address is invalid.' });

    return $self->redirect_to('/register');
  }

  # validate email is available
  if( defined Canvas::Store::User->search({ email => $email, })->first ) {
    $self->flash( error => { code => 4, message => 'That email already exists.' } );

    return $self->redirect_to('/register');
  }

  # validate passwords have sufficient length
  if( length $pass < 8 ) {
    $self->flash( error => { code => 5, message => 'Your password must be at least 8 characters long.' });

    return $self->redirect_to('/register');
  }

  # validate passwords match
  if( $pass ne $pass_confirm ) {
    $self->flash( error => { code => 6, message => 'Your passwords don\'t match.' } );

    return $self->redirect_to('/register');
  };

  $u = Canvas::Store::User->create({
    username  => $user,
    email     => $email,
  });

  if( defined $u ) {
    # store password as a salted hash
    $u->password( $u->hash_password( $pass ) );
    $u->update;

    # generate activiation token
    my $token = create_auth_token;

    my $um = Canvas::Store::UserMeta->create({
      user_id     => $u->id,
      meta_key    => 'activation_token',
      meta_value  => $token,
    });

    my $activation_key = substr( $token, 0, 32 );
    my $activation_url = 'https://kororaproject.org/activate/' . $user . '?token=' . url_escape substr( $token, 32 );

    my $message = "" .
      "G'day,\n\n" .
      "Thank you for registering to be part of our Korora community.\n\n".
      "Your activiation key is: " . $activation_key . "\n\n" .
      "In order to activate your Korora Prime account, copy your activation key and follow the prompts at: " . $activation_url . "\n\n" .
      "Please note that you must activate your account within 24 hours.\n\n" .
#      "If you have any questions regarding his process, click 'Reply' in your email client and we'll be only too happy to help.\n\n" .
      "Regards,\n" .
      "The Korora Team.\n";

    # send the activiation email
    $self->mail(
      to      => $email,
      from    => 'admin@kororaproject.org',
      subject => 'Korora Project - Prime Registration',
      data    => $message,
    );

    # subscribed "new registration event" notifications
    $self->notify_users(
      'user_notify_on_register',
      'admin@kororaproject.org',
      'Korora Project - New Prime Registration',
      "The following Prime account has just been registered:\n" .
      " - username: " . $u->username . "\n" .
      " - email:    " . $u->email . "\n\n" .
      "Regards,\n" .
      "The Korora Team.\n"
    );
  }

  $self->redirect_to('/registered');
}


#
# CATCH ALL
sub archive_forward_any {
  my $self = shift;

  my $path = $self->url_for->host('archive.kororaproject.org');

  $self->redirect_to( $path );
};

1;
