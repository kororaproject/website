package Canvas::TemplateRepository;

use strict;
use base 'Canvas::DBI';

__PACKAGE__->table('canvas_templaterepository');
__PACKAGE__->columns(All => qw/id template_id repo_id pref_url version enabled cost gpg_check/);

__PACKAGE__->has_a(template_id => 'Canvas::Template');
__PACKAGE__->has_a(repo_id => 'Canvas::Repository');



1;
