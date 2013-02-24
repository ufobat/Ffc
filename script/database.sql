CREATE TABLE "${Prefix}users" (
  "id" int(11) NOT NULL AUTO_INCREMENT,
  "name" varchar(64) NOT NULL,
  "password" varchar(64) NOT NULL,
  "email" varchar(1024) NOT NULL,
  "lastseenmsgs" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "lastseenforum" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "active" tinyint(1) NOT NULL DEFAULT '0',
  "admin" tinyint(1) NOT NULL DEFAULT '0',
  "show_images" tiniint(1) NOT NULL DEFAULT '1',
  "theme" varchar(64),
  PRIMARY KEY ("id"),
  UNIQUE KEY "u_name" ("name")
);

CREATE TABLE "${Prefix}posts" (
  "id" bigint(20) NOT NULL AUTO_INCREMENT,
  "from" int(11) NOT NULL,
  "posted" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  "text" text NOT NULL,
  "to" int(11) NOT NULL,
  "category" bigint,
  PRIMARY KEY ("id")
);

CREATE TABLE "${Prefix}categories" (
  "id" bigint(20) NOT NULL AUTO_INCREMENT,
  "name" varchar(64) NOT NULL,
  "short" varchar(8),
  PRIMARY KEY ("id"),
  UNIQUE KEY "u_name" ("name")
);

CREATE TABLE "${Prefix}lastseenforum" (
  "userid" bigint(20) NOT NULL,
  "category" bigint(20) NOT NULL,
  "lastseen" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("userid", "category")
);

