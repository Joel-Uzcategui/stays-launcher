# Uzcategui Stays — Launcher

Orchestrator for the booking system. This repository holds no application code:
it contains the development infrastructure and the submodules pointing at each
microservice.

## Architecture

| Service | Repository | Responsibility |
|---|---|---|
| API Gateway | `stays-api-gateway` | The only HTTP entry point. Translates requests into RPC |
| Auth | `stays-auth-ms` | Users, credentials, JWT, refresh tokens |
| Catalog | `stays-catalog-ms` | Hotels, room types, amenities |
| Booking | `stays-booking-ms` | Inventory, holds and bookings |
| Payments | `stays-payments-ms` | Stripe, webhooks, refunds |
| Search | `stays-search-ms` | Search index |
| Notifications | `stays-notifications-ms` | Emails |

All communication goes through RabbitMQ, used in two ways: **RPC**
(`client.send()`) for the critical path, where a user is waiting for a response,
and **events** (`client.emit()`) for everything that can happen afterwards.

## Getting started

1. Clone and restore the submodules:
   ```bash
   git submodule update --init --recursive
   ```

2. Generate the RS256 key pair. `auth-ms` signs with the private key; every
   other service verifies with the public one:
   ```bash
   openssl genrsa -out jwt-private.pem 2048
   openssl rsa -in jwt-private.pem -pubout -out jwt-public.pem
   base64 -w0 jwt-private.pem
   base64 -w0 jwt-public.pem
   ```

3. Create the `.env` and paste both base64 strings into `JWT_PRIVATE_KEY` and
   `JWT_PUBLIC_KEY`:
   ```bash
   cp .env.template .env
   ```

4. Start everything:
   ```bash
   docker compose up -d
   ```

5. Seed the development data:
   ```bash
   docker compose exec auth-ms npx prisma db seed
   docker compose exec catalog-ms npx prisma db seed
   ```

Check it is running:

```bash
docker compose ps
curl http://localhost:3002/api/health
```

## Daily use

```bash
docker compose up -d              # start
docker compose logs -f            # follow all logs
docker compose logs -f auth-ms    # follow one service
docker compose down               # stop, keeping data
docker compose down -v            # stop and wipe the databases
```

Each service mounts its `src` from the host, so saving a file recompiles and
restarts that container. No rebuild needed unless dependencies change:

```bash
docker compose up -d --build
```

## Ports

| | Port |
|---|---|
| API Gateway | 3002 |
| PostgreSQL | 5433 |
| RabbitMQ | 5672 |
| RabbitMQ management UI | 15672 |

PostgreSQL is mapped to 5433 to avoid clashing with a local install on 5432.

## Databases

One per service, all inside the same PostgreSQL container. The separation is
real: PostgreSQL does not allow queries across databases, so no service can read
another service's tables even if it tried.

They are created the first time the container starts, from
`infra/postgres/init-databases.sh`. Migrations run automatically on every
service start via `prisma migrate deploy`, which is idempotent.

To add a database for a new service later:

```bash
docker exec -it stays-postgres psql -U stays -c "CREATE DATABASE newdb;"
```

## Authentication

Tokens are signed with **RS256**. `auth-ms` holds the private key and is the
only service that can issue tokens; everything else gets the public key and can
only verify. With a symmetric secret, any service able to verify a token would
also be able to forge one.

The gateway verifies signatures locally, without calling `auth-ms` on every
request.

## Git submodules

Each microservice is an independent repository attached here as a submodule. The
launcher does not store their code: it stores **which commit each one points
at**.

Add a new one:

```bash
git submodule add git@github.com:Joel-Uzcategui/stays-booking-ms.git booking-ms
git add . && git commit -m "add booking-ms submodule" && git push
```

The second argument is the local path, which is why the folder is `booking-ms`
even though the repository is named `stays-booking-ms`.

Move the references to the latest commit of each service:

```bash
git submodule update --remote
```

### Important: push order

If you change code inside a submodule, **commit and push the submodule first,
then the launcher.**

The other way around, the launcher ends up pointing at a commit that does not
exist on the remote, and anyone cloning the project gets submodules they cannot
initialize.

## Environment variables

All of them live in `.env.template`.

| Variable | Purpose |
|---|---|
| `POSTGRES_PORT` | 5433 by default, to avoid clashing with a local PostgreSQL |
| `SERVICE_DATABASES` | Databases created when the container is initialized |
| `JWT_PRIVATE_KEY` | Base64 RS256 private key. Used only by `auth-ms` |
| `JWT_PUBLIC_KEY` | Base64 RS256 public key. Shared with every service |
| `SEED_ADMIN_*` | Development admin created by the seed |

`.env` is gitignored and must never be committed. Repository history is
permanent: a secret committed once stays there even if a later commit removes it.

The seeded admin exists for development only. In production the first
administrator is created with a CLI command, never from a seed whose credentials
live in a public repository.
