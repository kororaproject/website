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
      name      => 'Korora 21',
      version   => '21',
      codename  => 'Darla',
      isStable  => 1,
      isCurrent => 1,
      released  => '6 February 2015',
      available => 1,
      isos => {
        cinnamon => {
          i386 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/21/korora-21-i386-cinnamon-live.iso/download',
              torrent => '/torrents/korora-21-i386-cinnamon-live-iso.torrent'
            },
            checksum => {
              md5     => 'de6252cd96cacc888b4acbef8c8afec2',
              sha1    => 'ce3f6b9bb84c4573a5b8a2ad9904da2e8ba8f435',
              sha256  => '6fe00371dfc12a7e12283e5f2c49d454947e514a6869676c12fe947279062ccd',
            },
          },
          x86_64 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/21/korora-21-x86_64-cinnamon-live.iso/download',
              torrent => '/torrents/korora-21-x86_64-cinnamon-live-iso.torrent'
            },
            checksum => {
              md5    => 'd600dfbd777d4b39385dab7b1ad95783',
              sha1   => '0a8897c3a74666452733e9b5d550efa18637a8a3',
              sha256 => 'a44e7e2f3ad0fbe67a35aa3d71bf9f2e81eb1ba8a3f11075eba970996c3fe269'
            },
          },
        },
        gnome => {
          i386 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/21/korora-21-i386-gnome-live.iso/download',
              torrent => '/torrents/korora-21-i386-gnome-live-iso.torrent'
            },
            checksum => {
              md5     => '59aa3addf189861b9d0cb1f3e3d1169b',
              sha1    => '5fcecabcb43028a4d2d341730f216d03fcdcb307',
              sha256  => 'fa38a6039ced9995cb8c0ccf6662cf3989d25fc659f2f4779b64298771766782',
            },
          },
          x86_64 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/21/korora-21-x86_64-gnome-live.iso/download',
              torrent => '/torrents/korora-21-x86_64-gnome-live-iso.torrent'
            },
            checksum => {
              md5     => '741fbae6cc9246892a7ca8172b3674f1',
              sha1    => '2c8cdecdd0324f83ce4d5a0c5f16b71d99ff4e08',
              sha256  => 'b5794237aadb9a719b5dd35c4ef3d908d90b20debb8f6b2c94884ada74628bcf'
            },
          },
        },
        kde => {
          i386 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/21/korora-21-i386-kde-live.iso/download',
              torrent => '/torrents/korora-21-i386-kde-live-iso.torrent'
            },
            checksum => {
              md5     => '76c8041a8b447f948c931050e101f0ba',
              sha1    => 'b259d451e120424aa545ab04f3ea73911f2c5e11',
              sha256  => '2a7722dc56d481f8825851fab28014cede6cb250df7a5f7788420011a4c98185',
            },
          },
          x86_64 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/21/korora-21-x86_64-kde-live.iso/download',
              torrent => '/torrents/korora-21-x86_64-kde-live-iso.torrent'
            },
            checksum => {
              md5     => '8a75040a6f426292319aff5375ddbddc',
              sha1    => '9a72b79d00c9c8815203a1665b7af066cafc2b10',
              sha256  => '76578bc4ae127a58f3bab490fde957e6d944661d4f292e75f8b6d274721fd447'
            },
          },
        },
        xfce => {
          i386 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/21/korora-21-i386-xfce-live.iso/download',
              torrent => '/torrents/korora-21-i386-xfce-live-iso.torrent'
            },
            checksum => {
              md5     => '8a355a3c797d767e57720b080f2592f8',
              sha1    => 'b447a279fc67dca235d2e4db326fcfae862320d0',
              sha256  => 'c62212897f7f0aa6027d56ffdb34d4b4ca6f62b3d4cb85c308755ff11bc0875c'
            },
          },
          x86_64 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/21/korora-21-x86_64-xfce-live.iso/download',
              torrent => '/torrents/korora-21-x86_64-xfce-live-iso.torrent'
            },
            checksum => {
              md5     => '08f8e173e89735bba69fde8f81b7ebb6',
              sha1    => 'a7a803e7ad155876ad5a0ea5b8bd776c9a66b22b',
              sha256  => '492ad02a512f995d0f1cb43e30eca78bc79642ff56e25960c1c6c9f4395552e7',
            },
          },
        },
      },
    },
    {
      name      => 'Korora 20',
      version   => '20',
      codename  => 'Peach',
      isStable  => 1,
      isCurrent => 0,
      released  => '10 January 2014',
      available => 1,
      isos => {
        cinnamon => {
          i386 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-i386-cinnamon-live.iso/download',
              torrent => 'http://burnbit.com/download/271362/korora_20_i386_cinnamon_live_iso',
            },
            checksum => {
              md5     => '629ebb67dba64f0a17bb6e8fe2721ef9',
              sha1    => '7842a2b06ad3223bed67eea632f537fff0ea0819',
              sha256  => 'fe8d8013a09754e18fb523e56068e199c7e58aaea8e3ad29ad72d003d8207149',
            },
          },
          x86_64 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-x86_64-cinnamon-live.iso/download',
              torrent => 'http://burnbit.com/download/271361/korora_20_x86_64_cinnamon_live_iso',
            },
            checksum => {
              md5    => 'e5d5593751f2e323759499b62b8e1680',
              sha1   => '5270a13b19fbd24c9db89e3df921d1aeda476374',
              sha256 => '487a450d1d19df16de4c21d421c50dfdb4483092ee5a27ca7d4945238b34fd63'
            },
          },
        },
        gnome => {
          i386 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-i386-gnome-live.iso/download',
              torrent => 'http://burnbit.com/download/271366/korora_20_i386_gnome_live_iso',
            },
            checksum => {
              md5     => '7ce7a1307597eb2e102b287a7f5b2c95',
              sha1    => 'fcc10b785ffce8a9d7f7cd3fca38e8cde62ae2a8',
              sha256  => '7982750d08b2597a76880ac4e6b09c61cf710c5251a9738e15b7d06e4ade39c0',
            },
          },
          x86_64 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-x86_64-gnome-live.iso/download',
              torrent => 'http://burnbit.com/download/271380/korora_20_x86_64_gnome_live_iso',
            },
            checksum => {
              md5     => '17ecf28bad63b02d088877c33f1f2fb2',
              sha1    => '78117aa2d7ade29321ec74be37246bb670def82e',
              sha256  => '7c751d6b5207ccdfefb28e477d7a5d7e8a3df77823cbbed9b1484866f8668dac'
            },
          },
        },
        kde => {
          i386 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-i386-kde-live.iso/download',
              torrent => 'http://burnbit.com/download/271365/korora_20_i386_kde_live_iso',
            },
            checksum => {
              md5     => 'b9fa2dfcdc906af12212a923dd8110c2',
              sha1    => 'a5c757c2796bc4f9d1a3d6b515400c73981354f8',
              sha256  => '894943bff0c7fc456c5e2a93636f747e0cffaf1bcbf630bf1eee3588c9e454e0',
            },
          },
          x86_64 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-x86_64-kde-live.iso/download',
              torrent => 'http://burnbit.com/download/271148/korora_20_x86_64_kde_live_iso',
            },
            checksum => {
              md5     => 'a9eb84fdf71a2e1590f4d4bee7534336',
              sha1    => 'ec724f5f4f0e9c77e9c95fc2311a8190dc3ec461',
              sha256  => '0877cf6913c35da37656c0a316fafe5d27c7b151182deb031f0bc002d040d08c'
            },
          },
        },
        mate => {
          i386 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-i386-mate-live.iso/download',
              torrent => 'http://burnbit.com/download/271363/korora_20_i386_mate_live_iso',
            },
            checksum => {
              md5     => '78f0f56f113fadaaa0edf75deb53c3a3',
              sha1    => '3e388144c29fa4cd9b6dd0da045e71eeaff20e08',
              sha256  => 'e874dc7baa22d201b65124586398e49ba73879a4c3146e5d70bb733f991f0e35',
            },
          },
          x86_64 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-x86_64-mate-live.iso/download',
              torrent => 'http://burnbit.com/download/271376/korora_20_x86_64_mate_live_iso',
            },
            checksum => {
              md5     => '00c5e82f42f6b598be1b493d5ad9c3ae',
              sha1    => '58fd2c99f3e16d3b6027dacad4d8a6aa7b21425f',
              sha256  => '1d2384c765744a9513bde216c3f7a47b674faa8988ac86610a118529004aec36',
            },
          },
        },
        xfce => {
          i386 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-i386-xfce-live.iso/download',
              torrent => 'http://burnbit.com/download/270736/korora_20_i386_xfce_live_iso',
            },
            checksum => {
              md5     => '8edffc090daabd20d7c4961cc003b4b2',
              sha1    => 'fd53f50932c87721effb2fef5839192003652c5c',
              sha256  => '5071423a24d689327eec2866ef6f90488a655a1fd399ab1df256260c98d0368c'
            },
          },
          x86_64 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-x86_64-xfce-live.iso/download',
              torrent => 'http://burnbit.com/download/270883/korora_20_x86_64_xfce_live_iso',
            },
            checksum => {
              md5     => 'e1adedb1a623716b653a2b270116c585',
              sha1    => '2dbbe24f70e5f939f96fa33a99bfd732de265c5a',
              sha256  => 'b7e051652b693d053e644d7ce572b37700e7f1298d8ec50cfdd6f8386b189177',
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
  my $self = shift;

  $self->stash(map => DOWNLOAD_MAP, static_map => encode_json(DOWNLOAD_MAP));

  $self->render('website/download');
}

1;
