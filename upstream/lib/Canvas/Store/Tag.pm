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
package Canvas::Store::Tag;

use strict;

sub new {
  my $class = shift;

  my $tags = [];

  print "HERE\n";

  if( defined( $_[0]) ) {
    $tags = split /,/, $_[0];
  }

  bless {
      __tags  => $tags,
  }, $class;
}

sub to_array() {
  return shift->{__tags};
}

sub to_string() {
  my $self = shift;

  return join ',', @{ $self->{__tags} };
}

1;
