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
package Canvas::Core;

use warnings;
use strict;

use Mojo::Base 'Mojolicious::Controller';

#
# LOCAL INCLUDES
#
use Canvas::Store::Package;
use Canvas::Store::PackageDetails;
use Canvas::Store::User;
use Canvas::Store::UserMembership;
use Canvas::Store::Repository;
use Canvas::Store::RepositoryDetails;
use Canvas::Store::Template;
use Canvas::Store::TemplatePackage;
use Canvas::Store::TemplateMembership;
use Canvas::Store::TemplateRepository;
use Canvas::Store::WPUser;
use Canvas::Store::WPPost;
#
#
# GET /packages
#
# Returns all packages available
#
# Expected body contents is JSON encoded structure defining the template
# repositories and packages to be added.
#
# Returns:
#  - 200 on success
#  - 403 if entity exists and you don't have sufficient privileges to modify
#  - 500 if template owner doesn't exist or is invalid
#
# An overview of the JSON structure is shown below:
#
# [
#   {
#     id: id,
#     n:  "name",
#     s:  "summary",
#     sx: "description",
#     l:  "license",
#     u:  "url"
#     c:  "category",
#     t:  "type",
#     tx: [
#       "tag_1",
#       "tag_2",
#       ...
#     ]
#   },
#   ...
# ]
#
sub packages_get {
  my $self = shift;

  # construct search query as appropriate
  my $q = $self->build_query({
    name      => [ 'n', 'name' ],
    category  => [ 'c', 'category' ],
  });

  # build pager for packages
  my $pager = Canvas::Store::Package->pager(
    entries_per_page  => $self->param('_ep')  // 100,
    current_page      => $self->param('_cp')  // 0,
    order_by          => $self->param('_ob')  // 'name',
  );

  my @packages = $pager->search_where( $q );

  my $ret = [];

  foreach my $p ( @packages ) {
    push @$ret, {
      id  => $p->id+0,
      n   => $p->name,
      s   => $p->summary,
      sx  => $p->description,
      l   => $p->license,
      u   => $p->url,
      c   => $p->category,
      t   => $p->type,
      tx  => [ split /,/, $p->tags // '' ],
      cd  => $p->updated->epoch,
      ud  => $p->created->epoch,
    };
  }

  $self->render( json => {
    page        => $pager->current_page+0,
    page_size   => $pager->entries_per_page+0,
    last_page   => $pager->last_page+0,
    total_items => $pager->total_entries+0,
    items       => $ret,
  });
}

#
# POST /packages
#
# Add a new pacakge
#
# Expected body contents is JSON encoded structure defining the package to be
# added.
#
# Returns:
#  - 200 on success
#  - 403 if entity exists and you don't have sufficient privileges to modify
#  - 500 if package already exists
#
# An overview of the JSON structure is shown below:
#
# {
#   n:  "name",
#   s:  "summary",
#   sx: "description",
#   l:  "license",
#   u:  "url",
#   c:  "category",
#   t:  "type",
#   tx: [
#     "tag_1",
#     "tag_2",
#     ...
#   ],
#   d: [
#     {
#       e:  "epoch",
#       v:  "version",
#       r:  "revision",
#       a:  "arch",
#       is: "install_size",
#       ps: "package_size",
#       bt: "build_time",
#       ft: "file_time",
#       ri: repo_id,
#     },
#     ...
#   ]
# }
#
sub packages_post {
  my $self = shift;
  my $json = Mojo::JSON->new;
  my $data = $json->decode( $self->req->body );

  # TODO: only super admins and package admins can create packages

  # attempt to find existing package
  my ($p) = Canvas::Store::Package->search({
    name       => $data->{n},
  });

  # general package information exists
  # check if we're submitting a detailed package structure
  if( defined($p) ) {
    unless( defined($data->{d}) ) {
      return $self->render(
        status  => 500,
        text    => 'General package information already exists.',
        json    => { error => 'General package already exists.' },
      );
    }
  }
  # otherwise create the package
  else {
    $p = Canvas::Store::Package->insert({
      name        => $data->{n},
      summary     => $data->{s},
      description => $data->{sx},
      license     => $data->{l},
      url         => $data->{u},
      category    => $data->{c},
      type        => $data->{t},
      tags        => $data->{tx},
    });
  }

  # cache the arch to reduce DB hits
  my $arch_cache = {};

  for my $d ( @{ $data->{d} } ) {
    # cache arch lookups since there are very few
    unless( defined($arch_cache->{$d->{a}}) ) {
      $arch_cache->{$d->{a}} = Canvas::Store::Arch->find_or_create({ name => $d->{a} });
    }

    # attempt to find existing package details
    my( $pd ) = Canvas::Store::PackageDetails->search({
      package_id    => $p->id,
      epoch         => $d->{e},
      version       => $d->{v},
      rel           => $d->{r},
      arch_id       => $arch_cache->{ $d->{a} }->id,
      repo_id       => $d->{ri},
    });

    # details don't exist so add
    unless( defined( $pd ) ) {
      # create the package details
      my $pd = Canvas::Store::PackageDetails->insert({
        package_id    => $p->id,
        epoch         => $d->{e},
        version       => $d->{v},
        rel           => $d->{r},
        arch_id       => $arch_cache->{ $d->{a} }->id,

        install_size  => $d->{is},
        package_size  => $d->{ps},
        build_time    => Time::Piece->new( $d->{bt} ),
        file_time     => Time::Piece->new( $d->{ft} ),

        repo_id       => $d->{ri},
      });

      $d->{id} = $pd->id;
    }
  }

  # update general id
  $data->{id} = $p->id;

  $self->render(
    status  => 200,
    json    => $data,
  );
}

#
# GET /packages/latest
#
# Returns all packages based on latest updated time
#
# Returns:
#  - 200 on success
#  - 403 if entity exists and you don't have sufficient privileges to modify
#  - 500 if template owner doesn't exist or is invalid
#
# An overview of the JSON structure is shown below:
#
# [
#   {
#     id: id,
#     n:  "name",
#     s:  "summary",
#     sx: "description",
#     l:  "license",
#     u:  "url"
#     c:  "category",
#     t:  "type",
#     tx: [
#       "tag_1",
#       "tag_2",
#       ...
#     ]
#   },
#   ...
# ]
#
sub packages_latest_get {
  my $self = shift;

  # construct search query as appropriate
  my $q = $self->build_query({
    name      => [ 'n', 'name' ],
    category  => [ 'c', 'category' ],
  });

  # build pager for packages
  my @packages = Canvas::Store::Package->search_latest();

  my $ret = [];

  foreach my $p ( @packages ) {
    push @$ret, {
      id  => $p->id+0,
      n   => $p->name,
      s   => $p->summary,
      sx  => $p->description,
      l   => $p->license,
      u   => $p->url,
      c   => $p->category,
      t   => $p->type,
      tx  => [ split /,/, $p->tags // '' ],
      cd  => $p->updated->epoch,
      ud  => $p->created->epoch,
    };
  }

  $self->render( json => $ret );
}

#
# GET /api/package/:id
#
# Returns the package identified by :id
#
# Expected body contents is JSON encoded structure defining the template
# repositories and packages to be added.
#
# Returns:
#  - 200 on success
#  - 403 if entity exists and you don't have sufficient privileges to modify
#  - 500 if template owner doesn't exist or is invalid
#
# An overview of the JSON structure is shown below:
#
# {
#   n:  "name",
#   s:  "summary",
#   sx: "description",
#   l:  "license",
#   u:  "url",
#   c:  "category",
#   t:  "type",
#   tx: [
#     "tag_1",
#     "tag_2",
#     ...
#   ],
#   d: [
#     {
#       e:  "epoch",
#       v:  "version",
#       r:  "release",
#       a:  "arch",
#       is: "install_size",
#       ps: "package_size",
#       bt: "build_time",
#       ft: "file_time",
#       ri: repo_id
#     },
#     ...
#   ]
# }
#
sub package_id_get {
  my $self = shift;
  my $id = $self->param('id');

  my $p = Canvas::Store::Package->retrieve($id);

  # check we actually received a valid template
  unless( defined($p) ) {
    return $self->render(
      status  => 404,
      text    => 'not found',
      json    => { error => 'not found' },
    );
  }

  my @template_packages = $p->template_packages;

  my $package = {
    id  => $p->id+0,
    n   => $p->name,
    s   => $p->summary,
    sx  => $p->description,
    u   => $p->url,
    c   => $p->category,
    t   => $p->type,
    tx  => [ split /,/, $p->tags // '' ],
    cx  => scalar @template_packages,
    cd  => $p->updated->epoch,
    ud  => $p->created->epoch,
    d   => [],
  };

  foreach my $d ( $p->package_details ) {
    push @{ $package->{d} }, {
      e   => $d->epoch,
      v   => $d->version,
      r   => $d->rel,
      a   => $d->arch_id->name,
      is  => $d->install_size,
      ps  => $d->package_size,
      bt  => $d->build_time->epoch,
      ft  => $d->file_time->epoch,
      ri  => $d->repo_id,
      cd  => $p->updated->epoch,
      ud  => $p->created->epoch,
    }
  }

  $self->render(
    status => 200,
    json => $package,
  );
}

sub package_id_put {
  my $self = shift;
  my $json = Mojo::JSON->new;
  my $data = $json->decode( $self->req->body );

  # TODO: only super admins and package admins can modify packages

}

sub package_id_del {
}

#
# USERS
#
sub users_get {
  my $self = shift;

  my $cu = $self->authenticated_user;

  my $ret = [];

  foreach my $a ( Canvas::Store::User->retrieve_all ) {
    # skip if private and not ( our user or membership to user )
    next unless( ( $a->id eq $cu->{u}->id ) || ( scalar $a->user_memberships( member_id => $cu->{u}->id ) ) );

    push @$ret, {
      id    => $a->id+0,
      name  => $a->name,
      uuid  => $a->uuid,
    };
  }

  $self->render( json => $ret );
}

sub user_id_get {
  my $self = shift;
  my $id = $self->param('id');

  my $cu = $self->authenticated_user;
  my $p = Canvas::Store::User->retrieve($id);

  # skip if private and not ( our user or membership to user )
  unless( ( $p->id eq $cu->{u}->id ) || ( scalar $p->user_memberships( member_id => $cu->{u}->id ) ) ) {
    return $self->render(
      status  => 403,
      text    => 'denied',
      json    => { error => 'denied' },
    );
  }

  # check we actually received a valid user
  unless( defined($p) ) {
   return $self->render(
      status  => 404,
      text    => 'not found',
      json    => { error => 'not found' },
    );
  }

  $self->render( json => {
    id    => $p->id+0,
    name  => $p->name,
    uuid  => $p->uuid,
  });
}


sub user_id_memberships {
  my $self = shift;
  my $id = $self->param('id');

  my $cu = $self->authenticated_user;
  my $p = Canvas::Store::User->retrieve($id);
  my @member = $p->user_memberships( member_id => $cu->{u}->id );

  # abort if private and not ( our user or membership to user )
  unless( ( $p->id eq $cu->{u}->id ) || ( scalar @member && ( $member[0]->is_owner_admin ) ) ) {
    return $self->render(
      status  => 403,
      text    => 'denied',
      json    => { error => 'denied' },
    );
  }

  my $ret = [];

  foreach my $m ( $p->user_memberships ) {
    push @$ret, {
      id    => $m->member_id->id+0,
      name  => $m->member_id->name,
      uuid  => $m->member_id->uuid,
    };
  }

  $self->render( json => $ret );
}

#
# REPOSITORIES
#

#
# GET /repositories
#
# Returns all available repositories
#
# Returns:
#  - 200 on success
#
# An overview of the JSON structure is shown below:
#
# [
#   {
#     s: "stub",
#     n: "name",
#     gk: "gpg key",
#   },
#   ...
# ]
#
sub repositories_get {
  my $self = shift;

  # construct search query as appropriate
  my $q = $self->build_query({
    stub      => [ 's', 'n', 'name' ],
  });

  # build pager for packages
  my $pager = Canvas::Store::Repository->pager(
    entries_per_page  => $self->param('epp')  // 100,
    current_page      => $self->param('cp')   // 0,
  );

  my @repos = $pager->search_where( $q );

  my $ret = [];

  foreach my $r ( @repos ) {
    push @$ret, {
      id  => $r->id+0,
      s   => $r->stub,
      gk  => $r->gpg_key,
    };
  }

  $self->render( json => $ret );
};

#
# POST /repositories
#
# Add a new repository
#
# Expected body contents is JSON encoded structure defining the package to be
# added.
#
# Returns:
#  - 200 on success
#  - 403 if entity exists and you don't have sufficient privileges to modify
#  - 500 if package already exists
#
# An overview of the JSON structure is shown below:
#
# {
#   s: "stub",
#   n: "name",
#   gk: "gpg key",
#   u: "url"
# }
#
sub repositories_post {
  my $self = shift;
  my $json = Mojo::JSON->new;
  my $data = $json->decode( $self->req->body );

  # TODO: only super admins and package admins can create repositories

  # attempt to find existing general package
  my( $r ) = Canvas::Store::Repository->search({
    stub       => $data->{s},
  });

  # general repository information exists
  # check if we're submitting a detailed repository structure
  if( defined($r) ) {
    unless( defined($data->{d}) ) {
      return $self->render(
        status  => 500,
        text    => 'General repository information already exists.',
        json    => { error => 'General repository already exists.' },
      );
    }
  }
  # otherwise create the repository
  else {
    $r = Canvas::Store::Repository->insert({
      stub        => $data->{s},
      gpg_key     => $data->{gk},
    });
  }

  my $arch_cache = {};

  for my $d ( @{ $data->{d} } ) {
    # attempt to find existing general package
    my( $rd ) = Canvas::Store::RepositoryDetails->search({
      base_url => $data->{u},
    });

    # details don't exist so add
    unless( defined( $rd ) ) {
      # cache arch lookups since there are very few
      unless( defined($arch_cache->{$d->{a}}) ) {
        $arch_cache->{ $d->{a} } = Canvas::Store::Arch->find_or_create({ name => $d->{a} });
      }

      # create the package details
      $rd = Canvas::Store::RepositoryDetails->insert({
        repo_id     => $r->id,
        name        => $d->{n},
        arch_id     => $arch_cache->{ $d->{a} }->id,
        version     => $d->{v},
        base_url    => $d->{u},
      });

      # save the repository id for later
      $d->{id} = $rd->id;
    }
  }

  # update general id
  $data->{id} = $r->id;

  # return an updated version of the posted object
  $self->render(
    status  => 200,
    json    => $data,
  );
}

#
# GET /api/repository/:id
#
# Returns the repository identified by :id
#
# Returns:
#  - 200 on success
#  - 404 if repository does not exist
#
# An overview of the JSON structure is shown below:
#
# {
#   id: id,
#   s: "stub",
#   gk: "gpg key",
#   d: [
#     {
#       id: id,
#       n: "name",
#       a: "arch",
#       v: version,
#       u: "url",
#     },
#     ...
#   ]
# }
#
sub repository_id_get {
  my $self = shift;
  my $id = $self->param('id');

  my $r = Canvas::Store::Repository->retrieve($id);

  # check we actually received a valid profile
  unless( defined($r) ) {
    return $self->render(
      status  => 404,
      text    => 'not found',
      json    => { error => 'not found' },
    );
  }

  # build general repository information
  my $repo = {
    id  => $r->id+0,
    s   => $r->stub,
    gk  => $r->gpg_key,
    d   => [],
  };

  # construct search query as appropriate
  my $q = {
    repo_id => $r->id,
  };

  if( defined( $self->param( 'a' ) ) ) {
    my ($arch) = Canvas::Store::Arch->search( { name => $self->param( 'a' ) } );
    $q->{arch_id} = $arch->id if defined( $arch );
  }
  $q->{version} = $self->param('v') if defined( $self->param( 'v' ) );
  $q->{base_url} = $self->param('u') if defined( $self->param( 'u' ) );

  # search using our constructed query
  my @repos = Canvas::Store::RepositoryDetails->search( $q );

  # fill out details as required
  foreach my $d ( @repos ) {
    push @{ $repo->{d} }, {
      id  => $d->id+0,
      n   => $d->name,
      a   => $d->arch_id->name,
      v   => $d->version,
      u   => $d->base_url,
    };
  }

  $self->render(
    status => 200,
    json => $repo,
  );
}


#
# TEMPLATES
#

#
# GET /api/templates
#
#
#
sub templates_get {
  my $self = shift;

  # construct search query as appropriate
  my $q = {};

  my $q_name = $self->param('name');
  my $q_user = $self->param('user');

  $q->{name}    = $q_name     if defined($q_name);

  my @templates;
  if( keys %$q ) {
    @templates = Canvas::Store::Template->search( $q );
  }
  else {
    @templates = Canvas::Store::Template->retrieve_all();
  }

  # get auth'd user
  my $cu = $self->authenticated_user;

  # configure default return
  my $ret = [];

  foreach my $t ( @templates ) {
    # skip if private and not ( our user or membership to user )
    next if( $t->private && ! ( ( $t->user_id eq $cu->{u}->id ) || ( scalar $t->user_id->user_memberships( member_id => $cu->{u}->id ) ) ) );
    next if( defined( $q_user ) && ( $t->user_id->name ne $q_user) );

    # add to available
    push @$ret, {
      id          => $t->id+0,
      name        => $t->name,
      owner       => $t->user_id->name,
      description => $t->description,
    };
  }

  $self->render(
    status  => 200,
    json    => $ret,
  );
};

#
# POST /api/templates
#
# Add a new template
#
# Expected body contents is JSON encoded structure defining the template
# repositories and packages to be added.
#
# Returns:
#  - 200 on success
#  - 403 if entity exists and you don't have sufficient privileges to modify
#  - 500 if template owner doesn't exist or is invalid
#
# An overview of the JSON structure is shown below:
#
# {
#   u: "user / organisation",
#   n: "name",
#   r: [
#     ... array of repo objects to add ...,
#     {
#       n:  "name",
#       id: "short name",
#       bu: "base url",
#       ml: "mirror list url",
#       c:  "cost",
#       e:  "enabled",
#       gc: "gpg check",
#       gk: "gpg key"
#     },
#     ...
#   ],
#   p: [
#     ... array of package objects to add ...,
#     {
#       n: "name",
#       e: "epoch",
#       v: "version",
#       r: "release",
#       a: "arch",
#       p: "action"
#     },
#     ...
#   ]
# }
#
sub templates_post {
  my $self = shift;
  my $json = Mojo::JSON->new;
  my $data = $json->decode( $self->req->body );

  # find the user requested
  my( $u ) = Canvas::Store::User->search({
    name => $data->{u},
  });

  # bail if the user doesn't exist
  unless( defined($u) ) {
    return $self->render(
      status  => 500,
      text    => 'No user with that user.',
      json    => { error => 'No user with that user.' },
    );
  }

  my $cu = $self->authenticated_user;
  my @membership = $u->user_memberships( member_id => $cu->{u}->id );

  # validate the current user has access to write on this user
  unless( ( $data->{u} eq $cu->{u}->name ) ||
          ( scalar @membership && $membership[0]->can_create ) ) {

    return $self->render(
      status  => 403,
      text    => 'Not your user buddy.',
      json    => { error => 'Not your user buddy.' },
    );
  }

  # find or create new template
  my( $t ) = Canvas::Store::Template->search({
    user_id => $u->id+0,
    name       => $data->{n},
  });

  # template already exists
  if( defined($t) ) {
    return $self->render(
      status  => 500,
      text    => 'Template already exists with that name for this user.',
      json    => { error => 'Template already exists with that name for this user.' },
    );
  }

  # create the template
  $t = Canvas::Store::Template->insert({
    user_id => $u->id+0,
    name       => $data->{n},
  });

  Canvas::Store->do_transaction( sub {
    # get all archs to cache
    my $arch_cache = {};

    # store repositories
    foreach my $r ( @{ $data->{r} } ) {
      # calculate the base url
      my $bu = $r->{ml} // '';
      if( $bu eq '' ) {
        $bu = $r->{bu}[0] // '';
      }

      my $pu = $r->{bu}[0] // '';

      my $pr = Canvas::Store::Repository->find_or_create({
        name      => $r->{n},
        stub      => $r->{id},
        base_url  => $bu,
        gpg_key   => $r->{gk}[0] // '',
      });

      $t->add_to_template_repositories({
        repo_id     => $pr->id,
        pref_url    => $pu,
        enabled     => $r->{e},
        cost        => $r->{c}+0,
        gpg_check   => $r->{gc},
      });
    }

    # store pacakges
    foreach my $p ( @{ $data->{p} } ) {
      my $pp = Canvas::Store::Package->find_or_create({ name => $p->{n} });

      # cache arch lookups since there are very few
      unless( defined($arch_cache->{$p->{a}}) ) {
        $arch_cache->{$p->{a}} = Canvas::Store::Arch->find_or_create({ name => $p->{a} });
      }

      my $pa = $arch_cache->{$p->{a}};

      $t->add_to_template_packages({
        package_id  => $pp->id+0,
        arch_id     => $pa->id+0,
        epoch       => $p->{e},
        version     => $p->{v},
        rel         => $p->{r},
        action      => $p->{p}
      });
    }

  });

  $self->render(
    status  => 200,
    text    => 'id: ' . $t->id,
    json    => { id => $t->id },
  );
};


#
# GET /api/template/:id
#
# Returns the template identified by :id
#
# Returned body contents is an JSON encoded structure defining the template
# repositories and packages contained within.
#
# Returns:
#  - 200 on success
#  - 403 if entity exists and you don't have sufficient privileges to modify
#  - 404 if template doesn't exist
#  - 500 if template owner doesn't exist or is invalid
#
# An overview of the JSON structure is shown below:
#
# {
#   u: "user / organisation",
#   n: "name",
#   r: [
#     ... array of repo objects to add ...,
#     {
#       n:  "name",
#       id: "short name",
#       bu: "base url",
#       ml: "mirror list url",
#       c:  "cost",
#       e:  "enabled",
#       gc: "gpg check",
#       gk: "gpg key"
#     },
#     ...
#   ],
#   p: [
#     ... array of package objects to add ...,
#     {
#       n: "name",
#       e: "epoch",
#       v: "version",
#       r: "release",
#       a: "arch",
#       p: "action"
#     },
#     ...
#   ]
# }
#
sub template_id_get {
  my $self = shift;
  my $id = $self->param('id');
  my $cu = $self->authenticated_user;
  my $t = Canvas::Store::Template->retrieve($id);

  # check we actually received a valid template
  unless( defined($t) ) {
    return $self->render(
      status  => 404,
      json    => { error => 'not found' },
    );
  }

  # skip if private and not ( our user or membership to user )
  if( $t->private && ! ( ( $t->user_id eq $cu->{u}->id ) || ( scalar $t->user_id->user_memberships( member_id => $cu->{u}->id ) ) ) ) {
    return $self->render(
      status  => 403,
      text    => 'denied',
      json    => { error => 'denied' },
    );
  }

  # populate repository array
  my $r = [];
  foreach my $_r ( $t->template_repositories ) {
    push @$r, {
      n   => $_r->repo_id->name,
      v   => $_r->version,
      c   => $_r->cost+0,
      e   => $_r->enabled eq 1 ? Mojo::JSON->true : Mojo::JSON->false,
      gc  => $_r->gpg_check,
    }
  }

  # populate package array
  my $p = [];
  foreach my $_p ( $t->template_packages ) {
    push @$p, {
      n => $_p->package_id->name,
      e => $_p->epoch,
      v => $_p->version,
      r => $_p->rel,
      a => $_p->arch_id->name,
      p => $_p->action,
    }
  }

  $self->render( json => {
    id          => $t->id+0,
    name        => $t->name,
    description => $t->description,
    r           => $r,
    p           => $p,
  });
}


#
# PUT /api/template/:id
#
# Update existing template
#
# Expected body contents is JSON encoded structure defining the template
# repositories and packages to be added (or removed).
#
# Returns:
#  - 200 on success
#  - 403 if entity exists and you don't have sufficient privileges to modify
#  - 500 if template owner doesn't exist or is invalid
#
# An overview of the JSON structure is shown below:
#
# {
#   u: "user / organisation",
#   n: "name",
#   r: [
#     ... array of repo objects to add ...,
#     {
#       n:  "name",
#       id: "short name",
#       bu: "base url",
#       ml: "mirror list url",
#       c:  "cost",
#       e:  "enabled",
#       gc: "gpg check",
#       gk: "gpg key"
#     },
#     ...
#   ],
#   dr: [
#     ... array of repo ids to remove ...,
#     "repo_id_1",
#     "repo_id_2",
#     ...
#   ],
#   p: [
#     ... array of package objects to add ...,
#     {
#       n: "name",
#       e: "epoch",
#       v: "version",
#       r: "release",
#       a: "arch",
#       p: "action"
#     },
#     ...
#   ],
#   dp: [
#     ... array of package names to remove ...,
#     "package_name_1",
#     "package_name_2",
#     ...
#   ]
# }
#
sub template_id_put {
  my $self = shift;
  my $json = Mojo::JSON->new;

  my $id = $self->param('id');
  my $data = $json->decode( $self->req->body );

  my $cu = $self->authenticated_user;
  my $t = Canvas::Store::Template->retrieve($id);

  # check we actually received a valid template
  unless( defined($t) ) {
    return $self->render(
      status  => 404,
      json    => { error => 'not found' },
    );
  }

  # skip if private and not ( our user or membership to user )
  if( $t->private && ! ( ( $t->user_id eq $cu->{u}->id ) || ( scalar $t->user_id->user_memberships( member_id => $cu->{u}->id ) ) ) ) {
    return $self->render(
      status  => 403,
      text    => 'denied',
      json    => { error => 'denied' },
    );
  }

  Canvas::Store->do_transaction( sub {
    # get all archs to cache
    my $arch_cache = {};

    # add/update repositories
    foreach my $r ( @{ $data->{r} } ) {
      # calculate the base url
      my $bu = $r->{ml} // '';
      if( $bu eq '' ) {
        $bu = $r->{bu}[0] // '';
      }

      my $pu = $r->{bu}[0] // '';

      my $rr = Canvas::Store::Repository->find_or_create({
        name      => $r->{n},
        stub      => $r->{id},
        base_url  => $bu,
        gpg_key   => $r->{gk}[0] // '',
      });

      my @tr = $t->template_repositories({
        repo_id => $rr->id,
        template_id => $t->id,
      });

      # already exists, so update
      if( scalar @tr ) {
        $tr[0]->set({
          pref_url    => $pu,
          enabled     => $r->{e},
          cost        => $r->{c}+0,
          gpg_check   => $r->{gc},
        });

        $tr[0]->udpate;
      }
      # otherwise we must add
      else {
        $t->add_to_template_repositories({
          repo_id     => $rr->id,
          pref_url    => $pu,
          enabled     => $r->{e},
          cost        => $r->{c}+0,
          gpg_check   => $r->{gc},
        });
      }
    }

    # remove repositories
    foreach my $r ( @{ $data->{dr} } ) {
      my @rr = Canvas::Store::Repository->search({
        stub => $r->{id},
      });

      if( scalar @rr ) {
        my @dr = $t->template_repositories({
          repo_id => $rr[0]->id,
          template_id => $t->id,
        });

        foreach my $drr ( @dr ) {
          $drr->delete;
        }
      }
    }

    # add/update packages
    foreach my $p ( @{ $data->{p} } ) {
      my $pp = Canvas::Store::Package->find_or_create({ name => $p->{n} });

      # cache arch lookups since there are very few
      unless( defined($arch_cache->{$p->{a}}) ) {
        $arch_cache->{$p->{a}} = Canvas::Store::Arch->find_or_create({ name => $p->{a} });
      }
      my $pa = $arch_cache->{$p->{a}};

      my @tp = $t->template_packages({
        package_id => $pp->id,
        template_id => $t->id,
      });

      # already exists, so update
      if( scalar @tp ) {
        $tp[0]->set({
          arch_id     => $pa->id+0,
          epoch       => $p->{e},
          version     => $p->{v},
          rel         => $p->{r},
          action      => $p->{p}
        });

        $tp[0]->udpate;
      }
      # otherwise we must add
      else {
        $t->add_to_template_packages({
          package_id  => $pp->id+0,
          arch_id     => $pa->id+0,
          epoch       => $p->{e},
          version     => $p->{v},
          rel         => $p->{r},
          action      => $p->{p}
        });
      }
    }

    # remove packages
    foreach my $p ( @{ $data->{dp} } ) {
      my @pp = Canvas::Store::Package->search({ name => $p->{n} });

      if( scalar @pp ) {
        my @dp = $t->template_repositories({
          package_id => $pp[0]->id,
          template_id => $t,
        });
        foreach my $dpp ( @dp ) {
          $dpp->delete;
        }
      }
    }
  });

  $self->render(
    status  => 200,
    text    => 'id: ' . $t->id,
    json    => { id => $t->id },
  );
}

#
# DELETE /api/template/:id
#
# Delete template identified by :id
#
# Returns:
#  - 200 on success
#  - 403 if entity exists and you don't have sufficient privileges to modify
#  - 404 if template doesn't exist
#
sub template_id_del {
  my $self = shift;
  my $json = Mojo::JSON->new;

  my $id = $self->param('id');

  my $cu = $self->authenticated_user;
  my $t = Canvas::Store::Template->retrieve($id);

  # check we actually received a valid template
  unless( defined($t) ) {
    return $self->render(
      status  => 404,
      text    => 'not found',
      json    => { error => 'not found' },
    );
  }

  # skip if private and not ( our user or membership to user )
  if( $t->private && ! ( ( $t->user_id eq $cu->{u}->id ) || ( scalar $t->user_id->user_memberships( member_id => $cu->{u}->id ) ) ) ) {
    return $self->render(
      status  => 403,
      text    => 'denied',
      json    => { error => 'denied' },
    );
  }

  Canvas::Store->do_transaction( sub {
    $t->delete;
  });

  $self->render(
    status  => 200,
    text    => 'ok',
    json    => { message => 'ok' },
  );
}

#
# USERS
#

#
# GET /api/user/:user/template/:name
#
# Get template for user ":user" identified by ":name"
#
# Alternative invocation of GET /api/template/:id
#
sub user_user_template_name_get {
  my $self = shift;
  my $user = $self->param('user');
  my $name = $self->param('name');

  my $cu = $self->authenticated_user;
  my $t = Canvas::Store::Template->search({
    name  => $name,
    owner => $user,
  });

  # TODO: reuse below from GET /api/template/:id

  # check we actually received a valid template
  unless( defined($t) ) {
    return $self->render(
      status  => 404,
      json    => { error => 'not found' },
    );
  }

  # skip if private and not ( our user or membership to user )
  if( $t->private && ! ( ( $t->user_id eq $cu->{u}->id ) || ( scalar $t->user_id->user_memberships( member_id => $cu->{u}->id ) ) ) ) {
    return $self->render(
      status  => 403,
      text    => 'denied',
      json    => { error => 'denied' },
    );
  }

  # populate repository array
  my $r = [];
  foreach my $_r ( $t->template_repositories ) {
    push @$r, {
      n   => $_r->repo_id->name,
      v   => $_r->version,
      c   => $_r->cost+0,
      e   => $_r->enabled eq 1 ? Mojo::JSON->true : Mojo::JSON->false,
      gc  => $_r->gpg_check,
    }
  }

  # populate package array
  my $p = [];
  foreach my $_p ( $t->template_packages ) {
    push @$p, {
      n => $_p->package_id->name,
      e => $_p->epoch,
      v => $_p->version,
      r => $_p->rel,
      a => $_p->arch_id->name,
      p => $_p->action,
    }
  }

  $self->render( json => {
    id          => $t->id+0,
    name        => $t->name,
    description => $t->description,
    r           => $r,
    p           => $p,
  });
}

#
# PUT /api/user/:user/template/:name
#
# Update existing template for user ":user" identified by ":name"
#
# Alternative invocation of PUT /api/template/:id
#
sub user_user_template_name_put {
  my $self = shift;
  my $json = Mojo::JSON->new;

  my $user = $self->param('user');
  my $name = $self->param('name');
  my $data = $json->decode( $self->req->body );

  my $cu = $self->authenticated_user;
  my $t = Canvas::Store::Template->search({
    name  => $name,
    owner => $user,
  });

  # TODO: reuse below from PUT /api/template/:id

  # check we actually received a valid template
  unless( defined($t) ) {
    return $self->render(
      status  => 404,
      json    => { error => 'not found' },
    );
  }

  # skip if private and not ( our user or membership to user )
  if( $t->private && ! ( ( $t->user_id eq $cu->{u}->id ) || ( scalar $t->user_id->user_memberships( member_id => $cu->{u}->id ) ) ) ) {
    return $self->render(
      status  => 403,
      text    => 'denied',
      json    => { error => 'denied' },
    );
  }

  Canvas::Store->do_transaction( sub {
    # get all archs to cache
    my $arch_cache = {};

    # add/update repositories
    foreach my $r ( @{ $data->{r} } ) {
      # calculate the base url
      my $bu = $r->{ml} // '';
      if( $bu eq '' ) {
        $bu = $r->{bu}[0] // '';
      }

      my $pu = $r->{bu}[0] // '';

      my $rr = Canvas::Store::Repository->find_or_create({
        name      => $r->{n},
        stub      => $r->{id},
        base_url  => $bu,
        gpg_key   => $r->{gk}[0] // '',
      });

      my @tr = $t->template_repositories({
        repo_id => $rr->id,
        template_id => $t->id,
      });

      # already exists, so update
      if( scalar @tr ) {
        $tr[0]->set({
          pref_url    => $pu,
          enabled     => $r->{e},
          cost        => $r->{c}+0,
          gpg_check   => $r->{gc},
        });

        $tr[0]->udpate;
      }
      # otherwise we must add
      else {
        $t->add_to_template_repositories({
          repo_id     => $rr->id,
          pref_url    => $pu,
          enabled     => $r->{e},
          cost        => $r->{c}+0,
          gpg_check   => $r->{gc},
        });
      }
    }

    # remove repositories
    foreach my $r ( @{ $data->{dr} } ) {
      my @rr = Canvas::Store::Repository->search({
        stub => $r->{id},
      });

      if( scalar @rr ) {
        my @dr = $t->template_repositories({
          repo_id => $rr[0]->id,
          template_id => $t->id,
        });

        foreach my $drr ( @dr ) {
          $drr->delete;
        }
      }
    }

    # add/update packages
    foreach my $p ( @{ $data->{p} } ) {
      my $pp = Canvas::Store::Package->find_or_create({ name => $p->{n} });

      # cache arch lookups since there are very few
      unless( defined($arch_cache->{$p->{a}}) ) {
        $arch_cache->{$p->{a}} = Canvas::Store::Arch->find_or_create({ name => $p->{a} });
      }
      my $pa = $arch_cache->{$p->{a}};

      my @tp = $t->template_packages({
        package_id => $pp->id,
        template_id => $t->id,
      });

      # already exists, so update
      if( scalar @tp ) {
        $tp[0]->set({
          arch_id     => $pa->id+0,
          epoch       => $p->{e},
          version     => $p->{v},
          rel         => $p->{r},
          action      => $p->{p}
        });

        $tp[0]->udpate;
      }
      # otherwise we must add
      else {
        $t->add_to_template_packages({
          package_id  => $pp->id+0,
          arch_id     => $pa->id+0,
          epoch       => $p->{e},
          version     => $p->{v},
          rel         => $p->{r},
          action      => $p->{p}
        });
      }
    }

    # remove packages
    foreach my $p ( @{ $data->{dp} } ) {
      my @pp = Canvas::Store::Package->search({ name => $p->{n} });

      if( scalar @pp ) {
        my @dp = $t->template_repositories({
          package_id => $pp[0]->id,
          template_id => $t,
        });
        foreach my $dpp ( @dp ) {
          $dpp->delete;
        }
      }
    }
  });

  $self->render(
    status  => 200,
    text    => 'id: ' . $t->id,
    json    => { id => $t->id },
  );
}

#
# DELETE /api/user/:user/template/:name
#
# Delete template for user ":user" identified by ":name"
#
# Alternative invocation of DELETE /api/template/:id
#
sub user_user_template_name_del {
  my $self = shift;
  my $json = Mojo::JSON->new;

  my $user = $self->param('user');
  my $name = $self->param('name');

  my $cu = $self->authenticated_user;
  my $t = Canvas::Store::Template->search({
    name  => $name,
    owner => $user,
  });

  # TODO: reuse below from DEL /api/template/:id

  # check we actually received a valid template
  unless( defined($t) ) {
    return $self->render(
      status  => 404,
      text    => 'not found',
      json    => { error => 'not found' },
    );
  }

  # skip if private and not ( our user or membership to user )
  if( $t->private && ! ( ( $t->user_id eq $cu->{u}->id ) || ( scalar $t->user_id->user_memberships( member_id => $cu->{u}->id ) ) ) ) {
    return $self->render(
      status  => 403,
      text    => 'denied',
      json    => { error => 'denied' },
    );
  }

  Canvas::Store->do_transaction( sub {
    $t->delete;
  });

  $self->render(
    status  => 200,
    text    => 'ok',
    json    => { message => 'ok' },
  );
}

1;
