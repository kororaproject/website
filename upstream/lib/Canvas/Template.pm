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
package Canvas::Template;

#
# PERL INCLUDES
#
use Data::Dumper;
use Mango;
use Mango::BSON;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(j);
use Mojo::Util qw(trim);
use Time::Piece;

#
# LOCAL INCLUDES
#
use Canvas::Store::User;

#
# TEMPLATES
#

sub index_get {
  my $self = shift;

  my $mango = Mango->new('mongodb://localhost:27017');
  my $collection = $mango->db('canvas')->collection('templates');

  # find or create new template
  my $tc = $collection->find( {}, {
    name => 1,
    stub => 1,
    user => 1,
  });

  my $total = $tc->count;

  my $cache = $tc->all;

  $self->stash(
    total => $total,
    responses => $cache,
  );

  $self->render('canvas/template');
}

sub detail_get {
  my $self = shift;

  my $user = Canvas::Store::User->search( { username => $self->param('user') } )->first;

  return $self->redirect_to('/templates') unless $user;

  my $mango = Mango->new('mongodb://localhost:27017');
  my $collection = $mango->db('canvas')->collection('templates');

  # find or create new template
  my $template = $collection->find_one({
    user => $user->username,
    stub => $self->param('name')
  });

  return $self->redirect_to('/templates') unless $template;

  # TODO: ensure we have visibility rights

  #$template->{_id} = $template->{_id}->to_string;
  $self->stash(
    canvas      => $template,
    canvas_json => j($template),
  );

  $self->render('canvas/template-detail');
}

1;
