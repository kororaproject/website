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
package Canvas::Store::Template;

use strict;
use base 'Canvas::Store';

__PACKAGE__->table('canvas_template');
__PACKAGE__->columns(All => qw/id account_id name description private parent_id/);

__PACKAGE__->has_many(template_packages     => 'Canvas::Store::TemplatePackage'     => 'template_id');
__PACKAGE__->has_many(template_repositories => 'Canvas::Store::TemplateRepository'  => 'template_id');

__PACKAGE__->has_a(account_id => 'Canvas::Store::Account');
__PACKAGE__->has_a(parent_id  => 'Canvas::Store::Template');

1;
