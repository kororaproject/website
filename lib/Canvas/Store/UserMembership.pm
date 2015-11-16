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
package Canvas::Store::UserMembership;

use strict;
use base 'Canvas::Store';

use constant {
  ACL_OWNER => 128,
  ACL_ADMIN =>  64,
  ACL_WRITE =>   1,
};

__PACKAGE__->table('canvas_usermembership');
__PACKAGE__->columns(All => qw/id user_id member_id name access/);

__PACKAGE__->has_a(user_id    => 'Canvas::Store::User');
__PACKAGE__->has_a(member_id  => 'Canvas::Store::User');



sub is_owner {
  my $access = shift->access;

  return( $access & ACL_OWNER );
}

sub is_admin {
  my $access = shift->access;

  return( $access & ACL_ADMIN );
}

sub is_owner_admin {
  my $access = shift->access;

  return( $access & ACL_OWNER ) | ( $access & ACL_ADMIN );
}

sub is_admin {
  my $access = shift->access;

  return( $access & ACL_ADMIN );
}

sub can_delete {
  my $access = shift->access;

  return( $access & ACL_OWNER ) | ( $access & ACL_ADMIN );
}

sub can_create {
  my $access = shift->access;

  return( $access & ACL_OWNER ) | ( $access & ACL_ADMIN );
}

sub can_write {
  my $access = shift->access;

  return( $access & ACL_WRITE );
}

1;
