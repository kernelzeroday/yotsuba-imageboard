# 4chan Yotsuba


## Overview

Yotsuba imageboard engine (originally PHP 5.6, running on PHP 8.2) containerized for local use.

## Environments

| Env | Port | Compose File | Containers | Database |
|-----|------|--------------|------------|----------|
| **PROD** | 8082 | `docker-compose.yml` | `yotsuba-web`, `yotsuba-db` | `yotsuba_global` |
| **DEV** | 8084 | `docker-compose.dev.yml` | `yotsuba-dev-web`, `yotsuba-dev-db` | `yotsuba_dev` |

### CRITICAL RULES

1. **All development happens in DEV.** Never test migrations, patches, or experiments against prod.
2. **Back up before ANY prod change:** `docker exec yotsuba-web /usr/local/bin/backup.sh dump pre-<reason>`
3. **Promote explicitly.** Only touch prod when the user says to deploy/promote.
4. **Double-check container names.** `yotsuba-web` = PROD. `yotsuba-dev-web` = DEV. Mixing these up destroys data.
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
- `config/global_config.ini` — all global settings (limits, features, paths)
- `config/global_strings.ini` — UI strings and error messages
- `config/boards/*.config.ini` — per-board overrides
- `docker/entrypoint.sh` — container bootstrap (patches source for local use)

## Architecture

- Apache serves from `/www/4chan.org/web/boards/` where each board is a directory of symlinks back to the PHP source
- Config uses a cascading INI system: global → category → board
- The `L::d()` helper in `lib/util.php` resolves board → domain mapping
- `YOTSUBA_DIR` config key points to `/www/global/yotsuba/` (symlink to `/var/www/html`)
- The entrypoint rewrites remaining external URLs to local paths at container start

## Conventions

- PHP files have `-test.php` variants (test/staging copies of production files)
- CSS themes are named `yotsuba*`, `futaba*`, `burichan*` etc. — these are style names, not branding
- Cookie name is `4chan_pass`
- Database: `yotsuba_global` (MariaDB 10.1)
