# 4chan Yotsuba


## Overview

Yotsuba imageboard engine (originally PHP 5.6, running on PHP 8.2) containerized for local use.

## Environments

| Env | Port | Compose File | Containers | Database |
|-----|------|--------------|------------|----------|
| **PROD** | 8082 | `docker-compose.yml` | `yotsuba-prod-web`, `yotsuba-prod-pgdb`, `yotsuba-prod-clip`, `yotsuba-prod-memcached` | PostgreSQL `yotsuba` |
| **DEV** | 8084 | `docker-compose.dev.yml` | `yotsuba-dev-web`, `yotsuba-dev-pgdb`, `yotsuba-dev-clip`, `yotsuba-dev-memcached` | PostgreSQL `yotsuba_dev` |

### CRITICAL RULES

1. **All development happens in DEV.** Never test migrations, patches, or experiments against prod.
2. **Back up before ANY prod change:** `docker exec yotsuba-prod-web /usr/local/bin/backup.sh dump pre-<reason>`
3. **Promote explicitly.** Only touch prod when the user says to deploy/promote.
4. **Double-check container names.** `yotsuba-prod-*` = PROD. `yotsuba-dev-*` = DEV. Mixing these up destroys data.
5. **Autoposter OPs MUST use `--booru`.** Never create threads without images.

### Commands

```bash
# DEV (default for all work)
docker compose -f docker-compose.dev.yml up --build    # http://d.local:8084/b/
docker compose -f docker-compose.dev.yml down          # stop dev (volumes preserved)
docker compose -f docker-compose.dev.yml down -v       # full dev reset

# PROD (only when deploying)
docker compose up --build                              # http://d.local:8082/b/
docker compose down                                    # stop prod (NEVER use -v)
```

## Reference Codebases

- `../99chan` — 99chan source (Kusaba-derived), useful for comparing imageboard patterns
- `../vichan` — vichan fork (Tinyboard-derived), modern PHP imageboard reference

## Key Files

- `yotsuba_config.php` — config engine (loads INI files, connects to DB)
- `imgboard.php` — main board page handler (posting, thread display)
- `catalog.php` — catalog view
- `lib/dbal.php` — database abstraction layer (MySQL/PG translation)
- `lib/db.php` — legacy DB shim (routes through DBAL)
- `config/global_config.ini` — all global settings (limits, features, paths)
- `config/global_strings.ini` — UI strings and error messages
- `config/boards/*.config.ini` — per-board overrides
- `docker/entrypoint.sh` — container bootstrap (patches source for local use)
- `docker/clip/server.py` — ML inference server (CLIP + BLIP + toxicity + visual vocab, 670 lines)
- `docker/retag.php` — Batch ML reprocessing script (3 phases: images, text, context)
- `tagboard.php` — Tag index and semantic search UI

## Architecture

- Apache serves from `/www/4chan.org/web/boards/` where each board is a directory of symlinks back to the PHP source
- Config uses a cascading INI system: global → category → board
- The `L::d()` helper in `lib/util.php` resolves board → domain mapping
- `YOTSUBA_DIR` config key points to `/www/global/yotsuba/` (symlink to `/var/www/html`)
- The entrypoint rewrites remaining external URLs to local paths at container start

## Database

- **Engine:** PostgreSQL 16 (migrated from MariaDB 10.1)
- **Schema:** Single `posts` table with `board` column; per-board views (`a`, `b`, `g`, etc.) with INSTEAD OF triggers for transparent INSERT/UPDATE/DELETE
- **DBAL:** `lib/dbal.php` translates MySQL SQL to PG via regex pipeline in `translateSQL()` — handles backticks, INTERVAL, UNIX_TIMESTAMP, TIMESTAMPDIFF, INSERT IGNORE, GROUP_CONCAT, IF(), LIMIT in UPDATE/DELETE, etc.
- **Sequences:** `posts_no_seq` for auto-incrementing post numbers across all boards
- **Reserved words:** Column names `now`, `length`, `4pass_id` need backtick-quoting in queries (DBAL auto-quotes `4pass_id`; `now`/`length` must be manually backtick-quoted)
- **ML Pipeline:** Every post gets real-time ML analysis — see `ML.md` for full documentation. Key columns: `clip_nsfw`, `clip_anime`, `clip_desc` (image tags), `clip_text_desc` (text keywords), `clip_vector` (512-dim CLIP embedding), `clip_toxicity` + 6 granular toxicity dimensions, `clip_context_toxicity` (reply context scoring), `moderation_flag`/`moderation_reason`
- **pgvector:** HNSW index on `clip_vector` for cosine similarity search (visual + semantic)

## Conventions

- PHP files have `-test.php` variants (test/staging copies of production files)
- CSS themes are named `yotsuba*`, `futaba*`, `burichan*` etc. — these are style names, not branding
- Cookie name is `4chan_pass`
- Use `$db->qi('table')` to quote identifiers (backticks on MySQL, double-quotes on PG)
- Use `$db->lastInsertIdForTable('posts')` not `$db->lastInsertId()` for PG compatibility
