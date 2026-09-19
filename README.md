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

## Development

1. Clone the repository

2. Restore the submodules:
   ```bash
   git submodule update --init --recursive
   ```

3. Create a `.env` from `.env.template`:
   ```bash
   cp .env.template .env
   ```

4. Start the infrastructure:
   ```bash
   docker compose up -d
   ```
   This brings up PostgreSQL (port 5433) and RabbitMQ (5672, management UI on
   15672). On first run it creates one database per service.

5. Start the services. They still run locally, not in containers:
   ```bash
   cd auth-ms     && npm install && npm run start:dev
   cd api-gateway && npm install && npm run start:dev
   ```

`auth-ms` also needs its Prisma client and schema before first use:

```bash
cd auth-ms
npx prisma generate
npx prisma migrate deploy
npx prisma db seed
```

The generated client is gitignored, so `prisma generate` has to run on every
machine. The seed creates the development admin.

Check everything is up:

```bash
docker compose ps
curl http://localhost:3002/api/health
```

## Databases

One per service, all inside the same PostgreSQL container. The separation is
real: PostgreSQL does not allow queries across databases, so no service can read
another service's tables even if it tried.

They are created **only the first time** the container starts, from
`infra/postgres/init-databases.sh`. If you add a new service later, create its
database by hand:

```bash
docker exec -it stays-postgres psql -U stays -c "CREATE DATABASE newdb;"
```

Or drop the volume and start over, losing the data:

```bash
docker compose down -v && docker compose up -d
```

## Git submodules

Each microservice is an independent repository attached here as a submodule. The
launcher does not store their code: it stores **which commit each one points
at**.

Add a new one:

```bash
git submodule add git@github.com:Joel-Uzcategui/stays-catalog-ms.git catalog-ms
git add .
git commit -m "add catalog-ms submodule"
git push
```

The second argument is the local path, which is why the folder is `catalog-ms`
even though the repository is named `stays-catalog-ms`.

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

All of them live in `.env.template`. The ones that matter:

| Variable | Purpose |
|---|---|
| `POSTGRES_PORT` | 5433 by default, to avoid clashing with a local PostgreSQL |
| `SERVICE_DATABASES` | Databases created when the container is initialized |
| `JWT_PUBLIC_KEY` | Base64 RS256 public key. Verifies signatures, cannot issue tokens |

Tokens are signed with **RS256**: `auth-ms` holds the private key and is the only
service that can issue tokens. Every other service gets the public key and can
only verify. With a symmetric secret, any service able to verify a token would
also be able to forge one.

`.env` is gitignored and must never be committed. Repository history is
permanent: a secret committed once stays there even if a later commit removes it.
