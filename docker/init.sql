-- 4chan Yotsuba imageboard schema

USE yotsuba_global;

-- Board directory
CREATE TABLE IF NOT EXISTS `boardlist` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `dir` varchar(10) NOT NULL DEFAULT '',
  `name` varchar(64) NOT NULL DEFAULT '',
  `db` int(11) NOT NULL DEFAULT 1,
  `title` text,
  `description` text,
  `hidden` tinyint(1) DEFAULT 0,
  `section` int(11) DEFAULT 1,
  `max_image_width` int(11) DEFAULT 0,
  `max_image_height` int(11) DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `dir` (`dir`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed a test board
INSERT INTO `boardlist` (`dir`, `name`, `db`, `title`, `description`) VALUES
('b', 'Random', 1, 'Random', 'Anime/Random');

-- Per-board post table (named after board dir, e.g. 'b')
-- Posts for board 'b'
CREATE TABLE IF NOT EXISTS `b` (
  `no` int(11) NOT NULL AUTO_INCREMENT,
  `resto` int(11) NOT NULL DEFAULT 0,
  `root` int(11) NOT NULL DEFAULT 0,
  `now` varchar(32) NOT NULL DEFAULT '',
  `time` int(11) NOT NULL DEFAULT 0,
  `last_modified` int(11) NOT NULL DEFAULT 0,
  `name` varchar(64) NOT NULL DEFAULT '',
  `sub` varchar(128) NOT NULL DEFAULT '',
  `com` text NOT NULL,
  `host` varchar(255) NOT NULL DEFAULT '',
  `pwd` varchar(32) NOT NULL DEFAULT '',
  `4pass_id` varchar(64) NOT NULL DEFAULT '',
  `email` varchar(128) NOT NULL DEFAULT '',
  `filename` varchar(255) NOT NULL DEFAULT '',
  `ext` varchar(8) NOT NULL DEFAULT '',
  `w` int(11) NOT NULL DEFAULT 0,
  `h` int(11) NOT NULL DEFAULT 0,
  `tn_w` int(11) NOT NULL DEFAULT 0,
  `tn_h` int(11) NOT NULL DEFAULT 0,
  `tim` varchar(32) NOT NULL DEFAULT '',
  `md5` varchar(32) NOT NULL DEFAULT '',
  `tmd5` varchar(32) NOT NULL DEFAULT '',
  `fsize` int(11) NOT NULL DEFAULT 0,
  `filedeleted` tinyint(1) NOT NULL DEFAULT 0,
  `id` varchar(16) NOT NULL DEFAULT '',
  `capcode` varchar(8) NOT NULL DEFAULT '',
  `country` varchar(2) NOT NULL DEFAULT '',
  `sticky` tinyint(1) NOT NULL DEFAULT 0,
  `permasage` tinyint(1) NOT NULL DEFAULT 0,
  `permaage` tinyint(1) NOT NULL DEFAULT 0,
  `closed` tinyint(1) NOT NULL DEFAULT 0,
  `archived` tinyint(1) NOT NULL DEFAULT 0,
  `undead` tinyint(1) NOT NULL DEFAULT 0,
  `since4pass` tinyint(1) NOT NULL DEFAULT 0,
  `m_img` tinyint(1) NOT NULL DEFAULT 0,
  `upvotes` int(11) NOT NULL DEFAULT 0,
  `downvotes` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`no`),
  KEY `resto` (`resto`),
  KEY `root` (`root`),
  KEY `time` (`time`),
  KEY `sticky` (`sticky`),
  KEY `archived` (`archived`),
  KEY `last_modified` (`last_modified`),
  KEY `filedeleted` (`filedeleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Mod / staff users
CREATE TABLE IF NOT EXISTS `mod_users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(64) NOT NULL DEFAULT '',
  `password` varchar(128) NOT NULL DEFAULT '',
  `level` int(11) NOT NULL DEFAULT 0,
  `flags` varchar(255) NOT NULL DEFAULT '',
  `allow` tinyint(1) NOT NULL DEFAULT 1,
  `password_expired` tinyint(1) NOT NULL DEFAULT 0,
  `signed_agreement` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Banned users
CREATE TABLE IF NOT EXISTS `banned_users` (
  `no` int(11) NOT NULL AUTO_INCREMENT,
  `global` tinyint(1) NOT NULL DEFAULT 0,
  `board` varchar(10) NOT NULL DEFAULT '',
  `host` varchar(255) NOT NULL DEFAULT '',
  `reverse` varchar(255) NOT NULL DEFAULT '',
  `reason` text NOT NULL,
  `admin` varchar(64) NOT NULL DEFAULT '',
  `admin_ip` varchar(64) NOT NULL DEFAULT '',
  `zonly` tinyint(1) NOT NULL DEFAULT 0,
  `length` int(11) NOT NULL DEFAULT 0,
  `name` varchar(64) NOT NULL DEFAULT '',
  `tripcode` varchar(32) NOT NULL DEFAULT '',
  `4pass_id` varchar(64) NOT NULL DEFAULT '',
  `post_num` int(11) NOT NULL DEFAULT 0,
  `template_id` int(11) NOT NULL DEFAULT 0,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `now` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `unbannedon` timestamp NULL DEFAULT NULL,
  `unbannedby` varchar(64) NOT NULL DEFAULT '',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `md5` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`no`),
  KEY `host` (`host`),
  KEY `md5` (`md5`),
  KEY `board` (`board`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Deletion log
CREATE TABLE IF NOT EXISTS `del_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `imgonly` tinyint(1) NOT NULL DEFAULT 0,
  `postno` int(11) NOT NULL DEFAULT 0,
  `resto` int(11) NOT NULL DEFAULT 0,
  `board` varchar(10) NOT NULL DEFAULT '',
  `name` varchar(64) NOT NULL DEFAULT '',
  `sub` varchar(128) NOT NULL DEFAULT '',
  `com` text NOT NULL,
  `img` int(11) NOT NULL DEFAULT 0,
  `filename` varchar(255) NOT NULL DEFAULT '',
  `admin` varchar(64) NOT NULL DEFAULT '',
  `admin_ip` varchar(64) NOT NULL DEFAULT '',
  `template_id` int(11) NOT NULL DEFAULT 0,
  `tool` varchar(32) NOT NULL DEFAULT '',
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `postno` (`postno`),
  KEY `board` (`board`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- User action tracking
CREATE TABLE IF NOT EXISTS `user_actions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ip` bigint(20) NOT NULL DEFAULT 0,
  `board` varchar(10) NOT NULL DEFAULT '',
  `postno` int(11) NOT NULL DEFAULT 0,
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `uploaded` tinyint(1) NOT NULL DEFAULT 0,
  `action` varchar(64) NOT NULL DEFAULT '',
  `had_image` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `ip` (`ip`),
  KEY `board` (`board`),
  KEY `time` (`time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Reports
CREATE TABLE IF NOT EXISTS `reports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `board` varchar(10) NOT NULL DEFAULT '',
  `no` int(11) NOT NULL DEFAULT 0,
  `ip` bigint(20) NOT NULL DEFAULT 0,
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reason` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `board_no` (`board`, `no`),
  KEY `ip` (`ip`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Reports for posts
CREATE TABLE IF NOT EXISTS `reports_for_posts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `board` varchar(10) NOT NULL DEFAULT '',
  `postid` int(11) NOT NULL DEFAULT 0,
  `ip` bigint(20) NOT NULL DEFAULT 0,
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reason` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `board_postid` (`board`, `postid`),
  KEY `ip` (`ip`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Profiling times
CREATE TABLE IF NOT EXISTS `profiling_times` (
  `board` varchar(10) NOT NULL DEFAULT '',
  `run` int(11) NOT NULL DEFAULT 0,
  `time` float NOT NULL DEFAULT 0,
  `desc` varchar(64) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Blotter messages (site-wide announcements)
CREATE TABLE IF NOT EXISTS `blotter_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `content` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Contest banners
CREATE TABLE IF NOT EXISTS `contest_banners` (
  `file_id` int(11) NOT NULL AUTO_INCREMENT,
  `file_ext` varchar(8) NOT NULL DEFAULT '',
  `board` varchar(10) NOT NULL DEFAULT '',
  `is_live` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`file_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Ban templates (for moderation)
CREATE TABLE IF NOT EXISTS `ban_templates` (
  `no` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(128) NOT NULL DEFAULT '',
  `rule` text NOT NULL,
  `global` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Ban requests (pre-ban screening)
CREATE TABLE IF NOT EXISTS `ban_requests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `host` varchar(255) NOT NULL DEFAULT '',
  `reverse` varchar(255) NOT NULL DEFAULT '',
  `pwd` varchar(32) NOT NULL DEFAULT '',
  `xff` varchar(255) NOT NULL DEFAULT '',
  `reason` text NOT NULL,
  `global` tinyint(1) NOT NULL DEFAULT 0,
  `tpl_name` varchar(128) NOT NULL DEFAULT '',
  `ban_template` int(11) NOT NULL DEFAULT 0,
  `board` varchar(10) NOT NULL DEFAULT '',
  `janitor` varchar(64) NOT NULL DEFAULT '',
  `spost` text NOT NULL,
  `post_json` text NOT NULL,
  `warn_req` tinyint(1) NOT NULL DEFAULT 0,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `host` (`host`),
  KEY `board` (`board`),
  KEY `ts` (`ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Halloween event votes
CREATE TABLE IF NOT EXISTS `halloween_votes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `long_ip` bigint(20) NOT NULL DEFAULT 0,
  `board` varchar(10) NOT NULL DEFAULT '',
  `post_id` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `long_ip` (`long_ip`),
  KEY `board_post` (`board`, `post_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Like system scores
CREATE TABLE IF NOT EXISTS `like_user_scores` (
  `user_id` varchar(64) NOT NULL DEFAULT '',
  `user_score` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Like system audit log
CREATE TABLE IF NOT EXISTS `like_user_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` varchar(64) NOT NULL DEFAULT '',
  `target_user_id` varchar(64) NOT NULL DEFAULT '',
  `suspicious` tinyint(1) NOT NULL DEFAULT 0,
  `board` varchar(10) NOT NULL DEFAULT '',
  `post_id` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- User statistics counters
CREATE TABLE IF NOT EXISTS `user_stats` (
  `name` varchar(64) NOT NULL DEFAULT '',
  `count` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Post filter rules
CREATE TABLE IF NOT EXISTS `postfilter` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `pattern` text NOT NULL,
  `autosage` tinyint(1) NOT NULL DEFAULT 0,
  `log` tinyint(1) NOT NULL DEFAULT 1,
  `regex` tinyint(1) NOT NULL DEFAULT 0,
  `quiet` tinyint(1) NOT NULL DEFAULT 0,
  `lenient` tinyint(1) NOT NULL DEFAULT 0,
  `ops_only` tinyint(1) NOT NULL DEFAULT 0,
  `min_count` int(11) NOT NULL DEFAULT 0,
  `board` varchar(10) NOT NULL DEFAULT '',
  `ban_days` int(11) NOT NULL DEFAULT 0,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `board` (`board`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- IP range bans (spam filtering)
CREATE TABLE IF NOT EXISTS `iprangebans` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `range_start` bigint(20) NOT NULL DEFAULT 0,
  `range_end` bigint(20) NOT NULL DEFAULT 0,
  `asn` int(11) NOT NULL DEFAULT 0,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `expires_on` int(11) NOT NULL DEFAULT 0,
  `boards` varchar(255) NOT NULL DEFAULT '',
  `ops_only` tinyint(1) NOT NULL DEFAULT 0,
  `img_only` tinyint(1) NOT NULL DEFAULT 0,
  `lenient` tinyint(1) NOT NULL DEFAULT 0,
  `report_only` tinyint(1) NOT NULL DEFAULT 0,
  `ua_ids` varchar(255) NOT NULL DEFAULT '',
  `created_on` int(11) NOT NULL DEFAULT 0,
  `updated_on` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `range_lookup` (`range_start`, `range_end`),
  KEY `asn` (`asn`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- MD5/Content blacklist (for image uploads)
CREATE TABLE IF NOT EXISTS `blacklist` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `boardrestrict` varchar(10) NOT NULL DEFAULT '',
  `field` varchar(32) NOT NULL DEFAULT '',
  `contents` varchar(255) NOT NULL DEFAULT '',
  `reason` text NOT NULL,
  PRIMARY KEY (`id`),
  KEY `field` (`field`),
  KEY `contents` (`contents`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Post filter hit tracking
CREATE TABLE IF NOT EXISTS `postfilter_hits` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `filter_id` int(11) NOT NULL DEFAULT 0,
  `board` varchar(10) NOT NULL DEFAULT '',
  `long_ip` bigint(20) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `filter_id` (`filter_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
