# localchan

A self-contained imageboard for local security research and testing. Built from the Yotsuba PHP imageboard engine, containerized with Docker.

## Quick Start

```bash
docker compose up --build
```

Then open http://localhost:8082/b/

## Services

| Service   | URL                     | Purpose                |
|-----------|-------------------------|------------------------|
| Web       | http://localhost:8082    | Imageboard (PHP/Apache)|
| Adminer   | http://localhost:8081    | Database admin UI      |
| MariaDB   | localhost:3306           | Database               |
| Memcached | localhost:11211          | Cache                  |

## Architecture

```
docker-compose.yml          # Service definitions
Dockerfile                  # PHP 5.6 + Apache + extensions
docker/
  entrypoint.sh             # Container bootstrap (config patching, board setup)
  init.sql                  # Database schema
  init-boards.sh            # Pre-generates board HTML on startup
  config/config_db.php      # Database credentials (build-time defaults)
  static/                   # CSS, JS, images baked into the image

localchan_config.php        # Configuration engine (loads INI, connects DB)
config/
  global_config.ini         # Global settings (limits, features, paths)
  global_strings.ini        # UI strings and error messages
  boards/*.config.ini       # Per-board overrides (82 boards)
  categories/               # Board category groupings

imgboard.php                # Main board page handler
catalog.php                 # Catalog view
admin.php                   # Moderation panel
auth.php                    # Pass authentication
signin.php                  # User signin/email verification
json.php                    # JSON API

lib/                        # Core PHP libraries
  ini.php                   # INI config parser
  db.php / db_pdo.php       # Database abstraction
  util.php                  # Utilities + domain linker
  admin.php                 # Moderation functions
  postfilter.php            # Content filtering
  userpwd.php               # User password/cookie handling

views/                      # HTML templates
css/                        # Stylesheets (Yotsuba, Futaba, Photon, etc.)
js/                         # Client-side JavaScript
```

## Lab Environment

The entrypoint patches the codebase for local use:

- All external URLs (CDN, ads, analytics) rewritten to local paths
- CAPTCHA disabled
- Rate limits / flood protection relaxed
- Referrer validation bypassed
- GeoIP stubbed (no MaxMind database)
- Board indexes pre-generated on startup

## Default Credentials

| Resource | User      | Password  |
|----------|-----------|-----------|
| Database | localchan | localchan |
| DB root  | root      | rootpass  |
| Admin    | (via ADMIN_PASS in global_config.ini) | DISHSIS |

## Adding Boards

1. Add a row to the `boardlist` table
2. Create a matching `config/boards/<dir>.config.ini`
3. Create the post table (use board `b` as a template)
4. Rebuild the container or restart

## Reset

```bash
docker compose down -v   # Removes all data volumes
docker compose up --build
```
