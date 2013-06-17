package Canvas::Template;

use strict;
use base 'Canvas::DBI';

__PACKAGE__->table('canvas_template');
__PACKAGE__->columns(All => qw/id account_id name description private parent_id/);

__PACKAGE__->has_a(account_id => 'Canvas::Account');
__PACKAGE__->has_many(template_packages => 'Canvas::TemplatePackage' => 'template_id');
__PACKAGE__->has_many(template_repositories => 'Canvas::TemplateRepository' => 'template_id');
__PACKAGE__->has_a(parent_id => 'Canvas::Template');

1;
