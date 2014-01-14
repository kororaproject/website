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
package Canvas::Util;

use Mojo::Base 'Exporter';

#
# PERL INCLUDES
#
use Carp qw(croak);

our @EXPORT_OK = (
  qw(get_random_bytes)
);

sub get_random_bytes($) {
  my $count = shift // 8;
  my $bytes = undef;

  # extract randomness from /dev/urandom
  if( open( DEV, '/dev/urandom' ) ) {
    read( DEV, $bytes, $count );
    close( DEV );
  }
  # otherwise seed from the sha512 sum of the current time
  # including microseconds
  elsif( $count <= 64 ) {
    my( $t, $u ) = gettimeofday();
    $bytes = substr sha512( $t . '.' . $u ), 0, $count;
  }
  else {
    croak '/dev/urandom could not be opened and your count exceeds the entropy afforded by the fallback.';
  }

  return $bytes;
}

1;
