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
package Canvas::Helpers::Engage;

use Mojo::Base 'Mojolicious::Plugin';

#
# PERL INCLUDES
#
use Data::Dumper;

#
# CONSTANTS
#
use constant TYPE_STATUS_MAP => {
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
    [ 'Answered'    => 'answered'   ],
    [ 'Need Answer' => 'need-answer'],
  ],
  thank => [
    [ ''            => ''     ],
    [ 'Noted'       => 'noted'],
  ],
};

use constant TYPE_ICON_COLOUR_MAP => {
  idea => {
    icon    => 'fa-lightbulb-o',
    colour  => 'info',
  },
  problem => {
    icon    => 'fa-bug',
    colour  => 'danger',
  },
  question => {
    icon    => 'fa-question',
    colour  => 'warning',
  },
  thank => {
    icon    => 'fa-heart',
    colour  => 'success',
  },
};

sub _is_engage_post($) {
  my $post = shift;

  return 0 unless ref $post eq 'Canvas::Store::Post';

  return grep { $_ eq $post->type } qw(reply idea thank problem question);
}


sub register {
  my( $self, $app ) = @_;

  $app->helper(engage_icon => sub {
    my( $self, $type, $classes ) = @_;

    $classes //= '';

    return '<i class="fa ' . ( TYPE_ICON_COLOUR_MAP->{ $type }{icon} // 'fa-ban' ) . ' ' . $classes . '"></i>';
  });

  $app->helper(engage_icon_label => sub {
    my( $self, $type, $classes, $text ) = @_;

    $classes //= '';
    $text    //= '';

    return '<span class="label label-' . TYPE_ICON_COLOUR_MAP->{ $type }{colour} . '"><i class="fa ' . ( TYPE_ICON_COLOUR_MAP->{ $type }{icon} // 'fa-ban' ) . ' ' . $classes . '"></i>' . $text . '</span>';
  });
  $app->helper(engage_label => sub {
    my( $self, $type, $classes, $text ) = @_;

    $classes //= '';
    $text    //= '';

    return '<span class="label label-' . TYPE_ICON_COLOUR_MAP->{ $type }{colour} . ' ' . $classes . '">' . $text . '</span>';
  });


  $app->helper(engage_status => sub {
    my( $self, $post ) = @_;

    return 'unknown' unless _is_engage_post $post;

    # it's new if no replies and no modified status
    return 'new' if $post->status eq '' && $post->reply_count == 0;
    return 'active' if $post->status eq '';

    my $t = TYPE_STATUS_MAP->{ $post->type };

    my( $s ) = ( grep { $post->status ~~ @$_ } @$t );

    return 'unknown' unless defined $s;

    return lc $s->[0];
  });


  $app->helper(engage_status_list => sub {
    my( $self, $post ) = @_;

    return [] unless _is_engage_post $post;

    my $status = [];

    foreach my $s ( @{ TYPE_STATUS_MAP->{ $post->type } // [] } ) {
      push @$status, [ ( grep { m/$post->status/ } @$s) ?
        ( @$s, 'selected', 'selected' ) :
        ( @$s )
      ]
    }

    return $status;
  });

  $app->helper(engage_post_admin_template => sub {
    my( $self, $post ) = @_;

    my @caps;

    my $url = $self->url_for('current');

    if( $post->type ne 'reply' ) {
      if( $self->auth_user && $self->auth_user->is_active_account ) {
        if( $self->engage_post_can_subscribe( $post ) ) {
          push @caps, sprintf '<li><a href="%s/subscribe" class="text-left"><i class="fa fa-fwl fa-bookmark"></i> Subscribe</a></li>', $url;
        }
        else {
           push @caps, sprintf '<li><a href="%s/unsubscribe" class="text-left"><i class="fa fa-fwl fa-bookmark-o"></i> Unsubscribe</a></li>', $url;
        }
      }
    }
    else {
      $url .= '/reply/' . $post->id;

      if( $self->auth_user && $self->auth_user->is_active_account ) {
        # add quote button
        push @caps, sprintf '<li><a id="quote-%d" href="" class="text-left"><i class="fa fa-fwl fa-quote-left"></i> Quote</a></li>', $post->id;
      }
    }

    if( $self->engage_post_can_accept( $post ) ) {
      push @caps, sprintf '<li><a href="%s/accept" class="text-left"><i class="fa fa-fwl fa-check"></i> Accept</a></li>', $url;
    }

    if( $self->engage_post_can_unaccept( $post ) ) {
      push @caps, sprintf '<li><a href="%s/unaccept" class="text-left"><i class="fa fa-fwl fa-times"></i> Unaccept</a></li>', $url;
    }

    if( $self->engage_post_can_edit( $post ) ) {
      push @caps, sprintf '<li><a href="%s/edit" class="text-left"><i class="fa fa-fwl fa-edit"></i> Edit</a></li>', $url;
    }

    if( $self->engage_post_can_delete( $post ) ) {
      push @caps, sprintf '<li><a href="%s/delete" class="text-left"><i class="fa fa-fwl fa-trash-o"></i> Delete</a></li>', $url;
    }

    my $template = '';

    if( @caps ) {
      $template .= qq(
        <div class="engage-detail-footer-metadata">
          <div class="dropdown">
            <button class="btn btn-sm btn-default dropdown-toggle" type="button" id="post-detail-admin-dropdown" data-toggle="dropdown"><i class="fa fa-fw fa-cogs"></i></button>
            <ul class="dropdown-menu pull-right" role="menu" aria-labelledby="post-detail-admin-dropdown"> );

      $template .= join('', @caps);

      $template .= qq(
            </ul>
          </div>
        </div>);
    }

    return $template;
  });


  $app->helper(engage_post_last_update => sub {
    my( $self, $post ) = @_;

    return 0 unless _is_engage_post $post;

    my $t = ( $post->created > $post->updated ) ? $post->created : $post->updated;

    return $t unless $post->latest_reply;

    return ( $t > $post->latest_reply->updated ) ? $t : $post->latest_reply->updated;
  });

  $app->helper(engage_post_can_accept => sub {
    my( $self, $post ) = @_;

    return 0 unless _is_engage_post $post;

    return 0 unless $post->type eq 'reply' && $post->status ne 'accepted';

    return 0 unless defined $self->auth_user;

    return 0 unless $self->auth_user->is_active_account;

    return 1 if $self->auth_user->is_engage_moderator;

    return 1 if $self->auth_user->id == $post->author_id->id;

    return 0;
  });

  $app->helper(engage_post_can_unaccept => sub {
    my( $self, $post ) = @_;

    return 0 unless _is_engage_post $post;

    return 0 unless $post->type eq 'reply' && $post->status eq 'accepted';

    return 0 unless defined $self->auth_user;

    return 0 unless $self->auth_user->is_active_account;

    return 1 if $self->auth_user->is_engage_moderator;

    return 1 if $self->auth_user->id == $post->author_id->id;

    return 0;
  });

  $app->helper(engage_post_can_subscribe => sub {
    my( $self, $post ) = @_;

    return 0 unless _is_engage_post $post;

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

    return 0 unless _is_engage_post $post;

    return 0 unless defined $self->auth_user;

    return 0 unless $self->auth_user->is_active_account;

    return 1 if $self->auth_user->is_engage_moderator;

    return 1 if $self->auth_user->id == $post->author_id->id;

    return 0;
  });

  $app->helper(engage_post_can_edit_status => sub {
    my( $self, $post ) = @_;

    return 0 unless _is_engage_post $post;

    return 0 unless defined $self->auth_user;

    return 0 unless $self->auth_user->is_active_account;

    return 1 if $self->auth_user->is_engage_moderator;

    # only allow OP's to change status of questions
    return 1 if(
      $post->type eq 'question' &&
      $self->auth_user->id == $post->author_id->id
    );

    return 0;
  });

  $app->helper(engage_post_can_delete => sub {
    my( $self, $post ) = @_;

    return 0 unless _is_engage_post $post;

    return 0 unless defined $self->auth_user;

    return 0 unless $self->auth_user->is_active_account;

    return 1 if $self->auth_user->is_engage_moderator;

    return 0;
  });


}

1;
