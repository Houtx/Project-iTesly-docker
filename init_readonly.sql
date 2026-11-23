SELECT format('CREATE ROLE teslamate_app LOGIN PASSWORD %L', :'app_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'teslamate_app') \gexec
SELECT format('ALTER ROLE teslamate_app LOGIN PASSWORD %L', :'app_password') \gexec

GRANT CONNECT ON DATABASE teslamate TO teslamate_app;
GRANT USAGE ON SCHEMA public TO teslamate_app;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO teslamate_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO teslamate_app;
REVOKE UPDATE ON ALL TABLES IN SCHEMA public FROM teslamate_app;
GRANT UPDATE (cost) ON charging_processes TO teslamate_app;
ALTER ROLE teslamate_app RESET default_transaction_read_only;
ALTER ROLE teslamate_app SET statement_timeout = '20s';
