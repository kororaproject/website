#!/usr/bin/perl
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

#
# LOCAL INCLUDES
#
use Canvas::About;
use Canvas::Site;

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
  # AUTHENTICATION
  $self->plugin('authentication' => {
    autoload_user => 0,
    current_user_fn => 'authenticated_user',
    load_user => sub {
      my ($app, $uid) = @_;

      return {
        wpu => Canvas::Store::WPUser->retrieve( user_login => $uid ),
        u   => Canvas::Store::User->search( name => $uid )->first,
      };
    },
    validate_user => sub {
      my ($app, $user, $pass, $extradata) = @_;

      my $wpu = Canvas::Store::WPUser->retrieve( user_login => $user );
      my( $u ) = Canvas::Store::User->search( name => $user );

      if( defined($u) && defined($wpu) && $wpu->validate_password($pass) ) {
        return $wpu->user_login;
      };

      return undef;
    },
  });

  #
  # HELPERS
  $self->helper(build_query  => sub {
    my $self = shift;
    my $map = shift;

    return {} unless( ref( $map ) eq 'HASH' );

    my $q = {};

    while( my ( $k, $v ) = each %{ $map } ) {
      foreach my $r ( @{ $v } ) {
        $q->{ $k } = $self->param( $r ) if defined( $self->param( $r ) );
      }
    }

    return $q;
  });

  $self->helper(post_content => sub {
    my( $self, $content ) = @_;

    my $result = $content; # '<pre>' . $content . '</pre>';
    #

    # remove newlines immediately proceeding tags
#    say Dumper $result;
    $result =~ s/(?:\r?\n)?(<\/?(?:p|li|ol|ul)>)\s*(?:\r?\n)?/$1/img;
#    say Dumper $result;
#    $result =~ s/(<\/?(?:p|li|ol|ul)>)\s*\r?\n/$1/ig;





    # process no attribute tags
    $result =~ s/\[(i|code|b)\]/<$1>/mg;
    $result =~ s/\[\/(i|code|b)\]/<\/$1>/mg;

    # process urls
    $result =~ s/\[url\]([^\[]+)\[\/url\]/<a href="$1">$1<\/a>/ig;
    $result =~ s/\[url="([^"]+)"\]([^\[]+)\[\/url\]/<a href="$1">$2<\/a>/mig;
    $result =~ s/((?:ht|f)tps?:\/\/[^\s]+)/<a href="$1">$1<\/a>/ig;

    # process images
    $result =~ s/\[img\]([^\[]+)\[\/img\]/<img class="img-responsive" src="$1"><\/img>/mig;

    # compress multiple breaks into one
    #$result =~ s/(<br\/>)+/<br\/>/g;

    # process quotes
    $result =~ s/\[quote(:[a-zA-Z0-9]+)?\]/<blockquote>/mg;
    $result =~ s/\[quote="([^"]+)"\]/<cite>$1 wrote:<\/cite><blockquote>/mg;
    $result =~ s/\[\/quote(:[a-zA-Z0-9]+)?\]/<\/blockquote>/mg;


    # turn newlines into breaks
    #$result =~ s/(\r?\n>)+/[n]/g;
#  $result =~ s/(\r?\n|<br\s?\/?>)+/\n\n/mg;
#    $result =~ s/^(\r?\n|<br\s?\/?>)+/\n/mg;
#    $result =~ s/(\r?\n|<br\s?\/?>)+/<br\/>/g;
    #$result =~ s/(<br\s?\/?>)+/<br\/>/g;
    my @lines = split /(\r?\n)+/, $result;
    #my @lines = split /(\r?\n|<br\s?\/?>)+/, $result;
    say Dumper map { "<p>$_</p>" } grep { ! /\n/ } @lines;

    # strip empty paragraphs
    $result =~ s/<p>\s*<\/p>//ig;


    return Mojo::ByteStream->new( $result );
  });

  #
  # ROUTES
  my $r = $self->routes;

  $r->get('/')->to('site#index');

  # about pages
  $r->get('/about')->to('about#index');
  $r->get('/about/why-fedora')->to('about#why_fedora');
  $r->get('/about/whats-inside')->to('about#whats_inside');
  $r->get('/about/team')->to('about#team');
  $r->get('/about/roadmap')->to('about#roadmap');

  # discover pages
  $r->get('/discover')->to('discover#index');
  $r->get('/discover/gnome')->to('discover#gnome');
  $r->get('/discover/kde')->to('discover#kde');
  $r->get('/discover/cinnamon')->to('discover#cinnamon');
  $r->get('/discover/mate')->to('discover#mate');

  # support pages
  $r->get('/support')->to('support#index');
  $r->get('/support/irc')->to('support#irc');
  $r->get('/support/howto')->to('support#howto');

  $r->get('/support/forums')->to('forum#forums');
  $r->get('/forum/:name')->to('forum#forum_name');
  $r->get('/topic/:name')->to('forum#topic_name');

  # download pages
  $r->get('/download')->to('site#download');

  # news pages
  $r->get('/news')->to('news#index');
  $r->get('/news/:id')->to('news#post');


  $r->any('/authenticate')->to('site#auth');
  $r->any('/deauthenticate')->to('site#deauth');

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


  # catch all
  $r->get('/(*trap)')->to('site#index');
}

1;
