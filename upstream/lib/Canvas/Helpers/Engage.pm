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
package Canvas::Helpers::Engage;

use Mojo::Base 'Mojolicious::Plugin';

#
# PERL INCLUDES
#
use Data::Dumper;

#
# CONSTANTS
#
my $TYPE_STATUS_MAP = {
  idea => [
    [ ''                    => ''                   ],
    [ 'Under Consideration' => 'under-consideration'],
    [ 'Declined'            => 'declined'           ],
    [ 'Planned'             => 'planned'            ],
    [ 'In Progress'         => 'in-progress'        ],
    [ 'Completed'           => 'completed'          ],
    [ 'Gathering Feedback'  => 'gathering-feedback' ],
  ],
  problem => [
    [ ''              => ''             ],
    [ 'Known Problem' => 'known-problem'],
    [ 'Declined'      => 'declined'     ],
    [ 'Solved'        => 'solved'       ],
    [ 'In Progress'   => 'in-progress'  ],
  ],
  question => [
    [ ''            => ''           ],
    [ 'Answered'    => 'answered'   ],
    [ 'Need Answer' => 'need-answer'],
  ],
  thank => [
    [ ''            => ''     ],
    [ 'Noted'       => 'noted'],
  ],
};

sub register {
  my( $self, $app ) = @_;

  $app->helper(engage_icon => sub {
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


  $app->helper(engage_status => sub {
    my( $self, $post ) = @_;

    return 'unknown' unless ref $post eq 'Canvas::Store::Post';

    # it's new if no replies and no modified status
    return 'new' if $post->status eq '' && $post->reply_count == 0;
    return 'active' if $post->status eq '';

    my $t = $TYPE_STATUS_MAP->{ $post->type };

    my( $s ) = ( grep { $post->status ~~ @$_ } @$t );

    return 'unknown' unless defined $s;

    return lc $s->[0];
  });


  $app->helper(engage_status_list => sub {
    my( $self, $post ) = @_;

    return [] unless ref $post eq 'Canvas::Store::Post';

    my $status = [];

    foreach my $s ( @{ $TYPE_STATUS_MAP->{ $post->type } // [] } ) {
      push @$status, [ ( grep { m/$post->status/ } @$s) ?
        ( @$s, 'selected', 'selected' ) :
        ( @$s )
      ]
    }

    return $status;
  });

  $app->helper(engage_post_can_subscribe => sub {
    my( $self, $post ) = @_;

    return 0 unless ref $post eq 'Canvas::Store::Post';

    return 0 unless defined $self->auth_user;

    return 0 unless $self->auth_user->is_active_account;

    my $um = Canvas::Store::UserMeta->search({
      user_id     => $self->auth_user->id,
      meta_key    => 'engage_subscriptions',
      meta_value  => $post->id,
    })->first;

    # determine if we're subscribed
    return not defined $um;
  });

  $app->helper(engage_post_can_edit => sub {
    my( $self, $post ) = @_;

    return 0 unless ref $post eq 'Canvas::Store::Post';

    return 0 unless defined $self->auth_user;

    return 0 unless $self->auth_user->is_active_account;

    return 1 if $self->auth_user->is_engage_moderator;

    return 1 if $self->auth_user->id == $post->author_id->id;

    return 0;
  });
}

1;
