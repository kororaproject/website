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
      name      => 'Korora 23',
      version   => '23',
      codename  => 'Coral',
      isStable  => 1,
      isCurrent => 1,
      released  => '7 February 2016',
      available => 1,
      isos => {
        cinnamon => {
          i386 => {
            url => {
              "http"  => 'http://sourceforge.net/projects/kororaproject/files/23/korora-23-i386-cinnamon.iso/download',
#              "http (Asia)"  => 'http://dl.kororaproject.org/pub/isos/testing/23/i386/korora-23-beta-i386-cinnamon-live.iso',
#              "http (Europe)"  => 'http://beta.kororaproject.org/pub/isos/testing/23/i386/korora-23-beta-i386-cinnamon-live.iso',
#              "http (America)"  => 'http://gamma.kororaproject.org/pub/isos/testing/23/i386/korora-23-beta-i386-cinnamon-live.iso',
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
#              "http (Asia)"  => 'http://dl.kororaproject.org/pub/isos/testing/23/x86_64/korora-23-beta-x86_64-cinnamon-live.iso',
#              "http (Europe)"  => 'http://beta.kororaproject.org/pub/isos/testing/23/x86_64/korora-23-beta-x86_64-cinnamon-live.iso',
#              "http (America)"  => 'http://gamma.kororaproject.org/pub/isos/testing/23/x86_64/korora-23-beta-x86_64-cinnamon-live.iso',
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
#              "http (Asia)"  => 'http://dl.kororaproject.org/pub/isos/testing/23/i386/korora-23-beta-i386-gnome-live.iso',
#              "http (Europe)"  => 'http://beta.kororaproject.org/pub/isos/testing/23/i386/korora-23-beta-i386-gnome-live.iso',
#              "http (America)"  => 'http://gamma.kororaproject.org/pub/isos/testing/23/i386/korora-23-beta-i386-gnome-live.iso',
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
#              "http (Asia)"  => 'http://dl.kororaproject.org/pub/isos/testing/23/x86_64/korora-23-beta-x86_64-gnome-live.iso',
#              "http (Europe)"  => 'http://beta.kororaproject.org/pub/isos/testing/23/x86_64/korora-23-beta-x86_64-gnome-live.iso',
#              "http (America)"  => 'http://gamma.kororaproject.org/pub/isos/testing/23/x86_64/korora-23-beta-x86_64-gnome-live.iso',
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
#              "http (Asia)"  => 'http://dl.kororaproject.org/pub/isos/testing/23/i386/korora-23-beta-i386-kde-live.iso',
#              "http (Europe)"  => 'http://beta.kororaproject.org/pub/isos/testing/23/i386/korora-23-beta-i386-kde-live.iso',
#              "http (America)"  => 'http://gamma.kororaproject.org/pub/isos/testing/23/i386/korora-23-beta-i386-kde-live.iso',
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
#              "http (Asia)"  => 'http://dl.kororaproject.org/pub/isos/testing/23/x86_64/korora-23-beta-x86_64-kde-live.iso',
#              "http (Europe)"  => 'http://beta.kororaproject.org/pub/isos/testing/23/x86_64/korora-23-beta-x86_64-kde-live.iso',
#              "http (America)"  => 'http://gamma.kororaproject.org/pub/isos/testing/23/x86_64/korora-23-beta-x86_64-kde-live.iso',
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
#              "http (Asia)"  => 'http://dl.kororaproject.org/pub/isos/testing/23/i386/korora-23-beta-i386-mate-live.iso',
#              "http (Europe)"  => 'http://beta.kororaproject.org/pub/isos/testing/23/i386/korora-23-beta-i386-mate-live.iso',
#              "http (America)"  => 'http://gamma.kororaproject.org/pub/isos/testing/23/i386/korora-23-beta-i386-mate-live.iso',
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
#              "http (Asia)"  => 'http://dl.kororaproject.org/pub/isos/testing/23/x86_64/korora-23-beta-x86_64-mate-live.iso',
#              "http (Europe)"  => 'http://beta.kororaproject.org/pub/isos/testing/23/x86_64/korora-23-beta-x86_64-mate-live.iso',
#              "http (America)"  => 'http://gamma.kororaproject.org/pub/isos/testing/23/x86_64/korora-23-beta-x86_64-mate-live.iso',
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
#              "http (Asia)"  => 'http://dl.kororaproject.org/pub/isos/testing/23/i386/korora-23-beta-i386-xfce-live.iso',
#              "http (Europe)"  => 'http://beta.kororaproject.org/pub/isos/testing/23/i386/korora-23-beta-i386-xfce-live.iso',
#              "http (America)"  => 'http://gamma.kororaproject.org/pub/isos/testing/23/i386/korora-23-beta-i386-xfce-live.iso',
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
#              "http (Asia)"  => 'http://dl.kororaproject.org/pub/isos/testing/23/x86_64/korora-23-beta-x86_64-xfce-live.iso',
#              "http (Europe)"  => 'http://beta.kororaproject.org/pub/isos/testing/23/x86_64/korora-23-beta-x86_64-xfce-live.iso',
#              "http (America)"  => 'http://gamma.kororaproject.org/pub/isos/testing/23/x86_64/korora-23-beta-x86_64-xfce-live.iso',
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
    {
      name      => 'Korora 22',
      version   => '22',
      codename  => 'Selina',
      isStable  => 1,
      isCurrent => 0,
      released  => '2 August 2015',
      available => 1,
      isos => {
        cinnamon => {
          i386 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/22/korora-22-i386-cinnamon-live.iso/download',
              torrent => '/download/torrents/korora-22-i386-cinnamon-live-iso.torrent'
            },
            checksum => {
              md5     => '488cc2b1a01f6553b392425440cc6644',
              sha1    => '7a2be34ae8d47069ff4735331d8c2adc62a5bb6b',
              sha256  => 'd6145ae6130e0fd7b3320555c543c56954f857c469979a5b14321bf20196b685',
            },
          },
          x86_64 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/22/korora-22-x86_64-cinnamon-live.iso/download',
              torrent => '/download/torrents/korora-22-x86_64-cinnamon-live-iso.torrent'
            },
            checksum => {
              md5     => 'ef71549bb6e88ea51cfa8f9424ad329f',
              sha1    => 'bc5ac60cfb1d769673c9622b226cd9f6b6ed636f',
              sha256  => '2a06f6486172ab060ea44479ab7852ca80329f1cca62144af9a37c8caa686b13'
            },
          },
        },
        gnome => {
          i386 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/22/korora-22-i386-gnome-live.iso/download',
              torrent => '/download/torrents/korora-22-i386-gnome-live-iso.torrent'
            },
            checksum => {
              md5     => '3bbbbf2c60d22477613b51c3199570ce',
              sha1    => 'd0d3588aeee249f151c94c927b5ba29946c85bfd',
              sha256  => '7bf89d4c41d0052d5e29c05cde834d9ba9ee0db2ca3636e2dda5288dd5ce583b',
            },
          },
          x86_64 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/22/korora-22-x86_64-gnome-live.iso/download',
              torrent => '/download/torrents/korora-22-x86_64-gnome-live-iso.torrent'
            },
            checksum => {
              md5     => 'fd51893712a42e1282a6644a8cf978a6',
              sha1    => 'e3425458c02790d4cc564277a9a34d5b1427d249',
              sha256  => '9ecef349b473257a13de2392a4a7edca11f88f7fa0dc6e9e900f5f1ec1258881'
            },
          },
        },
        kde => {
          i386 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/22/korora-22-i386-kde-live.iso/download',
              torrent => '/download/torrents/korora-22-i386-kde-live-iso.torrent'
            },
            checksum => {
              md5     => 'afcb7743ed0bc05d2b0ee530ac49992b',
              sha1    => '1eeba35c2636cdeb17d6c2bbcadc63318bcc66d5',
              sha256  => 'b4f69e9762c3dc4b14f4d65d13e5bb8b2e827340d51c1b6c02a51e0d816e7706',
            },
          },
          x86_64 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/22/korora-22-x86_64-kde-live.iso/download',
              torrent => '/download/torrents/korora-22-x86_64-kde-live-iso.torrent'
            },
            checksum => {
              md5     => '072ee9344d6935a0a00308d1e2901877',
              sha1    => 'c78184f0893aca8c64df29a3a9152735c5d745c2',
              sha256  => '124c60047d1c085a694f8c91afc595cc6b41496a649d9bc5f668c69684806fe7'
            },
          },
        },
        mate => {
          i386 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/22/korora-22-i386-mate-live.iso/download',
              torrent => '/download/torrents/korora-22-i386-mate-live-iso.torrent'
            },
            checksum => {
              md5     => 'fc9cecc80517f8d100ea03ddce0fe706',
              sha1    => '96e45533a2601bded6b5e8226ae410e90323920d',
              sha256  => '7db79f6f0daf6e5a58067390f2cebdc135299892107d1d367df58c9d4ead9930',
            },
          },
          x86_64 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/22/korora-22-x86_64-mate-live.iso/download',
              torrent => '/download/torrents/korora-22-x86_64-mate-live-iso.torrent'
            },
            checksum => {
              md5     => '1d753a4c8d8c7779edc0476e71e6a6bc',
              sha1    => '086be38a1c03590a1ab3fbe0f7ecaae5b2eeef98',
              sha256  => '43827ea0a85cc9c55ebb872287d2299edc52ae342a96116f1d88e2b6e095234e'
            },
          },
        },
        xfce => {
          i386 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/22/korora-22-i386-xfce-live.iso/download',
              torrent => '/download/torrents/korora-22-i386-xfce-live-iso.torrent'
            },
            checksum => {
              md5     => '2acc91bed582e638180ffe1a91b8cc01',
              sha1    => '121602fc333834aac8659ca20763a37209997e6d',
              sha256  => '4af9980097539be0c1c757681f39086879678f02130e63c0b200f173b577e109'
            },
          },
          x86_64 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/22/korora-22-x86_64-xfce-live.iso/download',
              torrent => '/download/torrents/korora-22-x86_64-xfce-live-iso.torrent'
            },
            checksum => {
              md5     => 'd32bd52cde884112b5f13a045d751f2d',
              sha1    => '7b48b362c929ca086d1540f0d8dcd427370a8290',
              sha256  => 'b1a8ecac5bb13192bb26ece85d0059427d410a1536fd6b77e92fc139f8b3a643',
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
