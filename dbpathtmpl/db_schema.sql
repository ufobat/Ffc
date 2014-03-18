CREATE TABLE "users" (
  "id" integer PRIMARY KEY AUTOINCREMENT,
  "name" varchar(64) NOT NULL,
  "password" varchar(512) NOT NULL,
  "lastseen"  timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "lastseenmsgs"  integer NOT NULL DEFAULT '0',
  "lastseenforum" integer NOT NULL DEFAULT '0',
  "active" tinyint(1) NOT NULL DEFAULT '0',
  "email" varchar(1024) NOT NULL DEFAULT '',
  "avatar" varchar(128) NOT NULL DEFAULT '',
  "admin" tinyint(1) NOT NULL DEFAULT '0',
  "bgcolor" varchar(24) NOT NULL DEFAULT '',
  UNIQUE ("name")
);

CREATE TABLE "posts" (
  "id" integer PRIMARY KEY AUTOINCREMENT,
  "user_from" int(11) NOT NULL,
  "posted" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "altered" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "textdata" text NOT NULL,
  "user_to" integer,
  "category" integer
);

CREATE TABLE "categories" (
  "id" integer PRIMARY KEY AUTOINCREMENT,
  "name" varchar(16) NOT NULL,
  UNIQUE ("name")
);

CREATE TABLE "lastseenforum" (
  "userid" integer NOT NULL,
  "category" integer NOT NULL,
  "lastseen" integer NOT NULL DEFAULT '0',
  "show_cat" smallint NOT NULL DEFAULT '1',
  PRIMARY KEY ("userid", "category")
);

CREATE TABLE "lastseenmsgs" (
  "userid" integer NOT NULL,
  "user_from_id" integer NOT NULL,
  "lastseen" integer NOT NULL DEFAULT '0',
  PRIMARY KEY ("userid", "user_from_id")
);

CREATE TABLE "attachements" (
  "postid" int(11) NOT NULL,
  "number" integer not null default 0,
  "filename" varchar(256)
);

