# Feature Matrix: Yotsuba vs 99chan vs vichan

Cross-reference of three imageboard engines. **Status** reflects what exists in code, not necessarily what's working in our local Docker instance.

Legend: **Y** = Yes/Full | **P** = Partial/Stubbed | **N** = No/Missing | **~** = Different approach

## Core Posting

| Feature | Yotsuba (4chan) | 99chan (Kusaba) | vichan (Tinyboard) |
|---------|:-:|:-:|:-:|
| Image posting | Y | Y | Y |
| Text-only boards | Y | Y (type 1) | Y |
| Greentext (>) | Y | Y | Y |
| BBCode ([b], [i], [s], [spoiler]) | N (HTML tags) | Y | ~ (markdown) |
| Markdown (**bold**, ''italic'') | N | N | Y |
| [code] tags | Y | Y | Y (configurable) |
| [math] / [eqn] tags | P (infra only) | N | N |
| [sjis] art tags | Y | Y ([aa]) | N |
| Sage | Y | Y | Y |
| Noko | Y | Y | Y |
| Tripcodes (regular #) | Y (DES crypt) | Y (DES crypt) | Y (SHA1 salt) |
| Tripcodes (secure ##) | Y (SHA1+salt) | Y (MD5+seed) | Y (SHA1+salt) |
| Custom/forced tripcodes | N | Y (DB lookup) | Y (config map) |
| Dice rolling | Y (email field) | N | Y (email + inline) |
| Fortune telling | Y (/s4s/) | N | N |
| Max comment length | Y (configurable) | Y | Y |
| Duplicate post detection | Y (text+time) | Y (text+file MD5) | Y (hash-based) |
| Clipboard image paste | Y (our addition) | N | N |

## File Handling

| Feature | Yotsuba | 99chan | vichan |
|---------|:-:|:-:|:-:|
| JPG/PNG/GIF upload | Y | Y | Y |
| WebM upload | Y | N | Y |
| MP4 upload | Y | N | Y (via config) |
| PDF upload | Y (thumbnail via GS) | N | N |
| SWF/Flash upload (/f/) | Y | N | N |
| SVG upload | N | Y | Y (optional) |
| WebP upload | N | N | Y |
| BMP upload | N | N | Y |
| EXIF stripping | Y (custom per-format) | N (GD implicit) | Y (exiftool) |
| Thumbnail generation | Y (GD) | Y (GD/ImageMagick) | Y (GD/IM/GM) |
| Spoiler images | Y (per-board variants) | N | Y |
| Duplicate file rejection | Y (MD5) | Y (MD5) | Y (configurable scope) |
| File size limits | Y (per-board) | Y (per-board) | Y (global/per-board) |
| Dimension limits | Y | Y | Y |
| WebM duration limit | Y | N/A | Y (default 120s) |
| WebM audio control | Y (strip option) | N/A | Y (configurable) |
| Animated GIF processing | Y (gifsicle) | Y | Y |
| Multiple file upload | N | N | Y (extra_files) |
| Remote thumb server | N | Y (load balancer) | N |
| Image ID links (GIS/IQDB) | Y (JS extension) | N | Y (configurable) |
| Oekaki/Tegaki drawing | Y (HTML5 canvas) | Y (Java Shi-Painter) | N |
| Drawing replay | Y (.tgkr format) | Y (.pch format) | N |

## User Identity

| Feature | Yotsuba | 99chan | vichan |
|---------|:-:|:-:|:-:|
| Anonymous posting | Y | Y | Y |
| Poster IDs (per-thread) | Y (SHA1, colored) | N | Y (configurable) |
| Country flags | Y (GeoIP2/MaxMind) | N | Y (configurable) |
| Board-specific flags | Y (/pol/, /mlp/) | N | N |
| Capcodes (admin/mod/etc) | Y (7 types + icons) | Y (2 types, colored) | Y (configurable per-level) |
| Forced anonymity | Y (per-board) | Y | Y |
| 4chan Pass / user accounts | Y (pass_users) | N | N |
| User registration | N | N | N |
| IP-based user tracking | Y (userpwd system) | Y (IP only) | Y (IP only) |

## Moderation & Admin

| Feature | Yotsuba | 99chan | vichan |
|---------|:-:|:-:|:-:|
| Staff hierarchy levels | 4 (jan/mod/mgr/admin) | 3 (jan/mod/admin) | 3 (jan/mod/admin) |
| Per-board staff assignment | Y | Y | Y |
| Staff 2FA (TOTP) | Y (Google Auth) | N | N |
| Granular permission flags | Y (ban,capcode,html,etc) | N (level-based) | Y (extensive) |
| Post deletion (user) | Y (password-based) | Y (password-based) | Y (password-based) |
| Post deletion (mod) | Y + audit log | Y + mod log | Y + modlog |
| File-only deletion | Y | Y | Y |
| Delete all by IP | Y (global option) | Y | Y (global option) |
| Post editing (admin) | N | Y (with visibility) | Y (admin only) |
| Thread sticky | Y (with position) | Y | Y |
| Thread lock/close | Y | Y | Y |
| Thread cycle (auto-bump) | N | N | Y |
| Permasage / bumplock | Y | N | Y |
| Move thread between boards | N | Y | Y |
| IP search (find all posts) | Y | Y | Y (with notes) |
| Moderation log | Y (mod_log table) | Y | Y (modlogs table) |
| Deletion log | Y (del_log table) | N (in mod log) | N (in modlog) |
| Staff PM system | N | N | Y |
| Staff noticeboard | N | N | Y |
| Direct SQL access | N | Y (admin only) | N |
| Template editing | N | Y | N |
| Statistics dashboard | N | Y | Y (dashboard) |

## Ban System

| Feature | Yotsuba | 99chan | vichan |
|---------|:-:|:-:|:-:|
| Single IP bans | Y | Y (MD5 hashed) | Y |
| IP range bans | Y (range_start/end) | Y (prefix-based) | Y (CIDR + wildcard) |
| ASN-based bans | Y | N | N |
| IPv6 support | P | N | Y |
| Global vs board bans | Y | Y | Y |
| Temporary bans (expiry) | Y | Y | Y |
| Permanent bans | Y | Y | Y |
| Ban appeals | Y (full workflow) | Y (with deadline) | Y (approve/deny) |
| Ban templates | Y (extensive) | N | N |
| Ban page display | Y | Y | Y |
| Read-only bans | N | Y | N |
| OP-only bans | Y | N | N |
| Image-only bans | Y | N | N |
| UA-based bans | Y | N | N |
| Child post bans (ban OP+replies) | Y | N | N |
| .htaccess integration | N | Y | N |
| Cookie-based evasion detection | N | Y | N |
| Pass revocation on ban | Y | N/A | N/A |
| IP whitelist (CDN/proxy) | Y | N | Y (DNSBL exceptions) |

## Report System

| Feature | Yotsuba | 99chan | vichan |
|---------|:-:|:-:|:-:|
| Post reporting | Y | Y | Y |
| Report categories | Y (including illegal) | N | N |
| Report queue (weighted) | Y (top 200) | Y | Y |
| Rate limiting | Y (hourly+daily) | N | N |
| Auto-delete threshold | Y | N | N |
| Report captcha | Y (bypass for known) | Y | Y (optional) |
| Illegal content tracking | Y (NCMEC) | N | N |
| Reporter IP tracking | Y | Y | Y |
| Report dismissal | Y | Y | Y |

## Captcha System

| Feature | Yotsuba | 99chan | vichan |
|---------|:-:|:-:|:-:|
| Built-in captcha | N | Y (GD image) | Y (native) |
| reCAPTCHA | P (v3 referenced) | Y (v1) | N |
| hCaptcha (Twister) | Y | N | N |
| Captcha bypass credits | Y (reputation-based) | N | N |
| Pass bypasses captcha | Y | N/A | N/A |
| Report captcha | Y | Y | Y |
| Dynamic captcha loading | N | N | Y |

## Spam & Flood Protection

| Feature | Yotsuba | 99chan | vichan |
|---------|:-:|:-:|:-:|
| Post cooldown timers | Y (RENZOKU*) | Y (per-IP delay) | Y (configurable) |
| Thread creation cooldown | Y (RENZOKU3) | Y | Y |
| Image post cooldown | Y (RENZOKU2) | Y | Y |
| Per-thread flood detection | Y | N | N |
| Bot/automation detection | Y (header heuristics) | N | N |
| Browser fingerprinting | Y (req_sig) | N | N |
| Threat scoring | Y (multi-factor) | N | N |
| URL spam blacklist | N | Y (spam.txt + DB) | N |
| DNS Blacklist (DNSBL) | N | N | Y (multi-provider) |
| Proxy/VPN/Tor detection | Y (BanBuster UA) | Y (proxyban) | P (via DNSBL) |
| Image hash blacklist | Y (MD5, DMCA) | N | N |
| Post content analysis | Y (spam_filter) | N | Y (filter conditions) |
| Known user tracking | Y (age+posts) | N | N |
| Password blocking | Y (24hr blocks) | N | N |

## R9K / Originality

| Feature | Yotsuba | 99chan | vichan |
|---------|:-:|:-:|:-:|
| Text originality check | Y (MD5 hash) | N | N |
| Image originality check | P (commented out) | N | N |
| SNR (signal-to-noise) filter | Y | N | N |
| Mute escalation (exponential) | Y (2^n seconds) | N | N |
| Mute decay over time | Y (24hr cooldown) | N | N |

## Word Filters

| Feature | Yotsuba | 99chan | vichan |
|---------|:-:|:-:|:-:|
| Filter infrastructure | Y | Y | Y |
| Literal string filters | Y | Y | Y (via regex) |
| Regex filters | Y (is_regex flag) | Y | Y (native) |
| Per-board filters | Y | Y | Y |
| Global filters | Y | Y | Y |
| Admin UI for filters | Y | Y | Y (config-based) |
| PHP-based filter files | Y (wordfilters/*.php) | N | N |
| DB-backed filters | Y (word_filters table) | Y | Y (via config) |
| Filter actions (ban, reject) | N (replace only) | N (replace only) | Y (reject, ban, note) |
| Flood-match filters | N | N | Y |
| Classic smh→baka etc | Y (in PHP files) | N | N |

### Historical 4chan Wordfilters by Era

| Filter | Replacement | Era | In Codebase? |
|--------|------------|-----|:--:|
| wapanese | weeaboo | 2005 (the OG filter) | N |
| smh | baka | 2015+ | Y |
| tbh | desu | 2015+ | Y |
| fam | senpai | 2015+ | Y |
| fams | senpaitachi | 2015+ | Y |
| cuck | kek | 2016+ | Y |
| soy/soyjak | onions/basedjak | 2018+ | Y |
| sjw/sjws | (silent removal) | 2016+ | Y |
| reddit | reddit (was filtered various eras) | 2010s | N |
| le (standalone) | (removed) | 2012+ | N |
| cringe | based | late 2010s | N |
| incel | Reddit-spacer | 2018+ | N |
| coom/coomer | (various) | 2019+ | N |
| tranny | (various) | 2020+ | N |
| janny | (various) | 2018+ | N |
| kek | lol (brief reverse filter) | 2016 (brief) | N |
| n-word variants | (various) | various | N |
| 8chan/8kun | (filtered) | 2014+ | N |

## Board Features

| Feature | Yotsuba | 99chan | vichan |
|---------|:-:|:-:|:-:|
| Catalog view | Y (HTML + JSON) | N | Y |
| Thread watcher | Y (client-side JS) | Y (server-side DB) | Y (client-side JS) |
| Inline post expansion | Y (JS) | Y (expand.php AJAX) | Y (JS) |
| Quick reply | Y (JS extension) | N | Y (JS) |
| Image hover preview | Y (JS) | N | Y (JS) |
| Gallery mode | Y (JS) | N | Y (JS) |
| Auto-reload / live index | N | N | Y |
| Infinite scroll | N | N | Y |
| Backlinks (>>quoted by) | Y | N | Y |
| Cross-board quoting | Y (>>>/board/no) | Y (>>/board/no) | Y |
| Bump limit | Y (MAX_RES) | Y | Y |
| Image limit | Y (MAX_IMGRES) | N | Y |
| Thread auto-archive | Y (on bump limit) | Y (configurable) | N |
| Thread pruning | Y | Y | Y |
| Archive viewing | Y (external links) | Y (arch/ directory) | P (catalog only) |
| Semantic URLs | Y (slug in URL) | N | Y (configurable) |
| Embed support (YouTube etc) | N | N | Y (YouTube, Vimeo, etc) |
| RSS feeds | P (disabled) | Y | Y (theme) |

## Board Management

| Feature | Yotsuba | 99chan | vichan |
|---------|:-:|:-:|:-:|
| Dynamic board creation | N (config files) | Y (admin UI) | Y (mod panel) |
| Board deletion | N | Y | Y |
| Board config editing (UI) | N | Y (partial) | Y (config editor) |
| Board types (image/text/oekaki) | Y (per-board config) | Y (4 types) | Y (per-board) |
| Board categories | Y (ws/nws + sections) | N | Y (themes) |
| Board-specific CSS | Y (16 themes) | Y (KU_STYLES) | Y (per-board) |
| Custom CSS per board | P | N | Y |
| Board list page | Y (homepage.php) | Y | Y (theme) |

## API

| Feature | Yotsuba | 99chan | vichan |
|---------|:-:|:-:|:-:|
| JSON thread API | Y | N | Y (4chan-compatible) |
| JSON catalog API | Y | N | Y |
| JSON board list API | Y (boards.json) | N | Y |
| JSON archive API | Y | N | N |
| threads.json (lightweight) | Y | N | N |
| Thread watcher API | N (client-side) | N | N |
| 4chan API field compatibility | Y (canonical) | N | Y (mapped) |
| RSS/Atom feeds | P | Y | Y |

## Site Pages & UI

| Feature | Yotsuba | 99chan | vichan |
|---------|:-:|:-:|:-:|
| Homepage | Y (board list + stats) | Y | Y (theme-based) |
| FAQ page | Y (hardcoded) | Y | Y |
| Rules page | Y (hardcoded) | Y | Y |
| Custom static pages | Y (limited) | Y | Y (full CMS) |
| Blotter/announcements | Y | Y | Y (news system) |
| 404 error page | Y (our addition) | Y | Y |
| Ban page | Y | Y | Y |
| Search | P (stub) | Y (admin-only) | Y (public) |
| Theme/style selector | Y (16 themes) | Y (KU_STYLES) | Y (configurable) |
| Mobile layout | Y (responsive CSS) | N | Y (responsive) |
| Sitemap | N | N | Y |
| Public ban list | N | N | Y (theme) |

## Infrastructure

| Feature | Yotsuba | 99chan | vichan |
|---------|:-:|:-:|:-:|
| Config system | INI cascade (global→cat→board) | PHP constants | PHP array (instance→board) |
| Template engine | Raw PHP | Dwoo | Twig |
| Database | MySQL/MariaDB | MySQL/SQLite | MySQL/PostgreSQL/SQLite |
| Caching | Memcached | N | File-based |
| CDN integration | Y (Cloudflare purge) | N | N |
| Plugin/module system | P (plugins/ dir) | Y (modules) | N (events/hooks) |
| Event/hook system | N | N | Y |
| Migration system | Y (numbered SQL) | N | N |
| Load balancing | N | Y (thumb server) | N |
| GeoIP | Y (MaxMind GeoIP2) | N | Y (configurable) |
| DNSBL | N | N | Y |
| OCR (Tesseract) | N | N | Y |
| NNTP gateway | N | N | Y |

## What Yotsuba Is Missing That Others Have

| Feature | Available In | Difficulty | Value |
|---------|-------------|:----------:|:-----:|
| **Public search** | vichan | Medium | High |
| **Dynamic board creation UI** | 99chan, vichan | Medium | Medium |
| **DNSBL checking** | vichan | Easy | Medium |
| **Move thread between boards** | 99chan, vichan | Medium | Low |
| **Staff PM system** | vichan | Medium | Low |
| **Staff noticeboard** | vichan | Easy | Low |
| **Embed support (YouTube etc)** | vichan | Easy | Medium |
| **Post editing (admin)** | 99chan, vichan | Medium | Low |
| **Thread cycling** | vichan | Easy | Low |
| **Auto-reload / live updates** | vichan | Medium | High |
| **Multiple file upload** | vichan | Hard | Medium |
| **Public ban list** | vichan | Easy | Low |
| **Sitemap generation** | vichan | Easy | Low |
| **NNTP gateway** | vichan | Hard | Low |
| **Event/hook system** | vichan | Medium | Medium |
| **More wordfilter eras** | (historical) | Easy | High |
| **IPv6 ban support** | vichan | Medium | Medium |

## Local Instance Status (Docker)

Features that exist in Yotsuba code but need work in our local instance:

| Feature | Code Status | Local Status | Blocker |
|---------|:-:|:-:|---------|
| Captcha (hCaptcha) | Y | Broken | Needs external API key |
| Country flags (GeoIP) | Y | Broken | Missing MaxMind .mmdb |
| Salt files (secure trips) | Y | Missing | Need /www/keys/*.salt |
| Word filter DB entries | Y | Empty | Need migration to seed |
| Archive system | Y | Disabled | Need per-board enable |
| Search | P | Stub | Need implementation |
| TensorChan NSFW detection | Y | Disabled | External inference server |
| Cloudflare CDN | Y | N/A | Local instance |
| Stats dashboard | N | N | Need to build |
