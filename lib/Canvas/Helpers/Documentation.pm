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
package Canvas::Helpers::Documentation;

use Mojo::Base 'Mojolicious::Plugin';

sub register {
  my ($self, $app) = @_;

  $app->helper('document.can_view' => sub {
    my ($c, $document) = @_;

    return 1 if $document->{status} eq 'publish';

    return 0 unless $c->users->is_active($c->auth_user);

    return 1 if $c->users->is_document_moderator($c->auth_user);

    return 0;
  });

  $app->helper('document.can_add' => sub {
    my ($c) = @_;

    return 0 unless $c->users->is_active($c->auth_user);

    return 1 if $c->users->is_document_moderator($c->auth_user);

    return 0;
  });

  $app->helper('document.can_delete' => sub {
    my ($c) = @_;

    return 0 unless $c->users->is_active($c->auth_user);

    return 1 if $c->users->is_admin($c->auth_user);

    return 0;
  });

  $app->helper('document.can_edit' => sub {
    my ($c, $document) = @_;

    return 0 unless $c->users->is_active($c->auth_user);

    return 1 if $c->users->is_document_moderator($c->auth_user);

    return 0;
  });


  $app->helper('document.parents' => sub {
    my ($c, $selected) = @_;
    my $parents = [];

    $selected //= -1;
    push @{$parents}, [
      ($selected == 0) ? ("None", 0, 'selected', 'selected') : ("None", 0)
    ];

    my $documents = $c->pg->db->query("SELECT pm.meta_value::integer AS ho, hd.meta_value::integer AS depth, title, id FROM posts JOIN postmeta AS pm ON (pm.post_id=posts.id AND pm.meta_key='hierarchy_order') JOIN postmeta AS hd ON (hd.post_id=posts.id AND hd.meta_key='hierarchy_depth') WHERE type='document' ORDER BY ho")->hashes;

    foreach my $d (@{$documents}) {
      my $t = ("-" x $d->{depth}) . " " . $d->{title};
      push @{$parents}, [
        ($selected == $d->{id}) ? ($t, $d->{id}, 'selected', 'selected') : ($t, $d->{id})
      ]
    }

    return $parents;
  });
}

1;
