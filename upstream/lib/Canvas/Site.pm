#
# Copyright (C) 2013    Ian Firns   <firnsy@kororaproject.org>
#                       Chris Smart <csmart@kororaproject.org>
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
package Canvas::Site;

use warnings;
use strict;

use Mojo::Base 'Mojolicious::Controller';

#
# PERL INCLUDES
#
use Data::Dumper;


#
# CONTROLLER HANDLERS
#
sub index {
  my $self = shift;

  #return $self->redirect_to('login') unless( $self->is_user_authenticated );

  $self->render('index');
}

sub discover {
  my $self = shift;

  $self->render('discover');
}

sub download {
  my $self = shift;

  $self->render('download');
}

sub login {
  my $self = shift;

  $self->render('login');
}

sub auth {
  my $self = shift;
  my $json = Mojo::JSON->new;
  my $data = $json->decode($self->req->body);

  # collect first out of the parameters and then json decoded body
  my $u = $self->param('u') // $data->{u} // '';
  my $p = $self->param('p') // $data->{p} // '';

  if( $self->authenticate($u, $p) ) {
  }

  # extract the redirect url and fall back to the index
  my $url = $self->param('redirect_to') // $data->{redirect_to} // '/';

  return $self->redirect_to( $url );
};

sub deauth {
  my $self = shift;

  $self->logout;

  # extract the redirect url and fall back to the index
  my $url = $self->param('redirect_to') // '/';

  return $self->redirect_to( $url );
};

#
# CATCH ALL
sub trap {
  my $self = shift;

  my $path = $self->param('trap');

  # HTML5 mode forwarding based on valid paths
  $self->redirect_to('/#!/' . $path);
};



1;
