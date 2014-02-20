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

use warnings;
use strict;

#
# PERL INCLUDES
#
use Data::Dumper;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(j);
use Mojo::Util qw(trim);
use Time::Piece;

#
# LOCAL INCLUDES
#
use Canvas::Store::Template;
use Canvas::Store::Tag;
use Canvas::Store::User;

#
# TEMPLATES
#

sub index_get {
  my $self = shift;

  my $cache = Canvas::Store::Template->search_paged(
    page_size => 20,
    page      => $self->param('page'),
  );

  $self->stash(
    responses => $cache,
  );

  $self->render('canvas/template');
}

sub detail_get {
  my $self = shift;

  my $user = Canvas::Store::User->search( { username => $self->param('user') } )->first;

  return $self->redirect_to('/templates') unless $user;

  my $template = Canvas::Store::Template->search( {
    user_id => $user->id,
    stub    => $self->param('name'),
  })->first;

  return $self->redirect_to('/templates') unless $template;

  # TODO: ensure we have visibility rights

  my @packages     = $template->template_packages;
  my @repositories = $template->template_repositories;

  my $canvas = j(template => {
    details      => $template,
    packages     => \@packages,
    repositories => \@repositories,
  });

  say Dumper $canvas;

  $self->stash(
    details      => $template,
    packages     => \@packages,
    repositories => \@repositories,
    canvas       => $canvas,
  );

  $self->render('canvas/template-detail');
}


1;
