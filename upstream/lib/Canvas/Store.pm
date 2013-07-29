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
package Canvas::Store;

use strict;
use base 'Class::DBI';

#Canvas::DBI->connection('dbi:SQLite:dbname=canvas.db', '', '');
#Canvas::DBI->connection('dbi:mysql:dbname=canvas', 'canvas', 'c@nvas');

my ($dsn, $username, $password) = getConfig();

Canvas::Store->set_db(
  'Main',
  $dsn,
  $username,
  $password,
  { AutoCommit => 1 },
);

sub getConfig {
  return ('dbi:mysql:dbname=canvas', 'canvas', 'c@nva$');
#  return ('dbi:SQLite:canvas.db', '', '');
}

sub do_transaction {
  my $class = shift;
  my ( $code ) = @_;

  # Turn off AutoCommit for this scope.
  # A commit will occur at the exit of this block automatically,
  # when the local AutoCommit goes out of scope.
  local $class->db_Main->{ AutoCommit };

  # Execute the required code inside the transaction.

  eval { $code->() };

  if ( $@ ) {
    my $commit_error = $@;
    eval { $class->dbi_rollback }; # might also die!
    die $commit_error;
  }
}
1;
