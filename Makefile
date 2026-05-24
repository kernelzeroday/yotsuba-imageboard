DOCKER_HOST ?= ssh://d.local
export DOCKER_HOST

# === DEV (default target for all work) ===

dev:
	docker compose -f docker-compose.dev.yml up --build -d

dev-down:
	docker compose -f docker-compose.dev.yml down

dev-reset:
	docker compose -f docker-compose.dev.yml down -v

dev-logs:
	docker compose -f docker-compose.dev.yml logs -f web

dev-db:
	docker exec -it yotsuba-dev-db mysql -u root -prootpass yotsuba_dev

dev-shell:
	docker exec -it yotsuba-dev-web bash

dev-migrate:
	docker exec yotsuba-dev-web /usr/local/bin/run-migrations.sh

# === PROD (explicit, requires backup first) ===

prod-backup:
	docker exec yotsuba-web /usr/local/bin/backup.sh dump manual

prod-deploy: prod-backup
	docker compose up --build -d

prod-down:
	docker compose down

prod-db:
	docker exec -it yotsuba-db mysql -u root -prootpass yotsuba_global

prod-shell:
	docker exec -it yotsuba-web bash

prod-migrate: prod-backup
	docker exec yotsuba-web /usr/local/bin/run-migrations.sh

prod-status:
	@echo "=== PROD ==="
	@docker exec yotsuba-db mysql -u root -prootpass yotsuba_global -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='yotsuba_global'" 2>/dev/null | xargs -I{} echo "Tables: {}"
	@docker exec yotsuba-web find /www/4chan.org/web/images -type f ! -name '._*' 2>/dev/null | wc -l | xargs -I{} echo "Images: {}"
	@docker exec yotsuba-web ls -lt /www/backups/*.sql.gz 2>/dev/null | head -1 | awk '{print "Latest backup: " $$6, $$7, $$8, $$9}'

# === PROMOTE (dev -> prod) ===

promote: prod-backup
	@echo "Rebuilding prod from current source..."
	docker compose up --build -d
	@echo "Running migrations on prod..."
	docker exec yotsuba-web /usr/local/bin/run-migrations.sh
	@echo "Promotion complete. Verify at http://d.local:8082/"

# === SEED DEV FROM PROD ===

dev-seed-from-prod: prod-backup
	@echo "Copying latest prod backup to dev..."
	docker exec yotsuba-web cat /www/backups/manual_latest.sql.gz | gunzip | docker exec -i yotsuba-dev-db mysql -u root -prootpass yotsuba_dev
	@echo "Dev seeded from prod snapshot."

.PHONY: dev dev-down dev-reset dev-logs dev-db dev-shell dev-migrate \
        prod-backup prod-deploy prod-down prod-db prod-shell prod-migrate prod-status \
        promote dev-seed-from-prod
