package Canvas::Package;

use strict;
use base 'Canvas::DBI';

__PACKAGE__->table('canvas_package');
__PACKAGE__->columns(All => qw/id name description summary license url/);

__PACKAGE__->has_many(template_packages => 'Canvas::TemplatePackage' => 'package_id');
__PACKAGE__->has_many(package_ratings => 'Canvas::PackageRating' => 'package_id');


1;
