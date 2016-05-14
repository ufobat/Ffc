CREATE TABLE "users" (
  "id" integer PRIMARY KEY AUTOINCREMENT,
  "name" varchar(64) NOT NULL,
  "password" varchar(512) NOT NULL,
  "active" tinyint(1) NOT NULL DEFAULT '0',
  "chronsortorder" tinyint(1) NOT NULL DEFAULT '0',
  "topiclimit" smallint NOT NULL DEFAULT 20,
  "postlimit" smallint NOT NULL DEFAULT 10,
  "printpreviewdays" smallint NOT NULL DEFAULT 7,
  "avatar" varchar(128) NOT NULL DEFAULT '',
  "avatartype" varchar(16) NOT NULL DEFAULT '',
  "admin" tinyint(1) NOT NULL DEFAULT '0',
  "bgcolor" varchar(24) NOT NULL DEFAULT '',
  "usercolor" varchar(24),
  "autorefresh" integer NOT NULL DEFAULT 3,
  "hidelastseen" tinyint(1) NOT NULL DEFAULT 1,
  "inchat" tinyint(1) NOT NULL DEFAULT '0',
  "lastchatid" integer NOT NULL DEFAULT '0',
  "lastseenchat" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "lastseenchatactive" timestamp NOT NULL DEFAULT CURRENT_TIMESAMP,
  "chatrefreshsecs" integer NOT NULL DEFAULT 60,
  "lastonline" timestamp,
  "email" varchar(1024) NOT NULL DEFAULT '',
  "newsmail" tinyint(1) NOT NULL DEFAULT 1,
  "hideemail" tinyint(1) NOT NULL DEFAULT 1,
  "birthdate" varchar(10),
  "infos" varchar(1024),
  UNIQUE ("name")
);
CREATE INDEX "user_active_ix" ON "users"("active");
CREATE INDEX "user_inchat_ix" ON "users"("inchat");

CREATE TABLE "readlater" (
    "userid" int(11) NOT NULL,
    "postid" int(11) NOT NULL,
    PRIMARY KEY ("userid", "postid")
);
CREATE INDEX "readlater_userid_ix" ON "readlater"("userid");
CREATE INDEX "readlater_postid_ix" ON "readlater"("postid");

CREATE TABLE "topics" (
  "id" integer PRIMARY KEY AUTOINCREMENT,
  "userfrom" int(11) NOT NULL,
  "title" varchar(256) NOT NULL,
  "lastid" integer NOT NULL DEFAULT 0,
  "summary" varchar(256) NOT NULL DEFAULT ''
);
CREATE INDEX "topics_id" ON "topics"("id");

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
  "mailed" tinyint(1) NOT NULL DEFAULT '0',
  "ignore" tinyint(1) NOT NULL DEFAULT '0',
  "pin" tinyint(1) NOT NULL DEFAULT '0',
  "newsmail" tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY ("userid", "topicid")
);
CREATE INDEX "lsf_user_id" ON "lastseenforum"("userid");
CREATE INDEX "lsf_topics_id" ON "lastseenforum"("topicid");
CREATE INDEX "lsf_ignore_id" ON "lastseenforum"("ignore");
CREATE INDEX "lsf_pin_id" ON "lastseenforum"("pin");

CREATE TABLE "lastseenmsgs" (
  "userid" integer NOT NULL,
  "userfromid" integer NOT NULL,
  "lastseen" integer NOT NULL DEFAULT '0',
  "mailed" tinyint(1) NOT NULL DEFAULT '0',
  "lastid" integer NOT NULL DEFAULT '0',
  PRIMARY KEY ("userid", "userfromid")
);
CREATE INDEX "lsm_user_id" ON "lastseenmsgs"("userid");
CREATE INDEX "lsm_userfrom_id" ON "lastseenmsgs"("userfromid");
CREATE INDEX "lsm_lastid_id" ON "lastseenmsgs"("lastid");

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
   "posted" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
   "sysmsg" tinyint(1) NOT NULL DEFAULT 0
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

