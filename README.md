# 4chan Yotsuba — Historical Restoration

A working reconstruction of the classic 4chan imageboard, built from the leaked Yotsuba engine source code and supplemented with period-accurate features from the KusabaX line of imageboards (99chan gentlebot release).

## What This Is

In late 2014, a partial dump of 4chan's server-side PHP source code — the "Yotsuba" engine — was leaked online. The code was incomplete: it contained the core board rendering and posting engine but was missing the homepage, info pages, a working admin login flow, and various infrastructure components that were either hosted on separate internal servers or stripped before the leak.

This project takes that original leaked source and turns it into a fully functional, self-contained imageboard that can be run locally. Where the leak had gaps, we used two approaches:

1. **Reconstruction from the code itself** — the leaked source contains extensive comments, config keys, database references, and dead code paths that reveal how missing features worked. Much of what looks "new" is actually just wiring up what was already described in the code but couldn't run without 4chan's internal infrastructure.

2. **Reference from KusabaX (99chan)** — for features where the leak gives us no clues, we reference the [99chan fork of KusabaX](../99chan), a contemporary open-source imageboard engine from the same era. KusabaX powered dozens of small-to-mid-size imageboards in the 2006-2014 period and shared many architectural patterns with Yotsuba. It serves as our "what it probably looked like" reference, not as code we copy wholesale.

The goal is part historical restoration, part educated speculation — a "what we thought it might have been like" behind the scenes, informed by what admins, mods, and janitors of that era described publicly, and what the code itself reveals.

## Quick Start

```bash
docker compose up --build     # First run takes ~2min (builds PHP 5.6 image)
```

Open `http://localhost:8082/` for the homepage, or `http://localhost:8082/b/` for /b/.

```bash
docker compose down -v        # Full reset (wipes DB + uploads)
```

## Services

| Service   | URL                     | Purpose                |
|-----------|-------------------------|------------------------|
| Web       | http://localhost:8082    | Imageboard (PHP 5.6/Apache) |
| Adminer   | http://localhost:8081    | Database admin UI      |
| MariaDB   | localhost:3306           | Database (MariaDB 10.1)|
| Memcached | localhost:11211          | Session/config cache   |

## Source Provenance

Every component in this project falls into one of three categories:

### Original (from the leak)

These files are from the leaked Yotsuba source, modified only to fix runtime errors and rewrite hardcoded 4chan.org URLs to local paths:

| Component | Files | Notes |
|-----------|-------|-------|
| Board engine | `imgboard.php` (7,500+ lines) | The heart of the system. Thread creation, posting, image processing, page rendering, flood control, ban checking. |
| Catalog | `catalog.php` | Catalog view with JSON generation. |
| Admin panel | `admin.php` (4,400+ lines) | Full moderation interface: bans, deletions, thread options, cleanup, IP lookups. |
| Auth system | `lib/auth.php` | Role hierarchy (janitor/mod/manager/admin), permission flags, board access control. Cookie-based session using SHA-256 HMAC with a salt file. |
| Config engine | `yotsuba_config.php`, `lib/ini.php` | Cascading INI config: global → category → board. |
| Database layer | `lib/db.php`, `lib/db_pdo.php` | MySQL abstraction with query logging, error handling. Uses the deprecated `mysql_*` API. |
| Post filtering | `lib/postfilter.php` | Regex/pattern matching with auto-sage, quiet delete, auto-ban. |
| User identity | `lib/userpwd.php` | Cookie-based user tracking, "known user" status for rate limiting. |
| Domain router | `lib/util.php` | The `L::d()` helper that maps boards to domains (4chan.org vs 4channel.org). |
| RPC layer | `lib/rpc.php` | Internal HTTP calls between services (used for cross-board deletions). |
| GeoIP | `lib/geoip2.php` | MaxMind GeoIP2 integration for country flags. Stubbed locally. |
| Ban form | `forms/ban.php` (11,000+ lines) | The ban UI with templates, durations, public/private reasons. |
| Report form | `forms/report.php` | User-facing report submission. |
| Report handler | `modes/report.php` | Server-side report processing. |
| JSON API | `json.php` | Board/thread JSON endpoints. |
| Pass auth | `auth.php` | 4chan Pass (paid account) authentication flow. |
| Board configs | `config/boards/*.config.ini` (82 files) | Per-board settings for every board that existed at time of leak. |
| Category configs | `config/categories/*.config.ini` | Worksafe/NSFW category overrides. |
| Global config | `config/global_config.ini` | ~300 settings covering every aspect of the system. |
| Global strings | `config/global_strings.ini` | All user-facing error messages and UI text. |
| CSS themes | `css/yotsubanew.css`, `futabanew.css`, `burichannew.css`, `photon.css`, `tomorrow.css` | The five classic 4chan themes. |
| JavaScript | `js/core.min.*.js`, `js/extension.min.*.js` | Minified client-side code (inline expand, quick reply, settings, etc). |
| Views/templates | `views/imgboard.php`, `views/signin.tpl.php` | HTML rendering templates. |
| Misc | `rid.php`, `derefer.php`, `clippy.html`, `rebuildd.php`, `signin.php` | Random image display, URL dereferrer, Clippy easter egg, rebuild daemon, signin flow. |

### Reproduced / Refactored / Rewritten

These components existed in the original 4chan but were either missing from the leak, broken without infrastructure, or needed significant rework to function locally:

| Component | What happened | How we know it existed |
|-----------|---------------|----------------------|
| **Homepage** (`homepage.php`) | Written from scratch. The leak only contained the board engine (`imgboard.php`), not the www site. | Every 4chan page links to `/` and the board nav references it. We built a homepage that queries the `boardlist` table and displays boards by category with a random banner, matching the well-known 4chan.org front page layout. |
| **Info pages** (`/blotter`, `/rules`, `/faq`, `/legal`, `/contact`, `/feedback`, `/advertise`) | Scraped from the live 4chan.org site and served as static HTML with URLs rewritten for local serving. | These pages are linked from every board header/footer. The blotter data is also referenced in `global_config.ini` (`BLOTTER_URL`). |
| **Admin login form** | The leak had `auth_user()` which reads `4chan_auser` and `apass` cookies, but no login page — original 4chan mods logged in through a separate internal system (probably on `sys.4chan.org` or an internal-only domain). We added a login form to `admin.php`. | `adminvalid()` calls `auth_user()` which expects cookies to already be set. The old (commented-out) `auth_user()` at line 310 shows a login path that accepts POST `userlogin`/`passlogin`. |
| **Admin landing page** | The default case in admin.php's switch called the commented-out `admin_delete()`. We added a dashboard showing threads, board switcher, and tool links. | The switch cases for `ban`, `opt`, `cleanup`, `delall` all work — only the default landing was empty. |
| **Salt file** (`/www/keys/2014_admin.salt`) | Generated at container startup. | `auth_user()` reads this file and `die()`s with "Internal Server Error (s0)" without it. Referenced in 6+ places across `lib/auth.php`, `auth.php`, and `admin.php`. |
| **Database schema** (`docker/init.sql`) | Reconstructed from PHP code. The leak had no SQL dumps. We traced every `mysql_*_call()` in the source to build the schema: 84 board tables, `boardlist`, `mod_users`, `banned_users`, `ban_templates`, `ban_requests`, `del_log`, `reports`, `user_actions`, `postfilter`, `blacklist`, `event_log`, `iprangebans`, `blotter`, etc. | Every table is referenced by name in the PHP source with its column names visible in SQL query strings. |
| **Board directory structure** | The entrypoint creates symlink farms in `/www/4chan.org/web/boards/` where each board is a directory of symlinks back to the PHP source. | `BOARD_DIR`, `SELF_PATH`, `INDEX_DIR` constants and the Apache vhost all assume this structure. The config system also assumes board configs live at specific paths. |
| **URL rewriting** (`entrypoint.sh`) | All references to `boards.4chan.org`, `sys.4chan.org`, `i.4cdn.org`, `s.4cdn.org`, etc. are rewritten to local relative paths at container startup. | Hundreds of hardcoded URLs throughout the source reference 4chan's production CDN and domain structure. |
| **TENSORCHAN bypass** | Disabled in config. The ML inference server (`danbo.int:8501`) is internal to 4chan's network. | `tensorchan_check_nsfw()` in `imgboard.php` sends images to the inference server. Config keys `TENSORCHAN_MODE`, `TENSORCHAN_DIM`, `TENSORCHAN_THRES` define the system. |
| **Static assets** | 242 banner images, CSS for info pages, YUI sprites, favicon — all scraped from `s.4cdn.org`. | `rid.php` serves random banners from `/static/image/title/`. CSS files are referenced in page headers. |
| **Docker infrastructure** | `Dockerfile`, `docker-compose.yml`, `entrypoint.sh` — none of this existed in the leak. 4chan ran on bare metal with a complex multi-server architecture. | We containerized it as PHP 5.6 + Apache + MariaDB 10.1 + Memcached to match the technology stack of the era. |

### New Additions (from KusabaX / Original)

Features that we know existed in some form on 4chan but have no implementation in the leak. We reference the [99chan KusabaX fork](../99chan) for period-accurate implementations:

| Feature | Status | KusabaX Reference | Notes |
|---------|--------|-------------------|-------|
| **Board-specific banners** | Planned | `banners/` directory in 99chan, per-board banner serving | 4chan served different banners per board. The leak's `rid.php` only serves from a global pool. |
| **Ban appeals** | Planned | `bans.class.php` — full appeal system with appeal dates, reasons, admin review | The leak has `ban_requests` table but no user-facing appeal form. |
| **Word filters** | Planned | `manage.class.php::wordfilter()` — regex filters with board scope | The leak has `postfilter` table and `lib/postfilter.php` but the management UI is minimal. |
| **Report queue UI** | Planned | `manage.class.php::reports()` — report viewer with clear/resolve | The leak's `adminreportqueue()` and `adminreportclear()` are commented out in the admin switch. |
| **Moderation log viewer** | Planned | `manage.class.php::modlog()` — browsable action history | The leak writes to `event_log` but has no UI to read it. |
| **Statistics/graphs** | Planned | `manage.class.php::statistics()` — posting rates, unique IPs, activity graphs | No equivalent in the leak. |
| **Board creation UI** | Planned | `token.class.php::addBoard()` — create boards from admin panel | The leak requires manual SQL + config file creation. |
| **File hash banning** | Planned | `token.class.php` — ban by MD5 to prevent reposting | The leak has a `blacklist` table but limited UI. |
| **Thread archival** | Planned | `board-post.class.php` — archive instead of delete | The leak references archival in several places but the mechanism is incomplete. |
| **Oekaki (drawing)** | Not planned | `lib/oekaki/` — integrated paint applet | 4chan never had this. KusabaX-specific feature. |

## Historical Context

### The Leak (2014)

The source code appeared online in late 2014 during a period of significant upheaval at 4chan. What leaked was the server-side PHP that powered `boards.4chan.org` and `sys.4chan.org` — the board rendering and posting engine. It did NOT include:

- The `www.4chan.org` homepage/info site (separate codebase)
- The internal moderation tools beyond what's in `admin.php`
- Infrastructure scripts (deployment, monitoring, CDN config)
- The `4chan Pass` payment/account system backend
- Database dumps or user data
- The ad serving system ("danbo")
- The ML content detection system ("TENSORCHAN") server

The code itself is a monolithic PHP 5.x application that evolved continuously from 2003 to 2014. It carries archaeological layers of different coding styles, commented-out experiments, and references to systems that no longer existed by the time of the leak.

### What the Code Reveals

**TENSORCHAN** — 4chan had an internal ML system for detecting NSFW content on worksafe boards. Images were resized to 300x300 PNG and sent to `danbo.int:8501/predict`, which returned a `{"nsfw": 0.XX}` score. Despite config keys for thresholds and enforcement (`TENSORCHAN_THRES = 0.92`, `TENSORCHAN_LOG_ONLY`), the PHP code only ever *logged* scores above 0.5 — the blocking/banning logic was never implemented (or lived elsewhere). The system only checked "unknown" users (< 4 hours of verified activity), skipping trusted users and 4chan Pass holders.

**The role system** — janitor (level 1) < mod (level 10) < manager (level 20) < admin (level 50). Janitors could clear reports and request bans. Mods could ban, delete, and manage threads. Managers had additional powers like `permaage` and developer flags. Admins had unrestricted access. Each role had per-board allow/deny lists and special permission flags (`ban`, `banmsg`, `developer`, `html`).

**Ban templates** — pre-built ban reasons with automatic post-ban actions. A template could simultaneously ban a user, delete their post/all posts, quarantine content, or revoke their 4chan Pass. Templates had special actions like `revokepass_spam` and `revokepass_illegal`, suggesting a direct integration between moderation and the payment system.

**The cookie system** — evolved over time. The old auth (commented out) used `4chan_apass` with raw password comparison. The new auth used `apass` with `sha256(username + db_password + salt)`. The `4chan_pass` cookie tracked user identity for posting. `userpwd` cookies tracked posting history for rate limiting and "known user" trust scoring.

**Multiple domain architecture** — the `L::d()` helper mapped boards to either `4chan.org` (NSFW) or `4channel.org` (worksafe). This split happened in 2018 for advertiser compliance. The code contains both pre-split and post-split logic.

**Cloudflare integration** — `lib/admin.php` contains Cloudflare API calls for cache purging with what appear to be production API tokens and zone IDs. The code purged CDN cache on post deletion across both `4chan.org` and `4cdn.org` zones.

**The "DISHSIS" password** — the admin password in the config was literally `DISHSIS`. Whether this was a placeholder, inside joke, or actual credential is unknown.

### KusabaX and the Imageboard Ecosystem

KusabaX was the dominant open-source imageboard software from roughly 2006-2012. Written by "Harrison" (later forked as "Edaha"), it powered sites like 7chan, 99chan, 420chan, and hundreds of smaller boards. Its architecture — PHP + MySQL, symlink-based board directories, INI config, template-driven rendering — closely mirrored what we now know 4chan used internally.

The 99chan fork (the "gentlebot release") is particularly useful as a reference because:

1. It's from the same era (PHP 5.x, MySQL, same imageboard conventions)
2. It implements features that 4chan clearly had but the leak doesn't include (ban appeals, word filter UI, moderation logs, statistics)
3. Its moderation panel provides a template for what 4chan's internal tools likely looked like
4. It has a working board creation system, which the leak lacks

We do NOT copy KusabaX code into this project. We reference its architecture and feature set to understand what's plausible and period-accurate when filling gaps in the leak.

## Architecture

```
docker-compose.yml            # Service definitions
Dockerfile                    # PHP 5.6 + Apache + extensions
docker/
  entrypoint.sh               # Container bootstrap (patches source for local use)
  init.sql                    # Database schema (reconstructed from PHP source)
  init-boards.sh              # Pre-generates board HTML on startup
  Dockerfile.db               # MariaDB 10.1 with init script
  static/                     # CSS, JS, images, info pages
    css/                      # Board themes + info page styles
    js/                       # Minified client-side JS
    image/                    # Banners (242), sprites, icons
    pages/                    # Scraped info pages (blotter, rules, faq, etc.)

# === Original Leaked Source ===
imgboard.php                  # Main board engine (7,500+ lines)
catalog.php                   # Catalog view
admin.php                     # Moderation panel (4,400+ lines)
auth.php                      # 4chan Pass authentication
json.php                      # JSON API
yotsuba_config.php            # Config loader
config/
  global_config.ini           # ~300 global settings
  global_strings.ini          # UI strings / error messages
  boards/*.config.ini         # Per-board overrides (82 boards)
  categories/                 # Category-level overrides
lib/
  auth.php                    # Role/permission system
  admin.php                   # Moderation functions
  db.php                      # Database abstraction (mysql_* API)
  ini.php                     # INI config parser
  util.php                    # Domain mapping, utilities
  postfilter.php              # Content filtering engine
  userpwd.php                 # User cookie/identity tracking
  rpc.php                     # Inter-service HTTP calls
  geoip2.php                  # GeoIP integration (stubbed)
  json.php                    # JSON encoding helpers
forms/
  ban.php                     # Ban UI (11,000+ lines)
  report.php                  # Report submission form
modes/
  report.php                  # Report processing
views/
  imgboard.php                # Board HTML template
css/                          # Theme stylesheets
js/                           # Client-side JavaScript

# === Reproduced / New ===
homepage.php                  # Front page (new, queries boardlist)
infopage.php                  # Info page router (new, unused — static HTML used instead)
```

## Configuration

The config system uses cascading INI files: `global_config.ini` → `categories/{category}.config.ini` → `boards/{board}.config.ini`. Later files override earlier ones. Key settings:

| Key | Default | Purpose |
|-----|---------|---------|
| `CAPTCHA` | no (lab) | Enable/disable CAPTCHA |
| `TENSORCHAN_MODE` | 0 | ML content detection (0=off, 1=OPs, 2=all) |
| `MAX_USER_THREADS` | 999 (lab) | Max threads per user per period |
| `RENZOKU` | 5 (lab) | Seconds between posts |
| `CSS_VERSION` | 715 | Cache-busting version for stylesheets |
| `JS_VERSION_CORE` | 1123 | Cache-busting version for core JS |
| `STATIC_SERVER` | /static/ (lab) | CDN path for static assets |

## Default Credentials

| Resource | User     | Password |
|----------|----------|----------|
| Admin panel | admin | admin |
| Database | yotsuba  | yotsuba  |
| DB root  | root     | rootpass |

Admin panel: `http://localhost:8082/admin` (or `/{board}/admin`)

## What's Working

- All 82+ boards with posting, threads, replies, images
- Catalog view
- Five CSS themes (Yotsuba, Yotsuba B, Futaba, Burichan, Photon, Tomorrow)
- Random banner rotation (242 authentic banners)
- Homepage with board directory
- Info pages (blotter, rules, FAQ, legal, contact, feedback, advertise)
- Admin panel with board cleanup, thread options (sticky/lock/permasage), banning
- Admin login form with cookie-based sessions
- JSON API
- Image thumbnailing (JPEG, PNG, GIF, WebP)

## What's Missing / Planned

- [ ] Per-board banner images (currently global pool only)
- [ ] Report queue UI (code exists but is commented out)
- [ ] Ban appeal form (table exists, no frontend)
- [ ] Moderation log viewer (writes to `event_log`, no reader)
- [ ] Word filter management UI
- [ ] Board creation from admin panel
- [ ] File hash banning UI
- [ ] Thread archival system
- [ ] Statistics/activity graphs
- [ ] RSS feeds
- [ ] User-side ban page ("you have been banned" with appeal link)
- [ ] Mod/janitor JS extensions
- [ ] PHP 7.4/8.x migration (planned for `modern` branch)

## Reset

```bash
docker compose down -v   # Removes all data volumes
docker compose up --build
```
