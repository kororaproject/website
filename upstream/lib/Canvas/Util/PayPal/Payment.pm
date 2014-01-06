#
# Copyright (C) 2013-2014   Ian Firns   <firnsy@kororaproject.org>
#                           Chris Smart <csmart@kororaproject.org>
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
package Canvas::Util::PayPal::Payment;

use Mojo::Base -base;

#
# PERL INCLUDES
#
use Digest::SHA qw(sha256_hex sha512);

#
# MEMBERS
#
has intent     => sub { die 'No intent specified!' };
has request_id => undef;

sub generate_request_id {
  my $self = shift;

  unless( $self->{request_id} ) {
    $self->request_id( $self->_generate_token );
  }

  return $self->request_id;
}

sub http_headers {
  my $self = shift;

  return {
    'PayPal-Request-Id' => $self->generate_request_id,
  }
}


sub all {

}

sub create {
  my( $self, $context, $attributes ) = @_;

  die 'Invalid context supplied.' unless ref $context eq 'Canvas::Util::PayPal::API';

  return $context->post('v1/payments/payment', $attributes, $self->http_headers );
}

sub execute {
  my( $self, $context, $attributes ) = @_;

  die 'Invalid context supplied.' unless ref $context eq 'Canvas::Util::PayPal::API';

  return $context->post('v1/payments/payment/execute', $attributes, $self->http_headers );
}

sub find {
  my( $self, $context, $attributes ) = @_;

  die 'Invalid context supplied.' unless ref $context eq 'Canvas::Util::PayPal::API';

  return $context->get('v1/payments/payment', $self->http_headers );
}

sub list {

}

sub post {
  my( $self, $context, $attributes ) = @_;

  die 'Invalid context supplied.' unless ref $context eq 'Canvas::Util::PayPal::API';

  return $context->post('v1/payments/payment', $attributes, $self->http_headers );
}

#
# PRIVATE
#

sub _generate_token {
  my $bytes;

  # extract randomness from /dev/urandom
  if( open( DEV, "/dev/urandom" ) ) {
    read( DEV, $bytes, 16 );
    close( DEV );
  }
  # otherwise seed from the sha512 sum of the current time
  # including microseconds
  else {
    my( $t, $u ) = gettimeofday();
    $bytes = substr sha512( $t . '.' . $u ), 0, 48;
  }

  return sha256_hex( $bytes );
}



1;
