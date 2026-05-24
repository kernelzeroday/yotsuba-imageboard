-- Classic and amusing wordfilters in the 4chan tradition.
-- These go in the word_filters DB table, complementing the hardcoded ones
-- in wordfilters/global.php (smh→baka, tbh→desu, fam→senpai, soy→onions).

INSERT IGNORE INTO word_filters (pattern, replacement, board, is_regex, active, added_by) VALUES
-- The classic: origin of the word "weeaboo" (2005, Perry Bible Fellowship comic)
('wapanese', 'weeaboo', '', 0, 1, 'moot'),

-- Wholesome upgrade
('normie', 'normalfriend', '', 0, 1, 'moot'),
('normies', 'normalfriends', '', 0, 1, 'moot'),

-- Circular filter pair (the endless cycle)
('cope', 'seethe', '', 0, 1, 'moot'),
('seethe', 'cope', '', 0, 1, 'moot'),

-- Classical vocabulary upgrades
('yeet', 'defenestrate', '', 0, 1, 'moot'),
('yeeted', 'defenestrated', '', 0, 1, 'moot'),
('sus', 'suspicious', '', 0, 1, 'moot'),
('bussin', 'delectable', '', 0, 1, 'moot'),
('bruh', 'my good sir', '', 0, 1, 'moot'),
('rizz', 'charisma', '', 0, 1, 'moot'),

-- Volume swap
('lowkey', 'HIGHKEY', '', 0, 1, 'moot'),
('highkey', 'lowkey', '', 0, 1, 'moot'),

-- D&D stat block
('sigma', 'ligma', '', 0, 1, 'moot'),

-- Formal expansions
('imo', 'in this humble anon''s opinion', '', 0, 1, 'moot'),
('ngl', 'not gonna sugarcoat it', '', 0, 1, 'moot'),
('no cap', 'verily', '', 0, 1, 'moot'),

-- Positivity enforcement
('mid', 'acceptable', '', 0, 1, 'moot'),
('L take', 'W take', '', 0, 1, 'moot'),
('copium', 'hopium', '', 0, 1, 'moot'),

-- International flair
('based', 'basado', '', 0, 1, 'moot');
