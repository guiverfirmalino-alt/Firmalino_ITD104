# Test Catalog and Actual Results

Generated from `studync_test.results` after running both suites on **MySQL 8.0.46** and **PostgreSQL 16.15** (Ubuntu 24.04).
MySQL: **169/169 PASS** · PostgreSQL: **170/170 PASS**

*Expected* is what the test requires: success, a true condition, or failure with the listed MySQL error number / PostgreSQL SQLSTATE or message text. *Run as* is the database login that executed the test. Rows marked *Fails* are the negative (unsuccessful) test cases.


## 1. Database and table creation

| Id | Test | Run as | Expected (MySQL) | MySQL result | Expected (PostgreSQL) | PostgreSQL result |
|---|---|---|---|---|---|---|
| STR-01 | Database studync_db exists | root | Condition true | **PASS** | Condition true | **PASS** |
| STR-02 | All 13 ERD tables exist | root | Condition true | **PASS** – admins,audit_logs,instructors,materials,questions,quiz_results,quizzes,roles,student_answe | Condition true | **PASS** – student_answers,quizzes,user_roles,roles,audit_logs,subjects,materials,quiz_results,instru |
| STR-03 | 14 foreign keys defined | root | Condition true | **PASS** – 14 FKs | Condition true | **PASS** – 14 FKs |
| STR-04 | 10 views defined | root | Condition true | **PASS** | Condition true | **PASS** |
| STR-05 | MySQL: Stored procedures and functions exist (>=35 / >=12) · PostgreSQL: Procedures and functions exist (>=27 procedures / >=20 fn_ functions) | root | Condition true | **PASS** – FUNCTION:12,PROCEDURE:39 | Condition true | **PASS** – f:24 p:27 |
| STR-06 | MySQL: 42 triggers (36 audit + 6 business rule) · PostgreSQL: 41 triggers (36 audit + 5 business rule) | root | Condition true | **PASS** – 42 triggers | Condition true | **PASS** – 41 triggers |
| STR-07 | Sample data loaded (12 users, 19 questions, 12 results) | root | Condition true | **PASS** | Condition true | **PASS** |

## 2. Constraints, foreign keys, business-rule triggers

| Id | Test | Run as | Expected (MySQL) | MySQL result | Expected (PostgreSQL) | PostgreSQL result |
|---|---|---|---|---|---|---|
| CON-01 | FK: material for a non-existent subject is rejected | root | Fails: 1452 | **PASS** – error 1452: Cannot add or update a child row: a foreign key constraint fails (`studync_db` | Fails: 23503 | **PASS** – error 23503: insert or update on table "materials" violates foreign key constraint "fk_mat |
| CON-02 | FK: deleting a subject that has materials is rejected (no orphans) | root | Fails: 1451 | **PASS** – error 1451: Cannot delete or update a parent row: a foreign key constraint fails (`studync | Fails: 23503 | **PASS** – error 23503: update or delete on table "subjects" violates foreign key constraint "fk_mate |
| CON-03 | FK: deleting a quiz that has questions is rejected | root | Fails: 1451 | **PASS** – error 1451: Cannot delete or update a parent row: a foreign key constraint fails (`studync | Fails: 23503 | **PASS** – error 23503: update or delete on table "quizzes" violates foreign key constraint "fk_quest |
| CON-04 | CHECK: correct_answer must be one of the options | root | Fails: 3819 | **PASS** – error 3819: Check constraint 'ck_questions_correct_is_option' is violated. | Fails: 23514 | **PASS** – error 23514: new row for relation "questions" violates check constraint "ck_questions_corr |
| CON-05 | MySQL: UNIQUE: duplicate username rejected · PostgreSQL: UNIQUE: duplicate username rejected (case-insensitive) | root | Fails: 1062 | **PASS** – error 1062: Duplicate entry 'ana.santos' for key 'users.uq_users_username' | Fails: 23505 | **PASS** – error 23505: duplicate key value violates unique constraint "uq_users_username" |
| CON-06 | CHECK: invalid email format rejected | root | Fails: 3819 | **PASS** – error 3819: Check constraint 'ck_users_email_format' is violated. | Fails: 23514 | **PASS** – error 23514: new row for relation "users" violates check constraint "ck_users_email_format |
| CON-07 | CHECK: badly formatted primary key rejected | root | Fails: 3819 | **PASS** – error 3819: Check constraint 'ck_subjects_id_format' is violated. | Fails: 23514 | **PASS** – error 23514: new row for relation "subjects" violates check constraint "ck_subjects_id_for |
| CON-08 | NOT NULL: material without file_path rejected | root | Fails: 1364 | **PASS** – error 1364: Field 'file_path' doesn't have a default value | Fails: 23502 | **PASS** – error 23502: null value in column "file_path" of relation "materials" violates not-null co |
| CON-09 | UNIQUE: second result for same student and quiz rejected | root | Fails: 1062 | **PASS** – error 1062: Duplicate entry 'STU0000001-QUZ0000001' for key 'quiz_results.uq_quiz_results_ | Fails: 23505 | **PASS** – error 23505: duplicate key value violates unique constraint "uq_quiz_results_student_quiz" |
| CON-10 | Trigger: answers are locked after the quiz is submitted | root | Fails: answers are lo | **PASS** – error 1644: Quiz already submitted; answers are locked | Fails: answers are locked | **PASS** – error P0001: Quiz already submitted; answers are locked |
| CON-11 | Trigger: student answers cannot be modified | root | Fails: cannot be modi | **PASS** – error 1644: Student answers cannot be modified once submitted | Fails: cannot be modified | **PASS** – error P0001: Student answers cannot be modified once submitted |
| CON-12 | MySQL: Trigger: audit_logs is append-only (UPDATE blocked, even for root) · PostgreSQL: Trigger: audit_logs is append-only (UPDATE blocked, even for superuser) | root | Fails: append-only | **PASS** – error 1644: audit_logs is append-only: UPDATE is not allowed | Fails: append-only | **PASS** – error P0001: audit_logs is append-only: UPDATE/DELETE is not allowed |
| CON-13 | MySQL: Trigger: audit_logs is append-only (DELETE blocked, even for root) · PostgreSQL: Trigger: audit_logs is append-only (DELETE blocked, even for superuser) | root | Fails: append-only | **PASS** – error 1644: audit_logs is append-only: DELETE is not allowed | Fails: append-only | **PASS** – error P0001: audit_logs is append-only: UPDATE/DELETE is not allowed |
| CON-14 | Trigger ignores a forged is_correct = TRUE for a wrong answer | root | Condition true | **PASS** – stored is_correct = 0 | Condition true | **PASS** – stored is_correct = false |
| CON-15 | Trigger recomputes a forged score of 100 (0 of 3 correct -> 0.00) | root | Condition true | **PASS** – stored score = 0.00 | Condition true | **PASS** – stored score = 0.00 |

## 3. Module 1 – User management

| Id | Test | Run as | Expected (MySQL) | MySQL result | Expected (PostgreSQL) | PostgreSQL result |
|---|---|---|---|---|---|---|
| USR-01 | Admin registers a new student | root | Succeeds | **PASS** | Succeeds | **PASS** |
| USR-02 | Registration created users + user_roles + students rows | root | Condition true | **PASS** – user=USR0000013 student=STU0000008 | Condition true | **PASS** – USR0000013 |
| USR-03 | MySQL: Password is stored salted+hashed, never in plain text · PostgreSQL: Password is stored as a bcrypt hash, never in plain text | root | Condition true | **PASS** – $sha256$5000$4D13AAEB162C49F83 | Condition true | **PASS** – $2a$10$ASEFZ |
| USR-04 | MySQL: Same password for two users produces different hashes (salt) · PostgreSQL: Same password hashed twice gives different hashes (random salt) | root | Condition true | **PASS** | Condition true | **PASS** |
| USR-05 | Admin registers a new instructor | root | Succeeds | **PASS** | Succeeds | **PASS** |
| USR-06 | Duplicate username rejected by procedure | root | Fails: Username alrea | **PASS** – error 1644: Username already exists | Fails: Username already exists | **PASS** – error P0001: Username already exists |
| USR-07 | Weak password rejected | root | Fails: Weak password | **PASS** – error 1644: Weak password: minimum 8 characters with upper-case, lower-case and a digit | Fails: Weak password | **PASS** – error P0001: Weak password: minimum 8 characters with upper-case, lower-case and a digit |
| USR-08 | Invalid email rejected | root | Fails: Invalid email | **PASS** – error 1644: Invalid email address | Fails: Invalid email | **PASS** – error P0001: Invalid email address |
| USR-09 | Instructor cannot register users (application role check) | root | Fails: ACCESS DENIED | **PASS** – error 1644: ACCESS DENIED: this operation requires role(s) Administrator | Fails: ACCESS DENIED | **PASS** – error 42501: ACCESS DENIED: this operation requires role(s) Administrator |
| USR-10 | Unknown acting user rejected | root | Fails: unknown acting | **PASS** – error 1644: ACCESS DENIED: unknown acting user | Fails: unknown acting user | **PASS** – error 42501: ACCESS DENIED: unknown acting user |
| USR-11 | Authentication succeeds with the correct password | root | Condition true | **PASS** – 1 / USR0000013 / Student / Login successful | Condition true | **PASS** – t / USR0000013 / Student / Login successful |
| USR-12 | Authentication fails with a wrong password (generic message) | root | Condition true | **PASS** – 0 / Invalid username or password | Condition true | **PASS** – f / Invalid username or password |
| USR-13 | Inactive account cannot log in | root | Condition true | **PASS** – 0 / Invalid username or password | Condition true | **PASS** – f / Invalid username or password |
| USR-14 | Failed logins are written to the audit log | root | Condition true | **PASS** | Condition true | **PASS** |
| USR-15 | Admin updates user email and name | root | Succeeds | **PASS** | Succeeds | **PASS** |
| USR-16 | Update stored (email lower-cased, first name changed) | root | Condition true | **PASS** | Condition true | **PASS** |
| USR-17 | Admin assigns the Instructor role to a student (profile auto-created) | root | Succeeds | **PASS** | Succeeds | **PASS** |
| USR-18 | Role assignment created user_roles + instructors rows | root | Condition true | **PASS** | Condition true | **PASS** |
| USR-19 | Admin revokes the Instructor role again | root | Succeeds | **PASS** | Succeeds | **PASS** |
| USR-20 | Admin cannot revoke own Administrator role | root | Fails: cannot revoke  | **PASS** – error 1644: Administrators cannot revoke their own Administrator role | Fails: cannot revoke their own | **PASS** – error P0001: Administrators cannot revoke their own Administrator role |
| USR-21 | Admin cannot deactivate own account | root | Fails: own account st | **PASS** – error 1644: Administrators cannot change their own account status | Fails: own account status | **PASS** – error P0001: Administrators cannot change their own account status |
| USR-22 | Inactive user cannot perform any operation | root | Fails: inactive | **PASS** – error 1644: ACCESS DENIED: account is inactive | Fails: inactive | **PASS** – error 42501: ACCESS DENIED: account is inactive |
| USR-23 | User changes own password | root | Succeeds | **PASS** | Succeeds | **PASS** |
| USR-24 | Login works with the new password | root | Condition true | **PASS** – Login successful | Condition true | **PASS** – Login successful |
| USR-25 | Password change with wrong current password rejected | root | Fails: Current passwo | **PASS** – error 1644: Current password is incorrect | Fails: Current password is inco | **PASS** – error P0001: Current password is incorrect |
| USR-26 | Student cannot read another user record | root | Fails: ACCESS DENIED | **PASS** – error 1644: ACCESS DENIED: you may only view your own account | Fails: ACCESS DENIED | **PASS** – error 42501: ACCESS DENIED: you may only view your own account |

## 4. Module 2 – Subject management

| Id | Test | Run as | Expected (MySQL) | MySQL result | Expected (PostgreSQL) | PostgreSQL result |
|---|---|---|---|---|---|---|
| SUB-01 | Admin creates a subject | root | Succeeds | **PASS** | Succeeds | **PASS** |
| SUB-02 | New subject stored with generated id | root | Condition true | **PASS** – SUB0000006 | Condition true | **PASS** – SUB0000006 |
| SUB-03 | Duplicate subject name rejected | root | Fails: already exists | **PASS** – error 1644: Subject name already exists | Fails: already exists | **PASS** – error P0001: Subject name already exists |
| SUB-04 | Admin updates the subject | root | Succeeds | **PASS** | Succeeds | **PASS** |
| SUB-05 | Admin deletes an unused subject | root | Succeeds | **PASS** | Succeeds | **PASS** |
| SUB-06 | Deleted subject is gone | root | Condition true | **PASS** | Condition true | **PASS** |
| SUB-07 | Subject that has materials/quizzes cannot be deleted | root | Fails: cannot be dele | **PASS** – error 1644: Subject has materials or quizzes and cannot be deleted | Fails: cannot be deleted | **PASS** – error P0001: Subject has materials or quizzes and cannot be deleted |
| SUB-08 | Instructor cannot create subjects | root | Fails: ACCESS DENIED | **PASS** – error 1644: ACCESS DENIED: this operation requires role(s) Administrator | Fails: ACCESS DENIED | **PASS** – error 42501: ACCESS DENIED: this operation requires role(s) Administrator |
| SUB-09 | Student cannot delete subjects | root | Fails: ACCESS DENIED | **PASS** – error 1644: ACCESS DENIED: this operation requires role(s) Administrator | Fails: ACCESS DENIED | **PASS** – error 42501: ACCESS DENIED: this operation requires role(s) Administrator |

## 5. Module 3 – Learning materials

| Id | Test | Run as | Expected (MySQL) | MySQL result | Expected (PostgreSQL) | PostgreSQL result |
|---|---|---|---|---|---|---|
| MAT-01 | Instructor uploads a material | root | Succeeds | **PASS** | Succeeds | **PASS** |
| MAT-02 | Material linked to subject and uploading instructor | root | Condition true | **PASS** – MAT0000009 | Condition true | **PASS** – MAT0000012 |
| MAT-03 | Owner updates the material title | root | Succeeds | **PASS** | Succeeds | **PASS** |
| MAT-04 | Another instructor cannot update it | root | Fails: ACCESS DENIED | **PASS** – error 1644: ACCESS DENIED: you can only modify your own materials | Fails: ACCESS DENIED | **PASS** – error 42501: ACCESS DENIED: you can only modify your own materials |
| MAT-05 | Another instructor cannot delete it | root | Fails: ACCESS DENIED | **PASS** – error 1644: ACCESS DENIED: you can only delete your own materials | Fails: ACCESS DENIED | **PASS** – error 42501: ACCESS DENIED: you can only delete your own materials |
| MAT-06 | Path traversal in file_path rejected | root | Fails: Invalid file p | **PASS** – error 1644: Invalid file path | Fails: Invalid file path | **PASS** – error P0001: Invalid file path |
| MAT-07 | Upload to a non-existent subject rejected | root | Fails: Subject not fo | **PASS** – error 1644: Subject not found | Fails: Subject not found | **PASS** – error P0001: Subject not found |
| MAT-08 | Student cannot upload materials | root | Fails: ACCESS DENIED | **PASS** – error 1644: ACCESS DENIED: this operation requires role(s) Instructor | Fails: ACCESS DENIED | **PASS** – error 42501: ACCESS DENIED: this operation requires role(s) Instructor |
| MAT-09 | Student retrieves the materials of a subject | root | Succeeds | **PASS** | Succeeds | **PASS** |
| MAT-10 | Owner deletes the material | root | Succeeds | **PASS** | Succeeds | **PASS** |
| MAT-11 | Material deleted | root | Condition true | **PASS** | Condition true | **PASS** |

## 6. Module 4 – Quiz management

| Id | Test | Run as | Expected (MySQL) | MySQL result | Expected (PostgreSQL) | PostgreSQL result |
|---|---|---|---|---|---|---|
| QUZ-01 | Instructor creates a quiz | root | Succeeds | **PASS** | Succeeds | **PASS** |
| QUZ-02 | Instructor adds question 1 (correct answer given as letter) | root | Succeeds | **PASS** | Succeeds | **PASS** |
| QUZ-03 | Instructor adds question 2 (correct answer given as text) | root | Succeeds | **PASS** | Succeeds | **PASS** |
| QUZ-04 | Correct answers stored as option text | root | Condition true | **PASS** | Condition true | **PASS** |
| QUZ-05 | Question whose correct answer is not an option rejected | root | Fails: Correct answer | **PASS** – error 1644: Correct answer must be A, B, C, D or the exact text of an option | Fails: Correct answer must be | **PASS** – error P0001: Correct answer must be A, B, C, D or the exact text of an option |
| QUZ-06 | Question with duplicate options rejected (CHECK) | root | Fails: 3819 | **PASS** – error 3819: Check constraint 'ck_questions_distinct_options' is violated. | Fails: 23514 | **PASS** – error 23514: new row for relation "questions" violates check constraint "ck_questions_dist |
| QUZ-07 | Instructor updates a question | root | Succeeds | **PASS** | Succeeds | **PASS** |
| QUZ-08 | Instructor adds and deletes a temporary question | root | Succeeds | **PASS** | Succeeds | **PASS** |
| QUZ-09 | Instructor deletes a question | root | Succeeds | **PASS** | Succeeds | **PASS** |
| QUZ-10 | Instructor updates the quiz title | root | Succeeds | **PASS** | Succeeds | **PASS** |
| QUZ-11 | Another instructor cannot modify the quiz | root | Fails: ACCESS DENIED | **PASS** – error 1644: ACCESS DENIED: you can only manage your own quizzes | Fails: ACCESS DENIED | **PASS** – error 42501: ACCESS DENIED: you can only manage your own quizzes |
| QUZ-12 | Another instructor cannot add questions to it | root | Fails: ACCESS DENIED | **PASS** – error 1644: ACCESS DENIED: you can only manage your own quizzes | Fails: ACCESS DENIED | **PASS** – error 42501: ACCESS DENIED: you can only manage your own quizzes |
| QUZ-13 | Quiz with submitted results cannot be deleted | root | Fails: cannot be dele | **PASS** – error 1644: Quiz already has student answers or results and cannot be deleted | Fails: cannot be deleted | **PASS** – error P0001: Quiz already has student answers or results and cannot be deleted |
| QUZ-14 | Answered question cannot be changed | root | Fails: locked | **PASS** – error 1644: Question has already been answered and is locked | Fails: locked | **PASS** – error P0001: Question has already been answered and is locked |
| QUZ-15 | Student cannot create quizzes | root | Fails: ACCESS DENIED | **PASS** – error 1644: ACCESS DENIED: this operation requires role(s) Instructor | Fails: ACCESS DENIED | **PASS** – error 42501: ACCESS DENIED: this operation requires role(s) Instructor |
| QUZ-16 | Instructor creates and deletes an unused quiz (with a question) | root | Succeeds | **PASS** | Succeeds | **PASS** |
| QUZ-17 | Delete unused quiz | root | Succeeds | **PASS** | Succeeds | **PASS** |
| QUZ-18 | Quiz and its questions removed; question deletion audited | root | Condition true | **PASS** | Condition true | **PASS** |
| QUZ-19 | Student question view hides the answer key | root | Condition true | **PASS** | Condition true | **PASS** |

## 7. Module 5 – Assessment processing and score calculation

| Id | Test | Run as | Expected (MySQL) | MySQL result | Expected (PostgreSQL) | PostgreSQL result |
|---|---|---|---|---|---|---|
| ASM-01 | Student answers Q17 with a letter (correct) | root | Succeeds | **PASS** | Succeeds | **PASS** |
| ASM-02 | Student answers Q18 with option text (correct) | root | Succeeds | **PASS** | Succeeds | **PASS** |
| ASM-03 | Answer that is not an option is rejected | root | Fails: Answer must be | **PASS** – error 1644: Answer must be A, B, C, D or the exact text of an option | Fails: Answer must be | **PASS** – error P0001: Answer must be A, B, C, D or the exact text of an option |
| ASM-04 | Student answers Q19 (wrong) | root | Succeeds | **PASS** | Succeeds | **PASS** |
| ASM-05 | Second answer to the same question rejected | root | Fails: already answer | **PASS** – error 1644: Question already answered | Fails: already answered | **PASS** – error P0001: Question already answered |
| ASM-06 | MySQL: is_correct computed by the database (1,1,0) · PostgreSQL: is_correct computed by the database (t,t,f) | root | Condition true | **PASS** – 1,1,0 | Condition true | **PASS** – true,true,false |
| ASM-07 | Student submits the quiz | root | Succeeds | **PASS** | Succeeds | **PASS** |
| ASM-08 | Score = 2 of 3 correct = 66.67 | root | Condition true | **PASS** – result=RES0000013 score=66.67 | Condition true | **PASS** – RES0000015 score=66.67 |
| ASM-09 | Quiz cannot be submitted twice | root | Fails: already submit | **PASS** – error 1644: Quiz already submitted | Fails: already submitted | **PASS** – error P0001: Quiz already submitted |
| ASM-10 | Submitting a quiz with no answers rejected | root | Fails: No answers sub | **PASS** – error 1644: No answers submitted for this quiz | Fails: No answers submitted | **PASS** – error P0001: No answers submitted for this quiz |
| ASM-11 | Instructor cannot submit answers | root | Fails: ACCESS DENIED | **PASS** – error 1644: ACCESS DENIED: this operation requires role(s) Student | Fails: ACCESS DENIED | **PASS** – error 42501: ACCESS DENIED: this operation requires role(s) Student |
| ASM-12 | fn_calculate_quiz_score: partial attempt (4 of 5 answered, 2 correct) = 40.00 | root | Condition true | **PASS** | Condition true | **PASS** |
| ASM-13 | Every stored score equals the documented formula | root | Condition true | **PASS** | Condition true | **PASS** |
| ASM-14 | Student retrieves own results | root | Succeeds | **PASS** | Succeeds | **PASS** |
| ASM-15 | Student cannot retrieve another student's results | root | Fails: ACCESS DENIED | **PASS** – error 1644: ACCESS DENIED: students may only view their own results | Fails: ACCESS DENIED | **PASS** – error 42501: ACCESS DENIED: students may only view their own results |
| ASM-16 | Student reviews own submitted answers | root | Succeeds | **PASS** | Succeeds | **PASS** |
| ASM-17 | Answer review is not available before submission | root | Fails: No submitted r | **PASS** – error 1644: No submitted result for this student and quiz | Fails: No submitted result | **PASS** – error P0001: No submitted result for this student and quiz |

## 8. Module 6 – Reporting and monitoring

| Id | Test | Run as | Expected (MySQL) | MySQL result | Expected (PostgreSQL) | PostgreSQL result |
|---|---|---|---|---|---|---|
| RPT-01 | Admin: student performance report (all subjects) | root | Succeeds | **PASS** | Succeeds | **PASS** |
| RPT-02 | Instructor: performance report limited to own quizzes | root | Succeeds | **PASS** | Succeeds | **PASS** |
| RPT-03 | Student cannot run performance reports | root | Fails: ACCESS DENIED | **PASS** – error 1644: ACCESS DENIED: this operation requires role(s) Administrator,Instructor | Fails: ACCESS DENIED | **PASS** – error 42501: ACCESS DENIED: this operation requires role(s) Administrator,Instructor |
| RPT-04 | Instructor: quiz results report for own quiz | root | Succeeds | **PASS** | Succeeds | **PASS** |
| RPT-05 | Instructor: quiz results report for another instructor's quiz denied | root | Fails: ACCESS DENIED | **PASS** – error 1644: ACCESS DENIED: you can only manage your own quizzes | Fails: ACCESS DENIED | **PASS** – error 42501: ACCESS DENIED: you can only manage your own quizzes |
| RPT-06 | Admin: audit log report (filter by table) | root | Succeeds | **PASS** | Succeeds | **PASS** |
| RPT-07 | Instructor cannot read audit logs | root | Fails: ACCESS DENIED | **PASS** – error 1644: ACCESS DENIED: this operation requires role(s) Administrator | Fails: ACCESS DENIED | **PASS** – error 42501: ACCESS DENIED: this operation requires role(s) Administrator |
| RPT-08 | Admin: system activity summary | root | Succeeds | **PASS** | Succeeds | **PASS** |
| RPT-09 | MySQL: Performance view: QUZ averages correct (Ana avg of 100,75,75 = 83.33) · PostgreSQL: Performance view: Ana avg of 100,75,75 = 83.33 | root | Condition true | **PASS** – avg=83.33 | Condition true | **PASS** – avg=83.33 |
| RPT-10 | Quiz results view: QUZ0000001 has 4 submissions, average 70.00 | root | Condition true | **PASS** | Condition true | **PASS** |

## 9. Audit logging

| Id | Test | Run as | Expected (MySQL) | MySQL result | Expected (PostgreSQL) | PostgreSQL result |
|---|---|---|---|---|---|---|
| AUD-01 | INSERT audited with acting user, record id and new data | root | Condition true | **PASS** | Condition true | **PASS** |
| AUD-02 | UPDATE audited with old and new values | root | Condition true | **PASS** | Condition true | **PASS** |
| AUD-03 | DELETE audited with the deleted row in old_data | root | Condition true | **PASS** | Condition true | **PASS** |
| AUD-04 | password_hash never appears in the audit trail | root | Condition true | **PASS** | Condition true | **PASS** |
| AUD-05 | Password change logged as a flag only | root | Condition true | **PASS** | Condition true | **PASS** |
| AUD-06 | One operation produces exactly one audit row (no duplicates) | root | Condition true | **PASS** – 1 new row(s) | Condition true | **PASS** – 1 new row(s) |
| AUD-07 | No-op update writes no audit row | root | Condition true | **PASS** – 0 new row(s) | Condition true | **PASS** – 0 new row(s) |
| AUD-08 | Assessment activity audited (answers and results by the student) | root | Condition true | **PASS** | Condition true | **PASS** |
| AUD-09 | Direct DBA changes are audited with db_user and NULL application user | root | Condition true | **PASS** | Condition true | **PASS** |
| AUD-10 | MySQL: Session identity variable is cleared after each procedure · PostgreSQL: Session identity setting is cleared after each procedure | root | Condition true | **PASS** | Condition true | **PASS** |
| AUD-11 | Failed procedure calls leave no audit rows (rolled back) | root | Condition true | **PASS** | Condition true | **PASS** |

## 2. Constraints, foreign keys, business-rule triggers

| Id | Test | Run as | Expected (MySQL) | MySQL result | Expected (PostgreSQL) | PostgreSQL result |
|---|---|---|---|---|---|---|
| CON-16 | DBA maintenance account cannot TRUNCATE audit_logs | studync_dba | Fails: 1142 | **PASS** – error 1142: DROP command denied to user 'studync_dba'@'localhost' for table 'audit_logs' | Fails: 42501 | **PASS** – error 42501: permission denied for table audit_logs |

## 10. Role-based access (separate logins)

| Id | Test | Run as | Expected (MySQL) | MySQL result | Expected (PostgreSQL) | PostgreSQL result |
|---|---|---|---|---|---|---|
| RB-S01 | Student can read the student question view | ana.santos | Succeeds | **PASS** | Succeeds | **PASS** |
| RB-S02 | Student can read learning materials | ana.santos | Succeeds | **PASS** | Succeeds | **PASS** |
| RB-S03 | Student cannot read the users table (password hashes) | ana.santos | Fails: 1142 | **PASS** – error 1142: SELECT command denied to user 'ana.santos'@'localhost' for table 'users' | Fails: 42501 | **PASS** – error 42501: permission denied for table users |
| RB-S04 | Student cannot read the answer key view | ana.santos | Fails: 1142 | **PASS** – error 1142: SELECT command denied to user 'ana.santos'@'localhost' for table 'v_quiz_quest | Fails: 42501 | **PASS** – error 42501: permission denied for view v_quiz_questions_instructor |
| RB-S05 | Student cannot read the questions table directly | ana.santos | Fails: 1142 | **PASS** – error 1142: SELECT command denied to user 'ana.santos'@'localhost' for table 'questions' | Fails: 42501 | **PASS** – error 42501: permission denied for table questions |
| RB-S06 | Student cannot insert a result directly | ana.santos | Fails: 1142 | **PASS** – error 1142: INSERT command denied to user 'ana.santos'@'localhost' for table 'quiz_results | Fails: 42501 | **PASS** – error 42501: permission denied for table quiz_results |
| RB-S07 | Student cannot execute admin procedures | ana.santos | Fails: 1370 | **PASS** – error 1370: execute command denied to user 'ana.santos'@'localhost' for routine 'studync_d | Fails: 42501 | **PASS** – error 42501: permission denied for procedure sp_create_subject |
| RB-S08 | Student cannot execute instructor procedures | ana.santos | Fails: 1370 | **PASS** – error 1370: execute command denied to user 'ana.santos'@'localhost' for routine 'studync_d | Fails: 42501 | **PASS** – error 42501: permission denied for procedure sp_upload_material |
| RB-S09 | Student cannot read the audit trail | ana.santos | Fails: 1142 | **PASS** – error 1142: SELECT command denied to user 'ana.santos'@'localhost' for table 'v_audit_trai | Fails: 42501 | **PASS** – error 42501: permission denied for view v_audit_trail |
| RB-S10 | Student cannot delete audit logs | ana.santos | Fails: 1142 | **PASS** – error 1142: DELETE command denied to user 'ana.santos'@'localhost' for table 'audit_logs' | Fails: 42501 | **PASS** – error 42501: permission denied for table audit_logs |
| RB-S11 | Personal login cannot impersonate another student | ana.santos | Fails: may only act a | **PASS** – error 1644: ACCESS DENIED: a personal database login may only act as its own user | Fails: may only act as its own  | **PASS** – error 42501: ACCESS DENIED: a personal database login may only act as its own user |
| RB-S12 | Student answers Big-O quiz Q14 | ana.santos | Succeeds | **PASS** | Succeeds | **PASS** |
| RB-S13 | Student answers Big-O quiz Q15 | ana.santos | Succeeds | **PASS** | Succeeds | **PASS** |
| RB-S14 | Student answers Big-O quiz Q16 | ana.santos | Succeeds | **PASS** | Succeeds | **PASS** |
| RB-S15 | Student submits the quiz | ana.santos | Succeeds | **PASS** | Succeeds | **PASS** |
| RB-S16 | Student sees own new score 66.67 | ana.santos | Condition true | **PASS** – score=66.67 | Condition true | **PASS** – score=66.67 |
| RB-S17 | v_my_results shows only this student's 4 results | ana.santos | Condition true | **PASS** – 4 rows | Condition true | **PASS** – 4 rows |
| RB-S18 | MySQL: Student calls own results procedure · PostgreSQL: Student calls own results function | ana.santos | Succeeds | **PASS** | Succeeds | **PASS** |
| RB-I01 | Instructor uploads a material | jose.cruz | Succeeds | **PASS** | Succeeds | **PASS** |
| RB-I02 | Instructor reads the answer-key view | jose.cruz | Succeeds | **PASS** | Succeeds | **PASS** |
| RB-I03 | Instructor reads quiz results | jose.cruz | Succeeds | **PASS** | Succeeds | **PASS** |
| RB-I04 | Instructor cannot read users table | jose.cruz | Fails: 1142 | **PASS** – error 1142: SELECT command denied to user 'jose.cruz'@'localhost' for table 'users' | Fails: 42501 | **PASS** – error 42501: permission denied for table users |
| RB-I05 | Instructor cannot register students | jose.cruz | Fails: 1370 | **PASS** – error 1370: execute command denied to user 'jose.cruz'@'localhost' for routine 'studync_db | Fails: 42501 | **PASS** – error 42501: permission denied for procedure sp_register_student |
| RB-I06 | Instructor cannot create subjects | jose.cruz | Fails: 1370 | **PASS** – error 1370: execute command denied to user 'jose.cruz'@'localhost' for routine 'studync_db | Fails: 42501 | **PASS** – error 42501: permission denied for procedure sp_create_subject |
| RB-I07 | Instructor cannot read the audit trail | jose.cruz | Fails: 1142 | **PASS** – error 1142: SELECT command denied to user 'jose.cruz'@'localhost' for table 'v_audit_trail | Fails: 42501 | **PASS** – error 42501: permission denied for view v_audit_trail |
| RB-I08 | Instructor cannot submit answers | jose.cruz | Fails: 1370 | **PASS** – error 1370: execute command denied to user 'jose.cruz'@'localhost' for routine 'studync_db | Fails: 42501 | **PASS** – error 42501: permission denied for procedure sp_submit_answer |
| RB-I09 | Instructor cannot update materials table directly | jose.cruz | Fails: 1142 | **PASS** – error 1142: UPDATE command denied to user 'jose.cruz'@'localhost' for table 'materials' | Fails: 42501 | **PASS** – error 42501: permission denied for table materials |
| RB-I10 | Personal login cannot act as another instructor | jose.cruz | Fails: may only act a | **PASS** – error 1644: ACCESS DENIED: a personal database login may only act as its own user | Fails: may only act as its own  | **PASS** – error 42501: ACCESS DENIED: a personal database login may only act as its own user |
| RB-A01 | Admin reads the user directory (no password hashes) | maria.reyes | Succeeds | **PASS** | Succeeds | **PASS** |
| RB-A02 | Admin reads the audit trail | maria.reyes | Succeeds | **PASS** | Succeeds | **PASS** |
| RB-A03 | Admin creates a subject | maria.reyes | Succeeds | **PASS** | Succeeds | **PASS** |
| RB-A04 | Admin cannot read password hashes from users table | maria.reyes | Fails: 1142 | **PASS** – error 1142: SELECT command denied to user 'maria.reyes'@'localhost' for table 'users' | Fails: 42501 | **PASS** – error 42501: permission denied for table users |
| RB-A05 | Admin cannot delete audit logs | maria.reyes | Fails: 1142 | **PASS** – error 1142: DELETE command denied to user 'maria.reyes'@'localhost' for table 'audit_logs' | Fails: 42501 | **PASS** – error 42501: permission denied for table audit_logs |
| RB-A06 | Admin cannot upload materials (instructor function) | maria.reyes | Fails: 1370 | **PASS** – error 1370: execute command denied to user 'maria.reyes'@'localhost' for routine 'studync_ | Fails: 42501 | **PASS** – error 42501: permission denied for procedure sp_upload_material |
| RB-A07 | Admin cannot submit answers (student function) | maria.reyes | Fails: 1370 | **PASS** – error 1370: execute command denied to user 'maria.reyes'@'localhost' for routine 'studync_ | Fails: 42501 | **PASS** – error 42501: permission denied for procedure sp_submit_answer |
| RB-A08 | Admin cannot call internal helper procedures | maria.reyes | Fails: 1370 | **PASS** – error 1370: execute command denied to user 'maria.reyes'@'localhost' for routine 'studync_ | Fails: 42501 | **PASS** – error 42501: permission denied for procedure sp_set_actor |
| RB-A09 | v_user_directory exposes no password_hash column | maria.reyes | Condition true | **PASS** | Condition true | **PASS** |
| RB-P01 | Shared student account cannot call admin procedures even with an admin id | studync_app_student | Fails: 1370 | **PASS** – error 1370: execute command denied to user 'studync_app_student'@'localhost' for routine ' | Fails: 42501 | **PASS** – error 42501: permission denied for procedure sp_create_subject |
| RB-P02 | Shared student account passing an instructor id is still blocked by role check | studync_app_student | Fails: ACCESS DENIED | **PASS** – error 1644: ACCESS DENIED: this operation requires role(s) Student | Fails: ACCESS DENIED | **PASS** – error 42501: ACCESS DENIED: this operation requires role(s) Student |
| RB-P03 | Shared student account retrieves results for the authenticated student | studync_app_student | Succeeds | **PASS** | Succeeds | **PASS** |
| RB-P04 | Row-filtered view returns nothing for a non-personal login | studync_app_student | Condition true | **PASS** | Condition true | **PASS** |

## 11. GRANT / REVOKE

| Id | Test | Run as | Expected (MySQL) | MySQL result | Expected (PostgreSQL) | PostgreSQL result |
|---|---|---|---|---|---|---|
| GR-01 | After GRANT, ben.torres can read v_audit_trail | ben.torres | Succeeds | **PASS** | Succeeds | **PASS** |
| GR-02 | After REVOKE, ben.torres is denied again | ben.torres | Fails: 1142 | **PASS** – error 1142: SELECT command denied to user 'ben.torres'@'localhost' for table 'v_audit_trai | Fails: 42501 | **PASS** – error 42501: permission denied for view v_audit_trail |

## 2. Constraints, foreign keys, business-rule triggers

| Id | Test | Run as | Expected (MySQL) | MySQL result | Expected (PostgreSQL) | PostgreSQL result |
|---|---|---|---|---|---|---|
| CON-17 | Trigger: TRUNCATE audit_logs blocked, even for superuser (PostgreSQL only) | postgres | n/a (PostgreSQL only) | n/a | Fails: append-only | **PASS** – error P0001: audit_logs is append-only: TRUNCATE is not allowed |
