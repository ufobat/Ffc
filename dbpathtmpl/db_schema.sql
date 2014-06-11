CREATE TABLE "users" (
  "id" integer PRIMARY KEY AUTOINCREMENT,
  "name" varchar(64) NOT NULL,
  "password" varchar(512) NOT NULL,
  "lastseen"  timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "active" tinyint(1) NOT NULL DEFAULT '0',
  "email" varchar(1024) NOT NULL DEFAULT '',
  "avatar" varchar(128) NOT NULL DEFAULT '',
  "admin" tinyint(1) NOT NULL DEFAULT '0',
  "bgcolor" varchar(24) NOT NULL DEFAULT '',
  UNIQUE ("name")
);

CREATE TABLE "topics" (
  "id" integer PRIMARY KEY AUTOINCREMENT,
  "userfrom" int(11) NOT NULL,
  "title" varchar(256) NOT NULL
);

CREATE TABLE "posts" (
  "id" integer PRIMARY KEY AUTOINCREMENT,
  "userfrom" int(11) NOT NULL,
  "userto" int(11),
  "topicid" int(11),
  "posted" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "altered" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "textdata" text NOT NULL,
  "cache" text
);

CREATE TABLE "lastseenforum" (
  "userid" integer NOT NULL,
  "topicid" integer NOT NULL,
  "lastseen" integer NOT NULL DEFAULT '0',
  PRIMARY KEY ("userid", "topicid")
);

CREATE TABLE "lastseenmsgs" (
  "userid" integer NOT NULL,
  "userfromid" integer NOT NULL,
  "lastseen" integer NOT NULL DEFAULT '0',
  PRIMARY KEY ("userid", "userfromid")
);

CREATE TABLE "attachements" (
  "id" integer PRIMARY KEY AUTOINCREMENT,
  "postid" int(11) NOT NULL,
  "filename" varchar(256)
);

CREATE TABLE "config" (
  "key" varchar(32) NOT NULL,
  "value" varchar(256) NOT NULL DEFAULT '',
  UNIQUE ("key")
);

INSERT INTO "config" ("key", "value") 
  VALUES ('cookiename','Ffc_Forum');
INSERT INTO "config" ("key", "value") 
  VALUES ('cookiesecret','');
INSERT INTO "config" ("key", "value") 
  VALUES ('cryptsalt','');
INSERT INTO "config" ("key", "value") 
  VALUES ('postlimit','7');
INSERT INTO "config" ("key", "value") 
  VALUES ('topiclimit','21');
INSERT INTO "config" ("key", "value") 
  VALUES ('title','Ffc Forum');
INSERT INTO "config" ("key", "value") 
  VALUES ('sessiontimeout','432000');
INSERT INTO "config" ("key", "value") 
  VALUES ('commoncattitle','Allgemein');
INSERT INTO "config" ("key", "value") 
  VALUES ('urlshorten','30');
INSERT INTO "config" ("key", "value") 
  VALUES ('backgroundcolor','');
INSERT INTO "config" ("key", "value") 
  VALUES ('fixbackgroundcolor','0');
INSERT INTO "config" ("key", "value") 
  VALUES ('favicon','');

