package Canvas::PackageRating;

use strict;
use base 'Canvas::DBI';

__PACKAGE__->table('canvas_package_ratings');
__PACKAGE__->columns(All => qw/id package_id rating_id/);

__PACKAGE__->has_a(package_id => 'Canvas::Package');
__PACKAGE__->has_a(rating_id => 'Canvas::Rating');



1;

