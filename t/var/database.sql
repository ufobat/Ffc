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
  UNIQUE ("name")
);

CREATE TABLE "${Prefix}posts" (
  "id" integer PRIMARY KEY AUTOINCREMENT,
  "user_from" int(11) NOT NULL,
  "posted" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "textdata" text NOT NULL,
  "user_to" int(11),
  "category" bigint
);

CREATE TABLE "${Prefix}categories" (
  "id" integer PRIMARY KEY AUTOINCREMENT,
  "name" varchar(64) NOT NULL,
  "short" varchar(8),
  UNIQUE ("name")
);

CREATE TABLE "${Prefix}lastseenforum" (
  "userid" integer NOT NULL,
  "category" integer NOT NULL,
  "lastseen" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("userid", "category")
);

/*
DROP TABLE IF EXISTS `${Prefix}users`;
CREATE TABLE `${Prefix}users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL,
  `password` varchar(64) NOT NULL,
  `email` varchar(1024) NOT NULL,
  `lastseen` timestamp,
  `lastseenforum` timestamp,
  `lastseenmsgs` timestamp,
  `active` tinyint(1) NOT NULL DEFAULT '0',
  `admin` tinyint(1) NOT NULL DEFAULT '0',
  `show_images` tinyint(1) NOT NULL DEFAULT '1',
  `theme` varchar(64),
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=137 DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `${Prefix}posts`;
CREATE TABLE `${Prefix}posts` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_from` int(11) NOT NULL,
  `posted` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `textdata` text NOT NULL,
  `user_to` int(11),
  `category` bigint,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=65535 DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `${Prefix}categories`;
CREATE TABLE `${Prefix}categories` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL,
  `short` varchar(8),
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=65535 DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `${Prefix}lastseenforum`;
CREATE TABLE `${Prefix}lastseenforum` (
  `userid` bigint(20) NOT NULL,
  `category` bigint(20) NOT NULL,
  `lastseen` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`userid`, `category`)
);
*/
