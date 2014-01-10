// prototypes
Array.prototype.indexOfObject = function(prop, val) {
  for(var i = 0, l = this.length; i < l; i++) {
    if( this[i].hasOwnProperty(prop) &&
        this[i][prop] === val ) {
      return i;
    }
  }

  return -1;
}


/*
** DIRECTIVES
*/
'use strict';
angular.module('$strap.config', []).value('$strapConfig', {});
angular.module('$strap.filters', ['$strap.config']);
angular.module('$strap.directives', ['$strap.config']);
angular.module('$strap', [
  '$strap.filters',
  '$strap.directives',
  '$strap.config'
]);
angular.module('$strap.directives').directive('bsTooltip', [
  '$parse',
  '$compile',
  function ($parse, $compile) {
    return {
      restrict: 'A',
      scope: true,
      link: function postLink(scope, element, attrs, ctrl) {
        var getter = $parse(attrs.bsTooltip), setter = getter.assign, value = getter(scope);
        scope.$watch(attrs.bsTooltip, function (newValue, oldValue) {
          if (newValue !== oldValue) {
            value = newValue;
          }
        });
        if (!!attrs.unique) {
          element.on('show', function (ev) {
            $('.tooltip.in').each(function () {
              var $this = $(this), tooltip = $this.data('tooltip');
              if (tooltip && !tooltip.$element.is(element)) {
                $this.tooltip('hide');
              }
            });
          });
        }
        element.tooltip({
          title: function () {
            return angular.isFunction(value) ? value.apply(null, arguments) : value;
          },
          html: true
        });
        /*
        var tooltip = element.data('tooltip');
        tooltip.show = function () {
          var r = $.fn.tooltip.Constructor.prototype.show.apply(this, arguments);
          this.tip().data('tooltip', this);
          return r;
        };
        */
        scope._tooltip = function (event) {
          element.tooltip(event);
        };
        scope.hide = function () {
          element.tooltip('hide');
        };
        scope.show = function () {
          element.tooltip('show');
        };
        scope.dismiss = scope.hide;
      }
    };
  }
]);


var canvas = angular.module('canvas', ['$strap.directives']);



/*
** SERVICES
*/

canvas.service('Database', function($resource) {
  return {
    packages: $resource('/api/packages')
  };
});

/*
** CONTROLLERS
*/

function NavigationController($scope, CanvasNavigation) {

  $scope.sliderPaused = false;

  // configure korobar
  var korobar = $('#korobar');
  var fixed = true;

  var footer  = $('footer');

  $scope.$on('routeLoaded', function (event, args) {
    $scope.mode = args.mode;
    $scope.slug = args.slug;

    // TODO: correct korobar start position
    // HOME PAGE correction
    var start = 0;
    var ls = $('#layerslider');
    var ls_data = ls.layerSlider('data');

    if( args.slug == 'home' ) {
      start = 256;
      ls.layerSlider('start');
    }
    else {
      ls.layerSlider('stop');
    }

    if( start - $(window).scrollTop() <= 0 ) {
      korobar.css('top', 0);
      korobar.css('position', 'fixed');
      fixed = true;
    }
    else {
      korobar.css('position', 'absolute');
      korobar.css('top', start + 'px');
      fixed = false;
    }

    // pin korobar to top when it passes
    $(window).off('scroll');
    $(window).on('scroll', function () {
      if( !fixed && (korobar.offset().top - $(window).scrollTop() <= 0) ) {
        korobar.css('top', 0);
        korobar.css('position', 'fixed');
        fixed = true;
      }
      else if( fixed && $(window).scrollTop() <= start ) {
        korobar.css('position', 'absolute');
        korobar.css('top', start + 'px');
        fixed = false;
      }
    });

    // frob page-container minimum height to at least the footer top
    $('.page-container').css('min-height', ($(window).height()-footer.outerHeight()) + 'px');
  });

  $scope.pageActive = function(page) {
    return $scope.slug === page ? 'active' : '';
  };

  $scope.modeActive = function() {
    return $scope.mode;
  };

  $scope.isMode = function(mode) {
    return mode === $scope.mode;
  };
};

function ActivateController($scope, $http) {
  $scope.token = '';

  $scope.error = {
    token: 'Token is invalid.'
  };

  $scope.tokenIsValid = function() {
    return $scope.token.length == 32;
  };

  $scope.tokenIsState = function(state) {
    return $scope.token.length > 0 && ( state === $scope.tokenIsValid() );
  };


  $scope.canActivate = function() {
    return $scope.tokenIsValid();
  };
};

function PasswordResetController($scope, $http) {
  $scope.password = '';
  $scope.verify = '';

  $scope.error = {
    password: 'Password must be at least 8 characters.',
    verify: 'Passwords must match.'
  };

  $scope.passwordIsValid = function() {
    return $scope.password.length >= 8;
  };

  $scope.verifyIsValid = function() {
    return $scope.verify === $scope.password;
  };

  $scope.passwordIsState = function(state) {
    return $scope.password.length > 0 && ( state === $scope.passwordIsValid() );
  };

  $scope.verifyIsState = function(state) {
    return $scope.verify.length > 0 && ( state === $scope.verifyIsValid() );
  };

  $scope.canResetPassword = function() {
    return $scope.passwordIsValid() &&
           $scope.verifyIsValid();
  };
};

function RegisterController($scope, $http) {
  $scope.username = '';
  $scope.email = '';
  $scope.password = '';
  $scope.verify = '';

  $scope.error = {
    username: 'Username is already taken.',
    email: 'Email is invalid.',
    password: 'Password must be at least 8 characters.',
    verify: 'Passwords must match.'
  };

  $scope.usernames = {};
  $scope.emails    = {};
  $scope._lookup_details = false;

  $scope.lookupDetails = function() {
    /* check for cached results */
    if( $scope.usernames.hasOwnProperty( $scope.username ) &&
        $scope.emails.hasOwnProperty( $scope.email ) ) {
      return;
    }

    /* check profile status */
    $scope._lookup_details = true;

    $http({
      method: 'POST',
      url: '/profile/status',
      params: {
        name:   $scope.username,
        email:  $scope.email,
      }
    })
      .success( function(data, status, headers, config) {
        if( data.hasOwnProperty('username') ) {
          $scope.usernames[ data.username.key ] = ( data.username.status === 1 ) ? false : true;
        }
        if( data.hasOwnProperty('email') ) {
          $scope.emails[ data.email.key ] = ( data.email.status === 1 ) ? false : true;
        }
        $scope._lookup_details = false;
      })
      .error( function(data, status, headers, config) {
        $scope._lookup_details = false;
      });
  };

  $scope.usernameIsValid = function() {
    if( $scope.username.length > 0 ) {
      var re = /^[A-Za-z0-9_]+$/;
      if( re.test($scope.username) ) {
        if( $scope.usernames.hasOwnProperty( $scope.username ) ) {

          if( $scope.usernames[ $scope.username ] ) {
            $scope.error.username = '';
            return true;
          }
          else {
            $scope.error.username = 'Username is already taken.';
          }
        }
        else {
          $scope.error.username = 'Username can\'t be checked.';
        }
      }
      else {
        $scope.error.username = 'Usernames can only cotain alphanumeric characters and underscores only.';
      }
    }

    return false;
  };

  $scope.emailIsValid = function() {
    if( $scope.email.length > 0 ) {
      if( $scope.emails.hasOwnProperty( $scope.email ) ) {
        if( $scope.emails[ $scope.email ] ) {
          var re = /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\ ".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA -Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;

          $scope.error.email = '';
          if( re.test($scope.email) ) {
            return true;
          }

          $scope.error.email = 'Please enter a valid email address.';
        }
        else {
          $scope.error.email = 'Email address is already taken.';
        }
      }
      else {
        $scope.error.email = 'Email address can\'t be checked.';
      }
    }

    return false;
  };

  $scope.passwordIsValid = function() {
    return $scope.password.length >= 8;
  };

  $scope.verifyIsValid = function() {
    return $scope.verify === $scope.password;
  };

  $scope.usernameIsState = function(state) {
    return $scope.usernames.hasOwnProperty( $scope.username ) &&
           ( state === $scope.usernameIsValid() );
  };

  $scope.emailIsState = function(state) {
    return $scope.emails.hasOwnProperty( $scope.email ) &&
           ( state === $scope.emailIsValid() );
  };

  $scope.passwordIsState = function(state) {
    return $scope.password.length > 0 && ( state === $scope.passwordIsValid() );
  };

  $scope.verifyIsState = function(state) {
    return $scope.verify.length > 0 && ( state === $scope.verifyIsValid() );
  };


  $scope.canRegister = function() {
    return $scope.usernameIsValid() &&
           $scope.emailIsValid()    &&
           $scope.passwordIsValid() &&
           $scope.verifyIsValid();
  };
};

function DownloadController($scope) {
  $scope.pageLoaded = false;

  //
  // GLOBALS
  //

  $scope.downloads = [
  {
    name: 'Korora 20',
      version: '20',
      codename: 'Peach',
      isStable: false,
      isCurrent: true,
      released: '10 January 2014',
      archs: [
        { name: 'x86_64', label: '64 bit' },
        { name: 'i686',   label: '32 bit' }
      ],
      desktops: [
        { name: 'cinnamon', label: 'CINNAMON' },
        { name: 'gnome',    label: 'GNOME'    },
        { name: 'kde',      label: 'KDE'      },
        { name: 'mate',     label: 'MATE'     },
        { name: 'xfce',     label: 'XFCE'     },
      ],
      links: [
        {
          arch: 'i686',
          desktop: 'cinnamon',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-i386-cinnamon-live.iso/download', },
          ]
        },
        {
          arch: 'i686',
          desktop: 'gnome',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-i386-gnome-live.iso/download', },
          ]
        },
        {
          arch: 'i686',
          desktop: 'kde',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-i386-kde-live.iso/download', },
          ]
        },
        {
          arch: 'i686',
          desktop: 'mate',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-i386-mate-live.iso/download', },
          ]
        },
        {
          arch: 'i686',
          desktop: 'xfce',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-i386-xfce-live.iso/download', },
          ]
        },
        {
          arch: 'x86_64',
          desktop: 'cinnamon',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-x86_64-cinnamon-live.iso/download', },
          ]
        },
        {
          arch: 'x86_64',
          desktop: 'gnome',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-x86_64-gnome-live.iso/download', },
          ]
        },
        {
          arch: 'x86_64',
          desktop: 'kde',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-x86_64-kde-live.iso/download', },
          ]
        },
        {
          arch: 'x86_64',
          desktop: 'mate',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-x86_64-mate-live.iso/download', },
          ]
        },
        {
          arch: 'x86_64',
          desktop: 'xfce',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/20/korora-20-x86_64-xfce-live.iso/download', },
          ]
        }
      ],
      checksums: [
        {
          arch: 'i686',
          desktop: 'cinnamon',
          checksum: [
            { type: 'md5', hash: '629ebb67dba64f0a17bb6e8fe2721ef9' },
            { type: 'sha', hash: '7842a2b06ad3223bed67eea632f537fff0ea0819' },
            { type: 'sha256', hash: 'fe8d8013a09754e18fb523e56068e199c7e58aaea8e3ad29ad72d003d8207149' },
          ]
        },
        {
          arch: 'i686',
          desktop: 'gnome',
          checksum: [
            { type: 'md5', hash: '7ce7a1307597eb2e102b287a7f5b2c95' },
            { type: 'sha', hash: 'fcc10b785ffce8a9d7f7cd3fca38e8cde62ae2a8' },
            { type: 'sha256', hash: '7982750d08b2597a76880ac4e6b09c61cf710c5251a9738e15b7d06e4ade39c0' },
          ]
        },
        {
          arch: 'i686',
          desktop: 'kde',
          checksum: [
            { type: 'md5', hash: 'b9fa2dfcdc906af12212a923dd8110c2' },
            { type: 'sha', hash: 'a5c757c2796bc4f9d1a3d6b515400c73981354f8' },
            { type: 'sha256', hash: '894943bff0c7fc456c5e2a93636f747e0cffaf1bcbf630bf1eee3588c9e454e0' },
          ]
        },
        {
          arch: 'i686',
          desktop: 'mate',
          checksum: [
            { type: 'md5', hash: '78f0f56f113fadaaa0edf75deb53c3a3' },
            { type: 'sha', hash: '3e388144c29fa4cd9b6dd0da045e71eeaff20e08' },
            { type: 'sha256', hash: 'e874dc7baa22d201b65124586398e49ba73879a4c3146e5d70bb733f991f0e35' },
          ]
        },
        {
          arch: 'i686',
          desktop: 'xfce',
          checksum: [
            { type: 'md5', hash: '8edffc090daabd20d7c4961cc003b4b2' },
            { type: 'sha', hash: 'fd53f50932c87721effb2fef5839192003652c5c' },
            { type: 'sha256', hash: '5071423a24d689327eec2866ef6f90488a655a1fd399ab1df256260c98d0368c' },
          ]
        },
        {
          arch: 'x86_64',
          desktop: 'cinnamon',
          checksum: [
            { type: 'md5', hash: 'e5d5593751f2e323759499b62b8e1680' },
            { type: 'sha', hash: '5270a13b19fbd24c9db89e3df921d1aeda476374' },
            { type: 'sha256', hash: '487a450d1d19df16de4c21d421c50dfdb4483092ee5a27ca7d4945238b34fd63' },
          ]
        },
        {
          arch: 'x86_64',
          desktop: 'gnome',
          checksum: [
            { type: 'md5', hash: '17ecf28bad63b02d088877c33f1f2fb2' },
            { type: 'sha', hash: '78117aa2d7ade29321ec74be37246bb670def82e' },
            { type: 'sha256', hash: '7c751d6b5207ccdfefb28e477d7a5d7e8a3df77823cbbed9b1484866f8668dac' },
          ]
        },
        {
          arch: 'x86_64',
          desktop: 'kde',
          checksum: [
            { type: 'md5', hash: 'a9eb84fdf71a2e1590f4d4bee7534336' },
            { type: 'sha', hash: 'ec724f5f4f0e9c77e9c95fc2311a8190dc3ec461' },
            { type: 'sha256', hash: '0877cf6913c35da37656c0a316fafe5d27c7b151182deb031f0bc002d040d08c' },
          ]
        },
        {
          arch: 'x86_64',
          desktop: 'mate',
          checksum: [
            { type: 'md5', hash: '00c5e82f42f6b598be1b493d5ad9c3ae' },
            { type: 'sha', hash: '58fd2c99f3e16d3b6027dacad4d8a6aa7b21425f' },
            { type: 'sha256', hash: '1d2384c765744a9513bde216c3f7a47b674faa8988ac86610a118529004aec36' },
          ]
        },
        {
          arch: 'x86_64',
          desktop: 'xfce',
          checksum: [
            { type: 'md5', hash: 'e1adedb1a623716b653a2b270116c585' },
            { type: 'sha', hash: '2dbbe24f70e5f939f96fa33a99bfd732de265c5a' },
            { type: 'sha256', hash: 'b7e051652b693d053e644d7ce572b37700e7f1298d8ec50cfdd6f8386b189177' },
          ]
        }
      ],
      available: true,
    },
    {
      name: 'Korora 19.1',
      version: '19.1',
      codename: 'Bruce',
      isStable: true,
      isCurrent: true,
      released: '07 October 2013',
      archs: [
        {
          name: 'x86_64',
          label: '64 bit'
        },
        {
          name: 'i686',
          label: '32 bit'
        }
      ],
      desktops: [
        {
          name: 'cinnamon',
          label: 'CINNAMON'
        },
        {
          name: 'gnome',
          label: 'GNOME'
        },
        {
          name: 'kde',
          label: 'KDE'
        },
        {
          name: 'mate',
          label: 'MATE'
        }
      ],
      links: [
        {
          arch: 'i686',
          desktop: 'cinnamon',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/19/korora-19.1-i386-cinnamon-live.iso/download', },
            { type: 'TORRENT', url: 'http://burnbit.com/download/258852/korora_19_1_i386_cinnamon_live_iso', },
          ]
        },
        {
          arch: 'i686',
          desktop: 'gnome',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/19/korora-19.1-i386-gnome-live.iso/download', },
            { type: 'TORRENT', url: 'http://burnbit.com/download/258850/korora_19_1_i386_gnome_live_iso', },
          ]
        },
        {
          arch: 'i686',
          desktop: 'kde',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/19/korora-19.1-i386-kde-live.iso/download', },
            { type: 'TORRENT', url: 'http://burnbit.com/download/258849/korora_19_1_i386_kde_live_iso', },
          ]
        },
        {
          arch: 'i686',
          desktop: 'mate',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/19/korora-19.1-i386-mate-live.iso/download', },
            { type: 'TORRENT', url: 'http://burnbit.com/download/258851/korora_19_1_i386_mate_live_iso', },
          ]
        },
        {
          arch: 'x86_64',
          desktop: 'cinnamon',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/19/korora-19.1-x86_64-cinnamon-live.iso/download', },
            { type: 'TORRENT', url: 'http://burnbit.com/download/258848/korora_19_1_x86_64_cinnamon_live_iso', },
          ]
        },
        {
          arch: 'x86_64',
          desktop: 'gnome',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/19/korora-19.1-x86_64-gnome-live.iso/download', },
            { type: 'TORRENT', url: 'http://burnbit.com/download/258845/korora_19_1_x86_64_gnome_live_iso', },
          ]
        },
        {
          arch: 'x86_64',
          desktop: 'kde',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/19/korora-19.1-x86_64-kde-live.iso/download', },
            { type: 'TORRENT', url: 'http://burnbit.com/download/258847/korora_19_1_x86_64_kde_live_iso', },
          ]
        },
        {
          arch: 'x86_64',
          desktop: 'mate',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/19/korora-19.1-x86_64-mate-live.iso/download', },
            { type: 'TORRENT', url: 'http://burnbit.com/download/258846/korora_19_1_x86_64_mate_live_iso', },
          ]
        }
      ],
      checksums: [
        {
          arch: 'i686',
          desktop: 'cinnamon',
          checksum: [
            { type: 'md5', hash: 'be8efdd7b3db9b860f399abd891d07a9' },
            { type: 'sha', hash: '0978fb4f54f306c8f476e1109f7f872c27304757' },
            { type: 'sha256', hash: 'a0f287636dc2264a2fdee4b422b518337bb6b26e3e9f1775ccbad2e5621a9e6f' },
          ]
        },
        {
          arch: 'i686',
          desktop: 'gnome',
          checksum: [
            { type: 'md5', hash: 'dc4df9822705383aeb287ce77682cf10' },
            { type: 'sha', hash: '59e9ba6b456078c65eae1adcd724b94ecc3f052d' },
            { type: 'sha256', hash: 'f8cf78c06b7ee5dd8821f08fcdbfb075ff08661ac3672a830c81458670ded214' },
          ]
        },
        {
          arch: 'i686',
          desktop: 'kde',
          checksum: [
            { type: 'md5', hash: 'd57dac081ec565fcf7d03ce87782cc28' },
            { type: 'sha', hash: '5383bf026e97b0663ddbb452a106ff9ebfae2de7' },
            { type: 'sha256', hash: '08209b346ca67b998937d41a05835f98c5a2f015c93c68b85a56bd2e6fede7b8' },
          ]
        },
        {
          arch: 'i686',
          desktop: 'mate',
          checksum: [
            { type: 'md5', hash: '5b3dc6e039a99246cea3aa1d1df834d3' },
            { type: 'sha', hash: '1e66d5083ad607446ed8850baeda8b32dbba143a' },
            { type: 'sha256', hash: 'c7728ef26cc9e75757ff99d56752c955f70494b5f2a512c2a44138d15961af23' },
          ]
        },
        {
          arch: 'x86_64',
          desktop: 'cinnamon',
          checksum: [
            { type: 'md5', hash: '25742ef9af59ebb5765e30b8a4414a0e' },
            { type: 'sha', hash: 'f0718555cca66ac417c8484e40ab876f75f7eff1' },
            { type: 'sha256', hash: 'c274d70ae0aa2ce818237b248cb0ec2c5d8f76e8b76e729856bbc35fe0a34f38' },
          ]
        },
        {
          arch: 'x86_64',
          desktop: 'gnome',
          checksum: [
            { type: 'md5', hash: 'e1cfbef695af85b9f0094ecac6d7cb67' },
            { type: 'sha', hash: '95cc4648564a4dac6538206020423ca18746fa75' },
            { type: 'sha256', hash: '698956d7af8279c32730d60887a22e3b6ffdbd2e4c9b653e0833a9065ba29d54' },
          ]
        },
        {
          arch: 'x86_64',
          desktop: 'kde',
          checksum: [
            { type: 'md5', hash: '62cc01b7cc8d111c5c80248ad3380d71' },
            { type: 'sha', hash: 'fc4d071309957cc524b7cba110ae7ab1cb0b3e09' },
            { type: 'sha256', hash: 'a30cbef47b369beac8cc7a180338a9d77b3aba812d5a630230eb38acadf11047' },
          ]
        },
        {
          arch: 'x86_64',
          desktop: 'mate',
          checksum: [
            { type: 'md5', hash: '75344ea4e67bb7454b5dc9ea4a7dc3e5' },
            { type: 'sha', hash: '683433b865d81e6920b9a0288e03161df5a39bf6' },
            { type: 'sha256', hash: '5d79b3e3a01c37f5dd80d87e894e2ed152555b6dcbdeeac425a06387c08741c2' },
          ]
        }
      ],
      available: true,
    },
    {
      name: 'Korora 18',
      version: '18',
      codename: 'Flo',
      isStable: true,
      isCurrent: false,
      released: '01 May 2013',
      archs: [
        {
          name: 'x86_64',
          label: '64 bit'
        },
        {
          name: 'i686',
          label: '32 bit'
        }
      ],
      desktops: [
        {
          name: 'gnome',
          label: 'GNOME'
        },
        {
          name: 'kde',
          label: 'KDE'
        }
      ],
      links: [
        {
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/18/korora-18-i386-gnome-live.iso/download', },
          ],
          arch: 'i686',
          desktop: 'gnome',
        },
        {
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/18/korora-18-i386-kde-live.iso/download', },
          ],
          arch: 'i686',
          desktop: 'kde',
        },
        {
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/18/korora-18-x86_64-gnome-live.iso/download', },
          ],
          arch: 'x86_64',
          desktop: 'gnome',
        },
        {
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaproject/files/18/korora-18-x86_64-kde-live.iso/download', },
          ],
          arch: 'x86_64',
          desktop: 'kde',
        },
      ],
      checksums: [
        {
          arch: 'i686',
          desktop: 'gnome',
          checksum: [
            { type: 'md5', hash: '6b2937fc76599c82b4f1bf5eb87fc2ed' },
            { type: 'sha', hash: '91528703cbd314ca32b42df5b064dab526199ac8' },
            { type: 'sha256', hash: '5cf1f3192cef63c8eba8bfb3f6634d15aac8b7662c1a9bc913b528f88770fa25' },
          ],
        },
        {
          arch: 'i686',
          desktop: 'kde',
          checksum: [
            { type: 'md5', hash: 'e6f31d4ff03c1c6cc79123ec1bec3107' },
            { type: 'sha', hash: '4421274f16068f5194f3e9f5b5459a9ad86efbcb' },
            { type: 'sha256', hash: 'c359d3142157d3a0c15689d9e7e00f29b7d90681474d8b5d58125475ff6470ba' },
          ],
        },
        {
          arch: 'x86_64',
          desktop: 'gnome',
          checksum: [
            { type: 'md5', hash: '35720eed9123f973d9b3590cf29670de' },
            { type: 'sha', hash: '240fef106e8da4fd932d646ee337f2a7d37bd436' },
            { type: 'sha256', hash: '226d1c7c0af6262a906dacf88cee09efb62b7f25ff47357dff9da95ef7d6d0b9' },
          ],
        },
        {
          arch: 'x86_64',
          desktop: 'kde',
          checksum: [
            { type: 'md5', hash: 'ad140e9aaa19bdf5b5d4fd369b02705a' },
            { type: 'sha', hash: '4c6df0e8e6d32aa40789e63598e41a0fc7cfbd24' },
            { type: 'sha256', hash: 'ed1caa59d2bf1f120c6392e79937b2db23fe21935ff4a6f9503760cd52979213' },
          ],
        },
      ],
      available: true,
    },
    {
      name: 'Kororaa 17',
      version: '17',
      codename: 'Bubbles',
      isStable: true,
      isCurrent: false,
      released: '16 Jul 2012',
      archs: [
        {
          name: 'x86_64',
          label: '64 bit (x86_64)'
        },
        {
          name: 'i686',
          label: '32 bit (i686)'
        }
      ],
      desktops: [
        {
          name: 'gnome',
          label: 'GNOME'
        },
        {
          name: 'kde',
          label: 'KDE'
        }
      ],
      links: [
        {
          arch: 'i686',
          desktop: 'gnome',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaa/files/17/Kororaa-17-i686-Live-GNOME.iso/download', },
          ],
        },
        {
          arch: 'i686',
          desktop: 'kde',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaa/files/17/Kororaa-17-i686-Live-KDE.iso/download', },
          ],
        },
        {
          arch: 'x86_64',
          desktop: 'gnome',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaa/files/17/Kororaa-17-x86_64-Live-GNOME.iso/download', },
          ],
        },
        {
          arch: 'x86_64',
          desktop: 'kde',
          link: [
            { type: 'HTTP', url: 'http://sourceforge.net/projects/kororaa/files/17/Kororaa-17-x86_64-Live-KDE.iso/download', },
          ],
        },
      ],
      checksums: [
        {
          arch: 'i686',
          desktop: 'gnome',
          checksum: [
            { type: 'md5', hash: '35c0f58ed2c1b3db4d24de488cedeabb' },
            { type: 'sha', hash: 'b527eade025a75a2dc899574e9d825d31534d5f7' },
            { type: 'sha256', hash: '6f6e3fee31edc54565df917a779d1138cdc876f1a02144b45f5f38e320fe6ee4' },
          ],
        },
        {
          arch: 'i686',
          desktop: 'kde',
          checksum: [
            { type: 'md5', hash: '23063b994c8241a3ed652f13a1121eec' },
            { type: 'sha', hash: 'dab1dd6f8cc997a69458e02df547a2eccde55c0f' },
            { type: 'sha256', hash: 'a1487a5eab6fc9140a2a5e035ed194bc7e42bd9a6bd3bbcedf905482cf77b5fb' },
          ],
        },
        {
          arch: 'x86_64',
          desktop: 'gnome',
          checksum: [
            { type: 'md5', hash: '31eadf3abb27197ed8f8990a0b47dad7' },
            { type: 'sha', hash: '4073edc29033615ee9b32e586a6dae79dac1fbae' },
            { type: 'sha256', hash: '0db34cf287b92b4880c489ca2128d7cffba3346dc131f4a5a07555ab12219743' },
          ],
        },
        {
          arch: 'x86_64',
          desktop: 'kde',
          checksum: [
            { type: 'md5', hash: '44eade8b4290872ab38bc27a222ffbe7' },
            { type: 'sha', hash: '95adc42d847cab0975dc07c9a38422cd94c59c1d' },
            { type: 'sha256', hash: 'ce639eb52a79a9d6688d9a73ef8747c3d6b119ecda6d5ca744c64a0677586eb4' },
          ],
        },
      ],
      available: false,
    }
  ];

  //
  // FUNCTIONS
  //

  $scope.downloadsAvailable = function() {
    var _a = [];

    for(var i=0, l=$scope.downloads.length; i<l; i++ ) {
      if( $scope.downloads[i].available ) {
        _a.push( $scope.downloads[i] );
      }
    }

    return _a;
  };

  $scope.isAvailable = function(item) {
    return item.available;
  };

  $scope.getPreferredVersion = function( args ) {
    // check for specified arch
    if( args.hasOwnProperty('v') ) {
      for(var n=0, l=$scope.downloads.length; n<l; n++ ) {
        if( $scope.downloads[n].version === args.v ) {
          return $scope.downloads[n];
        }
      }
    }
    // otherise pick most current stable
    else {
      for(var n=0, l=$scope.downloads.length; n<l; n++ ) {
        if( $scope.downloads[n].isCurrent &&
            $scope.downloads[n].isStable ) {
          return $scope.downloads[n];
        }
      }
    }

    return $scope.downloads[0];
  };

  $scope.getPreferredArch = function( args ) {
    // check for specified arch
    var i = -1;
    if( args.hasOwnProperty('a') ) {
      i = $scope.version.archs.indexOfObject('name', args.a);
    }

    // check for browser arch as a fallback
    if( i < 0 ) {
      var _system_arch = ( window.navigator.userAgent.indexOf('WOW64')>-1 ||
                           window.navigator.platform == 'Win64' ||
                           window.navigator.userAgent.indexOf('x86_64')>-1 ) ? 'x86_64' : 'i686';

      i = $scope.version.archs.indexOfObject('name', _system_arch);
    }

    // otherwise the first item will do
    if( i < 0 ) {
      i = 0;
    }

    return $scope.version.archs[i];
  };

  $scope.getPreferredDesktop = function( args ) {
    // check for specified arch
    var i = -1;
    if( args.hasOwnProperty('d') ) {
      i = $scope.version.desktops.indexOfObject('name', args.d);
    }

    // check randomise as a fallback
    if( i < 0 ) {
      i = Math.floor(Math.random()* $scope.version.desktops.length);
    }

    return $scope.version.desktops[i];
  };

  $scope.hasArchs = function() {
    return $scope.version.archs.length > 0;
  };

  $scope.hasLinks = function() {
    return $scope.version.links.length > 0;
  };

  $scope.selectDesktop = function(d) {
    $scope.desktop = d;
  };

  $scope.selectedDesktop = function() {
    return $scope.desktop;
  };

  $scope.validDesktop = function() {
    return ($scope.desktop !== null);
  };

  $scope.getStabilityString = function() {

    return ( $scope.version.isCurrent ? "the latest " : "the previous " ) +
           ( $scope.version.isStable  ? "stable " : "beta " ) + "version";
  };

  $scope.isVersionStable = function() {
    return ( $scope.version.isStable );
  };

  $scope.isSelected = function(d) {
    return ( ( $scope.desktop !== null ) && ( $scope.desktop.name === d ) );
  };

  $scope.formatShortHash = function(hash) {
    if( hash.length > 16 ) {
      return hash.substr(0,8) + '...' + hash.substr(-8);
    }

    return hash;
  }

  //
  // INIT
  //

  var args = {}, hash;
  var q = document.URL.split('?')[1];
  if( q != undefined ) {
    q = q.split('&');
    for( var i = 0; i < q.length; i++ ) {
      hash = q[i].split('=');
      args[hash[0]] = hash[1];
    }
  }

  $scope.version = $scope.getPreferredVersion( args );
  $scope.arch = $scope.getPreferredArch( args );
  $scope.desktop = $scope.getPreferredDesktop( args );

  $scope.pageLoaded = true;
};


function DonateController($scope, $http) {
  $scope.donor_name;
  $scope.donor_email;
  $scope.donor_amount;

  $scope.cc_name;
  $scope.cc_number;
  $scope.cc_expirty_month;
  $scope.cc_expirty_year;
  $scope.cc_security_code;

  $scope.error = {
    email: 'Invalid email address specified.',
    password: 'Password must be at least 8 characters.',
    verify: 'Passwords must match.'
  };

  $scope.paymentViewUpdate = function(mode) {
    var _mode = mode || 'cc';

    if( _mode === 'cc' ) {
      $('#cc_payment').show();
    }
    else {
      $('#cc_payment').hide();
    }
  }

  $scope.donorEmailIsValid = function() {
    if( $scope.donor_email && $scope.donor_email.length > 0 ) {
      var re = /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\ ".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA -Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;

      if( re.test($scope.donor_email) ) {
        return true;
      }

      $scope.error.email = 'Please enter a valid email address.';
    }
    else {
      $scope.error.email = 'Email address is already taken.';
    }

    return false;
  };

  $scope.donorAmountIsValid = function() {
    return( ( $scope.donor_amount && $scope.donor_amount.length > 0 ) &&
            ( ! isNaN( parseFloat($scope.donor_amount) ) ) &&
            ( parseFloat($scope.donor_amount) > 0 ) );
  };


  $scope.donorEmailValidity = function(state) {
    if( $scope.donor_email && $scope.donor_email.length > 0 ) {
      return $scope.donorEmailIsValid() ? 'has-success' : 'has-error';;
    }

    return '';
  };

  $scope.donorAmountValidity = function(state) {
    if( $scope.donor_amount && $scope.donor_amount.length > 0 ) {
      return $scope.donorAmountIsValid() ? 'has-success' : 'has-error';;
    }

    return '';
  };

  $scope.ccNameIsValid = function() {
    return $scope.cc_name && $scope.cc_name.length > 0;
  };

  $scope.ccNameValidity = function(state) {
    if( $scope.cc_name && $scope.cc_name.length > 0 ) {
      return $scope.ccNameIsValid() ? 'has-success' : 'has-error';;
    }

    return '';
  };

  $scope.ccNumberIsValid = function() {
    return $scope.cc_number && $scope.cc_number.length >= 15;
  };

  $scope.ccNumberValidity = function(state) {
    if( $scope.cc_number && $scope.cc_number.length > 0 ) {
      return $scope.ccNumberIsValid() ? 'has-success' : 'has-error';;
    }

    return '';
  };

  $scope.ccSecurityCodeIsValid = function() {
    return $scope.cc_security_code && $scope.cc_security_code.length >= 3;
  };

  $scope.ccSecurityCodeValidity = function(state) {
    if( $scope.cc_security_code && $scope.cc_security_code.length > 0 ) {
      return $scope.ccSecurityCodeIsValid() ? 'has-success' : 'has-error';;
    }

    return '';
  };

  $scope.canDonate = function() {
    return $scope.donorEmailIsValid() &&
           $scope.donorAmountIsValid() &&
           $scope.ccNameIsValid() &&
           $scope.ccNumberIsValid();
  };
};




























function CanvasController($scope) {
  $scope.data = {};
};

function RepositoryController($scope) {
  $scope.data = [];
};

function PackageController($scope, CanvasNavigation, $http) {
  $scope.data = {};
  $scope.data_details = {};
  $scope._pageLoading = false;

  $scope.formatSize = function(bytes) {
    var _bytes = bytes;
    var _map = {
      1: 'b',
      2: 'k',
      3: 'M'
    };

    return bytes + 'b';
  }

  //
  // PAGINATION
  //


  //
  // PAGINATION
  //

  $scope.havePages = function() {
    return ( $scope.data.hasOwnProperty('page') ) &&
           ( $scope.data.hasOwnProperty('last_page') );
  };

  $scope.pageList = function(elements) {
    var _m = elements || 5;
    var _list = [];

    if( $scope.havePages() ) {
      var _total_pages = Math.ceil($scope.data.total_items / $scope.data.page_size);

      if( _m >= _total_pages ) {
        for( var i = 0; i < _total_pages; i++ ) {
          _list.push(i);
        }
      }
      else {
        /* calculate lower and upper bounds */
        var _lb = Math.max(0, $scope.data.page - Math.floor(_m / 2));
        var _ub = Math.min(_total_pages, _lb + _m);

        if( (_ub-_lb) <= (_m-1) ) {
          _lb = _ub - _m;
        }

        for( var i = _lb; i < _ub; i++ ) {
          _list.push(i);
        }
      }
    }

    return _list;
  }

  $scope.isFirstPage = function() {
    return ( $scope.havePages() ) &&
           ( $scope.data.page == 0 );
  };

  $scope.isLastPage = function() {
    return ( $scope.havePages() ) &&
           ( $scope.data.page === $scope.data.last_page );
  };

  $scope.currentPage = function() {
    if( ! $scope.havePages() ) {
      return 0;
    }

    return $scope.data.page;
  };

  $scope.isPage = function(page) {
    var _page = page || 0;

    return ( $scope.havePages() ) &&
           ( $scope.data.page === _page );
  };

  $scope.isPageLoading = function() {
    return $scope._pageLoading;
  }

  $scope.firstPage = function() {
    if( ( ! $scope.havePages() ) ||
        ( $scope.isFirstPage() ) ) {
      return;
    }

    $scope.loadPage({
      _cp: 0
    });
  }

  $scope.lastPage = function() {
    if( ( ! $scope.havePages() ) ||
        ( $scope.isLastPage() ) ) {
      return;
    }

    $scope.loadPage({
      _cp: $scope.data.last_page
    });
  }

  $scope.nextPage = function(elements) {
    var _m = elements || 5;

    if( ( ! $scope.havePages() ) ||
        ( $scope.isLastPage() ) ) {
      return;
    }

    $scope.loadPage({
      _cp: $scope.data.page + _m
    });
  }

  $scope.previousPage = function(elements) {
    var _m = elements || 5;

    if( ( ! $scope.havePages() ) ||
        ( $scope.isFirstPage() ) ) {
      return;
    }

    $scope.loadPage({
      _cp: $scope.data.page - _m
    });
  }

  $scope.setPage = function(page) {
    var _page = page || 0;

    if( ( ! $scope.havePages() ) &&
        ( ! $scope.isPage(page) ) ) {
      return;
    }

    $scope.loadPage({
      _cp: _page
    });
  }

  //
  // LOAD PACKAGES
  $scope.loadPage = function(param) {
    var _param = param || {};
    $scope._pageLoading = true;

    $http({
      method: 'GET',
      url: '/api/packages',
      params: _param
    })
      .success( function(data, status, headers, config) {
        $scope.data = data;

        console.log(data);
        $scope._pageLoading = false;
      })
      .error( function(data, status, headers, config) {
        $scope._pageLoading = false;
      });
  }

  //
  // DETAILS
  //
  $scope.isPackageDetailsSelected = function(id) {
    return ( ( $scope.data_details.hasOwnProperty(id) ) &&
             ( $scope.data_details[id].hasOwnProperty('_selected') ) &&
             ( $scope.data_details[id]._selected ) );
  }

  $scope.isPackageDetailsVisible = function(id) {
    return ( ( $scope.data_details.hasOwnProperty(id) ) &&
             ( $scope.data_details[id].hasOwnProperty('_visible') ) &&
             ( $scope.data_details[id]._visible ) );
  };

  $scope.togglePackageDetailsSelected = function(id) {
    // load the package details if required
    if( ! ( $scope.data_details.hasOwnProperty(id) ) ) {
      $scope.loadPackageDetails(id);
    }

    // toggle visibility
    if( $scope.data_details[id].hasOwnProperty('_selected') ) {
      $scope.data_details[id]._selected ^= true;
    }
  };

  $scope.togglePackageDetails = function(id) {
    // load the package details if required
    if( ! ( $scope.data_details.hasOwnProperty(id) ) ) {
      $scope.loadPackageDetails(id);
    }

    // toggle visibility
    if( $scope.data_details[id].hasOwnProperty('_visible') ) {
      $scope.data_details[id]._visible ^= true;
    }
  };

  //
  // LOAD PACKAGE DETAILS
  $scope.loadPackageDetails = function(id) {

    // TODO: validate id
    if( id <= 0 ) {
      return;
    }

    // check for cache
    if( $scope.data_details.hasOwnProperty(id) ) {
      return;
    }

    // initialise details object for id
    $scope.data_details[id] = {
      _pageLoading: true,
      _selected: false,
      _visible: false
    };

    $http({
      method: 'GET',
      url: '/api/package/' + id
    })
      .success( function(data, status, headers, config) {
        angular.extend($scope.data_details[id], data);

        $scope.data_details[id]._pageLoading = false;
      })
      .error( function(data, status, headers, config) {
        $scope.data_details[id]._pageLoading = false;
      });
  }

  //
  // INIT
  CanvasNavigation.setPage('canvas-packages');

  $scope.loadPage();
};
