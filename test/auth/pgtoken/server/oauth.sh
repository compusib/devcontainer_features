# Run once by the image's entrypoint, when the data directory is made. OAUTH_ISSUER is the issuer the server names
# to a client. The role `dev` is asked for a bearer token; `pw` logs in with its password, by the image's own rule.
echo "oauth_validator_libraries = 'pgtoken_gate_validator'" >> "$PGDATA/postgresql.conf"
sed -i "1i host all dev all oauth issuer=\"$OAUTH_ISSUER\" scope=\"pg\" delegate_ident_mapping=1" "$PGDATA/pg_hba.conf"
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -c "create role dev login" -c "create role pw login password '$POSTGRES_PASSWORD'"
