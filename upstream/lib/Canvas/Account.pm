package Canvas::Account;

use strict;
use base 'Canvas::DBI';

__PACKAGE__->table('canvas_account');
__PACKAGE__->columns(All => qw/id name uuid description organisation created updated/);

__PACKAGE__->has_many(template_memberships => 'Canvas::TemplateMembership' => 'account_id');
__PACKAGE__->has_many(account_memberships => 'Canvas::AccountMembership' => 'account_id');
__PACKAGE__->has_many(ratings => 'Canvas::Rating' => 'account_id');


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
