# 4chan Yotsuba — Historical Restoration

A working reconstruction of the classic 4chan imageboard, built from the leaked Yotsuba engine source code and supplemented with period-accurate features from the KusabaX line of imageboards (99chan gentlebot release).

## What This Is

In late 2014, a partial dump of 4chan's server-side PHP source code — the "Yotsuba" engine — was leaked online. The code was incomplete: it contained the core board rendering and posting engine but was missing the homepage, info pages, a working admin login flow, and various infrastructure components that were either hosted on separate internal servers or stripped before the leak.

This project takes that original leaked source and turns it into a fully functional, self-contained imageboard that can be run locally. Where the leak had gaps, we used two approaches:

1. **Reconstruction from the code itself** — the leaked source contains extensive comments, config keys, database references, and dead code paths that reveal how missing features worked. Much of what looks "new" is actually just wiring up what was already described in the code but couldn't run without 4chan's internal infrastructure.

2. **Reference from KusabaX (99chan)** — for features where the leak gives us no clues, we reference the [99chan fork of KusabaX](../99chan), a contemporary open-source imageboard engine from the same era. KusabaX powered dozens of small-to-mid-size imageboards in the 2006-2012 period and shared many architectural patterns with Yotsuba. It serves as our "what it probably looked like" reference, not as code we copy wholesale.

The goal is part historical restoration, part educated speculation — a "what we thought it might have been like" behind the scenes, informed by what admins, mods, and janitors of that era described publicly, and what the code itself reveals.

## Quick Start

```bash
# Production
docker compose up --build           # http://d.local:8082/b/

# Development (recommended for all work)
docker compose -f docker-compose.dev.yml up --build   # http://d.local:8084/b/
```

```bash
docker compose down -v              # Full reset (wipes DB + uploads)
```

## Environments

| Env | Port | Compose File | Containers | Purpose |
|-----|------|--------------|------------|---------|
| **PROD** | 8082 | `docker-compose.yml` | yotsuba-web, yotsuba-db | Stable build, MySQL |
| **DEV** | 8084 | `docker-compose.dev.yml` | yotsuba-dev-web, yotsuba-dev-db, pgdb, clip, etc. | Active development |

All development happens in DEV. Never test against prod.

## Services (Dev Stack)

| Service | Container | Port | Purpose |
|---------|-----------|------|---------|
| Web | yotsuba-dev-web | 8084 | PHP 8.2 / Apache |
| MariaDB | yotsuba-dev-db | 3307 | MySQL database |
| PostgreSQL | yotsuba-dev-pgdb | 5433 | PostgreSQL 16 (migration target) |
| CLIP | yotsuba-dev-clip | 8501 | CLIP inference server (NSFW + tagging) |
| Memcached | yotsuba-dev-memcached | 11212 | Session/config cache |
| Adminer | yotsuba-dev-adminer | 8085 | Database admin UI |

---

## Changelog / Surgery Log

Chronological record of major changes made to the leaked codebase.

### Phase 1: Containerization and Basic Restoration

**PHP 5.6 → PHP 8.2 migration**
- Upgraded from PHP 5.6 to 8.2 with Apache
- Fixed hundreds of deprecation warnings, `mysql_*` API calls, short array syntax
- Added `short_open_tag = On` for legacy `<?` files

**Docker infrastructure**
- `Dockerfile` — PHP 8.2-apache with GD, Imagick, memcached, intl, zip, mbstring, pdo_mysql, pdo_pgsql
- `docker-compose.yml` — prod stack (web + MariaDB 10.1 + memcached + adminer)
- `docker-compose.dev.yml` — dev stack with additional services (PostgreSQL, CLIP)
- `docker/entrypoint.sh` — container bootstrap that patches source for local use, rewrites all external URLs, generates config, creates board symlink farms
- `docker/init.sql` — full database schema reconstructed from PHP source (84 board tables, 20+ system tables)
- `docker/init-boards.sh` — pre-generates board HTML pages on startup

**Database schema reconstruction**
- Traced every `mysql_*_call()` in the source to reconstruct table schemas
- 84 board tables (one per board, created via `CREATE TABLE board LIKE a`)
- System tables: `mod_users`, `banned_users`, `ban_templates`, `ban_requests`, `del_log`, `reports`, `user_actions`, `postfilter`, `blacklist`, `event_log`, `iprangebans`, `blotter`, `boardlist`, etc.
- All 83 boards seeded with sticky welcome threads, capcode icons, blotter entries

**Homepage and info pages**
- `homepage.php` — front page querying `boardlist` table, matching original 4chan.org layout
- Static info pages scraped from 4chan.org: blotter, rules, FAQ, legal, contact, feedback, advertise
- Apache vhost with rewrite rules for clean URLs

**Admin panel restoration**
- Login form added (original relied on separate internal auth system)
- Salt file generation at container startup
- Dashboard landing page with board switcher and tool links
- Thread management: sticky, lock, permasage, cleanup, banning

**Static assets**
- 242 authentic banner images for random rotation
- All 6 classic CSS themes plus 18 additional community themes
- Minified client-side JavaScript (core + extensions)
- Capcode icons (admin, mod, manager, developer, founder)
- Party hat overlays, sticky/archived/closed icons

### Phase 2: DBAL Abstraction Layer

**Custom database abstraction** (`lib/dbal.php`, ~500 lines)
- `YotsubaDB` class wrapping PDO with MySQL/PostgreSQL dual-driver support
- Automatic SQL dialect translation (backticks → double quotes, MySQL functions → PG equivalents)
- Prepared statement support with type-detected parameter binding
- Query builder: `select()`, `insert()`, `update()`, `delete()`, `upsert()`
- Identifier quoting via `qi()` — handles PG reserved word board names (`int`, `out`, `test`)
- Table locking abstraction (MySQL `LOCK TABLES` → PG `BEGIN + LOCK TABLE`)
- `translateSQL()` pipeline: `HIGH_PRIORITY`, `DATE_SUB`, `UNIX_TIMESTAMP`, `IF()`, `GROUP_CONCAT`, `ON DUPLICATE KEY UPDATE`, `LIMIT offset,count` → PG equivalents

**Backward-compatible shim** (`lib/db.php`)
- Existing `mysql_global_call()` / `mysql_board_call()` routed through DBAL
- vsprintf queries translated via `translateSQL()` before execution
- All compatibility shims (`mysql_fetch_assoc`, `mysql_num_rows`, etc.) work with PDOStatement regardless of driver

**PostgreSQL schema** (`docker/init_pg.sql`)
- Full translation of MySQL schema to PostgreSQL
- `AUTO_INCREMENT` → `SERIAL`, `tinyint` → `SMALLINT`, `ENGINE=InnoDB` stripped
- Secondary indexes as `CREATE INDEX` statements
- `ON UPDATE CURRENT_TIMESTAMP` → trigger functions
- Reserved word board names always double-quoted

**Migration infrastructure**
- `docker/migrations/` — numbered SQL migration files
- `docker/run-migrations.sh` — applies pending migrations, tracks in `schema_migrations` table
- `YOTSUBA_DB_DRIVER` env var switches between `mysql` and `pgsql`

**PHPUnit test suite**
- `composer.json` with PHPUnit 10.5
- `tests/DBALTest.php` — 45 tests covering connection, query building, SQL translation, identifier quoting, upsert
- `tests/UtilTest.php` — 52 tests covering domain mapping, board config, string utilities
- `composer test` runs with `short_open_tag=On` for legacy file compatibility

### Phase 3: CLIP / TENSORCHAN Rewrite

The original leaked code contained `tensorchan_check_nsfw()` which sent images to 4chan's internal ML server (`danbo.int:8501`) for NSFW detection. We replaced this dead endpoint with a local CLIP-based inference server.

**CLIP server** (`docker/clip/`)
- `server.py` — FastAPI server running OpenAI ViT-B-32 via `open_clip`
- `Dockerfile` — `python:3.10-slim` base, CPU-only PyTorch (~1.1GB image)
- Zero-shot NSFW scoring: 7 unsafe + 10 safe text prompts, `score = unsafe_max / (unsafe_max + safe_max)`
- Image tagging: 40 curated prompts (anime, photograph, meme, screenshot, etc.), top-5 returned above threshold
- `/predict` endpoint accepts raw binary PNG — backward-compatible with original tensorchan API
- `/analyze` endpoint accepts multipart uploads
- `/health` endpoint for Docker healthcheck
- Model weights cached in `clip_cache` Docker volume (~350MB, downloaded on first start)

**PHP integration** (`imgboard.php`)
- `tensorchan_predict()` — now targets configurable `TENSORCHAN_HOST`/`TENSORCHAN_PORT` instead of hardcoded `danbo.int`
- `tensorchan_check_nsfw()` — returns full result array `{nsfw, tags, description}` instead of bare float
- `tensorchan_log()` — stores NSFW score, description, and tags JSON in `tensor_log` table
- `tensorchan_is_needed()` — simplified: removed user trust bypass (`isUserKnownOrVerified`), runs on ALL image posts when enabled
- Image `<img>` alt text uses CLIP description when available (e.g., `alt="anime or manga art, a digital illustration, cute or wholesome content"`)

**Database additions**
- `clip_nsfw` (float) and `clip_desc` (varchar 500) columns on all board tables, after `m_img`
- `tensor_log` table: stores all inference results with board, post ID, file ID, NSFW score, description, tags JSON
- `docker/migrations/015_tensorchan_clip.sql` — migration to add columns to existing tables

**JSON API** (`json.php`)
- `clip_desc` field exported in post JSON objects

**Configuration**
- `TENSORCHAN_HOST` / `TENSORCHAN_PORT` config keys
- `YOTSUBA_CLIP_HOST` env var in `docker-compose.dev.yml` — when set, entrypoint enables TENSORCHAN_MODE=2
- `TENSORCHAN_LOG_ONLY = no` — NSFW scores are now actionable, not just logged

---

## Source Provenance

Every component in this project falls into one of three categories:

### Original (from the leak)

These files are from the leaked Yotsuba source, modified only to fix runtime errors, rewrite hardcoded 4chan.org URLs, and adapt for PHP 8.2:

| Component | Files | Notes |
|-----------|-------|-------|
| Board engine | `imgboard.php` (10,000+ lines) | Thread creation, posting, image processing, page rendering, flood control, ban checking, CLIP integration. |
| Catalog | `catalog.php` | Catalog view with JSON generation. |
| Admin panel | `admin.php` (4,400+ lines) | Full moderation interface: bans, deletions, thread options, cleanup, IP lookups. |
| Auth system | `lib/auth.php` | Role hierarchy (janitor/mod/manager/admin), permission flags, board access control. |
| Config engine | `yotsuba_config.php`, `lib/ini.php` | Cascading INI config: global → category → board. |
| Database layer | `lib/db.php`, `lib/db_pdo.php` | Original MySQL abstraction, now shimmed through DBAL. |
| Post filtering | `lib/postfilter.php` | Regex/pattern matching with auto-sage, quiet delete, auto-ban. |
| User identity | `lib/userpwd.php` | Cookie-based user tracking, "known user" status. |
| Domain router | `lib/util.php` | The `L::d()` helper that maps boards to domains. |
| JSON API | `json.php` | Board/thread JSON endpoints, now includes `clip_desc`. |
| Ban form | `forms/ban.php` (11,000+ lines) | Ban UI with templates, durations, public/private reasons. |
| Report form | `forms/report.php`, `modes/report.php` | Report submission and processing. |
| Board configs | `config/boards/*.config.ini` (82 files) | Per-board settings. |
| CSS themes | `css/yotsubanew.css`, `futabanew.css`, etc. | Classic 4chan themes. |
| JavaScript | `js/core.min.*.js`, `js/extension.min.*.js` | Client-side code. |
| Misc | `rid.php`, `derefer.php`, `clippy.html`, `rebuildd.php`, `signin.php` | Utility scripts. |

### Reproduced / Reconstructed

Components that existed in the original 4chan but were missing from the leak or broken without infrastructure:

| Component | What happened |
|-----------|---------------|
| **Homepage** (`homepage.php`) | Written from scratch — leak only contained the board engine |
| **Info pages** | Scraped from live 4chan.org, URLs rewritten for local serving |
| **Admin login** | Added login form — original used separate internal auth system |
| **Database schema** (`init.sql`, `init_pg.sql`) | Reconstructed by tracing every SQL call in the PHP source |
| **Board directory structure** | Symlink farms generated at startup by entrypoint.sh |
| **URL rewriting** | All `boards.4chan.org`, `sys.4chan.org`, `i.4cdn.org` references patched |
| **Docker infrastructure** | Containerized a bare-metal multi-server architecture |

### New / Extended

Features added beyond what the leak contained:

| Feature | Status | Notes |
|---------|--------|-------|
| **DBAL** (`lib/dbal.php`) | Complete | MySQL/PostgreSQL dual-driver abstraction |
| **PostgreSQL support** | In progress | Schema translated, migration tooling built, data migration pending |
| **CLIP inference** | Complete | Replaced dead `danbo.int` with local CLIP server for NSFW + tagging |
| **PHPUnit tests** | Complete | 97 tests across DBAL and site utilities |
| **Migration system** | Complete | Numbered SQL migrations with tracking |
| **24 CSS themes** | Complete | 6 classic + 18 community themes |

## Architecture

```
docker-compose.yml              # Production stack
docker-compose.dev.yml          # Dev stack (MySQL + PostgreSQL + CLIP + Adminer)
Dockerfile                      # PHP 8.2 + Apache + extensions
docker/
  entrypoint.sh                 # Container bootstrap
  init.sql                      # MySQL schema (84 board tables + system tables)
  init_pg.sql                   # PostgreSQL schema (translated from MySQL)
  init-boards.sh                # Board HTML pre-generation
  run-migrations.sh             # Migration runner
  migrations/                   # Numbered SQL migration files
  backup.sh, backup-dump.sh     # Backup utilities
  clip/                         # CLIP inference server
    Dockerfile                  # python:3.10-slim + PyTorch CPU + open_clip
    server.py                   # FastAPI server (ViT-B-32)
    requirements.txt            # Python dependencies
  Dockerfile.db                 # MariaDB 10.1 with init script
  static/                       # CSS, JS, images, info pages

# Leaked source (modified for local use + PHP 8.2)
imgboard.php                    # Main board engine
catalog.php                     # Catalog view
admin.php                       # Moderation panel
json.php                        # JSON API
yotsuba_config.php              # Config loader
lib/
  dbal.php                      # Database abstraction layer (new)
  db.php                        # Original MySQL layer (shimmed through DBAL)
  auth.php, admin.php           # Auth and moderation
  postfilter.php, userpwd.php   # Content filtering, user tracking
  util.php, ini.php, rpc.php    # Utilities
config/
  global_config.ini             # ~300 global settings
  global_strings.ini            # UI strings
  boards/*.config.ini           # Per-board overrides (82 boards)
  categories/                   # Category-level overrides

# Test variants
imgboard-test.php               # Staging copy of imgboard.php
admin-test.php                  # Staging copy of admin.php
json-test.php                   # Staging copy of json.php
tests/                          # PHPUnit test suite
  DBALTest.php                  # DBAL unit tests
  UtilTest.php                  # Utility function tests
```

## Configuration

The config system uses cascading INI files: `global_config.ini` → `categories/{category}.config.ini` → `boards/{board}.config.ini`. Later files override earlier ones.

| Key | Default | Purpose |
|-----|---------|---------|
| `TENSORCHAN_MODE` | 0 | CLIP inference (0=off, 1=OPs, 2=all) |
| `TENSORCHAN_HOST` | clip | CLIP server hostname |
| `TENSORCHAN_PORT` | 8501 | CLIP server port |
| `TENSORCHAN_THRES` | 0.92 | NSFW score threshold for blocking |
| `TENSORCHAN_LOG_ONLY` | no | Log only vs. enforce |
| `CAPTCHA` | no | Enable/disable CAPTCHA |
| `RENZOKU` | 5 | Seconds between posts |

## Default Credentials

| Resource | User | Password |
|----------|------|----------|
| Admin panel | admin | admin |
| MySQL | yotsuba | yotsuba |
| PostgreSQL | yotsuba | yotsuba |
| DB root | root | rootpass |

Admin panel: `http://d.local:8084/admin`

## Historical Context

### The Leak (2014)

The source code appeared online in late 2014 during a period of significant upheaval at 4chan. What leaked was the server-side PHP that powered `boards.4chan.org` and `sys.4chan.org` — the board rendering and posting engine. It did NOT include:

- The `www.4chan.org` homepage/info site (separate codebase)
- Infrastructure scripts (deployment, monitoring, CDN config)
- The `4chan Pass` payment/account system backend
- Database dumps or user data
- The ad serving system ("danbo")
- The ML content detection system ("TENSORCHAN") server

The code is a monolithic PHP 5.x application that evolved continuously from 2003 to 2014. It carries archaeological layers of different coding styles, commented-out experiments, and references to systems that no longer existed by the time of the leak.

### What the Code Reveals

**TENSORCHAN** — 4chan had an internal ML system for detecting NSFW content on worksafe boards. Images were resized to 300x300 PNG and sent to `danbo.int:8501/predict`, which returned a `{"nsfw": 0.XX}` score. The system only checked "unknown" users (< 4 hours of verified activity), skipping trusted users and 4chan Pass holders. We replaced this with a local CLIP server that provides both NSFW scoring and image descriptions.

**The role system** — janitor (level 1) < mod (level 10) < manager (level 20) < admin (level 50). Each role had per-board allow/deny lists and special permission flags.

**Ban templates** — pre-built ban reasons with automatic post-ban actions. A template could simultaneously ban a user, delete their post/all posts, quarantine content, or revoke their 4chan Pass.

**Multiple domain architecture** — the `L::d()` helper mapped boards to either `4chan.org` (NSFW) or `4channel.org` (worksafe), a split that happened in 2018.

**The "DISHSIS" password** — the admin password in the config was literally `DISHSIS`. Whether this was a placeholder, inside joke, or actual credential is unknown.

## Reset

```bash
docker compose -f docker-compose.dev.yml down -v   # Wipe dev (DB + uploads)
docker compose -f docker-compose.dev.yml up --build
```
