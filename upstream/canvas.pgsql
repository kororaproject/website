BEGIN;

CREATE TABLE users (
  id            BIGSERIAL     PRIMARY KEY,
  username      VARCHAR(64),
  password      VARCHAR(64),

  realname      VARCHAR(128),
  email         VARCHAR(128),

  description   TEXT,

  /*
  ** pending, active, suspended, closed
  */

  status        VARCHAR(16)   DEFAULT 'pending',

  access        INTEGER       DEFAULT 0,

  created       TIMESTAMP     NOT NULL  DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'utc'),
  updated       TIMESTAMP     NOT NULL  DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'utc'),

  meta          JSONB         NOT NULL  DEFAULT '{}',

  UNIQUE (username)
);

CREATE TABLE usermeta (
  meta_id     BIGSERIAL       PRIMARY KEY,
  user_id     BIGINT          REFERENCES users(id),
  meta_key    VARCHAR(64),
  meta_value  TEXT
);


/*
** KORORA CANVAS - POST / ENGAGE STRUCTURES
*/

CREATE TABLE posts (
  id            BIGSERIAL     PRIMARY KEY,
  author_id     BIGINT        REFERENCES users(id),

  parent_id     BIGINT        DEFAULT 0,

  /* encrypt the post with a password */
  password      VARCHAR(32),

  /* types: news, question, problem, thanks, idea */
  type          VARCHAR(16)   NOT NULL,

  /*
  ** document: draft, publish
  ** news: draft, publish
  ** question: answered, waiting
  ** thanks: n/a
  ** reply: accepted
  */
  status        VARCHAR(32)   NOT NULL  DEFAULT '',

  /* name of the post */
  name          VARCHAR(200)  NOT NULL  DEFAULT '',

  /* name of the post */
  title         TEXT          NOT NULL  DEFAULT '',

  /* optional introductory paragraph of post */
  excerpt       TEXT          NOT NULL  DEFAULT '',

  /* primary content of post */
  content       TEXT          NOT NULL  DEFAULT '',

  /* provides an selectable prioritisation for post order */
  menu_order    INT           NOT NULL  DEFAULT 0,

  /*
  ** open - replies are enabled
  ** closed - post is closed from replies
  */
  reply_status  VARCHAR(16)   NOT NULL  DEFAULT 'open',
  reply_count   INT           NOT NULL  DEFAULT 0,

  meta          JSONB         NOT NULL  DEFAULT '{}',

  created       TIMESTAMP     NOT NULL  DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'utc'),
  updated       TIMESTAMP     NOT NULL  DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'utc')
);

CREATE TABLE postmeta (
  meta_id     BIGSERIAL       PRIMARY KEY,
  post_id     BIGINT          REFERENCES posts(id),
  meta_key    VARCHAR(64),
  meta_value  TEXT
);

CREATE TABLE tags (
  id            BIGSERIAL     PRIMARY KEY,
  name          VARCHAR(255)  NOT NULL,

  created       TIMESTAMP     NOT NULL  DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'utc')
);

CREATE TABLE post_tag (
  tag_id        BIGINT        REFERENCES tags(id),
  post_id       BIGINT        REFERENCES posts(id),
  created       TIMESTAMP     NOT NULL  DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'utc'),

  PRIMARY KEY (tag_id, post_id)
);



CREATE TABLE contributions (
  id              BIGSERIAL   PRIMARY KEY,
  merchant_id     VARCHAR(64) NOT NULL,
  transaction_id  VARCHAR(64) NOT NULL,

  name            VARCHAR(64),
  email           VARCHAR(128),

  amount          VARCHAR(16),
  fee             VARCHAR(16),

  /* donation or sponsorship */
  type            VARCHAR(16) NOT NULL,

  paypal_raw      TEXT,

  meta            JSONB       NOT NULL  DEFAULT '{}',

  created         TIMESTAMP   NOT NULL  DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'utc')
);









CREATE TABLE templates (
  id            BIGSERIAL     PRIMARY KEY,
  owner_id      BIGINT        REFERENCES users(id)      NOT NULL,

  uuid          VARCHAR(64),

  name          TEXT,
  stub          VARCHAR(128)  NOT NULL,
  description   TEXT,

  includes      JSONB         NOT NULL  DEFAULT '[]',
  packages      JSONB         NOT NULL  DEFAULT '[]',
  repos         JSONB         NOT NULL  DEFAULT '[]',

  meta          JSONB         NOT NULL  DEFAULT '{}',

  created       TIMESTAMP     NOT NULL  DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'utc'),
  updated       TIMESTAMP     NOT NULL  DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'utc'),

  UNIQUE(owner_id, name),
  UNIQUE(uuid)
);

CREATE TABLE templatemeta (
  meta_id     BIGSERIAL       PRIMARY KEY,
  template_id BIGINT          REFERENCES templates(id),
  meta_key    VARCHAR(64),
  meta_value  TEXT
);

CREATE TABLE machines (
  id            BIGSERIAL     PRIMARY KEY,
  owner_id      BIGINT        REFERENCES users(id)      NOT NULL,
  template_id   BIGINT        REFERENCES templates(id),

  uuid          VARCHAR(64),
  key           VARCHAR(128),

  name          TEXT,
  stub          VARCHAR(128)  NOT NULL,
  description   TEXT,

  stores        JSONB         NOT NULL  DEFAULT '[]',
  archives      JSONB         NOT NULL  DEFAULT '[]',
  history       JSONB         NOT NULL  DEFAULT '[]',

  meta          JSONB         NOT NULL  DEFAULT '{}',

  created       TIMESTAMP     NOT NULL  DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'utc'),
  updated       TIMESTAMP     NOT NULL  DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'utc'),

  UNIQUE(owner_id, name),
  UNIQUE(uuid)
);

CREATE TABLE machinemeta (
  meta_id     BIGSERIAL       PRIMARY KEY,
  machine_id  BIGINT          REFERENCES machines(id),
  meta_key    VARCHAR(64),
  meta_value  TEXT
);

COMMIT;
