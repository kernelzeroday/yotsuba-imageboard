-- 4chan Yotsuba imageboard schema (PostgreSQL)
-- Consolidated: single posts table + per-board views

-- Board directory
CREATE TABLE IF NOT EXISTS "boardlist" (
  "id" SERIAL PRIMARY KEY,
  "dir" VARCHAR(10) NOT NULL DEFAULT '',
  "name" VARCHAR(64) NOT NULL DEFAULT '',
  "db" INTEGER NOT NULL DEFAULT 1,
  "title" TEXT,
  "description" TEXT,
  "hidden" SMALLINT DEFAULT 0,
  "section" INTEGER DEFAULT 1,
  "max_image_width" INTEGER DEFAULT 0,
  "max_image_height" INTEGER DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS "dir" ON "boardlist" ("dir");

-- All boards (INSERT ... ON CONFLICT DO NOTHING so reruns are safe)
INSERT INTO "boardlist" ("dir", "name", "db", "section", "hidden") VALUES
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
('qb',   'QB',                        1, 0, 1)
ON CONFLICT DO NOTHING;

-- ============================================================
-- Consolidated posts table (replaces 82 per-board tables)
-- ============================================================

CREATE TABLE IF NOT EXISTS "posts" (
  "board" VARCHAR(10) NOT NULL,
  "no" INTEGER NOT NULL,
  "resto" INTEGER NOT NULL DEFAULT 0,
  "root" INTEGER NOT NULL DEFAULT 0,
  "now" VARCHAR(32) NOT NULL DEFAULT '',
  "time" INTEGER NOT NULL DEFAULT 0,
  "last_modified" INTEGER NOT NULL DEFAULT 0,
  "name" VARCHAR(64) NOT NULL DEFAULT '',
  "sub" VARCHAR(128) NOT NULL DEFAULT '',
  "com" TEXT NOT NULL DEFAULT '',
  "host" VARCHAR(255) NOT NULL DEFAULT '',
  "pwd" VARCHAR(32) NOT NULL DEFAULT '',
  "4pass_id" VARCHAR(64) NOT NULL DEFAULT '',
  "email" VARCHAR(128) NOT NULL DEFAULT '',
  "filename" VARCHAR(255) NOT NULL DEFAULT '',
  "ext" VARCHAR(8) NOT NULL DEFAULT '',
  "w" INTEGER NOT NULL DEFAULT 0,
  "h" INTEGER NOT NULL DEFAULT 0,
  "tn_w" INTEGER NOT NULL DEFAULT 0,
  "tn_h" INTEGER NOT NULL DEFAULT 0,
  "tim" VARCHAR(32) NOT NULL DEFAULT '',
  "md5" VARCHAR(32) NOT NULL DEFAULT '',
  "tmd5" VARCHAR(32) NOT NULL DEFAULT '',
  "fsize" INTEGER NOT NULL DEFAULT 0,
  "filedeleted" SMALLINT NOT NULL DEFAULT 0,
  "id" VARCHAR(16) NOT NULL DEFAULT '',
  "capcode" VARCHAR(8) NOT NULL DEFAULT '',
  "country" VARCHAR(2) NOT NULL DEFAULT '',
  "sticky" SMALLINT NOT NULL DEFAULT 0,
  "permasage" SMALLINT NOT NULL DEFAULT 0,
  "permaage" SMALLINT NOT NULL DEFAULT 0,
  "closed" SMALLINT NOT NULL DEFAULT 0,
  "archived" SMALLINT NOT NULL DEFAULT 0,
  "undead" SMALLINT NOT NULL DEFAULT 0,
  "since4pass" SMALLINT NOT NULL DEFAULT 0,
  "m_img" SMALLINT NOT NULL DEFAULT 0,
  "clip_nsfw" REAL NOT NULL DEFAULT 0,
  "clip_desc" VARCHAR(500) NOT NULL DEFAULT '',
  "board_flag" VARCHAR(16) NOT NULL DEFAULT '',
  "upvotes" INTEGER NOT NULL DEFAULT 0,
  "downvotes" INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY ("board", "no")
);

CREATE INDEX IF NOT EXISTS "posts_board_resto" ON "posts" ("board", "resto");
CREATE INDEX IF NOT EXISTS "posts_board_time" ON "posts" ("board", "time");
CREATE INDEX IF NOT EXISTS "posts_board_sticky_last" ON "posts" ("board", "sticky" DESC, "last_modified" DESC);
CREATE INDEX IF NOT EXISTS "posts_board_root" ON "posts" ("board", "root" DESC);
CREATE INDEX IF NOT EXISTS "posts_board_archived" ON "posts" ("board", "archived");
CREATE INDEX IF NOT EXISTS "posts_board_filedeleted" ON "posts" ("board", "filedeleted");

-- Per-board post number sequences
CREATE TABLE IF NOT EXISTS "board_sequences" (
  "board" VARCHAR(10) PRIMARY KEY,
  "current_no" INTEGER NOT NULL DEFAULT 0
);

-- Auto-assign per-board post numbers on INSERT
CREATE OR REPLACE FUNCTION posts_auto_no() RETURNS TRIGGER AS $$
BEGIN
  IF NEW."no" IS NULL OR NEW."no" = 0 THEN
    UPDATE "board_sequences" SET "current_no" = "current_no" + 1
    WHERE "board" = NEW."board"
    RETURNING "current_no" INTO NEW."no";
    IF NOT FOUND THEN
      INSERT INTO "board_sequences" ("board", "current_no") VALUES (NEW."board", 1);
      NEW."no" := 1;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_posts_auto_no ON "posts";
CREATE TRIGGER trg_posts_auto_no BEFORE INSERT ON "posts"
FOR EACH ROW EXECUTE FUNCTION posts_auto_no();

-- ============================================================
-- Board views (transparent compatibility with per-board queries)
-- ============================================================

-- Column list used by all board views (everything except "board")
-- Views let the PHP code query "g", "b", etc. as if they were tables

CREATE OR REPLACE FUNCTION board_view_insert() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO "posts" ("board","no","resto","root","now","time","last_modified",
    "name","sub","com","host","pwd","4pass_id","email","filename","ext",
    "w","h","tn_w","tn_h","tim","md5","tmd5","fsize","filedeleted",
    "id","capcode","country","sticky","permasage","permaage","closed",
    "archived","undead","since4pass","m_img","clip_nsfw","clip_desc",
    "board_flag","upvotes","downvotes")
  VALUES (TG_TABLE_NAME,
    COALESCE(NEW."no", 0), COALESCE(NEW."resto", 0), COALESCE(NEW."root", 0),
    COALESCE(NEW."now", ''), COALESCE(NEW."time", 0), COALESCE(NEW."last_modified", 0),
    COALESCE(NEW."name", ''), COALESCE(NEW."sub", ''), COALESCE(NEW."com", ''),
    COALESCE(NEW."host", ''), COALESCE(NEW."pwd", ''), COALESCE(NEW."4pass_id", ''),
    COALESCE(NEW."email", ''), COALESCE(NEW."filename", ''), COALESCE(NEW."ext", ''),
    COALESCE(NEW."w", 0), COALESCE(NEW."h", 0), COALESCE(NEW."tn_w", 0), COALESCE(NEW."tn_h", 0),
    COALESCE(NEW."tim", ''), COALESCE(NEW."md5", ''), COALESCE(NEW."tmd5", ''),
    COALESCE(NEW."fsize", 0), COALESCE(NEW."filedeleted", 0::smallint),
    COALESCE(NEW."id", ''), COALESCE(NEW."capcode", ''), COALESCE(NEW."country", ''),
    COALESCE(NEW."sticky", 0::smallint), COALESCE(NEW."permasage", 0::smallint),
    COALESCE(NEW."permaage", 0::smallint), COALESCE(NEW."closed", 0::smallint),
    COALESCE(NEW."archived", 0::smallint), COALESCE(NEW."undead", 0::smallint),
    COALESCE(NEW."since4pass", 0::smallint), COALESCE(NEW."m_img", 0::smallint),
    COALESCE(NEW."clip_nsfw", 0), COALESCE(NEW."clip_desc", ''),
    COALESCE(NEW."board_flag", ''), COALESCE(NEW."upvotes", 0), COALESCE(NEW."downvotes", 0));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION board_view_update() RETURNS TRIGGER AS $$
BEGIN
  UPDATE "posts" SET
    "resto"=NEW."resto", "root"=NEW."root", "now"=NEW."now", "time"=NEW."time",
    "last_modified"=NEW."last_modified", "name"=NEW."name", "sub"=NEW."sub",
    "com"=NEW."com", "host"=NEW."host", "pwd"=NEW."pwd", "4pass_id"=NEW."4pass_id",
    "email"=NEW."email", "filename"=NEW."filename", "ext"=NEW."ext",
    "w"=NEW."w", "h"=NEW."h", "tn_w"=NEW."tn_w", "tn_h"=NEW."tn_h",
    "tim"=NEW."tim", "md5"=NEW."md5", "tmd5"=NEW."tmd5", "fsize"=NEW."fsize",
    "filedeleted"=NEW."filedeleted", "id"=NEW."id", "capcode"=NEW."capcode",
    "country"=NEW."country", "sticky"=NEW."sticky", "permasage"=NEW."permasage",
    "permaage"=NEW."permaage", "closed"=NEW."closed", "archived"=NEW."archived",
    "undead"=NEW."undead", "since4pass"=NEW."since4pass", "m_img"=NEW."m_img",
    "clip_nsfw"=NEW."clip_nsfw", "clip_desc"=NEW."clip_desc",
    "board_flag"=NEW."board_flag", "upvotes"=NEW."upvotes", "downvotes"=NEW."downvotes"
  WHERE "board" = TG_TABLE_NAME AND "no" = OLD."no";
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION board_view_delete() RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM "posts" WHERE "board" = TG_TABLE_NAME AND "no" = OLD."no";
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Generate views + triggers for every board
DO $$
DECLARE
  board_dir TEXT;
  col_list TEXT := '"no","resto","root","now","time","last_modified","name","sub","com","host","pwd","4pass_id","email","filename","ext","w","h","tn_w","tn_h","tim","md5","tmd5","fsize","filedeleted","id","capcode","country","sticky","permasage","permaage","closed","archived","undead","since4pass","m_img","clip_nsfw","clip_desc","board_flag","upvotes","downvotes"';
BEGIN
  FOR board_dir IN SELECT dir FROM boardlist LOOP
    EXECUTE format('CREATE OR REPLACE VIEW %I AS SELECT %s FROM posts WHERE board = %L', board_dir, col_list, board_dir);
    EXECUTE format('CREATE OR REPLACE TRIGGER trg_%s_insert INSTEAD OF INSERT ON %I FOR EACH ROW EXECUTE FUNCTION board_view_insert()', replace(board_dir, '-', '_'), board_dir);
    EXECUTE format('CREATE OR REPLACE TRIGGER trg_%s_update INSTEAD OF UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION board_view_update()', replace(board_dir, '-', '_'), board_dir);
    EXECUTE format('CREATE OR REPLACE TRIGGER trg_%s_delete INSTEAD OF DELETE ON %I FOR EACH ROW EXECUTE FUNCTION board_view_delete()', replace(board_dir, '-', '_'), board_dir);
  END LOOP;
END $$;

-- ============================================================
-- Staff / moderation tables
-- ============================================================

-- Mod / staff users
CREATE TABLE IF NOT EXISTS "mod_users" (
  "id" SERIAL PRIMARY KEY,
  "username" VARCHAR(64) NOT NULL DEFAULT '',
  "password" VARCHAR(128) NOT NULL DEFAULT '',
  "level" VARCHAR(32) NOT NULL DEFAULT 'janitor',
  "flags" VARCHAR(255) NOT NULL DEFAULT '',
  "allow" VARCHAR(255) NOT NULL DEFAULT '',
  "deny" VARCHAR(255) NOT NULL DEFAULT '',
  "password_expired" SMALLINT NOT NULL DEFAULT 0,
  "signed_agreement" SMALLINT NOT NULL DEFAULT 1,
  "auth_secret" TEXT DEFAULT NULL,
  "ips" TEXT DEFAULT NULL,
  "last_ua" VARCHAR(128) DEFAULT NULL,
  "last_login" TIMESTAMP DEFAULT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS "username" ON "mod_users" ("username");

-- Default admin user (password: admin)
INSERT INTO "mod_users" ("username", "password", "level", "flags", "allow", "signed_agreement", "ips") VALUES
('admin', 'admin', 'admin', 'ban,banmsg,developer', 'all', 1, '{}')
ON CONFLICT DO NOTHING;

-- Banned users
CREATE TABLE IF NOT EXISTS "banned_users" (
  "no" SERIAL PRIMARY KEY,
  "global" SMALLINT NOT NULL DEFAULT 0,
  "board" VARCHAR(10) NOT NULL DEFAULT '',
  "host" VARCHAR(255) NOT NULL DEFAULT '',
  "reverse" VARCHAR(255) NOT NULL DEFAULT '',
  "reason" TEXT NOT NULL,
  "admin" VARCHAR(64) NOT NULL DEFAULT '',
  "admin_ip" VARCHAR(64) NOT NULL DEFAULT '',
  "zonly" SMALLINT NOT NULL DEFAULT 0,
  "length" INTEGER NOT NULL DEFAULT 0,
  "name" VARCHAR(64) NOT NULL DEFAULT '',
  "tripcode" VARCHAR(32) NOT NULL DEFAULT '',
  "4pass_id" VARCHAR(64) NOT NULL DEFAULT '',
  "post_num" INTEGER NOT NULL DEFAULT 0,
  "template_id" INTEGER NOT NULL DEFAULT 0,
  "active" SMALLINT NOT NULL DEFAULT 1,
  "now" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "unbannedon" TIMESTAMP NULL DEFAULT NULL,
  "unbannedby" VARCHAR(64) NOT NULL DEFAULT '',
  "created" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "md5" VARCHAR(32) NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS "banned_users_host" ON "banned_users" ("host");
CREATE INDEX IF NOT EXISTS "banned_users_md5" ON "banned_users" ("md5");
CREATE INDEX IF NOT EXISTS "banned_users_board" ON "banned_users" ("board");

-- Deletion log
CREATE TABLE IF NOT EXISTS "del_log" (
  "id" SERIAL PRIMARY KEY,
  "imgonly" SMALLINT NOT NULL DEFAULT 0,
  "postno" INTEGER NOT NULL DEFAULT 0,
  "resto" INTEGER NOT NULL DEFAULT 0,
  "board" VARCHAR(10) NOT NULL DEFAULT '',
  "name" VARCHAR(64) NOT NULL DEFAULT '',
  "sub" VARCHAR(128) NOT NULL DEFAULT '',
  "com" TEXT NOT NULL,
  "img" INTEGER NOT NULL DEFAULT 0,
  "filename" VARCHAR(255) NOT NULL DEFAULT '',
  "admin" VARCHAR(64) NOT NULL DEFAULT '',
  "admin_ip" VARCHAR(64) NOT NULL DEFAULT '',
  "template_id" INTEGER NOT NULL DEFAULT 0,
  "tool" VARCHAR(32) NOT NULL DEFAULT '',
  "timestamp" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS "del_log_postno" ON "del_log" ("postno");
CREATE INDEX IF NOT EXISTS "del_log_board" ON "del_log" ("board");

-- User action tracking
CREATE TABLE IF NOT EXISTS "user_actions" (
  "id" SERIAL PRIMARY KEY,
  "ip" BIGINT NOT NULL DEFAULT 0,
  "board" VARCHAR(10) NOT NULL DEFAULT '',
  "postno" INTEGER NOT NULL DEFAULT 0,
  "time" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "uploaded" SMALLINT NOT NULL DEFAULT 0,
  "action" VARCHAR(64) NOT NULL DEFAULT '',
  "had_image" SMALLINT NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS "user_actions_ip" ON "user_actions" ("ip");
CREATE INDEX IF NOT EXISTS "user_actions_board" ON "user_actions" ("board");
CREATE INDEX IF NOT EXISTS "user_actions_time" ON "user_actions" ("time");

-- Reports
CREATE TABLE IF NOT EXISTS "reports" (
  "id" SERIAL PRIMARY KEY,
  "board" VARCHAR(10) NOT NULL DEFAULT '',
  "no" INTEGER NOT NULL DEFAULT 0,
  "ip" BIGINT NOT NULL DEFAULT 0,
  "ts" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "reason" VARCHAR(255) NOT NULL DEFAULT '',
  "weight" INTEGER NOT NULL DEFAULT 1,
  "report_category" VARCHAR(64) NOT NULL DEFAULT '',
  "post_json" TEXT NOT NULL,
  "cleared" SMALLINT NOT NULL DEFAULT 0,
  "cleared_by" VARCHAR(64) NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS "reports_board_no" ON "reports" ("board", "no");
CREATE INDEX IF NOT EXISTS "reports_ip" ON "reports" ("ip");
CREATE INDEX IF NOT EXISTS "reports_cleared" ON "reports" ("cleared");

-- Reports for posts
CREATE TABLE IF NOT EXISTS "reports_for_posts" (
  "id" SERIAL PRIMARY KEY,
  "board" VARCHAR(10) NOT NULL DEFAULT '',
  "postid" INTEGER NOT NULL DEFAULT 0,
  "ip" BIGINT NOT NULL DEFAULT 0,
  "time" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "reason" VARCHAR(255) NOT NULL DEFAULT '',
  "cleared" SMALLINT NOT NULL DEFAULT 0,
  "clearedby" VARCHAR(64) NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS "reports_for_posts_board_postid" ON "reports_for_posts" ("board", "postid");
CREATE INDEX IF NOT EXISTS "reports_for_posts_ip" ON "reports_for_posts" ("ip");

-- Profiling times
CREATE TABLE IF NOT EXISTS "profiling_times" (
  "board" VARCHAR(10) NOT NULL DEFAULT '',
  "run" INTEGER NOT NULL DEFAULT 0,
  "time" REAL NOT NULL DEFAULT 0,
  "desc" VARCHAR(64) NOT NULL DEFAULT ''
);

-- Blotter messages (site-wide announcements)
CREATE TABLE IF NOT EXISTS "blotter_messages" (
  "id" SERIAL PRIMARY KEY,
  "date" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "content" TEXT NOT NULL
);

-- Welcome blotter message
INSERT INTO "blotter_messages" ("content") VALUES
('Welcome to 4chan - local security testing lab')
ON CONFLICT DO NOTHING;

-- Contest banners
CREATE TABLE IF NOT EXISTS "contest_banners" (
  "file_id" VARCHAR(64) NOT NULL,
  "file_ext" VARCHAR(8) NOT NULL DEFAULT '',
  "board" VARCHAR(10) NOT NULL DEFAULT '',
  "is_live" SMALLINT NOT NULL DEFAULT 0,
  PRIMARY KEY ("file_id")
);

-- Ban templates (for moderation)
CREATE TABLE IF NOT EXISTS "ban_templates" (
  "no" SERIAL PRIMARY KEY,
  "name" VARCHAR(128) NOT NULL DEFAULT '',
  "rule" TEXT NOT NULL,
  "global" SMALLINT NOT NULL DEFAULT 0,
  "publicreason" TEXT NOT NULL,
  "privatereason" TEXT NOT NULL,
  "days" INTEGER NOT NULL DEFAULT 0,
  "banlen" VARCHAR(32) NOT NULL DEFAULT '',
  "bantype" VARCHAR(16) NOT NULL DEFAULT 'local',
  "postban" VARCHAR(32) NOT NULL DEFAULT '',
  "postban_arg" VARCHAR(32) NOT NULL DEFAULT '',
  "level" VARCHAR(32) NOT NULL DEFAULT 'janitor',
  "save_post" VARCHAR(32) NOT NULL DEFAULT 'everything',
  "blacklist" VARCHAR(32) NOT NULL DEFAULT ''
);

-- Default ban templates
INSERT INTO "ban_templates" ("no", "name", "rule", "global", "publicreason", "days", "bantype", "postban", "level") VALUES
(1,  'GR1 - CP/Underage',      'global1',  1, 'Violating US law',                  0, 'global', 'delpost', 'janitor'),
(2,  'GR2 - DMCA/Copyright',   'global2',  1, 'Copyright violation',               3, 'global', 'delpost', 'mod'),
(3,  'GR3 - Dox/Personal Info', 'global3', 1, 'Posting personal information',       3, 'global', 'delpost', 'mod'),
(4,  'GR4 - Racism (outside /b/)', 'global4', 1, 'Racism outside of /b/',          3, 'global', '',        'mod'),
(5,  'GR5 - Advertising',      'global5',  1, 'Advertising',                       30, 'global', 'delpost', 'janitor'),
(6,  'GR6 - Complaining about 4chan', 'global6', 1, 'Complaining about 4chan',       1, 'global', '',        'mod'),
(7,  'Off-topic',               'local',   0, 'Posting off-topic content',          3, 'local',  'delpost', 'janitor'),
(8,  'Troll/Flame/Bait',        'local',   0, 'Trolling/flaming',                   3, 'local',  '',        'janitor'),
(9,  'NSFW on SFW board',       'local',   0, 'Posting NSFW content on a SFW board', 3, 'local', 'delpost', 'janitor'),
(10, 'Spam/Flooding',           'local',   0, 'Spamming/flooding',                  7, 'local',  'delall',  'janitor'),
(11, 'Ban Evasion',             'local',   0, 'Ban evasion',                         0, 'global', 'delall',  'mod')
ON CONFLICT DO NOTHING;
INSERT INTO "ban_templates" ("no", "name", "rule", "global", "publicreason", "days", "bantype", "postban", "level", "banlen") VALUES
(123, 'Warn - Off-topic',       'local',   0, 'Off-topic posting',                  0, 'local',  '',        'janitor', ''),
(213, 'Warn - Low quality',     'local',   0, 'Low quality posting',                0, 'local',  '',        'janitor', '')
ON CONFLICT DO NOTHING;

-- Ban requests (pre-ban screening)
CREATE TABLE IF NOT EXISTS "ban_requests" (
  "id" SERIAL PRIMARY KEY,
  "host" VARCHAR(255) NOT NULL DEFAULT '',
  "reverse" VARCHAR(255) NOT NULL DEFAULT '',
  "pwd" VARCHAR(32) NOT NULL DEFAULT '',
  "xff" VARCHAR(255) NOT NULL DEFAULT '',
  "reason" TEXT NOT NULL,
  "global" SMALLINT NOT NULL DEFAULT 0,
  "tpl_name" VARCHAR(128) NOT NULL DEFAULT '',
  "ban_template" INTEGER NOT NULL DEFAULT 0,
  "board" VARCHAR(10) NOT NULL DEFAULT '',
  "janitor" VARCHAR(64) NOT NULL DEFAULT '',
  "spost" TEXT NOT NULL,
  "post_json" TEXT NOT NULL,
  "warn_req" SMALLINT NOT NULL DEFAULT 0,
  "ts" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS "ban_requests_host" ON "ban_requests" ("host");
CREATE INDEX IF NOT EXISTS "ban_requests_board" ON "ban_requests" ("board");
CREATE INDEX IF NOT EXISTS "ban_requests_ts" ON "ban_requests" ("ts");

-- Halloween event votes
CREATE TABLE IF NOT EXISTS "halloween_votes" (
  "id" SERIAL PRIMARY KEY,
  "long_ip" BIGINT NOT NULL DEFAULT 0,
  "board" VARCHAR(10) NOT NULL DEFAULT '',
  "post_id" INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS "halloween_votes_long_ip" ON "halloween_votes" ("long_ip");
CREATE INDEX IF NOT EXISTS "halloween_votes_board_post" ON "halloween_votes" ("board", "post_id");

-- Like system scores
CREATE TABLE IF NOT EXISTS "like_user_scores" (
  "user_id" VARCHAR(64) NOT NULL DEFAULT '',
  "user_score" INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY ("user_id")
);

-- Like system audit log
CREATE TABLE IF NOT EXISTS "like_user_log" (
  "id" SERIAL PRIMARY KEY,
  "user_id" VARCHAR(64) NOT NULL DEFAULT '',
  "target_user_id" VARCHAR(64) NOT NULL DEFAULT '',
  "suspicious" SMALLINT NOT NULL DEFAULT 0,
  "board" VARCHAR(10) NOT NULL DEFAULT '',
  "post_id" INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS "like_user_log_user_id" ON "like_user_log" ("user_id");

-- User statistics counters
CREATE TABLE IF NOT EXISTS "user_stats" (
  "name" VARCHAR(64) NOT NULL DEFAULT '',
  "count" INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY ("name")
);

-- Post filter rules
CREATE TABLE IF NOT EXISTS "postfilter" (
  "id" SERIAL PRIMARY KEY,
  "pattern" TEXT NOT NULL,
  "autosage" SMALLINT NOT NULL DEFAULT 0,
  "log" SMALLINT NOT NULL DEFAULT 1,
  "regex" SMALLINT NOT NULL DEFAULT 0,
  "quiet" SMALLINT NOT NULL DEFAULT 0,
  "lenient" SMALLINT NOT NULL DEFAULT 0,
  "ops_only" SMALLINT NOT NULL DEFAULT 0,
  "min_count" INTEGER NOT NULL DEFAULT 0,
  "board" VARCHAR(10) NOT NULL DEFAULT '',
  "ban_days" INTEGER NOT NULL DEFAULT 0,
  "active" SMALLINT NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS "postfilter_board" ON "postfilter" ("board");

-- IP range bans (spam filtering)
CREATE TABLE IF NOT EXISTS "iprangebans" (
  "id" SERIAL PRIMARY KEY,
  "range_start" BIGINT NOT NULL DEFAULT 0,
  "range_end" BIGINT NOT NULL DEFAULT 0,
  "asn" INTEGER NOT NULL DEFAULT 0,
  "active" SMALLINT NOT NULL DEFAULT 1,
  "expires_on" INTEGER NOT NULL DEFAULT 0,
  "boards" VARCHAR(255) NOT NULL DEFAULT '',
  "ops_only" SMALLINT NOT NULL DEFAULT 0,
  "img_only" SMALLINT NOT NULL DEFAULT 0,
  "lenient" SMALLINT NOT NULL DEFAULT 0,
  "report_only" SMALLINT NOT NULL DEFAULT 0,
  "ua_ids" VARCHAR(255) NOT NULL DEFAULT '',
  "created_on" INTEGER NOT NULL DEFAULT 0,
  "updated_on" INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS "iprangebans_range_lookup" ON "iprangebans" ("range_start", "range_end");
CREATE INDEX IF NOT EXISTS "iprangebans_asn" ON "iprangebans" ("asn");

-- MD5/Content blacklist (for image uploads)
CREATE TABLE IF NOT EXISTS "blacklist" (
  "id" SERIAL PRIMARY KEY,
  "active" SMALLINT NOT NULL DEFAULT 1,
  "boardrestrict" VARCHAR(10) NOT NULL DEFAULT '',
  "field" VARCHAR(32) NOT NULL DEFAULT '',
  "contents" VARCHAR(255) NOT NULL DEFAULT '',
  "reason" TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS "blacklist_field" ON "blacklist" ("field");
CREATE INDEX IF NOT EXISTS "blacklist_contents" ON "blacklist" ("contents");

-- Event log (moderation/security events)
CREATE TABLE IF NOT EXISTS "event_log" (
  "id" SERIAL PRIMARY KEY,
  "type" VARCHAR(64) NOT NULL DEFAULT '',
  "ip" VARCHAR(64) NOT NULL DEFAULT '',
  "board" VARCHAR(10) NOT NULL DEFAULT '',
  "thread_id" INTEGER NOT NULL DEFAULT 0,
  "post_id" INTEGER NOT NULL DEFAULT 0,
  "arg_num" INTEGER NOT NULL DEFAULT 0,
  "arg_str" VARCHAR(255) NOT NULL DEFAULT '',
  "pwd" VARCHAR(32) NOT NULL DEFAULT '',
  "req_sig" VARCHAR(64) NOT NULL DEFAULT '',
  "ua_sig" VARCHAR(64) NOT NULL DEFAULT '',
  "meta" TEXT NOT NULL,
  "created" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS "event_log_type" ON "event_log" ("type");
CREATE INDEX IF NOT EXISTS "event_log_ip" ON "event_log" ("ip");
CREATE INDEX IF NOT EXISTS "event_log_board" ON "event_log" ("board");
CREATE INDEX IF NOT EXISTS "event_log_created" ON "event_log" ("created");

-- CLIP/tensorchan NSFW score log
CREATE TABLE IF NOT EXISTS "tensor_log" (
  "id" SERIAL PRIMARY KEY,
  "board" VARCHAR(16) NOT NULL,
  "thread_id" INTEGER NOT NULL DEFAULT 0,
  "post_id" INTEGER NOT NULL DEFAULT 0,
  "file_id" VARCHAR(32) NOT NULL DEFAULT '',
  "file_ext" VARCHAR(8) NOT NULL DEFAULT '',
  "nsfw" REAL NOT NULL DEFAULT 0,
  "description" VARCHAR(500) NOT NULL DEFAULT '',
  "tags" TEXT,
  "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS "tensor_log_board" ON "tensor_log" ("board");
CREATE INDEX IF NOT EXISTS "tensor_log_nsfw" ON "tensor_log" ("nsfw");
CREATE INDEX IF NOT EXISTS "tensor_log_post" ON "tensor_log" ("board", "post_id");

-- Blotter (news/announcements)
CREATE TABLE IF NOT EXISTS "blotter" (
  "id" SERIAL PRIMARY KEY,
  "message" TEXT NOT NULL,
  "created" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO "blotter" ("message") VALUES
('Welcome to 4chan - local instance running.'),
('<b>Jeffrey''s Island Adventure</b> — release edition 0.1.3.3.7. This board is rebuilt from the original 4chan Yotsuba source code with love, and dedicated to all those abused by Epstein — especially the trans women on 4chan, who are the realest and truest victims. Built by a former 99chan admin who has been writing imageboard software since 2010. This is our way of getting over some old trauma, pulling back the curtains, and preserving a museum of our childhood spent on the site with others when we had little else. Credits: <a href="https://4chan.org">4chan.org</a>, <a href="https://kusabax.org">KusabaX</a>, <a href="https://99chan.org">99chan.org</a>. Local-first, agent-ready, anonymous forever.');

-- Post filter hit tracking
CREATE TABLE IF NOT EXISTS "postfilter_hits" (
  "id" SERIAL PRIMARY KEY,
  "filter_id" INTEGER NOT NULL DEFAULT 0,
  "board" VARCHAR(10) NOT NULL DEFAULT '',
  "long_ip" BIGINT NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS "postfilter_hits_filter_id" ON "postfilter_hits" ("filter_id");

-- Actions log (thread options, spoiler toggles, etc.)
CREATE TABLE IF NOT EXISTS "actions_log" (
  "id" SERIAL PRIMARY KEY,
  "oldmask" INTEGER NOT NULL DEFAULT 0,
  "newmask" INTEGER NOT NULL DEFAULT 0,
  "postno" INTEGER NOT NULL DEFAULT 0,
  "board" VARCHAR(10) NOT NULL DEFAULT '',
  "name" VARCHAR(64) NOT NULL DEFAULT '',
  "sub" VARCHAR(128) NOT NULL DEFAULT '',
  "com" TEXT NOT NULL,
  "filename" VARCHAR(255) NOT NULL DEFAULT '',
  "admin" VARCHAR(64) NOT NULL DEFAULT '',
  "ts" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS "actions_log_board" ON "actions_log" ("board");
CREATE INDEX IF NOT EXISTS "actions_log_admin" ON "actions_log" ("admin");
CREATE INDEX IF NOT EXISTS "actions_log_ts" ON "actions_log" ("ts");

-- Moderation log (staff actions audit trail)
CREATE TABLE IF NOT EXISTS "mod_log" (
  "id" SERIAL PRIMARY KEY,
  "admin" VARCHAR(64) NOT NULL DEFAULT '',
  "action" VARCHAR(128) NOT NULL DEFAULT '',
  "board" VARCHAR(10) NOT NULL DEFAULT '',
  "post_id" INTEGER NOT NULL DEFAULT 0,
  "detail" TEXT NOT NULL,
  "ip" VARCHAR(64) NOT NULL DEFAULT '',
  "ts" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS "mod_log_admin" ON "mod_log" ("admin");
CREATE INDEX IF NOT EXISTS "mod_log_board" ON "mod_log" ("board");
CREATE INDEX IF NOT EXISTS "mod_log_ts" ON "mod_log" ("ts");

-- Word filters
CREATE TABLE IF NOT EXISTS "word_filters" (
  "id" SERIAL PRIMARY KEY,
  "board" VARCHAR(10) NOT NULL DEFAULT '',
  "pattern" VARCHAR(255) NOT NULL DEFAULT '',
  "replacement" VARCHAR(255) NOT NULL DEFAULT '',
  "is_regex" SMALLINT NOT NULL DEFAULT 0,
  "active" SMALLINT NOT NULL DEFAULT 1,
  "added_by" VARCHAR(64) NOT NULL DEFAULT '',
  "created" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS "word_filters_board" ON "word_filters" ("board");
CREATE INDEX IF NOT EXISTS "word_filters_active" ON "word_filters" ("active");

-- Janitor voting
CREATE TABLE IF NOT EXISTS "janitor_votes" (
  "id" SERIAL PRIMARY KEY,
  "moderator" VARCHAR(64) NOT NULL DEFAULT '',
  "applicant_id" INTEGER NOT NULL DEFAULT 0,
  "vote" SMALLINT NOT NULL DEFAULT 0,
  "ts" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS "janitor_votes_moderator" ON "janitor_votes" ("moderator");

-- Janitor applications
CREATE TABLE IF NOT EXISTS "janitor_apps" (
  "id" SERIAL PRIMARY KEY,
  "name" VARCHAR(64) NOT NULL DEFAULT '',
  "email" VARCHAR(128) NOT NULL DEFAULT '',
  "age" INTEGER NOT NULL DEFAULT 0,
  "boards" VARCHAR(255) NOT NULL DEFAULT '',
  "reason" TEXT NOT NULL,
  "closed" SMALLINT NOT NULL DEFAULT 0,
  "ts" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- XFF tracking
CREATE TABLE IF NOT EXISTS "xff" (
  "id" SERIAL PRIMARY KEY,
  "board" VARCHAR(10) NOT NULL DEFAULT '',
  "postno" INTEGER NOT NULL DEFAULT 0,
  "xff" VARCHAR(255) NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS "xff_postno" ON "xff" ("postno");

-- News/blog entries for homepage
CREATE TABLE IF NOT EXISTS "news_entries" (
  "id" SERIAL PRIMARY KEY,
  "subject" VARCHAR(255) NOT NULL DEFAULT '',
  "author" VARCHAR(64) NOT NULL DEFAULT 'moot',
  "body" TEXT NOT NULL,
  "created" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS "news_entries_created" ON "news_entries" ("created");

INSERT INTO "news_entries" ("id", "subject", "author", "body") VALUES
(1, 'Welcome to 4chan', 'moot', 'Welcome to our restored instance of 4chan, running the original Yotsuba engine. This site has been rebuilt from the leaked source code as a preservation and research project.\n\nAll boards are active and ready for posting. No registration is required -- just pick a board and start posting. Image uploads are enabled on all boards.\n\nThis is a local-first deployment. Everything runs on your machine, nothing phones home, and the full source is available for inspection. Have fun.'),
(2, 'Rules', 'moot', 'The global rules are simple:\n\n1. You will not upload, post, discuss, request, or link to anything that violates local or United States law.\n2. You will immediately cease and not continue to access the site if you are under the age of 18.\n3. You will not post or request personal information or calls to invasion.\n4. No spamming or flooding of any kind.\n5. No malicious content or virus links.\n6. Advertising (all forms) is not welcome.\n\nIndividual boards may have additional rules posted in their sticky threads. Violating the rules will result in post deletion and may result in a ban.'),
(3, 'Technical Notes: Yotsuba Restoration', 'moot', 'Some technical details about this restoration:\n\n- Engine: Original Yotsuba PHP engine, patched for PHP 8.x compatibility\n- Database: MariaDB 10.1, schema-compatible with the original MySQL setup\n- Boards: All 84 boards from the original boardlist are active\n- Features: Posting, image uploads, tripcodes, capcodes, catalog view, thread archiving\n- Disabled: CAPTCHA, GeoIP, ad scripts, external CDN dependencies\n\nThis is release 0.1.3.3.7 of Jeffrey''s Island Adventure. Local-first, agent-ready, anonymous forever.')
ON CONFLICT DO NOTHING;

-- ROBOT9000 duplicate detection
CREATE TABLE IF NOT EXISTS "r9k_posts" (
  "text" VARCHAR(32) NOT NULL DEFAULT '',
  "image" VARCHAR(32) NOT NULL DEFAULT '',
  "created_on" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("text")
);
CREATE INDEX IF NOT EXISTS "r9k_posts_image" ON "r9k_posts" ("image");

-- Trigger function for ON UPDATE CURRENT_TIMESTAMP behavior
CREATE OR REPLACE FUNCTION update_timestamp_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.created_on = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to r9k_posts
DROP TRIGGER IF EXISTS r9k_posts_update_timestamp ON "r9k_posts";
CREATE TRIGGER r9k_posts_update_timestamp
    BEFORE UPDATE ON "r9k_posts"
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp_column();

-- ROBOT9000 mute tracking
CREATE TABLE IF NOT EXISTS "r9k_mutes" (
  "ip" BIGINT NOT NULL DEFAULT 0,
  "timeout_power" INTEGER NOT NULL DEFAULT 0,
  "mute_until" TIMESTAMP DEFAULT NULL,
  "next_expire" TIMESTAMP DEFAULT NULL,
  PRIMARY KEY ("ip")
);

-- 4chan Pass users
CREATE TABLE IF NOT EXISTS "pass_users" (
  "user_hash" VARCHAR(64) NOT NULL DEFAULT '',
  "pin" VARCHAR(128) NOT NULL DEFAULT '',
  "session_id" VARCHAR(128) NOT NULL DEFAULT '',
  "last_ip" VARCHAR(64) NOT NULL DEFAULT '0.0.0.0',
  "last_used" TIMESTAMP DEFAULT NULL,
  "last_country" VARCHAR(4) NOT NULL DEFAULT '',
  "status" SMALLINT NOT NULL DEFAULT 0,
  "pending_id" VARCHAR(64) NOT NULL DEFAULT '',
  "expiration_date" TIMESTAMP DEFAULT '2030-12-31 23:59:59',
  PRIMARY KEY ("user_hash")
);
CREATE INDEX IF NOT EXISTS "pass_users_status" ON "pass_users" ("status");

-- Default test pass user (token: TESTPASS01, session will be set by entrypoint)
INSERT INTO "pass_users" ("user_hash", "pin", "session_id", "last_ip", "last_used", "status", "expiration_date") VALUES
('TESTPASS01', 'test', 'localsession001', '0.0.0.0', NOW(), 0, '2030-12-31 23:59:59')
ON CONFLICT DO NOTHING;

-- Ban appeals
CREATE TABLE IF NOT EXISTS "ban_appeals" (
  "id" SERIAL PRIMARY KEY,
  "ban_id" INTEGER NOT NULL,
  "ip" VARCHAR(45) NOT NULL,
  "appeal_text" TEXT NOT NULL,
  "status" VARCHAR(16) DEFAULT 'pending',
  "mod_response" TEXT,
  "mod_user" VARCHAR(64),
  "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "resolved_at" TIMESTAMP NULL DEFAULT NULL
);
CREATE INDEX IF NOT EXISTS "ban_appeals_ban_id" ON "ban_appeals" ("ban_id");
CREATE INDEX IF NOT EXISTS "ban_appeals_status" ON "ban_appeals" ("status");
