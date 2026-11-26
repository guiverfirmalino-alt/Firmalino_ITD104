-- =============================================================================
-- StudyNC Learning Management System Database  (PostgreSQL 16+)
-- File 01 : Database creation
-- Project : FIRMALINO - ITD104 Database Security, Administration & Management
-- -----------------------------------------------------------------------------
-- Run as   : a superuser (e.g. postgres), connected to the "postgres" database.
--   psql   : psql -U postgres -d postgres -f 01_database_creation.sql
--   pgAdmin: open a Query Tool on the "postgres" database and run the
--            statements ONE AT A TIME (highlight a statement, press F5).
--            PostgreSQL refuses DROP/CREATE DATABASE inside a multi-statement
--            batch ("cannot run inside a transaction block"). Files 02-10
--            can be executed as a whole.
-- Then run files 02-10 CONNECTED TO studync_db
--   psql   : psql -U postgres -d studync_db -f 02_table_creation.sql  (etc.)
--   pgAdmin: refresh, open a Query Tool on studync_db.
--
-- WARNING : drops and re-creates studync_db (clean rebuild).
--
-- Ownership model (PostgreSQL-specific security design)
--   studync_owner is a NOLOGIN role that owns the database, the schema and
--   every object. SECURITY DEFINER procedures therefore run with the rights of
--   studync_owner - NOT with superuser rights - which limits the damage any
--   bug in a definer routine could cause.
-- =============================================================================

-- PostgreSQL 13+: FORCE disconnects open sessions before dropping
DROP DATABASE IF EXISTS studync_db WITH (FORCE);

-- Roles are cluster-wide, so create the owner only if it does not exist yet
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'studync_owner') THEN
        CREATE ROLE studync_owner NOLOGIN;
    END IF;
END
$$;

CREATE DATABASE studync_db
    WITH OWNER    = studync_owner
         ENCODING = 'UTF8'
         TEMPLATE = template0;

COMMENT ON DATABASE studync_db IS 'StudyNC Learning Management System (ITD104 - Firmalino)';

-- Nobody may connect or create temp objects unless explicitly granted (file 08)
REVOKE ALL ON DATABASE studync_db FROM PUBLIC;

SELECT datname, pg_catalog.pg_get_userbyid(datdba) AS owner, pg_encoding_to_char(encoding) AS encoding
FROM pg_database WHERE datname = 'studync_db';
