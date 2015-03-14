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
package Website::Site;

use warnings;
use strict;

use Mojo::Base 'Mojolicious::Controller';

#
# PERL INCLUDES
#
use Data::Dumper;
use Mojo::Util qw(url_escape url_unescape);
use Time::Piece;
use Time::HiRes qw(gettimeofday);

#
# LOCAL INCLUDES
#

#
# controller handlers
#
sub index {
  my $c = shift;

  $c->render_steps('website/index', sub {
    my $delay = shift;

    # get latest news
    $c->pg->db->query("SELECT p.*, ARRAY_AGG(t.name) AS tags, u.username, u.email FROM posts p JOIN users u ON (u.id=p.author_id) LEFT JOIN post_tag pt ON (pt.post_id=p.id) LEFT JOIN tags t ON (t.id=pt.tag_id) WHERE p.type='news' AND p.status='publish' GROUP BY p.id, u.username, u.email ORDER BY p.created DESC LIMIT 1" => $delay->begin);
  },
  sub {
    my ($delay, $err, $res) = @_;

    $c->stash(news => $res->hash);
  });
}

sub exception_get {
  return shift->reply->exception('render_only');
}

sub not_found_get {
  return shift->reply->not_found;
}

sub forums_get {
  shift->redirect_to('/support/engage');
}

sub discover {
  shift->render('website/discover');
}

sub login {
  shift->render('website/login');
}

sub oauth {
  my $c = shift;

  my $provider = $c->param('provider');
  my $data = $c->req->json // {};

  my $rt     = $c->flash('rt');
  my $rt_url = $rt ? $c->ub64_decode($rt) : '/';

  return $c->redirect_to($rt_url) unless grep {$_ eq $provider} qw(email github);

  $c->delay(
    sub {
      my $delay = shift;
      my $args = {redirect_uri => $c->url_for('oauth/github')->to_abs};

      $c->oauth2->get_token($provider => $args, $delay->begin);
    },
    sub {
      my ($delay, $err, $token, $data) = @_;

      # store token to session
      $c->session(oauth => $data);
      $c->flash(rt => $rt);

      # abort
      if ($err) {
        $c->flash(page_errors => 'OAuth provider error. ' . $err);
        return $c->redirect_to($rt_url);
      }

      # if auth'd then link oauth with existing account
      if ($c->users->is_active) {
        $c->users->oauth->link($provider, $data);
        return $c->redirect_to($rt_url);
      }
      # else attempt auth
      else {
        return $c->redirect_to($rt_url) if $c->authenticate(undef, undef, $data);
      }

      # otherwise proceed to registration / profile page
      return $c->redirect_to('activateprovider', provider => $provider);
    }
  );
}

sub authenticate_any {
  my $c = shift;
  my $data = $c->req->json;

  # collect first out of the parameters and then json decoded body
  my $user = $c->param('u') // $data->{u} // '';
  my $pass = $c->param('p') // $data->{p} // '';

  # extract the redirect url and fall back to the index
  my $url = $c->param('rt') // $data->{rt};
  $url = defined $url ? $c->ub64_decode($url) : '/';

  unless ($c->authenticate($user, $pass)) {
    $c->flash( page_errors => 'The username or password was incorrect. Perhaps your account has not been activated?' );
  }

  return $c->redirect_to($url);
};

sub deauthenticate_any {
  my $c = shift;

  my $format = $c->stash('format') // 'html';

  $c->logout;

  return $c->render(status => 200, json => 'Done!') if $format eq 'json';

  # extract the redirect url and fall back to the index
  my $url = $c->param('rt');
  $url = defined $url ? $c->ub64_decode($url) : '/';

  return $c->redirect_to($url);
};

sub activated {
  my $c = shift;

  my $username = $c->flash('username') // 'foo';

  #return $c->redirect_to('/') unless defined $username;

  $c->stash(username => $username);

  $c->render('website/activated');
}

sub activate_get {
  my $c = shift;

  my $oauth    = $c->session('oauth');
  my $provider = $c->param('provider');
  my $rt       = $c->param('rt');
  my $rt_url   = $rt ? $c->ub64_decode($rt) : '/';
  my $username = $c->param('username') // '';

  # email activiation
  if ($provider eq 'email') {
    my $token = $c->param('token');

    # lookup the requested account for activation
    # TODO: add token confirmation check (ie we have an activation token)
    my $u = $c->pg->db->query("SELECT * FROM users WHERE username=? LIMIT 1", $username)->hash;

    # redirect to home unless account and activation token suffix exists
    return $c->redirect_to('/') unless $u && $token;

    $c->stash(username => $username, email => $u->{email}, realname => '');
  }
  elsif ($provider eq 'github' and (my $github = $oauth->{$provider})) {
    $c->stash(
      avatar_url => $github->{avatar_url},
      email      => $github->{email},
      realname   => $github->{name},
      username   => $github->{login},
    );
  }
  else {
    return $c->redirect_to('/');
  }

  my $error = $c->flash('error') // { code => 0, message => '' };

  $c->stash(
    error    => $error,
    rt       => $rt,
    rt_url   => $rt_url,
    provider => $provider,
  );

  $c->render('website/activate');
}

sub activate_post {
  my $c = shift;

  my $provider = $c->param('provider');
  my $username = $c->param('username');
  my $realname = $c->param('realname');
  my $url = $c->param('redirect_to') // '/';

  my $oauth = $c->session('oauth');
  my $activation = {};

  if ($provider eq 'email') {
    my $prefix = $c->param('prefix');
    my $suffix = $c->param('token');

    $activation->{email} = {
      prefix   => $prefix,
      realname => $realname,
      suffix   => $suffix,
      username => $username,
    };
  }
  elsif ($provider eq 'github') {
    if (my $github = $oauth->{github}) {
      my $email = $c->param('email');
      my $github = $oauth->{github};

      $activation->{github} = {
        email      => $email,
        oauth_user => $github->{login},
        realname   => $realname,
        username   => $username,
      };
    }
  }

  if (my $u = $c->users->account->activate($activation)) {
    # subscribed "registration event" notifications
    $c->notify_users(
      'user_notify_on_activate',
      'admin@kororaproject.org',
      'Korora Project - Prime Activation - Success',
      "The following Prime account has successfully been activated:\n" .
      " - username: " . $u->{username} . "\n" .
      " - email:    " . $u->{email} . "\n\n" .
      "Regards,\n" .
      "The Korora Team.\n"
    );

    $c->authenticate(undef, undef, {activated => {username => $u->{username}}});

    $c->flash(username => $u->{username});

    $c->redirect_to('/activated');
  }

  $c->redirect_to('/');
}

sub forgot_post {
  my $c = shift;

  my $email    = $c->param('email');
  my $rt       = $c->param('rt');
  my $rt_url   = $rt ? $c->ub64_decode($rt) : '/';
  my $username = $c->param('username');

  if ($c->users->account->forgot($username, $email)) {
    $c->flash(page_info => 'An email with further instructions has been sent to: ' . $email);
  }

  $c->redirect_to($rt_url);
}

sub registered_get {
  my $c = shift;

  my $rt     = $c->param('rt') // $c->flash('rt');
  my $rt_url = $rt ? $c->ub64_decode($rt) : '/';

  $c->stash(rt => $rt, rt_url => $rt_url);
  $c->render('website/registered');
}

sub register_get {
  my $c = shift;

  my $error  = $c->flash('error') // { code => 0, message => '' };
  my $rt     = $c->param('rt') // $c->flash('rt');
  my $values = $c->flash('values') // { user => '', email => '' };

  $c->flash(rt => $rt);

  my $rt_url = $rt ? $c->ub64_decode($rt) : '/';

  $c->stash(
    error  => $error,
    rt     => $rt,
    rt_url => $rt_url,
    values => $values,
  );

  $c->render('website/register');
}

sub register_post {
  my $c = shift;

  # extract the redirect url and fall back to the index
  my $url = $c->param('redirect_to') // '/';

  # grab registration details
  my $email        = $c->param('email');
  my $pass         = $c->param('pass');
  my $pass_confirm = $c->param('confirm');
  my $user         = $c->param('user');

  # flash the redirect and previous values for future redirects
  $c->flash(
    rt => $url,
    values => {user => $user, email => $email}
  );

  my $registration = {
    email => {
      email        => $email,
      password     => $pass,
      pass_confirm => $pass_confirm,
      username     => $user,
    }
  };

  return $c->redirect_to('/register') unless $c->users->account->register($registration);

  $c->redirect_to('/registered');
}


#
# CATCH ALL
sub archive_forward_any {
  my $self = shift;

  my $path = $self->url_for->host('archive.kororaproject.org');

  $self->redirect_to( $path );
};

1;
