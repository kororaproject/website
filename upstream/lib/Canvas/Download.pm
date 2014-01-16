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
package Canvas::Download;

use warnings;
use strict;

use Mojo::Base 'Mojolicious::Controller';

#
# PERL INCLUDES
#
use Data::Dumper;
use Mojo::JSON qw(j);

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
    {
      name      => 'Korora 19.1',
      version   => '19.1',
      codename  => 'Bruce',
      isStable  => 1,
      isCurrent => 0,
      released  => '07 October 2013',
      available => 1,
      isos => {
        cinnamon => {
          i386 => {
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
          x86_64 => {
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
        },
        gnome => {
          i386 => {
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
          x86_64 => {
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
        },
        kde => {
          i386 => {
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
          x86_64 => {
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
        },
        mate  => {
          i386 => {
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
          x86_64 => {
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
  ]
};

#
# CONTROLLER HANDLERS
#
sub index {
  my $self = shift;

  $self->stash( map => DOWNLOAD_MAP, static_map => j(DOWNLOAD_MAP) );

  $self->render('download');
}

1;
