-- Merge per-board rules from /rules page into sticky posts.
-- Splices a "Board Rules" section before the existing BEHAVIORAL GUIDELINES.

-- /3/ - 3DCG
UPDATE `3` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Images and discussion should relate to 3D modeling and imagery.<br>2. This is a worksafe board. No adult content is allowed.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /a/ - Anime & Manga
UPDATE `a` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All images and resulting discussion should pertain to anime or manga.<br>2. Use spoiler tags: [spoiler]text[/spoiler]. Images may be spoilerized via the checkbox.<br>3. Purposeful spoiling of a series may result in post deletion and temporary ban.<br>4. Live action TV discussion is permitted if rooted in anime or manga.<br>5. Japanese visual novels belong on /jp/, Western on /vg/.<br>6. Threads should have substantial OP text with a meaningful topic. No catch-phrase or template threads.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /aco/ - Adult Cartoons
UPDATE `aco` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Western-style 2D/3DCG adult illustrations only. Eastern-style content belongs on the appropriate board.<br>2. No furry, guro, bestiality, scat, or extreme content. All images should depict "of age" participants.<br>3. All images should be high quality and high resolution.<br>4. No racist remarks, trolls, or bump-replies.<br>5. Provide source information (artist, material) when possible.<br>6. Posting of ''real'' images is discouraged.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /adv/ - Advice
UPDATE `adv` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All advice threads welcome. Offering or requesting is allowed.<br>2. This is the destination for all questions regarding specific personal problems.<br>3. All threads are expected to be constructive. BAWWWing and venting is discouraged.<br>4. No hookup or camwhore threads. Take that to /soc/.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /an/ - Animals & Nature
UPDATE `an` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All images of animals and nature are welcome.<br>2. Posting images depicting animal cruelty is strictly forbidden.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /asp/ - Alternative Sports
UPDATE `asp` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Discussion of alternative sports: skydiving, surfing, skateboarding, rock-climbing, bungee-jumping, BMX, wrestling, paintball, etc.<br>2. Professional sports discussion belongs on /sp/. eSports on /vg/.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /b/ - Random
UPDATE `b` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. ZOMG NONE!!!1<br>2. Global rules 1, 2, 4, 7, 9, 10, 11, 12, 13, 14, and 15 are enforced.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /bant/ - International/Random
UPDATE `bant` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Global rules 1, 2, 4, 7, 9, 10, 11, 12, 13, 14, and 15 are enforced.<br>2. No porn dump threads. Use the appropriate boards for porn.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /biz/ - Business & Finance
UPDATE `biz` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All discussion should pertain to business, finance, economics, markets, currencies (including crypto), and starting/running a business.<br>2. All political discussion belongs on /pol/. Conspiracy theories on /x/.<br>3. No advertising, soliciting, or promotion. Disclose financial interest in discussed projects.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /c/ - Anime/Cute
UPDATE `c` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Images should be cute ("moe") in nature.<br>2. Ecchi belongs on its respective board. Males belong on /cm/.<br>3. Heterosexual couples are allowed.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /cgl/ - Cosplay & EGL
UPDATE `cgl` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Cosplay and elegant gothic lolita (EGL) dress are welcome.<br>2. No community vendettas. Don''t single out cosplayers for trolling.<br>3. J-fashion is allowed. Any ethnicity, but Japanese-origin fashion.<br>4. WAYWT threads should be cosplay/EGL/J-fashion focused. General fashion on /fa/.<br>5. Health threads belong on /adv/ or /fit/.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /ck/ - Food & Cooking
UPDATE `ck` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Images and discussion should relate to food and cooking.<br>2. Recipes are welcome!<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /cm/ - Cute/Male
UPDATE `cm` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Images should depict animated males and be cute/moe. Shounen-ai permitted.<br>2. Yaoi belongs on /y/. Couples belong on /c/.<br>3. Animated content only. No images of real people.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /co/ - Comics & Cartoons
UPDATE `co` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Images and discussion should pertain to Western media.<br>2. Spoiler tag use is enforced.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /d/ - Hentai/Alternative
UPDATE `d` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Alternative content (futanari, bondage, tentacles, etc.) is welcome.<br>2. No bestiality, guro, scat, or extreme content.<br>3. No Western-drawn/toon or fanart images.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /diy/ - Do It Yourself
UPDATE `diy` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. MAKERS GONNA MAKE!<br>2. Do not post or request instructions for making weapons or harmful devices. Think "Instructables" not "Anarchist''s Cookbook."<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /e/ - Ecchi
UPDATE `e` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Suggestive artwork or softcore female nudity of Japanese origin only. No hardcore, alternative, yuri, or yaoi.<br>2. Ecchi is suggestive and cute, but should not be confused with /c/.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /f/ - Flash
UPDATE `f` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All uploaded files should be uniquely Japanese in theme.<br>2. No retail Flash files or Flash exploits.<br>3. Tagging of uploaded files is mandatory.<br>4. If your file would be tagged "[?] Other", re-examine rule 1.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /fa/ - Fashion
UPDATE `fa` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Images and discussion should pertain to fashion and apparel.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /fit/ - Fitness
UPDATE `fit` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Dieting, exercise, healthy living, and workout plans are welcome.<br>2. Relationship, dating advice, and mental health threads belong on /adv/.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /g/ - Technology
UPDATE `g` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Technology images and discussion of past, present, and future welcome.<br>2. Tech support threads should be posted on /wsr/.<br>3. No trolling. Do not instigate or participate in flamewars.<br>4. You may use [code] tags to highlight syntax and preserve whitespace.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /gd/ - Graphic Design
UPDATE `gd` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Discussion of graphic design software and computer-aided techniques.<br>2. Photoshop requests belong on /wsr/ (worksafe) or /r/ (adult).<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /gif/ - Adult GIF
UPDATE `gif` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All GIFs should be animated. No static images.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /h/ - Hentai
UPDATE `h` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Provide artist, character, and source information when available.<br>2. Images should depict "of age" participants. No lolikon or shota.<br>3. Alternative, ecchi, shota, yuri, and yaoi belong on their boards.<br>4. No paysite passwords.<br>5. No Western-drawn/toon or fanart images.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /hc/ - Hardcore
UPDATE `hc` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Only tasteful hardcore pornography allowed.<br>2. No images depicting abuse.<br>3. This board is for straight content.<br>4. Requests belong on /r/.<br>5. No fakes, photo manipulations, or AI generated images.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /his/ - History & Humanities
UPDATE `his` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Discussion of history, philosophy, religion, law, classical artwork, archeology, anthropology, ancient languages, etc.<br>2. Books, poetry, and literature belong on /lit/.<br>3. Politics and current events belong on /pol/. Blatantly racist posts may result in a ban.<br>4. Do not start threads about events less than 25 years ago.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /hm/ - Handsome Men
UPDATE `hm` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Tasteful adult male photos and pornography only. LGBT lifestyle on /lgbt/.<br>2. No images depicting abuse.<br>3. Gay, male content only. No traps or trans content.<br>4. Self pics, rate me, camwhore, and hookup threads on /soc/.<br>5. No fakes, photo manipulations, or AI generated images.<br>6. No underage content. Violators get permanent bans.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /hr/ - High Resolution
UPDATE `hr` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Post quality high-resolution 2D/3D artwork, scans, photography.<br>2. Don''t just post images because they have large dimensions.<br>3. This board is for extremely large images. Not a random board.<br>4. Non-worksafe images allowed, but keep content tasteful.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /i/ - Oekaki
UPDATE `i` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Oekakis can be random, but no junk drawings. Quality over quantity!<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /ic/ - Artwork/Critique
UPDATE `ic` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All images and discussion should pertain to the critique of visual artwork.<br>2. User-created artwork is submitted for critique. Do not claim authorship of others'' work.<br>3. Only constructive criticism. Rude or offensive comments result in a ban.<br>4. No requests for free work.<br>5. No community vendettas. Don''t single out artists for trolling.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /int/ - International
UPDATE `int` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Discussion of foreign culture and language. Please be respectful.<br>2. Posting in languages other than English is allowed and encouraged!<br>3. All politics and current events belong on /pol/.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /jp/ - Otaku Culture
UPDATE `jp` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Light and visual novels, figures, Touhou, Vocaloid, doujin works and music, and diverse niche Japanese interests (kigurumi, idols, mahjong, tea).<br>2. Japanese visual novels here, Western on /vg/. Translated VNs are fine on either board.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /k/ - Weapons
UPDATE `k` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All weaponry is welcome. Military vehicles, knives, and other weapons included — not just firearms!<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /lgbt/ - LGBT
UPDATE `lgbt` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Respectful discussion of LGBT lifestyle and the LGBT community.<br>2. Hookup and rate me/camwhore threads belong on /soc/.<br>3. WORKSAFE BOARD. No nudity or pornography.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /lit/ - Literature
UPDATE `lit` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All literature discussion is welcome, however fan-fic is not allowed.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /m/ - Mecha
UPDATE `m` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All mecha and mecha-related (pilots, core fighter, mecha girl, hobby model) images are allowed.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /mlp/ - Pony
UPDATE `mlp` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. This is the destination for ALL cartoon/anime pony related content on 4chan.<br>2. This is a worksafe board. No pornographic content (including clop).<br>3. Topics must be show-related. People must be associated with the show, not the fandom.<br>4. No roleplay.<br>5. Ponies only — no anthro.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /mu/ - Music
UPDATE `mu` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Discuss music, artists, and instruments. All images should relate to the topic.<br>2. Trolling, instigating, or participating in a flamewar will result in a ban.<br>3. Minimize duplicate topics. Search for existing threads before posting a new one.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /n/ - Transportation
UPDATE `n` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All transportation welcome. Trains, planes, ships, bicycles, etc.<br>2. Automobiles belong on /o/.<br>3. Military vehicles on /k/.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /news/ - Current News
UPDATE `news` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All topics and discussion should be about current news articles. OP must contain a valid URL from a credible news source. No blog or editorial articles.<br>2. News articles should be current — no articles older than 48 hours.<br>3. Global rules in effect. No blatant trolling or racism.<br>4. You can also discuss news articles on /pol/. This board is specifically for current news articles.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /o/ - Auto
UPDATE `o` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All motor vehicle pictures are allowed.<br>2. Photos of models and race queens are permitted if sufficiently clothed.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /out/ - Outdoors
UPDATE `out` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Hiking, camping, geocaching, orienteering, farming, gardening, etc.<br>2. GO OUTSIDE AND TOSS A BALL OR SOMETHING.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /p/ - Photography
UPDATE `p` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Only upload images that you, the photographer, have taken.<br>2. Post photos with thoughtful composition. No random snapshots.<br>3. Post technical information: camera, lens, kit, etc.<br>4. Include a short description — when, where, and under what circumstances.<br>5. Only constructive criticism will be tolerated.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /po/ - Papercraft & Origami
UPDATE `po` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Upload your papercraft and origami images!<br>2. Requesting is permitted.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /pol/ - Politically Incorrect
UPDATE `pol` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Debate and discussion related to politics and current events is welcome.<br>2. You are free to speak your mind, but do not attack other users. Keep it civil!<br>3. No pornography. This is a politics board.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /pw/ - Professional Wrestling
UPDATE `pw` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All images and discussion should pertain to professional wrestling.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /qst/ - Quests
UPDATE `qst` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Author-driven collaborative storytelling ("quests") only. All threads should be part of a new or ongoing quest.<br>2. The author controls the story. Don''t complain if things don''t go your way.<br>3. All threads should be created by the quest author. No meta-threads.<br>4. No erotic roleplay.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /r9k/ - ROBOT9001
UPDATE `r9k` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. A place for hanging out and posting greentext stories.<br>2. Global Rule #3 is in effect — /b/ material belongs on /b/.<br>3. Advice threads belong on /adv/. Rate me, meetup, and camwhore threads on /soc/.<br>4. Purposefully evading the ROBOT9000 filter is not permitted.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /s/ - Sexy Beautiful Women
UPDATE `s` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Images should depict sexy, beautiful women. High quality and high resolution.<br>2. Post photo info if available (model, set, links). Global Rule 4 still applies.<br>3. No hardcore. Take it to /hc/.<br>4. No racist remarks, trolls, or bump-replies.<br>5. No paysite passwords.<br>6. No underage content. Violators get permanent bans.<br>7. No fakes, photo manipulations, or AI generated images.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /s4s/ - Shit 4chan Says
UPDATE `s4s` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. You must check your #fortune in order to post on this board.<br>2. Global rules 1, 2, 4, 6, 7, 9, 10, 11, 12, 13, 14, and 15 are enforced.<br>3. No porn dump threads.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /sci/ - Science & Math
UPDATE `sci` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All science and math related topics welcome.<br>2. Homework threads will be deleted, and the poster banned.<br>3. No "religion vs. science" threads.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /soc/ - Cams & Meetups
UPDATE `soc` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Camming and socializing (rate me, meetup, report in). Photos should be of yourself. No random porn dumps.<br>2. No whining (BAWWW) or life threads.<br>3. No Tinychat or Amazon wishlist/begging threads.<br>4. No soliciting or offering payment for photos/webcam shows.<br>5. Do not stalk or harass users.<br>6. No requesting contact info outside contact/meetup threads.<br>7. Minimize duplicate topics. Search for existing threads before posting.<br>8. Respect the gender of a thread.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /sp/ - Sports
UPDATE `sp` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All sports welcome.<br>2. Combine threads related to similar topics (specific teams, games, players, etc.).<br>3. eSports discussion belongs on /v/. General eSports threads on /vg/.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /t/ - Torrents
UPDATE `t` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All material licensed in the United States is prohibited.<br>2. No warez (retail software, games, movies).<br>3. Content should be Japanese in theme or origin. No anime.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /tg/ - Traditional Games
UPDATE `tg` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Board games, paper games, war games, card games, etc. go here!<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /toy/ - Toys
UPDATE `toy` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Toys, toys, toys!<br>2. No Japanese figurines. Action figures are permitted.<br>3. No "hot glue" fetish images.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /trash/ - Off-Topic
UPDATE `trash` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Global rules 1, 2, 4, 7, 9, 10, 11, 12, and 14 are enforced.<br>2. Don''t complain about your off-topic thread being moved here.<br>3. No lolikon or shota images.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /trv/ - Travel
UPDATE `trv` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Post images and information about locales and travel destinations.<br>2. Questions about other cultures welcome. Post in native languages.<br>3. All countries welcome. The more diverse, the better!<br>4. No discussion of prostitution or sex tourism.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /tv/ - Television & Film
UPDATE `tv` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Content should pertain to TV shows, movies, actors/actresses, film equipment, etc.<br>2. Actor discussion should pertain directly to their roles and careers. Off-topic discussion will be deleted.<br>3. All actress images should be accompanied by relevant discussion.<br>4. Use spoiler tags. Purposeful spoiling is not allowed.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /u/ - Yuri
UPDATE `u` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Yuri genre only. Lesbian and/or softcore, Japanese origin.<br>2. No men in images. Two or more women preferred. Solo images OK if relevant, but solo dumps go to /e/.<br>3. "Of age" participants only. No lolikon or shota.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /v/ - Video Games
UPDATE `v` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All posts should pertain to video games, consoles, and video game culture. Stay on topic.<br>2. No flagrant fanboyism.<br>3. No flamewars. Instigating or encouraging such activity will not be tolerated.<br>4. Don''t repost. Search the board first.<br>5. Purposeful spoiling may result in post deletion and temporary ban. Use spoiler tags.<br>6. "Generals" (long-term, recurring threads) belong on /vg/.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /vg/ - Video Game Generals
UPDATE `vg` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Long-term, recurring threads about specific games ("generals").<br>2. Western visual novels here, Japanese on /jp/. Translated VNs are fine on either board.<br>3. No purposeful spoiling. Use spoiler tags.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /vm/ - Video Games/Multiplayer
UPDATE `vm` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Multiplayer games (online or local, competitive or co-op, any platform). Discussion should focus on multiplayer aspects.<br>2. No fanboy or flamewar threads. No device wars.<br>3. No purposeful spoiling. Use spoiler tags.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /vmg/ - Video Games/Mobile
UPDATE `vmg` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Mobile games (Android, iOS, other phones/tablets). All mobile platforms welcome.<br>2. No fanboy or flamewar threads. No device wars.<br>3. No purposeful spoiling. Use spoiler tags.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /vp/ - Pokemon
UPDATE `vp` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Pokemon related discussion.<br>2. Respect global rules 3 and 5 — no NSFW or furry material.<br>3. Post all Pokegirl hentai to /h/.<br>4. No genwars. Keep discussions civil.<br>5. GOTTA CATCH ''EM ALL. This will be severely punished and strictly enforced.<br>6. No purposeful spoiling. Use spoiler tags.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /vr/ - Retro Games
UPDATE `vr` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Classic/retro games: platforms launched 2001 and earlier, titles released no later than December 2007 (homebrew after this date permitted).<br>2. No flamewars. No personal attacks.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /vrpg/ - Video Games/RPG
UPDATE `vrpg` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. RPG video games (western/JRPG, turn-based/action, MMOs). All platforms welcome.<br>2. No fanboy or flamewar threads. No console wars.<br>3. No purposeful spoiling. Use spoiler tags.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /vst/ - Video Games/Strategy
UPDATE `vst` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Strategy games (turn-based/real-time, tactics, MOBAs, single/multiplayer). All platforms welcome.<br>2. No fanboy or flamewar threads. No console wars.<br>3. No purposeful spoiling. Use spoiler tags.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /vt/ - Virtual YouTubers
UPDATE `vt` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All images and discussion should pertain to VTubers.<br>2. Discussion must pertain directly to their streams and content. Off-topic and IRL discussion will be deleted.<br>3. Don''t single out VTubers for trolling. Do not stalk or harass any VTubers.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /w/ - Anime/Wallpapers
UPDATE `w` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Wallpapers should be distinctly anime or J-pop related.<br>2. Minimum resolution of 480x600 pixels enforced.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /wg/ - Wallpapers/General
UPDATE `wg` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Wallpapers may depict anything within reason. Artistic nudes allowed, but no hardcore or pornographic content.<br>2. Minimum resolution of 480x600 pixels enforced.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /wsg/ - Worksafe GIF
UPDATE `wsg` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All worksafe GIFs welcome.<br>2. All GIFs should be animated. No static images.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /x/ - Paranormal
UPDATE `x` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. For all your creepy images and stories.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /xs/ - Extreme Sports
UPDATE `xs` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. Extreme sports: skydiving, surfing, skateboarding, climbing, bungee-jumping, parkour, BMX, airsoft, paintball, etc.<br>2. Pro sports on /sp/. eSports on /vg/. Pro wrestling on /pw/.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;

-- /y/ - Yaoi
UPDATE `y` SET com = REPLACE(com,
  '<b>BEHAVIORAL GUIDELINES',
  '<b>Board Rules:</b><br>1. All yaoi is allowed, including bara.<br>2. Animated content only. No images of real people.<br>3. "Of age" participants only. No lolikon or shota.<br><br><b>BEHAVIORAL GUIDELINES'
) WHERE no = 1 AND sticky = 1;
