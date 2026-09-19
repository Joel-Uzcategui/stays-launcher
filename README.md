# Uzcategui Stays — Launcher

Orquestador del sistema de reservas. Este repositorio no tiene código de
aplicación: contiene la infraestructura de desarrollo y los submódulos que
apuntan a cada microservicio.

## Arquitectura

| Servicio | Repositorio | Responsabilidad |
|---|---|---|
| API Gateway | `stays-api-gateway` | Única entrada HTTP. Traduce peticiones a RPC |
| Auth | `stays-auth-ms` | Usuarios, credenciales, JWT, refresh tokens |
| Catálogo | `stays-catalog-ms` | Hoteles, tipos de habitación, amenidades |
| Reservas | `stays-booking-ms` | Inventario, holds y reservas |
| Pagos | `stays-payments-ms` | Stripe, webhooks, reembolsos |
| Search | `stays-search-ms` | Índice de búsqueda |
| Notificaciones | `stays-notifications-ms` | Emails |

La comunicación pasa por RabbitMQ, usado de dos formas: **RPC** (`client.send()`)
para el camino crítico, donde hay un usuario esperando respuesta, y **eventos**
(`client.emit()`) para todo lo que puede ocurrir después.

## Desarrollo

1. Clonar el repositorio

2. Reconstruir los submódulos:
   ```bash
   git submodule update --init --recursive
   ```

3. Crear un `.env` a partir de `.env.template`:
   ```bash
   cp .env.template .env
   ```

4. Levantar la infraestructura:
   ```bash
   docker compose up -d
   ```
   Esto arranca PostgreSQL (puerto 5433) y RabbitMQ (5672, panel en 15672).
   La primera vez crea una base de datos por servicio.

5. Arrancar los servicios. Todavía corren en local, no en contenedor:
   ```bash
   cd auth-ms     && npm install && npm run start:dev
   cd api-gateway && npm install && npm run start:dev
   ```

Comprobar que todo está arriba:
```bash
docker compose ps
curl http://localhost:3002/api/health
```

## Bases de datos

Una por servicio, todas dentro del mismo contenedor de PostgreSQL. La separación
es real: PostgreSQL no permite consultas entre bases de datos distintas, así que
ningún servicio puede leer las tablas de otro aunque lo intentara.

Se crean **solo la primera vez** que arranca el contenedor, desde
`infra/postgres/init-databases.sh`. Si añades un servicio nuevo después, crea su
base a mano:

```bash
docker exec -it stays-postgres psql -U stays -c "CREATE DATABASE nueva;"
```

O borra el volumen y vuelve a empezar, perdiendo los datos:

```bash
docker compose down -v && docker compose up -d
```

## Submódulos de Git

Cada microservicio es un repositorio independiente enganchado aquí como
submódulo. El launcher no guarda su código: guarda **a qué commit apunta** cada
uno.

Añadir uno nuevo:

```bash
git submodule add git@github.com:Joel-Uzcategui/stays-catalog-ms.git catalog-ms
git add .
git commit -m "chore: añadir catalog-ms como submódulo"
git push
```

El segundo argumento es la ruta local, por eso la carpeta queda como `catalog-ms`
aunque el repositorio se llame `stays-catalog-ms`.

Actualizar las referencias a la última versión de cada servicio:

```bash
git submodule update --remote
```

### Importante: el orden de los push

Si tocas código dentro de un submódulo, **primero haz commit y push en el
submódulo y después en el launcher.**

Al revés, el launcher acaba apuntando a un commit que no existe en el remoto y
quien clone el proyecto se encontrará con submódulos que no puede inicializar.

## Variables de entorno

Todas en `.env.template`. Las que importan:

| Variable | Para qué |
|---|---|
| `POSTGRES_PORT` | 5433 por defecto, para no chocar con un PostgreSQL local |
| `SERVICE_DATABASES` | Bases que se crean al inicializar el contenedor |
| `JWT_SECRET` | Compartido: auth-ms firma, api-gateway verifica |

El `.env` está en el `.gitignore` y no debe subirse nunca. El historial de un
repositorio es permanente: un secreto commiteado sigue ahí aunque se borre en un
commit posterior.
