package Canvas::Profile;

use strict;
use base 'Canvas::DBI';

__PACKAGE__->table('canvas_profile');
__PACKAGE__->columns(All => qw/id name uuid description organisation gpg_private gpg_public created updated/);

__PACKAGE__->has_many(templates => 'Canvas::Template' => 'profile_id');
__PACKAGE__->has_many(ratings => 'Canvas::Rating' => 'profile_id');


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
