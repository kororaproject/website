package Mojolicious::Plugin::Cache;
use Mojo::Base 'Mojolicious::Plugin::Config';

use Cache::FastMmap;
use Mojo::JSON;
use Mojo::Template;
use Mojo::Util 'encode';

sub register {
  my ($self, $app, $args) = @_;

  $args //= {};

  my $cache = Cache::FastMmap->new( $args );

  $app->helper(cache => sub {
    return $cache
  });
}

1;


