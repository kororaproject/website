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
package Canvas::Discover;

use warnings;
use strict;

use Mojo::Base 'Mojolicious::Controller';

#
# PERL INCLUDES
#
use Data::Dumper;


#
# CONTROLLER HANDLERS
#
sub index {
  my $self = shift;

  $self->render('discover');
}

sub gnome {
  my $self = shift;

  $self->render('discover-gnome');
}

sub kde {
  my $self = shift;

  $self->render('discover-kde');
}

sub cinnamon {
  my $self = shift;

  $self->render('discover-cinnamon');
}

sub mate {
  my $self = shift;

  $self->render('discover-mate');
}


1;
