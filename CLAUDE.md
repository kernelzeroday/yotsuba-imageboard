# 4chan Yotsuba

PHP 5.6 imageboard (Yotsuba engine) containerized for local security testing.

## Build & Run

```bash
docker compose up --build     # http://localhost:8082/b/
docker compose down -v        # full reset (wipes DB + uploads)
```

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
