package Canvas::TemplateMembership;

use strict;
use base 'Canvas::DBI';

__PACKAGE__->table('canvas_templatemembership');
__PACKAGE__->columns(All => qw/id template_id account_id name access/);

__PACKAGE__->has_a(account_id => 'Canvas::Account');
__PACKAGE__->has_a(template_id => 'Canvas::Template');



1;
