#!/usr/bin/perl

use strict;

use lib '../lib';
use feature ':5.10';

use Data::Dumper;

use Canvas::Template;



#
# CREATE
#
my $template = {
  name => 'security-layer',
  description => 'this layer applies all the security you\'ll need.'
};

my $obj1 = Canvas::Template->insert($template);
say $obj1->name;

my $template = {
  name => 'encryption-layer',
  description => 'this layer applies all the encryption you\'ll need.'
};

my $obj2 = Canvas::Template->insert($template);

my $template = {
  name => 'base-layer',
  description => 'this layer applies everything.'
};

my $obj3 = Canvas::Template->insert($template);

$obj2->set(parent_id => $obj3->id);
$obj2->update;

#
# RETRIEVE ALL
#

my $all = [ Canvas::Template->retrieve_all ];

foreach my $t ( @$all ) {
  say Dumper($t->name, $t->parent_id->name);
}




#
# DELETE
#

foreach my $t ( @$all ) {
  $t->delete;
}

