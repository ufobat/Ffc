CREATE ALGORITHM=UNDEFINED DEFINER=`wwwrun`@`localhost` SQL SECURITY DEFINER VIEW `asb_posti` AS select `auf`.`id` AS `from`,`p`.`post_time` AS `posted`,`p`.`post_text` AS `text`,NULL AS `to` from ((`phpbb_posts` `p` join `phpbb_users` `u` on((`u`.`user_id` = `p`.`poster_id`))) join `asb_users` `auf` on((`u`.`username` = `auf`.`name`)));

CREATE TABLE `asb_users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL,
  `password` varchar(64) NOT NULL,
  `email` varchar(1024) NOT NULL,
  `lastseen` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=137 DEFAULT CHARSET=utf8;

CREATE TABLE `asb_posts` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `from` int(11) NOT NULL,
  `posted` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' ON UPDATE CURRENT_TIMESTAMP,
  `text` text NOT NULL,
  `to` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=65535 DEFAULT CHARSET=utf8;

insert into asb_users (name, email) select substring(username, 1, 64), user_email from phpbb_users;

insert into asb_posts (`from`, posted, text) select `from`, FROM_UNIXTIME(posted), text from asb_posti;

