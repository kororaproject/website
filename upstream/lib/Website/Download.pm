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
      name      => 'Korora 21 - Beta',
      version   => '21',
      codename  => 'Darla',
      isStable  => 0,
      isCurrent => 0,
      released  => '3 January 2015',
      available => 1,
      isos => {
        cinnamon => {
          i386 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/21/korora-21-beta-i386-cinnamon-live.iso/download',
            },
            checksum => {
              md5     => 'f625a9ba53371124ddadade8785ca687',
              sha1    => '41d7e72a9f73c5e76559cea2f3b4dc1d9c1172bf',
              sha256  => '09404a4118f11435f13af4335f4c6a134df23d46bb70b8a5583b19a6d4262509',
            },
          },
          x86_64 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/21/korora-21-beta-x86_64-cinnamon-live.iso/download',
            },
            checksum => {
              md5    => 'cf6c2dc4b71e401c2ad8279b4db14ae4',
              sha1   => '8a54e52d7df64818731f27aa7b415deeba8a409e',
              sha256 => '046d0b8f69343d5fe5682710a1ea9293f6bb56188f71afd0362d93cffa0f9dc9'
            },
          },
        },
        gnome => {
          i386 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/21/korora-21-beta-i386-gnome-live.iso/download',
            },
            checksum => {
              md5     => '72ce907bb59b48a74eff382fe1ab121d',
              sha1    => 'b4ddc9774e6a544d765a768de9abff14cd0d457b',
              sha256  => '17fcb0b39a26e9f3116e9aec987abd24808c049e25601e9fa64527d5fc0b6296',
            },
          },
          x86_64 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/21/korora-21-beta-x86_64-gnome-live.iso/download',
            },
            checksum => {
              md5     => 'ac6cff1811b2e94e7b11e98cfb40b87e',
              sha1    => 'aa20fd6bc30a8256c9f96e4f1edbbf7c17b93c36',
              sha256  => '4d44072ffe9cadc9e3c0fcfcbc1d9c6abdaae081ea20aad858de91330f1b1400'
            },
          },
        },
        kde => {
          i386 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/21/korora-21-beta-i386-kde-live.iso/download',
            },
            checksum => {
              md5     => 'c742544afa6153fff55461c2f18c2f18',
              sha1    => 'efe003d3263cf3a8160d78577c0b4bd8600ea63f',
              sha256  => '380a82e004bf30d981927d892c2a388062cd17fa53a80135783b3986e8223cab',
            },
          },
          x86_64 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/21/korora-21-beta-x86_64-kde-live.iso/download',
            },
            checksum => {
              md5     => '1678d80713f4ec166cab78b3a2e3abcc',
              sha1    => 'd36660d6e1f1398dc56d77ef886dfb26215158d7',
              sha256  => 'de7a311bf87262b56a6afccc8573531d9f953c5bddf09b7b95be66619f785e39'
            },
          },
        },
        xfce => {
          i386 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/21/korora-21-beta-i386-xfce-live.iso/download',
            },
            checksum => {
              md5     => '2ebcd2cd67d25cbf14a2872e48dee425',
              sha1    => '6297e4b41cee070b3c0781cc8e60eab03c8c0ef6',
              sha256  => '3eb3ffc8d8c1ac7b113cf545b01ebb02db3ae655cd6ddac5c02b19e1b8dd1ebe'
            },
          },
          x86_64 => {
            url => {
              http    => 'http://sourceforge.net/projects/kororaproject/files/21/korora-21-beta-x86_64-xfce-live.iso/download',
            },
            checksum => {
              md5     => '6df9fac7c3ac338631700c3387e059c9',
              sha1    => '9cc534b46499d8c1ba0498d88ebc3f44d540a56d',
              sha256  => 'cecf291356f9cab4a930de8b42492dab5ff283e9f7a2fd27f874db8b8861e536',
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
      isCurrent => 1,
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
