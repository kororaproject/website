

/*
**
*/
'use strict';
var app = angular.module('canvas', ['ui.bootstrap']);



/*
** SERVICES
*/
app.service('Database', function($resource) {
  return {
    packages: $resource('/api/packages')
  };
});


/*
** FILTERS
*/
app.filter('package', function() {
  return function(items, needle) {
    var _filtered = items.filter(function(element) {
      var _haystack = element.n + '||' + element.e + ':' + element.v + '-' + element.r + '||' + element.a;
      return _haystack.indexOf(needle) !== -1;
    });

    return _filtered;
  }
});

// 0-based pagination
app.filter('paginateWith', function() {
  return function(items, page, pageSize) {
    var _page = page || 0;
    var _pageSize = pageSize || 100;
    var _begin = _page * _pageSize;

    return items.slice(_begin, _begin+_pageSize);
  }
});

/*
** CONTROLLERS
*/

app.controller('NavigatationController', ['$scope', 'CanvasNavigation',
  function($scope, CanvasNavigation) {

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
  }
]);

app.controller('ActivateController', ['$scope', '$http',
  function($scope, $http) {
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
  }
]);

app.controller('PasswordResetController', ['$scope', '$http',
  function($scope, $http) {
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
  }
]);

app.controller('RegisterController', ['$scope', '$http',
  function($scope, $http) {
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
  }
]);

app.controller('DownloadController', ['$scope',
  function ($scope) {
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

      // check for specified version
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

      /* process for available desktops */
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

      return _release;
    };

    $scope.selectDesktop = function(d) {
      $scope.desktop = d;
    };

    $scope.desktopLabel = function(d) {
      if( $scope.downloads.desktops.hasOwnProperty(d) ) {
        return $scope.downloads.desktops[ d ];
      }

      return 'Unknown';
    };

    $scope.getDesktops = function() {
      return Object.keys($scope.release.isos);
    };

    $scope.getChecksums = function() {
      var _isos = $scope.release.isos;

      var _checksums = {};

      if (_isos.hasOwnProperty($scope.desktop)) {
        _checksums = _isos[$scope.desktop].checksum;
      }

      return _checksums;
    }

    $scope.getLinks = function() {
      var _isos = $scope.release.isos;

      var _links = {};

      if (_isos.hasOwnProperty($scope.desktop)) {
        _links = _isos[$scope.desktop].url;
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
  }
]);


app.controller('DonateController', ['$scope', '$http',
  function($scope, $http) {
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
  }
]);


app.controller('SponsorController', ['$scope', '$http',
  function($scope, $http) {
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
  }
]);





























app.controller('ModalInstanceCtrl', function ($scope, $modalInstance, items) {

  $scope.items = items;
  $scope.selected = {
    item: $scope.items[0]
  };

  $scope.ok = function () {
    $modalInstance.close($scope.selected.item);
  };

  $scope.cancel = function () {
    $modalInstance.dismiss('cancel');
  };
});

app.controller('TemplateController', ['$scope', '$modal', '$log', '$http', 'packageFilter',
  function($scope, $modal, $log, $http, packageFilter) {
    $scope.data = window.kp.template;
    $scope.data.includes_stubs = delete $scope.data.includes;

    $scope.packages = [];

    $scope.filter = "";

    $scope.packageOrderField = 'n';
    $scope.packageOrderReverse = false;

    $scope.pageSize = 50;
    $scope.item_count = $scope.packages.length;
    $scope.page = 0;
    $scope.page_last = Math.floor($scope.item_count / $scope.pageSize);
    $scope.page_item_first = 0;
    $scope.page_item_last = 0;

    $scope.resolveIncludes = function() {
      $http.get('/api/template/' + $scope.data.id + '/includes')
        .success(function(data, status, headers, config) {
          if (status === 200) {
            $scope.data.includes = data;
            $scope.flattenIncludes();
          }
        })
        .error(function(data, status, headers, config) {
        });
    };

    $scope.flattenIncludes = function() {
      var set = {};
      var packages = [];

      var fn; fn = function(i, p, s) {
        // add packages
        angular.forEach(i.packages, function(v) {
          if (! s[v.n]) {
            s[v.n] = 1;
            v.template = i.id;
            p.push(v);
          }
        });

        // resolve includes
        angular.forEach(i.includes, function(v) {
          fn(v, p, s);
        });
      };

      // recurse all includes
      fn($scope.data, packages, set);

      // replace our packages with our resolved ones
      $scope.data.packages = packages;
    };

    $scope.packageInclude = function(p) {
      return p.template !== $scope.data.id;
    };

    $scope.toggleOrderField = function(field) {
      if (field != $scope.packageOrderField) {
        $scope.packageOrderField = field
        $scope.packageOrderReverse = false;
      }
      else {
        $scope.packageOrderReverse ^= true;
      }
    };

    /* pager directive */
    $scope.noPageNext = function() {
      return $scope.page === $scope.page_last;
    };

    $scope.noPagePrev = function() {
      return $scope.page === 0;
    };

    $scope.pageNext = function() {
      if ($scope.page < $scope.page_last) {
        $scope.page++;

        $scope.page_item_first = ($scope.page * $scope.pageSize) + 1;
        $scope.page_item_last = Math.min($scope.page_item_first+$scope.pageSize, $scope.item_count);
      }
    };

    $scope.pagePrev = function() {
      if ($scope.page > 0) {
        $scope.page--;

        $scope.page_item_first = ($scope.page * $scope.pageSize) + 1;
        $scope.page_item_last = Math.min($scope.page_item_first+$scope.pageSize, $scope.item_count);
      }
    };
    /* end pager directive */

    $scope.$watchGroup(['filter','data.packages'], function() {
      $scope.packages = packageFilter($scope.data.packages, $scope.filter);

      if ($scope.item_count !== $scope.packages.length) {
        $scope.item_count = $scope.packages.length
        $scope.page_last = Math.floor($scope.item_count / $scope.pageSize);

        var _page_item_first = ($scope.page * $scope.pageSize) + 1;
        if ($scope.item_count < _page_item_first) {
          $scope.page = 0;
          _page_item_first = 1;
        }

        $scope.page_item_first = _page_item_first;
        $scope.page_item_last = Math.min($scope.page_item_first+$scope.pageSize, $scope.item_count);

      }
    });


    $scope.items = ['item1', 'item2', 'item3'];
    $scope.open = function() {
      var modalInstance = $modal.open({
        templateUrl: 'myModalContent.html',
        controller: 'ModalInstanceCtrl',
        size: 'lg',
        backdrop: 'static',
        resolve: {
          items: function() {
            return $scope.items;
          }
        }
      });

      modalInstance.result.then(function(selectedItem) {
        $scope.selected = selectedItem;
      }, function() {
        $log.info('Modal dismissed at: ' + new Date());
      });
    };

    $scope.resolveIncludes();
  }
]);
