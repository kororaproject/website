var canvas = angular.module('canvas', ['ngRoute', 'ngAnimate'])
  .config(function($routeProvider, $locationProvider) {
    $routeProvider
      .when('/',                     { templateUrl: '/partials/home.html', controller: 'HomeController' })
      .when('/about',                { templateUrl: '/partials/about.html', controller: 'AboutController' })
      .when('/discover',             { templateUrl: '/partials/discover.html', controller: 'DiscoverController' })
      .when('/canvas',               { templateUrl: '/partials/canvas.html', controller: 'CanvasController' })
      .when('/canvas/packages',      { templateUrl: '/partials/packages.html', controller: 'PackageController' })
      .when('/canvas/repositories',  { templateUrl: '/partials/repositories.html', controller: 'RepositoryController' })
      .otherwise({redirectTo: '/'});

    $locationProvider
      .html5Mode(true)
      .hashPrefix('!');
  });


/*
** DIRECTIVES
*/

/*
** SERVICES
*/

canvas.service('CanvasNavigation', function($rootScope) {
  var _page = '';
  var _mode = '';

  return {
    setPage: function( page ) {
      if( page.indexOf('canvas-') == 0 ) {
        _mode = 'canvas';
      }
      else {
        _mode = 'default';
      }

      $rootScope.$broadcast('routeLoaded', { slug: page, mode: _mode });
    }
  };
});

canvas.service('Database', function($resource) {
  return {
    packages: $resource('http://localhost:3000/api/packages')
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

    // frob page-container minimum height to at least the footer top
  $('.page-container').css('min-height', ($(window).height()-footer.outerHeight()) + 'px');

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


function HomeController($scope, CanvasNavigation) {
  $scope.data = {};

  //
  // INIT
  CanvasNavigation.setPage('home');
};

function AboutController($scope, CanvasNavigation) {
  $scope.data = {};

  //
  // INIT
  CanvasNavigation.setPage('about');

  $('#aboutdetails a').click(function (e) {
    e.preventDefault()
    $(this).tab('show')
  });
};

function DiscoverController($scope, CanvasNavigation) {
  $scope.data = {};

  //
  // INIT
  CanvasNavigation.setPage('discover');
};

function CanvasController($scope, CanvasNavigation) {
  $scope.data = {};

  //
  // INIT
  CanvasNavigation.setPage('canvas-home');
};

function RepositoryController($scope, CanvasNavigation) {
  $scope.data = [];

  //
  // INIT
  CanvasNavigation.setPage('canvas-repositories');
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
      url: 'http://localhost:3000/api/packages',
      params: _param
    })
      .success( function(data, status, headers, config) {
        $scope.data = data;

//        console.log(data);
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
      url: 'http://localhost:3000/api/package/' + id
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
