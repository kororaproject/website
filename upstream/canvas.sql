BEGIN;
/* renamed (legacy) tables */
DROP TABLE IF EXISTS canvas_account;
DROP TABLE IF EXISTS canvas_accountmembership;
DROP TABLE IF EXISTS canvas_screenshot;
DROP TABLE IF EXISTS canvas_package_screenshots;
DROP TABLE IF EXISTS canvas_postvote;

/* rebuild all tables from scratch */
DROP TABLE IF EXISTS canvas_user;
DROP TABLE IF EXISTS canvas_usermeta;
DROP TABLE IF EXISTS canvas_usermembership;
DROP TABLE IF EXISTS canvas_arch;
DROP TABLE IF EXISTS canvas_rating;
DROP TABLE IF EXISTS canvas_image;
DROP TABLE IF EXISTS canvas_package;
DROP TABLE IF EXISTS canvas_packagedetails;
DROP TABLE IF EXISTS canvas_package_ratings;
DROP TABLE IF EXISTS canvas_package_images;
DROP TABLE IF EXISTS canvas_repository;
DROP TABLE IF EXISTS canvas_repositorydetails;
DROP TABLE IF EXISTS canvas_comment;
DROP TABLE IF EXISTS canvas_template_ratings;
DROP TABLE IF EXISTS canvas_template_comments;
DROP TABLE IF EXISTS canvas_template;
DROP TABLE IF EXISTS canvas_templatemembership;
DROP TABLE IF EXISTS canvas_templatepackage;
DROP TABLE IF EXISTS canvas_templaterepository;
DROP TABLE IF EXISTS canvas_machine;

DROP TABLE IF EXISTS canvas_post;
DROP TABLE IF EXISTS canvas_postmeta;
DROP TABLE IF EXISTS canvas_post_vote;
DROP TABLE IF EXISTS canvas_postview;
DROP TABLE IF EXISTS canvas_vote;

DROP TABLE IF EXISTS canvas_tag;
DROP TABLE IF EXISTS canvas_post_tag;

DROP TABLE IF EXISTS canvas_donation;


CREATE TABLE canvas_user (
  id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
  username      VARCHAR(64)   NOT NULL,
  password      VARCHAR(64)   NOT NULL,

  realname      VARCHAR(128)  NOT NULL,
  email         VARCHAR(128)  NOT NULL,

  description   TEXT,

  /*
  ** pending, active, suspended, closed
  */

  status        VARCHAR(16)   NOT NULL  DEFAULT 'pending',

  /* is this user an organisation  */
  organisation  BOOL          NOT NULL  DEFAULT FALSE,

  gpg_private   TEXT,
  gpg_public    TEXT,

  access        INTEGER       NOT NULL  DEFAULT 0,

  created       DATETIME      NOT NULL,
  updated       DATETIME      NOT NULL,

  UNIQUE (username),
  UNIQUE (email)
);

CREATE TABLE canvas_usermeta (
  meta_id     BIGINT(20)      NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
  user_id     INTEGER         NOT NULL  REFERENCES canvas_user (id),
  meta_key    VARCHAR(64)               DEFAULT  NULL,
  meta_value  LONGTEXT                  DEFAULT  NULL
);



CREATE TABLE canvas_usermembership (
  id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
  user_id       INTEGER       NOT NULL  REFERENCES canvas_user (id),
  member_id     INTEGER       NOT NULL  REFERENCES canvas_user (id),

  /* default membership of a user is an owner */
  name          VARCHAR(64)   NOT NULL  DEFAULT 'owner',

  /* default access is write (1) */
  access        INTEGER       NOT NULL  DEFAULT 1,

  created       DATETIME      NOT NULL,
  updated       DATETIME      NOT NULL
);

CREATE TABLE canvas_image (
    id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    image         VARCHAR(128)  NOT NULL,

    /* default image type is unknown (0) */
    type          INTEGER       NOT NULL  DEFAULT 0,

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL
);

CREATE TABLE canvas_rating (
    id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    user_id       INTEGER       NOT NULL  REFERENCES canvas_user(id),
    description   TEXT,
    value         FLOAT         NOT NULL,

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL
);

CREATE TABLE canvas_arch (
    id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    name          VARCHAR(64)   NOT NULL,
    description   TEXT,

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL
);

CREATE TABLE canvas_package_ratings (
    id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    package_id    INTEGER       NOT NULL  REFERENCES canvas_package(id),
    rating_id     INTEGER       NOT NULL  REFERENCES canvas_rating(id),
    tags          TEXT,

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL,

    UNIQUE (package_id, rating_id)
);

CREATE TABLE canvas_package_images (
    id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    package_id    INTEGER       NOT NULL  REFERENCES canvas_package(id),
    image_id      INTEGER       NOT NULL  REFERENCES canvas_image(id),
    tags          TEXT,

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL,

    UNIQUE (package_id, image_id)
);

CREATE TABLE canvas_package (
    id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    name          VARCHAR(256)  NOT NULL,
    description   TEXT,
    summary       TEXT,
    license       VARCHAR(256),
    url           VARCHAR(256),
    category      VARCHAR(256),
    type          INTEGER,
    tags          TEXT,

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL
);

CREATE TABLE canvas_repository (
    id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    stub          VARCHAR(256)  NOT NULL,

    gpg_key       TEXT,

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL
);

CREATE TABLE canvas_repositorydetails (
    id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    repo_id       INTEGER       NOT NULL  REFERENCES canvas_repository(id),
    name          VARCHAR(256)  NOT NULL,

    version       INTEGER       NOT NULL,
    arch_id       INTEGER       NOT NULL  REFERENCES canvas_arch(id),

    base_url      VARCHAR(256)  NOT NULL  DEFAULT '',
    mirror_url    VARCHAR(256)  NOT NULL  DEFAULT '',

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL
);

CREATE TABLE canvas_packagedetails (
    id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    package_id    INTEGER       NOT NULL  REFERENCES canvas_package(id),
    arch_id       INTEGER       NOT NULL  REFERENCES canvas_arch(id),
    epoch         INTEGER,
    version       VARCHAR(64),
    rel           VARCHAR(64),

    install_size  INTEGER       NOT NULL  DEFAULT 0,
    package_size  INTEGER       NOT NULL  DEFAULT 0,

    /* time stored as unix epoch */
    build_time    INTEGER       NOT NULL,

    /* time stored as unix epoch */
    file_time     INTEGER       NOT NULL,

    repo_id       INTEGER       NOT NULL  REFERENCES canvas_repository(id),

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL
);

CREATE TABLE canvas_comment (
    id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    user_id       INTEGER       NOT NULL  REFERENCES canvas_user (id),
    comment       TEXT,

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL
);

CREATE TABLE canvas_template_ratings (
    id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    template_id   INTEGER       NOT NULL,
    rating_id     INTEGER       NOT NULL  REFERENCES canvas_rating (id),

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL,

    UNIQUE (template_id, rating_id)
);

CREATE TABLE canvas_template_comments (
    id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    template_id   INTEGER       NOT NULL,
    comment_id    INTEGER       NOT NULL  REFERENCES canvas_comment (id),

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL,

    UNIQUE (template_id, comment_id)
);

CREATE TABLE canvas_template (
    id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    user_id       INTEGER       NOT NULL  REFERENCES canvas_user(id),
    name          VARCHAR(256)  NOT NULL,
    description   TEXT,
    private       BOOL          NOT NULL  DEFAULT FALSE,
    parent_id     INTEGER       NOT NULL  DEFAULT 0,

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL
);

CREATE TABLE canvas_templatemembership (
    id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    template_id   INTEGER       NOT NULL  REFERENCES canvas_template (id),
    user_id       INTEGER       NOT NULL  REFERENCES canvas_user (id),
    name          VARCHAR(64)   NOT NULL  DEFAULT 'owner',
    access        INTEGER       NOT NULL  DEFAULT 15,

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL
);

CREATE TABLE canvas_templatepackage (
    id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    template_id   INTEGER       NOT NULL  REFERENCES canvas_template(id),
    package_id    INTEGER       NOT NULL  REFERENCES canvas_package(id),
    arch_id       INTEGER       NOT NULL  REFERENCES canvas_arch(id),
    version       VARCHAR(64)   NOT NULL,
    rel           VARCHAR(64)   NOT NULL,
    epoch         VARCHAR(64)   NOT NULL,

    /* default action is set to INSTALLED only */
    action        INTEGER       NOT NULL DEFAULT 1,

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL
);

CREATE TABLE canvas_templaterepository (
    id            INTEGER       NOT NULL PRIMARY KEY  AUTO_INCREMENT,
    template_id   INTEGER       NOT NULL REFERENCES canvas_template(id),
    repo_id       INTEGER       NOT NULL REFERENCES canvas_repository(id),
    pref_url      VARCHAR(256)  NOT NULL DEFAULT '',
    version       VARCHAR(64)   NOT NULL DEFAULT 0,
    enabled       BOOL          NOT NULL DEFAULT TRUE,
    cost          INTEGER       NOT NULL DEFAULT 1000,
    gpg_check     BOOL          NOT NULL DEFAULT TRUE,

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL
);

CREATE TABLE canvas_machine (
    id            INTEGER       NOT NULL PRIMARY KEY  AUTO_INCREMENT,
    user_id       INTEGER       NOT NULL REFERENCES canvas_user(id),
    template_id   INTEGER       NOT NULL REFERENCES canvas_template(id),
    name          VARCHAR(256)  NOT NULL,
    description   TEXT,

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL
);




/*
** KORORA CANVAS - POST / ENGAGE STRUCTURES
*/

/*


*/
CREATE TABLE canvas_post (
  id            INTEGER               NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
  author_id     INTEGER UNSIGNED      NOT NULL  REFERENCES canvas_user(id),

  parent_id     INTEGER UNSIGNED      NOT NULL  DEFAULT 0,

  /* encrypt the post with a password */
  password      VARCHAR(32)           NOT NULL,

  /* types: news, question, problem, thanks, idea */
  type          VARCHAR(16)           NOT NULL,

  /*
  ** news: draft, publish
  ** question: answered, waiting
  ** problem: waiting, known, progress, not, solved
  ** thanks: n/a
  ** idea: considered, declined, planned, progress, complete, feedback
  ** reply: standard, answer
  */
  status        VARCHAR(32)           NOT NULL,

  /* name of the post */
  name          VARCHAR(200)          NOT NULL  DEFAULT '',

  /* name of the post */
  title         TEXT                  NOT NULL  DEFAULT '',

  /* optional introductory paragraph of post */
  excerpt       TEXT                  NOT NULL  DEFAULT '',

  /* primary content of post */
  content       TEXT                  NOT NULL  DEFAULT '',

  /* provides an selectable prioritisation for post order */
  menu_order    INTEGER UNSIGNED      NOT NULL  DEFAULT 0,

  /*
  ** open - replies are enabled
  ** closed - post is closed from replies
  */
  reply_status  VARCHAR(16)           NOT NULL  DEFAULT 'open',
  reply_count   INTEGER UNSIGNED      NOT NULL  DEFAULT 0,

  created       DATETIME              NOT NULL,
  updated       DATETIME              NOT NULL
);

CREATE TABLE canvas_postmeta (
  meta_id     BIGINT(20)      NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
  post_id     INTEGER         NOT NULL  REFERENCES canvas_post (id),
  meta_key    VARCHAR(64)               DEFAULT  NULL,
  meta_value  LONGTEXT                  DEFAULT  NULL
);


CREATE TABLE canvas_tag (
  id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
  name          VARCHAR(255)  NOT NULL,

  created       DATETIME      NOT NULL
);

CREATE TABLE canvas_post_tag (
  tag_id        INTEGER       NOT NULL REFERENCES canvas_tag(id),
  post_id       INTEGER       NOT NULL REFERENCES canvas_post(id),
  created       DATETIME      NOT NULL,

  PRIMARY KEY (tag_id, post_id)
);

CREATE TABLE canvas_vote (
  id            INTEGER   NOT NULL  PRIMARY KEY  AUTO_INCREMENT,

  /* value to apply to vote tally */
  cast_value    INTEGER   NOT NULL  DEFAULT 0,

  /* value to apply to the voter */
  caster_value  INTEGER   NOT NULL  DEFAULT 0
);

CREATE TABLE canvas_post_vote (
  post_id       INTEGER       NOT NULL REFERENCES canvas_post(id),
  user_id       INTEGER       NOT NULL REFERENCES canvas_user(id),
  vote_id       INTEGER       NOT NULL REFERENCES canvas_vote(id),
  created       DATETIME      NOT NULL,

  PRIMARY KEY (post_id, user_id, vote_id)
);

CREATE TABLE canvas_postview (
  post_id       INTEGER       NOT NULL REFERENCES canvas_post(id),
  ip            VARCHAR(128),
  user_agent    VARCHAR(256),
  created       DATETIME      NOT NULL
);


CREATE TABLE canvas_donation (
  id              BIGINT(20)    NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
  payment_id      VARCHAR(64)   NOT NULL,
  transaction_id  VARCHAR(64)   NOT NULL,

  name            VARCHAR(64)             DEFAULT  NULL,
  email           VARCHAR(128)            DEFAULT  NULL,

  amount          VARCHAR(16)             DEFAULT  NULL,

  paypal_raw      TEXT                    DEFAULT  NULL,

  created         DATETIME      NOT NULL
);


COMMIT;
