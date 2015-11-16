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
package Canvas::Store::RepositoryDetails;

use strict;
use base 'Canvas::Store';

__PACKAGE__->table('canvas_repositorydetails');
__PACKAGE__->columns(All => qw/id repo_id name version arch_id base_url created updated/);

__PACKAGE__->has_a(arch_id => 'Canvas::Store::Arch');
__PACKAGE__->has_a(repo_id => 'Canvas::Store::Repository');

1;

