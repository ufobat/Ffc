CREATE TABLE `newstart_users` (
  `id` integer,
  `name` varchar(64) NOT NULL,
  `password` varchar(512) NOT NULL,
  `lastseen`  timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `active` tinyint(1) NOT NULL DEFAULT '0',
  `email` varchar(1024) NOT NULL DEFAULT '',
  `avatar` varchar(128) NOT NULL DEFAULT '',
  `admin` tinyint(1) NOT NULL DEFAULT '0',
  `bgcolor` varchar(24) NOT NULL DEFAULT '',
);

CREATE TABLE `newstart_topics` (
  `id` integer,
  `userfrom` int(11) NOT NULL,
  `posted` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `altered` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `title` varchar(256) NOT NULL
);

CREATE TABLE `newstart_posts` (
  `id` integer,
  `userfrom` int(11) NOT NULL,
  `userto` int(11),
  `topicid` int(11),
  `posted` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `altered` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `textdata` text NOT NULL,
  `cache` text
);

CREATE TABLE `newstart_attachements` (
  `id` integer,
  `postid` int(11) NOT NULL,
  `filename` varchar(256)
);

