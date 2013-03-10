CREATE ALGORITHM=UNDEFINED DEFINER=`wwwrun`@`localhost` SQL SECURITY DEFINER VIEW `asb_posti` AS select `auf`.`id` AS `from`,`p`.`post_time` AS `posted`,`p`.`post_text` AS `text`,NULL AS `to` from ((`phpbb_posts` `p` join `phpbb_users` `u` on((`u`.`user_id` = `p`.`poster_id`))) join `asb_users` `auf` on((`u`.`username` = `auf`.`name`)));

DROP TABLE IF EXISTS `asb_users`;
CREATE TABLE `asb_users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL,
  `password` varchar(64) NOT NULL,
  `email` varchar(1024) NOT NULL,
  `lastseenforum` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `lastseenmsgs` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `active` tinyint(1) NOT NULL DEFAULT '0',
  `admin` tinyint(1) NOT NULL DEFAULT '0',
  `show_images` tiniint(1) NOT NULL DEFAULT '1',
  `theme` varchar(64),
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=137 DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `asb_posts`;
CREATE TABLE `asb_posts` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `from` int(11) NOT NULL,
  `posted` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `text` text NOT NULL,
  `to` int(11),
  `category` bigint,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=65535 DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `asb_categories`;
CREATE TABLE `asb_categories` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL,
  `short` varchar(8),
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=65535 DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `abs_lastseenforum`;
CREATE TABLE `abs_lastseenforum` (
  `userid` bigint(20) NOT NULL,
  `category` bigint(20) NOT NULL,
  `lastseen` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`userid`, `category`)
);

insert into asb_users (name, email) select substring(username, 1, 64), user_email from phpbb_users;

insert into asb_posts (`from`, posted, text) select `from`, FROM_UNIXTIME(posted), text from asb_post;

insert into asb_categories (`name`, `short`) values ('Treffen und Feten', 'party');
insert into asb_categories (`name`, `short`) values ('Musik, Filme, Serien, Kunst', 'kultur');
insert into asb_categories (`name`, `short`) values ('Links, Bilder, Videos', 'links');
insert into asb_categories (`name`, `short`) values ('Computer und Spiele', 'pc');
insert into asb_categories (`name`, `short`) values ('Aufreger', 'arrrgh');
insert into asb_categories (`name`, `short`) values ('Zitate', 'zitate');
insert into asb_categories (`name`, `short`) values ('42', '42');
insert into asb_categories (`name`, `short`) values ('Forum allgemein', 'forum');

