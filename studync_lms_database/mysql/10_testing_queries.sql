-- =============================================================================
-- StudyNC LMS (MySQL 8.0+)
-- File 10 : Testing queries (self-checking test suite)
-- -----------------------------------------------------------------------------
-- PRE-CONDITION : run on a FRESH build (files 01-09). The tests change data,
--                 so rebuild with 01-09 before running this file again.
--
-- HOW IT WORKS
--   * Temporary helper procedures studync_db.tst_* record every test as
--     PASS/FAIL in studync_test.results with the MySQL account that ran it.
--     (They must live in studync_db because MySQL resolves unqualified names
--     in dynamic SQL against the routine's own schema. They are dropped at
--     the end of this file.)
--       expect_ok   (id, description, sql)            -> PASS if no error
--       expect_error(id, description, sql, expected)  -> PASS if it fails with
--                    the expected MySQL error number (e.g. '1142') or with an
--                    error message containing the expected text
--       check_true  (id, description, condition, detail)
--     The helpers are SQL SECURITY INVOKER, so the tested statement runs with
--     the privileges of the account executing the test - exactly what is
--     needed to prove role-based restrictions.
--   * Lines "-- @as <account>" start a section that must run while connected
--     as that MySQL account:
--       - command line : tests/run_mysql_tests.sh runs every section with the
--                        right account automatically
--       - Workbench    : open a connection as that account (passwords in
--                        file 08) and execute the section
--   * The final section prints the summary. Expected result: 0 FAIL.
--
-- Error numbers used:  1142 = command denied on table/view
--                      1370 = execute command denied on routine
--                      1451/1452 = foreign key violation (parent/child)
--                      1062 = duplicate key, 3819 = CHECK constraint violated
--                      1644 = SIGNAL raised by a procedure / trigger
-- =============================================================================

-- @as root
-- #############################################################################
-- SECTION 0 : test harness (run as root / DBA)
-- #############################################################################
DROP DATABASE IF EXISTS studync_test;
CREATE DATABASE studync_test;

CREATE TABLE studync_test.results (
    seq          INT AUTO_INCREMENT PRIMARY KEY,
    test_id      VARCHAR(12)  NOT NULL,
    description  VARCHAR(255) NOT NULL,
    expected     VARCHAR(20)  NOT NULL,
    outcome      ENUM('PASS','FAIL') NOT NULL,
    detail       TEXT,
    run_as       VARCHAR(100) NOT NULL,
    run_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DROP PROCEDURE IF EXISTS studync_db.tst_expect_ok;
DROP PROCEDURE IF EXISTS studync_db.tst_expect_error;
DROP PROCEDURE IF EXISTS studync_db.tst_check_true;

DELIMITER $$
CREATE PROCEDURE studync_db.tst_expect_ok(IN p_id VARCHAR(12), IN p_desc VARCHAR(255), IN p_sql TEXT)
    SQL SECURITY INVOKER
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg   TEXT DEFAULT NULL;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
        BEGIN GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT; END;
    SET @studync_test_sql = p_sql;
    PREPARE studync_test_stmt FROM @studync_test_sql;
    IF v_errno = 0 THEN
        EXECUTE studync_test_stmt;
        DEALLOCATE PREPARE studync_test_stmt;
    END IF;
    INSERT INTO studync_test.results (test_id, description, expected, outcome, detail, run_as)
    VALUES (p_id, p_desc, 'SUCCESS', IF(v_errno = 0, 'PASS', 'FAIL'),
            IF(v_errno = 0, 'succeeded', CONCAT('error ', v_errno, ': ', v_msg)), USER());
    SELECT p_id AS test_id, p_desc AS description, 'SUCCESS' AS expected,
           IF(v_errno = 0, 'PASS', 'FAIL') AS result,
           IF(v_errno = 0, 'succeeded', CONCAT('error ', v_errno, ': ', v_msg)) AS detail;
END $$

CREATE PROCEDURE studync_db.tst_expect_error(IN p_id VARCHAR(12), IN p_desc VARCHAR(255),
                                           IN p_sql TEXT, IN p_expected VARCHAR(255))
    SQL SECURITY INVOKER
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg   TEXT DEFAULT NULL;
    DECLARE v_pass  BOOLEAN;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
        BEGIN GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT; END;
    SET @studync_test_sql = p_sql;
    PREPARE studync_test_stmt FROM @studync_test_sql;
    IF v_errno = 0 THEN
        EXECUTE studync_test_stmt;
        DEALLOCATE PREPARE studync_test_stmt;
    END IF;
    SET v_pass = v_errno <> 0 AND (
                   p_expected IS NULL
                OR (REGEXP_LIKE(p_expected, '^[0-9]+$') AND v_errno = CAST(p_expected AS UNSIGNED))
                OR (NOT REGEXP_LIKE(p_expected, '^[0-9]+$') AND v_msg LIKE CONCAT('%', p_expected, '%')));
    INSERT INTO studync_test.results (test_id, description, expected, outcome, detail, run_as)
    VALUES (p_id, p_desc, CONCAT('ERROR ', LEFT(COALESCE(p_expected, 'any'), 14)), IF(v_pass, 'PASS', 'FAIL'),
            IF(v_errno = 0, 'statement unexpectedly succeeded', CONCAT('error ', v_errno, ': ', v_msg)), USER());
    SELECT p_id AS test_id, p_desc AS description, CONCAT('ERROR ', COALESCE(p_expected, 'any')) AS expected,
           IF(v_pass, 'PASS', 'FAIL') AS result,
           IF(v_errno = 0, 'statement unexpectedly succeeded', CONCAT('error ', v_errno, ': ', v_msg)) AS detail;
END $$

CREATE PROCEDURE studync_db.tst_check_true(IN p_id VARCHAR(12), IN p_desc VARCHAR(255),
                                         IN p_condition BOOLEAN, IN p_detail TEXT)
    SQL SECURITY INVOKER
BEGIN
    INSERT INTO studync_test.results (test_id, description, expected, outcome, detail, run_as)
    VALUES (p_id, p_desc, 'TRUE', IF(COALESCE(p_condition, FALSE), 'PASS', 'FAIL'), p_detail, USER());
    SELECT p_id AS test_id, p_desc AS description, 'TRUE' AS expected,
           IF(COALESCE(p_condition, FALSE), 'PASS', 'FAIL') AS result, p_detail AS detail;
END $$
DELIMITER ;

-- the role-test accounts may run the helpers and record results - nothing else
GRANT EXECUTE ON PROCEDURE studync_db.tst_expect_ok    TO 'ana.santos'@'localhost', 'ben.torres'@'localhost', 'jose.cruz'@'localhost', 'maria.reyes'@'localhost', 'studync_app_student'@'localhost', 'studync_dba'@'localhost';
GRANT EXECUTE ON PROCEDURE studync_db.tst_expect_error TO 'ana.santos'@'localhost', 'ben.torres'@'localhost', 'jose.cruz'@'localhost', 'maria.reyes'@'localhost', 'studync_app_student'@'localhost', 'studync_dba'@'localhost';
GRANT EXECUTE ON PROCEDURE studync_db.tst_check_true   TO 'ana.santos'@'localhost', 'ben.torres'@'localhost', 'jose.cruz'@'localhost', 'maria.reyes'@'localhost', 'studync_app_student'@'localhost', 'studync_dba'@'localhost';
GRANT INSERT ON studync_test.results TO 'ana.santos'@'localhost', 'ben.torres'@'localhost',
      'jose.cruz'@'localhost', 'maria.reyes'@'localhost', 'studync_app_student'@'localhost', 'studync_dba'@'localhost';

USE studync_db;

-- #############################################################################
-- SECTION 1 : database and table creation  (requirement: structure)
-- #############################################################################
CALL studync_db.tst_check_true('STR-01', 'Database studync_db exists',
     (SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = 'studync_db') = 1, NULL);
CALL studync_db.tst_check_true('STR-02', 'All 13 ERD tables exist',
     (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'studync_db' AND table_type = 'BASE TABLE') = 13,
     (SELECT GROUP_CONCAT(table_name) FROM information_schema.tables WHERE table_schema = 'studync_db' AND table_type = 'BASE TABLE'));
CALL studync_db.tst_check_true('STR-03', '14 foreign keys defined',
     (SELECT COUNT(*) FROM information_schema.referential_constraints WHERE constraint_schema = 'studync_db') = 14,
     (SELECT CONCAT(COUNT(*), ' FKs') FROM information_schema.referential_constraints WHERE constraint_schema = 'studync_db'));
CALL studync_db.tst_check_true('STR-04', '10 views defined',
     (SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'studync_db') = 10, NULL);
CALL studync_db.tst_check_true('STR-05', 'Stored procedures and functions exist (>=35 / >=12)',
     (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'studync_db' AND routine_type = 'PROCEDURE') >= 35
     AND (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'studync_db' AND routine_type = 'FUNCTION') >= 12,
     (SELECT GROUP_CONCAT(routine_type, ':', cnt) FROM (SELECT routine_type, COUNT(*) cnt FROM information_schema.routines
       WHERE routine_schema = 'studync_db' GROUP BY routine_type) x));
CALL studync_db.tst_check_true('STR-06', '42 triggers (36 audit + 6 business rule)',
     (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema = 'studync_db') = 42,
     (SELECT CONCAT(COUNT(*), ' triggers') FROM information_schema.triggers WHERE trigger_schema = 'studync_db'));
CALL studync_db.tst_check_true('STR-07', 'Sample data loaded (12 users, 19 questions, 12 results)',
     (SELECT COUNT(*) FROM users) = 12 AND (SELECT COUNT(*) FROM questions) = 19 AND (SELECT COUNT(*) FROM quiz_results) = 12, NULL);

-- #############################################################################
-- SECTION 2 : constraints, foreign keys and business-rule triggers
--             (direct DML as root - proves rules hold even for privileged users)
-- #############################################################################
CALL studync_db.tst_expect_error('CON-01', 'FK: material for a non-existent subject is rejected',
     "INSERT INTO materials (material_id, subject_id, instructor_id, title, file_path) VALUES ('MAT0000999','SUB9999999','INS0000001','x','x.pdf')", '1452');
CALL studync_db.tst_expect_error('CON-02', 'FK: deleting a subject that has materials is rejected (no orphans)',
     "DELETE FROM subjects WHERE subject_id = 'SUB0000001'", '1451');
CALL studync_db.tst_expect_error('CON-03', 'FK: deleting a quiz that has questions is rejected',
     "DELETE FROM quizzes WHERE quiz_id = 'QUZ0000001'", '1451');
CALL studync_db.tst_expect_error('CON-04', 'CHECK: correct_answer must be one of the options',
     "INSERT INTO questions VALUES ('QST0000999','QUZ0000005','Q?','Z','A1','B1','C1','D1')", '3819');
CALL studync_db.tst_expect_error('CON-05', 'UNIQUE: duplicate username rejected',
     "INSERT INTO users (user_id, username, email, password_hash) VALUES ('USR0000999','ana.santos','x@y.com', REPEAT('a',64))", '1062');
CALL studync_db.tst_expect_error('CON-06', 'CHECK: invalid email format rejected',
     "INSERT INTO users (user_id, username, email, password_hash) VALUES ('USR0000999','zed.user','not-an-email', REPEAT('a',64))", '3819');
CALL studync_db.tst_expect_error('CON-07', 'CHECK: badly formatted primary key rejected',
     "INSERT INTO subjects (subject_id, subject_name) VALUES ('S1','Bad Id Subject')", '3819');
CALL studync_db.tst_expect_error('CON-08', 'NOT NULL: material without file_path rejected',
     "INSERT INTO materials (material_id, subject_id, instructor_id, title) VALUES ('MAT0000999','SUB0000001','INS0000001','No path')", '1364');
CALL studync_db.tst_expect_error('CON-09', 'UNIQUE: second result for same student and quiz rejected',
     "INSERT INTO quiz_results (result_id, student_id, quiz_id) VALUES ('RES0000999','STU0000001','QUZ0000001')", '1062');
CALL studync_db.tst_expect_error('CON-10', 'Trigger: answers are locked after the quiz is submitted',
     "INSERT INTO student_answers (answer_id, student_id, question_id, student_answer) VALUES ('ANS0000999','STU0000004','QST0000005','Least privilege')", 'answers are locked');
CALL studync_db.tst_expect_error('CON-11', 'Trigger: student answers cannot be modified',
     "UPDATE student_answers SET student_answer = 'GRANT' WHERE answer_id = 'ANS0000002'", 'cannot be modified');
CALL studync_db.tst_expect_error('CON-12', 'Trigger: audit_logs is append-only (UPDATE blocked, even for root)',
     "UPDATE audit_logs SET description = 'tampered' WHERE log_id = 1", 'append-only');
CALL studync_db.tst_expect_error('CON-13', 'Trigger: audit_logs is append-only (DELETE blocked, even for root)',
     "DELETE FROM audit_logs WHERE log_id = 1", 'append-only');

-- forged is_correct / score are overwritten by the triggers
INSERT INTO student_answers (answer_id, student_id, question_id, student_answer, is_correct)
VALUES ('ANS0000999', 'STU0000002', 'QST0000017', 'var', TRUE);
CALL studync_db.tst_check_true('CON-14', 'Trigger ignores a forged is_correct = TRUE for a wrong answer',
     (SELECT is_correct FROM student_answers WHERE answer_id = 'ANS0000999') = FALSE,
     (SELECT CONCAT('stored is_correct = ', is_correct) FROM student_answers WHERE answer_id = 'ANS0000999'));
INSERT INTO quiz_results (result_id, student_id, quiz_id, score) VALUES ('RES0000999', 'STU0000002', 'QUZ0000005', 100);
CALL studync_db.tst_check_true('CON-15', 'Trigger recomputes a forged score of 100 (0 of 3 correct -> 0.00)',
     (SELECT score FROM quiz_results WHERE result_id = 'RES0000999') = 0.00,
     (SELECT CONCAT('stored score = ', score) FROM quiz_results WHERE result_id = 'RES0000999'));
-- clean up the two test rows (deletes are audited with db_user = root)
DELETE FROM quiz_results    WHERE result_id = 'RES0000999';
DELETE FROM student_answers WHERE answer_id = 'ANS0000999';

-- #############################################################################
-- SECTION 3 : MODULE 1 - User management (procedures)
--   USR0000001 = maria.reyes (Administrator)   USR0000003 = jose.cruz (Instructor)
--   USR0000006 = ana.santos  (Student)         USR0000012 = gina.lopez (Inactive)
-- #############################################################################
CALL studync_db.tst_expect_ok('USR-01', 'Admin registers a new student',
     "CALL sp_register_student('USR0000001','hana.cruz','hana.cruz@studync.edu','Pass#Hana2026','Hana','Cruz', @new_user, @new_student)");
CALL studync_db.tst_check_true('USR-02', 'Registration created users + user_roles + students rows',
     @new_user = 'USR0000013' AND @new_student = 'STU0000008'
     AND EXISTS (SELECT 1 FROM user_roles WHERE user_id = 'USR0000013' AND role_id = 'ROL0000003')
     AND EXISTS (SELECT 1 FROM students WHERE student_id = 'STU0000008' AND user_id = 'USR0000013'),
     CONCAT('user=', COALESCE(@new_user,'NULL'), ' student=', COALESCE(@new_student,'NULL')));
CALL studync_db.tst_check_true('USR-03', 'Password is stored salted+hashed, never in plain text',
     (SELECT password_hash LIKE '$sha256$5000$%' AND password_hash NOT LIKE '%Pass#Hana2026%' FROM users WHERE user_id = 'USR0000013'),
     (SELECT LEFT(password_hash, 30) FROM users WHERE user_id = 'USR0000013'));
CALL studync_db.tst_check_true('USR-04', 'Same password for two users produces different hashes (salt)',
     fn_hash_password('Same#Pass1', 'aaaa') <> fn_hash_password('Same#Pass1', 'bbbb'), NULL);
CALL studync_db.tst_expect_ok('USR-05', 'Admin registers a new instructor',
     "CALL sp_register_instructor('USR0000001','paolo.lim','paolo.lim@studync.edu','Pass#Paolo2026','Paolo','Lim', @u, @i)");
CALL studync_db.tst_expect_error('USR-06', 'Duplicate username rejected by procedure',
     "CALL sp_register_student('USR0000001','hana.cruz','other@studync.edu','Pass#Hana2026','Hana','Cruz', @u, @s)", 'Username already exists');
CALL studync_db.tst_expect_error('USR-07', 'Weak password rejected',
     "CALL sp_register_student('USR0000001','weak.user','weak@studync.edu','password','Weak','User', @u, @s)", 'Weak password');
CALL studync_db.tst_expect_error('USR-08', 'Invalid email rejected',
     "CALL sp_register_student('USR0000001','bad.mail','bad-mail','Pass#Bad2026','Bad','Mail', @u, @s)", 'Invalid email');
CALL studync_db.tst_expect_error('USR-09', 'Instructor cannot register users (application role check)',
     "CALL sp_register_student('USR0000003','x.user','x@studync.edu','Pass#Xuser2026','X','User', @u, @s)", 'ACCESS DENIED');
CALL studync_db.tst_expect_error('USR-10', 'Unknown acting user rejected',
     "CALL sp_create_subject('USR9999999','Ghost Subject',NULL,@s)", 'unknown acting user');

CALL sp_authenticate_user('hana.cruz', 'Pass#Hana2026', @ok, @uid, @roles, @msg);
CALL studync_db.tst_check_true('USR-11', 'Authentication succeeds with the correct password',
     @ok = TRUE AND @uid = 'USR0000013' AND @roles = 'Student', CONCAT_WS(' | ', @ok, @uid, @roles, @msg));
CALL sp_authenticate_user('hana.cruz', 'Wrong#Pass1', @ok, @uid, @roles, @msg);
CALL studync_db.tst_check_true('USR-12', 'Authentication fails with a wrong password (generic message)',
     @ok = FALSE AND @uid IS NULL AND @msg = 'Invalid username or password', CONCAT_WS(' | ', @ok, @msg));
CALL sp_authenticate_user('gina.lopez', 'Pass#Gina2026', @ok, @uid, @roles, @msg);
CALL studync_db.tst_check_true('USR-13', 'Inactive account cannot log in', @ok = FALSE, CONCAT_WS(' | ', @ok, @msg));
CALL studync_db.tst_check_true('USR-14', 'Failed logins are written to the audit log',
     (SELECT COUNT(*) FROM audit_logs WHERE action_type = 'LOGIN_FAILED' AND record_id = 'USR0000013') = 1, NULL);

CALL studync_db.tst_expect_ok('USR-15', 'Admin updates user email and name',
     "CALL sp_update_user('USR0000001','USR0000013','hana.cruz2@studync.edu','Hannah',NULL)");
CALL studync_db.tst_check_true('USR-16', 'Update stored (email lower-cased, first name changed)',
     (SELECT email FROM users WHERE user_id = 'USR0000013') = 'hana.cruz2@studync.edu'
     AND (SELECT first_name FROM students WHERE user_id = 'USR0000013') = 'Hannah', NULL);
CALL studync_db.tst_expect_ok('USR-17', 'Admin assigns the Instructor role to a student (profile auto-created)',
     "CALL sp_assign_role('USR0000001','USR0000013','Instructor')");
CALL studync_db.tst_check_true('USR-18', 'Role assignment created user_roles + instructors rows',
     fn_user_has_role('USR0000013','Instructor') AND fn_get_instructor_id('USR0000013') IS NOT NULL, NULL);
CALL studync_db.tst_expect_ok('USR-19', 'Admin revokes the Instructor role again',
     "CALL sp_revoke_role('USR0000001','USR0000013','Instructor')");
CALL studync_db.tst_expect_error('USR-20', 'Admin cannot revoke own Administrator role',
     "CALL sp_revoke_role('USR0000001','USR0000001','Administrator')", 'cannot revoke their own');
CALL studync_db.tst_expect_error('USR-21', 'Admin cannot deactivate own account',
     "CALL sp_set_user_status('USR0000001','USR0000001','Inactive')", 'own account status');
CALL studync_db.tst_expect_error('USR-22', 'Inactive user cannot perform any operation',
     "CALL sp_submit_answer('USR0000012','QST0000017','A',@a)", 'inactive');
CALL studync_db.tst_expect_ok('USR-23', 'User changes own password',
     "CALL sp_change_password('USR0000013','Pass#Hana2026','NewPass#2026')");
CALL sp_authenticate_user('hana.cruz', 'NewPass#2026', @ok, @uid, @roles, @msg);
CALL studync_db.tst_check_true('USR-24', 'Login works with the new password', @ok = TRUE, @msg);
CALL studync_db.tst_expect_error('USR-25', 'Password change with wrong current password rejected',
     "CALL sp_change_password('USR0000013','bad','Other#2026')", 'Current password is incorrect');
CALL studync_db.tst_expect_error('USR-26', 'Student cannot read another user record',
     "CALL sp_get_user('USR0000006','USR0000001')", 'ACCESS DENIED');

-- #############################################################################
-- SECTION 4 : MODULE 2 - Subject management
-- #############################################################################
CALL studync_db.tst_expect_ok('SUB-01', 'Admin creates a subject',
     "CALL sp_create_subject('USR0000001','Information Assurance','Security policies and risk management.', @sub)");
CALL studync_db.tst_check_true('SUB-02', 'New subject stored with generated id', @sub = 'SUB0000006'
     AND EXISTS (SELECT 1 FROM subjects WHERE subject_id = 'SUB0000006'), @sub);
CALL studync_db.tst_expect_error('SUB-03', 'Duplicate subject name rejected',
     "CALL sp_create_subject('USR0000001','Information Assurance',NULL,@x)", 'already exists');
CALL studync_db.tst_expect_ok('SUB-04', 'Admin updates the subject',
     "CALL sp_update_subject('USR0000001','SUB0000006',NULL,'Security policies, risk management and compliance.')");
CALL studync_db.tst_expect_ok('SUB-05', 'Admin deletes an unused subject',
     "CALL sp_delete_subject('USR0000001','SUB0000005')");
CALL studync_db.tst_check_true('SUB-06', 'Deleted subject is gone',
     NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = 'SUB0000005'), NULL);
CALL studync_db.tst_expect_error('SUB-07', 'Subject that has materials/quizzes cannot be deleted',
     "CALL sp_delete_subject('USR0000001','SUB0000001')", 'cannot be deleted');
CALL studync_db.tst_expect_error('SUB-08', 'Instructor cannot create subjects',
     "CALL sp_create_subject('USR0000003','Hacking 101',NULL,@x)", 'ACCESS DENIED');
CALL studync_db.tst_expect_error('SUB-09', 'Student cannot delete subjects',
     "CALL sp_delete_subject('USR0000006','SUB0000006')", 'ACCESS DENIED');

-- #############################################################################
-- SECTION 5 : MODULE 3 - Learning material management
--   jose.cruz = USR0000003 / INS0000001, liza.garcia = USR0000004 / INS0000002
-- #############################################################################
CALL studync_db.tst_expect_ok('MAT-01', 'Instructor uploads a material',
     "CALL sp_upload_material('USR0000003','SUB0000006','Risk Assessment Primer','materials/sub6/risk-primer.pdf', @mat)");
CALL studync_db.tst_check_true('MAT-02', 'Material linked to subject and uploading instructor',
     (SELECT CONCAT(subject_id, '/', instructor_id) FROM materials WHERE material_id = @mat) = 'SUB0000006/INS0000001', @mat);
CALL studync_db.tst_expect_ok('MAT-03', 'Owner updates the material title',
     "CALL sp_update_material('USR0000003', @mat, NULL, 'Risk Assessment Primer (v2)', NULL)");
CALL studync_db.tst_expect_error('MAT-04', 'Another instructor cannot update it',
     "CALL sp_update_material('USR0000004', @mat, NULL, 'Hijacked', NULL)", 'ACCESS DENIED');
CALL studync_db.tst_expect_error('MAT-05', 'Another instructor cannot delete it',
     "CALL sp_delete_material('USR0000004', @mat)", 'ACCESS DENIED');
CALL studync_db.tst_expect_error('MAT-06', 'Path traversal in file_path rejected',
     "CALL sp_upload_material('USR0000003','SUB0000006','Bad','../../etc/passwd', @x)", 'Invalid file path');
CALL studync_db.tst_expect_error('MAT-07', 'Upload to a non-existent subject rejected',
     "CALL sp_upload_material('USR0000003','SUB0000999','X','x.pdf', @x)", 'Subject not found');
CALL studync_db.tst_expect_error('MAT-08', 'Student cannot upload materials',
     "CALL sp_upload_material('USR0000006','SUB0000006','X','x.pdf', @x)", 'ACCESS DENIED');
CALL studync_db.tst_expect_ok('MAT-09', 'Student retrieves the materials of a subject',
     "CALL sp_get_materials_by_subject('USR0000006','SUB0000001')");
CALL studync_db.tst_expect_ok('MAT-10', 'Owner deletes the material', "CALL sp_delete_material('USR0000003', @mat)");
CALL studync_db.tst_check_true('MAT-11', 'Material deleted', NOT EXISTS (SELECT 1 FROM materials WHERE material_id = @mat), NULL);

-- #############################################################################
-- SECTION 6 : MODULE 4 - Quiz management
-- #############################################################################
CALL studync_db.tst_expect_ok('QUZ-01', 'Instructor creates a quiz',
     "CALL sp_create_quiz('USR0000003','SUB0000006','Risk Management Quiz', @quiz)");
CALL studync_db.tst_expect_ok('QUZ-02', 'Instructor adds question 1 (correct answer given as letter)',
     "CALL sp_add_question('USR0000003', @quiz, 'Risk = Threat x ?', 'Vulnerability','Firewall','Password','Backup','A', @q1)");
CALL studync_db.tst_expect_ok('QUZ-03', 'Instructor adds question 2 (correct answer given as text)',
     "CALL sp_add_question('USR0000003', @quiz, 'Which control is preventive?', 'Audit log','Firewall','CCTV review','Incident report','Firewall', @q2)");
CALL studync_db.tst_check_true('QUZ-04', 'Correct answers stored as option text',
     (SELECT correct_answer FROM questions WHERE question_id = @q1) = 'Vulnerability'
     AND (SELECT correct_answer FROM questions WHERE question_id = @q2) = 'Firewall', NULL);
CALL studync_db.tst_expect_error('QUZ-05', 'Question whose correct answer is not an option rejected',
     "CALL sp_add_question('USR0000003', @quiz, 'Bad?', 'a1','b1','c1','d1','E', @x)", 'Correct answer must be');
CALL studync_db.tst_expect_error('QUZ-06', 'Question with duplicate options rejected (CHECK)',
     "CALL sp_add_question('USR0000003', @quiz, 'Dup?', 'same','same','c1','d1','A', @x)", '3819');
CALL studync_db.tst_expect_ok('QUZ-07', 'Instructor updates a question',
     "CALL sp_update_question('USR0000003', @q2, 'Which control is PREVENTIVE?', NULL, NULL, NULL, NULL, NULL)");
CALL studync_db.tst_expect_ok('QUZ-08', 'Instructor adds and deletes a temporary question',
     "CALL sp_add_question('USR0000003', @quiz, 'Temp?', 'w','x','y','z','D', @q3)");
CALL studync_db.tst_expect_ok('QUZ-09', 'Instructor deletes a question', "CALL sp_delete_question('USR0000003', @q3)");
CALL studync_db.tst_expect_ok('QUZ-10', 'Instructor updates the quiz title',
     "CALL sp_update_quiz('USR0000003', @quiz, NULL, 'Risk Management Quiz 1')");
CALL studync_db.tst_expect_error('QUZ-11', 'Another instructor cannot modify the quiz',
     "CALL sp_update_quiz('USR0000004', @quiz, NULL, 'Mine now')", 'ACCESS DENIED');
CALL studync_db.tst_expect_error('QUZ-12', 'Another instructor cannot add questions to it',
     "CALL sp_add_question('USR0000004', @quiz, 'X?', 'a','b','c','d','A', @x)", 'ACCESS DENIED');
CALL studync_db.tst_expect_error('QUZ-13', 'Quiz with submitted results cannot be deleted',
     "CALL sp_delete_quiz('USR0000003','QUZ0000001')", 'cannot be deleted');
CALL studync_db.tst_expect_error('QUZ-14', 'Answered question cannot be changed',
     "CALL sp_update_question('USR0000003','QST0000001','Changed?',NULL,NULL,NULL,NULL,NULL)", 'locked');
CALL studync_db.tst_expect_error('QUZ-15', 'Student cannot create quizzes',
     "CALL sp_create_quiz('USR0000006','SUB0000001','My quiz', @x)", 'ACCESS DENIED');
CALL studync_db.tst_expect_ok('QUZ-16', 'Instructor creates and deletes an unused quiz (with a question)',
     "CALL sp_create_quiz('USR0000003','SUB0000006','Throwaway Quiz', @tq)");
CALL sp_add_question('USR0000003', @tq, 'Throwaway?', 'a1','b1','c1','d1','A', @tq1);
CALL studync_db.tst_expect_ok('QUZ-17', 'Delete unused quiz', "CALL sp_delete_quiz('USR0000003', @tq)");
CALL studync_db.tst_check_true('QUZ-18', 'Quiz and its questions removed; question deletion audited',
     NOT EXISTS (SELECT 1 FROM quizzes WHERE quiz_id = @tq) AND NOT EXISTS (SELECT 1 FROM questions WHERE quiz_id = @tq)
     AND EXISTS (SELECT 1 FROM audit_logs WHERE table_name = 'questions' AND action_type = 'DELETE' AND record_id = @tq1), NULL);
CALL studync_db.tst_check_true('QUZ-19', 'Student question view hides the answer key',
     NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'studync_db'
                 AND table_name = 'v_quiz_questions_student' AND column_name = 'correct_answer'), NULL);

-- #############################################################################
-- SECTION 7 : MODULE 5 - Assessment processing and score calculation
--   ben.torres = USR0000007 / STU0000002 takes QUZ0000005 (3 questions):
--   QST0000017 correct 'let' (A), QST0000018 'console.log()' (D),
--   QST0000019 'Value and type' (B)
-- #############################################################################
CALL studync_db.tst_expect_ok('ASM-01', 'Student answers Q17 with a letter (correct)',
     "CALL sp_submit_answer('USR0000007','QST0000017','A', @a1)");
CALL studync_db.tst_expect_ok('ASM-02', 'Student answers Q18 with option text (correct)',
     "CALL sp_submit_answer('USR0000007','QST0000018','console.log()', @a2)");
CALL studync_db.tst_expect_error('ASM-03', 'Answer that is not an option is rejected',
     "CALL sp_submit_answer('USR0000007','QST0000019','E', @x)", 'Answer must be');
CALL studync_db.tst_expect_ok('ASM-04', 'Student answers Q19 (wrong)',
     "CALL sp_submit_answer('USR0000007','QST0000019','Value only', @a3)");
CALL studync_db.tst_expect_error('ASM-05', 'Second answer to the same question rejected',
     "CALL sp_submit_answer('USR0000007','QST0000019','B', @x)", 'already answered');
CALL studync_db.tst_check_true('ASM-06', 'is_correct computed by the database (1,1,0)',
     (SELECT GROUP_CONCAT(is_correct ORDER BY question_id) FROM student_answers
       WHERE student_id = 'STU0000002' AND question_id IN ('QST0000017','QST0000018','QST0000019')) = '1,1,0',
     (SELECT GROUP_CONCAT(is_correct ORDER BY question_id) FROM student_answers
       WHERE student_id = 'STU0000002' AND question_id IN ('QST0000017','QST0000018','QST0000019')));
CALL studync_db.tst_expect_ok('ASM-07', 'Student submits the quiz',
     "CALL sp_submit_quiz('USR0000007','QUZ0000005', @res, @score)");
CALL studync_db.tst_check_true('ASM-08', 'Score = 2 of 3 correct = 66.67', @score = 66.67,
     CONCAT('result=', COALESCE(@res,'NULL'), ' score=', COALESCE(@score,'NULL')));
CALL studync_db.tst_expect_error('ASM-09', 'Quiz cannot be submitted twice',
     "CALL sp_submit_quiz('USR0000007','QUZ0000005', @x, @y)", 'already submitted');
CALL studync_db.tst_expect_error('ASM-10', 'Submitting a quiz with no answers rejected',
     "CALL sp_submit_quiz('USR0000008','QUZ0000005', @x, @y)", 'No answers submitted');
CALL studync_db.tst_expect_error('ASM-11', 'Instructor cannot submit answers',
     "CALL sp_submit_answer('USR0000003','QST0000017','A', @x)", 'ACCESS DENIED');
CALL studync_db.tst_check_true('ASM-12', 'fn_calculate_quiz_score: partial attempt (4 of 5 answered, 2 correct) = 40.00',
     fn_calculate_quiz_score('STU0000004','QUZ0000001') = 40.00, NULL);
CALL studync_db.tst_check_true('ASM-13', 'Every stored score equals the documented formula',
     (SELECT COUNT(*) FROM quiz_results qr WHERE qr.score <> fn_calculate_quiz_score(qr.student_id, qr.quiz_id)) = 0, NULL);
CALL studync_db.tst_expect_ok('ASM-14', 'Student retrieves own results',
     "CALL sp_get_student_results('USR0000007', NULL)");
CALL studync_db.tst_expect_error('ASM-15', 'Student cannot retrieve another student''s results',
     "CALL sp_get_student_results('USR0000007','STU0000001')", 'ACCESS DENIED');
CALL studync_db.tst_expect_ok('ASM-16', 'Student reviews own submitted answers',
     "CALL sp_get_answer_review('USR0000007','QUZ0000005', NULL)");
CALL studync_db.tst_expect_error('ASM-17', 'Answer review is not available before submission',
     "CALL sp_get_answer_review('USR0000006','QUZ0000005', NULL)", 'No submitted result');

-- #############################################################################
-- SECTION 8 : MODULE 6 - Reporting and monitoring
-- #############################################################################
CALL studync_db.tst_expect_ok('RPT-01', 'Admin: student performance report (all subjects)',
     "CALL sp_report_student_performance('USR0000001', NULL)");
CALL studync_db.tst_expect_ok('RPT-02', 'Instructor: performance report limited to own quizzes',
     "CALL sp_report_student_performance('USR0000003', NULL)");
CALL studync_db.tst_expect_error('RPT-03', 'Student cannot run performance reports',
     "CALL sp_report_student_performance('USR0000006', NULL)", 'ACCESS DENIED');
CALL studync_db.tst_expect_ok('RPT-04', 'Instructor: quiz results report for own quiz',
     "CALL sp_report_quiz_results('USR0000003','QUZ0000001')");
CALL studync_db.tst_expect_error('RPT-05', 'Instructor: quiz results report for another instructor''s quiz denied',
     "CALL sp_report_quiz_results('USR0000003','QUZ0000003')", 'ACCESS DENIED');
CALL studync_db.tst_expect_ok('RPT-06', 'Admin: audit log report (filter by table)',
     "CALL sp_report_audit_logs('USR0000001','subjects',NULL,NULL,NULL,20)");
CALL studync_db.tst_expect_error('RPT-07', 'Instructor cannot read audit logs',
     "CALL sp_report_audit_logs('USR0000003',NULL,NULL,NULL,NULL,10)", 'ACCESS DENIED');
CALL studync_db.tst_expect_ok('RPT-08', 'Admin: system activity summary', "CALL sp_report_system_activity('USR0000001', 7)");
CALL studync_db.tst_check_true('RPT-09', 'Performance view: QUZ averages correct (Ana avg of 100,75,75 = 83.33)',
     (SELECT average_score FROM v_student_performance WHERE student_id = 'STU0000001') = 83.33,
     (SELECT CONCAT('avg=', average_score) FROM v_student_performance WHERE student_id = 'STU0000001'));
CALL studync_db.tst_check_true('RPT-10', 'Quiz results view: QUZ0000001 has 4 submissions, average 70.00',
     (SELECT COUNT(*) FROM v_quiz_results_detail WHERE quiz_id = 'QUZ0000001') = 4
     AND (SELECT ROUND(AVG(score),2) FROM quiz_results WHERE quiz_id = 'QUZ0000001') = 70.00, NULL);

-- #############################################################################
-- SECTION 9 : audit logging
-- #############################################################################
CALL studync_db.tst_check_true('AUD-01', 'INSERT audited with acting user, record id and new data',
     EXISTS (SELECT 1 FROM audit_logs WHERE table_name = 'subjects' AND action_type = 'INSERT'
              AND record_id = 'SUB0000006' AND performed_by = 'USR0000001'
              AND JSON_UNQUOTE(JSON_EXTRACT(new_data, '$.subject_name')) = 'Information Assurance'
              AND old_data IS NULL), NULL);
CALL studync_db.tst_check_true('AUD-02', 'UPDATE audited with old and new values',
     EXISTS (SELECT 1 FROM audit_logs WHERE table_name = 'subjects' AND action_type = 'UPDATE' AND record_id = 'SUB0000006'
              AND JSON_UNQUOTE(JSON_EXTRACT(old_data, '$.description')) = 'Security policies and risk management.'
              AND JSON_UNQUOTE(JSON_EXTRACT(new_data, '$.description')) LIKE '%compliance%'), NULL);
CALL studync_db.tst_check_true('AUD-03', 'DELETE audited with the deleted row in old_data',
     EXISTS (SELECT 1 FROM audit_logs WHERE table_name = 'subjects' AND action_type = 'DELETE' AND record_id = 'SUB0000005'
              AND JSON_UNQUOTE(JSON_EXTRACT(old_data, '$.subject_name')) = 'Technical Writing' AND new_data IS NULL), NULL);
CALL studync_db.tst_check_true('AUD-04', 'password_hash never appears in the audit trail',
     NOT EXISTS (SELECT 1 FROM audit_logs WHERE JSON_CONTAINS_PATH(COALESCE(new_data, JSON_OBJECT()), 'one', '$.password_hash')
                                           OR JSON_CONTAINS_PATH(COALESCE(old_data, JSON_OBJECT()), 'one', '$.password_hash')), NULL);
CALL studync_db.tst_check_true('AUD-05', 'Password change logged as a flag only',
     EXISTS (SELECT 1 FROM audit_logs WHERE table_name = 'users' AND action_type = 'UPDATE' AND record_id = 'USR0000013'
              AND JSON_EXTRACT(new_data, '$.password_changed') = TRUE), NULL);
SET @before = (SELECT COUNT(*) FROM audit_logs);
CALL sp_create_subject('USR0000001', 'Audit Count Subject', NULL, @cnt_sub);
CALL studync_db.tst_check_true('AUD-06', 'One operation produces exactly one audit row (no duplicates)',
     (SELECT COUNT(*) FROM audit_logs) - @before = 1, CONCAT((SELECT COUNT(*) FROM audit_logs) - @before, ' new row(s)'));
SET @before = (SELECT COUNT(*) FROM audit_logs);
CALL sp_update_subject('USR0000001', @cnt_sub, 'Audit Count Subject', NULL);
CALL studync_db.tst_check_true('AUD-07', 'No-op update writes no audit row',
     (SELECT COUNT(*) FROM audit_logs) - @before = 0, CONCAT((SELECT COUNT(*) FROM audit_logs) - @before, ' new row(s)'));
CALL studync_db.tst_check_true('AUD-08', 'Assessment activity audited (answers and results by the student)',
     EXISTS (SELECT 1 FROM audit_logs WHERE table_name = 'quiz_results' AND action_type = 'INSERT'
              AND performed_by = 'USR0000007' AND record_id = @res)
     AND (SELECT COUNT(*) FROM audit_logs WHERE table_name = 'student_answers' AND performed_by = 'USR0000007'
              AND action_type = 'INSERT' AND JSON_UNQUOTE(JSON_EXTRACT(new_data, '$.question_id')) IN ('QST0000017','QST0000018','QST0000019')) = 3, NULL);
CALL studync_db.tst_check_true('AUD-09', 'Direct DBA changes are audited with db_user and NULL application user',
     EXISTS (SELECT 1 FROM audit_logs WHERE table_name = 'quiz_results' AND action_type = 'DELETE'
              AND record_id = 'RES0000999' AND performed_by IS NULL AND db_user LIKE 'root@%'), NULL);
CALL studync_db.tst_check_true('AUD-10', 'Session identity variable is cleared after each procedure',
     @app_user_id IS NULL, NULL);
CALL studync_db.tst_check_true('AUD-11', 'Failed procedure calls leave no audit rows (rolled back)',
     NOT EXISTS (SELECT 1 FROM audit_logs WHERE table_name = 'subjects' AND JSON_UNQUOTE(JSON_EXTRACT(new_data,'$.subject_name')) = 'Hacking 101'), NULL);

-- @as studync_dba
-- #############################################################################
-- SECTION 9b : the DBA maintenance account cannot wipe the audit trail
-- (MySQL TRUNCATE does not fire triggers and needs the DROP privilege, which
--  studync_dba_role deliberately does not have)
-- #############################################################################
USE studync_db;
CALL studync_db.tst_expect_error('CON-16', 'DBA maintenance account cannot TRUNCATE audit_logs', "TRUNCATE TABLE audit_logs", '1142');

-- @as ana.santos
-- #############################################################################
-- SECTION 10 : RBAC - personal STUDENT login  (ana.santos = USR0000006)
-- #############################################################################
USE studync_db;
CALL studync_db.tst_expect_ok('RB-S01', 'Student can read the student question view',
     "SELECT question_id, question_text, option_a FROM v_quiz_questions_student WHERE quiz_id = 'QUZ0000004'");
CALL studync_db.tst_expect_ok('RB-S02', 'Student can read learning materials', "SELECT * FROM v_learning_materials");
CALL studync_db.tst_expect_error('RB-S03', 'Student cannot read the users table (password hashes)', "SELECT * FROM users", '1142');
CALL studync_db.tst_expect_error('RB-S04', 'Student cannot read the answer key view',
     "SELECT correct_answer FROM v_quiz_questions_instructor", '1142');
CALL studync_db.tst_expect_error('RB-S05', 'Student cannot read the questions table directly',
     "SELECT correct_answer FROM questions", '1142');
CALL studync_db.tst_expect_error('RB-S06', 'Student cannot insert a result directly',
     "INSERT INTO quiz_results (result_id, student_id, quiz_id, score) VALUES ('RES0000998','STU0000001','QUZ0000004',100)", '1142');
CALL studync_db.tst_expect_error('RB-S07', 'Student cannot execute admin procedures',
     "CALL sp_create_subject('USR0000001','Student Subject',NULL,@x)", '1370');
CALL studync_db.tst_expect_error('RB-S08', 'Student cannot execute instructor procedures',
     "CALL sp_upload_material('USR0000003','SUB0000001','x','x.pdf',@x)", '1370');
CALL studync_db.tst_expect_error('RB-S09', 'Student cannot read the audit trail', "SELECT * FROM v_audit_trail", '1142');
CALL studync_db.tst_expect_error('RB-S10', 'Student cannot delete audit logs', "DELETE FROM audit_logs", '1142');
CALL studync_db.tst_expect_error('RB-S11', 'Personal login cannot impersonate another student',
     "CALL sp_submit_answer('USR0000007','QST0000014','A',@x)", 'may only act as its own user');
CALL studync_db.tst_expect_ok('RB-S12', 'Student answers Big-O quiz Q14', "CALL sp_submit_answer('USR0000006','QST0000014','B',@x)");
CALL studync_db.tst_expect_ok('RB-S13', 'Student answers Big-O quiz Q15', "CALL sp_submit_answer('USR0000006','QST0000015','A',@x)");
CALL studync_db.tst_expect_ok('RB-S14', 'Student answers Big-O quiz Q16', "CALL sp_submit_answer('USR0000006','QST0000016','A',@x)");
CALL studync_db.tst_expect_ok('RB-S15', 'Student submits the quiz', "CALL sp_submit_quiz('USR0000006','QUZ0000004',@r,@s)");
CALL studync_db.tst_check_true('RB-S16', 'Student sees own new score 66.67', @s = 66.67, CONCAT('score=', COALESCE(@s,'NULL')));
CALL studync_db.tst_check_true('RB-S17', 'v_my_results shows only this student''s 4 results',
     (SELECT COUNT(*) FROM v_my_results) = 4, CONCAT((SELECT COUNT(*) FROM v_my_results), ' rows'));
CALL studync_db.tst_expect_ok('RB-S18', 'Student calls own results procedure', "CALL sp_get_student_results('USR0000006', NULL)");

-- @as jose.cruz
-- #############################################################################
-- SECTION 11 : RBAC - personal INSTRUCTOR login  (jose.cruz = USR0000003)
-- #############################################################################
USE studync_db;
CALL studync_db.tst_expect_ok('RB-I01', 'Instructor uploads a material', "CALL sp_upload_material('USR0000003','SUB0000001','Backup Strategies','materials/sub1/backup.pdf',@m)");
CALL studync_db.tst_expect_ok('RB-I02', 'Instructor reads the answer-key view', "SELECT question_id, correct_answer FROM v_quiz_questions_instructor WHERE instructor_id = 'INS0000001'");
CALL studync_db.tst_expect_ok('RB-I03', 'Instructor reads quiz results', "SELECT * FROM v_quiz_results_detail WHERE instructor_id = 'INS0000001'");
CALL studync_db.tst_expect_error('RB-I04', 'Instructor cannot read users table', "SELECT * FROM users", '1142');
CALL studync_db.tst_expect_error('RB-I05', 'Instructor cannot register students', "CALL sp_register_student('USR0000001','i.x','ix@studync.edu','Pass#Ix2026','I','X',@a,@b)", '1370');
CALL studync_db.tst_expect_error('RB-I06', 'Instructor cannot create subjects', "CALL sp_create_subject('USR0000001','X',NULL,@x)", '1370');
CALL studync_db.tst_expect_error('RB-I07', 'Instructor cannot read the audit trail', "SELECT * FROM v_audit_trail", '1142');
CALL studync_db.tst_expect_error('RB-I08', 'Instructor cannot submit answers', "CALL sp_submit_answer('USR0000003','QST0000001','A',@x)", '1370');
CALL studync_db.tst_expect_error('RB-I09', 'Instructor cannot update materials table directly', "UPDATE materials SET title = 'x'", '1142');
CALL studync_db.tst_expect_error('RB-I10', 'Personal login cannot act as another instructor',
     "CALL sp_upload_material('USR0000004','SUB0000002','x','x.pdf',@x)", 'may only act as its own user');

-- @as maria.reyes
-- #############################################################################
-- SECTION 12 : RBAC - personal ADMINISTRATOR login  (maria.reyes = USR0000001)
-- #############################################################################
USE studync_db;
CALL studync_db.tst_expect_ok('RB-A01', 'Admin reads the user directory (no password hashes)', "SELECT * FROM v_user_directory");
CALL studync_db.tst_expect_ok('RB-A02', 'Admin reads the audit trail', "SELECT * FROM v_audit_trail ORDER BY log_id DESC LIMIT 5");
CALL studync_db.tst_expect_ok('RB-A03', 'Admin creates a subject', "CALL sp_create_subject('USR0000001','Cloud Computing',NULL,@x)");
CALL studync_db.tst_expect_error('RB-A04', 'Admin cannot read password hashes from users table', "SELECT password_hash FROM users", '1142');
CALL studync_db.tst_expect_error('RB-A05', 'Admin cannot delete audit logs', "DELETE FROM audit_logs", '1142');
CALL studync_db.tst_expect_error('RB-A06', 'Admin cannot upload materials (instructor function)', "CALL sp_upload_material('USR0000001','SUB0000001','x','x.pdf',@x)", '1370');
CALL studync_db.tst_expect_error('RB-A07', 'Admin cannot submit answers (student function)', "CALL sp_submit_answer('USR0000001','QST0000001','A',@x)", '1370');
CALL studync_db.tst_expect_error('RB-A08', 'Admin cannot call internal helper procedures', "CALL sp_set_actor('USR0000001','Administrator')", '1370');
CALL studync_db.tst_check_true('RB-A09', 'v_user_directory exposes no password_hash column',
     NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'studync_db'
                  AND table_name = 'v_user_directory' AND column_name = 'password_hash'), NULL);

-- @as studync_app_student
-- #############################################################################
-- SECTION 13 : RBAC - shared application account for students
-- #############################################################################
USE studync_db;
CALL studync_db.tst_expect_error('RB-P01', 'Shared student account cannot call admin procedures even with an admin id',
     "CALL sp_create_subject('USR0000001','Escalation',NULL,@x)", '1370');
CALL studync_db.tst_expect_error('RB-P02', 'Shared student account passing an instructor id is still blocked by role check',
     "CALL sp_submit_answer('USR0000003','QST0000001','A',@x)", 'ACCESS DENIED');
CALL studync_db.tst_expect_ok('RB-P03', 'Shared student account retrieves results for the authenticated student',
     "CALL sp_get_student_results('USR0000008', NULL)");
CALL studync_db.tst_check_true('RB-P04', 'Row-filtered view returns nothing for a non-personal login',
     (SELECT COUNT(*) FROM v_my_results) = 0, NULL);

-- @as root
-- #############################################################################
-- SECTION 14 : GRANT / REVOKE demonstration (temporary privilege)
-- #############################################################################
GRANT SELECT ON studync_db.v_audit_trail TO 'ben.torres'@'localhost';

-- @as ben.torres
USE studync_db;
CALL studync_db.tst_expect_ok('GR-01', 'After GRANT, ben.torres can read v_audit_trail', "SELECT COUNT(*) FROM v_audit_trail");

-- @as root
REVOKE SELECT ON studync_db.v_audit_trail FROM 'ben.torres'@'localhost';

-- @as ben.torres
USE studync_db;
CALL studync_db.tst_expect_error('GR-02', 'After REVOKE, ben.torres is denied again', "SELECT COUNT(*) FROM v_audit_trail", '1142');

-- @as root
-- #############################################################################
-- SECTION 15 : SUMMARY  (expected: every test PASS, 0 FAIL) + cleanup
-- #############################################################################
DROP PROCEDURE IF EXISTS studync_db.tst_expect_ok;
DROP PROCEDURE IF EXISTS studync_db.tst_expect_error;
DROP PROCEDURE IF EXISTS studync_db.tst_check_true;

SELECT outcome, COUNT(*) AS tests FROM studync_test.results GROUP BY outcome;
SELECT test_id, description, run_as, detail FROM studync_test.results WHERE outcome = 'FAIL';
SELECT LEFT(test_id, LOCATE('-', test_id) - 1) AS area, COUNT(*) AS tests,
       SUM(outcome = 'PASS') AS passed, SUM(outcome = 'FAIL') AS failed
  FROM studync_test.results GROUP BY area ORDER BY MIN(seq);
