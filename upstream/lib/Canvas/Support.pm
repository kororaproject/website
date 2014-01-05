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
package Canvas::Support;

use warnings;
use strict;

use Mojo::Base 'Mojolicious::Controller';

#
# PERL INCLUDES
#
use Data::Dumper;
use Mojo::JSON qw(j);
use Mojo::Util qw(trim);
use Time::Piece;

#
# LOCAL INCLUDES
#
use Canvas::Store::Donation;

#
# PRIVATE HELPERS
#

sub _get_cc_type {
  my ($number) = @_;

  $number =~ s/[\s\-]//go;
  $number =~ s/[x\*\.\_]/x/gio;

  return "invalid" if $number =~ /[^\dx]/io;

  $number =~ s/\D//g;

  {
    local $^W=0; #no warning at next line
    return "invalid"
    unless( length($number) >= 13 || length($number) == 8 || length($number) == 9 #Isracard
    )
    && 0+$number;
  }

  return "visa" if $number =~ /^4[0-8][\dx]{11}([\dx]{3})?$/o;

  return "mastercard" if   $number =~ /^5[1-5][\dx]{14}$/o;

  return "amex" if $number =~ /^3[47][\dx]{13}$/o;

  return "discover"
    if   $number =~ /^30[0-5][\dx]{11}([\dx]{2})?$/o  #diner's: 300-305
    ||   $number =~ /^3095[\dx]{10}([\dx]{2})?$/o     #diner's: 3095
    ||   $number =~ /^3[689][\dx]{12}([\dx]{2})?$/o   #diner's: 36 38 and 39
    ||   $number =~ /^6011[\dx]{12}$/o
    ||   $number =~ /^64[4-9][\dx]{13}$/o
    ||   $number =~ /^65[\dx]{14}$/o;

  return "unsupported" # switch
    if $number =~ /^49(03(0[2-9]|3[5-9])|11(0[1-2]|7[4-9]|8[1-2])|36[0-9]{2})[\dx]{10}([\dx]{2,3})?$/o
    || $number =~ /^564182[\dx]{10}([\dx]{2,3})?$/o
    || $number =~ /^6(3(33[0-4][0-9])|759[0-9]{2})[\dx]{10}([\dx]{2,3})?$/o;

  # redunant with above, catch 49* that's not Switch
  return "visa" if $number =~ /^4[\dx]{12}([\dx]{3})?$/o;

  return "unsupported";
}

sub _validate_cc_number {
  my $number = shift;

  my ($i, $sum, $weight);

  return 0 if $number =~ /[^\d\s]/;

  $number =~ s/\D//g;

  if( $number =~ /^[\dx]{8,9}$/ ) { # Isracard
    $number = "0$number" if length $number == 8;

    for( $i=1; $i < length $number; $i++ ) {
      $sum += substr($number,9-$i,1) * $i;
    }

    return ( $sum % 11 == 0 ) ? 1 : 0;
  }

  return 0 unless length $number >= 13 && 0+$number;

  for( $i = 0; $i < length($number) - 1; $i++ ) {
    $weight = substr($number, -1 * ($i + 2), 1) * (2 - ($i % 2));
    $sum += (($weight < 10) ? $weight : ($weight - 9));
  }

  return ( substr($number, -1) == (10 - $sum % 10) % 10 ) ? 1 : 0;
}

#
# CONTROLLER HANDLERS
#
sub index {
  my $self = shift;

  $self->render('support');
}

sub irc {
  my $self = shift;

  $self->render('support-irc');
}

sub howto {
  my $self = shift;

  $self->render('support-howto');
}

sub contribute_get {
  my $self = shift;

  $self->render('support-contribute');
}

sub donate_get {
  my $self = shift;

  my $v = $self->flash('values') // {
    donor_name => '',
    donor_email => '',
    donor_amount => 25,
    cc_name => '',
    cc_number => '',
    cc_expirty_year => '',
    cc_expirty_month => '',
    cc_security_code => '',
  };

  $self->stash(v => $v);

  $self->render('support-contribute-donate');
}

sub donate_post {
  my $self = shift;

  my $v = {
    donor_name        => $self->param('donor_name')        // 'Anonymous',
    donor_email       => $self->param('donor_email')       // '',
    donor_amount      => $self->param('donor_amount')      // '25.00',
    payment_type      => $self->param('payment_type')      // 'card',
    cc_name           => $self->param('cc_name')           // '',
    cc_number         => $self->param('cc_number')         // '',
    cc_expiry_month   => $self->param('cc_expiry_month')   // 0,
    cc_expiry_year    => $self->param('cc_expiry_year')    // 0,
    cc_security_code  => $self->param('cc_security_code')  // '',
  };

  # store entered values for errors
  $self->flash( values => $v );

  my @names = split / /, $v->{cc_name};
  my( $first_name, $last_name ) = ( shift @names, join ' ', @names );

  # validate the donor name
  unless( length trim $v->{donor_name} ) {
    $self->flash(page_errors => "Please enter a name to attribute your donation to. Anonymous works too if you wish.");
    return $self->redirect_to('supportcontributedonate');
  }

  # validate the donor email
  unless( $v->{donor_email} =~ m/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/ ) {
    $self->flash(page_errors => "Please enter a valid email address so we can thank you.");
    return $self->redirect_to('supportcontributedonate');
  }

  # validate the donor amount
  unless( $v->{donor_amount}+0 > 0 ) {
    $self->flash(page_errors => "Please specify at least a dollar.");
    return $self->redirect_to('supportcontributedonate');
  }

  my $cc_type = _get_cc_type( $v->{cc_number} );

  if( $v->{payment_type} eq 'card' ) {
    # validate the cc name
    unless( length trim $v->{cc_name} ) {
      $self->flash(page_errors => "Please enter the full name on the front of your card.");
      return $self->redirect_to('supportcontributedonate');
    }

    # validate the cc number
    unless( _validate_cc_number( $v->{cc_number} ) ) {
      $self->flash(page_errors => "Please enter a valid credit card number.");
      return $self->redirect_to('supportcontributedonate');
    }

    # validate the cc type
    unless( grep { $_ eq $cc_type } qw(visa discover amex mastercard) ) {
      $self->flash(page_errors => "Please enter a supported credit card number. We accept Visa, MasterCard, Discover and AmEx.");
      return $self->redirect_to('supportcontributedonate');
    }

    # validate the cc expiry
    my $now = gmtime;
    unless( ( $now->year < $v->{cc_expiry_year} ) ||
            ( $now->year == $v->{cc_expiry_year} && $now->mon < $v->{cc_expiry_month} ) ) {
      $self->flash(page_errors => "Please enter a credit card that hasn't expired.");
      return $self->redirect_to('supportcontributedonate');
    }

    # validate the cc security code
    unless( length trim $v->{cc_security_code} ) {
      $self->flash(page_errors => "Please enter the security code for your card. It's the last " . ( $cc_type eq 'amex' ? "4 digits on the front of your card." : "3 digits on the back of your card.") );
      return $self->redirect_to('supportcontributedonate');
    }

    # retrieve the PayPal transaction information from the cache
    # and rebuild as required
    my $pp_context = $self->cache->get('pp_context');

    unless( ref $pp_context eq 'Canvas::Util::PayPal::API' ) {
      $self->app->log->debug('Rebuilding PayPal API context ...');
      $pp_context = Canvas::Util::PayPal::API->new(
        client_id     => $self->config->{paypal}{client_id},
        client_secret => $self->config->{paypal}{client_secret},
      );

      $self->cache->set(pp_context => $pp_context);
    };


    # create our payment object
    my $pp_payment = Canvas::Util::PayPal::Payment->new;
    my $ret = $pp_payment->create($pp_context, {
      intent => 'sale',
      payer => {
        payment_method => "credit_card",
        funding_instruments => [{
          credit_card => {
            type          => $cc_type,
            number        => "$v->{cc_number}",
            expire_month  => "$v->{cc_expiry_month}",
            expire_year   => "$v->{cc_expiry_year}",
            cvv2          => "$v->{cc_security_code}",
            first_name    => $first_name,
            last_name     => $last_name,
          }
        }]
      },
      transactions => [{
        item_list => {
          items => [
            {
              name      => "Korora Donation",
              sku       => "Korora Donation",
              price     => "$v->{donor_amount}",
              currency  => "USD",
              quantity  => 1,
            }
          ]
        },
        amount => {
          total     => "$v->{donor_amount}",
          currency  => "USD"
        },
        description => "Personal donation to the Korora Project."
      }]
    });

    # TODO: remove
    say Dumper $ret;

    # check payment state
    if( $ret->{state} eq 'approved' ) {
      # reset flash values
      #$self->flash( values => {} );
      $self->flash(page_success => "Thank you for your donation. Korora will only get better with your contribution.");

      my $created = Time::Piece->strptime( $ret->{creation_time}, '%Y-%m-%dT%H:%M:%SZ' );

      my $d = Canvas::Store::Donation->create({
        payment_id      => $ret->{id},
        transaction_id  => $ret->{transactions}[0]{related_resources}[0]{sale}{id},
        amount          => $ret->{transactions}[0]{amount}{total},
        name            => $v->{donor_name},
        email           => $v->{donor_email},
        paypal_raw      => j($ret),
        created         => $created,
      });
    }
    else {
      $self->flash(page_errors => "Your transaction could not be completed. Nothing has been charged to your card.");
    }
  }

  $self->redirect_to('supportcontributedonate');
}

sub sponsor_get {
  my $self = shift;

  $self->render('support-contribute-sponsor');
}

sub sponsor_post {
  my $self = shift;

  $self->redirect_to('supportcontributesponsor');
}

1;
