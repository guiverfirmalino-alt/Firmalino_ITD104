# Testing Instructions

## What is tested

File `10_testing_queries.sql` in each folder is a **self-checking** test suite. Every test writes a PASS or FAIL row to `studync_test.results`, together with the database login that ran it, so the result never depends on reading output by eye.

| Area (test id prefix) | Covers | Positive / negative |
|---|---|---|
| STR | database, 13 tables, 14 FKs, 10 views, routines, triggers, sample data | positive |
| CON | FK restrictions, UNIQUE, CHECK, NOT NULL, answer lock, immutable answers, append-only audit log, forged `is_correct`/score overwritten, DBA cannot TRUNCATE the audit log | mostly negative |
| USR | register, duplicate/weak/invalid input, login success, failure and inactive account, update, assign/revoke role, deactivate, change password | both |
| SUB | create, update, delete, duplicate, delete-in-use, unauthorized roles | both |
| MAT | upload, update, delete, ownership, path traversal, missing subject, student denied | both |
| QUZ | quiz and question CRUD, bad answer key, duplicate options, ownership, locks after answers/results | both |
| ASM | answer by letter or text, invalid answer, duplicate answer, submit, double submit, empty submit, **score calculation**, own-results only, review | both |
| RPT | performance report, quiz report, audit report, activity summary, role limits, numeric checks of averages | both |
| AUD | INSERT/UPDATE/DELETE logged with user, record id, old/new data; no password hash; exactly one row per change; no row for no-op updates; DBA changes logged; failed calls leave no rows | positive |
| RB-S / RB-I / RB-A / RB-P | the same operations attempted by real **student, instructor, administrator and shared-application logins**, proving GRANT/REVOKE and anti-impersonation | both |
| GR | GRANT takes effect and REVOKE removes it | both |

The full list of every test, its expected behaviour and the actual result in both DBMSs is in **[06_test_catalog_and_results.md](06_test_catalog_and_results.md)**.

## How to run

### Automated (recommended)

```bash
tests/run_mysql_tests.sh                 # builds MySQL 01-09, runs 10, prints the summary
tests/build_postgresql.sh --test         # builds PostgreSQL 01-09, runs 10, prints the summary
```

Both scripts exit with code 0 only if every test passed. The full console output is saved in `test_results/`.
Override the admin connection with `ROOT_CMD="mysql -u root -pXXXX"` or `PSQL="psql -U postgres -h localhost"`.

### Manual

* **PostgreSQL** (psql or pgAdmin): run `10_testing_queries.sql` as `postgres` on a fresh build. Each line prints `TEST-ID PASS/FAIL description [detail]`, and the last three queries print the summary.
* **MySQL Workbench**: run the sections in order. Sections that start with `-- @as <account>` must run in a connection logged in as that account (passwords are in file 08). After the last section:

```sql
SELECT outcome, COUNT(*) FROM studync_test.results GROUP BY outcome;   -- expect only PASS
SELECT * FROM studync_test.results WHERE outcome = 'FAIL';             -- expect 0 rows
```

## Reading a result

| Column | Meaning |
|---|---|
| `expected` | `SUCCESS`, `TRUE`, or `ERROR <code or text>` |
| `outcome` | PASS if the actual behaviour matched the expectation |
| `detail` | the actual error number and message, or the measured value (for example `score=66.67`) |
| `run_as` | the database login that executed the statement, which shows that role tests really ran as that role |

## Expected error codes

| Situation | MySQL | PostgreSQL |
|---|---|---|
| Missing privilege on a table or view | 1142 | 42501 |
| Missing EXECUTE on a routine | 1370 | 42501 |
| Application-level ACCESS DENIED (role, ownership, impersonation, inactive) | 1644 (`SIGNAL 45000`) | 42501 |
| Business-rule violation | 1644 | P0001 |
| Foreign key | 1451 / 1452 | 23503 |
| Unique | 1062 | 23505 |
| Check | 3819 | 23514 |
| Not null | 1364 | 23502 |

## Last verified run

| DBMS | Server | Tests | PASS | FAIL |
|---|---|---|---|---|
| MySQL | 8.0.46 (Ubuntu 24.04) | 169 | 169 | 0 |
| PostgreSQL | 16.15 (Ubuntu 24.04) | 170 | 170 | 0 |

PostgreSQL has one extra test, CON-17: even a superuser's `TRUNCATE audit_logs` is blocked by a statement-level trigger. MySQL has no TRUNCATE trigger. There, the protection is that no StudyNC account has the DROP privilege that TRUNCATE needs (CON-16).
