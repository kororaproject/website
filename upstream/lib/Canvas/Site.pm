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
package Canvas::Site;

use warnings;
use strict;

use Mojo::Base 'Mojolicious::Controller';

#
# PERL INCLUDES
#
use Data::Dumper;
use Mojo::Util qw(b64_encode url_escape url_unescape);
use Time::Piece;
use Time::HiRes qw(gettimeofday);
use Digest::SHA qw(sha512);

#
# LOCAL INCLUDES
#
use Canvas::Store::User;
use Canvas::Store::UserMeta;
use Canvas::Store::WPUser;

#
# CONSTANTS
#
use constant DOWNLOAD_MAP => [
{
  name      => 'Korora 20',
  version   => '20',
  codename  => 'Peach',
  isStable  => 0,
  isCurrent => 1,
  released  => '29 November 2013',
  available => 1,
  isos => {
    i686 => {
      cinnamon => {
        url => {
          http => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-beta-i386-cinnamon-live.iso/download',
        },
        checksum => {
          md5     => '6d9e5953effe741298c037a1ba66e4a7',
          sha     => '5063a350fc966f37d1959c2f309eddc717d46fae',
          sha256  => '76f4c38387388ac695f68dd0333a90dcd897317f793a3fdf4998260c84c45f13',
        },
      },
      gnome => {
        url => {
          http => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-beta-i386-gnome-live.iso/download',
        },
        checksum => {
          md5     => 'c6ef9ec1c56197d13bdc6f54f58c2c18',
          sha     => 'ae37750b48bd5849b6806626bcad32d625c51d1c',
          sha256  => '88958873bd396a5470255c747cb35dec568df4048b2fb95d1383698c461ab6ad',
        },
      },
      kde => {
        url => {
          http => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-beta-i386-kde-live.iso/download',
        },
        checksum => {
          md5     => '233c1522c9f53f2be2de1498fa2157ee',
          sha     => 'a541c4938f919aa477bb04b3b90ca1432619f0ac',
          sha256  => 'e45936c17a5d8f8d508492d1e295ea64e99051daaf560dcbeb69a703781966bc',
        },
      },
      mate => {
        url => {
          http => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-beta-i386-mate-live.iso/download',
        },
        checksum => {
          md5     => '14b7594011a078d4fac7d848dcca06c8',
          sha     => '72f98c04f1ba791e8180279ab9e220f38c5be198',
          sha256  => '4d25d654a1db2295c2de6e6819f168c92e65f44b35141be7e75cb36c082822d3',
        },
      },
      xfce => {
        url => {
          http => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-beta-i386-xfce-live.iso/download',
        },
        checksum => {
          md5     => '012e5a512db1b787e41ebe34868be671',
          sha     => 'f3d3737ceed52d326aacf44a0b38386422434aa2',
          sha256  => '01bef27250f2e9452855f2be8dffb6a465453ae4382802b7ea062b25c6ad229f'
        },
      },
    },
    x86_64 => {
      cinnamon => {
        url => {
          http => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-beta-x86_64-cinnamon-live.iso/download',
        },
        checksum => {
          md5    => 'cdaad5f13b3ab0de50496ee4842d04cf',
          sha    => 'c1fc7ce6056835a7ee1ab2132536a7e531ca63e5',
          sha256 => '54f5de26b90bfa67ba54f988c30c1a9c2382f7f03766e4630960ccf6f3577ff0'
        },
      },
      gnome => {
        url => {
          http => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-beta-x86_64-gnome-live.iso/download',
        },
        checksum => {
          md5     => 'eb1633dbc2a4ddc5a2bfde813847c512',
          sha     => '479a917cb267d76b0300e23b64f3b34e06867f8e',
          sha256  => 'bbc023c7612acfa9b5a77e899de93128d235e055ef9f5c923ea0367132cb9ae3'
        },
      },
      kde => {
        url => {
          http => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-beta-x86_64-kde-live.iso/download',
        },
        checksum => {
          md5     => '6901173323dfed0c90e425796ca06fa9',
          sha     => '59aa81bb6cd1aa93418b2a16849bc6eeac54e8c9',
          sha256  => '10e1df39ab20f3d8d15c960323983b76e9c4d760889b384f7e6bccf4657c383f'
        },
      },
      mate => {
        url => {
          http => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-beta-x86_64-mate-live.iso/download',
        },
        checksum => {
          md5     => 'bdc2cec74aa727ad5f4e75ec8b5c6ced',
          sha     => 'f528f10dbeed766a58c3147ea4c398bbf53e3615',
          sha256  => '2156a75507a1007016fa74a8d225e2a4224c1ec1fd61beb9c7ecbc15f7d610af',
        },
      },
      xfce => {
        url => {
          http => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-beta-x86_64-xfce-live.iso/download',
        },
        checksum => {
          md5     => '7fb43e9624b2799a37a9ae843d32f872',
          sha     => '2cc3ccf04dd6656761b55437e94325401300c62f',
          sha256  => '0ed3d599c1992663de65af4dc716adb38d3e1ddc36994061c635562c436c4eb6',
        },
      },
    },
  },
},
{
  name      => 'Korora 19.1',
  version   => '19.1',
  codename  => 'Bruce',
  isStable  => 1,
  isCurrent => 1,
  released  => '07 October 2013',
  available => 1,
  isos => {
    i686 => {
      cinnamon => {
        url => {
          http    => 'http://sourceforge.net/projects/kororaproject/files/19/korora-19.1-i386-cinnamon-live.iso/download',
          torrent => 'http://burnbit.com/download/258852/korora_19_1_i386_cinnamon_live_iso',
        },
        checksum => {
          md5     => 'be8efdd7b3db9b860f399abd891d07a9',
          sha     => '0978fb4f54f306c8f476e1109f7f872c27304757',
          sha256  => 'a0f287636dc2264a2fdee4b422b518337bb6b26e3e9f1775ccbad2e5621a9e6f',
        },
      },
      gnome => {
        url => {
          http    => 'http://sourceforge.net/projects/kororaproject/files/19/korora-19.1-i386-gnome-live.iso/download',
          torrent => 'http://burnbit.com/download/258850/korora_19_1_i386_gnome_live_iso',
        },
        checksum => {
          md5     => 'dc4df9822705383aeb287ce77682cf10',
          sha     => '59e9ba6b456078c65eae1adcd724b94ecc3f052d',
          sha256  => 'f8cf78c06b7ee5dd8821f08fcdbfb075ff08661ac3672a830c81458670ded214'
        },
      },
      kde => {
        url => {
          http    => 'http://sourceforge.net/projects/kororaproject/files/19/korora-19.1-i386-kde-live.iso/download',
          torrent => 'http://burnbit.com/download/258849/korora_19_1_i386_kde_live_iso',
        },
        checksum => {
          md5     => 'd57dac081ec565fcf7d03ce87782cc28',
          sha     => '5383bf026e97b0663ddbb452a106ff9ebfae2de7',
          sha256  => '08209b346ca67b998937d41a05835f98c5a2f015c93c68b85a56bd2e6fede7b8',
        },
      },
      mate  => {
        url => {
          http    => 'http://sourceforge.net/projects/kororaproject/files/19/korora-19.1-i386-mate-live.iso/download',
          torrent => 'http://burnbit.com/download/258851/korora_19_1_i386_mate_live_iso',
        },
        checksum => {
          md5     => '5b3dc6e039a99246cea3aa1d1df834d3',
          sha     => '1e66d5083ad607446ed8850baeda8b32dbba143a',
          sha256  => 'c7728ef26cc9e75757ff99d56752c955f70494b5f2a512c2a44138d15961af23'
        },
      },
    },
    x86_64 => {
      cinnamon => {
        url => {
          http    => 'http://sourceforge.net/projects/kororaproject/files/19/korora-19.1-x86_64-cinnamon-live.iso/download',
          torrent => 'http://burnbit.com/download/258848/korora_19_1_x86_64_cinnamon_live_iso',
        },
        checksum => {
          md5     => '25742ef9af59ebb5765e30b8a4414a0e',
          sha     => 'f0718555cca66ac417c8484e40ab876f75f7eff1',
          sha256  => 'c274d70ae0aa2ce818237b248cb0ec2c5d8f76e8b76e729856bbc35fe0a34f38',
        },
      },
      gnome => {
        url => {
          http    => 'http://sourceforge.net/projects/kororaproject/files/19/korora-19.1-x86_64-gnome-live.iso/download',
          torrent => 'http://burnbit.com/download/258845/korora_19_1_x86_64_gnome_live_iso',
        },
        checksum => {
          md5     => 'e1cfbef695af85b9f0094ecac6d7cb67',
          sha     => '95cc4648564a4dac6538206020423ca18746fa75',
          sha256  => '698956d7af8279c32730d60887a22e3b6ffdbd2e4c9b653e0833a9065ba29d54'
        },
      },
      kde => {
        url => {
          http    => 'http://sourceforge.net/projects/kororaproject/files/19/korora-19.1-x86_64-kde-live.iso/download',
          torrent => 'http://burnbit.com/download/258847/korora_19_1_x86_64_kde_live_iso',
        },
        checksum => {
          md5     => '62cc01b7cc8d111c5c80248ad3380d71',
          sha     => 'fc4d071309957cc524b7cba110ae7ab1cb0b3e09',
          sha256  => 'a30cbef47b369beac8cc7a180338a9d77b3aba812d5a630230eb38acadf11047'
        },
      },
      mate => {
        url => {
          http    => 'http://sourceforge.net/projects/kororaproject/files/19/korora-19.1-x86_64-mate-live.iso/download',
          torrent => 'http://burnbit.com/download/258846/korora_19_1_x86_64_mate_live_iso',
        },
        checksum => {
          md5     => '75344ea4e67bb7454b5dc9ea4a7dc3e5',
          sha     => '683433b865d81e6920b9a0288e03161df5a39bf6',
          sha256  => '5d79b3e3a01c37f5dd80d87e894e2ed152555b6dcbdeeac425a06387c08741c2'
        },
      },
    },
  },
},
{
  name      => 'Korora 18',
  version   => '18',
  codename  => 'Flo',
  isStable  => 1,
  isCurrent => 1,
  released  => '01 May 2013',
  available => 1,
  isos => {
    i686 => {
      gnome => {
        url => {
          http => 'http://sourceforge.net/projects/kororaproject/files/18/korora-18-i386-gnome-live.iso/download',
        },
        checksum => {
          md5     => '6b2937fc76599c82b4f1bf5eb87fc2ed',
          sha     => '91528703cbd314ca32b42df5b064dab526199ac8',
          sha256  => '5cf1f3192cef63c8eba{bfb3f6634d15aac8b7662c1a9bc913b528f88770fa25'
        },
      },
      kde => {
        url => {
          http => 'http://sourceforge.net/projects/kororaproject/files/18/korora-18-i386-kde-live.iso/download',
        },
        checksum => {
          md5     => 'e6f31d4ff03c1c6cc79123ec1bec3107',
          sha     => '4421274f16068f5194f3e9f5b5459a9ad86efbcb',
          sha256  => 'c359d3142157d3a0c15689d9e7e00f29b7d90681474d8b5d58125475ff6470ba'
        },
      },
    },
    x86_64 => {
      gnome => {
        url => {
          http => 'http://sourceforge.net/projects/kororaproject/files/18/korora-18-x86_64-gnome-live.iso/download',
        },
        checksum => {
          md5     => '35720eed9123f973d9b3590cf29670de',
          sha     => '240fef106e8da4fd932d646ee337f2a7d37bd436',
          sha256  => '226d1c7c0af6262a906dacf88cee09efb62b7f25ff47357dff9da95ef7d6d0b9',
        },
      },
      kde => {
        url => {
          http => 'http://sourceforge.net/projects/kororaproject/files/18/korora-18-x86_64-kde-live.iso/download',
        },
        checksum => {
          md5     => 'ad140e9aaa19bdf5b5d4fd369b02705a',
          sha     => '4c6df0e8e6d32aa40789e63598e41a0fc7cfbd24',
          sha256  => 'ed1caa59d2bf1f120c6392e79937b2db23fe21935ff4a6f9503760cd52979213'
        },
      },
    },
  },
}];

#
# INTERNAL HELPERS
#

#
# create_auth_token()
#
sub create_auth_token {
  my $bytes;

  # extract randomness from /dev/urandom
  if( open( DEV, "/dev/urandom" ) ) {
    read( DEV, $bytes, 48 );
    close( DEV );
  }
  # otherwise seed from the sha512 sum of the current time
  # including microseconds
  else {
    my( $t, $u ) = gettimeofday();
    $bytes = substr sha512( $t . '.' . $u ), 0, 48;
  }

  my $token = b64_encode( $bytes );
  chomp $token;

  return $token;
}


#
# controller handlers
#
sub index {
  my $self = shift;

  #return $self->redirect_to('login') unless( $self->is_user_authenticated );

  $self->render('index');
}

sub discover {
  my $self = shift;

  $self->render('discover');
}

sub download {
  my $self = shift;

  $self->stash( map => DOWNLOAD_MAP );

  $self->render('download');
}

sub login {
  my $self = shift;

  $self->render('login');
}

sub authenticate_any {
  my $self = shift;
  my $json = Mojo::JSON->new;
  my $data = $json->decode($self->req->body);

  # collect first out of the parameters and then json decoded body
  my $user = $self->param('u') // $data->{u} // '';
  my $pass = $self->param('p') // $data->{p} // '';

  # extract the redirect url and fall back to the index
  my $url = $self->param('redirect_to') // $data->{redirect_to} // '/';

  # TODO: remove after 2 months and 2 weeks of live

  # attempt to find new backend user
  my $u = Canvas::Store::User->search({ username => $user })->first;

  # if now found fallback to WP backend detection
  unless( defined $u ) {
    my $wp = Canvas::Store::WPUser->search({ user_login => $user })->first;

    # start migration if a WP user is found and the password is valid
    if( defined $wp && $wp->validate_password( $pass ) ) {

      # create new user based on WP details
      $u = Canvas::Store::User->create({
        username  => $user,
        password  => $wp->user_pass,
        email     => $wp->user_email,
      });

      # generate activiation token
      my $token = create_auth_token;

      my $um = Canvas::Store::UserMeta->create({
        user_id     => $u->id,
        meta_key    => 'activation_token',
        meta_value  => url_escape $token,
      });

      my $activation_key = substr( $token, 0, 31 );
      # current url for dev and testing, assuming that when this hits prod it will replace current website on current domain.
      my $activation_url = 'https://canvas.kororaproject.org/activate/' . $user . '?token=' . url_escape substr( $token, 31 );
      #my $activation_url = 'https://kororaproject.org/activate/' . $user . '?token=' . url_escape substr( $token, 31 );

      my $message = "" .
        "G'day,\n\n" .
        "Thank you for continuing to be a part of our Korora community.\n\n".
        "Your activiation key is: " . $activation_key . "\n\n" .
        "In order to activate your migrated Korora Prime account, copy your activation key and follow the prompts at: " . $activation_url . "\n\n" .
        "Please note that you must activate your account within 24 hours.\n\n" .
        "Regards,\n" .
        "The Korora Team.\n";

      # send the activiation email
      $self->mail(
        to      => $u->email,
        from    => 'accounts@kororaproject.org',
        subject => 'Korora Project - Prime Registration',
        data    => $message,
      );

      $self->flash( redirect_to => $url );

      return $self->redirect_to('/registered');
    }
  }

  # TODO: END

  unless( $self->authenticate($user, $pass) ) {
    $self->flash( page_errors => 'The username or password was incorrect. Perhaps your account has not been activated?' );
  }

  return $self->redirect_to( $url );
};

sub deauthenticate_any {
  my $self = shift;

  $self->logout;

  # extract the redirect url and fall back to the index
  my $url = $self->param('redirect_to') // '/';

  return $self->redirect_to( $url );
};

sub activated {
  my $self = shift;

  my $username = $self->flash('username');

  return $self->redirect_to( '/' ) unless defined $username;

  $self->stash( username => $username );
  $self->render('activated');
}

sub activate_get {
  my $self = shift;

  my $suffix = $self->param('token');
  my $username = $self->param('username');

  # lookup the requested account for activation
  my $u = Canvas::Store::User->search({ username => $username })->first;

  # redirect to home unless account and activation token suffix exists
  return $self->redirect_to('/') unless(
    defined $u &&
    defined $suffix
  );

  my $error = $self->flash('error') // { code => 0, message => '' };

  $self->stash(
    username    => $username,
    error       => $error
  );

  $self->render('activate');
}

sub activate_post {
  my $self = shift;

  my $username = $self->param('username');
  my $prefix = $self->param('prefix');
  my $suffix = $self->param('token');
  my $url = $self->param('redirect_to') // '/';

  # lookup the requested account for activation
  my $u = Canvas::Store::User->search({ username => $username })->first;

  # redirect unless account and activation token prefix/suffix exists
  return $self->redirect_to( $url ) unless(
    defined $u &&
    defined $prefix &&
    defined $suffix
  );

  # build the supplied token and fetch the stored token
  my $token_supplied = $prefix . url_unescape( $suffix );
  my $token = url_unescape( $u->metadata('activation_token') // '' );

  # redirect to same page unless supplied and stored tokens match
  unless( $token eq $token_supplied ) {
    $self->flash( page_errors => 'Your token is invalid.' );
    return $self->redirect_to( $self->url_with('current') );
  };

  # remove activation if account age is more than 24 hours
  # and then return to redirect or home
  my $now = gmtime;
  if( ($now - $u->created) > 86400 ) {
    $self->flash( page_errors => 'Activation of this account has been over 24 hours.' );

    $u->metadata_clear('activiation_token');
    $u->delete;

    return $self->redirect_to( $url );
  }

  $u->status('active');
  $u->update;

  $u->metadata_clear('activation_token');

  $self->flash( username => $username );

  $self->redirect_to('/activated');
}

sub forgot_post {
  my $self = shift;

  my $email = $self->param('email');

  # extract the redirect url and fall back to the index
  my $url = $self->param('redirect_to') // '/';

  # validate email address
  unless( $email =~ m/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/ ) {
    $self->flash( page_errors => 'Your email address is invalid.' );

    return $self->redirect_to( $url );
  }

  my $u = Canvas::Store::User->search({ email => $email })->first;

  # validate email is available
  unless( defined $u ) {
    $self->flash( page_errors => 'Your email is not registered.' );

    return $self->redirect_to( $url );
  }

  # change account status to pending
  $u->status('pending');
  $u->update;

  # generate activiation token
  my $token = create_auth_token;

  my $um = Canvas::Store::UserMeta->create({
    user_id     => $u->id,
    meta_key    => 'activation_token',
    meta_value  => url_escape $token,
  });

  my $activation_key = substr( $token, 0, 31 );
  # current url for dev and testing, assuming that when this hits prod it will replace current website on current domain.
  my $activation_url = 'https://canvas.kororaproject.org/activate/' . $u->username . '?token=' . url_escape substr( $token, 31 );
  #my $activation_url = 'https://kororaproject.org/activate/' . $u->username . '?token=' . url_escape substr( $token, 31 );

  my $message = "" .
    "G'day,\n\n" .
    "We've temporarily deactivated your account to prevent unauthorised activity.\n\n".
    "Your activiation key is: " . $activation_key . "\n\n" .
    "In order to activate your Korora Prime account, copy your activation key and follow the prompts at: " . $activation_url . "\n\n" .
    "Please note that you must re-activate your account within 24 hours.\n\n" .
#      "If you have any questions regarding his process, click 'Reply' in your email client and we'll be only too happy to help.\n\n" .
    "Regards,\n" .
    "The Korora Team.\n";

  # send the activiation email
  $self->mail(
    to      => $email,
    from    => 'accounts@kororaproject.org',
    subject => 'Korora Project - Prime Re-activation / Lost Password',
    data    => $message,
  );

  $self->flash( page_info => 'A re-activation email has been sent to your account.' );
  $self->redirect_to( $url );
}

sub registered_get {
  my $self = shift;

  my $url  = $self->flash('redirect_to');

  return $self->redirect_to( '/' ) unless defined $url;

  $self->stash( redirect_to => $url );
  $self->render('registered');
}

sub register_get {
  my $self = shift;

  my $error = $self->flash('error') // { code => 0, message => '' };
  my $values = $self->flash('values') // { user => '', email => '' };
  my $url = $self->param('redirect_to') // ( $self->flash('redirect_to') // '' );

  $self->stash( error => $error, values => $values, redirect_to => $url );

  $self->render('register');
}

sub register_post {
  my $self = shift;

  # extract the redirect url and fall back to the index
  my $url = $self->param('redirect_to') // '/';

  # grab registration details
  my $user = $self->param('user');
  my $pass = $self->param('pass');
  my $pass_confirm = $self->param('confirm');
  my $email = $self->param('email');

  # flash the redirect and previous values for future redirects
  $self->flash(
    redirect_to => $url,
    values      => { user => $user, email => $email }
  );

  # validate username
  unless( $user =~ m/^[a-zA-Z0-9_]+$/ ) {
    $self->flash( error => { code => 1, message => 'Your username can only consist of alphanumeric characters and underscores only [A-Z, a-z, 0-9, _].' });

    return $self->redirect_to('/register');
  }

  # validate user name is available
  my $u = Canvas::Store::User->search({
    username => $user,
  })->first;

  if( defined $u ) {
    $self->flash( error => { code => 2, message => 'That username already exists.' } );

    return $self->redirect_to('/register');
  }

  # validate email address
  unless( $email =~ m/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/ ) {
    $self->flash( error => { code => 3, message => 'Your email address is invalid.' });

    return $self->redirect_to('/register');
  }

  # validate email is available
  if( defined Canvas::Store::User->search({ email => $email, })->first ) {
    $self->flash( error => { code => 4, message => 'That email already exists.' } );

    return $self->redirect_to('/register');
  }

  # validate passwords have sufficient length
  if( length $pass < 8 ) {
    $self->flash( error => { code => 5, message => 'Your password must be at least 8 characters long.' });

    return $self->redirect_to('/register');
  }

  # validate passwords match
  if( $pass ne $pass_confirm ) {
    $self->flash( error => { code => 6, message => 'Your passwords don\'t match.' } );

    return $self->redirect_to('/register');
  };

  $u = Canvas::Store::User->create({
    username  => $user,
    email     => $email,
  });

  if( defined $u ) {
    # store password as a salted hash
    $u->password( $u->hash_password( $pass ) );
    $u->update;

    # generate activiation token
    my $token = create_auth_token;

    my $um = Canvas::Store::UserMeta->create({
      user_id     => $u->id,
      meta_key    => 'activation_token',
      meta_value  => url_escape $token,
    });

    my $activation_key = substr( $token, 0, 32 );
    # current url for dev and testing, assuming that when this hits prod it will replace current website on current domain.
    my $activation_url = 'https://canvas.kororaproject.org/activate/' . $user . '?token=' . url_escape substr( $token, 32 );
    #my $activation_url = 'https://kororaproject.org/activate/' . $user . '?token=' . url_escape substr( $token, 32 );

    say Dumper $token;

    my $message = "" .
      "G'day,\n\n" .
      "Thank you for registering to be part of our Korora community.\n\n".
      "Your activiation key is: " . $activation_key . "\n\n" .
      "In order to activate your Korora Prime account, copy your activation key and follow the prompts at: " . $activation_url . "\n\n" .
      "Please note that you must activate your account within 24 hours.\n\n" .
#      "If you have any questions regarding his process, click 'Reply' in your email client and we'll be only too happy to help.\n\n" .
      "Regards,\n" .
      "The Korora Team.\n";

    # send the activiation email
    $self->mail(
      to      => $email,
      from    => 'accounts@kororaproject.org',
      subject => 'Korora Project - Prime Registration',
      data    => $message,
    );
  }

  $self->redirect_to('/registered');
}



sub profile_get {
  my $self = shift;

  my $u = Canvas::Store::User->search({
    username  => $self->param('name'),
  })->first;

  $self->stash( user => $u );
  $self->render('profile');
}

sub profile_status_post {
  my $self = shift;

  my $username = $self->param('name')   // '';
  my $email    = $self->param('email')  // '';

  my $result = {};

  if( length $username ) {
    my $u = Canvas::Store::User->search({
      username  => $username,
    })->first;

    $result->{username} = {
      key     => $username,
      status  => defined $u ? 1 : 0,
    };
  }

  if( length $email ) {
    my $e = Canvas::Store::User->search({
      email  => $email,
    })->first;

    $result->{email} = {
      key     => $email,
      status  => defined $e ? 1 : 0,
    }
  }


  $self->render( json => $result );
}


#
# CATCH ALL
sub trap {
  my $self = shift;

  my $path = $self->param('trap');

  # HTML5 mode forwarding based on valid paths
  $self->redirect_to('/');
};



1;
