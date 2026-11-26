# Stored Procedure and Function Documentation

**Common rules for every public routine**

* The first parameter, `p_actor_user_id`, is the authenticated application user who performs the action. `sp_set_actor` checks that the user exists, is Active, has the required role, and (for personal logins) is the same person as the login. It then publishes the id to the audit triggers.
* All routines are **SECURITY DEFINER**, so callers need only EXECUTE.
* Errors: authorization failures start with `ACCESS DENIED` (MySQL SQLSTATE 45000 / errno 1644; PostgreSQL SQLSTATE 42501). Validation errors use the same messages in both DBMSs (MySQL 45000; PostgreSQL P0001).
* **Transactions.** MySQL procedures use `START TRANSACTION … COMMIT` with an `EXIT HANDLER` that does `ROLLBACK; RESIGNAL`. In PostgreSQL every CALL is atomic: any exception rolls back all of its changes. There is no explicit COMMIT, so the procedures can also be called inside a caller's transaction.
* **Read operations.** In MySQL they are procedures that return result sets (`sp_get_*`, `sp_report_*`). In PostgreSQL they are set-returning functions (`fn_get_*`, `fn_report_*`, used as `SELECT * FROM fn_…(…)`), because a PostgreSQL procedure cannot return a result set.
* **Optional parameters.** Passing NULL to an "update" parameter keeps the current value.
* **OUT parameters.** In MySQL, pass session variables (`@id`). In PostgreSQL, pass `NULL` as a placeholder; the values come back as a result row.

## Module 1 – User Management

| Routine | Roles | Parameters | Behaviour |
|---|---|---|---|
| `sp_authenticate_user` | all | username, password, OUT success, OUT user_id, OUT roles, OUT message | Verifies the hash; inactive accounts fail. Logs LOGIN_SUCCESS or LOGIN_FAILED. Never raises an error, so the failure log row is kept. |
| `sp_register_student` | Admin | actor, username, email, password, first, last, OUT user_id, OUT student_id | DFD 1.1 validate → 1.3 register → 1.4 assign role → 1.5 store. Hashes the password and creates the users, user_roles and students rows in one transaction. |
| `sp_register_instructor` | Admin | same, OUT instructor_id | Same flow for instructors (DFD 1.2). |
| `sp_assign_role` | Admin | actor, user_id, role_name | Adds the role and creates the matching profile row if it is missing. |
| `sp_revoke_role` | Admin | actor, user_id, role_name | An admin cannot remove their own Administrator role, and a user must keep at least one role. |
| `sp_update_user` | Admin | actor, user_id, email, first, last | Updates the email (stored lower-case, kept unique) and the profile names. |
| `sp_set_user_status` | Admin | actor, user_id, 'Active' or 'Inactive' | Replaces deletion. An admin cannot change their own status. |
| `sp_change_password` | all (self) | actor, old, new | Checks the old password and the password policy, then stores a new hash with a new salt. |
| `sp_get_user` / `fn_get_user` | all | actor, user_id | Admins can read anyone; other users only themselves. |

## Module 2 – Subject Management (Administrator)

| Routine | Parameters | Behaviour |
|---|---|---|
| `sp_create_subject` | actor, name, description, OUT subject_id | Name is required and unique (case-insensitive). |
| `sp_update_subject` | actor, subject_id, name, description | NULL keeps the current value. |
| `sp_delete_subject` | actor, subject_id | Refused if the subject still has materials or quizzes. |

## Module 3 – Learning Material Management (Instructor, own materials)

| Routine | Parameters | Behaviour |
|---|---|---|
| `sp_upload_material` | actor, subject_id, title, file_path, OUT material_id | DFD 3.1 select subject → 3.2 upload → 3.3 store. The path must not contain `..`, backslashes or control characters. |
| `sp_update_material` | actor, material_id, subject_id, title, file_path | Owner only. |
| `sp_delete_material` | actor, material_id | Owner only. |
| `sp_get_materials_by_subject` / `fn_get_materials_by_subject` | actor, subject_id | All roles. |

## Module 4 – Quiz Management (Instructor, own quizzes)

| Routine | Parameters | Behaviour |
|---|---|---|
| `sp_create_quiz` | actor, subject_id, title, OUT quiz_id | |
| `sp_update_quiz` | actor, quiz_id, subject_id, title | Owner only. |
| `sp_delete_quiz` | actor, quiz_id | Owner only. Refused once there are answers or results. Deletes the questions explicitly (audited), then the quiz. |
| `sp_add_question` | actor, quiz_id, text, option_a..d, correct (letter A–D or option text), OUT question_id | Refused after results exist, because adding a question would change existing scores. |
| `sp_update_question` | actor, question_id, text, options, correct | Refused once anyone has answered the question. |
| `sp_delete_question` | actor, question_id | Same lock. |
| `sp_get_quiz_questions` / `fn_get_quiz_questions` | actor, quiz_id | Admins and the owning instructor see `correct_answer`. Everyone else does not (MySQL omits the column; PostgreSQL returns NULL). |

## Module 5 – Assessment Processing (Student)

| Routine | Parameters | Behaviour |
|---|---|---|
| `sp_submit_answer` | actor, question_id, answer (A–D or option text), OUT answer_id | DFD 5.2. Checks that the answer is one of the options, allows one answer per question, and refuses answers after submission. **`is_correct` is set by trigger and not revealed to the student before submission.** |
| `sp_submit_quiz` | actor, quiz_id, OUT result_id, OUT score | DFD 5.3/5.4. The quiz must have questions, at least one answer must exist, and it can be submitted only once. The score is calculated by trigger. |
| `sp_get_student_results` / `fn_get_student_results` | actor, student_id (optional) | Students see their own results, instructors see their own quizzes, admins see everything. |
| `sp_get_answer_review` / `fn_get_answer_review` | actor, quiz_id, student_id (optional) | Per-question review, available only after the quiz is submitted. |

**Scoring rule** (`fn_calculate_quiz_score`): `score = ROUND(correct / total questions × 100, 2)`. All questions have equal weight and unanswered questions count as wrong. Example: 2 of 3 correct gives 66.67. Four of five questions answered with two correct gives 40.00 (tests ASM-08 and ASM-12).

## Module 6 – Reporting and Monitoring

| Routine | Roles | Output |
|---|---|---|
| `…report_student_performance(actor, subject_id?)` | Admin (all), Instructor (own quizzes) | student, subject, quizzes taken, average, highest and lowest score |
| `…report_quiz_results(actor, quiz_id)` | Admin, owning Instructor | per-student scores (MySQL also returns a second result set with summary statistics; PostgreSQL has `fn_report_quiz_summary`) |
| `…report_audit_logs(actor, table?, action?, from?, to?, limit)` | Admin | audit trail, filterable |
| `…report_system_activity(actor, days)` | Admin | operations per table and action, distinct users, last activity |

## Functions (both DBMSs)

| Function | Purpose |
|---|---|
| `fn_hash_password`, `fn_verify_password` | Password hashing and verification (MySQL: salted, iterated SHA-256; PostgreSQL: bcrypt) |
| `fn_is_strong_password` | Password policy |
| `fn_is_safe_file_path` | Material path validation |
| `fn_resolve_option` | Maps A–D or option text to the stored option |
| `fn_user_has_role`, `fn_get_instructor_id`, `fn_get_student_id`, `fn_question_count` | Lookups |
| `fn_calculate_quiz_score` | The assessment rule |
| MySQL only: `fn_format_id`, `fn_hash_password_iter` | Id formatting and the hash loop |

## Internal helpers (not granted to anyone)

`sp_set_actor`, `sp_next_id` (MySQL), `sp_clear_actor` (PostgreSQL), `sp_create_profile`, `sp_register_user`, `sp_assert_quiz_owner`.

## Calling the procedures safely from an application (no SQL injection)

Always pass values as **bound parameters**, never by joining strings into SQL:

```python
# MySQL (mysql-connector-python)
cur.callproc("sp_submit_answer", (auth_user_id, question_id, answer_from_form, None))

# PostgreSQL (psycopg 3)
cur.execute("CALL studync.sp_submit_answer(%s, %s, %s, NULL)", (auth_user_id, question_id, answer_from_form))
```

```php
// PHP PDO (MySQL)
$stmt = $pdo->prepare("CALL sp_submit_answer(?, ?, ?, @answer_id)");
$stmt->execute([$authUserId, $questionId, $_POST['answer']]);
```

Inside the database no routine builds dynamic SQL from its parameters, so user input is always treated as data.
