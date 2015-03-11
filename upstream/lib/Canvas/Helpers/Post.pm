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
package Canvas::Helpers::Post;

use Mojo::Base 'Mojolicious::Plugin';

#
# PERL INCLUDES
#

sub register {
  my ($self, $app) = @_;

  $app->helper('posts.format.created_updated' => sub {
    my ($c, $post) = @_;

    my $i = $post->{created_epoch} eq $post->{updated_epoch} ? 'created' : 'updated';

    return sprintf "%s %s", $i, $c->users->format_time($post->{updated_epoch});
  });
}


1;

