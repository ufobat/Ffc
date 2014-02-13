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

CREATE VIEW "${Prefix}vw_posts" AS
  SELECT p.id AS id, p.textdata as textdata, p.posted as posted, 
       c.name as cat, COALESCE(c.short,'') as catshort,
       f.id as f_id, f.name as f_name, f.active as f_active,
       t.id as t_id, t.name as t_name, t.active as t_active,
       f.avatar as f_avatar,
       CASE WHEN f.id = t.id OR f.id = u.id
            THEN 0
            ELSE CASE WHEN t.id IS NOT NULL
                      THEN CASE WHEN p.altered >= t.lastseenmsgs THEN 1 ELSE 0 END
                      ELSE CASE WHEN p.category IS NULL
                                THEN CASE WHEN p.altered >= u.lastseenforum THEN 1 ELSE 0 END
                                ELSE CASE WHEN p.altered >= l.lastseen THEN 1 ELSE 0 END
                           END
                 END
       END as new, u.id as user_id
  FROM             ${Prefix}posts         p
  INNER       JOIN ${Prefix}users         u
  INNER       JOIN ${Prefix}users         f ON f.id = p.user_from
  LEFT  OUTER JOIN ${Prefix}users         t ON t.id = p.user_to
  LEFT  OUTER JOIN ${Prefix}categories    c ON c.id = p.category
  LEFT  OUTER JOIN ${Prefix}lastseenforum l ON c.id = l.category AND l.userid = u.id
  ORDER BY p.id DESC
;
