CREATE TABLE "${Prefix}users" (
  "id" integer PRIMARY KEY AUTOINCREMENT,
  "name" varchar(64) NOT NULL,
  "password" varchar(64) NOT NULL,
  "email" varchar(1024),
  "lastseen" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "lastseenmsgs" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "lastseenforum" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "active" tinyint(1) NOT NULL DEFAULT '0',
  "admin" tinyint(1) NOT NULL DEFAULT '0',
  "show_images" tiniint(1) NOT NULL DEFAULT '1',
  "theme" varchar(64),
  "avatar" varchar(128),
  "bgcolor" varchar(24) DEFAULT '',
  "fontsize" integer DEFAULT 0,
  UNIQUE ("name")
);

CREATE TABLE "${Prefix}posts" (
  "id" integer PRIMARY KEY AUTOINCREMENT,
  "user_from" int(11) NOT NULL,
  "posted" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "altered" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "textdata" text NOT NULL,
  "user_to" int(11),
  "category" bigint
);

CREATE TABLE "${Prefix}categories" (
  "id" integer PRIMARY KEY AUTOINCREMENT,
  "name" varchar(64) NOT NULL,
  "short" varchar(8),
  "sort" smallint not null default 0,
  UNIQUE ("name")
);

CREATE TABLE "${Prefix}lastseenforum" (
  "userid" integer NOT NULL,
  "category" integer NOT NULL,
  "lastseen" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "show_cat" smallint NOT NULL DEFAULT 1,
  PRIMARY KEY ("userid", "category")
);

CREATE TABLE "${Prefix}attachements" (
  "postid" int(11) NOT NULL,
  "number" integer not null default 0,
  "filename" varchar(256),
  "description" varchar(256)
);
