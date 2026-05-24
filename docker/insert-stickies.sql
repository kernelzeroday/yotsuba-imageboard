-- Insert sticky welcome threads for all 75 boards that don't already have one.
-- Boards that ALREADY have stickies (skipped): a, b, d, e, g, h, sci, u

SET @ts = UNIX_TIMESTAMP(NOW());
SET @nowstr = DATE_FORMAT(NOW(), '%m/%d/%y(%a)%H:%i:%s');

-- /3/ - 3DCG
INSERT INTO `3` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /3/ - 3DCG',
'This board is for the discussion of 3DCG (3D Computer Graphics) and related topics such as modeling, rendering, animation, and texturing.<br><br>If you are new, please take the time to read our rules. Keep discussions related to 3D content creation.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `3` AS t;

-- /aco/ - Adult Cartoons
INSERT INTO `aco` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /aco/ - Adult Cartoons',
'This board is for the discussion and sharing of Western-style adult-oriented artwork and cartoons. This is an adult board; all content posted here must be suitable for adults only.<br><br>Please read the rules before posting.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `aco` AS t;

-- /adv/ - Advice
INSERT INTO `adv` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /adv/ - Advice',
'This board is for giving and receiving advice on personal, social, and professional matters.<br><br>Please keep discussions civil and constructive. This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `adv` AS t;

-- /an/ - Animals & Nature
INSERT INTO `an` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /an/ - Animals &amp; Nature',
'This board is for the discussion of animals, nature, and related topics. Post your pets, wildlife photography, and animal-related content here.<br><br>This is a worksafe board. Please be respectful toward animals.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `an` AS t;

-- /asp/ - Alternative Sports & Wrestling
INSERT INTO `asp` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /asp/ - Alternative Sports &amp; Wrestling',
'This board is for the discussion of alternative sports, wrestling, and combat sports. All discussion should be related to athletic competition.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `asp` AS t;

-- /bant/ - International/Random
INSERT INTO `bant` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /bant/ - International/Random',
'This board is the international counterpart to /b/. The stories and information posted here are artistic works of fiction and falsehood. Only a fool would take anything posted here as fact.<br><br>This is a worksafe board. Country flags are enabled.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `bant` AS t;

-- /biz/ - Business & Finance
INSERT INTO `biz` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /biz/ - Business &amp; Finance',
'This board is for the discussion of business, finance, investing, and cryptocurrency. Keep discussions related to financial topics.<br><br>This is a worksafe board. Do not solicit or post financial scams.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `biz` AS t;

-- /c/ - Anime/Cute
INSERT INTO `c` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /c/ - Anime/Cute',
'This board is for the sharing of cute anime images. All images should feature cute anime girls or characters.<br><br>This is a worksafe board. No explicit or NSFW content.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `c` AS t;

-- /cgl/ - Cosplay & EGL
INSERT INTO `cgl` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /cgl/ - Cosplay &amp; EGL',
'This board is for the discussion of cosplay, Elegant Gothic Lolita fashion, and related topics. Share your costumes, coordinate outfits, and discuss conventions.<br><br>This is a worksafe board. Keep criticism constructive.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `cgl` AS t;

-- /ck/ - Food & Cooking
INSERT INTO `ck` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /ck/ - Food &amp; Cooking',
'This board is for the discussion of food, cooking, recipes, and culinary techniques. Share your dishes, ask for advice, and discuss restaurants.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `ck` AS t;

-- /cm/ - Cute/Male
INSERT INTO `cm` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /cm/ - Cute/Male',
'This board is for images of cute and handsome anime boys and male characters. All content should focus on male characters in a cute or aesthetic context.<br><br>This is a worksafe board. No explicit content.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `cm` AS t;

-- /co/ - Comics & Cartoons
INSERT INTO `co` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /co/ - Comics &amp; Cartoons',
'This board is for the discussion of Western comics, cartoons, and animation. Topics include Marvel, DC, indie comics, and animated shows.<br><br>This is a worksafe board. For Japanese animation, use /a/.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `co` AS t;

-- /diy/ - Do It Yourself
INSERT INTO `diy` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /diy/ - Do It Yourself',
'This board is for the discussion of DIY projects, home improvement, woodworking, electronics tinkering, and general craftsmanship.<br><br>This is a worksafe board. Share your projects and help others with theirs.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `diy` AS t;

-- /f/ - Flash
INSERT INTO `f` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /f/ - Flash',
'This board is for the sharing and discussion of Flash animations and games. Upload .swf files to share with other users.<br><br>This is a worksafe board. Please tag your uploads appropriately.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `f` AS t;

-- /fa/ - Fashion
INSERT INTO `fa` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /fa/ - Fashion',
'This board is for the discussion of fashion, clothing, accessories, and personal style. Share outfit ideas, discuss trends, and ask for advice.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `fa` AS t;

-- /fit/ - Fitness
INSERT INTO `fit` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /fit/ - Fitness',
'This board is for the discussion of health, fitness, exercise, diet, and bodybuilding. Share routines, ask for advice, and discuss training methods.<br><br>This is a worksafe board. Read the sticky FAQ before posting.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `fit` AS t;

-- /gd/ - Graphic Design
INSERT INTO `gd` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /gd/ - Graphic Design',
'This board is for the discussion of graphic design, typography, branding, and visual communication. Share your work and critique others constructively.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `gd` AS t;

-- /gif/ - Adult GIF
INSERT INTO `gif` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /gif/ - Adult GIF',
'This board is for the sharing of adult-oriented animated GIFs and WebMs. All content on this board is for adults only.<br><br>Please read the rules before posting. All performers must be 18+.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `gif` AS t;

-- /hc/ - Hardcore
INSERT INTO `hc` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /hc/ - Hardcore',
'This board is for the sharing of hardcore adult images. All content on this board is for adults only.<br><br>All performers must be 18+. Please read the rules before posting.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `hc` AS t;

-- /his/ - History & Humanities
INSERT INTO `his` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /his/ - History &amp; Humanities',
'This board is for the discussion of history, philosophy, religion, and the humanities. Discuss historical events, figures, and ideas.<br><br>This is a worksafe board. Keep discussions academic and on-topic.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `his` AS t;

-- /hm/ - Handsome Men
INSERT INTO `hm` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /hm/ - Handsome Men',
'This board is for the sharing of images of attractive men. All content on this board is for adults only.<br><br>All subjects must be 18+. Please read the rules before posting.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `hm` AS t;

-- /hr/ - High Resolution
INSERT INTO `hr` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /hr/ - High Resolution',
'This board is for the sharing of high-resolution images (minimum 1000x1000 or equivalent). All images should be high quality and high resolution.<br><br>This is a worksafe board. Low-resolution images will be removed.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `hr` AS t;

-- /i/ - Oekaki
INSERT INTO `i` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /i/ - Oekaki',
'This board is for the sharing of Oekaki drawings and digital artwork. Use the built-in drawing tools or share your own artwork.<br><br>This is a worksafe board. Be constructive when commenting on others'' work.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `i` AS t;

-- /ic/ - Artwork/Critique
INSERT INTO `ic` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /ic/ - Artwork/Critique',
'This board is for the sharing and critique of artwork. Post your art and provide constructive feedback to other artists.<br><br>This is a worksafe board. Keep critique constructive and on-topic.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `ic` AS t;

-- /int/ - International
INSERT INTO `int` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /int/ - International',
'This board is for the discussion of foreign cultures, languages, and international topics. Country flags are displayed next to each post.<br><br>This is a worksafe board. Respect other cultures and keep discussions civil.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `int` AS t;

-- /j/ - Photography
INSERT INTO `j` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /j/ - Photography',
'This board is dedicated to photography. Share your photographs, discuss cameras, lenses, composition techniques, and post-processing.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `j` AS t;

-- /jp/ - Otaku Culture
INSERT INTO `jp` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /jp/ - Otaku Culture',
'This board is for the discussion of otaku culture and Japanese-related topics that don''t fit on other boards. Topics include visual novels, Touhou, vocaloid, and Japanese media.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `jp` AS t;

-- /k/ - Weapons
INSERT INTO `k` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /k/ - Weapons',
'This board is for the discussion of weapons, firearms, knives, military equipment, and related topics.<br><br>This is a worksafe board. All discussion of weapons must be legal and responsible. No threats of violence.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `k` AS t;

-- /lgbt/ - LGBT
INSERT INTO `lgbt` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /lgbt/ - LGBT',
'This board is for the discussion of LGBT topics, issues, and experiences. Keep discussions respectful and on-topic.<br><br>This is a worksafe board. No explicit content.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `lgbt` AS t;

-- /lit/ - Literature
INSERT INTO `lit` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /lit/ - Literature',
'This board is for the discussion of literature, books, poetry, and writing. Share recommendations, discuss authors, and talk about the written word.<br><br>This is a worksafe board. Check the recommended reading list before asking for suggestions.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `lit` AS t;

-- /m/ - Mecha
INSERT INTO `m` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /m/ - Mecha',
'This board is for the discussion of mecha anime, manga, models, and related media. Topics include Gundam, Macross, super robot shows, and mecha model kits.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `m` AS t;

-- /mlp/ - Pony
INSERT INTO `mlp` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /mlp/ - Pony',
'This is the board for discussion of My Little Pony: Friendship is Magic and related media. All pony-related content belongs here.<br><br>This is a worksafe board. No explicit content. Keep pony content on this board only.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `mlp` AS t;

-- /mu/ - Music
INSERT INTO `mu` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /mu/ - Music',
'This board is for the discussion of music, musicians, albums, and the music industry. Share what you''re listening to, discuss genres, and recommend music.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `mu` AS t;

-- /n/ - Transportation
INSERT INTO `n` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /n/ - Transportation',
'This board is for the discussion of trains, bicycles, public transit, and all other forms of transportation. Share photos, discuss infrastructure, and talk about getting around.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `n` AS t;

-- /news/ - Current News
INSERT INTO `news` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /news/ - Current News',
'This board is for the discussion of current news and events. All threads must link to a news article or source. Discuss current events objectively.<br><br>This is a worksafe board. All threads must be news-related.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `news` AS t;

-- /o/ - Auto
INSERT INTO `o` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /o/ - Auto',
'This board is for the discussion of automobiles, motorcycles, motorsports, and automotive culture. Share your rides, discuss repairs, and talk about cars.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `o` AS t;

-- /out/ - Outdoors
INSERT INTO `out` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /out/ - Outdoors',
'This board is for the discussion of outdoor activities, camping, hiking, fishing, hunting, and nature exploration.<br><br>This is a worksafe board. Share your outdoor adventures and help others plan theirs.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `out` AS t;

-- /p/ - Photo
INSERT INTO `p` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /p/ - Photography',
'This board is for the discussion and sharing of photographs. Post your best work, discuss technique, equipment, and post-processing.<br><br>This is a worksafe board. Provide constructive criticism when commenting on photos.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `p` AS t;

-- /po/ - Papercraft & Origami
INSERT INTO `po` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /po/ - Papercraft &amp; Origami',
'This board is for the discussion and sharing of papercraft, origami, and paper-based art projects. Share templates, tutorials, and your finished work.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `po` AS t;

-- /pol/ - Politically Incorrect
INSERT INTO `pol` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /pol/ - Politically Incorrect',
'This board is for the discussion of news, world events, political issues, and other related topics. Country flags are displayed next to each post.<br><br>This is a worksafe board. Off-topic and shitposting threads will be deleted.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `pol` AS t;

-- /pw/ - Professional Wrestling
INSERT INTO `pw` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /pw/ - Professional Wrestling',
'This board is for the discussion of professional wrestling, including WWE, AEW, NJPW, and all other promotions. Discuss matches, storylines, and wrestlers.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `pw` AS t;

-- /qa/ - Question & Answer
INSERT INTO `qa` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /qa/ - Question &amp; Answer',
'This board is for discussion about the site itself: boards, features, suggestions, and meta-topics. Ask questions and provide feedback here.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `qa` AS t;

-- /qb/ - QB (Question Board)
INSERT INTO `qb` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /qb/ - Question Board',
'This board is for general questions and discussion. If you have a question that doesn''t fit on another board, ask it here.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `qb` AS t;

-- /qst/ - Quests
INSERT INTO `qst` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /qst/ - Quests',
'This board is for the creation and participation in quests - collaborative, choice-driven storytelling threads where the audience votes on the protagonist''s actions.<br><br>This is a worksafe board. Quest masters should clearly label their threads.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `qst` AS t;

-- /r/ - Adult Requests
INSERT INTO `r` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /r/ - Adult Requests',
'This board is for requesting and sharing adult content. All content on this board is for adults only.<br><br>Please be specific with your requests and include reference images when possible. All subjects must be 18+.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `r` AS t;

-- /r9k/ - ROBOT9001
INSERT INTO `r9k` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /r9k/ - ROBOT9001',
'This board is for the discussion of online culture, feelings, and experiences. The ROBOT9001 script prevents exact reposts of previously submitted content.<br><br>This is a worksafe board. Greentext stories and personal blogging are welcome.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `r9k` AS t;

-- /s/ - Sexy Beautiful Women
INSERT INTO `s` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /s/ - Sexy Beautiful Women',
'This board is for the sharing of softcore images of beautiful women. All content on this board is for adults only.<br><br>All subjects must be 18+. Keep content tasteful and softcore. Hardcore content belongs on /hc/.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `s` AS t;

-- /s4s/ - Shit 4chan Says
INSERT INTO `s4s` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /s4s/ - Shit 4chan Says',
'This board is for fun and shitposting. There are minimal rules - just have fun and be excellent to each other.<br><br>This is a worksafe board. le ebin memes xDDD',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `s4s` AS t;

-- /soc/ - Cams & Meetups
INSERT INTO `soc` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /soc/ - Cams &amp; Meetups',
'This board is for socializing, meetup threads, and cam/rate threads. This is the only board where posting personal information about yourself is allowed.<br><br>All participants must be 18+. Be safe when meeting people from the internet.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `soc` AS t;

-- /sp/ - Sports
INSERT INTO `sp` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /sp/ - Sports',
'This board is for the discussion of sports, sporting events, athletes, and teams. Discuss live games, post highlights, and debate your favorite teams.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `sp` AS t;

-- /t/ - Torrents
INSERT INTO `t` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /t/ - Torrents',
'This board is for the discussion and sharing of torrents and file-sharing. Share magnet links and discuss content.<br><br>This is an adult board. Please read the rules before posting.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `t` AS t1;

-- /test/ - Test
INSERT INTO `test` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /test/ - Test',
'This board is for testing posting functionality. Feel free to make test posts here. Your posts may be periodically cleaned up.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `test` AS t;

-- /tg/ - Traditional Games
INSERT INTO `tg` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /tg/ - Traditional Games',
'This board is for the discussion of tabletop RPGs, board games, card games, war games, and other traditional games. Topics include D&amp;D, Warhammer, Magic: The Gathering, and more.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `tg` AS t;

-- /toy/ - Toys
INSERT INTO `toy` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /toy/ - Toys',
'This board is for the discussion and sharing of toys, action figures, collectibles, and related merchandise. Share your collection and discuss new releases.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `toy` AS t;

-- /trash/ - Off-Topic
INSERT INTO `trash` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /trash/ - Off-Topic',
'This board is the designated dumping ground for threads that don''t belong on other boards. Content here is largely unmoderated.<br><br>This is an adult board. Anything goes within the bounds of US law and global rules.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `trash` AS t;

-- /trv/ - Travel
INSERT INTO `trv` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /trv/ - Travel',
'This board is for the discussion of travel, destinations, trip planning, and travel experiences. Share photos and advice from your trips.<br><br>This is a worksafe board. Be helpful to fellow travelers.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `trv` AS t;

-- /tv/ - Television & Film
INSERT INTO `tv` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /tv/ - Television &amp; Film',
'This board is for the discussion of television shows, movies, actors, and the entertainment industry. Discuss current shows, recommend films, and debate your favorites.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `tv` AS t;

-- /v/ - Video Games
INSERT INTO `v` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /v/ - Video Games',
'This board is for the discussion of video games. Talk about games you''re playing, upcoming releases, game design, and the industry.<br><br>This is a worksafe board. For game-specific generals, use /vg/.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `v` AS t;

-- /vg/ - Video Game Generals
INSERT INTO `vg` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /vg/ - Video Game Generals',
'This board is for ongoing discussion of specific video games in general threads. Create or join a general thread for your favorite game.<br><br>This is a worksafe board. Each general should have a clear topic in the subject field.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `vg` AS t;

-- /vip/ - Very Important Posts
INSERT INTO `vip` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /vip/ - Very Important Posts',
'This board is exclusively for 4chan Pass users. Enjoy your discussion free from the masses. Topics can be anything within global rules.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `vip` AS t;

-- /vm/ - Video Games/Multiplayer
INSERT INTO `vm` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /vm/ - Video Games/Multiplayer',
'This board is for the discussion of multiplayer and competitive video games. Discuss online games, find groups, and share strategies.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `vm` AS t;

-- /vmg/ - Video Games/Mobile
INSERT INTO `vmg` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /vmg/ - Video Games/Mobile',
'This board is for the discussion of mobile and gacha video games. Discuss your favorite mobile games, share tips, and talk about new releases.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `vmg` AS t;

-- /vp/ - Pok&eacute;mon
INSERT INTO `vp` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /vp/ - Pok&eacute;mon',
'This board is for the discussion of Pok&eacute;mon in all its forms: games, anime, manga, trading cards, and competitive battling. All Pok&eacute;mon content belongs here.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `vp` AS t;

-- /vr/ - Retro Games
INSERT INTO `vr` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /vr/ - Retro Games',
'This board is for the discussion of classic and retro video games, including consoles, arcades, and PC games from older generations. Emulation discussion is welcome.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `vr` AS t;

-- /vrpg/ - Video Games/RPG
INSERT INTO `vrpg` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /vrpg/ - Video Games/RPG',
'This board is for the discussion of role-playing video games, including JRPGs, WRPGs, action RPGs, and tactical RPGs. Discuss your favorite RPGs and share recommendations.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `vrpg` AS t;

-- /vst/ - Video Games/Strategy
INSERT INTO `vst` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /vst/ - Video Games/Strategy',
'This board is for the discussion of strategy video games, including RTS, turn-based strategy, grand strategy, 4X, and city-building games.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `vst` AS t;

-- /vt/ - Virtual YouTubers
INSERT INTO `vt` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /vt/ - Virtual YouTubers',
'This board is for the discussion of Virtual YouTubers (VTubers), including Hololive, Nijisanji, independents, and related content. Discuss streams, clips, and news.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `vt` AS t;

-- /w/ - Anime/Wallpapers
INSERT INTO `w` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /w/ - Anime/Wallpapers',
'This board is for the sharing of anime and manga-related wallpapers. All images should be wallpaper-quality resolution (at least 1024x768 or equivalent).<br><br>This is a worksafe board. No explicit content.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `w` AS t;

-- /wg/ - Wallpapers/General
INSERT INTO `wg` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /wg/ - Wallpapers/General',
'This board is for the sharing of desktop and mobile wallpapers of all kinds. All images should be wallpaper-quality resolution.<br><br>This is a worksafe board. No explicit content. Anime wallpapers belong on /w/.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `wg` AS t;

-- /wsg/ - Worksafe GIF
INSERT INTO `wsg` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /wsg/ - Worksafe GIF',
'This board is for the sharing of worksafe animated GIFs and WebMs. All content must be safe for work.<br><br>Keep content worksafe. NSFW content belongs on /gif/.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `wsg` AS t;

-- /wsr/ - Worksafe Requests
INSERT INTO `wsr` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /wsr/ - Worksafe Requests',
'This board is for making worksafe requests. Ask for help finding images, identifying songs, solving tech problems, or any other worksafe request.<br><br>This is a worksafe board. Be specific with your requests.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `wsr` AS t;

-- /x/ - Paranormal
INSERT INTO `x` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /x/ - Paranormal',
'This board is for the discussion of the paranormal, supernatural, occult, and unexplained phenomena. Topics include ghosts, aliens, cryptids, conspiracy theories, and the esoteric.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `x` AS t;

-- /xs/ - Extreme Sports
INSERT INTO `xs` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /xs/ - Extreme Sports',
'This board is for the discussion of extreme sports including skateboarding, surfing, snowboarding, BMX, climbing, and other action sports.<br><br>This is a worksafe board.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `xs` AS t;

-- /y/ - Yaoi
INSERT INTO `y` (no, resto, root, now, time, last_modified, name, sub, com, host, pwd, tim, capcode, sticky, closed)
SELECT COALESCE(MAX(no),0)+1, 0, @ts, @nowstr, @ts, @ts, 'moot',
'Welcome to /y/ - Yaoi',
'This board is for the sharing of yaoi (male/male) artwork and images. All content on this board is for adults only.<br><br>All characters depicted must be 18+. Please read the rules before posting.',
'127.0.0.1', '', @ts, 'admin', 1, 1
FROM `y` AS t;
