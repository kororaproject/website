package Canvas::DBI;

use strict;
use base 'Class::DBI';

#Canvas::DBI->connection('dbi:SQLite:dbname=canvas.db', '', '');
#Canvas::DBI->connection('dbi:mysql:dbname=canvas', 'canvas', 'c@nvas');

my ($dsn, $username, $password) = getConfig();

Canvas::DBI->set_db(
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
