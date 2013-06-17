package Canvas::Rating;

use strict;
use base 'Canvas::DBI';

__PACKAGE__->table('canvas_rating');
__PACKAGE__->columns(All => qw/id account_id description value/);

__PACKAGE__->has_many(template_rating => 'Canvas::TemplateRating' => 'package_id');
__PACKAGE__->has_many(package_ratings => 'Canvas::PackageRating' => 'package_id');

__PACKAGE__->has_a(account_id => 'Canvas::Account');

1;

