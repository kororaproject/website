BEGIN;
/* renamed (legacy) tables */
DROP TABLE IF EXISTS canvas_account;
DROP TABLE IF EXISTS canvas_accountmembership;
DROP TABLE IF EXISTS canvas_screenshot;
DROP TABLE IF EXISTS canvas_package_screenshots;

/* rebuild all tables from scratch */
DROP TABLE IF EXISTS canvas_user;
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

CREATE TABLE canvas_user (
    id            INTEGER       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    name          VARCHAR(64)   NOT NULL,
    uuid          VARCHAR(64)   NOT NULL,
    description   TEXT,

    /* is this user an organisation  */
    organisation  BOOL          NOT NULL  DEFAULT FALSE,

    gpg_private   TEXT,
    gpg_public    TEXT,

    access        INTEGER       NOT NULL  DEFAULT 1,

    created       DATETIME      NOT NULL,
    updated       DATETIME      NOT NULL
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

COMMIT;
