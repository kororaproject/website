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
package Canvas::Store::User;

use strict;
use base 'Canvas::Store';

#
# PERL INCLUDES
#
use Digest::MD5 qw(md5);
use Data::Dumper;

#
# MODEL DEFINITION
#
__PACKAGE__->table('kwp_users');
__PACKAGE__->columns(All => qw/ID user_login user_pass user_nicename user_email user_url user_registered user_activation_key user_status display_name/);

my $itoa64 = './0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

sub validate_password($$) {
  my ( $self, $pass ) = @_;

  my $setting = $self->user_pass;

  my $id = substr($setting, 0, 3);

  # wordpress uses "$P$"
  return 0 if ($id != '$P$' && $id != '$H$');

  my $count_log2 = index($itoa64, substr $setting, 3, 1);
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

  return $output eq $self->user_pass;
}

sub _encode64 {
  my ($input, $count) = @_;
  my $output = '';
  my $i = 0;

  while ($i < $count) {
    my $value = ord( substr $input, $i++, 1);
    $output .= substr $itoa64, ($value & 0x3f), 1;

    if ($i < $count) {
      $value |= ord( substr $input, $i, 1 ) << 8;
    }

    $output .= substr $itoa64, (($value >> 6) & 0x3f), 1;

    last if ($i++ >= $count);

    if ($i < $count) {
      $value |= ord( substr $input, $i, 1 ) << 16;
    }

    $output .= substr $itoa64, (($value >> 12) & 0x3f), 1;

    last if ($i++ >= $count);

    $output .= substr $itoa64, (($value >> 18) & 0x3f), 1;
  }


  return $output;
}

1;

