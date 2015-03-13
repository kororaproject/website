
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
  $scope.username = '';
  $scope.email = '';
  $scope.password = '';
  $scope.verify = '';

  $scope.error = {
    username: 'Username is already taken.',
    email: 'Email is invalid.',
    password: 'Password must be at least 8 characters.',
    verify: 'Passwords must match.',
    token: 'Token is invalid.'
  };

  $scope.usernames = {};
  $scope._lookup_details = false;

  $scope.lookupDetails = function() {
    console.debug("Lookup: " + $scope.username + "||");

    /* check for cached results */
    if ($scope.usernames.hasOwnProperty($scope.username))
      return;

    /* check profile status */
    $scope._lookup_details = true;

    $http({
      method: 'POST',
      url: '/profile/status',
      params: { name: $scope.username }
    })
      .success( function(data, status, headers, config) {
        if (data.hasOwnProperty('username') ) {
          $scope.usernames[data.username.key] = (data.username.status !== 1);
        }
        $scope._lookup_details = false;
      })
      .error( function(data, status, headers, config) {
        $scope._lookup_details = false;
      });
  };

  $scope.tokenIsValid = function() {
    return $scope.token.length == 32;
  };

  $scope.tokenIsState = function(state) {
    return $scope.token.length > 0 && ( state === $scope.tokenIsValid() );
  };

  $scope.usernameIsState = function(state) {
    var _u = $scope.username;
    return _u.length && $scope.usernames.hasOwnProperty(_u) && (state === $scope.usernameIsValid());
  };

  $scope.usernameIsValid = function() {
    if ($scope.username.length > 0) {
      var re = /^[A-Za-z0-9_]+$/;
      if (re.test($scope.username)) {
        if ($scope.usernames.hasOwnProperty($scope.username)) {
          if ($scope.usernames[$scope.username]) {
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
        $scope.error.username = 'Usernames can only contain alphanumeric characters and underscores only.';
      }
    }

    return false;
  };

  $scope.canActivateEmail = function() {
    return $scope.tokenIsValid();
  };

  $scope.canActivateOAuth = function() {
    return $scope.usernameIsValid();
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
    if ($scope.usernames.hasOwnProperty($scope.username) &&
        $scope.emails.hasOwnProperty($scope.email)) {
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
        if (data.hasOwnProperty('username') ) {
          $scope.usernames[data.username.key] = (data.username.status !== 1);
        }
        if (data.hasOwnProperty('email')) {
          $scope.emails[data.email.key] = (data.email.status !== 1);
        }
        $scope._lookup_details = false;
      })
      .error( function(data, status, headers, config) {
        $scope._lookup_details = false;
      });
  };

  $scope.usernameIsValid = function() {
    if ($scope.username.length > 0) {
      var re = /^[A-Za-z0-9_]+$/;
      if (re.test($scope.username)) {
        if ($scope.usernames.hasOwnProperty($scope.username)) {
          if ($scope.usernames[$scope.username]) {
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
        $scope.error.username = 'Usernames can only contain alphanumeric characters and underscores only.';
      }
    }

    return false;
  };

  $scope.emailIsValid = function() {
    if ($scope.email.length > 0) {
      if ($scope.emails.hasOwnProperty($scope.email)) {
        if ($scope.emails[$scope.email] ) {
          var re = /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\ ".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA -Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;

          $scope.error.email = '';
          if (re.test($scope.email)) {
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
    var _u = $scope.username;
    return _u.length && $scope.usernames.hasOwnProperty(_u) && (state === $scope.usernameIsValid());
  };

  $scope.emailIsState = function(state) {
    var _e = $scope.email;
    return _e.length && $scope.emails.hasOwnProperty(_e) && (state === $scope.emailIsValid());
  };

  $scope.passwordIsState = function(state) {
    return $scope.password.length > 0 && ( state === $scope.passwordIsValid() );
  };

  $scope.verifyIsState = function(state) {
    return $scope.verify.length > 0 && ( state === $scope.verifyIsValid() );
  };

  $scope.canRegister = function() {
    return $scope.usernameIsValid() &&
           $scope.passwordIsValid() &&
           $scope.verifyIsValid();
  };
};

function DownloadController($scope) {
  $scope.pageLoaded = false;

  //
  // GLOBALS
  //

  $scope.downloads = angular.fromJson(document._download_map);

  /* pre-process the map for available releases */
  $scope.releases = [];

  for(var i=0, l=$scope.downloads.releases.length; i<l; i++ ) {
    if( $scope.downloads.releases[i].available ) {
      $scope.releases.push( $scope.downloads.releases[i] );
    }
  }

  $scope.release = $scope.releases[0];

  $scope.getPreferredRelease = function(args) {
    var _release = $scope.releases[0];

    // check for specified arch
    if (args.hasOwnProperty('v') ) {
      for (var n=0, l=$scope.releases.length; n<l; n++) {
        if ($scope.releases[n].version === args.v) {
          _release = $scope.releases[n];
          continue;
        }
      }
    }
    // otherise pick most current stable
    else {
      for (var n=0, l=$scope.releases.length; n<l; n++) {
        if( !!$scope.releases[n].isCurrent &&
            !!$scope.releases[n].isStable ) {
          _release = $scope.releases[n];
          continue;
        }
      }
    }

    /* process for available desktops and archs */
    $scope.desktops = Object.keys(_release.isos)

    /* calculate preferred desktop */
    if( args.hasOwnProperty('d') &&
        $scope.desktops.indexOf(args.d) !== -1) {
        $scope.desktop = args.d;
    }
    else {
      /* check randomise as a fallback */
      $scope.desktop = $scope.desktops[Math.floor(Math.random() * $scope.desktops.length)];
    }

    /* re-calculate available archs */
    console.debug(_release, $scope.desktop);
    $scope.archs = Object.keys(_release.isos[$scope.desktop]);

    /* calculate preferred arch */
    if (args.hasOwnProperty('a') && $scope.archs.indexOf(args.a) !== -1) {
      $scope.arch = args.a;
    }
    else {
      var _nav = window.navigator;
      var _system_arch = (_nav.userAgent.indexOf('WOW64') > -1 ||
                          _nav.platform == 'Win64' ||
                          _nav.userAgent.indexOf('x86_64') > -1) ? 'x86_64' : 'i686';

      if($scope.archs.indexOf(_system_arch) !== -1) {
        $scope.arch = _system_arch;
      }
      else {
        $scope.arch = $scope.archs[0];
      }
    }

    return _release;
  };

  $scope.hasArchs = function() {
    return $scope.archs.length > 0;
  };

  $scope.selectDesktop = function(d) {
    $scope.desktop = d;
  };

  $scope.archLabel = function(a) {
    if( $scope.downloads.archs.hasOwnProperty(a) ) {
      return $scope.downloads.archs[ a ];
    }

    return 'Unknown';
  };

  $scope.desktopLabel = function(d) {
    if( $scope.downloads.desktops.hasOwnProperty(d) ) {
      return $scope.downloads.desktops[ d ];
    }

    return 'Unknown';
  };

  $scope.getArchs = function() {
    return Object.keys($scope.release.isos[$scope.desktop]);
  };

  $scope.getDesktops = function() {
    return Object.keys($scope.release.isos);
  };

  $scope.getChecksums = function() {
    var _isos = $scope.release.isos;

    var _checksums = {};

    if( _isos.hasOwnProperty( $scope.desktop ) &&
        _isos[ $scope.desktop ].hasOwnProperty( $scope.arch ) ) {
      _checksums = _isos[ $scope.desktop ][ $scope.arch ].checksum;
    }

    return _checksums;
  }

  $scope.getLinks = function() {
    var _isos = $scope.release.isos;

    var _links = {};

    if( _isos.hasOwnProperty( $scope.desktop ) &&
        _isos[ $scope.desktop ].hasOwnProperty( $scope.arch ) ) {
      _links = _isos[ $scope.desktop ][ $scope.arch ].url;
    }

    return _links;
  }

  $scope.validDesktop = function() {
    return ($scope.desktop !== null);
  };

  $scope.getStabilityString = function() {

    return ( $scope.release.isCurrent ? "the latest " : "the previous " ) +
           ( $scope.release.isStable  ? "stable " : "beta " ) + "version";
  };

  $scope.isReleaseStable = function() {
    return ( $scope.release.isStable );
  };

  $scope.isSelected = function(d) {
    return ( ( $scope.desktop !== null ) && ( $scope.desktop === d ) );
  };

  $scope.formatShortHash = function(hash) {
    if( hash.length > 16 ) {
      return hash.substr(0,8) + '...' + hash.substr(-8);
    }

    return hash;
  }

  //
  // WATCHES
  //
  $scope.$watch('release', function(n,o) {
    if (o!=n) {
      /* re-calculate preferred desktop */
      $scope.desktops = Object.keys($scope.release.isos)

      if ($scope.desktops.indexOf($scope.desktop) === -1 ) {
        /* check randomise as a fallback */
        $scope.desktop = $scope.desktops[Math.floor(Math.random() * $scope.desktops.length )];
      }

      /* re-calculate available archs */
      $scope.archs = Object.keys($scope.release.isos[$scope.desktop]);
    }
  })

  //
  // INIT
  //

  /* process args based on path query */
  var args = {}, hash;
  var q = document.URL.split('?')[1];
  if( q != undefined ) {
    q = q.split('&');
    for( var i = 0; i < q.length; i++ ) {
      hash = q[i].split('=');
      args[hash[0]] = hash[1];
    }
  }

  $scope.release = $scope.getPreferredRelease(args);

  $scope.pageLoaded = true;
};


function DonateController($scope, $http) {
  $scope.donor_name;
  $scope.donor_email;
  $scope.donor_amount;

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

  $scope.canDonate = function() {
    return $scope.donorEmailIsValid() &&
           $scope.donorAmountIsValid();
  };
};


function SponsorController($scope, $http) {
  $scope.sponsor_name;
  $scope.sponsor_email;
  $scope.sponsor_amount;

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

  $scope.sponsorEmailIsValid = function() {
    if( $scope.sponsor_email && $scope.sponsor_email.length > 0 ) {
      var re = /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\ ".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA -Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;

      if( re.test($scope.sponsor_email) ) {
        return true;
      }

      $scope.error.email = 'Please enter a valid email address.';
    }
    else {
      $scope.error.email = 'Email address is already taken.';
    }

    return false;
  };

  $scope.sponsorAmountIsValid = function() {
    return( ( $scope.sponsor_amount && $scope.sponsor_amount.length > 0 ) &&
            ( ! isNaN( parseFloat($scope.sponsor_amount) ) ) &&
            ( parseFloat($scope.sponsor_amount) >= 10 ) );
  };


  $scope.sponsorEmailValidity = function(state) {
    if( $scope.sponsor_email && $scope.sponsor_email.length > 0 ) {
      return $scope.sponsorEmailIsValid() ? 'has-success' : 'has-error';;
    }

    return '';
  };

  $scope.sponsorAmountValidity = function(state) {
    if( $scope.sponsor_amount && $scope.sponsor_amount.length > 0 ) {
      return $scope.sponsorAmountIsValid() ? 'has-success' : 'has-error';;
    }

    return '';
  };

  $scope.canSponsor = function() {
    return $scope.sponsorEmailIsValid() &&
           $scope.sponsorAmountIsValid();
  };
};




























function CanvasController($scope) {
  $scope.data = {};
};

function TemplateController($scope) {
  $scope.data = window.kp.template;

  $scope.orderByField = 'n';
  $scope.orderReverse = true;
  $scope.pageSize = 10;
  $scope.page = 0;
  $scope.pages = Math.floor( $scope.data.repos.length / $scope.pageSize );


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
