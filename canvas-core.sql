BEGIN;
/* rebuild all tables from scratch */
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
DROP TABLE IF EXISTS canvas_template_map;
DROP TABLE IF EXISTS canvas_templatemembership;
DROP TABLE IF EXISTS canvas_templatepackage;
DROP TABLE IF EXISTS canvas_templaterepository;
DROP TABLE IF EXISTS canvas_machine;

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

  stub          VARCHAR(128)  NOT NULL,
  name          VARCHAR(256)  NOT NULL,
  description   TEXT,

  /*
  ** default action is set to explicitly install
  ** bit 0: share with template owner (default)
  ** bit 1: share with template members
  ** bit 2: share with everybody
  */
  shared        INTEGER       NOT NULL  DEFAULT 1,

  /*
  ** 0 = stand alone
  ** 1 = dependency only
  */
  build_type    INTEGER       NOT NULL  DEFAULT 0,

  created       DATETIME      NOT NULL,
  updated       DATETIME      NOT NULL
);

CREATE TABLE canvas_template_map (
  parent_id       INTEGER       NOT NULL REFERENCES canvas_template(id),
  child_id        INTEGER       NOT NULL REFERENCES canvas_template(id),

  priority        INTEGER       NOT NULL DEFAULT 1000,
};

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

    repo_name     VARCHAR(128)  NOT NULL,

    /* nevra details of package */
    name          VARCHAR(128)  NOT NULL,
    arch          VARCHAR(16)   NOT NULL,
    version       VARCHAR(64)   NOT NULL,
    rel           VARCHAR(64)   NOT NULL,
    epoch         VARCHAR(64)   NOT NULL,

    /*
    ** default action is set to explicitly install
    ** bit 0: explictly install
    ** bit 1: explictly uninstall
    ** bit 2: pin arch
    ** bit 3: pin release
    ** bit 4: pin version
    ** bit 5: pin epoch
    ** bit 6: lock installation
    ** bit 7: lock uninstallation
    */
    action        INTEGER       NOT NULL DEFAULT 1,

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL
);

CREATE TABLE canvas_templaterepository (
    id            INTEGER       NOT NULL PRIMARY KEY  AUTO_INCREMENT,
    template_id   INTEGER       NOT NULL REFERENCES canvas_template(id),

    name          VARCHAR(128)  NOT NULL,
    stub          VARCHAR(128)  NOT NULL,

    gpg_key       TEXT,

    baseurl       VARCHAR(256)  NOT NULL DEFAULT '',
    mirrorlist    VARCHAR(256)  NOT NULL DEFAULT '',
    metalink      VARCHAR(256)  NOT NULL DEFAULT '',

    exclude       TEXT          NOT NULL DEFAULT '',

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

COMMIT;
