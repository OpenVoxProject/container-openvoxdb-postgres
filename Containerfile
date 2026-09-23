FROM postgres:18-alpine

RUN test -f "$(pg_config --sharedir)/extension/pg_trgm.control" \
    && test -f "$(pg_config --sharedir)/extension/pgcrypto.control"

COPY --chmod=0755 init-openvox.sh /docker-entrypoint-initdb.d/10-openvox.sh

USER postgres
