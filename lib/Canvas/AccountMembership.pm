package Canvas::AccountMembership;

use strict;
use base 'Canvas::DBI';

use constant {
  ACL_OWNER => 128,
  ACL_ADMIN =>  64,
  ACL_WRITE =>   1,
};

__PACKAGE__->table('canvas_accountmembership');
__PACKAGE__->columns(All => qw/id account_id member_id name access/);

__PACKAGE__->has_a(account_id => 'Canvas::Account');
__PACKAGE__->has_a(member_id => 'Canvas::Account');



sub is_owner {
  my $access = shift->access;

  return ( $access & ACL_OWNER );
}

sub is_admin {
  my $access = shift->access;

  return ( $access & ACL_ADMIN );
}

sub is_owner_admin {
  my $access = shift->access;

  return ( $access & ACL_OWNER ) | ( $access & ACL_ADMIN );
}

sub is_admin {
  my $access = shift->access;

  return ( $access & ACL_ADMIN );
}

sub can_delete {
  my $access = shift->access;

  return ( $access & ACL_OWNER ) | ( $access & ACL_ADMIN );
}

sub can_create {
  my $access = shift->access;

  return ( $access & ACL_OWNER ) | ( $access & ACL_ADMIN );
}

sub can_write {
  my $access = shift->access;

  return ( $access & ACL_WRITE );
}

1;
