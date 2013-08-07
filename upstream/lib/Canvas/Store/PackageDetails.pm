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
package Canvas::Store::PackageDetails;

use strict;
use base 'Canvas::Store';

use Time::Piece;

__PACKAGE__->table('canvas_packagedetails');
__PACKAGE__->columns(All => qw/id package_id arch_id epoch version rel install_size package_size build_time file_time repo_id/);

__PACKAGE__->has_a(package_id => 'Canvas::Store::Package');
__PACKAGE__->has_a(arch_id    => 'Canvas::Store::Arch');
__PACKAGE__->has_a(repo_id    => 'Canvas::Store::Repository');

#
# inflate/deflate epoch stored values
__PACKAGE__->has_a(
  build_time  => 'Time::Piece',
  inflate     => sub { Time::Piece->new( shift ) },
  deflate     => sub { shift->epoch }
);

__PACKAGE__->has_a(
  file_time  => 'Time::Piece',
  inflate     => sub { Time::Piece->new( shift ) },
  deflate     => sub { shift->epoch }
);

1;

