package Canvas::Arch;

use strict;
use base 'Canvas::DBI';

__PACKAGE__->table('canvas_arch');
__PACKAGE__->columns(All => qw/id name description/);

__PACKAGE__->has_many(template_packages => 'Canvas::TemplatePackage' => 'arch_id');

1;

