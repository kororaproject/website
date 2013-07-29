BEGIN;
DROP TABLE IF EXISTS canvas_account;
DROP TABLE IF EXISTS canvas_accountmembership;
DROP TABLE IF EXISTS canvas_screenshot;
DROP TABLE IF EXISTS canvas_rating;
DROP TABLE IF EXISTS canvas_arch;
DROP TABLE IF EXISTS canvas_package_ratings;
DROP TABLE IF EXISTS canvas_package_screenshots;
DROP TABLE IF EXISTS canvas_package;
DROP TABLE IF EXISTS canvas_repository;
DROP TABLE IF EXISTS canvas_comment;
DROP TABLE IF EXISTS canvas_template_ratings;
DROP TABLE IF EXISTS canvas_template_comments;
DROP TABLE IF EXISTS canvas_template;
DROP TABLE IF EXISTS canvas_templatemembership;
DROP TABLE IF EXISTS canvas_templatepackage;
DROP TABLE IF EXISTS canvas_templaterepository;
DROP TABLE IF EXISTS canvas_machine;

CREATE TABLE canvas_account (
    id            integer       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    name          varchar(64)   NOT NULL,
    uuid          varchar(64)   NOT NULL,
    description   text,
    organisation  bool          NOT NULL DEFAULT FALSE,
    gpg_private   text,
    gpg_public    text,
    created       datetime      NOT NULL,
    updated       datetime      NOT NULL
)
;

CREATE TABLE canvas_accountmembership (
    id            integer       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    account_id    integer       NOT NULL REFERENCES canvas_account (id),
    member_id     integer       NOT NULL REFERENCES canvas_account (id),
    name          varchar(64)   NOT NULL DEFAULT 'owner',
    access        integer       NOT NULL DEFAULT 15
)
;
CREATE TABLE canvas_screenshot (
    id            integer       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    image         varchar(128)  NOT NULL
)
;
CREATE TABLE canvas_rating (
    id            integer       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    account_id    integer       NOT NULL REFERENCES canvas_account (id),
    description   text,
    value         float         NOT NULL
)
;
CREATE TABLE canvas_arch (
    id integer NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    name varchar(64) NOT NULL,
    description text
)
;
CREATE TABLE canvas_package_ratings (
    id integer NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    package_id integer NOT NULL,
    rating_id integer NOT NULL REFERENCES canvas_rating (id),
    UNIQUE (package_id, rating_id)
)
;
CREATE TABLE canvas_package_screenshots (
    id integer NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    package_id integer NOT NULL,
    screenshot_id integer NOT NULL REFERENCES canvas_screenshot (id),
    UNIQUE (package_id, screenshot_id)
)
;
CREATE TABLE canvas_package (
    id            integer NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    name          varchar(256) NOT NULL,
    description   text,
    summary       text,
    license       varchar(256),
    url           varchar(256)
)
;
CREATE TABLE canvas_repository (
    id integer NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    stub varchar(256) NOT NULL,
    name varchar(256) NOT NULL,
    base_url varchar(256) NOT NULL DEFAULT '',
    gpg_key text
)
;
CREATE TABLE canvas_comment (
    id integer NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    account_id integer NOT NULL REFERENCES canvas_account (id),
    comment text
)
;
CREATE TABLE canvas_template_ratings (
    id integer NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    template_id integer NOT NULL,
    rating_id integer NOT NULL REFERENCES canvas_rating (id),
    UNIQUE (template_id, rating_id)
)
;
CREATE TABLE canvas_template_comments (
    id integer NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    template_id integer NOT NULL,
    comment_id integer NOT NULL REFERENCES canvas_comment (id),
    UNIQUE (template_id, comment_id)
)
;
CREATE TABLE canvas_template (
    id integer NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    account_id integer NOT NULL REFERENCES canvas_account(id),
    name varchar(256) NOT NULL,
    description text,
    private bool NOT NULL DEFAULT FALSE,
    parent_id integer NOT NULL DEFAULT 0
)
;
CREATE TABLE canvas_templatemembership (
    id            integer       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    template_id   integer       NOT NULL REFERENCES canvas_template (id),
    account_id    integer       NOT NULL REFERENCES canvas_account (id),
    name          varchar(64)   NOT NULL DEFAULT 'owner',
    access        integer       NOT NULL DEFAULT 15
)
;
CREATE TABLE canvas_templatepackage (
    id            integer       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    template_id   integer       NOT NULL REFERENCES canvas_template(id),
    package_id    integer       NOT NULL REFERENCES canvas_package(id),
    arch_id       integer       NOT NULL REFERENCES canvas_arch(id),
    version       varchar(64)   NOT NULL,
    rel           varchar(64)   NOT NULL,
    epoch         varchar(64)   NOT NULL,

    /* default action is set to INSTALLED only */
    action        integer       NOT NULL DEFAULT 1
)
;
CREATE TABLE canvas_templaterepository (
    id            integer       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    template_id   integer       NOT NULL REFERENCES canvas_template(id),
    repo_id       integer       NOT NULL REFERENCES canvas_repository(id),
    pref_url      varchar(256)  NOT NULL DEFAULT '',
    version       varchar(64)   NOT NULL DEFAULT 0,
    enabled       bool          NOT NULL DEFAULT TRUE,
    cost          integer       NOT NULL DEFAULT 1000,
    gpg_check     bool          NOT NULL DEFAULT TRUE
)
;
CREATE TABLE canvas_machine (
    id            integer       NOT NULL  PRIMARY KEY  AUTO_INCREMENT,
    account_id    integer       NOT NULL REFERENCES canvas_account(id),
    template_id   integer       NOT NULL REFERENCES canvas_template(id),
    name          varchar(256)  NOT NULL,
    description   text
)
;
COMMIT;
