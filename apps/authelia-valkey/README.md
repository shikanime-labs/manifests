# authelia-valkey

Valkey 9 (valkey/valkey 9-alpine) on :6379 as authelia's session store
(session.redis), enabling multi-replica authelia later. Persistent: AOF
enabled (--appendonly yes) on a 512Mi local-path volume. Only the authelia
pod may connect (NetworkPolicy).
