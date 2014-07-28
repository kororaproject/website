#!/usr/bin/perl
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
package Canvas;

use warnings;
use strict;

use Mojo::Base 'Mojolicious';

#
# PERL INCLUDES
#
use Data::Dumper;

use Mojo::ByteStream;
use Mojo::JSON;
use Mojolicious::Plugin::Authentication;
use Mojolicious::Plugin::Cache;
use Mojolicious::Plugin::JSONConfig;
use Mojolicious::Plugin::Mail;

use POSIX qw(floor);
use Time::Piece;

#
# LOCAL INCLUDES
#
use Canvas::Store::User;
use Canvas::Util::PayPal;

#
# CONSTANTS
#
use constant {
  DEBUG   => 1
};


#
# INITIALISE
#
sub startup {
  my $self = shift;

  #
  # CONFIGURATION
  my $config = $self->plugin('JSONConfig' => {
    file => './canvas.conf',
  });

  # set the secret
  die "Ensure secrets are specified in config." unless ref $config->{secret} eq 'ARRAY';
  $self->secrets( $config->{secret} );

  #
  # HYPNOTOAD
  $self->app->config(hypnotoad => $config->{hypnotoad} // {} );

  #
  # CACHE
  $self->plugin('Cache' => $config->{cache} // {} );

  # set default session expiration to 4 hours
  $self->sessions->default_expiration(14400);

  #
  # AUTHENTICATION
  $self->app->log->info('Loading authentication handler.');
  $self->plugin('authentication' => {
    autoload_user   => 0,
    current_user_fn => 'auth_user',
    load_user       => sub {
      my( $app, $uid ) = @_;

      return Canvas::Store::User->search( username => $uid )->first;
    },
    validate_user   => sub {
      my( $app, $user, $pass, $extra ) = @_;

      my $u = Canvas::Store::User->search( username => $user )->first;

      if( defined($u) && $u->status eq 'active' && $u->validate_password($pass)  ) {
        return $u->username;
      };

      return undef;
    },
  });

  #
  # MAIL
  unless( $config->{mail} && ( $config->{mail}{mode} // '') eq 'production' ) {
    $self->app->log->info('Loading dummy mail handler for non-production testing.');

    $self->helper('mail' => sub {
      shift->app->log->debug('Sending an email ' . join "\n", @_);
    });
  }
  else {
    $self->app->log->info('Loading production mail handler.');
    $self->plugin('mail' => {
      type => 'text/plain',
    });
  }

  #
  # HELPERS
  $self->app->log->info('Loading page helpers.');
  $self->plugin('Canvas::Helpers');
  $self->plugin('Canvas::Helpers::Profile');

  #
  # PAYPAL

  # prepare the PayPal transaction information
  my $pp_context = Canvas::Util::PayPal->new(
    caller_user      => $config->{paypal}{caller_user},
    caller_password  => $config->{paypal}{caller_password},
    caller_signature => $config->{paypal}{caller_signature},
    url_base         => $config->{paypal}{url_base},
    mode             => $config->{paypal}{mode},
  );

  $self->cache->set(pp_context => $pp_context);

  #
  # ROUTES
  my $r = $self->routes;

  $r->get('/')->to('core#index');

  #
  # exception/not_found
  $r->get('/404')->to('core#not_found_get');
  $r->get('/500')->to('core#exception_get');

  $r->get('/templates')->to('template#index_get');
  $r->get('/template/:user')->to('template#summary_get');
  $r->get('/template/:user/:name')->to('template#detail_get');


  # authentication and registration
  $r->any('/authenticate')->to('core#authenticate_any');
  $r->any('/deauthenticate')->to('core#deauthenticate_any');
  $r->get('/register')->to('core#register_get');
  $r->post('/register')->to('core#register_post');
  $r->get('/registered')->to('core#registered_get');
  $r->get('/activate/:username')->to('core#activate_get');
  $r->post('/activate/:username')->to('core#activate_post');
  $r->get('/activated')->to('core#activated');
  $r->post('/forgot')->to('core#forgot_post');


  # profile pages
  $r->get('/profile/admin')->to('profile#profile_admin_get');
  $r->post('/profile/status')->to('profile#profile_status_post');
  $r->get('/profile/:name')->to('profile#profile_get');
  $r->get('/profile/:name/reset')->to('profile#profile_reset_password_get');
  $r->post('/profile/:name/reset')->to('profile#profile_reset_password_post');

  #
  # CANVAS API ROUTES
  my $r_api = $r->under('/api');

  $r_api->get('/packages')->to('core#packages_get');
  $r_api->get('/packages/latest')->to('core#packages_latest_get');
  $r_api->get('/package/:id')->to('core#package_id_get');
  $r_api->put('/package/:id')->to('core#package_id_put');
  $r_api->delete('/package/:id')->to('core#package_id_del');

  $r_api->get('/users')->to('core#users_get');
  $r_api->get('/user/:id')->to('core#user_id_get');
  $r_api->get('/user/:id/memberships')->to('core#user_id_memberships_get');

  $r_api->get('/repositories')->to('core#repositories_get');
  $r_api->post('/repositories')->to('core#repositories_post');
  $r_api->get('/repository/:id')->to('core#repository_id_get');

  $r_api->get('/templates')->to('core#templates_get');
  $r_api->post('/templates')->to('core#templates_post');
  $r_api->get('/template/:id')->to('core#template_id_get');
  $r_api->put('/template/:id')->to('core#template_id_put');
  $r_api->delete('/template/:id')->to('core#template_id_del');

  $r_api->get('/user/:user/template/:name')->to('core#user_user_template_name_get');
  $r_api->put('/user/:user/template/:name')->to('core#user_user_template_name_put');
  $r_api->delete('/user/:user/template/:name')->to('core#user_user_template_name_del');
}

1;
