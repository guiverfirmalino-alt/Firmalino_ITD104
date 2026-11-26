-- =============================================================================
-- StudyNC LMS (MySQL 8.0+)
-- File 08 : Database roles, user accounts, GRANT / REVOKE  (RBAC)
-- -----------------------------------------------------------------------------
-- Principle of least privilege, derived from the Detailed CRUD Matrix:
--   * NO application role receives INSERT/UPDATE/DELETE on any table.
--     All changes go through SQL SECURITY DEFINER stored procedures (EXECUTE).
--   * NO application role receives SELECT on base tables; reads go through
--     views (SELECT) or read procedures. password_hash is never readable.
--   * Internal helper procedures (sp_set_actor, sp_next_id, sp_create_profile,
--     sp_register_user, sp_assert_quiz_owner) are granted to nobody.
--
-- Roles
--   studync_admin_role       Administrator  (User, Subject, Reporting/Audit)
--   studync_instructor_role  Instructor     (Materials, Quizzes, Questions, Results)
--   studync_student_role     Student        (View materials/quizzes, Submit, own Results)
--   studync_dba_role         Database administrator (maintenance; not an app role)
--
-- Accounts
--   Shared application accounts (the web/app tier connects with these and
--   passes the authenticated user's id to every procedure):
--     studync_app_admin, studync_app_instructor, studync_app_student
--   Personal demo accounts (account name = users.username, so the
--   anti-impersonation rule in sp_set_actor and the row filter in
--   v_my_results apply):
--     maria.reyes (admin), jose.cruz / liza.garcia (instructors),
--     ana.santos / ben.torres (students)
--
-- !! The passwords below are DEMO passwords for the academic environment.
-- !! Change them before any real deployment.
-- =============================================================================
USE studync_db;

-- -----------------------------------------------------------------------------
-- 0. Clean re-run
-- -----------------------------------------------------------------------------
DROP USER IF EXISTS 'studync_app_admin'@'localhost', 'studync_app_instructor'@'localhost',
                    'studync_app_student'@'localhost', 'studync_dba'@'localhost',
                    'maria.reyes'@'localhost', 'jose.cruz'@'localhost', 'liza.garcia'@'localhost',
                    'ana.santos'@'localhost', 'ben.torres'@'localhost';
DROP ROLE IF EXISTS 'studync_admin_role', 'studync_instructor_role',
                    'studync_student_role', 'studync_dba_role';

-- -----------------------------------------------------------------------------
-- 1. Roles
-- -----------------------------------------------------------------------------
CREATE ROLE 'studync_admin_role', 'studync_instructor_role',
            'studync_student_role', 'studync_dba_role';

-- -----------------------------------------------------------------------------
-- 2. Privileges common to every application role
-- -----------------------------------------------------------------------------
-- login + own password + own profile
GRANT EXECUTE ON PROCEDURE studync_db.sp_authenticate_user TO 'studync_admin_role', 'studync_instructor_role', 'studync_student_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_change_password   TO 'studync_admin_role', 'studync_instructor_role', 'studync_student_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_get_user          TO 'studync_admin_role', 'studync_instructor_role', 'studync_student_role';
-- View Subjects / View Materials / View Quizzes (header)
GRANT SELECT  ON studync_db.v_subject_catalog              TO 'studync_admin_role', 'studync_instructor_role', 'studync_student_role';
GRANT SELECT  ON studync_db.v_learning_materials           TO 'studync_admin_role', 'studync_instructor_role', 'studync_student_role';
GRANT SELECT  ON studync_db.v_quiz_overview                TO 'studync_admin_role', 'studync_instructor_role', 'studync_student_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_get_materials_by_subject TO 'studync_admin_role', 'studync_instructor_role', 'studync_student_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_get_quiz_questions       TO 'studync_admin_role', 'studync_instructor_role', 'studync_student_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_get_student_results      TO 'studync_admin_role', 'studync_instructor_role', 'studync_student_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_get_answer_review        TO 'studync_admin_role', 'studync_instructor_role', 'studync_student_role';

-- -----------------------------------------------------------------------------
-- 3. Administrator : Register Instructor/Student, View Users, Subjects C/R/U/D,
--                    View Results, View Audit Logs, reports
-- -----------------------------------------------------------------------------
GRANT EXECUTE ON PROCEDURE studync_db.sp_register_student           TO 'studync_admin_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_register_instructor        TO 'studync_admin_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_assign_role                TO 'studync_admin_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_revoke_role                TO 'studync_admin_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_update_user                TO 'studync_admin_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_set_user_status            TO 'studync_admin_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_create_subject             TO 'studync_admin_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_update_subject             TO 'studync_admin_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_delete_subject             TO 'studync_admin_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_report_student_performance TO 'studync_admin_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_report_quiz_results        TO 'studync_admin_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_report_audit_logs          TO 'studync_admin_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_report_system_activity     TO 'studync_admin_role';
GRANT SELECT  ON studync_db.v_user_directory      TO 'studync_admin_role';
GRANT SELECT  ON studync_db.v_quiz_results_detail TO 'studync_admin_role';
GRANT SELECT  ON studync_db.v_student_performance TO 'studync_admin_role';
GRANT SELECT  ON studync_db.v_audit_trail         TO 'studync_admin_role';
GRANT SELECT  ON studync_db.roles                 TO 'studync_admin_role';   -- reference data only

-- -----------------------------------------------------------------------------
-- 4. Instructor : Upload/Update/Delete Material, Create/Update/Delete Quiz,
--                 Add/Update/Delete Question, View Quizzes, View Results
-- -----------------------------------------------------------------------------
GRANT EXECUTE ON PROCEDURE studync_db.sp_upload_material            TO 'studync_instructor_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_update_material            TO 'studync_instructor_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_delete_material            TO 'studync_instructor_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_create_quiz                TO 'studync_instructor_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_update_quiz                TO 'studync_instructor_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_delete_quiz                TO 'studync_instructor_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_add_question               TO 'studync_instructor_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_update_question            TO 'studync_instructor_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_delete_question            TO 'studync_instructor_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_report_student_performance TO 'studync_instructor_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_report_quiz_results        TO 'studync_instructor_role';
GRANT SELECT  ON studync_db.v_quiz_questions_instructor TO 'studync_instructor_role';
GRANT SELECT  ON studync_db.v_quiz_results_detail       TO 'studync_instructor_role';
GRANT SELECT  ON studync_db.v_student_performance       TO 'studync_instructor_role';

-- -----------------------------------------------------------------------------
-- 5. Student : View Materials, View Quizzes (no answer key), Submit Answer,
--              Submit Quiz, View (own) Results
-- -----------------------------------------------------------------------------
GRANT EXECUTE ON PROCEDURE studync_db.sp_submit_answer TO 'studync_student_role';
GRANT EXECUTE ON PROCEDURE studync_db.sp_submit_quiz   TO 'studync_student_role';
GRANT SELECT  ON studync_db.v_quiz_questions_student   TO 'studync_student_role';
GRANT SELECT  ON studync_db.v_my_results               TO 'studync_student_role';

-- -----------------------------------------------------------------------------
-- 6. Database administrator (maintenance account, schema-scoped only, no
--    global privileges such as SUPER / FILE / CREATE USER).
--    DROP is deliberately NOT granted: in MySQL, TRUNCATE TABLE requires DROP
--    and does not fire triggers, so DROP would allow wiping audit_logs.
--    TRIGGER is not granted either (the DBA could drop the audit triggers).
-- -----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, CREATE VIEW, SHOW VIEW,
      EXECUTE, LOCK TABLES, REFERENCES
      ON studync_db.* TO 'studync_dba_role';

-- -----------------------------------------------------------------------------
-- 7. REVOKE : make sure no application role holds blanket schema privileges or
--    direct access to sensitive tables (idempotent; IF EXISTS = MySQL 8.0.30+).
-- -----------------------------------------------------------------------------
REVOKE IF EXISTS ALL PRIVILEGES ON studync_db.* FROM 'studync_admin_role', 'studync_instructor_role', 'studync_student_role';
REVOKE IF EXISTS SELECT, INSERT, UPDATE, DELETE ON studync_db.users      FROM 'studync_admin_role', 'studync_instructor_role', 'studync_student_role';
REVOKE IF EXISTS SELECT, INSERT, UPDATE, DELETE ON studync_db.audit_logs FROM 'studync_admin_role', 'studync_instructor_role', 'studync_student_role';
-- Students must never see the answer key or other students' data
REVOKE IF EXISTS SELECT ON studync_db.v_quiz_questions_instructor FROM 'studync_student_role';
REVOKE IF EXISTS SELECT ON studync_db.v_quiz_results_detail       FROM 'studync_student_role';
-- Internal helpers are never callable directly
REVOKE IF EXISTS EXECUTE ON PROCEDURE studync_db.sp_set_actor FROM 'studync_admin_role', 'studync_instructor_role', 'studync_student_role';

-- -----------------------------------------------------------------------------
-- 8. User accounts (+ password-lock policy: 5 failed attempts -> 1 day lock)
-- -----------------------------------------------------------------------------
CREATE USER 'studync_app_admin'@'localhost'      IDENTIFIED BY 'AppAdm!n#2026'   FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1;
CREATE USER 'studync_app_instructor'@'localhost' IDENTIFIED BY 'AppInstr#2026'   FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1;
CREATE USER 'studync_app_student'@'localhost'    IDENTIFIED BY 'AppStud#2026'    FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1;
CREATE USER 'studync_dba'@'localhost'            IDENTIFIED BY 'Dba#StudyNC2026' FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1;

CREATE USER 'maria.reyes'@'localhost' IDENTIFIED BY 'Maria#2026'  FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1 PASSWORD EXPIRE INTERVAL 180 DAY;
CREATE USER 'jose.cruz'@'localhost'   IDENTIFIED BY 'Jose#2026'   FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1 PASSWORD EXPIRE INTERVAL 180 DAY;
CREATE USER 'liza.garcia'@'localhost' IDENTIFIED BY 'Liza#2026'   FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1 PASSWORD EXPIRE INTERVAL 180 DAY;
CREATE USER 'ana.santos'@'localhost'  IDENTIFIED BY 'Ana#2026'    FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1 PASSWORD EXPIRE INTERVAL 180 DAY;
CREATE USER 'ben.torres'@'localhost'  IDENTIFIED BY 'Ben#2026'    FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1 PASSWORD EXPIRE INTERVAL 180 DAY;

-- role membership
GRANT 'studync_admin_role'      TO 'studync_app_admin'@'localhost', 'maria.reyes'@'localhost';
GRANT 'studync_instructor_role' TO 'studync_app_instructor'@'localhost', 'jose.cruz'@'localhost', 'liza.garcia'@'localhost';
GRANT 'studync_student_role'    TO 'studync_app_student'@'localhost', 'ana.santos'@'localhost', 'ben.torres'@'localhost';
GRANT 'studync_dba_role'        TO 'studync_dba'@'localhost';

-- activate the granted role automatically at login
SET DEFAULT ROLE ALL TO
    'studync_app_admin'@'localhost', 'studync_app_instructor'@'localhost', 'studync_app_student'@'localhost',
    'studync_dba'@'localhost', 'maria.reyes'@'localhost', 'jose.cruz'@'localhost',
    'liza.garcia'@'localhost', 'ana.santos'@'localhost', 'ben.torres'@'localhost';

-- -----------------------------------------------------------------------------
-- 9. Verification
-- -----------------------------------------------------------------------------
SHOW GRANTS FOR 'studync_student_role';
SHOW GRANTS FOR 'ana.santos'@'localhost' USING 'studync_student_role';
SELECT grantee, table_name, privilege_type
  FROM information_schema.table_privileges
 WHERE table_schema = 'studync_db'
 ORDER BY grantee, table_name;
