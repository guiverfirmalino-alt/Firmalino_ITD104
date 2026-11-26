# User Roles and Permissions (RBAC)

## 1. Two layers of access control

StudyNC checks every request at two levels. A request must pass both.

1. **Database privileges** (GRANT/REVOKE on roles). These decide which views a database login may SELECT and which procedures or functions it may EXECUTE. **No application role has INSERT, UPDATE, DELETE or SELECT on any base table.**
2. **Application-role check inside every procedure** (`sp_set_actor`). The acting application user must exist, be `Active`, and hold one of the roles the operation needs. Ownership rules are checked too, such as "only the instructor who owns a quiz may change it."

Because of layer 2, even a privileged connection cannot act as a student without a student user id, and an instructor cannot change another instructor's quiz.

## 2. Database roles and accounts

| Database role | Application role (documentation) | Login accounts (demo) |
|---|---|---|
| `studync_admin_role` | Administrator | `studync_app_admin` (shared app account), `maria.reyes` (personal) |
| `studync_instructor_role` | Instructor | `studync_app_instructor`, `jose.cruz`, `liza.garcia` |
| `studync_student_role` | Student | `studync_app_student`, `ana.santos`, `ben.torres` |
| `studync_dba_role` | (database maintenance, not an app role) | `studync_dba` |
| `studync_owner` (PostgreSQL only, NOLOGIN) | owns all objects; SECURITY DEFINER code runs as this role, not as a superuser | – |

Demo passwords are in `08_users_roles_permissions.sql`. **They must be changed for any real use.**

* **Shared application accounts** are what a web application would use. The application authenticates the person with `sp_authenticate_user` and passes that person's `user_id` to every call.
* **Personal accounts** have a login name equal to `users.username`. For these, the database itself stops impersonation: `ana.santos` cannot pass `ben.torres`'s user id (tests RB-S11 and RB-I10). The `v_my_results` view returns only the logged-in student's rows.

## 3. Permission matrix (from the Detailed CRUD Matrix)

| Process / Function (CRUD matrix) | Object granted | Admin | Instructor | Student |
|---|---|:-:|:-:|:-:|
| Login | `sp_authenticate_user` | ✔ | ✔ | ✔ |
| Change own password | `sp_change_password` | ✔ | ✔ | ✔ |
| Register Instructor | `sp_register_instructor` | ✔ | | |
| Register Student | `sp_register_student` | ✔ | | |
| Assign / revoke role | `sp_assign_role`, `sp_revoke_role` | ✔ | | |
| Manage account (update, activate/deactivate) | `sp_update_user`, `sp_set_user_status` | ✔ | | |
| View Users | `v_user_directory`, `sp_get_user`/`fn_get_user` (others: own record only) | ✔ | own | own |
| Create / Update / Delete Subject | `sp_create_subject`, `sp_update_subject`, `sp_delete_subject` | ✔ | | |
| View Subjects | `v_subject_catalog` | ✔ | ✔ | ✔ |
| Upload / Update / Delete Material | `sp_upload_material`, `sp_update_material`, `sp_delete_material` | | ✔ (own) | |
| View Materials | `v_learning_materials`, `…get_materials_by_subject` | ✔ | ✔ | ✔ |
| Create / Update / Delete Quiz | `sp_create_quiz`, `sp_update_quiz`, `sp_delete_quiz` | | ✔ (own) | |
| Add / Update / Delete Question | `sp_add_question`, `sp_update_question`, `sp_delete_question` | | ✔ (own) | |
| View Quizzes | `v_quiz_overview`; questions: `v_quiz_questions_instructor` (with key) / `v_quiz_questions_student` (no key) | ✔ | ✔ | ✔ (no key) |
| Submit Answer | `sp_submit_answer` | | | ✔ |
| Submit Quiz | `sp_submit_quiz` | | | ✔ |
| View Results | `v_quiz_results_detail`, `…get_student_results`, `…get_answer_review` | ✔ (all) | ✔ (own quizzes) | ✔ (own only, `v_my_results`) |
| Reports | `…report_student_performance`, `…report_quiz_results`, `v_student_performance` | ✔ | ✔ (own quizzes) | |
| View Audit Logs | `v_audit_trail`, `…report_audit_logs`, `…report_system_activity` | ✔ | | |

(`…` means `sp_` in MySQL and `fn_` in PostgreSQL.)

## 4. What is explicitly denied (REVOKE) and verified by tests

| Restriction | Test ids |
|---|---|
| No role can read `users` (password hashes), not even Administrators | RB-S03, RB-I04, RB-A04 |
| Students cannot see the answer key (`questions`, `v_quiz_questions_instructor`) | RB-S04, RB-S05 |
| Nobody can INSERT, UPDATE or DELETE tables directly | RB-S06, RB-I09 |
| Nobody can modify or delete `audit_logs`; the DBA cannot TRUNCATE it | RB-S10, RB-A05, CON-12, CON-13, CON-16 |
| Internal helpers (`sp_set_actor` etc.) are not callable | RB-A08 |
| Each role is denied the other roles' procedures | RB-S07, RB-S08, RB-I05, RB-I06, RB-I08, RB-A06, RB-A07, RB-P01 |
| A GRANT takes effect and a REVOKE removes it again | GR-01, GR-02 |

## 5. Password security and credential storage

| | MySQL | PostgreSQL |
|---|---|---|
| Application passwords (`users.password_hash`) | Salted, key-stretched SHA-256: `$sha256$5000$<random 16-byte salt>$<hash>`. MySQL has no built-in bcrypt. | **bcrypt** (cost 10) via `pgcrypto`: `crypt(pw, gen_salt('bf',10))` |
| Policy | ≥ 8 characters, upper-case, lower-case and digit (`fn_is_strong_password`) | same |
| Exposure | No view returns the hash; the audit trail removes it and records only `password_changed: true` | same |
| Database login passwords | `caching_sha2_password`; `FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1`; personal accounts `PASSWORD EXPIRE INTERVAL 180 DAY` | SCRAM-SHA-256; `VALID UNTIL`, `CONNECTION LIMIT` (core PostgreSQL has no lock-after-N-failures) |
| Login auditing | `sp_authenticate_user` writes LOGIN_SUCCESS / LOGIN_FAILED with a generic error message (no username enumeration) | same |

**Production note:** the procedures receive the plain password so the database can hash it, which lets this academic project be demonstrated inside the database. In production, connect over TLS (`REQUIRE SSL` / `hostssl`), keep statement logging off for these calls, or hash in the application tier with bcrypt or Argon2.

## 6. PostgreSQL-specific hardening

* `REVOKE EXECUTE ON ALL FUNCTIONS/PROCEDURES … FROM PUBLIC` and `ALTER DEFAULT PRIVILEGES … REVOKE EXECUTE ON ROUTINES FROM PUBLIC`. PostgreSQL grants EXECUTE to everyone by default.
* `REVOKE ALL ON DATABASE studync_db FROM PUBLIC` (no CONNECT unless granted). The `public` schema is not used.
* Every SECURITY DEFINER routine pins `SET search_path = studync, pg_temp`, which blocks search-path hijacking.
* `v_my_results` is a `security_barrier` view.
* pgcrypto is installed in its own `extensions` schema.
