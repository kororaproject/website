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
package Canvas::News;

use warnings;
use strict;

#
# PERL INCLUDES
#
use Data::Dumper;
use Mojo::Base 'Mojolicious::Controller';
use Time::Piece;

#
# LOCAL INCLUDES
#
use Canvas::Store::WPPost;
use Canvas::Store::Pager;

#
# NEWS
#

sub index {
  my $self = shift;

  my $cache = {};

  my $pager = Canvas::Store::WPPost->pager(
    where             => { post_type => 'post' },
    order_by          => 'post_modified_gmt DESC',
    entries_per_page  => 5,
    current_page      => $self->param('page') // 0,
  );

  $cache->{items} = [ $pager->search_where ];
  $cache->{item_count} = $pager->total_entries;
  $cache->{page_size} = $pager->entries_per_page;
  $cache->{page} = $pager->current_page;

#  my foreach my $p ( @posts ) {
#    push @$cache, {
#      id            => $p->ID,
#      created       => $p->post_date_gmt,
#      updated       => $p->post_modified_gmt,
#      title         => $p->post_title,
#      content       => $p->post_content,
#      excerpt       => $p->post_excerpt,
#      name          => $p->post_name,
#      author        => $p->post_author->user_nicename,
#    };
#  }

  $self->stash( news => $cache );
  $self->render('news');
}

sub post {
  my $self = shift;
  my $post = $self->param('id');

  my $p = Canvas::Store::WPPost->search({ post_name => $post })->first;

  # check we found the post
  $self->redirect_to('/') unless defined $p;

  my $cache = {
    id            => $p->ID,
    created       => $p->post_date_gmt,
    updated       => $p->post_modified_gmt,
    title         => $p->post_title,
    content       => $p->post_content,
    excerpt       => $p->post_excerpt,
    name          => $p->post_name,
    author        => $p->post_author->user_nicename,
  };


  $self->stash( post => $cache );
  $self->render('news-post');
}

1;
