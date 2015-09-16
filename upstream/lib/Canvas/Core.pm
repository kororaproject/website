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
    $template->{includes_resolved} = [];

    for my $template_name (@{$includes}) {
      my ($user, $name) = split /:/, $template_name;

      # TODO: ensure include is also "visible" to user
      my $t = $c->pg->db->query('SELECT t.id, t.name, t.description, t.stub, t.includes, t.repos, t.packages, t.meta, u.username, EXTRACT(EPOCH FROM t.created) AS created, EXTRACT(EPOCH FROM t.updated) AS updated FROM templates t JOIN users u ON (u.id=t.owner_id) WHERE t.stub=? AND u.username=?', $name, $user)->expand->hash;

      # recursively resolve
      if ($t) {
        $t = resolve_includes($c, $t);
        push @{$template->{includes_resolved}}, $t;
      }
    }
  }

  return $template;
}

sub alpha { shift->render('canvas/alpha'); }

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

  my $format = $c->stash('format') // 'html';

  # collect first out of the parameters and then json decoded body
  my $user = $c->param('u') // $data->{u} // '';
  my $pass = $c->param('p') // $data->{p} // '';


  # extract the redirect url and fall back to the index
  my $url = $c->param('rt') // $data->{rt};
  $url = defined $url ? $c->ub64_decode($url) : '/';

  unless ($c->authenticate($user, $pass)) {
    return $c->render(status => 403, json => '') if $format eq 'json';

    $c->flash(page_errors => 'The username or password was incorrect. Perhaps your account has not been activated?');
  }

  return $c->render(status => 200, json => '') if $format eq 'json';

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

  my $uuid = $c->param('uuid');
  my $user = $c->param('user');
  my $name = $c->param('name');

  # get auth'd user
  my $cu = $c->auth_user // { id => -1 };

  $c->render_later;

  $c->canvas->templates->find(
    uuid      => $uuid,
    name      => $name,
    user_name => $user,
    user_id   => $cu->{id},
    sub {
      my ($err, $templates) = @_;

      return $c->render(status => 500, text => $err, json => {error => $err}) if $err;

      $c->render(status  => 200, json => $templates->to_array);
    }
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
    my $msg = 'not authenticated.';
    return $c->render(status => 403, text => $msg, json => {error => $msg});
  };

  # get auth'd user
  my $cu = $c->auth_user // { id => -1 };

  my $template = $c->req->json;

  $c->render_later;

  $c->canvas->templates->add(
    template => $template,
    user_id  => $cu->{id},
    sub {
      my ($err, $uuid) = @_;

      return $c->render(status => 500, text => $err, json => {error => $err}) if $err;

      $c->render(status => 200, text => "uuid: $uuid", json => {uuid => $uuid});
    }
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
sub template_get {
  my $c = shift;
  my $uuid = $c->param('uuid');
  my $resolve = $c->param('resolve') // 1;

  # get auth'd user
  my $cu = $c->auth_user // { id => -1 };

  $c->render_later;

  $c->canvas->templates->find(
    uuid    => $uuid,
    user_id => $cu->{id},
    sub {
      my ($err, $templates) = @_;

      return $c->render(status => 500, text => $err, json => {error => $err}) if $err;

      if ($templates->size != 1) {
        $err = 'too many template found.';
        return $c->render(status => 500, text => $err, json => {error => $err});
      }

      # only expect one template
      my $template = $templates->first;

      $c->resolve_includes($template) if !!$resolve;

      $c->render(json => $template);
    }
  );
}

sub template_includes_get {
  my $c = shift;
  my $uuid = $c->param('uuid');

  # get auth'd user
  my $cu = $c->auth_user // { id => -1 };

  my $template = $c->canvas->templates->find(
    uuid    => $uuid,
    user_id => $cu->{id}
  );

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
sub template_update {
  my $c = shift;
  my $uuid = $c->param('uuid');

  unless ($c->users->is_active) {
    my $msg = 'not authenticated.';
    return $c->render(status => 403, text => $msg, json => {error => $msg});
  };

  my $template = $c->req->json;

  # get auth'd user
  my $cu = $c->auth_user // { id => -1 };

  $c->render_later;

  $c->canvas->templates->update(
    uuid     => $uuid,
    template => $template,
    user_id  => $cu->{id},
    sub {
      my ($err, $uuid) = @_;

      return $c->render(status => 500, text => $err, json => {error => $err}) if $err;
      $c->render(status => 200, text => "uuid: $uuid", json => {uuid => $uuid});
    }
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
sub template_del {
  my $c = shift;
  my $uuid = $c->param('uuid');

  unless ($c->users->is_active) {
    my $msg = 'not authenticated.';
    return $c->render(status => 403, text => $msg, json => {error => $msg});
  };

  my $template = $c->req->json;

  # get auth'd user
  my $cu = $c->auth_user // { id => -1 };

  $c->render_later;

  $c->canvas->templates->remove(
    uuid     => $uuid,
    user_id  => $cu->{id},
    sub {
      my ($err, $uuid) = @_;

      return $c->render(status => 500, text => $err, json => {error => $err}) if $err;
      $c->render(status => 200, text => "uuid: $uuid", json => {uuid => $uuid});
    }
  );
}

#
# MACHINES
#

#
# GET /api/machines
#
# Returns all available machines
#
# Returns:
#  - 200 on success
#  - 404 if repository does not exist
#
sub machines_get {
  my $c = shift;

  my $uuid = $c->param('uuid');
  my $user = $c->param('user');
  my $name = $c->param('name');

  # get auth'd user
  my $cu = $c->auth_user // { id => undef };

  $c->render_later;

  $c->canvas->machines->find(
    uuid      => $uuid,
    name      => $name,
    user_name => $user,
    user_id   => $cu->{id},
    sub {
      my ($err, $machines) = @_;

      return $c->render(status => 500, text => $err, json => {error => $err}) if $err;

      $c->render(status  => 200, json => $machines->to_array);
    }
  );
};

#
# POST /api/machines
#
# Add a new machine
#
# Expected body contents is JSON encoded structure defining the machine
# repositories and packages to be added.
#
# Returns:
#  - 200 on success
#  - 403 if entity exists and you don't have sufficient privileges to modify
#  - 500 if machine owner doesn't exist or is invalid
#
sub machines_post {
  my $c = shift;

  unless ($c->users->is_active) {
    my $msg = 'not authenticated.';
    return $c->render(status => 403, text => $msg, json => {error => $msg});
  };

  # get auth'd user
  my $cu = $c->auth_user // { id => -1 };

  my $machine = $c->req->json;

  $c->render_later;

  $c->canvas->machines->add(
    machine => $machine,
    user_id  => $cu->{id},
    sub {
      my ($err, $uuid, $key) = @_;

      return $c->render(status => 500, text => $err, json => {error => $err}) if $err;

      $c->render(status => 200, text => "uuid: $uuid, key: $key", json => {uuid => $uuid, key => $key});
    }
  );
};


#
# GET /api/machine/:id
#
# Returns the machine identified by :id
#
# Returned body contents is an JSON encoded structure defining the machine
# repositories and packages contained within.
#
# Returns:
#  - 200 on success
#  - 403 if entity exists and you don't have sufficient privileges to modify
#  - 404 if machine doesn't exist
#  - 500 if machine owner doesn't exist or is invalid
#
sub machine_get {
  my $c = shift;
  my $uuid = $c->param('uuid');

  # get auth'd user
  my $cu = $c->auth_user // { id => -1 };

  $c->render_later;

  $c->canvas->machines->find(
    uuid      => $uuid,
    user_id => $cu->{id},
    sub {
      my ($err, $machines) = @_;

      return $c->render(status => 500, text => $err, json => {error => $err}) if $err;

      if ($machines->size != 1) {
        $err = 'too many machine found.';
        return $c->render(status => 500, text => $err, json => {error => $err});
      }

      # only expect one machine
      my $machine = $machines->first;

      $c->render(json => $machine);
    }
  );
}

sub machine_sync {
  my $c = shift;
  my $uuid = $c->param('uuid');

  # get request headers
  my $uuid2 = $c->req->headers->header('x-canvas-uuid');
  my $hash  = $c->req->headers->header('x-canvas-hash');
  my $nonce = $c->req->headers->header('x-canvas-nonce');
  my $templ = $c->req->headers->header('x-canvas-template') // 0;

  unless ($uuid eq $uuid2) {
    my $err = 'internal server error.';
    return $c->render(status => 500, text => $err, json => {error => $err});
  }

  # get auth'd user
  my $cu = $c->auth_user // { id => undef };

  $c->render_later;

  Mojo::IOLoop->delay(
    sub {
      my $d = shift;

      $c->canvas->machines->get(
        uuid    => $uuid,
        hash    => $hash,
        nonce   => $nonce,
        user_id => $cu->{id},
        $d->begin(0)
      );
    },
    sub {
      my ($d, $err, $machine) = @_;

      return $c->render(status => 500, text => $err, json => {error => $err}) if $err;

      $d->data(machine => $machine);

      if ($templ ne "1" || $templ eq $machine->{template}) {
        return $d->pass(undef, undef);
      }

      $c->canvas->templates->get($machine->{template}, $d->begin(0));
    },
    sub {
      my ($d, $err, $template) = @_;

      return $c->render(status => 500, text => $err, json => {error => $err}) if $err;

      $c->resolve_includes($template) if $template;

      $c->render(json => {machine => $d->data('machine'), template => $template});
    }
  );
}

#
# PUT /api/machine/:id
#
# Update existing machine
#
# Expected body contents is JSON encoded structure defining the machine
# repositories and packages to be added (or removed).
#
# Returns:
#  - 200 on success
#  - 403 if entity exists and you don't have sufficient privileges to modify
#  - 404 if machine doesn't exist
#  - 500 if machine owner doesn't exist or is invalid
#
sub machine_update {
  my $c = shift;
  my $uuid = $c->param('uuid');

  unless ($c->users->is_active) {
    my $msg = 'not authenticated.';
    return $c->render(status => 403, text => $msg, json => {error => $msg});
  };

  my $machine = $c->req->json;

  # get auth'd user
  my $cu = $c->auth_user // { id => -1 };

  $c->render_later;

  $c->canvas->machines->update(
    uuid    => $uuid,
    machine => $machine,
    user_id => $cu->{id},
    sub {
      my ($err, $uuid) = @_;

      return $c->render(status => 500, text => $err, json => {error => $err}) if $err;
      $c->render(status => 200, text => "uuid: $uuid", json => {uuid => $uuid});
    }
  );
}

#
# DELETE /api/machine/:id
#
# Delete machine identified by :id
#
# Returns:
#  - 200 on success
#  - 403 if entity exists and you don't have sufficient privileges to modify
#  - 404 if machine doesn't exist
#
sub machine_del {
  my $c = shift;
  my $uuid = $c->param('uuid');

  unless ($c->users->is_active) {
    my $msg = 'not authenticated.';
    return $c->render(status => 403, text => $msg, json => {error => $msg});
  };

  my $machine = $c->req->json;

  # get auth'd user
  my $cu = $c->auth_user // { id => -1 };

  $c->render_later;

  $c->canvas->machines->remove(
    uuid    => $uuid,
    user_id => $cu->{id},
    sub {
      my ($err, $uuid) = @_;

      return $c->render(status => 500, text => $err, json => {error => $err}) if $err;
      $c->render(status => 200, text => "uuid: $uuid", json => {uuid => $uuid});
    }
  );
}

1;
