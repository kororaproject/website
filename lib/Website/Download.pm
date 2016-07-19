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
  archs => {
    i386    => '32 bit',
    x86_64  => '64 bit',
  },
  desktops => {
    cinnamon  => 'Cinnamon',
    gnome     => 'GNOME',
    kde       => 'KDE',
    mate      => 'MATE',
    xfce      => 'Xfce',
  },
  releases => [
    {
      name      => 'Korora 24',
      version   => '24',
      codename  => 'Sheldon',
      isStable  => 1,
      isCurrent => 1,
      released  => '19 July 2016',
      available => 1,
      isos => {
        cinnamon => {
          x86_64 => {
            url => {
              "http"  => 'http://sourceforge.net/projects/kororaproject/files/24/korora-24-x86_64-cinnamon.iso/download',
            },
            checksum => {
              md5     => '603bf01359698f2794bd6902a1702433',
              sha1    => '57bf00a34df14aa0f29375fc4d111031849486a4',
              sha256  => '8d0e7ebe8b87034a6f9c80b6802a56546a144bdc6f0cf39f94a86122097e974d',
            },
          },
        },
        gnome => {
          x86_64 => {
            url => {
              "http"  => 'http://sourceforge.net/projects/kororaproject/files/24/korora-24-x86_64-gnome.iso/download',
            },
            checksum => {
              md5     => 'a18d369abf4ae27a067b6a738df7598e',
              sha1    => 'ee57d511e7c1d9d13d40d84439d506a477a512f4',
              sha256  => '7aeaf72ce19e2392db85333a2661b5a87516e279184df3552b250eaa34be2acf'
            },
          },
        },
        mate => {
          x86_64 => {
            url => {
              "http"  => 'http://sourceforge.net/projects/kororaproject/files/24/korora-24-x86_64-mate.iso/download',
            },
            checksum => {
              md5     => '087a8759689a51a355cc072ea37fe4a3',
              sha1    => '48133afbcc841e64c32eaa4accf051d06a487a02',
              sha256  => '15f2ae176e50b9ff06df1df2c6d6f0ab205bab980b1dd86312faa4b0e04b45d9',
            },
          },
        },
        xfce => {
          x86_64 => {
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
    },
    {
      name      => 'Korora 23',
      version   => '23',
      codename  => 'Coral',
      isStable  => 1,
      isCurrent => 0,
      released  => '7 February 2016',
      available => 1,
      isos => {
        cinnamon => {
          i386 => {
            url => {
              "http"  => 'http://sourceforge.net/projects/kororaproject/files/23/korora-23-i386-cinnamon.iso/download',
            },
            checksum => {
              md5     => '63df726f01d7789504a31d0a03916cfe',
              sha1    => '16a9acdcf71aaccda5a5665d9e9cede7ebcc140d',
              sha256  => '85f0650f6c91a52e889dc80f2fee6a219b3e985f1d81e87fea97386c6ebfb373',
            },
          },
          x86_64 => {
            url => {
              "http"  => 'http://sourceforge.net/projects/kororaproject/files/23/korora-23-x86_64-cinnamon.iso/download',
            },
            checksum => {
              md5     => '954e682b15ba0c0839498cb185d4acff',
              sha1    => 'b1e7bfb0c4c4867fa805bae26f072bdd83acea31',
              sha256  => 'f7740fd2f054d7557c2832c02f4777eaca586f6ffbe60757557b74dc27e50d6c',
            },
          },
        },
        gnome => {
          i386 => {
            url => {
              "http"  => 'http://sourceforge.net/projects/kororaproject/files/23/korora-23-i386-gnome.iso/download',
            },
            checksum => {
              md5     => 'b41a6bf4b3cbdb703a346f816f4ad18b',
              sha1    => 'e3430c65182dd18e8166696684cade6b93d1a78e',
              sha256  => '6e7ac920ac0e9d9121661b779b39b763d1329c8eec353cd0f051d1451b7706b3',
            },
          },
          x86_64 => {
            url => {
              "http"  => 'http://sourceforge.net/projects/kororaproject/files/23/korora-23-x86_64-gnome.iso/download',
            },
            checksum => {
              md5     => '5cc9db18cc88990286bf2a4322cfa847',
              sha1    => '6c4fe80df9e869167d9bf68a173fbbc481e637b2',
              sha256  => 'cd7b4f612d60da1dc600c77a9b521dd9051e7b265ceddf07e22d725b694be9b0'
            },
          },
        },
        kde => {
          i386 => {
            url => {
              "http"  => 'http://sourceforge.net/projects/kororaproject/files/23/korora-23-i386-kde.iso/download',
            },
            checksum => {
              md5     => 'dec715f1167671716d56e564523a116e',
              sha1    => 'b9d50dca536fdc581ac9070a899e189e2a01bb0b',
              sha256  => 'bc71cd0f10019f3d61fefdc36ad6bfbabd4746d145776de366bd57dba601a71a',
            },
          },
          x86_64 => {
            url => {
              "http"  => 'http://sourceforge.net/projects/kororaproject/files/23/korora-23-x86_64-kde.iso/download',
            },
            checksum => {
              md5     => '9bbca3b6badca68a73662b08377c6416',
              sha1    => '43b6a6c8076bca3d55af67b23eae59ad8152abd0',
              sha256  => 'c19bbe290d096171d67e3bb9b73bd0b29a8aa7c6d8a0429edebb4481adfa702a'
            },
          },
        },
        mate => {
          i386 => {
            url => {
              "http"  => 'http://sourceforge.net/projects/kororaproject/files/23/korora-23-i386-mate.iso/download',
            },
            checksum => {
              md5     => '31400451da35f5b5b9d70371df05deea',
              sha1    => '4ca35cedaba7a18ac92c97fc55cc8b56b5db817e',
              sha256  => '471001cf59b09456240e0462fdfab1e3bc3ba9986077de565ebabfe99d6325e5',
            },
          },
          x86_64 => {
            url => {
              "http"  => 'http://sourceforge.net/projects/kororaproject/files/23/korora-23-x86_64-mate.iso/download',
            },
            checksum => {
              md5     => 'abc8d24d47c07fabcc6c40258d8d538c',
              sha1    => '83a5949ccef5ea1efea464064f33d358cbf674fe',
              sha256  => '98bb94f287a5770127c7aa23f5ece0c35ff68531cb1cc36732a808882f0f0c28',
            },
          },
        },
        xfce => {
          i386 => {
            url => {
              "http"  => 'http://sourceforge.net/projects/kororaproject/files/23/korora-23-i386-xfce.iso/download',
            },
            checksum => {
              md5     => '5ef9ad7ddc9f79eacd0b78b9595c8bc4',
              sha1    => '7fca915356b7b50b6a09d8f8178abfc8189cd74e',
              sha256  => 'ff8b10c04ae4fb2179847e8b41ce938afc984d522ee4d14043f22dd00f6b0bb2'
            },
          },
          x86_64 => {
            url => {
              "http"  => 'http://sourceforge.net/projects/kororaproject/files/23/korora-23-x86_64-xfce.iso/download',
            },
            checksum => {
              md5     => '1c2f57f545de31d8ab72c7050a230853',
              sha1    => 'df4abd79c2a3a6f01583d24d57f1c5b418e023a2',
              sha256  => 'c0900e1f2467d06d1651369d96cd43a9ce51a1307015aa798792d38c16a193f1',
            },
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
