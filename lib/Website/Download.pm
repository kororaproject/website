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
      name      => 'Korora 25',
      version   => '25',
      codename  => 'Gurgle',
      isStable  => 1,
      isCurrent => 1,
      released  => '8 December 2016',
      available => 1,
      isos => {
        cinnamon => {
          url => {
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
    {
      name      => 'Korora 24',
      version   => '24',
      codename  => 'Sheldon',
      isStable  => 1,
      isCurrent => 0,
      released  => '19 July 2016',
      available => 1,
      isos => {
        cinnamon => {
          url => {
            "http"  => 'http://sourceforge.net/projects/kororaproject/files/24/korora-24-x86_64-cinnamon.iso/download',
          },
          checksum => {
            md5     => '603bf01359698f2794bd6902a1702433',
            sha1    => '57bf00a34df14aa0f29375fc4d111031849486a4',
            sha256  => '8d0e7ebe8b87034a6f9c80b6802a56546a144bdc6f0cf39f94a86122097e974d',
          },
        },
        gnome => {
          url => {
            "http"  => 'http://sourceforge.net/projects/kororaproject/files/24/korora-24-x86_64-gnome.iso/download',
          },
          checksum => {
            md5     => 'a18d369abf4ae27a067b6a738df7598e',
            sha1    => 'ee57d511e7c1d9d13d40d84439d506a477a512f4',
            sha256  => '7aeaf72ce19e2392db85333a2661b5a87516e279184df3552b250eaa34be2acf'
          },
        },
        mate => {
          url => {
            "http"  => 'http://sourceforge.net/projects/kororaproject/files/24/korora-24-x86_64-mate.iso/download',
          },
          checksum => {
            md5     => '087a8759689a51a355cc072ea37fe4a3',
            sha1    => '48133afbcc841e64c32eaa4accf051d06a487a02',
            sha256  => '15f2ae176e50b9ff06df1df2c6d6f0ab205bab980b1dd86312faa4b0e04b45d9',
          },
        },
        xfce => {
          url => {
            "http"  => 'http://sourceforge.net/projects/kororaproject/files/24/korora-24-x86_64-xfce.iso/download',
          },
          checksum => {
            md5     => '18e5cf7d7c076b03436de460e8a1f3ee',
            sha1    => 'd36540be6767175552a84e6f9111fba35aa5ed46',
            sha256  => '2e60ff382f31d76462b3bb0c88f967fb7e12eda2c52d3a58e8835d52135b7202',
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
