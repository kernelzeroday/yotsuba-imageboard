-- Add Jeffrey's Island Adventure release announcement if not present
INSERT INTO `blotter` (`message`)
SELECT '<b>Jeffrey''s Island Adventure</b> — release edition 0.1.3.3.7. This board is rebuilt from the original 4chan Yotsuba source code with love, and dedicated to all those abused by Epstein — especially the trans women on 4chan, who are the realest and truest victims. Built by a former 99chan admin who has been writing imageboard software since 2010. This is our way of getting over some old trauma, pulling back the curtains, and preserving a museum of our childhood spent on the site with others when we had little else. Credits: <a href="https://4chan.org">4chan.org</a>, <a href="https://kusabax.org">KusabaX</a>, <a href="https://99chan.org">99chan.org</a>. Local-first, agent-ready, anonymous forever.'
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM blotter WHERE message LIKE '%Jeffrey%Island%');
