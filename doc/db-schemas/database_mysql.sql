SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";

CREATE TABLE IF NOT EXISTS `${Prefix}attachements` (
  `postid` int(11) NOT NULL,
  `number` int(11) NOT NULL DEFAULT '0',
  `filename` varchar(256) DEFAULT NULL,
  `description` varchar(256) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `${Prefix}categories` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL,
  `short` varchar(8) DEFAULT NULL,
  `sort` smallint(6) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=65549 ;

CREATE TABLE IF NOT EXISTS `${Prefix}lastseenforum` (
  `userid` bigint(20) NOT NULL,
  `category` bigint(20) NOT NULL,
  `lastseen` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `show_cat` tinyint(4) NOT NULL DEFAULT '1',
  PRIMARY KEY (`userid`,`category`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `${Prefix}posts` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_from` int(11) NOT NULL,
  `posted` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `altered` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `textdata` text NOT NULL,
  `user_to` int(11) DEFAULT NULL,
  `category` bigint(20) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=67464 ;

CREATE TABLE IF NOT EXISTS `${Prefix}users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL,
  `password` varchar(64) NOT NULL,
  `email` varchar(1024) NOT NULL,
  `lastseen` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `lastseenforum` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `lastseenmsgs` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `active` tinyint(1) NOT NULL DEFAULT '0',
  `admin` tinyint(1) NOT NULL DEFAULT '0',
  `show_images` tinyint(1) NOT NULL DEFAULT '1',
  `theme` varchar(64) DEFAULT NULL,
  `avatar` varchar(128) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=149 ;