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
# PERL INCLUDES
#
use Time::Piece;

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


sub index {
  my $self = shift;

  $self->render('canvas/index');
}

sub exception_get {
  return shift->render_exception('render_only');
}

sub not_found_get {
  return shift->render_not_found;
}

sub authenticate_any {
  my $self = shift;
  my $json = Mojo::JSON->new;
  my $data = $json->decode($self->req->body);

  # collect first out of the parameters and then json decoded body
  my $user = $self->param('u') // $data->{u} // '';
  my $pass = $self->param('p') // $data->{p} // '';

  # extract the redirect url and fall back to the index
  my $url = $self->param('redirect_to') // $data->{redirect_to} // '/';

  unless( $self->authenticate($user, $pass) ) {
    $self->flash( page_errors => 'The username or password was incorrect. Perhaps your account has not been activated?' );

    return $self->render( status => 403, json => 'Not Authorised!' ) if $self->stash('format') eq 'json';
  }

  return $self->render( status => 200, json => 'Access Granted!' ) if $self->stash('format') eq 'json';

  return $self->redirect_to( $url );
};

sub deauthenticate_any {
  my $self = shift;

  $self->logout;

  return $self->render( status => 200, json => 'Done!' ) if $self->stash('format') eq 'json';

  # extract the redirect url and fall back to the index
  my $url = $self->param('redirect_to') // '/';

  return $self->redirect_to( $url );
};

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

  my $p = Canvas::Store::User->retrieve($id);
  my @member = $p->user_memberships( member_id => $self->auth_user->id );

  # abort if private and not ( our user or membership to user )
  unless( ( $p->id eq $self->auth_user->id ) || ( scalar @member && ( $member[0]->is_owner_admin ) ) ) {
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
# TEMPLATES
#

#
# GET /api/templates
#
# Returns all available templates
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
  my $cu = $self->auth_user;

  # configure default return
  my $ret = [];

  foreach my $t ( @templates ) {
    # skip if private and not ( our user or membership to user )
    next if( $t->private && ! ( ( $t->user_id eq $cu->id ) || ( scalar $t->user_id->user_memberships( member_id => $cu->id ) ) ) );
    next if( defined( $q_user ) && ( $t->user_id->username ne $q_user) );

    # add to available
    push @$ret, {
      id          => $t->id+0,
      name        => $t->name,
      owner       => $t->user_id->username,
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

  unless( $self->is_user_authenticated ) {
    return $self->render(
      status  => 403,
      text    => 'Not authenticated.',
      json    => { error => 'Not authenticated.' },
    );
  };

  my $json = Mojo::JSON->new;
  my $data = $json->decode( $self->req->body );

  # find the user requested
  my $u = Canvas::Store::User->search({ username => $data->{u} })->first;

  # bail if the user doesn't exist
  unless( defined($u) ) {
    say "NO USER";
    return $self->render(
      status  => 500,
      text    => 'No user with that user.',
      json    => { error => 'No user with that user.' },
    );
  }

  my $cu = $self->auth_user;
  my @membership = $u->user_memberships( member_id => $cu->id );

  # validate the current user has access to write on this user
  unless( ( $data->{u} eq $cu->username ) ||
          ( scalar @membership && $membership[0]->can_create ) ) {

    return $self->render(
      status  => 403,
      text    => 'Not your user buddy.',
      json    => { error => 'Not your user buddy.' },
    );
  }

  # find or create new template
  my $t = Canvas::Store::Template->search({
    user_id => $u->id+0,
    name    => $data->{n},
  })->first;

  # template already exists
  if( defined($t) ) {
    say "EXISTS";
    return $self->render(
      status  => 500,
      text    => 'Template already exists with that name for this user.',
      json    => { error => 'Template already exists with that name for this user.' },
    );
  }

  my $now = gmtime;

  Canvas::Store->do_transaction( sub {

    # generate sanitised unique stub based on defined stub or template name
    my $stub = $self->sanitise_with_dashes( $data->{s} // $data->{n} );
    my( @te ) = Canvas::Store::Template->search( { user_id => $u->id, stub => $stub } );
    $stub .= '-' . ( $te[-1]->id + 1 ) if @te;

    # create the template
    $t = Canvas::Store::Template->insert({
      user_id => $u->id+0,
      name    => $data->{n},
      stub    => $stub,
      created => $now,
      updated => $now,
    });

    # store repositories
    foreach my $r ( @{ $data->{r} } ) {
      # calculate the base url
      Canvas::Store::TemplateRepository->insert({
        template_id => $t->id,
        name        => $r->{n},
        stub        => $r->{s},
        baseurl     => join( ',', @{ $r->{bu} // [] } ),
        mirrorlist  => $r->{ml} // '',
        metalink    => $r->{ma} // '',
        gpg_key     => $r->{gk}[0] // '',
        enabled     => $r->{e},
        exclude     => join( ',', @{ $r->{x} // [] } ),
        cost        => $r->{c}+0,
        gpg_check   => $r->{gc},
        created     => $now,
        updated     => $now,
      });
    }

    # store pacakges
    foreach my $p ( @{ $data->{p} } ) {
      Canvas::Store::TemplatePackage->insert({
        template_id => $t->id,
        name        => $p->{n},
        arch        => $p->{a},
        epoch       => $p->{e},
        version     => $p->{v},
        rel         => $p->{r},
        action      => $p->{z},
        created     => $now,
        updated     => $now,
      });
    }
  });

  unless( defined($t) ) {
    return $self->render(
      status  => 500,
      text    => 'Unable to create template.',
      json    => { error => 'Unable to create template.' }
    );
  }

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
  my $t = Canvas::Store::Template->retrieve($id);

  # check we actually received a valid template
  unless( defined($t) ) {
    return $self->render(
      status  => 404,
      json    => { error => 'not found' },
    );
  }

  # skip if private and not ( our user or membership to user )
  if( $t->private && ! ( ( $t->user_id eq $self->auth_user->id ) || ( scalar $t->user_id->user_memberships( member_id => $self->auth_user->id ) ) ) ) {
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
      n   => $_r->name,
      s   => $_r->stub,
      bu  => split( /,/, $_r->baseurl ),
      ml  => split( /,/, $_r->mirrorlist ),
      ma  => split( /,/, $_r->metalink ),
      v   => $_r->version,
      c   => $_r->cost+0,
      e   => $_r->enabled eq 1 ? Mojo::JSON->true : Mojo::JSON->false,
      x   => $_r->exclude,
      gc  => $_r->gpg_check,
    }
  }

  # populate package array
  my $p = [];
  foreach my $_p ( $t->template_packages ) {
    push @$p, {
      n => $_p->name,
      e => $_p->epoch,
      v => $_p->version,
      r => $_p->rel,
      a => $_p->arch,
      z => $_p->action,
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

  my $t = Canvas::Store::Template->retrieve($id);

  # check we actually received a valid template
  unless( defined($t) ) {
    return $self->render(
      status  => 404,
      json    => { error => 'not found' },
    );
  }

  # skip if private and not ( our user or membership to user )
  if( $t->private && ! ( ( $t->user_id eq $self->auth_user->id ) || ( scalar $t->user_id->user_memberships( member_id => $self->auth_user->id ) ) ) ) {
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
  if( $t->private && ! ( ( $t->user_id eq $self->auth_user->id ) || ( scalar $t->user_id->user_memberships( member_id => $self->auth_user->id ) ) ) ) {
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
