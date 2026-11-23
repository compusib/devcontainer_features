# The server of gate L (../gates.sh): a PostgreSQL 18 that asks for a bearer token and takes whatever it gets
# (validator.c). For the gate alone.
FROM postgres:18-bookworm
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc libc6-dev libkrb5-dev postgresql-server-dev-18 \
    && rm -rf /var/lib/apt/lists/*
COPY validator.c /tmp/validator.c
RUN gcc -shared -fPIC -I"$(pg_config --includedir-server)" -o "$(pg_config --pkglibdir)/pgtoken_gate_validator.so" /tmp/validator.c
COPY oauth.sh /docker-entrypoint-initdb.d/oauth.sh
