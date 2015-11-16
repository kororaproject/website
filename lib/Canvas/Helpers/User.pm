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
use Digest::SHA qw(sha512 sha256_hex);
use Mojo::Util qw(url_escape url_unescape);
use Time::Piece;

#
# LOCAL INCLUDES
#
use Canvas::Util qw(get_random_bytes);

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

sub create_auth_token {
  my $bytes = get_random_bytes(48);

  return sha256_hex($bytes);
}

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
  my ($pass, $setting) = @_;

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

  $app->helper('users.account.register' => sub {
    my ($c, $data) = @_;

    my ($user, $email, $pass, $pass_confirm);

    if (my $ed = $data->{email}) {
      $user         = $ed->{username};
      $email        = $ed->{email};
      $pass         = $ed->{password};
      $pass_confirm = $ed->{pass_confirm};
    }
    else {
      return undef;
    }

    # validate username
    unless ($user =~ m/^[a-zA-Z0-9_]+$/) {
      $c->flash(error => {code => 1, message => 'Your username can only consist of alphanumeric characters and underscores only [A-Z, a-z, 0-9, _].'});
      return undef;
    }

    # check the username is available
    my $u = $c->pg->db->query("SELECT * FROM users WHERE username=? LIMIT 1", $user)->hash;

    if (defined $u) {
      $c->flash(error => {code => 2, message => 'That username already exists.'});
      return undef;
    }

    # validate email address
    unless ($email =~ m/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/) {
      $c->flash(error => {code => 3, message => 'Your email address is invalid.'});
      return undef;
    }

    # validate passwords have sufficient length
    if (length $pass < 8) {
      $c->flash(error => {code => 5, message => 'Your password must be at least 8 characters long.'});
      return undef;
    }

    # validate passwords match
    if ($pass ne $pass_confirm) {
      $c->flash(error => {code => 6, message => 'Your passwords don\'t match.'});
      return undef;
    };

    my $user_id = $c->pg->db->query("INSERT INTO users (username,email,password) VALUES (?,?,?) RETURNING ID", $user, $email, $c->users->password->hash($pass))->array->[0];

    # prepare activation email if email provider
    if (my $ed = $data->{email}) {
      # generate activation token
      my $token = create_auth_token;

      my $um = $c->pg->db->query("INSERT INTO usermeta (user_id,meta_key,meta_value) VALUES (?,'activation_token',?)", $user_id, $token);

      my $activation_key = substr $token, 0, 32;
      my $activation_url = $c->url_for('activateprovider', provider => 'email')->query(token => url_escape(substr($token, 32)), username => $user)->to_abs;

      my $message = "" .
        "G'day,\n\n" .
        "Thank you for registering to be part of our Korora community!\n\n" .
        "Please follow the steps below to activate your account.\n\n" .
        "Step 1) This is your activation key, please highlight and copy it:\n" .
        "" . $activation_key . "\n\n" .
        "Step 2) Visit the following Korora webpage:\n" .
        "" . $activation_url . "\n\n" .
        "Step 3) Paste your activation key and click Activate.\n\n" .
        "Please note that you must activate your account within 24 hours.\n\n" .
        "If you run into trouble, please contact webmaster\@kororaproject.org\n\n" .
        "Regards,\n" .
        "The Korora Team.\n";

      # send the activation email
      $c->mail(
        to      => $email,
        from    => 'admin@kororaproject.org',
        subject => 'Korora Project - Prime Registration',
        data    => $message,
      );
    }

    # subscribed "new registration event" notifications
    $c->notify_users(
      'user_notify_on_register',
      1,
      'admin@kororaproject.org',
      'Korora Project - A new Prime email registration',
      "The following Prime account has just been registered:\n" .
      " - username: " . $user . "\n" .
      " - email:    " . $email . "\n\n" .
      "Regards,\n" .
      "The Korora Team.\n"
    );

    return $user_id;
  });

  $app->helper('users.account.activate' => sub {
    my ($c, $data) = @_;

    my ($provider, $u, $username);

    if (my $ed = $data->{email}) {
      $provider = 'Email';
      $username = $ed->{username};

      my $prefix   = $ed->{prefix};
      my $suffix   = $ed->{suffix};

      # check the username is available
      $u = $c->pg->db->query("SELECT u.*, um.meta_value AS activation_token, EXTRACT(EPOCH FROM u.updated)::int AS updated_epoch FROM users u JOIN usermeta um ON (um.user_id=u.id AND um.meta_key='activation_token') WHERE username=? LIMIT 1", $username)->hash;

      # redirect unless account and activation token prefix/suffix exists
      return undef unless $u && $prefix && $suffix;

      # build the supplied token and fetch the stored token
      my $token_supplied = $prefix . url_unescape $suffix;
      my $token = $u->{activation_token};

      # redirect unless account and activation token prefix/suffix exists
      # redirect to same page unless supplied and stored tokens match
      unless ($token eq $token_supplied) {
        $c->flash(page_errors => 'Your token is invalid.');
        return undef;
      };

      # remove activation if account age is more than 24 hours
      # and then return to redirect or home
      my $now = gmtime->epoch;
      if (($now - $u->{updated_epoch}) > 86400) {
        $c->flash(page_errors => 'Activation of this account has been over 24 hours.');

        # store username and email for notification before we delete
        my $username = $u->{username};
        my $email = $u->{email};

        my $db = $c->pg->db;
        my $tx = $db->begin;

        $db->query("DELETE FROM usermeta WHERE user_id=?", $u->{id});
        $db->query("DELETE FROM users WHERE id=?", $u->{id});

        $tx->commit;

        # subscribed "registration event" notifications
        $c->notify_users(
          'user_notify_on_activate',
          1,
          'admin@kororaproject.org',
          'Korora Project - Prime email activation - Time Expiry',
          "The following Prime account has exceeded it's activation time limit:\n" .
          " - username: " . $username . "\n" .
          " - email:    " . $email . "\n\n" .
          "The account has been deleted.\n\n" .
          "Regards,\n" .
          "The Korora Team.\n"
        );

        return undef;
      }

      my $db = $c->pg->db;
      my $tx = $db->begin;

      # prepare realname for updating
      my $realname = $ed->{realname} // $u->{realname};

      # update status and realname
      $db->query("UPDATE users SET status='active', realname=? WHERE id=?", $realname, $u->{id});
      $db->query("DELETE FROM usermeta WHERE meta_key='activation_token' AND user_id=?", $u->{id});

      $tx->commit;
    }
    elsif (my $gd = $data->{github}) {
      $provider = 'GitHub';
      $username     = $gd->{username};

      # OAuth activation duplicates some steps from email registration
      my $realname     = $gd->{realname};
      my $email        = $gd->{email};
      my $pass         = $gd->{pass};
      my $pass_confirm = $gd->{pass_confirm};

      # validate username
      unless ($username =~ m/^[a-zA-Z0-9_]+$/) {
        $c->flash(error => {code => 1, message => 'Your username can only consist of alphanumeric characters and underscores only [A-Z, a-z, 0-9, _].'});
        return undef;
      }

      # check the username is available
      $u = $c->pg->db->query("SELECT * FROM users WHERE username=? LIMIT 1", $username)->hash;

      if ($u) {
        $c->flash(page_errors => 'Username is unavailable.');
        return undef;
      }

      my $db = $c->pg->db;
      my $tx = $db->begin;

      my $pass_hash = $pass ? $c->users->password->hash($pass) : '';

      say Dumper $gd;

      my $user_id = $db->query("INSERT INTO users (username,realname,email,password,status) VALUES (?,?,?,?,'active') RETURNING ID", $username, $realname, $email, $pass_hash)->array->[0];
      $db->query("INSERT INTO usermeta (user_id,meta_key,meta_value) VALUES (?,'oauth_github',?)", $user_id, $gd->{oauth_user});
      $u = $db->query("SELECT * FROM users WHERE id=?", $user_id)->hash;

      $tx->commit;
    }
    else {
      $c->flash(page_errors => 'OAuth provider is not supported.');

      return undef;
    }

    # subscribed "new activation event" notifications
    $c->notify_users(
      'user_notify_on_activate',
      1,
      'admin@kororaproject.org',
      'Korora Project - A new Prime activation via ' . $provider,
      "The following Prime account has just been activated:\n" .
      " - username: " . $username . "\n" .
      "Regards,\n" .
      "The Korora Team.\n"
    );

    return $u;
  });

  $app->helper('users.account.forgot' => sub {
    my ($c, $username, $email) = @_;

    # check the username is available
    my $u = $c->pg->db->query("SELECT * FROM users WHERE username=? AND email=? LIMIT 1", $username, $email)->hash;

    # validate email is available, don't reveal email account information
    unless ($u) {
      $c->flash(page_info => 'An email with further instructions has been sent to: ' . $email);

      return undef;
    }

    # validate account is active, don't reveal email account information
    unless($u->{status} eq 'active') {
      $c->flash(page_info => 'An email with further instructions has been sent to: ' . $email);

      return undef;
    }

    # generate activation token
    my $token = create_auth_token;

    my $db = $c->pg->db;
    my $tx = $db->begin;

    # erase existing tokens
    $db->query("DELETE FROM usermeta WHERE meta_key='password_reset_token' AND user_id=?", $u->{id});
    $db->query("INSERT INTO usermeta (user_id,meta_key,meta_value) VALUES (?,'password_reset_token',?)", $u->{id}, $token);

    $tx->commit;

    my $activation_url = $c->url_for('profilenamereset', name => $u->{username})->query(token => url_escape($token))->to_abs;

    my $message = "" .
      "G'day,\n\n" .
      "You (or someone else) entered this email address when trying to change the password of a Korora Prime account.\n\n".
      "In order to reset the password for your Korora Prime account, continue on and follow the prompts at: " . $activation_url . "\n\n" .
      "If you did not request this password reset, simply ignore this email.\n\n" .
      "Regards,\n" .
      "The Korora Team.\n";

    # send the activation email
    $c->mail(
      to      => $email,
      from    => 'admin@kororaproject.org',
      subject => 'Korora Project - Prime Re-activation / Lost Password',
      data    => $message,
    );

    # subscribed "new registration event" notifications
    $c->notify_users(
      'user_notify_on_lostpass',
      'admin@kororaproject.org',
      'Korora Project - Prime Account - Lost Password',
      "The following Prime account has just been requested lost password re-activation:\n" .
      " - username: " . $u->{username} . "\n" .
      " - email:    " . $u->{email} . "\n\n" .
      "Regards,\n" .
      "The Korora Team.\n"
    );

    return $u;
  });

  $app->helper('users.account.reset' => sub {
    my ($c, $user, $pass, $pass_confirm, $token) = @_;

    # lookup the requested account for activation
    my $u = $c->pg->db->query("SELECT u.*, um.meta_value AS password_reset_token FROM users u JOIN usermeta um ON (u.id=um.user_id) WHERE u.username=? AND meta_key='password_reset_token' LIMIT 1", $user)->hash;

    return undef unless $u;

    # redirect to same page unless supplied and stored tokens match
    unless ($u->{password_reset_token} eq $token) {
      $c->flash(page_errors => 'Your token is invalid.');
      return undef;
    };

    # validate passwords have sufficient length
    if (length $pass < 8) {
      $c->flash(page_errors => 'Your password must be at least 8 characters long.');
      return undef;
    }

    # validate passwords match
    if ($pass ne $pass_confirm) {
      $c->flash(page_errors => 'Your passwords don\'t match.');
      return undef;
    };

    my $db = $c->pg->db;
    my $tx = $db->begin;

    my $pass_hash = $c->users->password->hash($pass);

    # update the password
    $db->query("UPDATE users SET password=? WHERE id=?", $pass_hash, $u->{id});

    # clear token if it exists
    $db->query("DELETE FROM usermeta WHERE meta_key='password_reset_token' AND user_id=?", $u->{id});

    $tx->commit;

    return $u;
  });

  $app->helper('users.validate' => sub {
    my ($c, $user_hash, $password) = @_;

    return 0 unless ref $user_hash eq 'HASH';

    return _crypt_private($password, $user_hash->{password}) eq $user_hash->{password};
  });

  $app->helper('users.password.hash' => sub {
    my ($c, $password) = @_;

    my $random = get_random_bytes(6);
    my $hash   = _crypt_private($password, _gensalt_private($random));

    return length( $hash ) == 34 ? $hash : undef;
  });

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

  $app->helper('users.format_time' => sub {
    my ($self, $time) = (shift, shift);

    my %args = @_>1 ? @_ : ref $_[0] eq 'HASH' ? %{$_[0]} : ();
    $args{format} //= 'distance';

    $time = gmtime($time) unless ref($time) eq 'Time::Piece';

    if ($args{format} eq 'distance') {
      return $app->distance_of_time_in_words($time); 
    }
    else {
      return $time->strftime($args{format});
    }
  });

  $app->helper('users.oauth.link' => sub {
    my ($c, $provider, $data) = @_;

    return unless $c->users->is_active;

    # grab existing oauth links
    my $mk = sprintf("oauth_%s", $provider);
    my $op = $c->pg->db->query("SELECT * FROM usermeta WHERE user_id=? AND meta_key=?", $c->auth_user->{id}, $mk)->hashes;

    my $mv = '';

    if ($provider eq 'github') { $mv = $data->{github}{login} }

    # check for duplicates
    unless (grep {$_->{meta_value} eq $mv} @{$op}) {
      # look for existing link
      my $found = $c->pg->db->query("SELECT meta_value FROM usermeta WHERE user_id=? AND meta_key=? AND meta_value=?", $c->auth_user->{id}, $mk, $mv)->hash;

      # insert if not found
      if ($found) {
        $c->flash(page_errors => 'Profile already registered with OAuth provider account.');
      }
      else {
        $c->flash(page_info => 'Profile registered with OAuth provider account.');
        $c->pg->db->query("INSERT INTO usermeta (user_id,meta_key,meta_value) VALUES (?,?,?)", $c->auth_user->{id}, $mk, $mv);
      }
    };
  });
}


1;

