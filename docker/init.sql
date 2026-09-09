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

-- All boards (INSERT IGNORE so reruns are safe)
INSERT IGNORE INTO `boardlist` (`dir`, `name`, `db`, `section`, `hidden`) VALUES
-- Section 1: Japanese Culture
('3',   '3DCG',                  1, 1, 0),
('a',   'Anime & Manga',         1, 1, 0),
('c',   'Anime/Cute',            1, 1, 0),
('w',   'Anime/Wallpapers',      1, 1, 0),
('m',   'Mecha',                 1, 1, 0),
('cgl', 'Cosplay & EGL',         1, 1, 0),
('cm',  'Cute/Male',             1, 1, 0),
('f',   'Flash',                 1, 1, 0),
('n',   'Transportation',        1, 1, 0),
('jp',  'Otaku Culture',         1, 1, 0),
('vp',  'Pokemon',               1, 1, 0),
-- Section 2: Video Games
('v',    'Video Games',               1, 2, 0),
('vg',   'Video Game Generals',       1, 2, 0),
('vr',   'Retro Games',               1, 2, 0),
('vrpg', 'Video Games/RPG',           1, 2, 0),
('vst',  'Video Games/Strategy',      1, 2, 0),
('vm',   'Video Games/Multiplayer',   1, 2, 0),
('vmg',  'Video Games/Mobile',        1, 2, 0),
-- Section 3: Interests
('co',   'Comics & Cartoons',         1, 3, 0),
('g',    'Technology',                1, 3, 0),
('tv',   'Television & Film',         1, 3, 0),
('k',    'Weapons',                   1, 3, 0),
('o',    'Auto',                      1, 3, 0),
('an',   'Animals & Nature',          1, 3, 0),
('tg',   'Traditional Games',         1, 3, 0),
('sp',   'Sports',                    1, 3, 0),
('xs',   'Extreme Sports',            1, 3, 0),
('pw',   'Professional Wrestling',    1, 3, 0),
('sci',  'Science & Math',            1, 3, 0),
('his',  'History & Humanities',      1, 3, 0),
('int',  'International',             1, 3, 0),
('out',  'Outdoors',                  1, 3, 0),
('toy',  'Toys',                      1, 3, 0),
('biz',  'Business & Finance',        1, 3, 0),
('trv',  'Travel',                    1, 3, 0),
('fit',  'Fitness',                   1, 3, 0),
('news', 'Current News',              1, 3, 0),
('wsg',  'Worksafe GIF',              1, 3, 0),
('qst',  'Quests',                    1, 3, 0),
('diy',  'Do It Yourself',            1, 3, 0),
('wsr',  'Worksafe Requests',         1, 3, 0),
('vt',   'Virtual YouTubers',         1, 3, 0),
('adv',  'Advice',                    1, 3, 0),
('po',   'Papercraft & Origami',      1, 3, 0),
('p',    'Photo',                     1, 3, 0),
('ck',   'Food & Cooking',            1, 3, 0),
('ic',   'Artwork/Critique',          1, 3, 0),
('gd',   'Graphic Design',            1, 3, 0),
('lit',  'Literature',                1, 3, 0),
('mu',   'Music',                     1, 3, 0),
('fa',   'Fashion',                   1, 3, 0),
('i',    'Oekaki',                    1, 3, 0),
-- Section 5: Other
('b',    'Random',                    1, 5, 0),
('r9k',  'ROBOT9001',                 1, 5, 0),
('pol',  'Politically Incorrect',     1, 5, 0),
('bant', 'International/Random',      1, 5, 0),
('soc',  'Cams & Meetups',            1, 5, 0),
('s4s',  'Shit 4chan Says',           1, 5, 0),
('vip',  'Very Important Posts',      1, 5, 0),
('qa',   'Question & Answer',         1, 5, 0),
('trash','Off-Topic',                 1, 5, 0),
-- Section 6: Misc
('mlp',  'Pony',                      1, 6, 0),
('x',    'Paranormal',                1, 6, 0),
('wg',   'Wallpapers/General',        1, 6, 0),
-- Section 7: Adult
('s',    'Sexy Beautiful Women',      1, 7, 0),
('hc',   'Hardcore',                  1, 7, 0),
('hm',   'Handsome Men',              1, 7, 0),
('h',    'Hentai',                    1, 7, 0),
('e',    'Ecchi',                     1, 7, 0),
('u',    'Yuri',                      1, 7, 0),
('d',    'Hentai/Alternative',        1, 7, 0),
('y',    'Yaoi',                      1, 7, 0),
('t',    'Torrents',                  1, 7, 0),
('hr',   'High Resolution',           1, 7, 0),
('gif',  'Adult GIF',                 1, 7, 0),
('aco',  'Adult Cartoons',            1, 7, 0),
('r',    'Adult Requests',            1, 7, 0),
-- Section 8: LGBT
('lgbt', 'LGBT',                      1, 8, 0),
-- Hidden boards
('j',    'Janitor',                   1, 0, 1),
('test', 'Testing',                   1, 0, 1),
('asp',  'Alternative Sports',        1, 0, 1),
('qb',   'QB',                        1, 0, 1);

-- ============================================================
-- Per-board post tables
-- ============================================================

-- Board: /a/ - Anime & Manga
CREATE TABLE IF NOT EXISTS `a` (
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
  `clip_nsfw` float NOT NULL DEFAULT 0,
  `clip_desc` varchar(500) NOT NULL DEFAULT '',
  `board_flag` varchar(16) NOT NULL DEFAULT '',
  `source_filename` varchar(255) NOT NULL DEFAULT '',
  `source_ext` varchar(16) NOT NULL DEFAULT '',
  `source_fsize` int(11) NOT NULL DEFAULT 0,
  `source_data` mediumblob,
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

-- Board: /3/ - 3DCG
CREATE TABLE IF NOT EXISTS `3` LIKE `a`;

-- Board: /b/ - Random
CREATE TABLE IF NOT EXISTS `b` LIKE `a`;

-- Board: /c/ - Anime/Cute
CREATE TABLE IF NOT EXISTS `c` LIKE `a`;

-- Board: /w/ - Anime/Wallpapers
CREATE TABLE IF NOT EXISTS `w` LIKE `a`;

-- Board: /m/ - Mecha
CREATE TABLE IF NOT EXISTS `m` LIKE `a`;

-- Board: /cgl/ - Cosplay & EGL
CREATE TABLE IF NOT EXISTS `cgl` LIKE `a`;

-- Board: /cm/ - Cute/Male
CREATE TABLE IF NOT EXISTS `cm` LIKE `a`;

-- Board: /f/ - Flash
CREATE TABLE IF NOT EXISTS `f` LIKE `a`;

-- Board: /n/ - Transportation
CREATE TABLE IF NOT EXISTS `n` LIKE `a`;

-- Board: /jp/ - Otaku Culture
CREATE TABLE IF NOT EXISTS `jp` LIKE `a`;

-- Board: /vp/ - Pokemon
CREATE TABLE IF NOT EXISTS `vp` LIKE `a`;

-- Board: /v/ - Video Games
CREATE TABLE IF NOT EXISTS `v` LIKE `a`;

-- Board: /vg/ - Video Game Generals
CREATE TABLE IF NOT EXISTS `vg` LIKE `a`;

-- Board: /vr/ - Retro Games
CREATE TABLE IF NOT EXISTS `vr` LIKE `a`;

-- Board: /vrpg/ - Video Games/RPG
CREATE TABLE IF NOT EXISTS `vrpg` LIKE `a`;

-- Board: /vst/ - Video Games/Strategy
CREATE TABLE IF NOT EXISTS `vst` LIKE `a`;

-- Board: /vm/ - Video Games/Multiplayer
CREATE TABLE IF NOT EXISTS `vm` LIKE `a`;

-- Board: /vmg/ - Video Games/Mobile
CREATE TABLE IF NOT EXISTS `vmg` LIKE `a`;

-- Board: /co/ - Comics & Cartoons
CREATE TABLE IF NOT EXISTS `co` LIKE `a`;

-- Board: /g/ - Technology
CREATE TABLE IF NOT EXISTS `g` LIKE `a`;

-- Board: /tv/ - Television & Film
CREATE TABLE IF NOT EXISTS `tv` LIKE `a`;

-- Board: /k/ - Weapons
CREATE TABLE IF NOT EXISTS `k` LIKE `a`;

-- Board: /o/ - Auto
CREATE TABLE IF NOT EXISTS `o` LIKE `a`;

-- Board: /an/ - Animals & Nature
CREATE TABLE IF NOT EXISTS `an` LIKE `a`;

-- Board: /tg/ - Traditional Games
CREATE TABLE IF NOT EXISTS `tg` LIKE `a`;

-- Board: /sp/ - Sports
CREATE TABLE IF NOT EXISTS `sp` LIKE `a`;

-- Board: /xs/ - Extreme Sports
CREATE TABLE IF NOT EXISTS `xs` LIKE `a`;

-- Board: /pw/ - Professional Wrestling
CREATE TABLE IF NOT EXISTS `pw` LIKE `a`;

-- Board: /sci/ - Science & Math
CREATE TABLE IF NOT EXISTS `sci` LIKE `a`;

-- Board: /his/ - History & Humanities
CREATE TABLE IF NOT EXISTS `his` LIKE `a`;

-- Board: /int/ - International
CREATE TABLE IF NOT EXISTS `int` LIKE `a`;

-- Board: /out/ - Outdoors
CREATE TABLE IF NOT EXISTS `out` LIKE `a`;

-- Board: /toy/ - Toys
CREATE TABLE IF NOT EXISTS `toy` LIKE `a`;

-- Board: /biz/ - Business & Finance
CREATE TABLE IF NOT EXISTS `biz` LIKE `a`;

-- Board: /trv/ - Travel
CREATE TABLE IF NOT EXISTS `trv` LIKE `a`;

-- Board: /fit/ - Fitness
CREATE TABLE IF NOT EXISTS `fit` LIKE `a`;

-- Board: /news/ - Current News
CREATE TABLE IF NOT EXISTS `news` LIKE `a`;

-- Board: /wsg/ - Worksafe GIF
CREATE TABLE IF NOT EXISTS `wsg` LIKE `a`;

-- Board: /qst/ - Quests
CREATE TABLE IF NOT EXISTS `qst` LIKE `a`;

-- Board: /diy/ - Do It Yourself
CREATE TABLE IF NOT EXISTS `diy` LIKE `a`;

-- Board: /wsr/ - Worksafe Requests
CREATE TABLE IF NOT EXISTS `wsr` LIKE `a`;

-- Board: /vt/ - Virtual YouTubers
CREATE TABLE IF NOT EXISTS `vt` LIKE `a`;

-- Board: /adv/ - Advice
CREATE TABLE IF NOT EXISTS `adv` LIKE `a`;

-- Board: /po/ - Papercraft & Origami
CREATE TABLE IF NOT EXISTS `po` LIKE `a`;

-- Board: /p/ - Photo
CREATE TABLE IF NOT EXISTS `p` LIKE `a`;

-- Board: /ck/ - Food & Cooking
CREATE TABLE IF NOT EXISTS `ck` LIKE `a`;

-- Board: /ic/ - Artwork/Critique
CREATE TABLE IF NOT EXISTS `ic` LIKE `a`;

-- Board: /gd/ - Graphic Design
CREATE TABLE IF NOT EXISTS `gd` LIKE `a`;

-- Board: /lit/ - Literature
CREATE TABLE IF NOT EXISTS `lit` LIKE `a`;

-- Board: /mu/ - Music
CREATE TABLE IF NOT EXISTS `mu` LIKE `a`;

-- Board: /fa/ - Fashion
CREATE TABLE IF NOT EXISTS `fa` LIKE `a`;

-- Board: /i/ - Oekaki
CREATE TABLE IF NOT EXISTS `i` LIKE `a`;

-- Board: /r9k/ - ROBOT9001
CREATE TABLE IF NOT EXISTS `r9k` LIKE `a`;

-- Board: /pol/ - Politically Incorrect
CREATE TABLE IF NOT EXISTS `pol` LIKE `a`;

-- Board: /bant/ - International/Random
CREATE TABLE IF NOT EXISTS `bant` LIKE `a`;

-- Board: /soc/ - Cams & Meetups
CREATE TABLE IF NOT EXISTS `soc` LIKE `a`;

-- Board: /s4s/ - Shit 4chan Says
CREATE TABLE IF NOT EXISTS `s4s` LIKE `a`;

-- Board: /vip/ - Very Important Posts
CREATE TABLE IF NOT EXISTS `vip` LIKE `a`;

-- Board: /qa/ - Question & Answer
CREATE TABLE IF NOT EXISTS `qa` LIKE `a`;

-- Board: /trash/ - Off-Topic
CREATE TABLE IF NOT EXISTS `trash` LIKE `a`;

-- Board: /mlp/ - Pony
CREATE TABLE IF NOT EXISTS `mlp` LIKE `a`;

-- Board: /x/ - Paranormal
CREATE TABLE IF NOT EXISTS `x` LIKE `a`;

-- Board: /wg/ - Wallpapers/General
CREATE TABLE IF NOT EXISTS `wg` LIKE `a`;

-- Board: /s/ - Sexy Beautiful Women
CREATE TABLE IF NOT EXISTS `s` LIKE `a`;

-- Board: /hc/ - Hardcore
CREATE TABLE IF NOT EXISTS `hc` LIKE `a`;

-- Board: /hm/ - Handsome Men
CREATE TABLE IF NOT EXISTS `hm` LIKE `a`;

-- Board: /h/ - Hentai
CREATE TABLE IF NOT EXISTS `h` LIKE `a`;

-- Board: /e/ - Ecchi
CREATE TABLE IF NOT EXISTS `e` LIKE `a`;

-- Board: /u/ - Yuri
CREATE TABLE IF NOT EXISTS `u` LIKE `a`;

-- Board: /d/ - Hentai/Alternative
CREATE TABLE IF NOT EXISTS `d` LIKE `a`;

-- Board: /y/ - Yaoi
CREATE TABLE IF NOT EXISTS `y` LIKE `a`;

-- Board: /t/ - Torrents
CREATE TABLE IF NOT EXISTS `t` LIKE `a`;

-- Board: /hr/ - High Resolution
CREATE TABLE IF NOT EXISTS `hr` LIKE `a`;

-- Board: /gif/ - Adult GIF
CREATE TABLE IF NOT EXISTS `gif` LIKE `a`;

-- Board: /aco/ - Adult Cartoons
CREATE TABLE IF NOT EXISTS `aco` LIKE `a`;

-- Board: /r/ - Adult Requests
CREATE TABLE IF NOT EXISTS `r` LIKE `a`;

-- Board: /lgbt/ - LGBT
CREATE TABLE IF NOT EXISTS `lgbt` LIKE `a`;

-- Board: /j/ - Janitor (hidden)
CREATE TABLE IF NOT EXISTS `j` LIKE `a`;

-- Board: /test/ - Testing (hidden)
CREATE TABLE IF NOT EXISTS `test` LIKE `a`;

-- Board: /asp/ - Alternative Sports (hidden)
CREATE TABLE IF NOT EXISTS `asp` LIKE `a`;

-- Board: /qb/ - QB (hidden)
CREATE TABLE IF NOT EXISTS `qb` LIKE `a`;

-- ============================================================
-- Staff / moderation tables
-- ============================================================

-- Mod / staff users
CREATE TABLE IF NOT EXISTS `mod_users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(64) NOT NULL DEFAULT '',
  `password` varchar(128) NOT NULL DEFAULT '',
  `level` varchar(32) NOT NULL DEFAULT 'janitor',
  `flags` varchar(255) NOT NULL DEFAULT '',
  `allow` varchar(255) NOT NULL DEFAULT '',
  `deny` varchar(255) NOT NULL DEFAULT '',
  `password_expired` tinyint(1) NOT NULL DEFAULT 0,
  `signed_agreement` tinyint(1) NOT NULL DEFAULT 1,
  `auth_secret` text DEFAULT NULL,
  `ips` text DEFAULT NULL,
  `last_ua` varchar(128) DEFAULT NULL,
  `last_login` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Default admin user (password: admin)
INSERT IGNORE INTO `mod_users` (`username`, `password`, `level`, `flags`, `allow`, `signed_agreement`, `ips`) VALUES
('admin', 'admin', 'admin', 'ban,banmsg,developer', 'all', 1, '{}');

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
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reason` varchar(255) NOT NULL DEFAULT '',
  `weight` int(11) NOT NULL DEFAULT 1,
  `report_category` varchar(64) NOT NULL DEFAULT '',
  `post_json` text NOT NULL,
  `cleared` tinyint(1) NOT NULL DEFAULT 0,
  `cleared_by` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `board_no` (`board`, `no`),
  KEY `ip` (`ip`),
  KEY `cleared` (`cleared`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Reports for posts
CREATE TABLE IF NOT EXISTS `reports_for_posts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `board` varchar(10) NOT NULL DEFAULT '',
  `postid` int(11) NOT NULL DEFAULT 0,
  `ip` bigint(20) NOT NULL DEFAULT 0,
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reason` varchar(255) NOT NULL DEFAULT '',
  `cleared` tinyint(1) NOT NULL DEFAULT 0,
  `clearedby` varchar(64) NOT NULL DEFAULT '',
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

-- Welcome blotter message
INSERT IGNORE INTO `blotter_messages` (`content`) VALUES
('Welcome to 4chan - local security testing lab');

-- Contest banners
CREATE TABLE IF NOT EXISTS `contest_banners` (
  `file_id` varchar(64) NOT NULL,
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
  `publicreason` text NOT NULL,
  `privatereason` text NOT NULL,
  `days` int(11) NOT NULL DEFAULT 0,
  `banlen` varchar(32) NOT NULL DEFAULT '',
  `bantype` varchar(16) NOT NULL DEFAULT 'local',
  `postban` varchar(32) NOT NULL DEFAULT '',
  `postban_arg` varchar(32) NOT NULL DEFAULT '',
  `level` varchar(32) NOT NULL DEFAULT 'janitor',
  `save_post` varchar(32) NOT NULL DEFAULT 'everything',
  `blacklist` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Default ban templates
INSERT IGNORE INTO `ban_templates` (`no`, `name`, `rule`, `global`, `publicreason`, `privatereason`, `days`, `bantype`, `postban`, `level`) VALUES
(1,  'GR1 - CP/Underage',      'global1',  1, 'Violating US law',                    '', 0, 'global', 'delpost', 'janitor'),
(2,  'GR2 - DMCA/Copyright',   'global2',  1, 'Copyright violation',                 '', 3, 'global', 'delpost', 'mod'),
(3,  'GR3 - Dox/Personal Info', 'global3', 1, 'Posting personal information',         '', 3, 'global', 'delpost', 'mod'),
(4,  'GR4 - Racism (outside /b/)', 'global4', 1, 'Racism outside of /b/',            '', 3, 'global', '',        'mod'),
(5,  'GR5 - Advertising',      'global5',  1, 'Advertising',                         '', 30, 'global', 'delpost', 'janitor'),
(6,  'GR6 - Complaining about 4chan', 'global6', 1, 'Complaining about 4chan',         '', 1, 'global', '',        'mod'),
(7,  'Off-topic',               'local',   0, 'Posting off-topic content',            '', 3, 'local',  'delpost', 'janitor'),
(8,  'Troll/Flame/Bait',        'local',   0, 'Trolling/flaming',                     '', 3, 'local',  '',        'janitor'),
(9,  'NSFW on SFW board',       'local',   0, 'Posting NSFW content on a SFW board',  '', 3, 'local', 'delpost', 'janitor'),
(10, 'Spam/Flooding',           'local',   0, 'Spamming/flooding',                    '', 7, 'local',  'delall',  'janitor'),
(11, 'Ban Evasion',             'local',   0, 'Ban evasion',                          '', 0, 'global', 'delall',  'mod');
INSERT IGNORE INTO `ban_templates` (`no`, `name`, `rule`, `global`, `publicreason`, `privatereason`, `days`, `bantype`, `postban`, `level`, `banlen`) VALUES
(123, 'Warn - Off-topic',       'local',   0, 'Off-topic posting',                  '', 0, 'local',  '',        'janitor', ''),
(213, 'Warn - Low quality',     'local',   0, 'Low quality posting',                '', 0, 'local',  '',        'janitor', '');

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

-- One current vote per anonymous voter and post
CREATE TABLE IF NOT EXISTS `post_votes` (
  `board` varchar(10) NOT NULL,
  `post_id` int(11) NOT NULL,
  `voter_hash` char(64) NOT NULL,
  `direction` varchar(4) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`board`, `post_id`, `voter_hash`),
  KEY `post_votes_updated` (`updated_at`)
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

-- Event log (moderation/security events)
CREATE TABLE IF NOT EXISTS `event_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(64) NOT NULL DEFAULT '',
  `ip` varchar(64) NOT NULL DEFAULT '',
  `board` varchar(10) NOT NULL DEFAULT '',
  `thread_id` int(11) NOT NULL DEFAULT 0,
  `post_id` int(11) NOT NULL DEFAULT 0,
  `arg_num` int(11) NOT NULL DEFAULT 0,
  `arg_str` varchar(255) NOT NULL DEFAULT '',
  `pwd` varchar(32) NOT NULL DEFAULT '',
  `req_sig` varchar(64) NOT NULL DEFAULT '',
  `ua_sig` varchar(64) NOT NULL DEFAULT '',
  `meta` text NOT NULL,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `type` (`type`),
  KEY `ip` (`ip`),
  KEY `board` (`board`),
  KEY `created` (`created`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- CLIP/tensorchan NSFW score log
CREATE TABLE IF NOT EXISTS `tensor_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `board` varchar(16) NOT NULL,
  `thread_id` int(11) NOT NULL DEFAULT 0,
  `post_id` int(11) NOT NULL DEFAULT 0,
  `file_id` varchar(32) NOT NULL DEFAULT '',
  `file_ext` varchar(8) NOT NULL DEFAULT '',
  `nsfw` float NOT NULL DEFAULT 0,
  `description` varchar(500) NOT NULL DEFAULT '',
  `tags` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `board` (`board`),
  KEY `nsfw` (`nsfw`),
  KEY `post` (`board`, `post_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Blotter (news/announcements)
CREATE TABLE IF NOT EXISTS `blotter` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `message` text NOT NULL,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `blotter` (`message`) VALUES
('Welcome to 4chan - local instance running.'),
('<b>Jeffrey''s Island Adventure</b> — release edition 0.1.3.3.7. This board is rebuilt from the original 4chan Yotsuba source code with love, and dedicated to all those abused by Epstein — especially the trans women on 4chan, who are the realest and truest victims. Built by a former 99chan admin who has been writing imageboard software since 2010. This is our way of getting over some old trauma, pulling back the curtains, and preserving a museum of our childhood spent on the site with others when we had little else. Credits: <a href=\"https://4chan.org\">4chan.org</a>, <a href=\"https://kusabax.org\">KusabaX</a>, <a href=\"https://99chan.org\">99chan.org</a>. Local-first, agent-ready, anonymous forever.');

-- Post filter hit tracking
CREATE TABLE IF NOT EXISTS `postfilter_hits` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `filter_id` int(11) NOT NULL DEFAULT 0,
  `board` varchar(10) NOT NULL DEFAULT '',
  `long_ip` bigint(20) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `filter_id` (`filter_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Actions log (thread options, spoiler toggles, etc.)
CREATE TABLE IF NOT EXISTS `actions_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `oldmask` int(11) NOT NULL DEFAULT 0,
  `newmask` int(11) NOT NULL DEFAULT 0,
  `postno` int(11) NOT NULL DEFAULT 0,
  `board` varchar(10) NOT NULL DEFAULT '',
  `name` varchar(64) NOT NULL DEFAULT '',
  `sub` varchar(128) NOT NULL DEFAULT '',
  `com` text NOT NULL,
  `filename` varchar(255) NOT NULL DEFAULT '',
  `admin` varchar(64) NOT NULL DEFAULT '',
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `board` (`board`),
  KEY `admin` (`admin`),
  KEY `ts` (`ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Moderation log (staff actions audit trail)
CREATE TABLE IF NOT EXISTS `mod_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `admin` varchar(64) NOT NULL DEFAULT '',
  `action` varchar(128) NOT NULL DEFAULT '',
  `board` varchar(10) NOT NULL DEFAULT '',
  `post_id` int(11) NOT NULL DEFAULT 0,
  `detail` text NOT NULL,
  `ip` varchar(64) NOT NULL DEFAULT '',
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `admin` (`admin`),
  KEY `board` (`board`),
  KEY `ts` (`ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Word filters
CREATE TABLE IF NOT EXISTS `word_filters` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `board` varchar(10) NOT NULL DEFAULT '',
  `pattern` varchar(255) NOT NULL DEFAULT '',
  `replacement` varchar(255) NOT NULL DEFAULT '',
  `is_regex` tinyint(1) NOT NULL DEFAULT 0,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `added_by` varchar(64) NOT NULL DEFAULT '',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `board` (`board`),
  KEY `active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Janitor voting
CREATE TABLE IF NOT EXISTS `janitor_votes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `moderator` varchar(64) NOT NULL DEFAULT '',
  `applicant_id` int(11) NOT NULL DEFAULT 0,
  `vote` tinyint(1) NOT NULL DEFAULT 0,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `moderator` (`moderator`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Janitor applications
CREATE TABLE IF NOT EXISTS `janitor_apps` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL DEFAULT '',
  `email` varchar(128) NOT NULL DEFAULT '',
  `age` int(11) NOT NULL DEFAULT 0,
  `boards` varchar(255) NOT NULL DEFAULT '',
  `reason` text NOT NULL,
  `closed` tinyint(1) NOT NULL DEFAULT 0,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- XFF tracking
CREATE TABLE IF NOT EXISTS `xff` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `board` varchar(10) NOT NULL DEFAULT '',
  `postno` int(11) NOT NULL DEFAULT 0,
  `xff` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `postno` (`postno`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- News/blog entries for homepage
CREATE TABLE IF NOT EXISTS `news_entries` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `subject` varchar(255) NOT NULL DEFAULT '',
  `author` varchar(64) NOT NULL DEFAULT 'moot',
  `body` text NOT NULL,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `created` (`created`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `news_entries` (`id`, `subject`, `author`, `body`) VALUES
(1, 'Welcome to 4chan', 'moot', 'Welcome to our restored instance of 4chan, running the original Yotsuba engine. This site has been rebuilt from the leaked source code as a preservation and research project.\n\nAll boards are active and ready for posting. No registration is required -- just pick a board and start posting. Image uploads are enabled on all boards.\n\nThis is a local-first deployment. Everything runs on your machine, nothing phones home, and the full source is available for inspection. Have fun.'),
(2, 'Rules', 'moot', 'The global rules are simple:\n\n1. You will not upload, post, discuss, request, or link to anything that violates local or United States law.\n2. You will immediately cease and not continue to access the site if you are under the age of 18.\n3. You will not post or request personal information or calls to invasion.\n4. No spamming or flooding of any kind.\n5. No malicious content or virus links.\n6. Advertising (all forms) is not welcome.\n\nIndividual boards may have additional rules posted in their sticky threads. Violating the rules will result in post deletion and may result in a ban.'),
(3, 'Technical Notes: Yotsuba Restoration', 'moot', 'Some technical details about this restoration:\n\n- Engine: Original Yotsuba PHP engine, patched for PHP 8.x compatibility\n- Database: MariaDB 10.1, schema-compatible with the original MySQL setup\n- Boards: All 84 boards from the original boardlist are active\n- Features: Posting, image uploads, tripcodes, capcodes, catalog view, thread archiving\n- Disabled: CAPTCHA, GeoIP, ad scripts, external CDN dependencies\n\nThis is release 0.1.3.3.7 of Jeffrey''s Island Adventure. Local-first, agent-ready, anonymous forever.');

-- ROBOT9000 duplicate detection
CREATE TABLE IF NOT EXISTS `r9k_posts` (
  `text` varchar(32) NOT NULL DEFAULT '',
  `image` varchar(32) NOT NULL DEFAULT '',
  `created_on` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`text`),
  KEY `image` (`image`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ROBOT9000 mute tracking
CREATE TABLE IF NOT EXISTS `r9k_mutes` (
  `ip` bigint(20) NOT NULL DEFAULT 0,
  `timeout_power` int(11) NOT NULL DEFAULT 0,
  `mute_until` datetime DEFAULT NULL,
  `next_expire` datetime DEFAULT NULL,
  PRIMARY KEY (`ip`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4chan Pass users
CREATE TABLE IF NOT EXISTS `pass_users` (
  `user_hash` varchar(64) NOT NULL DEFAULT '',
  `pin` varchar(128) NOT NULL DEFAULT '',
  `session_id` varchar(128) NOT NULL DEFAULT '',
  `last_ip` varchar(64) NOT NULL DEFAULT '0.0.0.0',
  `last_used` datetime DEFAULT NULL,
  `last_country` varchar(4) NOT NULL DEFAULT '',
  `status` tinyint(1) NOT NULL DEFAULT 0,
  `pending_id` varchar(64) NOT NULL DEFAULT '',
  `expiration_date` datetime DEFAULT '2030-12-31 23:59:59',
  PRIMARY KEY (`user_hash`),
  KEY `status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Default test pass user (token: TESTPASS01, session will be set by entrypoint)
INSERT IGNORE INTO `pass_users` (`user_hash`, `pin`, `session_id`, `last_ip`, `last_used`, `status`, `expiration_date`) VALUES
('TESTPASS01', 'test', 'localsession001', '0.0.0.0', NOW(), 0, '2030-12-31 23:59:59');

-- Ban appeals
CREATE TABLE IF NOT EXISTS `ban_appeals` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ban_id` int(11) NOT NULL,
  `ip` varchar(45) NOT NULL,
  `appeal_text` text NOT NULL,
  `status` enum('pending','approved','denied') DEFAULT 'pending',
  `mod_response` text,
  `mod_user` varchar(64),
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `resolved_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ban_id` (`ban_id`),
  KEY `status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
