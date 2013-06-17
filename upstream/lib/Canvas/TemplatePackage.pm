package Canvas::TemplatePackage;

use strict;
use base 'Canvas::DBI';

__PACKAGE__->table('canvas_templatepackage');
__PACKAGE__->columns(All => qw/id template_id package_id arch_id version rel epoch pinned/);

__PACKAGE__->has_a(template_id => 'Canvas::Template');
__PACKAGE__->has_a(package_id => 'Canvas::Package');
__PACKAGE__->has_a(arch_id => 'Canvas::Arch');



1;
