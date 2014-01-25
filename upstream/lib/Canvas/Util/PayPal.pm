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
package Canvas::Util::PayPal;

use Mojo::Base -base;

#
# PERL INCLUDES
#
use Data::Dumper;
use Mojo::JSON qw(j);
use Mojo::URL;
use Mojo::UserAgent;
use Mojo::Util qw(url_unescape);
use Time::Piece;

#
# MEMBERS
#
has caller_user      => sub { die 'No caller usre specified!' };
has caller_password  => sub { die 'No caller password specified!' };
has caller_signature => sub { die 'No caller signature specified!' };
has url_base         => sub { die 'No url base specified' };

sub new {
  shift->SUPER::new->config(@_);
}

sub config {
  my $self = shift;
  my $args = ref $_[0] ? $_[0] : {@_};

  $self->caller_user( $args->{caller_user} // '' );
  $self->caller_password( $args->{caller_password} // '' );
  $self->caller_signature( $args->{caller_signature} // '' );
  $self->url_base( Mojo::URL->new($args->{url_base} // 'http://localhost:3000') );

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

  return $self;
}

sub donate_prepare {
  my( $self, $amount ) = @_;

  my $url = $self->{endpoint}->path('nvp');

  my $params = {
    USER                            => $self->caller_user,
    PWD                             => $self->caller_password,
    SIGNATURE                       => $self->caller_signature,
    BRANDNAME                       => 'Korora Project',
    TOTALTYPE                       => 'Total',
    PAGESTYLE                       => 'KororaProject',
    METHOD                          => 'SetExpressCheckout',
    VERSION                         => 93,
    NOSHIPPING                      => 1,
    PAYMENTREQUEST_0_PAYMENTACTION  => 'SALE',
    PAYMENTREQUEST_0_DESC           => "\$${amount}USD donation to the Korora Project",
    PAYMENTREQUEST_0_AMT            => $amount,
    PAYMENTREQUEST_0_CURRENCYCODE   => 'USD',
    RETURNURL                       => Mojo::URL->new($self->url_base)->path('/contribute/donate/confirm'),
    CANCELURL                       => Mojo::URL->new($self->url_base)->path('/contribute/donate'),
  };

  my $tx = $self->{ua}->post( $url => form => $params );

  # return decoded name/value pairs on success
  if( my $res = $tx->success ) {
    return $self->_decode_nvp( $res->body );
  }

  my( $err, $code ) = $tx->error;

  return {
    ACK   => 'ERROR',
    ERROR => $code ? "$code response: $err" : "Connection error: $err"
  };
}

sub donate_confirm {
  my( $self, $token ) = @_;

  my $url = $self->{endpoint}->path('nvp');

  my $params = {
    USER                            => $self->caller_user,
    PWD                             => $self->caller_password,
    SIGNATURE                       => $self->caller_signature,
    METHOD                          => 'GetExpressCheckoutDetails',
    VERSION                         => 93,
    TOKEN                           => $token,
  };

  my $tx = $self->{ua}->post( $url => form => $params );

  # return decoded name/value pairs on success
  if( my $res = $tx->success ) {
    return $self->_decode_nvp( $res->body );
  }

  my( $err, $code ) = $tx->error;

  return {
    ACK   => 'ERROR',
    ERROR => $code ? "$code response: $err" : "Connection error: $err"
  };
}

sub donate_commit {
  my( $self, $token, $payerid, $amount ) = @_;

  my $url = $self->{endpoint}->path('nvp');

  my $params = {
    USER                            => $self->caller_user,
    PWD                             => $self->caller_password,
    SIGNATURE                       => $self->caller_signature,
    METHOD                          => 'DoExpressCheckoutPayment',
    VERSION                         => 93,
    TOKEN                           => $token,
    PAYERID                         => $payerid,
    PAYMENTREQUEST_0_PAYMENTACTION  => 'SALE',
    PAYMENTREQUEST_0_AMT            => $amount,
    PAYMENTREQUEST_0_CURRENCYCODE   => 'USD',
  };

  my $tx = $self->{ua}->post( $url => form => $params );

  # return decoded name/value pairs on success
  if( my $res = $tx->success ) {
    return $self->_decode_nvp( $res->body );
  }

  my( $err, $code ) = $tx->error;

  return {
    ACK   => 'ERROR',
    ERROR => $code ? "$code response: $err" : "Connection error: $err"
  };
}



sub sponsor_prepare {
  my( $self, $amount ) = @_;

  my $url = $self->{endpoint}->path('nvp');

  my $params = {
    USER                            => $self->caller_user,
    PWD                             => $self->caller_password,
    SIGNATURE                       => $self->caller_signature,
    BRANDNAME                       => 'Korora Project',
    TOTALTYPE                       => 'Total',
    PAGESTYLE                       => 'KororaProject',
    METHOD                          => 'SetExpressCheckout',
    VERSION                         => 86,
    L_BILLINGTYPE0                  => 'RecurringPayments' ,
    L_BILLINGAGREEMENTDESCRIPTION0  => "\$${amount}USD/month sponsorship to the Korora Project",
    RETURNURL                       => Mojo::URL->new($self->url_base)->path('/contribute/sponsor/confirm'),
    CANCELURL                       => Mojo::URL->new($self->url_base)->path('/contribute/sponsor'),
  };

  my $tx = $self->{ua}->post( $url => form => $params );

  # return decoded name/value pairs on success
  if( my $res = $tx->success ) {
    return $self->_decode_nvp( $res->body );
  }

  my( $err, $code ) = $tx->error;

  return {
    ACK   => 'ERROR',
    ERROR => $code ? "$code response: $err" : "Connection error: $err"
  };
}

sub sponsor_confirm {
  my( $self, $token ) = @_;

  my $url = $self->{endpoint}->path('nvp');

  my $params = {
    USER                            => $self->caller_user,
    PWD                             => $self->caller_password,
    SIGNATURE                       => $self->caller_signature,
    METHOD                          => 'GetExpressCheckoutDetails',
    VERSION                         => 86,
    TOKEN                           => $token,
  };

  my $tx = $self->{ua}->post( $url => form => $params );

  # return decoded name/value pairs on success
  if( my $res = $tx->success ) {
    return $self->_decode_nvp( $res->body );
  }

  my( $err, $code ) = $tx->error;

  return {
    ACK   => 'ERROR',
    ERROR => $code ? "$code response: $err" : "Connection error: $err"
  };
}

sub sponsor_commit {
  my( $self, $token, $payerid, $amount ) = @_;

  my $url = $self->{endpoint}->path('nvp');

  my $params = {
    USER              => $self->caller_user,
    PWD               => $self->caller_password,
    SIGNATURE         => $self->caller_signature,
    METHOD            => 'CreateRecurringPaymentsProfile',
    VERSION           => 86,
    TOKEN             => $token,
    PAYERID           => $payerid,
    PROFILESTARTDATE  => gmtime->strftime('%Y-%m-%dT%H:%M:%SZ'),
    DESC              => "\$${amount}USD/month sponsorship to the Korora Project",
    BILLINGPERIOD     => 'Month',
    BILLINGFREQUENCY  => 1,
    AMT               => $amount,
    CURRENCYCODE      => 'USD',
    MAXFAILEDPAYMENTS => 3,
  };

  my $tx = $self->{ua}->post( $url => form => $params );

  # return decoded name/value pairs on success
  if( my $res = $tx->success ) {
    return $self->_decode_nvp( $res->body );
  }

  my( $err, $code ) = $tx->error;

  return {
    ACK   => 'ERROR',
    ERROR => $code ? "$code response: $err" : "Connection error: $err"
  };
}


#
# PRIVATE
#

sub _default_endpoint {
  my $self = shift;

  return 'https://api-3t.paypal.com' if $self->{mode} eq 'live';

  return 'https://api-3t.sandbox.paypal.com';
}

sub _decode_nvp {
  my $self = shift;

  my $nvp = {};

  foreach my $n ( split /&/, shift // '' ) {
    my( $k, $v ) = split /=/, $n;
    $nvp->{$k} = url_unescape($v);
  }

  return $nvp;
}

1;
