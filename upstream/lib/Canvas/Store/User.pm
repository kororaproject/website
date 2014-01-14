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
package Canvas::Store::User;

use strict;
use Mojo::Base 'Canvas::Store';

#
# PERL INCLUDES
#
use Digest::MD5 qw(md5);

#
# LOCAL INCLUDES
#
use Canvas::Util qw(get_random_bytes);

#
# MODEL DEFINITION
#
__PACKAGE__->table('canvas_user');
__PACKAGE__->columns(All => qw/id username email password status realname description organisation access created updated/);

#
# N:N MAPPINGS
#
__PACKAGE__->has_many(template_memberships  => 'Canvas::Store::TemplateMembership'    => 'user_id');
__PACKAGE__->has_many(user_memberships      => 'Canvas::Store::UserMembership'        => 'user_id');
__PACKAGE__->has_many(ratings               => 'Canvas::Store::Rating'                => 'user_id');

__PACKAGE__->has_many(meta                  => 'Canvas::Store::UserMeta'              => 'user_id');
__PACKAGE__->has_many(templates             => [ 'Canvas::Store::TemplateMembership'  => 'user_id' ]);

# default value for created
__PACKAGE__->set_sql(MakeNewObj => qq{
INSERT INTO __TABLE__ (created, updated, %s)
VALUES (UTC_TIMESTAMP(), UTC_TIMESTAMP(), %s)
});

#
# INFLATOR/DEFLATORS
#
__PACKAGE__->has_a(
  created => 'Time::Piece',
  inflate => sub { my $t = shift; ( $t eq "0000-00-00 00:00:00" ) ? gmtime(0) : Time::Piece->strptime($t, "%Y-%m-%d %H:%M:%S") },
  deflate => sub { shift->strftime("%Y-%m-%d %H:%M:%S") }
);

__PACKAGE__->has_a(
  updated => 'Time::Piece',
  inflate => sub { my $t = shift; ( $t eq "0000-00-00 00:00:00" ) ? gmtime(0) : Time::Piece->strptime($t, "%Y-%m-%d %H:%M:%S") },
  deflate => sub { shift->strftime("%Y-%m-%d %H:%M:%S") }
);

__PACKAGE__->set_sql(update => qq {
UPDATE __TABLE__
  SET    updated = UTC_TIMESTAMP(), %s
  WHERE  __IDENTIFIER__
});

my $itoa64 = './0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

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

  my $count_log2 = index($itoa64, substr( $setting, 3, 1 ));
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
  $output .= substr( $itoa64, ( 8 + 5 ), 1 );
  $output .= _encode64($input, 6);

  return $output;
}
sub _encode64 {
  my( $input, $count ) = @_;
  my $output = '';
  my $i = 0;

  while( $i < $count ) {
    my $value = ord( substr $input, $i++, 1);
    $output .= substr $itoa64, ($value & 0x3f), 1;

    if( $i < $count ) {
      $value |= ord( substr $input, $i, 1 ) << 8;
    }

    $output .= substr $itoa64, (($value >> 6) & 0x3f), 1;

    last if ($i++ >= $count);

    if( $i < $count ) {
      $value |= ord( substr $input, $i, 1 ) << 16;
    }

    $output .= substr $itoa64, (($value >> 12) & 0x3f), 1;

    last if( $i++ >= $count );

    $output .= substr $itoa64, (($value >> 18) & 0x3f), 1;
  }

  return $output;
}


sub metadata_clear($$) {
  my( $self, $key ) = @_;

  # clears all metadata items of the specified key
  foreach my $m ( grep { $key eq $_->meta_key } $self->meta ) {
    $m->delete;
  }
}

sub metadata($$) {
  my( $self, $key ) = @_;

  my @meta = grep { $key eq $_->meta_key } $self->meta;

  return ( @meta ) ? $meta[0]->meta_value : undef;
}

sub is_active_account($) {
  return ( shift->status // '' ) eq 'active';
}

#
# ACCESS CONTROL
#

#
# bit: 7 = god
#      6 = reserved
#      5 = reserved
#      4 = reserved
#      3 = can_documentation_moderate
#      2 = can_news_moderate
#      1 = can_engage_moderate
#      0 = can_engage
#
sub is_engage_moderator($) {
  return ( shift->access // 0 ) & 0x02;
}

sub is_news_moderator($) {
  return ( shift->access // 0 ) & 0x04;
}

sub is_document_moderator($) {
  return ( shift->access // 0 ) & 0x08;
}

sub is_admin($) {
  return ( shift->access // 0 ) & 0x80;
}

1;
