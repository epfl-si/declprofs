.PHONY: build
build:
	docker compose build

.PHONY: up
up:
	docker compose up -d

.PHONY: down
down:
	docker compose down

.PHONY: logs
logs:
	docker compose logs -f


canned_restore = set -e; password=$$(grep )

DOCKER_MYSQL = docker compose exec -T db bash -c 'mysql -u root --password=$${MYSQL_ROOT_PASSWORD}'

.PHONY: restore
restore:
	./devsupport/mariadb restoredb dinfo --no-data \
	  --ignore-table=dinfo.CfFonds \
	  --ignore-table=dinfo.FondsCFs \
	  --ignore-table=dinfo.newgroups
	./devsupport/mariadb restoretable dinfo sciper
	./devsupport/mariadb restoretable dinfo accounts
	./devsupport/mariadb restoretable dinfo emails
	./devsupport/mariadb restoretable dinfo unites1

	./devsupport/mariadb restoredb accred --no-data \
	  --ignore-table=accred.test_view
	./devsupport/mariadb restoretable accred accreds \
	  --where='classid=5'

	./devsupport/mariadb restoredb declprofs
