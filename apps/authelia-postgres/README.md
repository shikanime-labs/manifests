# authelia-postgres

PostgreSQL backing authelia (postgres:17, port :5432) so authelia can move
off SQLite and later run HA. Credentials come from the `authelia-postgres-env`
basic-auth Secret (POSTGRES_DB/USER/PASSWORD); data sits on the 1Gi
`data` volumeClaimTemplate. Only the authelia pod may connect
(NetworkPolicy).
