package Canvas::Repository;

use strict;
use base 'Canvas::DBI';

__PACKAGE__->table('canvas_repository');
__PACKAGE__->columns(All => qw/id stub name base_url gpg_key/);

__PACKAGE__->has_many(template_packages => 'Canvas::TemplatePackage' => 'package_id');
__PACKAGE__->has_many(package_ratings => 'Canvas::PackageRating' => 'package_id');


1;
