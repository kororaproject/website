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
package Website::Download;

use warnings;
use strict;

use Mojo::Base 'Mojolicious::Controller';

#
# PERL INCLUDES
#
use Data::Dumper;
use Mojo::JSON qw(encode_json);

#
# CONSTANTS
#
use constant DOWNLOAD_MAP => {
  desktops => {
    cinnamon  => 'Cinnamon',
    gnome     => 'GNOME',
    kde       => 'KDE',
    mate      => 'MATE',
    xfce      => 'Xfce',
  },

  releases => [
    {
      name      => 'Korora 26',
      version   => '26',
      codename  => 'Bloat',
      isStable  => 1,
      isCurrent => 1,
      released  => '24 September 2017',
      available => 1,
      isos => {
        cinnamon => {
          url => {
            "http"  => 'http://sourceforge.net/projects/kororaproject/files/26/korora-live-cinnamon-26-x86_64.iso/download',
            "torrent" => 'https://dl.kororaproject.org/pub/isos/releases/26/x86_64/korora-live-cinnamon-26-x86_64.iso.torrent',
          },
          checksum => {
            md5     => 'e8956c55bd5ad1f283763c59f5dc145d',
            sha1    => '5b49b1b81c342d6ba0b9272ab9de340717c4f0a5',
            sha256  => 'ec0d5443214554f4bdf7f0e92c1f1aaa10d46114b192a66ad527892949241ced'
          },
        },
        gnome => {
          url => {
            "http"  => 'http://sourceforge.net/projects/kororaproject/files/26/korora-live-gnome-26-x86_64.iso/download',
            "torrent" => 'https://dl.kororaproject.org/pub/isos/releases/26/x86_64/korora-live-gnome-26-x86_64.iso.torrent',
          },
          checksum => {
            md5     => '16f60597dd6c283b99f822458afe4858',
            sha1    => '5e4896e7406a3304e10093994df505eb839cf8b3',
            sha256  => 'd9e0cf3b69c680e7587352820e4d7cfe7c37f4f0ff354434e8f704773edfe5ee'
          },
        },
        kde => {
          url => {
            "http"  => 'http://sourceforge.net/projects/kororaproject/files/26/korora-live-kde-26-x86_64.iso/download',
            "torrent" => 'https://dl.kororaproject.org/pub/isos/releases/26/x86_64/korora-live-kde-26-x86_64.iso.torrent',
          },
          checksum => {
            md5     => '92efe48d0b04969d9414a9fbbbaec8bd',
            sha1    => '8ba7cc75e939952ec8c966db1e095154419fe955',
            sha256  => 'ded79e93610578d6861ababe57175f62521734e103c3704ef3be73dd93e4f25e'
          },
        },
        mate => {
          url => {
            "http"  => 'http://sourceforge.net/projects/kororaproject/files/26/korora-live-mate-26-x86_64.iso/download',
            "torrent" => 'https://dl.kororaproject.org/pub/isos/releases/26/x86_64/korora-live-mate-26-x86_64.iso.torrent',
          },
          checksum => {
            md5     => '8af3ae6d203e0fb9c7ceb2b77770aed9',
            sha1    => 'fa96dafd99caf04bb83b71286934a0f368c864ef',
            sha256  => '9c13132c5ac45e5a3cdc7443202ffab31510bf6b8a57691142b93a6415268129'
          },
        },
        xfce => {
          url => {
            "http"  => 'http://sourceforge.net/projects/kororaproject/files/26/korora-live-xfce-26-x86_64.iso/download',
            "torrent" => 'https://dl.kororaproject.org/pub/isos/releases/26/x86_64/korora-live-xfce-26-x86_64.iso.torrent',
          },
          checksum => {
            md5     => '5edbfb1388035e20348669a09b2a8990',
            sha1    => 'b63c4501a8f31f89711230db3342cae9ac25ce82',
            sha256  => 'bdecffb23b752e5b71126ea0ea0ecea187d721cb311926bed747100bf901e9b7'
          },
        },
      },
    },
    {
      name      => 'Korora 25',
      version   => '25',
      codename  => 'Gurgle',
      isStable  => 1,
      isCurrent => 0,
      released  => '8 December 2016',
      available => 0,
      isos => {
        cinnamon => {
          url => {
            "torrent" => 'https://dl.kororaproject.org/pub/isos/releases/25/x86_64/korora-live-cinnamon-25-x86_64.iso.torrent',
            "http"  => 'http://sourceforge.net/projects/kororaproject/files/25/korora-live-cinnamon-25-x86_64.iso/download',
          },
          checksum => {
            md5     => '050cac6e9bbde974069f8ec31cea2e86',
            sha1    => '13bd78a1900bd34ca3f4f2f23a334bc60eb0a0a8',
            sha256  => 'a0e17d8c7a54f63950f89f1801e9884b5ef696bb4b8fdbb68f14195b2d778211'
          },
        },
        gnome => {
          url => {
            "torrent" => 'https://dl.kororaproject.org/pub/isos/releases/25/x86_64/korora-live-gnome-25-x86_64.iso.torrent',
            "http"  => 'http://sourceforge.net/projects/kororaproject/files/25/korora-live-gnome-25-x86_64.iso/download',
          },
          checksum => {
            md5     => '2a21e30659101b33eb1f24e34db0e611',
            sha1    => 'b683c642062bb1037a3d854ac6b1f2c49091eb9f',
            sha256  => '1be5d06feb7fedb5a364f7bcd735754f22efe3a56e1ad2310d64e965619c5468'
          },
        },
        kde => {
          url => {
            "torrent" => 'https://dl.kororaproject.org/pub/isos/releases/25/x86_64/korora-live-kde-25-x86_64.iso.torrent',
            "http"  => 'http://sourceforge.net/projects/kororaproject/files/25/korora-live-kde-25-x86_64.iso/download',
          },
          checksum => {
            md5     => 'c2f5dd171b2809262164fcfcfe3d7d72',
            sha1    => 'c8803e613eb380bdf135265a12b5adf6e66f843b',
            sha256  => '1af9b932ec3c03a5d27c9f81babf3f3925390bffbf47525fd9e70e0b5fccf811'
          },
        },
        mate => {
          url => {
            "torrent" => 'https://dl.kororaproject.org/pub/isos/releases/25/x86_64/korora-live-mate-25-x86_64.iso.torrent',
            "http"  => 'http://sourceforge.net/projects/kororaproject/files/25/korora-live-mate-25-x86_64.iso/download',
          },
          checksum => {
            md5     => '8e55704155b4c243e368c914b60e9e30',
            sha1    => 'fba2509a4187e9746f668be48ae1a7e48b90c308',
            sha256  => 'da685120fb378dd4b11200a82fe050bd11fbc470e3ddaf57887e28c0ac049f61'
          },
        },
        xfce => {
          url => {
            "torrent" => 'https://dl.kororaproject.org/pub/isos/releases/25/x86_64/korora-live-xfce-25-x86_64.iso.torrent',
            "http"  => 'http://sourceforge.net/projects/kororaproject/files/25/korora-live-xfce-25-x86_64.iso/download',
          },
          checksum => {
            md5     => '81d32eaf6b932e09f14ff04767f25b4c',
            sha1    => '3c351fdd6ae806a42b8da9ee32e050e7f6977ab4',
            sha256  => '52ff7c88dd8bc5a92b0248b6268ff2c8ce7d5d3b51270005526faa2627e91f15'
          },
        },
      },
    },
  ]
};

#
# CONTROLLER HANDLERS
#
sub index {
  my $c = shift;

  $c->stash(map => DOWNLOAD_MAP, static_map => encode_json(DOWNLOAD_MAP));

  $c->render('download');
}

sub torrent_file {
  my $c = shift;
  my $file = $c->param('file');

  $c->res->headers->content_type('application/x-bittorrent');
  $c->reply->static('torrents/' . $file);
}

1;
