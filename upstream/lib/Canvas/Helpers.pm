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
package Canvas::Helpers;

use Mojo::Base 'Mojolicious::Plugin';

#
# LOCAL INCLUDES
#
use Canvas::Util::MultiMarkdown;

sub register {
  my( $self, $app ) = @_;

  $app->helper(render_markdown => sub {
    my( $self, $post ) = @_;

    my $m = Canvas::Util::MultiMarkdown->new(
      tab_width   => 2,
      heading_ids => 0,
      img_ids     => 0,
    );

    return $m->markdown( $post );
  });

  $app->helper(build_query => sub {
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

  $app->helper(pluralise => sub {
    my( $self, $amount, $unit ) = @_;

    if( $amount ne '1' ) {
      $unit .= 's';
      $unit =~ s/os$/oes/;
      $unit =~ s/ys$/ies/;
    }

    return $amount . ' ' . $unit;
  });

  # time prettifier
  $app->helper(time_ago => sub {
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
}

1;
