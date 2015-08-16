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
use Mojo::Pg;
use Mojolicious::Plugin::Authentication;
use Mojolicious::Plugin::Cache;
use Mojolicious::Plugin::Mail;
use Mojolicious::Plugin::OAuth2;
use Mojolicious::Plugin::RenderSteps;

use POSIX qw(floor);
use Time::Piece;

#
# LOCAL INCLUDES
#
use Canvas::Model::Templates;

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
  # OAUTH2
  $self->plugin(OAuth2 => $config->{oauth2} // {} );

  #
  # AUTHENTICATION
  $self->app->log->info('Loading authentication handler.');
  $self->plugin('authentication' => {
    autoload_user   => 0,
    current_user_fn => 'auth_user',
    load_user => sub {
      my ($app, $user) = @_;

      my $user_hash = $app->pg->db->query("SELECT * FROM users WHERE username=?", $user)->hash // {};

      # load metadata
      if ($user_hash->{id}) {
        $user_hash->{meta} = {};

        $user_hash->{oauth} = $app->session('oauth') // {};

        my $key_values = $app->pg->db->query("SELECT meta_key AS key, array_agg(meta_value) AS values FROM usermeta where user_id=? GROUP BY meta_key", $user_hash->{id})->hashes // {};

        $key_values->each(sub {
          my $e = shift;
          $user_hash->{meta}{$e->{key}} = $e->{values};
        });
      }

      return $user_hash;
    },
    validate_user => sub {
      my ($app, $user, $pass, $extra) = @_;

      # check user pass
      if ($user and $pass) {
        my $u = $app->pg->db->query("SELECT username, password FROM users WHERE username=?", $user)->hash;

        return $u->{username} if $app->users->validate($u, $pass);
      }
      # check github
      elsif (my $github = $extra->{github}) {
        my $u = $app->pg->db->query("SELECT u.username FROM users u JOIN usermeta um ON (um.user_id=u.id) WHERE um.meta_key='oauth_github' AND um.meta_value=?", $github->{login})->hash;

        return $u->{username} if $u;
      }
      # check activation
      elsif (my $activated = $extra->{activated}) {
        my $u = $app->pg->db->query("SELECT username FROM users WHERE username=?", $activated->{username})->hash;

        return $u->{username} if $u;
      }

      return undef;
    },
  });

  $self->plugin('RenderSteps');


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
  $self->plugin('Canvas::Helpers::User');

  #
  # MODEL
  $self->helper(pg => sub { state $pg = Mojo::Pg->new($config->{database}{uri}); });
  $self->helper('canvas.templates' => sub {
    state $posts = Canvas::Model::Templates->new(pg => shift->pg)
  });

  #
  # ROUTES
  my $r = $self->routes;

  #
  # CANVAS API ROUTES
  my $r_api = $r->under('/api');

  $r_api->get('/packages')->to('core#packages_get');
  $r_api->get('/packages/latest')->to('core#packages_latest_get');
  $r_api->get('/package/:id')->to('core#package_id_get');
  $r_api->put('/package/:id')->to('core#package_id_put');
  $r_api->delete('/package/:id')->to('core#package_id_del');

  $r_api->get('/repositories')->to('core#repositories_get');
  $r_api->post('/repositories')->to('core#repositories_post');
  $r_api->get('/repository/:id')->to('core#repository_id_get');

  $r_api->get('/templates')->to('core#templates_get');
  $r_api->post('/templates')->to('core#templates_post');
  $r_api->get('/template/:id')->to('core#template_id_get');
  $r_api->put('/template/:id')->to('core#template_id_update');
  $r_api->delete('/template/:id')->to('core#template_id_del');
  $r_api->get('/template/:id/includes')->to('core#template_id_includes_get');



  #
  # PRIMARY ROUTES

  # exception/not_found
  $r->get('/404')->to('core#not_found_get');
  $r->get('/500')->to('core#exception_get');

  # authentication and registration
  $r->any('/authenticate')->to('core#authenticate_any');
  $r->any('/deauthenticate')->to('core#deauthenticate_any');

  #
  if (0) {
    $r->get('/')->to('core#index');
    $r->get('/templates')->to('template#index_get');

    $r->get('/:user/template')->to('template#summary_get');
    $r->get('/:user/template/:name')->to('template#detail_get');
  }
  else {
    $r->get('/')->to('core#alpha');
    $r->any('/*trap' => {trap => ''} => sub { shift->redirect_to('/'); });
  }


}

1;
