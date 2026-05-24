-- Restore stickies that were lost.
-- Strategy: delete all no=1 posts, remove migration markers for 008/009/010/012,
-- so the migration runner re-applies them fresh on next run.

-- Preserve /ck/'s existing user post (no=1, sticky=0, "Cow Gallstones > Gold")
-- by moving it to a safe post number
SET @ck_max = (SELECT IFNULL(MAX(no), 1) FROM `ck`);
UPDATE `ck` SET no = @ck_max + 1 WHERE no = 1 AND sticky = 0;

-- Delete any remaining no=1 posts across all board tables
DELETE FROM `3` WHERE no = 1;
DELETE FROM `a` WHERE no = 1;
DELETE FROM `aco` WHERE no = 1;
DELETE FROM `adv` WHERE no = 1;
DELETE FROM `an` WHERE no = 1;
DELETE FROM `asp` WHERE no = 1;
DELETE FROM `b` WHERE no = 1;
DELETE FROM `bant` WHERE no = 1;
DELETE FROM `biz` WHERE no = 1;
DELETE FROM `c` WHERE no = 1;
DELETE FROM `cgl` WHERE no = 1;
DELETE FROM `ck` WHERE no = 1;
DELETE FROM `cm` WHERE no = 1;
DELETE FROM `co` WHERE no = 1;
DELETE FROM `d` WHERE no = 1;
DELETE FROM `diy` WHERE no = 1;
DELETE FROM `e` WHERE no = 1;
DELETE FROM `f` WHERE no = 1;
DELETE FROM `fa` WHERE no = 1;
DELETE FROM `fit` WHERE no = 1;
DELETE FROM `g` WHERE no = 1;
DELETE FROM `gd` WHERE no = 1;
DELETE FROM `gif` WHERE no = 1;
DELETE FROM `h` WHERE no = 1;
DELETE FROM `hc` WHERE no = 1;
DELETE FROM `his` WHERE no = 1;
DELETE FROM `hm` WHERE no = 1;
DELETE FROM `hr` WHERE no = 1;
DELETE FROM `i` WHERE no = 1;
DELETE FROM `ic` WHERE no = 1;
DELETE FROM `int` WHERE no = 1;
DELETE FROM `j` WHERE no = 1;
DELETE FROM `jp` WHERE no = 1;
DELETE FROM `k` WHERE no = 1;
DELETE FROM `lgbt` WHERE no = 1;
DELETE FROM `lit` WHERE no = 1;
DELETE FROM `m` WHERE no = 1;
DELETE FROM `mlp` WHERE no = 1;
DELETE FROM `mu` WHERE no = 1;
DELETE FROM `n` WHERE no = 1;
DELETE FROM `o` WHERE no = 1;
DELETE FROM `out` WHERE no = 1;
DELETE FROM `p` WHERE no = 1;
DELETE FROM `po` WHERE no = 1;
DELETE FROM `pol` WHERE no = 1;
DELETE FROM `pw` WHERE no = 1;
DELETE FROM `qa` WHERE no = 1;
DELETE FROM `qb` WHERE no = 1;
DELETE FROM `qst` WHERE no = 1;
DELETE FROM `r` WHERE no = 1;
DELETE FROM `r9k` WHERE no = 1;
DELETE FROM `s` WHERE no = 1;
DELETE FROM `s4s` WHERE no = 1;
DELETE FROM `sci` WHERE no = 1;
DELETE FROM `soc` WHERE no = 1;
DELETE FROM `sp` WHERE no = 1;
DELETE FROM `t` WHERE no = 1;
DELETE FROM `tg` WHERE no = 1;
DELETE FROM `toy` WHERE no = 1;
DELETE FROM `trash` WHERE no = 1;
DELETE FROM `trv` WHERE no = 1;
DELETE FROM `tv` WHERE no = 1;
DELETE FROM `u` WHERE no = 1;
DELETE FROM `v` WHERE no = 1;
DELETE FROM `vg` WHERE no = 1;
DELETE FROM `vip` WHERE no = 1;
DELETE FROM `vm` WHERE no = 1;
DELETE FROM `vmg` WHERE no = 1;
DELETE FROM `vp` WHERE no = 1;
DELETE FROM `vr` WHERE no = 1;
DELETE FROM `vrpg` WHERE no = 1;
DELETE FROM `vst` WHERE no = 1;
DELETE FROM `vt` WHERE no = 1;
DELETE FROM `w` WHERE no = 1;
DELETE FROM `wg` WHERE no = 1;
DELETE FROM `wsg` WHERE no = 1;
DELETE FROM `wsr` WHERE no = 1;
DELETE FROM `x` WHERE no = 1;
DELETE FROM `xs` WHERE no = 1;
DELETE FROM `y` WHERE no = 1;

-- Remove sticky-related migration markers so they re-run
DELETE FROM schema_migrations WHERE version IN (
  '008_behavioral_stickies.sql',
  '009_lock_stickies.sql',
  '010_sticky_board_rules.sql',
  '012_global_rules_in_stickies.sql'
);
