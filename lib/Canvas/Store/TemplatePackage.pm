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
package Canvas::Store::TemplatePackage;

#
# PERL INCLUDES
#
use Mojo::Base 'Canvas::Store';

#
# CONSTANTS
#
use constant {
  ACTION_LOCK_UNINSTALL =>  0x80,
  ACTION_LOCK_INSTALL   =>  0x40,
  ACTION_PIN_EPOCH      =>  0x20,
  ACTION_PIN_VERSION    =>  0x10,
  ACTION_PIN_RELEASE    =>  0x08,
  ACTION_PIN_ARCH       =>  0x04,
  ACTION_UNINSTALL      =>  0x02,
  ACTION_INSTALL        =>  0x01,
};

#
# TABLE DEFINITION
#
__PACKAGE__->table('canvas_templatepackage');
__PACKAGE__->columns(All => qw/id template_id repo_name name arch version rel epoch action created updated/);

#
# 1:N MAPPINGS
#
__PACKAGE__->has_a(template_id  => 'Canvas::Store::Template');

#
# INFLATOR/DEFLATORS
#
__PACKAGE__->has_a(
  created => 'Time::Piece',
  inflate => sub { my $t = shift; ( $t eq "0000-00-00 00:00:00" ) ? gmtime(0) : Time::Piece->strptime($t, "%Y-%m-%d %H:%M:%S") },
  deflate => sub { shift->strftime("%Y-%m-%d %H:%M:%S") }
);

__PACKAGE__->has_a(
  updated => 'Time::Piece',
  inflate => sub { my $t = shift; ( $t eq "0000-00-00 00:00:00" ) ? gmtime(0) : Time::Piece->strptime($t, "%Y-%m-%d %H:%M:%S") },
  deflate => sub { shift->strftime("%Y-%m-%d %H:%M:%S") }
);


#
# ATTRIBUTES
#

sub is_pinned {
  return( shift->action & ( ACTION_PIN_EPOCH | ACTION_PIN_VERSION | ACTION_PIN_RELEASE | ACTION_PIN_ARCH ) );
}

#
# is_installed()
#
# is the package explicitly installed by the template
#
sub is_installed {

  return( shift->action & ACTION_INSTALL );
}

#
# is_removed()
#
# is the package explicitly removed by the template
#
sub is_removed {
  return( shift->action & ACTION_INSTALL );
}

#
# UPDATE HELPER
#
__PACKAGE__->set_sql(update => qq{
 UPDATE __TABLE__
  SET updated=UTC_TIMESTAMP(), %s
   WHERE  __IDENTIFIER__
});

1;
