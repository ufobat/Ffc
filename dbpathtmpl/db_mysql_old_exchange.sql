/************************************************************
*** Benutzertabelle *****************************************
************************************************************/
DROP TABLE IF EXISTS `newstart_users`;
CREATE TABLE `newstart_users` (
  `id` integer,
  `name` varchar(64) NOT NULL,
  `password` varchar(512) NOT NULL DEFAULT '',
  `lastseen`  timestamp,
  `active` tinyint(1) NOT NULL DEFAULT '0',
  `email` varchar(1024) NOT NULL DEFAULT '',
  `avatar` varchar(128) NOT NULL DEFAULT '',
  `admin` tinyint(1) NOT NULL DEFAULT '0',
  `bgcolor` varchar(24) NOT NULL DEFAULT ''
);
INSERT INTO `newstart_users` 
        (`id`, `name`, `password`, `lastseen`, `active`, `email`, `avatar`, `admin`, `bgcolor`)
    SELECT 
        `id`, `name`, `password`, `lastseen`, `active`, `email`, `avatar`, `admin`, `bgcolor`
        FROM `ffc_users`;

/************************************************************
*** Überschriftentabelle ************************************
************************************************************/
DROP TABLE IF EXISTS `newstart_topics`;
CREATE TABLE `newstart_topics` (
  `id` integer,
  `userfrom` int(11) NOT NULL,
  `title` varchar(256) NOT NULL
);
INSERT INTO `newstart_topics`
        (`id`, `title`, `userfrom`)
    SELECT
        `id`, `name`, 1
        FROM `ffc_categories`;

/************************************************************
*** Beitragstabelle *****************************************
************************************************************/
DROP TABLE IF EXISTS `newstart_posts`;
CREATE TABLE `newstart_posts` (
  `id` integer,
  `userfrom` int(11) NOT NULL,
  `userto` int(11),
  `topicid` int(11),
  `posted` timestamp,
  `altered` timestamp,
  `textdata` text NOT NULL,
  `cache` text
);
INSERT INTO `newstart_posts`
        (`id`, `userfrom`, `userto`, `topicid`, `posted`, `altered`, `textdata`, `cache`)
    SELECT
        `id`, `user_from`, `user_to`, `category`, `posted`, `altered`, `textdata`, `textdata`
         FROM `ffc_posts`;

/************************************************************
*** Daetianhangstabelle *************************************
************************************************************/
DROP TABLE IF EXISTS `newstart_attachements`;
CREATE TABLE `newstart_attachements` (
  `postid` int(11) NOT NULL,
  `filename` varchar(256)
);
INSERT INTO `newstart_attachements`
        (`postid`, `filename`)
    SELECT `postid`, `filename`
        FROM `ffc_attachements`;

