# Database Implementation Instructions

Both implementations are **independent**: each folder builds a complete StudyNC database by itself. Run the files **in numeric order**.

## Requirements

| | MySQL | PostgreSQL |
|---|---|---|
| Server version | **8.0.30 or newer** (uses `REVOKE IF EXISTS`, CHECK constraints, roles, `FAILED_LOGIN_ATTEMPTS`). Verified on 8.0.46. | **16 or newer** (14+ works for procedures with OUT parameters). Verified on 16.15. |
| Client | MySQL Workbench 8.0 or the `mysql` command-line client | pgAdmin 4 or `psql` |
| Account to run 01–10 | `root` or another account with CREATE USER and GRANT OPTION | the `postgres` superuser |
| Extensions | none | `pgcrypto` (ships with PostgreSQL; created by file 02) |

## A. MySQL 8

### Command line

```bash
cd mysql
for f in 0*.sql; do mysql -u root -p < "$f" || break; done      # files 01-09
```

### MySQL Workbench

1. Connect as `root`.
2. For files 01 to 09: *File → Open SQL Script*, then *Execute* (⚡ lightning icon). The `DELIMITER $$` lines are understood by Workbench.
3. File 10 (tests) contains sections marked `-- @as <account>`. Run the `root` sections in the root connection. For each other section, open a new connection as that account (passwords are in file 08) and run that section there. You can also run `tests/run_mysql_tests.sh`, which does all of this automatically.

### What each file does

| File | Content |
|---|---|
| 01_database_creation.sql | drops and recreates `studync_db` (utf8mb4) |
| 02_table_creation.sql | 13 tables (PK, NOT NULL, DEFAULT) + role reference data |
| 03_constraints_and_indexes.sql | UNIQUE, CHECK, FK, secondary indexes |
| 04_views.sql | 10 SQL SECURITY DEFINER views |
| 05_stored_procedures.sql | 36 procedures (31 public procedures for the 6 modules + 5 internal helpers) |
| 06_functions.sql | 12 functions (hashing, validation, scoring) |
| 07_triggers_and_audit_logs.sql | 6 business-rule triggers + 36 audit triggers |
| 08_users_roles_permissions.sql | 4 roles, 9 accounts, GRANT/REVOKE |
| 09_sample_data.sql | sample data, created through the procedures |
| 10_testing_queries.sql | 169 self-checking tests |

## B. PostgreSQL 16

### Command line (psql)

```bash
cd postgresql
psql -U postgres -d postgres   -f 01_database_creation.sql
for f in 0[2-9]_*.sql; do psql -U postgres -d studync_db -v ON_ERROR_STOP=1 -f "$f" || break; done
psql -U postgres -d studync_db -f 10_testing_queries.sql
```

or simply `tests/build_postgresql.sh --test`.

### pgAdmin 4

1. Open a Query Tool on the **postgres** database and run `01_database_creation.sql` **one statement at a time** (highlight a statement, press F5). PostgreSQL does not allow `DROP/CREATE DATABASE` inside a multi-statement batch.
2. Refresh the tree, open a Query Tool on **studync_db**, then open and run files 02 to 10 one after another (F5 runs the whole file). This was checked by sending each file to the server as a single batch, the way pgAdmin does.
3. File 10 switches identity with `SET SESSION AUTHORIZATION`, so the whole test suite runs in one Query Tool session.

### What each file does

| File | Content |
|---|---|
| 01_database_creation.sql | NOLOGIN owner role `studync_owner`, database `studync_db`, REVOKE CONNECT from PUBLIC |
| 02_table_creation.sql | schema `studync`, `extensions` schema + pgcrypto, ENUM type, 10 sequences, 13 tables, role reference data |
| 03_constraints_and_indexes.sql | UNIQUE (case-insensitive indexes), CHECK, FK, FK indexes, GIN index on audit JSONB |
| 04_views.sql | 10 views (owner-rights; `v_my_results` is a security_barrier view) |
| 05_stored_procedures.sql | 27 PL/pgSQL procedures (all data-changing operations) |
| 06_functions.sql | 10 helper functions + 10 retrieval/report functions |
| 07_triggers_and_audit_logs.sql | generic `fn_audit_row()` audit trigger function + 36 audit triggers + 5 business-rule triggers |
| 08_users_roles_permissions.sql | 4 group roles, 9 logins, REVOKE FROM PUBLIC, GRANTs |
| 09_sample_data.sql | sample data, created through the procedures |
| 10_testing_queries.sql | 170 self-checking tests |

## C. Re-running

* Both builds are re-runnable: 01 drops the database and 08 drops and recreates its roles.
* **The tests change data.** Rebuild with 01 to 09 before running file 10 again.
* In PostgreSQL the roles are cluster-wide and survive `DROP DATABASE`. File 08 removes them cleanly (`DROP OWNED` + `DROP ROLE`).

## D. Quick manual tour (after loading the sample data)

MySQL, as root:

```sql
USE studync_db;
CALL sp_authenticate_user('ana.santos', 'Pass#Ana2026', @ok, @uid, @roles, @msg);
SELECT @ok, @uid, @roles, @msg;
CALL sp_get_quiz_questions('USR0000006', 'QUZ0000004');          -- student: no answer key
CALL sp_submit_answer('USR0000006', 'QST0000014', 'B', @a);
CALL sp_submit_answer('USR0000006', 'QST0000015', 'A', @a);
CALL sp_submit_quiz('USR0000006', 'QUZ0000004', @res, @score);  SELECT @res, @score;   -- 66.67
CALL sp_report_quiz_results('USR0000001', 'QUZ0000004');
SELECT * FROM v_audit_trail ORDER BY log_id DESC LIMIT 10;
```

PostgreSQL, as postgres:

```sql
SET search_path = studync;
CALL sp_authenticate_user('ana.santos', 'Pass#Ana2026', NULL, NULL, NULL, NULL);
SELECT * FROM fn_get_quiz_questions('USR0000006', 'QUZ0000004');
CALL sp_submit_answer('USR0000006', 'QST0000014', 'B', NULL);
CALL sp_submit_answer('USR0000006', 'QST0000015', 'A', NULL);
CALL sp_submit_quiz('USR0000006', 'QUZ0000004', NULL, NULL);       -- returns result_id, 66.67
SELECT * FROM fn_report_quiz_results('USR0000001', 'QUZ0000004');
SELECT * FROM v_audit_trail ORDER BY log_id DESC LIMIT 10;
```

Sample application logins: every sample user's password is `Pass#<FirstName>2026` (for example `Pass#Maria2026`).
Sample ids: USR0000001 maria.reyes (Admin), USR0000002 carlo.mendoza (Admin + Instructor), USR0000003–5 instructors jose.cruz, liza.garcia and ramon.villanueva, USR0000006–12 students (ana, ben, carla, diego, ella, felix, gina; gina is Inactive).
