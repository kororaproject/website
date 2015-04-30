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
package Website::Engage;

use warnings;
use strict;

#
# PERL INCLUDES
#
use Data::Dumper;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw(trim);
use POSIX qw(ceil);
use Time::Piece;

#
# LOCAL INCLUDES
#

#
# CONSTANTS
#
use constant TYPE_MAP => {
  '' => {
    status => {
      ''  => 'All Responses'
    }
  },
  question  => {
    name  => 'question',
    title => 'Ask a New Question',
    icon  => 'fa-question',
    status  => {
      ''            => 'All Questions',
      'need-answer' => 'Questions - Need Answer',
      'answered'    => 'Questions - Answered',
    },
  },
  thank     => {
    name  => 'thank',
    title => 'Say Thanks',
    icon  => 'fa-trophy',
    status  => {
      ''      => 'All Thanks',
      'noted' => 'Thanks - Noted',
    },
  },
};



#
# HELPERS
#

sub filter_valid_types($) {
  my $types_valid_map =  {
    question => 1,
    thank => 1,
  };

  my $types = shift // [ keys %$types_valid_map ];
  $types = [ $types ] unless ref $types eq 'ARRAY';

  my $v = [ grep { $types_valid_map->{$_} } @$types ];

  $v = [ keys %$types_valid_map ] unless @$v;

  return $v;
}

#
# ENGAGE
#

sub index {
  my $c = shift;

  my $page      = $c->param('page')   // 1;
  my $page_size = 20;
  my $status    = $c->param('status') // '';
  my $tags      = $c->param('tags');
  my $type      = filter_valid_types($c->param('type')) // '';

  $c->render_steps('website/engage', sub {
    my $delay = shift;

    my $db = $c->pg->db;
    my @filter = ();

    # filter on type
    if ($type) {
      push @filter, ' p.type IN (' . join(',', map { $db->dbh->quote($_) } @{$type}) . ')';
    }

    # filter on type
    if ($status) {
      push @filter, ' p.status=' . $db->dbh->quote($status);
    }

    # filter on tags
    if ($tags) {
      foreach my $t (split /[ ,]+/, $tags) {
        my $lt = $db->dbh->quote( '%' . $t . '%' );
        push @filter, '(p.title LIKE ' . $lt . ' OR p.content LIKE ' . $lt . ' OR t.name LIKE ' . $lt . ' OR r.content LIKE ' . $lt . ')';
      }
    }

    # build total count query
    my $raw_count_sql = 'SELECT COUNT(DISTINCT(p.id)) FROM post_tag pt LEFT JOIN posts p ON (p.id=pt.post_id) LEFT JOIN tags t ON (t.id=pt.tag_id) LEFT JOIN posts r ON (r.parent_id=p.id) WHERE (' . join( ') AND (', @filter ) . ')';

    # build paginated query
    my $raw_sql = 'SELECT p.*, EXTRACT(EPOCH FROM p.created) AS created_epoch, EXTRACT(EPOCH FROM p.updated) AS updated_epoch, pu.username, pu.email, ARRAY_AGG(DISTINCT t.name) AS tags, ARRAY_TO_JSON(ARRAY_AGG(DISTINCT ROW(ru.username, ru.email))) AS replies FROM post_tag pt LEFT JOIN posts p ON (p.id=pt.post_id) LEFT JOIN tags t ON (t.id=pt.tag_id) LEFT JOIN posts r ON (r.parent_id=p.id) LEFT JOIN users pu ON (pu.id=p.author_id) LEFT JOIN users ru ON (ru.id=r.author_id) WHERE (' . join( ') AND (', @filter ) . ') GROUP BY p.id, pu.id ORDER BY p.updated DESC';

    $raw_sql .= ' LIMIT ' . $page_size . ' OFFSET ' . ($page_size * ($page-1));

    # get total count
    $db->query($raw_count_sql => $delay->begin);

    # get paged items with username and email associated
    $db->query($raw_sql => $delay->begin);
  },
  sub {
    my ($delay, $count_err, $count_res, $err, $res) = @_;

    my $count = $count_res->array->[0];

    my $r = $res->expand->hashes;

    $c->stash(
      filter    => TYPE_MAP->{$type}{status}{$status},
      responses => {
        items       => $r,
        item_count  => $count,
        page_size   => $page_size,
        page        => $page,
        page_last   => ceil($count / $page_size),
      },
    );
  });
}

sub engage_syntax_get {
  my $c = shift;

  $c->render('website/engage-syntax-help');
}

sub engage_post_prepare_add_get {
  my $c = shift;

  my $content = $c->flash('content')  // '';
  my $tags    = $c->flash('tags')     // '';
  my $title   = $c->param('title')    // $c->flash('title') // '';
  my $type    = $c->param('type');

  # ensure it's a valid type
  return $c->redirect_to('/support/engage') unless grep { $_ eq $type } qw(question thank);

  # only allow authenticated and authorised users
  return $c->redirect_to('/support/engage') unless $c->is_user_authenticated;

  $c->stash(
    type    => TYPE_MAP->{$type},
    title   => $title,
    content => $content,
    tags    => $tags,
  );

  $c->render('website/engage-new');
}

sub engage_post_add_post {
  my $c = shift;

  # only allow authenticated and authorised users
  return $c->redirect_to('/support/engage') unless $c->users->is_active;

  my $type      = $c->param('type');
  my $content   = trim $c->param('content');
  my $title     = trim $c->param('title');
  my $tag_list  = trim $c->param('tags');

  my $status    = $type eq 'question' ? 'need-answer' : '';

  $c->flash(
    content => $content,
    tags    => $tag_list,
    title   => $title,
  );

  # ensure it's a valid type
  return $c->redirect_to('/support/engage') unless grep {$_ eq $type} qw(question thank);

  # ensure we have some sane title (at least 16 characters)
  unless (length $title >= 16) {
    $c->flash( page_errors => 'Your title lacks a little description. Pleast use at least least 16 characters.' );
    return $c->redirect_to('supportengagetypeadd', type => $type);
  }

  # ensure we have some sane content (at least 16 characters)
  unless (length $content >= 16) {
    $c->flash(page_errors => 'Your content lacks a little description. Pleast use at least least 16 characters to convey something meaningful.');
    return $c->redirect_to('supportengagetypeadd', type => $type);
  }

  my $tags = $c->sanitise_taglist($tag_list);

  # ensure we have some at least one tag
  unless (@{$tags}) {
    $c->flash(page_errors => 'Your post will be a lot easier to find with tags added. Please add at least one tag.');
    return $c->redirect_to('supportengagetypeadd', type => $type);
  }

  my $now = gmtime;
  my $stub = $c->sanitise_with_dashes($title);

  # enforce max stub size allowing 16 chars for padding
  $stub = substr $stub, 0, 112 if length($stub) > 112;

  # check for existing stubs and append the ID + 1 of the last
  my $e = $c->pg->db->query("SELECT MAX(id) FROM posts WHERE type=? AND name=?", $type, $stub)->hash;

  $stub .= '-' . ($e->{max} + 1) if $e;

  my $db = $c->pg->db;
  my $tx = $db->begin;

  my $created = $now;

  # create the post
  my $post_id = $db->query('INSERT INTO posts (type, name, status, title, content, author_id, created, updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?) RETURNING ID', $type, $stub, $status, $title, $content, $c->auth_user->{id}, $created, $now)->array->[0];

  # create the tags
  foreach my $tag (@{$tags}) {
    # find or create tag
    my $t = $db->query("SELECT id FROM tags WHERE name=?", $tag)->hash;

    unless ($t) {
      $t->{id} = $db->query("INSERT INTO tags (name) VALUES (?) RETURNING ID", $tag)->array->[0];
    }

    # insert the link
    my $pt = $db->query("INSERT INTO post_tag (post_id, tag_id) VALUES (?, ?)", $post_id, $t->{id});
  }

  $tx->commit;

  # undo our flash since we succeeded
  $c->flash(content => '');

  my $subject = 'Korora Project - New Engage Item: ' . $title;
  my $message = join "",
    "G'day,\n\n",
    "A new engage item has been posted by " . $c->auth_user->{username} . "\n\n",
    "URL: https://kororaproject.org" . $c->url_for('supportengagetypestub', type => $type, stub => $stub) . "\n",
    "Type: " . $type . "\n",
    "Status: " . $status . "\n",
    "Excerpt:\n",
    $content . "\n\n",
    "Regards,\n",
    "The Korora Team.\n";

  $c->notify_users('engage_notify_on_new', 1, 'engage@kororaproject.org', $subject, $message);

  # redirect to the detail
  $c->redirect_to('supportengagetypestub', type => $type, stub => $stub);
}

sub engage_post_detail_get {
  my $c = shift;

  my $page      = $c->param('page')   // 1;
  my $page_size = 20;
  my $stub = $c->param('stub');
  my $type = $c->param('type');

  # could have flashed 'content' from an attempted reply
  my $content = $c->flash('content') // '';

  $c->render_steps('website/engage-detail', sub {
    my $delay = shift;

    $c->pg->db->query("SELECT p.*, EXTRACT(EPOCH FROM p.created) AS created_epoch, EXTRACT(EPOCH FROM p.updated) AS updated_epoch, u.username, u.email, ARRAY_AGG(DISTINCT t.name) AS tags FROM posts p LEFT JOIN post_tag pt ON (pt.post_id=p.id) LEFT JOIN tags t ON (t.id=pt.tag_id) JOIN users u ON (u.id=p.author_id) WHERE p.type=? AND p.name=? GROUP BY p.id, u.username, u.email" => ($type, $stub) => $delay->begin);
  },
  sub {
    my ($delay, $p_err, $p_res) = @_;

    # check we found the post
    $delay->emit(redirect => '/support/engage') unless $p_res;

    my $post = $p_res->hash;
    $delay->data(post => $post);

    $c->pg->db->query("SELECT p.*, EXTRACT(EPOCH FROM p.created) AS created_epoch, EXTRACT(EPOCH FROM p.updated) AS updated_epoch, u.username, u.email FROM posts p JOIN users u ON (u.id=p.author_id) WHERE p.type='reply' AND p.status='accepted' AND p.parent_id=? GROUP BY p.id, u.username, u.email ORDER BY created" => ($post->{id}) => $delay->begin);

    $c->pg->db->query("SELECT COUNT(id) FROM posts WHERE type='reply' AND parent_id=?" => ($post->{id}) => $delay->begin);

    $c->pg->db->query("SELECT p.*, EXTRACT(EPOCH FROM p.created) AS created_epoch, EXTRACT(EPOCH FROM p.updated) AS updated_epoch, u.username, u.email FROM posts p JOIN users u ON (u.id=p.author_id) WHERE p.type='reply' AND p.parent_id=? GROUP BY p.id, u.username, u.email ORDER BY created LIMIT ? OFFSET ?" => ($post->{id}, $page_size, ($page_size * ($page-1))) => $delay->begin);
  },
  sub {
    my ($delay, $a_err, $a_res, $rc_err, $rc_res, $r_err, $r_res) = @_;

    my $count = $rc_res->array->[0];
    my $post = $delay->data('post');
    my $accepted = $a_res->hash;

    # allow path to get back here
    $c->flash(rt_url => $c->ub64_encode($c->url_with));

    $c->stash({
      response  => $post,
      accepted  => $accepted,
      content   => $content,
      replies   => {
        items       => $r_res->hashes,
        item_count  => $count,
        page_size   => $page_size,
        page        => $page,
        page_last   => ceil($count / $page_size),
      },
    });
  });
}

sub engage_post_edit_get {
  my $c = shift;

  my $stub = $c->param('stub');
  my $type = $c->param('type');

  $c->render_steps('website/engage-edit', sub {
    my $delay = shift;

    $c->pg->db->query("SELECT p.*, EXTRACT(EPOCH FROM p.created) AS created_epoch, EXTRACT(EPOCH FROM p.updated) AS updated_epoch, u.username, u.email, ARRAY_AGG(DISTINCT t.name) AS tags FROM posts p LEFT JOIN post_tag pt ON (pt.post_id=p.id) LEFT JOIN tags t ON (t.id=pt.tag_id) JOIN users u ON (u.id=p.author_id) WHERE p.type=? AND p.name=? GROUP BY p.id, u.username, u.email" => ($type, $stub) => $delay->begin);
  },
  sub {
    my ($delay, $p_err, $p_res) = @_;

    my $post = $p_res->hash;

    # check we found the post
    $delay->emit(redirect => '/support/engage') unless $c->engage->can_edit($post);

    $c->stash(post => $post);
  });
}

sub engage_post_edit_post {
  my $c = shift;

  # only allow authenticated and authorised users
  return $c->redirect_to('/support/engage') unless $c->users->is_active;

  my $stub = $c->param('stub');
  my $type = $c->param('type');

  my $p = $c->pg->db->query("SELECT * FROM posts WHERE type=? AND name=? LIMIT 1", $type, $stub)->expand->hash;

  # check we found the post
  return $c->redirect_to('/support/engage') unless defined $p;

  # update title, content and status
  my $title     = $c->param('title');
  my $content   = $c->param('content');
  my $status    = $c->param('status');
  my $tag_list  = trim $c->param('tags');

  my $now = gmtime;

  my $db = $c->pg->db;
  my $tx = $db->begin;

  my $meta = $p->{meta};
  $meta->{updated} = $c->auth_user->{id};

  $db->query("UPDATE posts SET status=?,meta=?::jsonb,title=?,content=?,updated=? WHERE id=?", $status, {json => $meta}, $title, $content, $now, $p->{id});

  # update tags
  my $tt = $db->query("SELECT ARRAY_AGG(t.name) AS tags FROM posts p LEFT JOIN post_tag pt ON (pt.post_id=p.id) LEFT JOIN tags t ON (t.id=pt.tag_id) WHERE p.id=? GROUP BY p.id", $p->{id})->hash;

  my @tags_old = $tt->{tags};
  my @tags_new = @{$c->sanitise_taglist($tag_list)};

  my %to = map { $_ => 1 } @tags_old;
  my %tn = map { $_ => 1 } @tags_new;

  # add tags
  foreach my $ta (grep(!defined $to{$_}, @tags_new)) {
    # find or create tag
    my $t = $db->query("SELECT id FROM tags WHERE name=?", $ta)->hash;
    unless ($t) {
      $t = { id => $db->query("INSERT INTO tags (name) VALUES (?) RETURNING ID", $ta)->array->[0] };
    }

    # find or create post/tag reference
    my $pt = $db->query("SELECT * FROM post_tag WHERE post_id=? AND tag_id=?", $p->{id}, $t->{id})->hash;
    unless ($pt) {
      $db->query("INSERT INTO post_tag (post_id, tag_id) VALUES (?, ?)", $p->{id}, $t->{id});
    }
  }

  $tx->commit;

  $c->redirect_to('supportengagetypestub', type => $type, stub => $stub);
}

sub engage_post_subscribe_any {
  my $c = shift;

  my $stub = $c->param('stub');
  my $type = $c->param('type');

  my $url = $c->url_for('supportengagetypestub', type => $type, stub => $stub);

  # redirect unless we're actively auth'd
  return $c->redirect_to($url) unless $c->users->is_active;

  my $p = $c->pg->db->query("SELECT id FROM posts WHERE type=? AND name=? LIMIT 1", $type, $stub)->hash;

  # check we found the post
  return $c->redirect_to($url) unless defined $p;

  # subscribe (engage_subscriptions)
  $c->pg->db->query("INSERT INTO usermeta (user_id,meta_key,meta_value) VALUES (?,'engage_subscriptions',?)",$c->auth_user->{id}, $p->{id});

  $c->redirect_to($url);
}

sub engage_post_unsubscribe_any {
  my $c = shift;

  my $stub  = $c->param('stub');
  my $type  = $c->param('type');

  # delete usermeta entry
  if ($c->users->is_active) {
    $c->pg->db->query("DELETE FROM usermeta WHERE user_id=? AND meta_key='engage_subscriptions' AND meta_value::integer IN (SELECT id FROM posts WHERE type=? AND name=?)", $c->auth_user->{id}, $type, $stub);
  }

  $c->redirect_to($c->url_for('supportengagetypestub', type => $type, stub => $stub));
}


sub engage_reply_post {
  my $c= shift;

  my $content   = $c->param('content') // '';
  my $id        = $c->param('parent_id');
  my $type      = $c->param('type');
  my $stub      = $c->param('stub');
  my $subscribe = $c->param('subscribe') // 0;

  my $rt     = $c->param('rt');
  my $rt_url = $rt ? $c->ub64_decode($rt) : $c->url_for('supportengagetypestub', type => $type, stub => $stub);

  # only allow authenticated and authorised users
  return $c->redirect_to($rt_url) unless $c->users->is_active;

  # ensure we have content
  unless (length(trim $content) >= 16) {
    $c->flash(content => $content);

    $c->flash(page_errors => 'Your reply lacks a little description. Pleast use at least least 16 characters to convey something meaningful.');
    return $c->redirect_to($rt_url);
  }

  my $p = $c->pg->db->query("SELECT * FROM posts WHERE id=?", $id)->hash;

  # check we found the post
  return $c->redirect_to('/support/engage') unless $p;

  my $db = $c->pg->db;
  my $tx = $db->begin;

  my $now = gmtime;
  my $created = $now;

  # create the post
  my $reply_id = $db->query("INSERT INTO posts (type, name, content, author_id, created, updated, parent_id) VALUES ('reply', ?, ?, ?, ?, ?, ?) RETURNING ID", $stub, $content, $c->auth_user->{id}, $created, $now, $id)->array->[0];

  # TODO: optimise with an increment
  $db->query("UPDATE posts SET reply_count=reply_count+1,updated=? WHERE id=?", $now, $p->{id});

  # auto-subscribe participants (engage_subscriptions)
  my $s = $db->query("SELECT meta_id FROM usermeta WHERE user_id=? AND meta_key='engage_subscriptions' AND meta_value=?", $c->auth_user->{id}, $p->{id})->hash;

  $db->query("INSERT INTO usermeta (user_id, meta_key, meta_value) VALUES (?, 'engage_subscriptions', ?)", $c->auth_user->{id}, $p->{id}) unless ($s);

  $tx->commit;

  my $subject = 'Korora Project - Engage Reply: ' . $p->{title};
  my $message = join "",
    "G'day,\n\n",
    "A new reply has been posted by " . $c->auth_user->{username} . "\n\n",
    "URL: https://kororaproject.org" . $c->url_for( 'supportengagetypestub', type=> $type, stub => $stub ) . '#reply-' . $reply_id . "\n",
    "Type: " . $type . "\n",
    "Status: " . $p->{status} . "\n",
    "Excerpt:\n",
    $content . "\n\n",
    "Regards,\n",
    "The Korora Team.\n";

  $c->notify_users('engage_subscriptions', $p->{id}, 'engage@kororaproject.org', $subject, $message);

  # redirect to the detail
  $c->redirect_to($rt_url);
}

sub engage_reply_accept_any {
  my $c = shift;

  my $type    = $c->param('type');
  my $stub    = $c->param('stub');
  my $id      = $c->param('id');
  my $content = $c->param('content');

  my $r = $c->pg->db->query("SELECT * FROM posts WHERE type='reply' AND id=? LIMIT 1", $id)->hash;

  # ensure we have edit capabilities
  return $c->redirect_to('supportengagetypestub', type => $type, stub => $stub) unless $c->engage->can_accept($r);

  $c->pg->db->query("UPDATE posts SET status='accepted' WHERE id=?", $id);

  # redirect to the detail
  $c->redirect_to( 'supportengagetypestub', type => $type, stub => $stub );
}

sub engage_reply_unaccept_any {
  my $c = shift;

  my $type    = $c->param('type');
  my $stub    = $c->param('stub');
  my $id      = $c->param('id');
  my $content = $c->param('content');

  my $r = $c->pg->db->query("SELECT * FROM posts WHERE type='reply' AND id=? LIMIT 1", $id)->hash;

  # ensure we have edit capabilities
  return $c->redirect_to('supportengagetypestub', type => $type, stub => $stub) unless $c->engage->can_unaccept($r);

  $c->pg->db->query("UPDATE posts SET status='' WHERE id=?", $id);

  # redirect to the detail
  $c->redirect_to('supportengagetypestub', type => $type, stub => $stub);
}

sub engage_reply_edit_get {
  my $c = shift;

  my $id   = $c->param('id');
  my $type = $c->param('type');
  my $stub = $c->param('stub');

  my $rt_url = $c->ub64_decode($c->flash('rt')) //
                 $c->url_for('supportengagetypestub', type => $type, stub => $stub);

  $c->render_steps('website/engage-reply-edit', sub {
    my $delay = shift;

    $c->pg->db->query("SELECT r.content, r.author_id, p.title, p.type, EXTRACT(EPOCH FROM r.created) AS created_epoch, EXTRACT(EPOCH FROM r.updated) AS updated_epoch, u.username, u.email FROM posts r JOIN posts p ON (r.parent_id=p.id) JOIN users u ON (u.id=r.author_id) WHERE r.type='reply' AND r.id=? LIMIT 1" => ($id) => $delay->begin);
  },
  sub {
    my ($delay, $p_err, $p_res) = @_;

    my $post = $p_res->hash;

    # check we found the post
    $delay->emit(redirect => $rt_url) unless $c->engage->can_edit($post);

    my $content = $c->flash('content') // $post->{content};

    $c->stash(
      content => $content,
      reply   => $post,
      rt      => $c->ub64_encode($rt_url),
      rt_url  => $rt_url
    );
  });
}

sub engage_reply_edit_post {
  my $c = shift;

  my $content = $c->param('content');
  my $id      = $c->param('id');
  my $type    = $c->param('type');
  my $stub    = $c->param('stub');

  my $redirect_url = $c->param('redirect_url') // $c->url_for('supportengagetypestub', type => $type, stub => $stub);


  # ensure edits maintain some context
  unless( length( trim $content ) >= 16 ) {
    $c->flash(content => $content);
    $c->flash(page_errors => 'Your editted reply lacks a little description. Pleast use at least least 16 characters to convey something meaningful.');
    return $c->redirect_to( $c->url_with );
  }

  my $r = $c->pg->db->query("SELECT * FROM posts WHERE type='reply' AND id=? LIMIT 1", $id)->expand->hash;

  # ensure we have edit capabilities
  return $c->redirect_to( $redirect_url ) unless $c->engage->can_edit( $r );

  my $now = gmtime;

  my $db = $c->pg->db;
  my $tx = $db->begin;

  my $meta = $r->{meta};
  $meta->{updated} = $c->auth_user->{id};

  # update the reply
  $db->query("UPDATE posts SET content=?,meta=?::jsonb,updated=? WHERE id=?", $content, {json => $meta},$now, $id);

  # update the parent timestamp
  $db->query("UPDATE posts SET updated=? WHERE id=?", $now, $r->{parent_id});

  $tx->commit;

  # redirect to the detail
  $c->redirect_to($redirect_url);
}

sub engage_post_delete_any {
  my $c = shift;

  my $type = $c->param('type');
  my $stub = $c->param('stub');

  my $p = $c->pg->db->query("SELECT * FROM posts WHERE type=? AND name=? LIMIT 1", $type, $stub)->hash;

  # only allow authenticated and authorised users
  return $c->redirect_to('/support/engage') unless $c->engage->can_delete($p);

  # delete post and children
  $c->pg->db->query("DELETE FROM posts WHERE type IN ('question', 'thank', reply') AND (id=? OR parent_id=?)", $p->{id}, $p->{id});

  $c->redirect_to('/support/engage');
}

sub engage_reply_any {
  my $c = shift;

  my $id   = $c->param('id');
  my $stub = $c->param('stub');

  $c->render_later;

  Mojo::IOLoop->delay(sub {
    my $delay = shift;

    $c->pg->db->query("SELECT p.content, u.username FROM posts p JOIN users u ON (u.id=p.author_id) WHERE p.id=? AND p.name=? LIMIT 1" => ($id, $stub) => $delay->begin);
  },
  sub {
    my ($delay, $p_err, $p_res) = @_;

    my $p = $p_res->hash;

    $c->render(json => $p);
  })->catch(sub {
    $c->render(json => {});
  })->wait;
}


sub engage_reply_delete_any {
  my $c = shift;

  my $type = $c->param('type');
  my $stub = $c->param('stub');
  my $id   = $c->param('id');

  my $r = $c->pg->db->query("SELECT * FROM posts WHERE type='reply' AND id=? LIMIT 1", $id)->hash;

  # only allow authenticated and authorised users
  return $c->redirect_to('/support/engage') unless $c->engage->can_delete($r);

  $c->pg->db->query("DELETE FROM posts WHERE id=?", $id);

  # redirect to the detail
  $c->redirect_to( 'supportengagetypestub', type => $type, stub => $stub );
}

1;
