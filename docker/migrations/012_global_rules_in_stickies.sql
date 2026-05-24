-- Add global rules to all board stickies
-- Inserts before the board-specific "Board Rules:" section

SET @global_rules = CONCAT(
  '<b>Global Rules:</b><br>',
  '1. You will not upload, post, discuss, request, or link to anything that violates local or United States law.<br>',
  '2. You will immediately cease and not continue to access the site if you are under the age of 18.<br>',
  '3. You will not post any of the following outside of /b/: Troll posts, Racism, Anthropomorphic ("furry") pornography, Grotesque ("guro") images, Loli/shota pornography, Dubs or GET posts.<br>',
  '4. You will not post or request personal information ("dox") or calls to invasion ("raids"). Inciting or participating in cross-board raids is also not permitted.<br>',
  '5. All boards that default to the Yotsuba B (blue) theme are to be considered "work safe". Violators may be temporarily banned and their posts removed. Spoilered pornography or other NSFW content is NOT allowed on work safe boards.<br>',
  '6. The quality of posts is extremely important to this community. Contributors are encouraged to provide high-quality images and informative comments.<br>',
  '7. Submitting false or misclassified reports, or otherwise abusing the reporting system may result in a ban.<br>',
  '8. Complaining about 4chan (its policies, moderation, etc) on the imageboards may result in post deletion and a ban.<br>',
  '9. Evading your ban will result in a permanent one. Instead, wait and appeal it!<br>',
  '10. No spamming or flooding of any kind. No intentionally evading spam or post filters.<br>',
  '11. Advertising (all forms) is not welcome — this includes any type of referral linking, "offers", soliciting, begging, stream threads, etc.<br>',
  '12. Impersonating a 4chan administrator, moderator, or janitor is strictly forbidden.<br>',
  '13. Do not use avatars or attach signatures to your posts.<br>',
  '14. The use of scrapers, bots, or other automated posting or downloading scripts is prohibited. Users may also not post from proxies, VPNs, or Tor exit nodes.<br>',
  '15. All pony/brony threads, images, Flashes, and avatars belong on /mlp/.<br>',
  '16. All request threads for work-safe content belong on /wsr/, unless otherwise noted.<br>',
  '17. Do not upload images containing additional data such as embedded sounds, documents, archives, etc.<br>',
  '<br>Global rules apply to all boards unless otherwise noted.<br>',
  'Remember: The use of 4chan is a privilege, not a right. The 4chan moderation team reserves the right to revoke access and remove content for any reason without notice.<br><br>'
);

-- For each board, insert global rules before board-specific rules
-- Pattern: ... welcome text ... <b>Board Rules:</b> ...
-- Becomes: ... welcome text ... <b>Global Rules:</b> ... <b>Board Rules:</b> ...

UPDATE `3` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `a` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `aco` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `adv` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `an` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `asp` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `b` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `bant` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `biz` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `c` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `cgl` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `ck` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `cm` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `co` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `d` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `diy` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `e` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `f` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `fa` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `fit` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `g` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `gd` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `gif` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `h` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `hc` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `his` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `hm` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `hr` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `i` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `ic` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `int` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `jp` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `k` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `lgbt` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `lit` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `m` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `mlp` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `mu` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `n` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `news` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `o` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `out` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `p` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `po` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `pol` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `pw` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `qa` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `qst` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `r` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `r9k` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `s` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `s4s` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `sci` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `soc` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `sp` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `t` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `tg` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `toy` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `trash` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `trv` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `tv` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `u` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `v` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `vg` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `vip` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `vm` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `vmg` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `vp` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `vr` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `vrpg` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `vst` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `vt` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `w` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `wg` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `wsg` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `wsr` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `x` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `xs` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
UPDATE `y` SET com = REPLACE(com, '<b>Board Rules:</b>', CONCAT(@global_rules, '<b>Board Rules:</b>')) WHERE no=1 AND sticky=1 AND com NOT LIKE '%Global Rules:%';
