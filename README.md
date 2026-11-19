# vector-tribble

[Vector](https://vector.dev) as an event gateway on [tribble](https://www.dreamhost.com): it
takes events over HTTP, shapes them, and writes them to Postgres.

```
POST /sensors/<app>  ->  Vector  ->  Postgres `events`
```

The first commit of this repository put a Kafka topic between the two halves, so that accepting
an event did not depend on the database. That is one `git revert` away.

## Sending an event

```
curl -u "$INGEST_USERNAME:$INGEST_PASSWORD" \
     -H 'Content-Type: application/json' \
     -d '{"payload": {"event_name": "site_check_requested", "user_id": "demo", "domain": "example.com"}}' \
     https://<this app's address>/sensors/ops
```

`<app>` in the path names the producer. `payload.event_name` and `payload.user_id` are
required; `payload.timestamp` (seconds) and `payload.id` are optional and are filled in.

A `200` means the row is in Postgres; if the database is away the request fails or waits, and
the producer should send again. An event missing a required field also gets a `200` and is
dropped, with an error in this app's log: the HTTP source answers before the event is shaped.

## Variables

| variable | |
| :-- | :-- |
| `INGEST_USERNAME`, `INGEST_PASSWORD` | HTTP basic credentials every producer must send (secret) |
| `DATABASE_URL` | a reference to the Postgres app's `DATABASE_URL` |

## The table

Vector does not create it. Its Postgres sink fills columns that have the same names as the
event's fields:

| column | type |
| :-- | :-- |
| `id`, `name`, `app`, `user_id`, `event_class` | `text` |
| `occurred_at`, `ingested_at` | `timestamptz` |
| `message` | `jsonb`, the whole event |

`id` must not be unique. A producer that retries sends the same event twice, the sink cannot
upsert, and one duplicate would fail its whole batch; readers de-duplicate instead.

## Notes

- **The config is checked at build time** (`vector validate` in the `Dockerfile`), so a mistake
  in `vector.yaml` fails the build and the running app is left as it was.
- **The health check is TCP** on 8080. The HTTP source has no health route.
- **Stateless.** Nothing is kept on disk, so the app needs no volume, and it can run more than
  one replica.
