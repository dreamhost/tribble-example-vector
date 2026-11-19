# vector-tribble

[Vector](https://vector.dev) as an event gateway on [tribble](https://www.dreamhost.com): it
takes events over HTTP, puts them on a Kafka topic, and writes that topic to Postgres.

```
POST /sensors/<app>  ->  Vector  ->  Kafka `events`  ->  Vector  ->  Postgres `events`
```

Both halves run in this one app. Kafka sits between them so that accepting an event does not
depend on the database, and so the topic can be read by something else later.

## Sending an event

```
curl -u "$INGEST_USERNAME:$INGEST_PASSWORD" \
     -H 'Content-Type: application/json' \
     -d '{"payload": {"event_name": "site_check_requested", "user_id": "demo", "domain": "example.com"}}' \
     https://<this app's address>/sensors/ops
```

`<app>` in the path names the producer. `payload.event_name` and `payload.user_id` are
required; `payload.timestamp` (seconds) and `payload.id` are optional and are filled in.

A `200` means Kafka has the event. An event missing a required field also gets a `200` and is
dropped, with an error in this app's log: the HTTP source answers before the event is shaped.

## Variables

| variable | |
| :-- | :-- |
| `INGEST_USERNAME`, `INGEST_PASSWORD` | HTTP basic credentials every producer must send (secret) |
| `KAFKA_BOOTSTRAP_SERVERS` | `<the Kafka app's TRIBBLE_HOST>:9092` |
| `DATABASE_URL` | a reference to the Postgres app's `DATABASE_URL` |

## The table

Vector does not create it. Its Postgres sink fills columns that have the same names as the
event's fields:

| column | type |
| :-- | :-- |
| `id`, `name`, `app`, `user_id`, `event_class` | `text` |
| `occurred_at`, `ingested_at` | `timestamptz` |
| `message` | `jsonb`, the whole event |

`id` must not be unique. Delivery from Kafka is at-least-once, the sink cannot upsert, and one
duplicate would fail its whole batch; readers de-duplicate instead.

## Notes

- **The config is checked at build time** (`vector validate` in the `Dockerfile`), so a mistake
  in `vector.yaml` fails the build and the running app is left as it was.
- **The health check is TCP** on 8080. The HTTP source has no health route.
- **Stateless.** Nothing is kept on disk, so the app needs no volume. One replica is enough;
  more would share the Kafka consumer group and work, but the topic has one partition.
