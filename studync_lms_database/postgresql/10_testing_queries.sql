-- =============================================================================
-- StudyNC LMS (PostgreSQL 16+)
-- File 10 : Testing queries (self-checking test suite)
-- Run as  : superuser connected to studync_db (psql or pgAdmin Query Tool)
-- -----------------------------------------------------------------------------
-- PRE-CONDITION: fresh build (files 01-09). Tests change data, so rebuild
-- before running this file again.
--
-- HOW IT WORKS
--   * Functions in schema studync_test record each test in
--     studync_test.results (PASS/FAIL + the login that ran it):
--       tst_expect_ok   (id, description, sql)
--       tst_expect_error(id, description, sql, expected)
--            expected = a 5-character SQLSTATE (e.g. '42501') or a fragment
--                       of the expected error message
--       tst_check_true  (id, description, condition, detail)
--     They are SECURITY INVOKER, and each statement runs inside its own
--     exception block (sub-transaction), so a failing statement is rolled
--     back and the script continues.
--   * Role-based tests switch identity with
--         SET SESSION AUTHORIZATION "ana.santos";   ...   RESET SESSION AUTHORIZATION;
--     which changes session_user exactly as a real login would (PostgreSQL
--     can do this inside one script; MySQL needs separate connections).
--   * Test ids match the MySQL suite one-to-one, plus CON-17 (TRUNCATE
--     trigger), which has no MySQL equivalent.
--   * Final section prints the summary. Expected result: 0 FAIL.
--
-- SQLSTATEs used: 42501 insufficient_privilege (GRANT missing or ACCESS DENIED)
--                 23503 foreign_key_violation, 23505 unique_violation,
--                 23514 check_violation, 23502 not_null_violation,
--                 P0001 raise_exception (business rule)
-- =============================================================================
SET search_path = studync, pg_temp;

-- #############################################################################
-- SECTION 0 : test harness
-- #############################################################################
DROP SCHEMA IF EXISTS studync_test CASCADE;
CREATE SCHEMA studync_test;

CREATE TABLE studync_test.results (
    seq          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    test_id      VARCHAR(12)  NOT NULL,
    description  VARCHAR(255) NOT NULL,
    expected     VARCHAR(30)  NOT NULL,
    outcome      VARCHAR(4)   NOT NULL CHECK (outcome IN ('PASS','FAIL')),
    detail       TEXT,
    run_as       VARCHAR(100) NOT NULL DEFAULT session_user,
    run_at       TIMESTAMPTZ  NOT NULL DEFAULT clock_timestamp()
);

CREATE FUNCTION studync_test.tst_expect_ok(p_id TEXT, p_desc TEXT, p_sql TEXT)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
    v_state TEXT; v_msg TEXT; v_outcome TEXT; v_detail TEXT;
BEGIN
    BEGIN
        EXECUTE p_sql;
        v_outcome := 'PASS'; v_detail := 'succeeded';
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        v_outcome := 'FAIL'; v_detail := 'error ' || v_state || ': ' || v_msg;
    END;
    INSERT INTO studync_test.results (test_id, description, expected, outcome, detail)
    VALUES (p_id, p_desc, 'SUCCESS', v_outcome, v_detail);
    RETURN rpad(p_id, 8) || ' ' || v_outcome || '  ' || p_desc || '  [' || v_detail || ']';
END $$;

CREATE FUNCTION studync_test.tst_expect_error(p_id TEXT, p_desc TEXT, p_sql TEXT, p_expected TEXT)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
    v_state TEXT; v_msg TEXT; v_pass BOOLEAN := FALSE; v_detail TEXT;
BEGIN
    BEGIN
        EXECUTE p_sql;
        v_detail := 'statement unexpectedly succeeded';
        RAISE EXCEPTION USING ERRCODE = 'ZZ999';        -- undo the unexpected change
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        IF v_state <> 'ZZ999' THEN
            v_detail := 'error ' || v_state || ': ' || v_msg;
            v_pass := p_expected IS NULL
                   OR (p_expected ~ '^[0-9A-Z]{5}$' AND v_state = p_expected)
                   OR (p_expected !~ '^[0-9A-Z]{5}$' AND strpos(v_msg, p_expected) > 0);
        END IF;
    END;
    INSERT INTO studync_test.results (test_id, description, expected, outcome, detail)
    VALUES (p_id, p_desc, 'ERROR ' || left(coalesce(p_expected, 'any'), 24),
            CASE WHEN v_pass THEN 'PASS' ELSE 'FAIL' END, v_detail);
    RETURN rpad(p_id, 8) || ' ' || CASE WHEN v_pass THEN 'PASS' ELSE 'FAIL' END || '  ' || p_desc || '  [' || v_detail || ']';
END $$;

CREATE FUNCTION studync_test.tst_check_true(p_id TEXT, p_desc TEXT, p_condition BOOLEAN, p_detail TEXT DEFAULT NULL)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE v_outcome TEXT := CASE WHEN coalesce(p_condition, FALSE) THEN 'PASS' ELSE 'FAIL' END;
BEGIN
    INSERT INTO studync_test.results (test_id, description, expected, outcome, detail)
    VALUES (p_id, p_desc, 'TRUE', v_outcome, p_detail);
    RETURN rpad(p_id, 8) || ' ' || v_outcome || '  ' || p_desc || coalesce('  [' || p_detail || ']', '');
END $$;

GRANT USAGE ON SCHEMA studync_test TO "ana.santos", "ben.torres", "jose.cruz", "maria.reyes", studync_app_student, studync_dba;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA studync_test TO "ana.santos", "ben.torres", "jose.cruz", "maria.reyes", studync_app_student, studync_dba;
GRANT INSERT ON studync_test.results TO "ana.santos", "ben.torres", "jose.cruz", "maria.reyes", studync_app_student, studync_dba;

-- short aliases for readability in this file
CREATE FUNCTION pg_temp.ok(a TEXT, b TEXT, c TEXT)           RETURNS TEXT LANGUAGE sql AS $$ SELECT studync_test.tst_expect_ok(a, b, c) $$;
CREATE FUNCTION pg_temp.err(a TEXT, b TEXT, c TEXT, d TEXT)  RETURNS TEXT LANGUAGE sql AS $$ SELECT studync_test.tst_expect_error(a, b, c, d) $$;
CREATE FUNCTION pg_temp.chk(a TEXT, b TEXT, c BOOLEAN, d TEXT DEFAULT NULL) RETURNS TEXT LANGUAGE sql AS $$ SELECT studync_test.tst_check_true(a, b, c, d) $$;

-- #############################################################################
-- SECTION 1 : database and table creation
-- #############################################################################
SELECT pg_temp.chk('STR-01', 'Database studync_db exists', (SELECT count(*) FROM pg_database WHERE datname = 'studync_db') = 1);
SELECT pg_temp.chk('STR-02', 'All 13 ERD tables exist',
       (SELECT count(*) FROM information_schema.tables WHERE table_schema = 'studync' AND table_type = 'BASE TABLE') = 13,
       (SELECT string_agg(table_name, ',') FROM information_schema.tables WHERE table_schema = 'studync' AND table_type = 'BASE TABLE'));
SELECT pg_temp.chk('STR-03', '14 foreign keys defined',
       (SELECT count(*) FROM pg_constraint WHERE connamespace = 'studync'::regnamespace AND contype = 'f') = 14,
       (SELECT count(*) || ' FKs' FROM pg_constraint WHERE connamespace = 'studync'::regnamespace AND contype = 'f'));
SELECT pg_temp.chk('STR-04', '10 views defined', (SELECT count(*) FROM information_schema.views WHERE table_schema = 'studync') = 10);
SELECT pg_temp.chk('STR-05', 'Procedures and functions exist (>=27 procedures / >=20 fn_ functions)',
       (SELECT count(*) FROM pg_proc WHERE pronamespace = 'studync'::regnamespace AND prokind = 'p') >= 27
   AND (SELECT count(*) FROM pg_proc WHERE pronamespace = 'studync'::regnamespace AND prokind = 'f' AND proname LIKE 'fn\_%' AND proname NOT LIKE 'fn\_trg%' AND proname <> 'fn_audit_row') >= 20,
       (SELECT string_agg(prokind::text || ':' || c, ' ') FROM (SELECT prokind, count(*) c FROM pg_proc WHERE pronamespace = 'studync'::regnamespace GROUP BY prokind) x));
SELECT pg_temp.chk('STR-06', '41 triggers (36 audit + 5 business rule)',
       (SELECT count(*) FROM pg_trigger WHERE NOT tgisinternal AND tgrelid IN (SELECT oid FROM pg_class WHERE relnamespace = 'studync'::regnamespace)) = 41,
       (SELECT count(*) || ' triggers' FROM pg_trigger WHERE NOT tgisinternal AND tgrelid IN (SELECT oid FROM pg_class WHERE relnamespace = 'studync'::regnamespace)));
SELECT pg_temp.chk('STR-07', 'Sample data loaded (12 users, 19 questions, 12 results)',
       (SELECT count(*) FROM users) = 12 AND (SELECT count(*) FROM questions) = 19 AND (SELECT count(*) FROM quiz_results) = 12);

-- #############################################################################
-- SECTION 2 : constraints, foreign keys and business-rule triggers (as superuser)
-- #############################################################################
SELECT pg_temp.err('CON-01', 'FK: material for a non-existent subject is rejected',
       $q$INSERT INTO materials (subject_id, instructor_id, title, file_path) VALUES ('SUB9999999','INS0000001','x','x.pdf')$q$, '23503');
SELECT pg_temp.err('CON-02', 'FK: deleting a subject that has materials is rejected (no orphans)',
       $q$DELETE FROM subjects WHERE subject_id = 'SUB0000001'$q$, '23503');
SELECT pg_temp.err('CON-03', 'FK: deleting a quiz that has questions is rejected',
       $q$DELETE FROM quizzes WHERE quiz_id = 'QUZ0000001'$q$, '23503');
SELECT pg_temp.err('CON-04', 'CHECK: correct_answer must be one of the options',
       $q$INSERT INTO questions (quiz_id, question_text, correct_answer, option_a, option_b, option_c, option_d) VALUES ('QUZ0000005','Q?','Z','A1','B1','C1','D1')$q$, '23514');
SELECT pg_temp.err('CON-05', 'UNIQUE: duplicate username rejected (case-insensitive)',
       $q$INSERT INTO users (user_id, username, email, password_hash) VALUES ('USR0000999','Ana.Santos','x@y.com', repeat('a',64))$q$, '23505');
SELECT pg_temp.err('CON-06', 'CHECK: invalid email format rejected',
       $q$INSERT INTO users (user_id, username, email, password_hash) VALUES ('USR0000999','zed.user','not-an-email', repeat('a',64))$q$, '23514');
SELECT pg_temp.err('CON-07', 'CHECK: badly formatted primary key rejected',
       $q$INSERT INTO subjects (subject_id, subject_name) VALUES ('S1','Bad Id Subject')$q$, '23514');
SELECT pg_temp.err('CON-08', 'NOT NULL: material without file_path rejected',
       $q$INSERT INTO materials (subject_id, instructor_id, title) VALUES ('SUB0000001','INS0000001','No path')$q$, '23502');
SELECT pg_temp.err('CON-09', 'UNIQUE: second result for same student and quiz rejected',
       $q$INSERT INTO quiz_results (student_id, quiz_id) VALUES ('STU0000001','QUZ0000001')$q$, '23505');
SELECT pg_temp.err('CON-10', 'Trigger: answers are locked after the quiz is submitted',
       $q$INSERT INTO student_answers (student_id, question_id, student_answer) VALUES ('STU0000004','QST0000005','Least privilege')$q$, 'answers are locked');
SELECT pg_temp.err('CON-11', 'Trigger: student answers cannot be modified',
       $q$UPDATE student_answers SET student_answer = 'GRANT' WHERE answer_id = 'ANS0000002'$q$, 'cannot be modified');
SELECT pg_temp.err('CON-12', 'Trigger: audit_logs is append-only (UPDATE blocked, even for superuser)',
       $q$UPDATE audit_logs SET description = 'tampered' WHERE log_id = 1$q$, 'append-only');
SELECT pg_temp.err('CON-13', 'Trigger: audit_logs is append-only (DELETE blocked, even for superuser)',
       $q$DELETE FROM audit_logs WHERE log_id = 1$q$, 'append-only');
-- PostgreSQL-only extra: TRUNCATE does not fire row triggers, so a statement-
-- level BEFORE TRUNCATE trigger protects the table even from a superuser.
SELECT pg_temp.err('CON-17', 'Trigger: TRUNCATE audit_logs blocked, even for superuser (PostgreSQL only)',
       $q$TRUNCATE audit_logs$q$, 'append-only');
SET SESSION AUTHORIZATION studync_dba;
SELECT studync_test.tst_expect_error('CON-16', 'DBA maintenance account cannot TRUNCATE audit_logs',
       $q$TRUNCATE studync.audit_logs$q$, '42501');
RESET SESSION AUTHORIZATION;
SET search_path = studync, pg_temp;

INSERT INTO student_answers (student_id, question_id, student_answer, is_correct)
VALUES ('STU0000002', 'QST0000017', 'var', TRUE);
SELECT pg_temp.chk('CON-14', 'Trigger ignores a forged is_correct = TRUE for a wrong answer',
       (SELECT NOT is_correct FROM student_answers WHERE student_id = 'STU0000002' AND question_id = 'QST0000017'),
       (SELECT 'stored is_correct = ' || is_correct FROM student_answers WHERE student_id = 'STU0000002' AND question_id = 'QST0000017'));
INSERT INTO quiz_results (student_id, quiz_id, score) VALUES ('STU0000002', 'QUZ0000005', 100);
SELECT pg_temp.chk('CON-15', 'Trigger recomputes a forged score of 100 (0 of 3 correct -> 0.00)',
       (SELECT score FROM quiz_results WHERE student_id = 'STU0000002' AND quiz_id = 'QUZ0000005') = 0.00,
       (SELECT 'stored score = ' || score FROM quiz_results WHERE student_id = 'STU0000002' AND quiz_id = 'QUZ0000005'));
DELETE FROM quiz_results    WHERE student_id = 'STU0000002' AND quiz_id = 'QUZ0000005';
DELETE FROM student_answers WHERE student_id = 'STU0000002' AND question_id = 'QST0000017';

-- #############################################################################
-- SECTION 3 : MODULE 1 - User management
--   USR0000001 maria.reyes (Admin)   USR0000003 jose.cruz (Instructor)
--   USR0000006 ana.santos (Student)  USR0000012 gina.lopez (Inactive)
-- #############################################################################
SELECT pg_temp.ok('USR-01', 'Admin registers a new student',
       $q$CALL sp_register_student('USR0000001','hana.cruz','hana.cruz@studync.edu','Pass#Hana2026','Hana','Cruz', NULL, NULL)$q$);
SELECT pg_temp.chk('USR-02', 'Registration created users + user_roles + students rows',
       EXISTS (SELECT 1 FROM users u JOIN user_roles ur ON ur.user_id = u.user_id AND ur.role_id = 'ROL0000003'
                JOIN students s ON s.user_id = u.user_id WHERE u.username = 'hana.cruz' AND u.user_id = 'USR0000013' AND s.student_id = 'STU0000008'),
       (SELECT user_id FROM users WHERE username = 'hana.cruz'));
SELECT pg_temp.chk('USR-03', 'Password is stored as a bcrypt hash, never in plain text',
       (SELECT password_hash LIKE '$2a$10$%' AND password_hash NOT LIKE '%Pass#Hana2026%' FROM users WHERE username = 'hana.cruz'),
       (SELECT left(password_hash, 12) FROM users WHERE username = 'hana.cruz'));
SELECT pg_temp.chk('USR-04', 'Same password hashed twice gives different hashes (random salt)',
       fn_hash_password('Same#Pass1') <> fn_hash_password('Same#Pass1'));
SELECT pg_temp.ok('USR-05', 'Admin registers a new instructor',
       $q$CALL sp_register_instructor('USR0000001','paolo.lim','paolo.lim@studync.edu','Pass#Paolo2026','Paolo','Lim', NULL, NULL)$q$);
SELECT pg_temp.err('USR-06', 'Duplicate username rejected by procedure',
       $q$CALL sp_register_student('USR0000001','hana.cruz','other@studync.edu','Pass#Hana2026','Hana','Cruz', NULL, NULL)$q$, 'Username already exists');
SELECT pg_temp.err('USR-07', 'Weak password rejected',
       $q$CALL sp_register_student('USR0000001','weak.user','weak@studync.edu','password','Weak','User', NULL, NULL)$q$, 'Weak password');
SELECT pg_temp.err('USR-08', 'Invalid email rejected',
       $q$CALL sp_register_student('USR0000001','bad.mail','bad-mail','Pass#Bad2026','Bad','Mail', NULL, NULL)$q$, 'Invalid email');
SELECT pg_temp.err('USR-09', 'Instructor cannot register users (application role check)',
       $q$CALL sp_register_student('USR0000003','x.user','x@studync.edu','Pass#Xuser2026','X','User', NULL, NULL)$q$, 'ACCESS DENIED');
SELECT pg_temp.err('USR-10', 'Unknown acting user rejected',
       $q$CALL sp_create_subject('USR9999999','Ghost Subject',NULL,NULL)$q$, 'unknown acting user');

DO $$
DECLARE ok BOOLEAN; uid VARCHAR; roles VARCHAR; msg VARCHAR;
BEGIN
    CALL sp_authenticate_user('hana.cruz', 'Pass#Hana2026', ok, uid, roles, msg);
    PERFORM pg_temp.chk('USR-11', 'Authentication succeeds with the correct password',
            ok AND uid = 'USR0000013' AND roles = 'Student', concat_ws(' | ', ok, uid, roles, msg));
    CALL sp_authenticate_user('hana.cruz', 'Wrong#Pass1', ok, uid, roles, msg);
    PERFORM pg_temp.chk('USR-12', 'Authentication fails with a wrong password (generic message)',
            NOT ok AND uid IS NULL AND msg = 'Invalid username or password', concat_ws(' | ', ok, msg));
    CALL sp_authenticate_user('gina.lopez', 'Pass#Gina2026', ok, uid, roles, msg);
    PERFORM pg_temp.chk('USR-13', 'Inactive account cannot log in', NOT ok, concat_ws(' | ', ok, msg));
END $$;
SELECT pg_temp.chk('USR-14', 'Failed logins are written to the audit log',
       (SELECT count(*) FROM audit_logs WHERE action_type = 'LOGIN_FAILED' AND record_id = 'USR0000013') = 1);

SELECT pg_temp.ok('USR-15', 'Admin updates user email and name',
       $q$CALL sp_update_user('USR0000001','USR0000013','Hana.Cruz2@studync.edu','Hannah',NULL)$q$);
SELECT pg_temp.chk('USR-16', 'Update stored (email lower-cased, first name changed)',
       (SELECT email FROM users WHERE user_id = 'USR0000013') = 'hana.cruz2@studync.edu'
       AND (SELECT first_name FROM students WHERE user_id = 'USR0000013') = 'Hannah');
SELECT pg_temp.ok('USR-17', 'Admin assigns the Instructor role to a student (profile auto-created)',
       $q$CALL sp_assign_role('USR0000001','USR0000013','Instructor')$q$);
SELECT pg_temp.chk('USR-18', 'Role assignment created user_roles + instructors rows',
       fn_user_has_role('USR0000013','Instructor') AND fn_get_instructor_id('USR0000013') IS NOT NULL);
SELECT pg_temp.ok('USR-19', 'Admin revokes the Instructor role again', $q$CALL sp_revoke_role('USR0000001','USR0000013','Instructor')$q$);
SELECT pg_temp.err('USR-20', 'Admin cannot revoke own Administrator role',
       $q$CALL sp_revoke_role('USR0000001','USR0000001','Administrator')$q$, 'cannot revoke their own');
SELECT pg_temp.err('USR-21', 'Admin cannot deactivate own account',
       $q$CALL sp_set_user_status('USR0000001','USR0000001','Inactive')$q$, 'own account status');
SELECT pg_temp.err('USR-22', 'Inactive user cannot perform any operation',
       $q$CALL sp_submit_answer('USR0000012','QST0000017','A',NULL)$q$, 'inactive');
SELECT pg_temp.ok('USR-23', 'User changes own password', $q$CALL sp_change_password('USR0000013','Pass#Hana2026','NewPass#2026')$q$);
DO $$
DECLARE ok BOOLEAN; uid VARCHAR; roles VARCHAR; msg VARCHAR;
BEGIN
    CALL sp_authenticate_user('hana.cruz', 'NewPass#2026', ok, uid, roles, msg);
    PERFORM pg_temp.chk('USR-24', 'Login works with the new password', ok, msg);
END $$;
SELECT pg_temp.err('USR-25', 'Password change with wrong current password rejected',
       $q$CALL sp_change_password('USR0000013','bad','Other#2026')$q$, 'Current password is incorrect');
SELECT pg_temp.err('USR-26', 'Student cannot read another user record',
       $q$SELECT * FROM fn_get_user('USR0000006','USR0000001')$q$, 'ACCESS DENIED');

-- #############################################################################
-- SECTION 4 : MODULE 2 - Subject management
-- #############################################################################
SELECT pg_temp.ok('SUB-01', 'Admin creates a subject',
       $q$CALL sp_create_subject('USR0000001','Information Assurance','Security policies and risk management.', NULL)$q$);
SELECT pg_temp.chk('SUB-02', 'New subject stored with generated id',
       (SELECT subject_id FROM subjects WHERE subject_name = 'Information Assurance') = 'SUB0000006',
       (SELECT subject_id FROM subjects WHERE subject_name = 'Information Assurance'));
SELECT pg_temp.err('SUB-03', 'Duplicate subject name rejected',
       $q$CALL sp_create_subject('USR0000001','information assurance',NULL,NULL)$q$, 'already exists');
SELECT pg_temp.ok('SUB-04', 'Admin updates the subject',
       $q$CALL sp_update_subject('USR0000001','SUB0000006',NULL,'Security policies, risk management and compliance.')$q$);
SELECT pg_temp.ok('SUB-05', 'Admin deletes an unused subject', $q$CALL sp_delete_subject('USR0000001','SUB0000005')$q$);
SELECT pg_temp.chk('SUB-06', 'Deleted subject is gone', NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = 'SUB0000005'));
SELECT pg_temp.err('SUB-07', 'Subject that has materials/quizzes cannot be deleted',
       $q$CALL sp_delete_subject('USR0000001','SUB0000001')$q$, 'cannot be deleted');
SELECT pg_temp.err('SUB-08', 'Instructor cannot create subjects',
       $q$CALL sp_create_subject('USR0000003','Hacking 101',NULL,NULL)$q$, 'ACCESS DENIED');
SELECT pg_temp.err('SUB-09', 'Student cannot delete subjects',
       $q$CALL sp_delete_subject('USR0000006','SUB0000006')$q$, 'ACCESS DENIED');

-- #############################################################################
-- SECTION 5 : MODULE 3 - Learning material management
-- #############################################################################
SELECT pg_temp.ok('MAT-01', 'Instructor uploads a material',
       $q$CALL sp_upload_material('USR0000003','SUB0000006','Risk Assessment Primer','materials/sub6/risk-primer.pdf', NULL)$q$);
DO $$
DECLARE m VARCHAR := (SELECT material_id FROM materials WHERE title = 'Risk Assessment Primer');
BEGIN
    PERFORM pg_temp.chk('MAT-02', 'Material linked to subject and uploading instructor',
            (SELECT subject_id || '/' || instructor_id FROM materials WHERE material_id = m) = 'SUB0000006/INS0000001', m);
    PERFORM pg_temp.ok('MAT-03', 'Owner updates the material title',
            format('CALL sp_update_material(%L, %L, NULL, %L, NULL)', 'USR0000003', m, 'Risk Assessment Primer (v2)'));
    PERFORM pg_temp.err('MAT-04', 'Another instructor cannot update it',
            format('CALL sp_update_material(%L, %L, NULL, %L, NULL)', 'USR0000004', m, 'Hijacked'), 'ACCESS DENIED');
    PERFORM pg_temp.err('MAT-05', 'Another instructor cannot delete it',
            format('CALL sp_delete_material(%L, %L)', 'USR0000004', m), 'ACCESS DENIED');
    PERFORM pg_temp.err('MAT-06', 'Path traversal in file_path rejected',
            $q$CALL sp_upload_material('USR0000003','SUB0000006','Bad','../../etc/passwd', NULL)$q$, 'Invalid file path');
    PERFORM pg_temp.err('MAT-07', 'Upload to a non-existent subject rejected',
            $q$CALL sp_upload_material('USR0000003','SUB0000999','X','x.pdf', NULL)$q$, 'Subject not found');
    PERFORM pg_temp.err('MAT-08', 'Student cannot upload materials',
            $q$CALL sp_upload_material('USR0000006','SUB0000006','X','x.pdf', NULL)$q$, 'ACCESS DENIED');
    PERFORM pg_temp.ok('MAT-09', 'Student retrieves the materials of a subject',
            $q$SELECT * FROM fn_get_materials_by_subject('USR0000006','SUB0000001')$q$);
    PERFORM pg_temp.ok('MAT-10', 'Owner deletes the material', format('CALL sp_delete_material(%L, %L)', 'USR0000003', m));
    PERFORM pg_temp.chk('MAT-11', 'Material deleted', NOT EXISTS (SELECT 1 FROM materials WHERE material_id = m));
END $$;

-- #############################################################################
-- SECTION 6 : MODULE 4 - Quiz management
-- #############################################################################
SELECT pg_temp.ok('QUZ-01', 'Instructor creates a quiz',
       $q$CALL sp_create_quiz('USR0000003','SUB0000006','Risk Management Quiz', NULL)$q$);
DO $$
DECLARE
    z  VARCHAR := (SELECT quiz_id FROM quizzes WHERE title = 'Risk Management Quiz');
    q2 VARCHAR; q3 VARCHAR; tq VARCHAR; tq1 VARCHAR;
BEGIN
    PERFORM pg_temp.ok('QUZ-02', 'Instructor adds question 1 (correct answer given as letter)',
            format('CALL sp_add_question(%L,%L,%L,%L,%L,%L,%L,%L,NULL)', 'USR0000003', z, 'Risk = Threat x ?', 'Vulnerability','Firewall','Password','Backup','A'));
    PERFORM pg_temp.ok('QUZ-03', 'Instructor adds question 2 (correct answer given as text)',
            format('CALL sp_add_question(%L,%L,%L,%L,%L,%L,%L,%L,NULL)', 'USR0000003', z, 'Which control is preventive?', 'Audit log','Firewall','CCTV review','Incident report','Firewall'));
    PERFORM pg_temp.chk('QUZ-04', 'Correct answers stored as option text',
            (SELECT string_agg(correct_answer, ',' ORDER BY question_id) FROM questions WHERE quiz_id = z) = 'Vulnerability,Firewall');
    PERFORM pg_temp.err('QUZ-05', 'Question whose correct answer is not an option rejected',
            format('CALL sp_add_question(%L,%L,%L,%L,%L,%L,%L,%L,NULL)', 'USR0000003', z, 'Bad?', 'a1','b1','c1','d1','E'), 'Correct answer must be');
    PERFORM pg_temp.err('QUZ-06', 'Question with duplicate options rejected (CHECK)',
            format('CALL sp_add_question(%L,%L,%L,%L,%L,%L,%L,%L,NULL)', 'USR0000003', z, 'Dup?', 'same','same','c1','d1','A'), '23514');
    q2 := (SELECT question_id FROM questions WHERE question_text = 'Which control is preventive?');
    PERFORM pg_temp.ok('QUZ-07', 'Instructor updates a question',
            format('CALL sp_update_question(%L,%L,%L,NULL,NULL,NULL,NULL,NULL)', 'USR0000003', q2, 'Which control is PREVENTIVE?'));
    PERFORM pg_temp.ok('QUZ-08', 'Instructor adds and deletes a temporary question',
            format('CALL sp_add_question(%L,%L,%L,%L,%L,%L,%L,%L,NULL)', 'USR0000003', z, 'Temp?', 'w','x','y','z','D'));
    q3 := (SELECT question_id FROM questions WHERE question_text = 'Temp?');
    PERFORM pg_temp.ok('QUZ-09', 'Instructor deletes a question', format('CALL sp_delete_question(%L,%L)', 'USR0000003', q3));
    PERFORM pg_temp.ok('QUZ-10', 'Instructor updates the quiz title',
            format('CALL sp_update_quiz(%L,%L,NULL,%L)', 'USR0000003', z, 'Risk Management Quiz 1'));
    PERFORM pg_temp.err('QUZ-11', 'Another instructor cannot modify the quiz',
            format('CALL sp_update_quiz(%L,%L,NULL,%L)', 'USR0000004', z, 'Mine now'), 'ACCESS DENIED');
    PERFORM pg_temp.err('QUZ-12', 'Another instructor cannot add questions to it',
            format('CALL sp_add_question(%L,%L,%L,%L,%L,%L,%L,%L,NULL)', 'USR0000004', z, 'X?', 'a','b','c','d','A'), 'ACCESS DENIED');
    PERFORM pg_temp.err('QUZ-13', 'Quiz with submitted results cannot be deleted',
            $q$CALL sp_delete_quiz('USR0000003','QUZ0000001')$q$, 'cannot be deleted');
    PERFORM pg_temp.err('QUZ-14', 'Answered question cannot be changed',
            $q$CALL sp_update_question('USR0000003','QST0000001','Changed?',NULL,NULL,NULL,NULL,NULL)$q$, 'locked');
    PERFORM pg_temp.err('QUZ-15', 'Student cannot create quizzes',
            $q$CALL sp_create_quiz('USR0000006','SUB0000001','My quiz', NULL)$q$, 'ACCESS DENIED');
    PERFORM pg_temp.ok('QUZ-16', 'Instructor creates and deletes an unused quiz (with a question)',
            $q$CALL sp_create_quiz('USR0000003','SUB0000006','Throwaway Quiz', NULL)$q$);
    tq := (SELECT quiz_id FROM quizzes WHERE title = 'Throwaway Quiz');
    CALL sp_add_question('USR0000003', tq, 'Throwaway?', 'a1','b1','c1','d1','A', tq1);
    PERFORM pg_temp.ok('QUZ-17', 'Delete unused quiz', format('CALL sp_delete_quiz(%L,%L)', 'USR0000003', tq));
    PERFORM pg_temp.chk('QUZ-18', 'Quiz and its questions removed; question deletion audited',
            NOT EXISTS (SELECT 1 FROM quizzes WHERE quiz_id = tq) AND NOT EXISTS (SELECT 1 FROM questions WHERE quiz_id = tq)
            AND EXISTS (SELECT 1 FROM audit_logs WHERE table_name = 'questions' AND action_type = 'DELETE' AND record_id = tq1));
END $$;
SELECT pg_temp.chk('QUZ-19', 'Student question view hides the answer key',
       NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'studync'
                   AND table_name = 'v_quiz_questions_student' AND column_name = 'correct_answer'));

-- #############################################################################
-- SECTION 7 : MODULE 5 - Assessment processing and score calculation
--   ben.torres = USR0000007 / STU0000002 takes QUZ0000005
-- #############################################################################
SELECT pg_temp.ok('ASM-01', 'Student answers Q17 with a letter (correct)', $q$CALL sp_submit_answer('USR0000007','QST0000017','A', NULL)$q$);
SELECT pg_temp.ok('ASM-02', 'Student answers Q18 with option text (correct)', $q$CALL sp_submit_answer('USR0000007','QST0000018','console.log()', NULL)$q$);
SELECT pg_temp.err('ASM-03', 'Answer that is not an option is rejected', $q$CALL sp_submit_answer('USR0000007','QST0000019','E', NULL)$q$, 'Answer must be');
SELECT pg_temp.ok('ASM-04', 'Student answers Q19 (wrong)', $q$CALL sp_submit_answer('USR0000007','QST0000019','Value only', NULL)$q$);
SELECT pg_temp.err('ASM-05', 'Second answer to the same question rejected', $q$CALL sp_submit_answer('USR0000007','QST0000019','B', NULL)$q$, 'already answered');
SELECT pg_temp.chk('ASM-06', 'is_correct computed by the database (t,t,f)',
       (SELECT string_agg(is_correct::text, ',' ORDER BY question_id) FROM student_answers
         WHERE student_id = 'STU0000002' AND question_id IN ('QST0000017','QST0000018','QST0000019')) = 'true,true,false',
       (SELECT string_agg(is_correct::text, ',' ORDER BY question_id) FROM student_answers
         WHERE student_id = 'STU0000002' AND question_id IN ('QST0000017','QST0000018','QST0000019')));
SELECT pg_temp.ok('ASM-07', 'Student submits the quiz', $q$CALL sp_submit_quiz('USR0000007','QUZ0000005', NULL, NULL)$q$);
SELECT pg_temp.chk('ASM-08', 'Score = 2 of 3 correct = 66.67',
       (SELECT score FROM quiz_results WHERE student_id = 'STU0000002' AND quiz_id = 'QUZ0000005') = 66.67,
       (SELECT result_id || ' score=' || score FROM quiz_results WHERE student_id = 'STU0000002' AND quiz_id = 'QUZ0000005'));
SELECT pg_temp.err('ASM-09', 'Quiz cannot be submitted twice', $q$CALL sp_submit_quiz('USR0000007','QUZ0000005', NULL, NULL)$q$, 'already submitted');
SELECT pg_temp.err('ASM-10', 'Submitting a quiz with no answers rejected', $q$CALL sp_submit_quiz('USR0000008','QUZ0000005', NULL, NULL)$q$, 'No answers submitted');
SELECT pg_temp.err('ASM-11', 'Instructor cannot submit answers', $q$CALL sp_submit_answer('USR0000003','QST0000017','A', NULL)$q$, 'ACCESS DENIED');
SELECT pg_temp.chk('ASM-12', 'fn_calculate_quiz_score: partial attempt (4 of 5 answered, 2 correct) = 40.00',
       fn_calculate_quiz_score('STU0000004','QUZ0000001') = 40.00);
SELECT pg_temp.chk('ASM-13', 'Every stored score equals the documented formula',
       (SELECT count(*) FROM quiz_results qr WHERE qr.score <> fn_calculate_quiz_score(qr.student_id, qr.quiz_id)) = 0);
SELECT pg_temp.ok('ASM-14', 'Student retrieves own results', $q$SELECT * FROM fn_get_student_results('USR0000007')$q$);
SELECT pg_temp.err('ASM-15', 'Student cannot retrieve another student''s results',
       $q$SELECT * FROM fn_get_student_results('USR0000007','STU0000001')$q$, 'ACCESS DENIED');
SELECT pg_temp.ok('ASM-16', 'Student reviews own submitted answers', $q$SELECT * FROM fn_get_answer_review('USR0000007','QUZ0000005')$q$);
SELECT pg_temp.err('ASM-17', 'Answer review is not available before submission',
       $q$SELECT * FROM fn_get_answer_review('USR0000006','QUZ0000005')$q$, 'No submitted result');

-- #############################################################################
-- SECTION 8 : MODULE 6 - Reporting and monitoring
-- #############################################################################
SELECT pg_temp.ok('RPT-01', 'Admin: student performance report (all subjects)', $q$SELECT * FROM fn_report_student_performance('USR0000001')$q$);
SELECT pg_temp.ok('RPT-02', 'Instructor: performance report limited to own quizzes', $q$SELECT * FROM fn_report_student_performance('USR0000003')$q$);
SELECT pg_temp.err('RPT-03', 'Student cannot run performance reports', $q$SELECT * FROM fn_report_student_performance('USR0000006')$q$, 'ACCESS DENIED');
SELECT pg_temp.ok('RPT-04', 'Instructor: quiz results report for own quiz', $q$SELECT * FROM fn_report_quiz_results('USR0000003','QUZ0000001')$q$);
SELECT pg_temp.err('RPT-05', 'Instructor: quiz results report for another instructor''s quiz denied',
       $q$SELECT * FROM fn_report_quiz_results('USR0000003','QUZ0000003')$q$, 'ACCESS DENIED');
SELECT pg_temp.ok('RPT-06', 'Admin: audit log report (filter by table)', $q$SELECT * FROM fn_report_audit_logs('USR0000001','subjects',NULL,NULL,NULL,20)$q$);
SELECT pg_temp.err('RPT-07', 'Instructor cannot read audit logs', $q$SELECT * FROM fn_report_audit_logs('USR0000003')$q$, 'ACCESS DENIED');
SELECT pg_temp.ok('RPT-08', 'Admin: system activity summary', $q$SELECT * FROM fn_report_system_activity('USR0000001', 7)$q$);
SELECT pg_temp.chk('RPT-09', 'Performance view: Ana avg of 100,75,75 = 83.33',
       (SELECT average_score FROM v_student_performance WHERE student_id = 'STU0000001') = 83.33,
       (SELECT 'avg=' || average_score FROM v_student_performance WHERE student_id = 'STU0000001'));
SELECT pg_temp.chk('RPT-10', 'Quiz results view: QUZ0000001 has 4 submissions, average 70.00',
       (SELECT count(*) FROM v_quiz_results_detail WHERE quiz_id = 'QUZ0000001') = 4
       AND (SELECT round(avg(score), 2) FROM quiz_results WHERE quiz_id = 'QUZ0000001') = 70.00);

-- #############################################################################
-- SECTION 9 : audit logging
-- #############################################################################
SELECT pg_temp.chk('AUD-01', 'INSERT audited with acting user, record id and new data',
       EXISTS (SELECT 1 FROM audit_logs WHERE table_name = 'subjects' AND action_type = 'INSERT' AND record_id = 'SUB0000006'
               AND performed_by = 'USR0000001' AND new_data ->> 'subject_name' = 'Information Assurance' AND old_data IS NULL));
SELECT pg_temp.chk('AUD-02', 'UPDATE audited with old and new values',
       EXISTS (SELECT 1 FROM audit_logs WHERE table_name = 'subjects' AND action_type = 'UPDATE' AND record_id = 'SUB0000006'
               AND old_data ->> 'description' = 'Security policies and risk management.'
               AND new_data ->> 'description' LIKE '%compliance%'));
SELECT pg_temp.chk('AUD-03', 'DELETE audited with the deleted row in old_data',
       EXISTS (SELECT 1 FROM audit_logs WHERE table_name = 'subjects' AND action_type = 'DELETE' AND record_id = 'SUB0000005'
               AND old_data ->> 'subject_name' = 'Technical Writing' AND new_data IS NULL));
SELECT pg_temp.chk('AUD-04', 'password_hash never appears in the audit trail',
       NOT EXISTS (SELECT 1 FROM audit_logs WHERE coalesce(new_data, '{}') ? 'password_hash' OR coalesce(old_data, '{}') ? 'password_hash'));
SELECT pg_temp.chk('AUD-05', 'Password change logged as a flag only',
       EXISTS (SELECT 1 FROM audit_logs WHERE table_name = 'users' AND action_type = 'UPDATE' AND record_id = 'USR0000013'
               AND (new_data ->> 'password_changed')::boolean));
DO $$
DECLARE b INTEGER; s VARCHAR;
BEGIN
    b := (SELECT count(*) FROM audit_logs);
    CALL sp_create_subject('USR0000001', 'Audit Count Subject', NULL, s);
    PERFORM pg_temp.chk('AUD-06', 'One operation produces exactly one audit row (no duplicates)',
            (SELECT count(*) FROM audit_logs) - b = 1, ((SELECT count(*) FROM audit_logs) - b) || ' new row(s)');
    b := (SELECT count(*) FROM audit_logs);
    CALL sp_update_subject('USR0000001', s, 'Audit Count Subject', NULL);
    PERFORM pg_temp.chk('AUD-07', 'No-op update writes no audit row',
            (SELECT count(*) FROM audit_logs) - b = 0, ((SELECT count(*) FROM audit_logs) - b) || ' new row(s)');
END $$;
SELECT pg_temp.chk('AUD-08', 'Assessment activity audited (answers and results by the student)',
       EXISTS (SELECT 1 FROM audit_logs WHERE table_name = 'quiz_results' AND action_type = 'INSERT' AND performed_by = 'USR0000007'
               AND new_data ->> 'quiz_id' = 'QUZ0000005')
       AND (SELECT count(*) FROM audit_logs WHERE table_name = 'student_answers' AND action_type = 'INSERT' AND performed_by = 'USR0000007'
               AND new_data ->> 'question_id' IN ('QST0000017','QST0000018','QST0000019')) = 3);
SELECT pg_temp.chk('AUD-09', 'Direct DBA changes are audited with db_user and NULL application user',
       EXISTS (SELECT 1 FROM audit_logs WHERE table_name = 'quiz_results' AND action_type = 'DELETE'
               AND old_data ->> 'quiz_id' = 'QUZ0000005' AND performed_by IS NULL AND db_user = 'postgres'));
SELECT pg_temp.chk('AUD-10', 'Session identity setting is cleared after each procedure',
       coalesce(current_setting('studync.app_user_id', true), '') = '');
SELECT pg_temp.chk('AUD-11', 'Failed procedure calls leave no audit rows (rolled back)',
       NOT EXISTS (SELECT 1 FROM audit_logs WHERE table_name = 'subjects' AND new_data ->> 'subject_name' = 'Hacking 101'));

-- #############################################################################
-- SECTION 10 : RBAC - personal STUDENT login (ana.santos = USR0000006)
-- #############################################################################
SET SESSION AUTHORIZATION "ana.santos";
SET search_path = studync, pg_temp;
SELECT studync_test.tst_expect_ok('RB-S01', 'Student can read the student question view',
       $q$SELECT question_id, question_text, option_a FROM v_quiz_questions_student WHERE quiz_id = 'QUZ0000004'$q$);
SELECT studync_test.tst_expect_ok('RB-S02', 'Student can read learning materials', $q$SELECT * FROM v_learning_materials$q$);
SELECT studync_test.tst_expect_error('RB-S03', 'Student cannot read the users table (password hashes)', $q$SELECT * FROM users$q$, '42501');
SELECT studync_test.tst_expect_error('RB-S04', 'Student cannot read the answer key view', $q$SELECT correct_answer FROM v_quiz_questions_instructor$q$, '42501');
SELECT studync_test.tst_expect_error('RB-S05', 'Student cannot read the questions table directly', $q$SELECT correct_answer FROM questions$q$, '42501');
SELECT studync_test.tst_expect_error('RB-S06', 'Student cannot insert a result directly',
       $q$INSERT INTO quiz_results (student_id, quiz_id, score) VALUES ('STU0000001','QUZ0000004',100)$q$, '42501');
SELECT studync_test.tst_expect_error('RB-S07', 'Student cannot execute admin procedures',
       $q$CALL sp_create_subject('USR0000001','Student Subject',NULL,NULL)$q$, '42501');
SELECT studync_test.tst_expect_error('RB-S08', 'Student cannot execute instructor procedures',
       $q$CALL sp_upload_material('USR0000003','SUB0000001','x','x.pdf',NULL)$q$, '42501');
SELECT studync_test.tst_expect_error('RB-S09', 'Student cannot read the audit trail', $q$SELECT * FROM v_audit_trail$q$, '42501');
SELECT studync_test.tst_expect_error('RB-S10', 'Student cannot delete audit logs', $q$DELETE FROM audit_logs$q$, '42501');
SELECT studync_test.tst_expect_error('RB-S11', 'Personal login cannot impersonate another student',
       $q$CALL sp_submit_answer('USR0000007','QST0000014','A',NULL)$q$, 'may only act as its own user');
SELECT studync_test.tst_expect_ok('RB-S12', 'Student answers Big-O quiz Q14', $q$CALL sp_submit_answer('USR0000006','QST0000014','B',NULL)$q$);
SELECT studync_test.tst_expect_ok('RB-S13', 'Student answers Big-O quiz Q15', $q$CALL sp_submit_answer('USR0000006','QST0000015','A',NULL)$q$);
SELECT studync_test.tst_expect_ok('RB-S14', 'Student answers Big-O quiz Q16', $q$CALL sp_submit_answer('USR0000006','QST0000016','A',NULL)$q$);
SELECT studync_test.tst_expect_ok('RB-S15', 'Student submits the quiz', $q$CALL sp_submit_quiz('USR0000006','QUZ0000004',NULL,NULL)$q$);
SELECT studync_test.tst_check_true('RB-S16', 'Student sees own new score 66.67',
       (SELECT score FROM v_my_results WHERE quiz_id = 'QUZ0000004') = 66.67,
       (SELECT 'score=' || score FROM v_my_results WHERE quiz_id = 'QUZ0000004'));
SELECT studync_test.tst_check_true('RB-S17', 'v_my_results shows only this student''s 4 results',
       (SELECT count(*) FROM v_my_results) = 4, (SELECT count(*) || ' rows' FROM v_my_results));
SELECT studync_test.tst_expect_ok('RB-S18', 'Student calls own results function', $q$SELECT * FROM fn_get_student_results('USR0000006')$q$);
RESET SESSION AUTHORIZATION;

-- #############################################################################
-- SECTION 11 : RBAC - personal INSTRUCTOR login (jose.cruz = USR0000003)
-- #############################################################################
SET SESSION AUTHORIZATION "jose.cruz";
SET search_path = studync, pg_temp;
SELECT studync_test.tst_expect_ok('RB-I01', 'Instructor uploads a material', $q$CALL sp_upload_material('USR0000003','SUB0000001','Backup Strategies','materials/sub1/backup.pdf',NULL)$q$);
SELECT studync_test.tst_expect_ok('RB-I02', 'Instructor reads the answer-key view', $q$SELECT question_id, correct_answer FROM v_quiz_questions_instructor WHERE instructor_id = 'INS0000001'$q$);
SELECT studync_test.tst_expect_ok('RB-I03', 'Instructor reads quiz results', $q$SELECT * FROM v_quiz_results_detail WHERE instructor_id = 'INS0000001'$q$);
SELECT studync_test.tst_expect_error('RB-I04', 'Instructor cannot read users table', $q$SELECT * FROM users$q$, '42501');
SELECT studync_test.tst_expect_error('RB-I05', 'Instructor cannot register students', $q$CALL sp_register_student('USR0000001','i.x','ix@studync.edu','Pass#Ix2026','I','X',NULL,NULL)$q$, '42501');
SELECT studync_test.tst_expect_error('RB-I06', 'Instructor cannot create subjects', $q$CALL sp_create_subject('USR0000001','X',NULL,NULL)$q$, '42501');
SELECT studync_test.tst_expect_error('RB-I07', 'Instructor cannot read the audit trail', $q$SELECT * FROM v_audit_trail$q$, '42501');
SELECT studync_test.tst_expect_error('RB-I08', 'Instructor cannot submit answers', $q$CALL sp_submit_answer('USR0000003','QST0000001','A',NULL)$q$, '42501');
SELECT studync_test.tst_expect_error('RB-I09', 'Instructor cannot update materials table directly', $q$UPDATE materials SET title = 'x'$q$, '42501');
SELECT studync_test.tst_expect_error('RB-I10', 'Personal login cannot act as another instructor',
       $q$CALL sp_upload_material('USR0000004','SUB0000002','x','x.pdf',NULL)$q$, 'may only act as its own user');
RESET SESSION AUTHORIZATION;

-- #############################################################################
-- SECTION 12 : RBAC - personal ADMINISTRATOR login (maria.reyes = USR0000001)
-- #############################################################################
SET SESSION AUTHORIZATION "maria.reyes";
SET search_path = studync, pg_temp;
SELECT studync_test.tst_expect_ok('RB-A01', 'Admin reads the user directory (no password hashes)', $q$SELECT * FROM v_user_directory$q$);
SELECT studync_test.tst_expect_ok('RB-A02', 'Admin reads the audit trail', $q$SELECT * FROM v_audit_trail ORDER BY log_id DESC LIMIT 5$q$);
SELECT studync_test.tst_expect_ok('RB-A03', 'Admin creates a subject', $q$CALL sp_create_subject('USR0000001','Cloud Computing',NULL,NULL)$q$);
SELECT studync_test.tst_expect_error('RB-A04', 'Admin cannot read password hashes from users table', $q$SELECT password_hash FROM users$q$, '42501');
SELECT studync_test.tst_expect_error('RB-A05', 'Admin cannot delete audit logs', $q$DELETE FROM audit_logs$q$, '42501');
SELECT studync_test.tst_expect_error('RB-A06', 'Admin cannot upload materials (instructor function)', $q$CALL sp_upload_material('USR0000001','SUB0000001','x','x.pdf',NULL)$q$, '42501');
SELECT studync_test.tst_expect_error('RB-A07', 'Admin cannot submit answers (student function)', $q$CALL sp_submit_answer('USR0000001','QST0000001','A',NULL)$q$, '42501');
SELECT studync_test.tst_expect_error('RB-A08', 'Admin cannot call internal helper procedures', $q$CALL sp_set_actor('USR0000001','Administrator')$q$, '42501');
SELECT studync_test.tst_check_true('RB-A09', 'v_user_directory exposes no password_hash column',
       NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'studync'
                   AND table_name = 'v_user_directory' AND column_name = 'password_hash'));
RESET SESSION AUTHORIZATION;

-- #############################################################################
-- SECTION 13 : RBAC - shared application account for students
-- #############################################################################
SET SESSION AUTHORIZATION studync_app_student;
SET search_path = studync, pg_temp;
SELECT studync_test.tst_expect_error('RB-P01', 'Shared student account cannot call admin procedures even with an admin id',
       $q$CALL sp_create_subject('USR0000001','Escalation',NULL,NULL)$q$, '42501');
SELECT studync_test.tst_expect_error('RB-P02', 'Shared student account passing an instructor id is still blocked by role check',
       $q$CALL sp_submit_answer('USR0000003','QST0000001','A',NULL)$q$, 'ACCESS DENIED');
SELECT studync_test.tst_expect_ok('RB-P03', 'Shared student account retrieves results for the authenticated student',
       $q$SELECT * FROM fn_get_student_results('USR0000008')$q$);
SELECT studync_test.tst_check_true('RB-P04', 'Row-filtered view returns nothing for a non-personal login',
       (SELECT count(*) FROM v_my_results) = 0);
RESET SESSION AUTHORIZATION;

-- #############################################################################
-- SECTION 14 : GRANT / REVOKE demonstration
-- #############################################################################
GRANT SELECT ON studync.v_audit_trail TO "ben.torres";
SET SESSION AUTHORIZATION "ben.torres";
SET search_path = studync, pg_temp;
SELECT studync_test.tst_expect_ok('GR-01', 'After GRANT, ben.torres can read v_audit_trail', $q$SELECT count(*) FROM v_audit_trail$q$);
RESET SESSION AUTHORIZATION;
REVOKE SELECT ON studync.v_audit_trail FROM "ben.torres";
SET SESSION AUTHORIZATION "ben.torres";
SET search_path = studync, pg_temp;
SELECT studync_test.tst_expect_error('GR-02', 'After REVOKE, ben.torres is denied again', $q$SELECT count(*) FROM v_audit_trail$q$, '42501');
RESET SESSION AUTHORIZATION;
SET search_path = studync, pg_temp;

-- #############################################################################
-- SECTION 15 : SUMMARY (expected: every test PASS, 0 FAIL)
-- #############################################################################
SELECT outcome, count(*) AS tests FROM studync_test.results GROUP BY outcome;
SELECT test_id, description, run_as, detail FROM studync_test.results WHERE outcome = 'FAIL' ORDER BY seq;
SELECT split_part(test_id, '-', 1) AS area, count(*) AS tests,
       count(*) FILTER (WHERE outcome = 'PASS') AS passed, count(*) FILTER (WHERE outcome = 'FAIL') AS failed
FROM studync_test.results GROUP BY 1 ORDER BY min(seq);
