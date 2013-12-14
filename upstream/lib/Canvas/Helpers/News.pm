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
package Canvas::Helpers::News;

use Mojo::Base 'Mojolicious::Plugin';

sub register {
  my( $self, $app ) = @_;

  $app->helper(news_post_can_add => sub {
    my( $self ) = @_;

    return 0 unless defined $self->auth_user;

    return 0 unless $self->auth_user->is_active_account;

    return 1 if $self->auth_user->is_news_moderator;

    return 0;
  });

  $app->helper(news_post_can_delete => sub {
    my( $self ) = @_;

    return 0 unless defined $self->auth_user;

    return 0 unless $self->auth_user->is_active_account;

    return 1 if $self->auth_user->is_admin;

    return 0;
  });

  $app->helper(news_post_can_edit => sub {
    my( $self ) = @_;

    return 0 unless defined $self->auth_user;

    return 0 unless $self->auth_user->is_active_account;

    return 1 if $self->auth_user->is_news_moderator;

    return 0;
  });
}

1;
