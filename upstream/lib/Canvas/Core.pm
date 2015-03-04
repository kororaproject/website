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
use Mango;
use Mojo::Util qw(dumper);


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
  return shift->reply->exception('render_only');
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

  my $format = $self->stash('format') // '';

  # extract the redirect url and fall back to the index
  my $url = $self->param('redirect_to') // $data->{redirect_to} // '/';

  unless( $self->authenticate($user, $pass) ) {
    $self->flash( page_errors => 'The username or password was incorrect. Perhaps your account has not been activated?' );

    return $self->render( status => 403, json => 'Not Authorised!' ) if $format eq 'json';
  }
  else {
    unless( $self->auth_user->metadata('is_canvas_member') ) {
      $self->logout;

      $self->flash( page_errors => 'You are not a member of the Canvas alpha test team. Stay tuned for future announcments.' );

      return $self->render( status => 403, json => 'Not Authorised!' ) if $format eq 'json';
    }

    return $self->render( status => 200, json => 'Access Granted!' ) if $format eq 'json';
  }

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

  my $mango = Mango->new('mongodb://localhost:27017');
  my $collection = $mango->db('canvas')->collection('templates');

  # find or create new template
  my $tc = $collection->find( $q, {
    name => 1,
    user => 1,
  })->all;

  # get auth'd user
  my $cu = $self->auth_user;

  # configure default return
  my $ret = [];

  foreach my $t ( @{ $tc } ) {
    # skip unless sharable ( our user or membership to user )
    # next unless $t->isSharable( $cu->id );

    #next if( defined( $q_user ) && ( $t->user_id->username ne $q_user) );

    # add to available
    push @$ret, {
      id          => $t->{_id}->to_string,
      name        => $t->{name},
      user        => $t->{user},
      description => $t->{description} // '',
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
  my $u = Canvas::Store::User->search({ username => $data->{user} })->first;

  # bail if the user doesn't exist
  unless( defined($u) ) {
    say "NO USER";
    return $self->render(
      status  => 500,
      text    => 'No user with that name.',
      json    => { error => 'No user with that user.' },
    );
  }

  my $cu = $self->auth_user;
  my @membership = $u->user_memberships( member_id => $cu->id );

  # validate the current user has access to write on this user
  unless( ( $data->{user} eq $cu->username ) ||
          ( scalar @membership && $membership[0]->can_create ) ) {

    return $self->render(
      status  => 403,
      text    => 'Not your user buddy.',
      json    => { error => 'Not your user buddy.' },
    );
  }

  my $mango = Mango->new('mongodb://localhost:27017');
  my $collection = $mango->db('canvas')->collection('templates');

  # generate sanitised unique stub based on template name
  $data->{stub} = $self->sanitise_with_dashes( $data->{name} );

  # check if template already exists
  my $t = $collection->find_one({
    user => $u->username,
    stub => $data->{stub}
  });

  if( defined($t) ) {
    say "EXISTS";
    return $self->render(
      status  => 500,
      text    => 'Template already exists with that name for this user.',
      json    => { error => 'Template already exists with that name for this user.' },
    );
  }

  # insert document
  my $oid   = $mango->db('canvas')->collection('templates')->insert( $data );

  $self->render(
    status  => 200,
    text    => 'id: ' . $oid,
    json    => { id => $oid },
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

  my $mango = Mango->new('mongodb://localhost:27017');
  my $collection = $mango->db('canvas')->collection('templates');

  # find or create new template
  my $t = $collection->find_one({
    oid => $id
  });

  # check we actually received a valid template
  unless( defined($t) ) {
    return $self->render(
      status  => 404,
      json    => { error => 'not found' },
    );
  }

  # skip if private and not ( our user or membership to user )
#  if( $t->private && ! ( ( $t->user_id eq $self->auth_user->id ) || ( scalar $t->user_id->user_memberships( member_id => $self->auth_user->id ) ) ) ) {
#    return $self->render(
#      status  => 403,
#      text    => 'denied',
#      json    => { error => 'denied' },
#    );
#  }

  $self->render( json => {
    id          => $t->{_id}->to_string,
    name        => $t->{name},
    user        => $t->{user},
    repos       => $t->{repos}        // [],
    packages    => $t->{packages}     // [],
    description => $t->{description}  // '',
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
#   user: "user / organisation",
#   name: "name",
#   repos: [
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
#   packages: [
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

  my $mango = Mango->new('mongodb://localhost:27017');
  my $collection = $mango->db('canvas')->collection('templates');

  # find template
  my $t = $collection->find_one( { oid => $id } );

  # check we actually received a valid template
  unless( defined($t) ) {
    return $self->render(
      status  => 404,
      json    => { error => 'not found' },
    );
  }

  # skip if private and not ( our user or membership to user )
#  if( $t->private && ! ( ( $t->user_id eq $self->auth_user->id ) || ( scalar $t->user_id->user_memberships( member_id => $self->auth_user->id ) ) ) ) {
#    return $self->render(
#      status  => 403,
#      text    => 'denied',
#      json    => { error => 'denied' },
#    );
#  }

  # add new repos and packages
  $collection->update( { _id => $t->{_id} }, { '$set' => $data } );

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

  my $mango = Mango->new('mongodb://localhost:27017');
  my $collection = $mango->db('canvas')->collection('templates');

  # find or create new template
  my $t = $collection->find_one({
    oid => $id
  });

  # check we actually received a valid template
  unless( defined($t) ) {
    return $self->render(
      status  => 404,
      text    => 'not found',
      json    => { error => 'not found' },
    );
  }

  # skip if private and not ( our user or membership to user )
  #if( $t->private && ! ( ( $t->user_id eq $self->auth_user->id ) || ( scalar $t->user_id->user_memberships( member_id => $self->auth_user->id ) ) ) ) {
  #  return $self->render(
  #    status  => 403,
  #    text    => 'denied',
  #    json    => { error => 'denied' },
  #  );
  #}

  $collection->remove( _id => $t->{_id} );

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

  my $mango = Mango->new('mongodb://localhost:27017');
  my $collection = $mango->db('canvas')->collection('templates');

  # find or create new template
  my $t = $collection->find_one({
    user => $user,
    stub => $name,
  });

  my $cu = $self->authenticated_user;
  # TODO: reuse below from GET /api/template/:id

  # check we actually received a valid template
  unless( defined($t) ) {
    return $self->render(
      status  => 404,
      json    => { error => 'not found' },
    );
  }

  # skip if private and not ( our user or membership to user )
  #if( $t->private && ! ( ( $t->user_id eq $cu->{u}->id ) || ( scalar $t->user_id->user_memberships( member_id => $cu->{u}->id ) ) ) ) {
  #  return $self->render(
  #    status  => 403,
  #    text    => 'denied',
  #    json    => { error => 'denied' },
  #  );
  #}

  $self->render( json => {
    id          => $t->{_id}->to_string,
    name        => $t->{name},
    user        => $t->{user},
    repos       => $t->{repos}        // [],
    packages    => $t->{packages}     // [],
    description => $t->{description}  // '',
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

  my $mango = Mango->new('mongodb://localhost:27017');
  my $collection = $mango->db('canvas')->collection('templates');

  # find template
  my $t = $collection->find_one( { user => $user, name => $name } );

  # check we actually received a valid template
  unless( defined($t) ) {
    return $self->render(
      status  => 404,
      json    => { error => 'not found' },
    );
  }

  # skip if private and not ( our user or membership to user )
#  if( $t->private && ! ( ( $t->user_id eq $self->auth_user->id ) || ( scalar $t->user_id->user_memberships( member_id => $self->auth_user->id ) ) ) ) {
#    return $self->render(
#      status  => 403,
#      text    => 'denied',
#      json    => { error => 'denied' },
#    );
#  }

  # add new repos and packages
  $collection->update( { _id => $t->{_id} }, { '$set' => $data } );

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

  my $mango = Mango->new('mongodb://localhost:27017');
  my $collection = $mango->db('canvas')->collection('templates');

  # find or create new template
  my $t = $collection->find_one({
    name => $name,
    user => $user,
  });

  # check we actually received a valid template
  unless( defined($t) ) {
    return $self->render(
      status  => 404,
      text    => 'not found',
      json    => { error => 'not found' },
    );
  }

  my $cu = $self->authenticated_user;

  # skip if private and not ( our user or membership to user )
#  if( $t->private && ! ( ( $t->user_id eq $cu->{u}->id ) || ( scalar $t->user_id->user_memberships( member_id => $cu->{u}->id ) ) ) ) {
#    return $self->render(
#      status  => 403,
#      text    => 'denied',
#      json    => { error => 'denied' },
#    );
#  }

  $collection->remove( _id => $t->{_id} );

  $self->render(
    status  => 200,
    text    => 'ok',
    json    => { message => 'ok' },
  );
}

1;
