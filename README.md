# OpenVoxDB PostgreSQL container

PostgreSQL on Alpine, with a separate OpenVoxDB database and a non-superuser application role.
The initialization script enables `pg_trgm` and `pgcrypto` in the OpenVoxDB application database.
The container runs as the `postgres` operating-system user.

## Build

Run from this directory:

```sh
podman build -t openvoxdb-postgres:18 -f Containerfile .
```

No database credentials or environment defaults are needed during the build.
The build only checks that the extension files exist and copies the initialization script into the image.
The script runs at container startup, not during the build.

## Configuration

Supply these environment variables when starting the container:

| Variable | Purpose | Default |
| --- | --- | --- |
| `POSTGRES_PASSWORD` | Database administrator password | Required |
| `POSTGRES_USER` | Database administrator role | `postgres` |
| `POSTGRES_DB` | Initial administrator database | Same as `POSTGRES_USER` |
| `OPENVOX_DATABASE` | Application database to create | Required |
| `OPENVOX_USER` | Application role to create | Required |
| `OPENVOX_PASSWORD` | Application role password | Required |

The application role and database names must differ from `POSTGRES_USER` and `POSTGRES_DB`, respectively.
Provide passwords at runtime through a protected environment file or Kubernetes Secrets; do not bake them into the image.

## Run with Podman

Create a local `postgresql.env` file, replace both password placeholders, and keep the file out of version control:

```dotenv
POSTGRES_PASSWORD=replace-with-admin-password
OPENVOX_DATABASE=puppetdb
OPENVOX_USER=puppetdb
OPENVOX_PASSWORD=replace-with-application-password
```

```sh
chmod 600 postgresql.env
podman volume create openvox-postgres-data
podman run -d --name openvoxdb-postgres \
  --env-file postgresql.env \
  -p 127.0.0.1:5432:5432 \
  -v openvox-postgres-data:/var/lib/postgresql:U \
  openvoxdb-postgres:18

podman logs -f openvoxdb-postgres
```

PostgreSQL stores its data in `/var/lib/postgresql/18/docker`; mount persistent storage at `/var/lib/postgresql`.
The Podman `:U` option adjusts volume ownership for the container user.
For Kubernetes, ensure the mounted volume is writable by the effective container user.
Connect locally on port `5432` using the `OPENVOX_*` database credentials.

## Test with Compose

The included `compose.yml` builds the local image and uses fixed passwords for local testing only.
It exposes PostgreSQL on `127.0.0.1:5432` and keeps data in a named volume.

```sh
podman-compose up -d --build
podman-compose logs -f openvoxdb-postgres
```

Check the installed extensions and application role:

```sh
podman-compose exec openvoxdb-postgres \
  sh -c 'PGPASSWORD="$OPENVOX_PASSWORD" psql -h 127.0.0.1 -U "$OPENVOX_USER" -d "$OPENVOX_DATABASE" -c "\dx" -c "SELECT current_user, rolsuper FROM pg_roles WHERE rolname = current_user;"'
```

The output should include `pg_trgm`, `pgcrypto`, and `rolsuper = f` for `puppetdb`.
Use `podman-compose down` to stop and remove the containers while retaining the data.
Use `podman-compose down -v` to delete the test data and run initialization again on the next start.
Docker Compose users can replace `podman-compose` with `docker compose` in these commands.

## Initialization and restarts

Initialization runs only when the data directory has not yet been initialized.
Restarting the container preserves the database and does not rerun the script.
Changing environment variables later does not update existing database names, roles, or passwords.
Apply password changes in PostgreSQL as well as in the runtime configuration.
If initialization fails, inspect the logs and database state before retrying; scripts may have run only partially.

Use `podman stop openvoxdb-postgres` and `podman start openvoxdb-postgres` to stop and restart the container.
Keep the named volume when replacing the container, and back up data before upgrades.
Moving an existing lower PostgreSQL version installation to this image requires a major-version migration, not just an image change.
