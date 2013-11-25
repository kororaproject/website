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

use POSIX qw(floor);
use Text::Markdown;
#use Text::MultiMarkdown;
use Time::Piece;

#
# LOCAL INCLUDES
#
use Canvas::About;
use Canvas::Site;
use Canvas::Store::User;

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

  $self->secret('canvas');

  #
  # AUTHENTICATION
  $self->plugin('authentication' => {
    autoload_user => 0,
    current_user_fn => 'auth_user',
    load_user => sub {
      my ($app, $uid) = @_;

      return Canvas::Store::User->search( username => $uid )->first;
    },
    validate_user => sub {
      my ($app, $user, $pass, $extradata) = @_;

      my $u = Canvas::Store::User->search( username => $user )->first;

      if( defined($u) && $u->validate_password($pass) ) {
        return $u->username;
      };

      return undef;
    },
  });

  $self->plugin('mail' => {
    from => 'firnsy@gmail.com',
    type => 'text/plain',
  });

  #
  # HELPERS
  $self->helper(build_query => sub {
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

  $self->helper(pluralise => sub {
    my( $self, $amount, $unit ) = @_;

    if( $amount ne '1' ) {
      $unit .= 's';
      $unit =~ s/os$/oes/;
      $unit =~ s/ys$/ies/;
    }

    return $amount . ' ' . $unit;
  });

  # time prettifier
  $self->helper(time_ago => sub {
    my( $self, $time ) = @_;

    my $now = gmtime;
    $time = Time::Piece->new( $time ) unless ref $time eq 'Time::Piece';

    my $d = $now - $time;
    my $t;
    my $u;

    return 'One moment ago' if ( $d < 60 );

    if( $d > 604800 ) {
      $t = floor( $d / 604800 );
      $u = 'week';
    }
    elsif( $d > 84600 ) {
      $t = floor( $d / 86400 );
      $u = 'day';
    }
    elsif( $d > 3600 ) {
      $t = floor( $d / 3600 );
      $u = 'hour';
    }
    else {
      $t = floor( $d / 60 );
      $u = 'minute';
    }

    return $self->pluralise( $t, $u ) . ' ago';
  });

  $self->helper(engage_icon => sub {
    my( $self, $type, $classes ) = @_;

    $classes //= '';

    my $map = {
      idea      => 'fa-lightbulb-o',
      problem   => 'fa-bug',
      question  => 'fa-question',
      thank     => 'fa-heart',
    };

    return '<i class="fa ' . ( $map->{ $type } // 'fa-ban' ) . ' ' . $classes . '"></i>';
  });

  $self->helper(render_post => sub {
    my( $self, $post ) = @_;

#    my $m = Text::MultiMarkdown->new(
    my $m = Text::Markdown->new(
      tab_width   => 2,
#      heading_ids => 0,
#      img_ids     => 0,
    );

    return $m->markdown( $post );
  });

  $self->helper(news_can_add => sub {
    my( $self ) = @_;

    return 0 unless defined $self->auth_user;

    return 0 unless $self->auth_user->is_active_account;

    return 1 if $self->auth_user->is_admin;

    return 0;
  });

  $self->helper(post_can_edit => sub {
    my( $self, $post ) = @_;

    return 0 unless ref $post eq 'Canvas::Store::Post';

    return 0 unless defined $self->auth_user;

    return 0 unless $self->auth_user->is_active_account;

    say "is active";

    return 1 if $self->auth_user->is_admin;

    return 1 if $self->auth_user->id == $post->author->id;

    return 0;
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

  $r->get('/support/engage')->to('engage#index');
  $r->get('/support/engage/:type')->to('engage#summary');
  $r->get('/support/engage/:type/add')->to('engage#engage_prepare');
  $r->post('/support/engage/:type/add')->to('engage#add');
  $r->get('/support/engage/:type/:stub')->to('engage#detail');
  $r->get('/support/engage/:type/:stub/edit')->to('engage#edit_get');
  $r->post('/support/engage/:type/:stub/edit')->to('engage#edit');
  $r->get('/support/engage/:type/:stub/reply')->to('engage#reply_get');
  $r->post('/support/engage/:type/:stub/reply')->to('engage#reply');

  # download pages
  $r->get('/download')->to('site#download');

  # news pages
  $r->get('/news')->to('news#index');
  $r->get('/news/create')->to('news#post_create');
  $r->post('/news')->to('news#post_update');
  $r->get('/news/:id')->to('news#post');
  $r->get('/news/:id/')->to('news#post');
  $r->get('/news/:id/edit')->to('news#post_edit');
  $r->get('/news/:id/delete')->to('news#post_delete');

  # authentication and registration
  $r->any('/authenticate')->to('site#auth');
  $r->any('/deauthenticate')->to('site#deauth');
  $r->get('/register')->to('site#register_get');
  $r->post('/register')->to('site#register_post');
  $r->get('/registered')->to('site#registered');
  $r->get('/activate/:username')->to('site#activate_get');
  $r->post('/activate/:username')->to('site#activate_post');
  $r->get('/activated')->to('site#activated');


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
#  $r->get('/(*trap)')->to('site#index');
}

1;
