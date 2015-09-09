package Canvas::Model::Machines;
use Mojo::Base -base;

use Digest::SHA qw(sha256_hex sha512_hex);
use Mojo::Util qw(dumper);
use Time::Piece;

use Canvas::Util qw(get_random_bytes);

has 'pg';

sub add {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $self = shift;
  my $args = @_%2 ? shift : {@_};

  my $machine = $args->{machine};

  # name => stub
  $machine->{stub} //= $machine->{name};

  # sanitise name to [A-Za-z0-9_-]
  $machine->{stub} =~ s/[^\w-]+//g;

  # ensure we have a stub
  return $cb->('invalid name defined.', undef) unless length $machine->{stub};

  # ensure we have a template
  return $cb->('invalid template defined.', undef) unless length($machine->{template}) == 64;

  my $now = gmtime;

  # generate unique id and key
  $machine->{uuid} = sha256_hex join '',
    $machine->{user},
    $machine->{name},
    $now->epoch;

  my $bytes = get_random_bytes(48);
  $machine->{key} = sha512_hex join '',
    $machine->{user},
    $machine->{name},
    $bytes,
    $now->epoch;

  # set default values
  $machine->{description} //= '';
  $machine->{stores}      //= [];
  $machine->{archives}    //= [];
  $machine->{history}     //= [];
  $machine->{meta}        //= {};

  if ($cb) {
    return Mojo::IOLoop->delay(
      sub {
        my $d = shift;

        # ensure template is accessible
        $self->pg->db->query('
          SELECT
            t.id
          FROM templates t
          JOIN users u ON
            (u.id=t.owner_id)
          WHERE
            t.uuid=$1 AND
            (t.owner_id=$2 OR
              (u.meta->\'members\' @> $2) OR
              (t.meta @> \'{"public": true}\'::jsonb)
            )' => (
              $machine->{template}, $args->{user_id}) => $d->begin);
      },
      sub {
        my ($d, $err, $res) = @_;

        # abort on error or results (ie already exists)
        return $cb->('internal server error', undef, undef) if $err;
        return $cb->('template doesn\'t exist or not accessible', undef, undef) if $res->rows == 0;

        $d->data(template => $res->array->[0]);

        # check for existing machine
        $self->pg->db->query('
          SELECT m.id
          FROM machines m
          JOIN users u ON
            (u.id=m.owner_id)
          WHERE m.stub=? AND u.username=?' => ($machine->{stub}, $machine->{user}) => $d->begin);
      },
      sub {
        my ($d, $err, $res) = @_;

        # abort on error or results (ie already exists)
        return $cb->('internal server error', undef, undef) if $err;
        return $cb->('machine already exists', undef, undef) if $res->rows;

        # insert if we're the owner or member of owner's group
        $self->pg->db->query('
          INSERT INTO machines
            (owner_id, template_id, uuid, key, name, stub,
            description, stores, archives, history, meta)
          SELECT u.id, $1,$2,$3,$4,$5,$6,$7,$8,$9,$10
          FROM users u
          WHERE
            u.username=$11 AND
            (u.id=$12 OR
              (u.meta->\'members\' @> $12))
          LIMIT 1' => (
            $d->data('template'),
            $machine->{uuid},
            $machine->{key},
            $machine->{title},
            $machine->{stub}, $machine->{description},
            {json => $machine->{stores}},
            {json => $machine->{archives}},
            {json => $machine->{history}},
            {json => $machine->{meta}},
            $machine->{user},
            $args->{user_id}
          ) => $d->begin);
      },
      sub {
        my ($d, $err, $res) = @_;

        return $cb->('internal server error', undef, undef) if $err;
        return $cb->('not authorised to add', undef, undef) if $res->rows == 0;

        return $cb->(undef, $machine->{uuid}, $machine->{key});
      }
    );
  }
}

sub all {
  my $self = shift;

  my $args = @_%2 ? shift : {@_};

  return $self->pg->db->query('
    SELECT
      m.uuid, m.name, m.description, m.stub, m.includes,
      m.repos, m.packages, m.meta, m.owner_id,
      u.username AS owner,
      EXTRACT(EPOCH FROM m.created) AS created,
      EXTRACT(EPOCH FROM m.updated) AS updated
    FROM machines m
    JOIN users u ON
      (u.id=m.owner_id)
    WHERE
      (m.owner_id=$1)', $args->{id})->expand->hash;
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
            m.uuid, m.name, m.description, m.stub, m.includes,
            m.repos, m.packages, m.meta, u.username,
            EXTRACT(EPOCH FROM m.created) AS created,
            EXTRACT(EPOCH FROM m.updated) AS updated
          FROM machines m
          JOIN users u ON
            (u.id=m.owner_id)
          WHERE
            (m.uuid=$1 or $1 IS NULL) AND
            (m.stub=$2 or $2 IS NULL) AND
            (u.username=$3 or $3 IS NULL) AND
            (m.owner_id=$4 OR
              (u.meta->\'members\' @> $4)
            )' => (
              $args->{uuid}, $args->{name},
              $args->{user_name}, $args->{user_id}) => $d->begin);
      },
      sub {
        my ($d, $err, $res) = @_;

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

        # check for existing machine we can modify/remove
        $self->pg->db->query('
          SELECT t.id
          FROM machines m
          JOIN users u ON
            (u.id=m.owner_id)
          WHERE
            m.uuid=$1 AND
            (u.id=$2 OR (u.meta->\'members\' @> $2))
          ' => ($args->{uuid}, $args->{user_id}) => $d->begin);
      },
      sub {
        my ($d, $err, $res) = @_;

        # abort on error or results (ie already exists)
        return $cb->('internal server error', undef) if $err;
        return $cb->('machine doesn\'t exist', undef) if $res->rows == 0;

        # insert if we're the owner or member of owner's group
        $self->pg->db->query('DELETE FROM machinemeta WHERE machine_id=$1' => ($args->{id}) => $d->begin);
        $self->pg->db->query('DELETE FROM machines WHERE id=$1' => ($args->{id}) => $d->begin);
      },
      sub {
        my ($d, $err_meta, $res_meta, $err, $res) = @_;

        return $cb->('internal server error', undef) if $err or $err_meta;

        return $cb->(undef, $res->rows == 1);
      }
    );
  }
}

sub update {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $self = shift;
  my $args = @_%2 ? shift : {@_};

  my $machine = $args->{machine};

  # ensure we have a template
  return $cb->('invalid template defined.', undef) unless length($machine->{template}) == 64;

  # ensure we have a sanitised stub
  $machine->{stub} //= $machine->{name};
  $machine->{stub} =~ s/[^\w-]+//g;
  return $cb->('invalid name defined.', undef) unless length $machine->{stub};

  $machine->{title}       //= '';
  $machine->{description} //= '';
  $machine->{stores}      //= [];
  $machine->{archives}    //= [];
  $machine->{hisotry}     //= [];
  $machine->{meta}        //= {};

  if ($cb) {
    return Mojo::IOLoop->delay(
      sub {
        my $d = shift;

        # ensure template is accessible
        $self->pg->db->query('
          SELECT
            t.id
          FROM templates t
          JOIN users u ON
            (u.id=t.owner_id)
          WHERE
            t.uuid=$1 AND
            (t.owner_id=$2 OR
              (u.meta->\'members\' @> $2) OR
              (t.meta @> \'{"public": true}\'::jsonb)
            )' => (
              $machine->{template}, $args->{user_id}) => $d->begin);
      },
      sub {
        my ($d, $err, $res) = @_;

        # abort on error or results (ie already exists)
        return $cb->('internal server error', undef, undef) if $err;
        return $cb->('template doesn\'t exist or not accessible', undef, undef) if $res->rows == 0;

        $d->data(template => $res->array->[0]);

        # check for existing machine we can modify
        $self->pg->db->query('
          SELECT m.id
          FROM machines m
          JOIN users u ON
            (u.id=m.owner_id)
          WHERE
            m.uuid=$1 AND
            (u.id=$2 OR (u.meta->\'members\' @> $2))
          ' => ($args->{uuid}, $args->{user_id}) => $d->begin);
      },
      sub {
        my ($d, $err, $res) = @_;

        # abort on error or results (ie already exists)
        return $cb->('internal server error', undef) if $err;
        return $cb->('machine doesn\'t exist', undef) if $res->rows == 0;

        # insert if we're the owner or member of owner's group
        $self->pg->db->query('
          UPDATE machines
            SET
              name=$1, stub=$2, description=$3,
              includes=$4, packages=$5, repos=$6, meta=$7
          WHERE
            uuid=$8' => (
            $machine->{title},
            $machine->{stub}, $machine->{description},
            {json => $machine->{stores}},
            {json => $machine->{archives}},
            {json => $machine->{history}},
            {json => $machine->{meta}},
            $args->{uuid},
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
