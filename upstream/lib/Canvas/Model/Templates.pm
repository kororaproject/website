package Canvas::Model::Templates;
use Mojo::Base -base;

has 'pg';


sub add {

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
  my $self = shift;

  my $args = @_%2 ? shift : {@_};

  # TODO: page

  return $self->pg->db->query('
    SELECT
      t.id, t.name, t.description, t.stub, t.includes,
      t.repos, t.packages, t.meta, t.owner_id,
      u.username,
      EXTRACT(EPOCH FROM t.created) AS created,
      EXTRACT(EPOCH FROM t.updated) AS updated
    FROM templates t
    JOIN users u ON
      (u.id=t.owner_id)
    WHERE
      (t.id=$1 or $1 IS NULL) AND
      (t.name=$2 or $2 IS NULL) AND
      (u.username=$3 or $3 IS NULL) AND
      (t.owner_id=$4 OR (t.meta @> \'{"public": true}\'::jsonb))', $args->{id}, $args->{name}, $args->{user_name}, $args->{user_id})->expand->hashes;
}

sub remove {
  my ($self, $id, $user) = @_;

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
      t.id=? AND
      (t.owner_id=? OR (t.meta @> \'{"public": true}\'::jsonb))', $id, $user->{id})->expand->hash;
}

sub update {

}

1;
