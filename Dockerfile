FROM timberio/vector:0.62.0-debian

COPY vector.yaml /etc/vector/vector.yaml

# vector.yaml takes its credentials and the database address from the environment (`${NAME}`).
# Vector has left that off by default since 0.57, because a variable's value is pasted into the
# config as text and so could add configuration of its own. Here every variable is set by the
# app's owner, and none comes from a request.
ENV VECTOR_DANGEROUSLY_ALLOW_ENV_VAR_INTERPOLATION=true

# Fails the build, not the deploy, on a config that does not parse. `--no-environment` skips
# the check that needs Postgres to be there; the variables only need to be set.
RUN INGEST_USERNAME=check INGEST_PASSWORD=check \
    DATABASE_URL=postgres://check:check@localhost:5432/check \
    vector validate --no-environment /etc/vector/vector.yaml
