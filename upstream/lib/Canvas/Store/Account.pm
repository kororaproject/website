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
package Canvas::Store::Account;

use strict;
use base 'Canvas::Store';

__PACKAGE__->table('canvas_account');
__PACKAGE__->columns(All => qw/id name uuid description organisation created updated/);

__PACKAGE__->has_many(template_memberships  => 'Canvas::Store::TemplateMembership'  => 'account_id');
__PACKAGE__->has_many(account_memberships   => 'Canvas::Store::AccountMembership'   => 'account_id');
__PACKAGE__->has_many(ratings               => 'Canvas::Store::Rating'              => 'account_id');

#
# DIRECT CONNECTIONS (via MAPS)
#
__PACKAGE__->has_many(templates             => [ 'Canvas::Store::TemplateMembership'  => 'account_id' ]);

# default value for created
__PACKAGE__->set_sql(MakeNewObj => qq{
INSERT INTO __TABLE__ (created, updated, %s)
VALUES (CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, %s)
});

__PACKAGE__->set_sql(update => qq {
UPDATE __TABLE__
  SET    updated = CURRENT_TIMESTAMP, %s
  WHERE  __IDENTIFIER__
});
1;
