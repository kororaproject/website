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
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(j encode_json);
use Mojo::Util qw(trim);
use Time::Piece;

#
# LOCAL INCLUDES
#

#
# TEMPLATES
#

sub index_get {
  my $c = shift;

  $c->render_steps('canvas/template', sub {
    my $delay = shift;

    # get total count
    $c->pg->db->query("SELECT COUNT(id) FROM templates" => $delay->begin);

    $c->pg->db->query("SELECT t.name, t.stub, u.username AS user FROM templates t JOIN users u ON (u.id=t.owner_id)" => $delay->begin);
  },
  sub {
    my ($delay, $count_err, $count_res, $err, $res) = @_;

    my $count = $count_res->array->[0];
    my $results = $res->expand->hashes;

    $c->stash(
      total     => $count,
      responses => $results
    );
  });
}

sub detail_get {
  my $c = shift;

  my $username      = $c->param('user');
  my $template_name = $c->param('name');

  $c->render_steps('canvas/template-detail', sub {
    my $delay = shift;

    # get total count
    $c->pg->db->query("SELECT t.* FROM templates t JOIN users u ON (u.id=t.owner_id) WHERE u.username=? AND t.stub=?" => ($username, $template_name) => $delay->begin);
  },
  sub {
    my ($delay, $err, $res) = @_;

    my $template = $res->expand->hash;

    return $c->redirect_to('/templates') unless $template;

    # TODO: ensure we have visibility rights

    #$template->{_id} = $template->{_id}->to_string;
    $c->stash(
      canvas      => $template,
      canvas_json => encode_json($template),
    );
  });
}

1;
