#
# Copyright (C) 2013    Ian Firns   <firnsy@kororaproject.org>
#                       Chris Smart <csmart@kororaproject.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
package Canvas::Util::PayPal::API;

use Mojo::Base -base;

#
# PERL INCLUDES
#
use Data::Dumper;
use Mojo::JSON;
use Mojo::URL;
use Mojo::Util qw(b64_encode decode encode);
use Mojo::UserAgent;
use Time::Piece;

#
# MEMBERS
#
has client_id     => sub { die 'No client ID specified!' };
has client_secret => sub { die 'No client secret specified!' };

sub new {
  shift->SUPER::new->config(@_);
}

sub config {
  my $self = shift;
  my $args = ref $_[0] ? $_[0] : {@_};

  $self->client_id( $args->{client_id} // '' );
  $self->client_secret( $args->{client_secret} // '' );

  $self->{mode}             = $args->{mode} // 'sandbox';
  $self->{ssl_options}      = $args->{ssl_options} // {};
  $self->{token_hash}       = undef;
  $self->{token_request_at} = undef;

  if( $self->{token} ) {
    $self->{token_hash} = {
      access_token  => $self->{token},
      token_type    => 'Bearer'
    };
  }

  $self->{endpoint} = Mojo::URL->new( $args->{endpoint} // $self->_default_endpoint );
  $self->{token_endpoint} = Mojo::URL->new( $args->{token_endpoint} // $self->{endpoint} );

  $self->{ua} = Mojo::UserAgent->new;
  $self->{j} = Mojo::JSON->new;

  return $self;
}

sub basic_auth {
  my $self = shift;
  my $credentials = sprintf "%s:%s", $self->client_id, $self->client_secret;

  return decode( b64_encode( encode( $credentials )) );
}

sub get_token_hash {
  my $self = shift;

  $self->validate_token_hash;

  unless( $self->{token_hash} ) {
    $self->{token_request_at} = gmtime();


    $self->{token_hash} =
    my $tx = $self->{ua}->post( $self->{token_endpoing}->path('/v1/oauth2/token') => {
        Authorization   => sprintf( "Basic %s", $self->basic_auth),
        'Content-Type'  => 'application/x-www-form-urlencoded',
        Accept          => 'application/json'
      } => form => {
        grant_type      => 'client_credentials'
      }
    );
  }

  return $self->{token_hash}
}

sub validate_token_hash {
  my $self = shift;

  if( $self->{token_request_at} &&
      $self->{token_hash} &&
      $self->{token_hash}{expires_in} ) {
    my $delta = gmtime - $self->{token_request_at};
    $self->{token_hash} = undef if( $delta > $self->{token_hash}{expires_in} );
  }
}

sub get_token {
  my $h = shift->get_token_hash();

  return $h->{access_token};
}

sub get_token_type {
  my $h = shift->get_token_hash();
  return $h->{token_type};
}

sub request {
  my( $self, $url, $method, $params, $headers ) = @_;

  my $http_headers = { %{ $self->_headers }, %{ $headers // {} } };

  if( $http_headers->{'PayPal-Request-Id'} ) {
    #  logging.info('PayPal-Request-Id: %s' % (http_headers['PayPal-Request-Id']))
  }

  my $tx;
  given( $method ) {
    when('GET') {
      $tx = $self->{ua}->get( $url => $http_headers );
    }
    when('POST') {
      $tx = $self->{ua}->post( $url => $http_headers => form => $params );
    }
    when('DELETE') {
      $tx = $self->{ua}->delete( $url => $http_headers );
    }
  }

  # format Error message for bad request
  if( $tx->res->code == 400 ) {
    return {
      error => $self->{j}->decode( $tx->res->body )
    };
  }
  # handle Exipre token
  elsif( $tx->res->code == 401 ) {
    if($self->{token_hash} && $self->client_id ) {
      $self->{token_hash} = undef;

      return $self->request( $url, $method, $params, $headers );
    }
  }

  return $self->{j}->decode( $tx->res->body );
}


# Make GET request
# == Example
#   api.get("v1/payments/payment?count=1")
#   api.get("v1/payments/payment/PAY-1234")
sub get {
  my( $self, $action, $headers ) = @_;

  return $self->request( $self->{endpoint}->path( $action ), 'GET', undef, $headers );
}

# Make POST request
# == Example
#   api.post("v1/payments/payment", { 'indent': 'sale' })
#   api.post("v1/payments/payment/PAY-1234/execute", { 'payer_id': '1234' })
sub post {
  my( $self, $action, $params, $headers ) = @_;

  return $self->request( $self->{endpoint}->path( $action ), 'POST', $params, $headers );
}

# Make DELETE request
sub delete {
  my( $self, $action, $headers ) = @_;

  return $self->request( $self->{endpoint}->path( $action ), 'GET', undef, $headers );
}

sub dump {
  say Dumper shift;
}

#
# PRIVATE
#
sub _default_endpoint {
  my $self = shift;

  return 'https://api.paypal.com' if $self->{mode} eq 'live';

  return 'https://api.sandbox.paypal.com';
}

sub _headers {
  my $self = shift;

  return {
    Authorization   => sprintf( '%s %s', $self->get_token_type, $self->get_token ),
    'Content-Type'  => 'application/json',
    Accept          => 'application/json',
#    "User-Agent": self.user_agent
  }
}


1;
