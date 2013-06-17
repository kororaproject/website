package Canvas::TemplateRating;

use strict;
use base 'Canvas::DBI';

__PACKAGE__->table('canvas_template_ratings');
__PACKAGE__->columns(All => qw/id template_id rating_id/);

__PACKAGE__->has_a(template_id => 'Canvas::Template');
__PACKAGE__->has_a(rating_id => 'Canvas::Rating');



1;

