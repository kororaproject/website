var canvas = angular.module('canvas', ['ngRoute'])
  .config(function($routeProvider) {
    $routeProvider
      .when('/', {templateUrl: 'partials/home.html', controller: 'HomeController'})
      .when('/packages', {templateUrl: 'partials/packages.html', controller: 'PackageController'})
      .when('/repositories', {templateUrl: 'partials/repositories.html', controller: 'RepositoryController'})
      .otherwise({redirectTo: '/'});
  });

canvas.service('CanvasNavigation', function($rootScope) {
  var _page = '';

  return {
    setPage: function( page ) {
      $rootScope.$broadcast('routeLoaded', { slug: page });
    }
  };
});

canvas.service('Database', function($resource) {
  return {
    packages: $resource('http://localhost:3000/api/packages')
  };
});

function NavigationController($scope, CanvasNavigation) {
  $scope.$on('routeLoaded', function (event, args) {
    $scope.slug = args.slug;
  });

  $scope.pageActive = function(page) {
    return $scope.slug === page ? 'active' : '';
  };
};


function HomeController($scope, CanvasNavigation) {
  $scope.data = {};

  //
  // INIT
  CanvasNavigation.setPage('home');
};

function RepositoryController($scope, CanvasNavigation) {
  $scope.data = [];

  //
  // INIT
  CanvasNavigation.setPage('repositories');
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
    var _m = elements || 9;
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
    var _m = elements || 9;

    if( ( ! $scope.havePages() ) ||
        ( $scope.isLastPage() ) ) {
      return;
    }

    $scope.loadPage({
      _cp: $scope.data.page + _m
    });
  }

  $scope.previousPage = function(elements) {
    var _m = elements || 9;

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
  CanvasNavigation.setPage('packages');

  $scope.loadPage();
};
