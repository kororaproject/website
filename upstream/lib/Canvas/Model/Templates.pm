package Canvas::Model::Templates;
use Mojo::Base -base;

use Digest::SHA qw(sha256_hex);
use Mojo::Util qw(dumper);
use Time::Piece;

has 'pg';

sub add {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $self = shift;
  my $args = @_%2 ? shift : {@_};

  my $template = $args->{template};

  # name => stub
  $template->{stub} //= $template->{name};

  # sanitise name to [A-Za-z0-9_-]
  $template->{stub} =~ s/[^\w-]+//g;

  # ensure we have a stub
  return $cb->('invalid name defined.', undef) unless length $template->{stub};

  my $now = gmtime;

  # generate unique id
  $template->{uuid} = sha256_hex join '',
    $template->{user},
    $template->{name},
    $now->epoch;

  # set default values
  $template->{description} //= '';
  $template->{includes}    //= [];
  $template->{meta}        //= {};
  $template->{packages}    //= {};
  $template->{repos}       //= {};

  if ($cb) {
    return Mojo::IOLoop->delay(
      sub {
        my $d = shift;

        # check for existing template
        $self->pg->db->query('
          SELECT t.id
          FROM templates t
          JOIN users u ON
            (u.id=t.owner_id)
          WHERE t.stub=? AND u.username=?' => ($template->{stub}, $template->{user}) => $d->begin);
      },
      sub {
        my ($d, $err, $res) = @_;

        # abort on error or results (ie already exists)
        return $cb->('internal server error', undef) if $err;
        return $cb->('template already exists', undef) if $res->rows;

        # insert if we're the owner or member of owner's group
        $self->pg->db->query('
          INSERT INTO templates
            (owner_id, uuid, name, stub, description,
            includes, packages, repos, meta)
          SELECT u.id, $1,$2,$3,$4,$5,$6,$7,$8
          FROM users u
          WHERE
            u.username=$9 AND
            (u.id=$10 OR
              (u.meta->\'members\' @> CAST($10 AS text)::jsonb))
          LIMIT 1' => (
            $template->{uuid},
            $template->{title},
            $template->{stub}, $template->{description},
            {json => $template->{includes}},
            {json => $template->{packages}},
            {json => $template->{repos}},
            {json => $template->{meta}},
            $template->{user},
            $args->{user_id}
          ) => $d->begin);
      },
      sub {
        my ($d, $err, $res) = @_;

        return $cb->('internal server error', undef) if $err;
        return $cb->('not authorised to add', undef) if $res->rows == 0;

        return $cb->(undef, $template->{uuid});
      }
    );
  }
}

sub all {
  my $self = shift;

  my $args = @_%2 ? shift : {@_};

  return $self->pg->db->query('
    SELECT
      t.id, t.name, t.description, t.stub, t.includes,
      t.repos, t.packages, t.meta, t.owner_id,
      u.username AS owner,
      EXTRACT(EPOCH FROM t.created) AS created,
      EXTRACT(EPOCH FROM t.updated) AS updated
    FROM templates t
    JOIN users u ON
      (u.id=t.owner_id)
    WHERE
      (t.owner_id=$1 OR
        (t.meta @> \'{"public": true}\'::jsonb))', $args->{id})->expand->hash;
}

sub find {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $self = shift;

  my $args = @_%2 ? shift : {@_};

  # TODO: page

  if ($cb) {
    return Mojo::IOLoop->delay(
      sub {
        my $d = shift;

        $self->pg->db->query('
          SELECT
            t.uuid, t.name, t.description, t.stub, t.includes,
            t.repos, t.packages, t.meta, u.username,
            EXTRACT(EPOCH FROM t.created) AS created,
            EXTRACT(EPOCH FROM t.updated) AS updated
          FROM templates t
          JOIN users u ON
            (u.id=t.owner_id)
          WHERE
            (t.uuid=$1 or $1 IS NULL) AND
            (t.stub=$2 or $2 IS NULL) AND
            (u.username=$3 or $3 IS NULL) AND
            (t.owner_id=$4 OR
              (u.meta->\'members\' @> CAST($4 AS text)::jsonb) OR
              (t.meta @> \'{"public": true}\'::jsonb)
            )' => (
              $args->{uuid}, $args->{name},
              $args->{user_name}, $args->{user_id}) => $d->begin);
      },
      sub {
        my ($d, $err, $res) = @_;

        warn dumper $err;
        return $cb->('internal server error', undef) if $err;

        return $cb->(undef, $res->expand->hashes);
      }
    );
  }
}

sub remove {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $self = shift;
  my $args = @_%2 ? shift : {@_};

  if ($cb) {
    return Mojo::IOLoop->delay(
      sub {
        my $d = shift;

        # check for existing template we can modify/remove
        $self->pg->db->query('
          SELECT t.id
          FROM templates t
          JOIN users u ON
            (u.id=t.owner_id)
          WHERE
            t.uuid=$1 AND
            (u.id=$2 OR (u.meta->\'members\' @> CAST($2 AS text)::jsonb))
          ' => ($args->{uuid}, $args->{user_id}) => $d->begin);
      },
      sub {
        my ($d, $err, $res) = @_;

        # abort on error or results (ie already exists)
        return $cb->('internal server error', undef) if $err;
        return $cb->('template doesn\'t exist', undef) if $res->rows == 0;

        # insert if we're the owner or member of owner's group
        $self->pg->db->query('DELETE FROM templatemeta WHERE template_id=$1' => ($args->{id}) => $d->begin);
        $self->pg->db->query('DELETE FROM templates WHERE id=$1' => ($args->{id}) => $d->begin);
      },
      sub {
        my ($d, $err_meta, $res_meta, $err, $res) = @_;

        return $cb->('internal server error', undef) if $err or $err_meta;

        return $cb->(undef, $res->rows == 1);
      }
    );
  }
}

sub resolve {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $self = shift;
  my $args = @_%2 ? shift : {@_};

  my $template = $args->{template};
  my $includes = $template->{includes};

  if (@{$includes}) {
    $template->{includes} = [];

    for my $template_name (@{$includes}) {
      my ($user, $name) = split /:/, $template_name;

      # TODO: ensure include is also "visible" to user
      my $t = $self->pg->db->query('SELECT t.uuid, t.name, t.description, t.stub, t.includes, t.repos, t.packages, t.meta, u.username, EXTRACT(EPOCH FROM t.created) AS created, EXTRACT(EPOCH FROM t.updated) AS updated FROM templates t JOIN users u ON (u.id=t.owner_id) WHERE t.stub=? AND u.username=?', $name, $user)->expand->hash;

      # recursively resolve
      if ($t) {
        $t = $self->resolve_includes(template => $t);
        push @{$template->{includes_resolved}}, $t;
      }
    }
  }

  return $template;
}

sub update {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $self = shift;
  my $args = @_%2 ? shift : {@_};

  my $template = $args->{template};

  # ensure we have a uuid
  return $cb->('no uuid defined.', undef) unless length $template->{uuid};

  # ensure we have a sanitised stub
  $template->{stub} //= $template->{name};
  $template->{stub} =~ s/[^\w-]+//g;
  return $cb->('invalid name defined.', undef) unless length $template->{stub};

  $template->{title}       //= '';
  $template->{description} //= '';
  $template->{includes}    //= [];
  $template->{meta}        //= {};
  $template->{packages}    //= {};
  $template->{repos}       //= {};

  if ($cb) {
    return Mojo::IOLoop->delay(
      sub {
        my $d = shift;

        # check for existing template we can modify
        $self->pg->db->query('
          SELECT t.id
          FROM templates t
          JOIN users u ON
            (u.id=t.owner_id)
          WHERE
            t.uuid=$1 AND
            (u.id=$2 OR (u.meta->\'members\' @> CAST($2 AS text)::jsonb))
          ' => ($template->{uuid}, $args->{user_id}) => $d->begin);
      },
      sub {
        my ($d, $err, $res) = @_;

        # abort on error or results (ie already exists)
        return $cb->('internal server error', undef) if $err;
        return $cb->('template doesn\'t exist', undef) if $res->rows == 0;

        # insert if we're the owner or member of owner's group
        $self->pg->db->query('
          UPDATE templates
            SET
              name=$1, stub=$2, description=$3,
              includes=$4, packages=$5, repos=$6, meta=$7
          WHERE
            uuid=$8' => (
            $template->{title},
            $template->{stub}, $template->{description},
            {json => $template->{includes}},
            {json => $template->{packages}},
            {json => $template->{repos}},
            {json => $template->{meta}},
            $template->{uuid},
          ) => $d->begin);
      },
      sub {
        my ($d, $err, $res) = @_;

        return $cb->('internal server error', undef) if $err;

        return $cb->(undef, $res->rows == 1);
      }
    );
  }
}

1;
