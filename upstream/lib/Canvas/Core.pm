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
use Mojo::Util qw(dumper);
use Time::Piece;

#
# LOCAL INCLUDES
#

sub resolve_includes {
  my ($c, $template) = @_;

  my $includes = $template->{includes};

  if (@{$includes}) {
    $template->{includes} = [];

    for my $stub (@{$includes}) {
      my $t = $c->pg->db->query('SELECT t.id, t.name, t.description, t.stub, t.repos, t.packages, t.meta, u.username AS owner, EXTRACT(EPOCH FROM t.created) AS created, EXTRACT(EPOCH FROM t.updated) AS updated FROM templates t JOIN users u ON (u.id=t.owner_id) WHERE t.stub=?', $stub)->expand->hash;

      push @{$template->{includes}}, $t if $t;
    }
  }

  return $template;
}

sub index {
  my $c = shift;

  $c->render('canvas/index');
}

sub exception_get {
  return shift->reply->exception('render_only');
}

sub not_found_get {
  return shift->render_not_found;
}

sub oauth {
  my $c = shift;

  my $provider = $c->param('provider');
  my $data = $c->req->json // {};

  my $rt     = $c->flash('rt');
  my $rt_url = $rt ? $c->ub64_decode($rt) : '/';

  return $c->redirect_to($rt_url) unless grep {$_ eq $provider} qw(email github);

  $c->delay(
    sub {
      my $delay = shift;
      my $args = {redirect_uri => $c->url_for('oauth/github')->to_abs};

      $c->oauth2->get_token($provider => $args, $delay->begin);
    },
    sub {
      my ($delay, $err, $token, $data) = @_;

      # store token to session
      $c->session(oauth => $data);
      $c->flash(rt => $rt);

      # abort
      if ($err) {
        $c->flash(page_errors => 'OAuth provider error. ' . $err);
        return $c->redirect_to($rt_url);
      }

      # if auth'd then link oauth with existing account
      if ($c->users->is_active) {
        $c->users->oauth->link($provider, $data);
        return $c->redirect_to($rt_url);
      }
      # else attempt auth
      else {
        return $c->redirect_to($rt_url) if $c->authenticate(undef, undef, $data);
      }

      # otherwise proceed to registration / profile page
      return $c->redirect_to('activateprovider', provider => $provider);
    }
  );
}

sub authenticate_any {
  my $c = shift;
  my $data = $c->req->json;

  # collect first out of the parameters and then json decoded body
  my $user = $c->param('u') // $data->{u} // '';
  my $pass = $c->param('p') // $data->{p} // '';

  # extract the redirect url and fall back to the index
  my $url = $c->param('rt') // $data->{rt};
  $url = defined $url ? $c->ub64_decode($url) : '/';

  unless ($c->authenticate($user, $pass)) {
    $c->flash( page_errors => 'The username or password was incorrect. Perhaps your account has not been activated?' );
  }

  return $c->redirect_to($url);
};

sub deauthenticate_any {
  my $c = shift;

  my $format = $c->stash('format') // 'html';

  $c->logout;

  return $c->render(status => 200, json => 'Done!') if $format eq 'json';

  # extract the redirect url and fall back to the index
  my $url = $c->param('rt');
  $url = defined $url ? $c->ub64_decode($url) : '/';

  return $c->redirect_to($url);
};

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
sub templates_get {
  my $c = shift;

  # construct search query as appropriate
  my $q = {};

  my $user = $c->param('user');
  my $name = $c->param('name');

  my $templates = $c->pg->db->query('SELECT t.id, t.stub, t.description, t.name, t.owner_id, u.username FROM templates t JOIN users u ON (u.id=t.owner_id) WHERE (t.stub=$1 OR $1 IS NULL) AND (u.username=$2 OR $2 IS NULL)', $name, $user)->hashes;

  # get auth'd user
  my $cu = $c->auth_user // { id => -1 };

  # filter out private and non-owned templates
  $templates = $templates->grep(sub { !!($_->{meta}{public} // 0) || ($_->{owner_id} == $cu->{id}) });

  $c->render(
    status  => 200,
    json    => $templates->to_array,
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
sub templates_post {
  my $c = shift;

  unless ($c->users->is_active) {
    return $c->render(
      status  => 403,
      text    => 'Not authenticated.',
      json    => { error => 'Not authenticated.' },
    );
  };

  my $template = $c->req->json;

  # find the user requested
  my $u = $c->pg->db->query('SELECT * FROM users WHERE username=?', $template->{user})->hash;

  # bail if the user doesn't exist
  unless ($u) {
    return $c->render(
      status  => 500,
      text    => 'No user with that name.',
      json    => { error => 'No user with that user.' },
    );
  }

  # generate sanitised unique stub based on template name
  $template->{stub} = $c->sanitise_with_dashes($template->{name});

  # check if template already exists
  my $t = $c->pg->db->query('SELECT * FROM templates WHERE stub=?', $template->{stub})->hash;

  if ($t) {
    say "EXISTS";
    return $c->render(
      status  => 500,
      text    => 'Template already exists.',
      json    => { error => 'Template already exists.' },
    );
  }

  $template->{description} //= '';
  $template->{meta}        //= {};
  $template->{packages}    //= {};
  $template->{repos}       //= {};

  my $id = $c->pg->db->query('INSERT INTO templates (owner_id, name, stub, description, packages, repos, meta) VALUES (?,?,?,?,?,?,?) RETURNING ID', $u->{id}, $template->{name}, $template->{stub}, $template->{description}, {json => $template->{packages}}, {json => $template->{repos}}, {json => $template->{meta}})->array->[0];

  $c->render(
    status  => 200,
    text    => 'id: ' . $id,
    json    => { id => $id },
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
sub template_id_get {
  my $c = shift;
  my $id = $c->param('id');
  my $resolve = $c->param('resolve') // 1;

  my $template = $c->pg->db->query('SELECT t.id, t.name, t.description, t.stub, t.includes, t.repos, t.packages, t.meta, u.username AS owner, EXTRACT(EPOCH FROM t.created) AS created, EXTRACT(EPOCH FROM t.updated) AS updated FROM templates t JOIN users u ON (u.id=t.owner_id) WHERE t.id=?', $id)->expand->hash;

  # check we actually received a valid template
  unless ($template) {
    return $c->render(
      status  => 404,
      json    => { error => 'not found' },
    );
  }

  # get auth'd user
  my $cu = $c->auth_user // { id => -1 };

  # skip if private and not owned by us
  if (!$template->{meta}{public} && $template->{owner_id} != $cu->{id}) {
    return $c->render(
      status  => 403,
      text    => 'denied',
      json    => { error => 'denied' },
    );
  }

  if (!!$resolve) {
    $c->resolve_includes( $template );
  }

  $c->render(json => $template);
}

sub template_id_includes_get {
  my $c = shift;
  my $id = $c->param('id');
  my $resolve = 1; #$c->param('resolve') // 1;

  my $template = $c->pg->db->query('SELECT t.id, t.name, t.description, t.stub, t.includes, t.repos, t.packages, t.meta, t.owner_id, u.username AS owner, EXTRACT(EPOCH FROM t.created) AS created, EXTRACT(EPOCH FROM t.updated) AS updated FROM templates t JOIN users u ON (u.id=t.owner_id) WHERE t.id=?', $id)->expand->hash;

  # check we actually received a valid template
  unless ($template) {
    return $c->render(
      status  => 404,
      json    => { error => 'not found' },
    );
  }

  # get auth'd user
  my $cu = $c->auth_user // { id => -1 };

  # skip if private and not owned by us
  if (!$template->{meta}{public} && $template->{owner_id} != $cu->{id}) {
    return $c->render(
      status  => 403,
      text    => 'denied',
      json    => { error => 'denied' },
    );
  }

  $c->resolve_includes($template);

  $c->render(json => $template->{includes});
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
#  - 404 if template doesn't exist
#  - 500 if template owner doesn't exist or is invalid
#
sub template_id_update {
  my $c = shift;
  my $id = $c->param('id');

  my $template = $c->pg->db->query('SELECT t.id, t.name, t.description, t.stub, t.repos, t.packages, t.meta, t.owner_id, u.username AS owner, EXTRACT(EPOCH FROM t.created) AS created, EXTRACT(EPOCH FROM t.updated) AS updated FROM templates t JOIN users u ON (u.id=t.owner_id) WHERE t.id=?', $id)->expand->hash;

  # check we actually received a valid template
  unless ($template) {
    return $c->render(
      status  => 404,
      json    => { error => 'not found' },
    );
  }

  unless ($c->users->is_active) {
    return $c->render(
      status  => 403,
      text    => 'Not authenticated.',
      json    => { error => 'Not authenticated.' },
    );
  };

  my $updated = $c->req->json;

  # find the user requested
  my $u = $c->pg->db->query('SELECT * FROM users WHERE username=?', $updated->{user})->hash;

  # bail if the user doesn't exist
  unless ($u) {
    say "NO USER";
    return $c->render(
      status  => 500,
      text    => 'No user with that name.',
      json    => { error => 'No user with that user.' },
    );
  }

  # get auth'd user
  my $cu = $c->auth_user // { id => -1 };

  # skip if private and not owned by us
  if (!$template->{meta}{public} && $template->{owner_id} != $cu->{id}) {
    return $c->render(
      status  => 403,
      text    => 'denied',
      json    => { error => 'denied' },
    );
  }

  # generate sanitised unique stub based on template name
  $updated->{stub} = $c->sanitise_with_dashes($updated->{name});

  # check if template already exists
  my $t = $c->pg->db->query('SELECT * FROM templates WHERE stub=?', $updated->{stub})->hash;

  if ($t && ($t->{id} ne $template->{id})) {
    say "EXISTS";
    return $c->render(
      status  => 500,
      text    => 'Template already exists.',
      json    => { error => 'Template already exists.' },
    );
  }

  #$updated->{includes} = ['korora-core'];

  $c->pg->db->query('UPDATE templates SET name=?, stub=?, description=?, packages=?, repos=?, includes=?, meta=? WHERE id=?', $updated->{name}, $updated->{stub}, $updated->{description}, {json => $updated->{packages}}, {json => $updated->{repos}}, {json => $updated->{includes}}, {json => $updated->{meta}}, $id);

  $c->render(
    status  => 200,
    text    => "id: $id",
    json    => { id => $id },
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
  my $c = shift;
  my $id = $c->param('id');

  my $template = $c->pg->db->query('SELECT t.name, t.description, t.stub, t.repos, t.packages, t.meta, t.owner_id, u.username AS owner, EXTRACT(EPOCH FROM t.created) AS created, EXTRACT(EPOCH FROM t.updated) AS updated FROM templates t JOIN users u ON (u.id=t.owner_id) WHERE t.id=?', $id)->expand->hash;

  # check we actually received a valid template
  unless ($template) {
    return $c->render(
      status  => 404,
      json    => { error => 'not found' },
    );
  }

  # get auth'd user
  my $cu = $c->auth_user // { id => -1 };

  # skip if private and not owned by us
  if (!$template->{meta}{public} && $template->{owner_id} != $cu->{id}) {
    return $c->render(
      status  => 403,
      text    => 'denied',
      json    => { error => 'denied' },
    );
  }

  my $db = $c->pg->db;
  my $tx = $db->begin;
  $db->query('DELETE FROM templatemeta WHERE template_id=?', $id);;
  $db->query('DELETE FROM templates WHERE id=?', $id);;
  $tx->commit;

  $c->render(
    status  => 200,
    text    => 'ok',
    json    => { message => 'ok' },
  );
}

1;
