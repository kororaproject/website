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
package Canvas::Helpers::User;

use Mojo::Base 'Mojolicious::Plugin';

#
# PERL INCLUDES
#
use Data::Dumper;
use Digest::MD5 qw(md5);

#
# CONSTANTS
#

#
# bit: 7 = god
#      6 = reserved
#      5 = reserved
#      4 = reserved
#      3 = can_document_moderate
#      2 = can_news_moderate
#      1 = can_engage_moderate
#      0 = can_engage

use constant {
  ACCESS_ADMIN                => 0x80,
  ACCESS_CAN_DOC_MODERATE     => 0x04,
  ACCESS_CAN_NEWS_MODERATE    => 0x02,
  ACCESS_CAN_ENGAGE_MODERATE  => 0x01,
  ACCESS_CAN_ENGAGE           => 0x00,

  ITOA64 => './0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
};

sub validate_password($$) {
  my ( $self, $pass ) = @_;

  my $setting = $self->password;

  return _crypt_private( $pass, $setting ) eq $self->password;
}

sub hash_password($$) {
  my( $self, $pass ) = @_;

  my $random = get_random_bytes(6);
  my $hash = _crypt_private($pass, _gensalt_private($random));

  return length( $hash ) == 34 ? $hash : undef;
}

sub _crypt_private($$) {
  my ( $pass, $setting ) = @_;

  my $id = substr($setting, 0, 3);

  # wordpress uses "$p$"
  return 0 if( $id ne '$P$' && $id ne '$H$' );

  my $count_log2 = index(ITOA64, substr( $setting, 3, 1 ));
  return 0 if( $count_log2 < 7 || $count_log2 > 30 );

  my $count = 1 << $count_log2;

  my $salt = substr $setting, 4, 8;
  return 0 if( length $salt != 8 );

  my $hash = md5($salt . $pass);
  do {
    $hash = md5($hash . $pass);
  } while (--$count);

  my $output = substr($setting, 0, 12);
  $output .= _encode64($hash, 16);

  return $output;
}

sub _gensalt_private($) {
  my $input = shift;

  my $output = '$P$';
#  $output .= $itoa64[ min($this->iteration_count_log2 + 5, 30)];
  # hardcode iterations to 8
  $output .= substr(ITOA64, ( 8 + 5 ), 1 );
  $output .= _encode64($input, 6);

  return $output;
}
sub _encode64 {
  my( $input, $count ) = @_;
  my $output = '';
  my $i = 0;

  while( $i < $count ) {
    my $value = ord( substr $input, $i++, 1);
    $output .= substr ITOA64, ($value & 0x3f), 1;

    if( $i < $count ) {
      $value |= ord( substr $input, $i, 1 ) << 8;
    }

    $output .= substr ITOA64, (($value >> 6) & 0x3f), 1;

    last if ($i++ >= $count);

    if( $i < $count ) {
      $value |= ord( substr $input, $i, 1 ) << 16;
    }

    $output .= substr ITOA64, (($value >> 12) & 0x3f), 1;

    last if( $i++ >= $count );

    $output .= substr ITOA64, (($value >> 18) & 0x3f), 1;
  }

  return $output;
}

sub register {
  my ($self, $app) = @_;

  $app->helper('users.name' => sub {
    my ($c, $user) = @_;

    $user = $c->auth_user unless ref $user eq 'HASH';

    return $user->{realname} || $user->{username};
  });

  $app->helper('users.is_active' => sub {
    my ($c, $user) = @_;

    $user = $c->auth_user unless ref $user eq 'HASH';

    return ($user->{status} // '') eq 'active';
  });

  $app->helper('users.is_admin' => sub {
    my ($c, $user) = @_;

    $user = $c->auth_user unless ref $user eq 'HASH';

    return ( $user->{access} // 0 ) & ACCESS_ADMIN;
  });

  $app->helper('users.is_document_moderator' => sub {
    my ($c, $user) = @_;

    $user = $c->auth_user unless ref $user eq 'HASH';

    return ( $user->{access} // 0 ) & ACCESS_CAN_DOC_MODERATE;
  });


  $app->helper('users.is_engage_moderator' => sub {
    my ($c, $user) = @_;

    $user = $c->auth_user unless ref $user eq 'HASH';

    return ( $user->{access} // 0 ) & ACCESS_CAN_ENGAGE_MODERATE;
  });

  $app->helper('users.is_news_moderator' => sub {
    my ($c, $user) = @_;

    $user = $c->auth_user unless ref $user eq 'HASH';

    return ( $user->{access} // 0 ) & ACCESS_CAN_NEWS_MODERATE;
  });

  $app->helper('users.validate' => sub {
    my ($c, $user_hash, $password) = @_;

    return 0 unless ref $user_hash eq 'HASH';

    return _crypt_private($password, $user_hash->{password}) eq $user_hash->{password};
  });

  $app->helper('users.format_time' => sub {
    my ($self, $time) = (shift, shift);

    my %args = @_>1 ? @_ : ref $_[0] eq 'HASH' ? %{$_[0]} : ();

    $args{format} //= 'distance';

    if ($args{format} eq 'distance') {
      return $app->distance_of_time_in_words($time); 
    }

  });
}


1;

