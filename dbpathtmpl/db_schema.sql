CREATE TABLE "users" (
  "id" integer PRIMARY KEY AUTOINCREMENT,
  "name" varchar(64) NOT NULL,
  "password" varchar(512) NOT NULL,
  "active" tinyint(1) NOT NULL DEFAULT '0',
  "email" varchar(1024) NOT NULL DEFAULT '',
  "newsmail" tinyint(1) NOT NULL DEFAULT '1',
  "chronsortorder" tinyint(1) NOT NULL DEFAULT '0',
  "topiclimit" smallint NOT NULL DEFAULT 20,
  "postlimit" smallint NOT NULL DEFAULT 10,
  "printpreviewdays" smallint NOT NULL DEFAULT 7,
  "avatar" varchar(128) NOT NULL DEFAULT '',
  "avatartype" varchar(16) NOT NULL DEFAULT '',
  "admin" tinyint(1) NOT NULL DEFAULT '0',
  "bgcolor" varchar(24) NOT NULL DEFAULT '',
  "autorefresh" integer NOT NULL DEFAULT 3,
  "inchat" tinyint(1) NOT NULL DEFAULT '0',
  "lastchatid" integer NOT NULL DEFAULT '0',
  "lastseenchat" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "lastseenchatactive" timestamp NOT NULL DEFAULT CURRENT_TIMESAMP,
  "chatrefreshsecs" integer NOT NULL DEFAULT 60,
  UNIQUE ("name")
);
CREATE INDEX "user_active_ix" ON "users"("active");
CREATE INDEX "user_inchat_ix" ON "users"("inchat");

CREATE TABLE "topics" (
  "id" integer PRIMARY KEY AUTOINCREMENT,
  "userfrom" int(11) NOT NULL,
  "title" varchar(256) NOT NULL,
  "lastid" integer NOT NULL DEFAULT 0
);

CREATE TABLE "posts" (
  "id" integer PRIMARY KEY AUTOINCREMENT,
  "userfrom" int(11) NOT NULL,
  "userto" int(11),
  "topicid" int(11),
  "posted" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "altered" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "score" integer NOT NULL DEFAULT 0,
  "textdata" text NOT NULL,
  "cache" text,
  "blocked" tinyint(1) NOT NULL DEFAULT 0
);

CREATE INDEX "posts_userto_ix" ON "posts"("userto");
CREATE INDEX "posts_topicid_ix" ON "posts"("topicid");

CREATE TABLE "lastseenforum" (
  "userid" integer NOT NULL,
  "topicid" integer NOT NULL,
  "lastseen" integer NOT NULL DEFAULT '0',
  "ignore" tinyint(1) NOT NULL DEFAULT '0',
  "pin" tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY ("userid", "topicid")
);

CREATE TABLE "lastseenmsgs" (
  "userid" integer NOT NULL,
  "userfromid" integer NOT NULL,
  "lastseen" integer NOT NULL DEFAULT '0',
  "lastid" integer NOT NULL DEFAULT '0',
  PRIMARY KEY ("userid", "userfromid")
);

CREATE TABLE "attachements" (
  "id" integer PRIMARY KEY AUTOINCREMENT,
  "postid" int(11) NOT NULL,
  "filename" varchar(256),
  "content_type" varchar(128),
  "isimage" tinyint(1) NOT NULL DEFAULT '0',
  "inline" tinyint(1) NOT NULL DEFAULT '0'
);

CREATE INDEX "attachements_postid_ix" ON "attachements"("postid");

CREATE TABLE "chat" (
   "id" integer PRIMARY KEY AUTOINCREMENT,
   "userfromid" integer NOT NULL,
   "msg" text NOT NULL,
  "posted" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE "config" (
  "key" varchar(32) NOT NULL,
  "value" varchar(256) NOT NULL DEFAULT '',
  UNIQUE ("key")
);

INSERT INTO "config" ("key", "value") 
  VALUES ('cookiename','');
INSERT INTO "config" ("key", "value") 
  VALUES ('cookiesecret','');
INSERT INTO "config" ("key", "value") 
  VALUES ('cryptsalt','');
INSERT INTO "config" ("key", "value") 
  VALUES ('title','Ffc Forum');
INSERT INTO "config" ("key", "value") 
  VALUES ('sessiontimeout','432000');
INSERT INTO "config" ("key", "value") 
  VALUES ('urlshorten','30');
INSERT INTO "config" ("key", "value") 
  VALUES ('backgroundcolor','');
INSERT INTO "config" ("key", "value") 
  VALUES ('favicon','');
INSERT INTO "config" ("key", "value") 
  VALUES ('favicontype','png');
INSERT INTO "config" ("key", "value") 
  VALUES ('faviconcontenttype','image/png');
INSERT INTO "config" ("key", "value") 
  VALUES ('customcss','');
INSERT INTO "config" ("key", "value") 
  VALUES ('starttopic','0');
INSERT INTO "config" ("key", "value") 
  VALUES ('maxscore','10');
INSERT INTO "config" ("key", "value") 
  VALUES ('maxuploadsize','3');

