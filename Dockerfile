FROM timberio/vector:0.62.0-debian

COPY vector.yaml /etc/vector/vector.yaml

# Fails the build, not the deploy, on a config that does not parse. `--no-environment` skips
# the check that needs Postgres to be there; the variables only need to be set.
RUN INGEST_USERNAME=check INGEST_PASSWORD=check \
    DATABASE_URL=postgres://check:check@localhost:5432/check \
    vector validate --no-environment /etc/vector/vector.yaml
