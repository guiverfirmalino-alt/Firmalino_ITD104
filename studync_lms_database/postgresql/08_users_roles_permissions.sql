-- =============================================================================
-- StudyNC LMS (PostgreSQL 16+)
-- File 08 : Roles, login users, GRANT / REVOKE  (RBAC)
-- Run as  : superuser connected to studync_db
-- -----------------------------------------------------------------------------
-- Same permission matrix as the MySQL version (derived from the Detailed CRUD
-- Matrix). PostgreSQL-specific hardening:
--   * By default PostgreSQL grants EXECUTE on every new function/procedure to
--     PUBLIC. That is revoked here (and for future objects via ALTER DEFAULT
--     PRIVILEGES), otherwise any login could call admin procedures.
--   * CONNECT on the database was revoked from PUBLIC in file 01; only the
--     StudyNC roles get it back.
--   * The public schema gets no privileges; StudyNC lives in schema studync.
--   * Roles and users are cluster-wide objects: this script is re-runnable
--     (it drops what it created before re-creating it).
--   * No native "lock after N failed logins" exists in core PostgreSQL;
--     account expiry (VALID UNTIL) and CONNECTION LIMIT are used instead.
--     Passwords are stored by the server as SCRAM-SHA-256 (PG16 default).
--
-- !! DEMO passwords for the academic environment - change them in production.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. Clean re-run (remove privileges in this database, then the roles)
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    r TEXT;
BEGIN
    FOREACH r IN ARRAY ARRAY['studync_app_admin','studync_app_instructor','studync_app_student','studync_dba',
                             'maria.reyes','jose.cruz','liza.garcia','ana.santos','ben.torres',
                             'studync_admin_role','studync_instructor_role','studync_student_role','studync_dba_role']
    LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('DROP OWNED BY %I', r);
            EXECUTE format('DROP ROLE %I', r);
        END IF;
    END LOOP;
END
$$;

-- -----------------------------------------------------------------------------
-- 1. Group roles (NOLOGIN)
-- -----------------------------------------------------------------------------
CREATE ROLE studync_admin_role      NOLOGIN;
CREATE ROLE studync_instructor_role NOLOGIN;
CREATE ROLE studync_student_role    NOLOGIN;
CREATE ROLE studync_dba_role        NOLOGIN;

-- -----------------------------------------------------------------------------
-- 2. REVOKE default / public privileges first
-- -----------------------------------------------------------------------------
REVOKE ALL ON DATABASE studync_db FROM PUBLIC;
REVOKE ALL ON SCHEMA public  FROM PUBLIC;
REVOKE ALL ON SCHEMA studync FROM PUBLIC;
REVOKE ALL ON ALL TABLES    IN SCHEMA studync FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA studync FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS  IN SCHEMA studync FROM PUBLIC;
REVOKE EXECUTE ON ALL PROCEDURES IN SCHEMA studync FROM PUBLIC;
-- objects created later by studync_owner are private by default as well
ALTER DEFAULT PRIVILEGES FOR ROLE studync_owner IN SCHEMA studync REVOKE EXECUTE ON ROUTINES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE studync_owner IN SCHEMA studync REVOKE ALL ON TABLES FROM PUBLIC;

-- -----------------------------------------------------------------------------
-- 3. Privileges common to all application roles
-- -----------------------------------------------------------------------------
GRANT CONNECT ON DATABASE studync_db TO studync_admin_role, studync_instructor_role, studync_student_role, studync_dba_role;
GRANT USAGE   ON SCHEMA studync      TO studync_admin_role, studync_instructor_role, studync_student_role, studync_dba_role;

GRANT EXECUTE ON PROCEDURE studync.sp_authenticate_user        TO studync_admin_role, studync_instructor_role, studync_student_role;
GRANT EXECUTE ON PROCEDURE studync.sp_change_password          TO studync_admin_role, studync_instructor_role, studync_student_role;
GRANT EXECUTE ON FUNCTION  studync.fn_get_user                 TO studync_admin_role, studync_instructor_role, studync_student_role;
GRANT EXECUTE ON FUNCTION  studync.fn_get_materials_by_subject TO studync_admin_role, studync_instructor_role, studync_student_role;
GRANT EXECUTE ON FUNCTION  studync.fn_get_quiz_questions       TO studync_admin_role, studync_instructor_role, studync_student_role;
GRANT EXECUTE ON FUNCTION  studync.fn_get_student_results      TO studync_admin_role, studync_instructor_role, studync_student_role;
GRANT EXECUTE ON FUNCTION  studync.fn_get_answer_review        TO studync_admin_role, studync_instructor_role, studync_student_role;
GRANT SELECT  ON studync.v_subject_catalog, studync.v_learning_materials, studync.v_quiz_overview
              TO studync_admin_role, studync_instructor_role, studync_student_role;

-- -----------------------------------------------------------------------------
-- 4. Administrator
-- -----------------------------------------------------------------------------
GRANT EXECUTE ON PROCEDURE studync.sp_register_student, studync.sp_register_instructor,
                           studync.sp_assign_role, studync.sp_revoke_role,
                           studync.sp_update_user, studync.sp_set_user_status,
                           studync.sp_create_subject, studync.sp_update_subject, studync.sp_delete_subject
              TO studync_admin_role;
GRANT EXECUTE ON FUNCTION  studync.fn_report_student_performance, studync.fn_report_quiz_results,
                           studync.fn_report_quiz_summary, studync.fn_report_audit_logs,
                           studync.fn_report_system_activity
              TO studync_admin_role;
GRANT SELECT  ON studync.v_user_directory, studync.v_quiz_results_detail,
                 studync.v_student_performance, studync.v_audit_trail, studync.roles
              TO studync_admin_role;

-- -----------------------------------------------------------------------------
-- 5. Instructor
-- -----------------------------------------------------------------------------
GRANT EXECUTE ON PROCEDURE studync.sp_upload_material, studync.sp_update_material, studync.sp_delete_material,
                           studync.sp_create_quiz, studync.sp_update_quiz, studync.sp_delete_quiz,
                           studync.sp_add_question, studync.sp_update_question, studync.sp_delete_question
              TO studync_instructor_role;
GRANT EXECUTE ON FUNCTION  studync.fn_report_student_performance, studync.fn_report_quiz_results,
                           studync.fn_report_quiz_summary
              TO studync_instructor_role;
GRANT SELECT  ON studync.v_quiz_questions_instructor, studync.v_quiz_results_detail, studync.v_student_performance
              TO studync_instructor_role;

-- -----------------------------------------------------------------------------
-- 6. Student
-- -----------------------------------------------------------------------------
GRANT EXECUTE ON PROCEDURE studync.sp_submit_answer, studync.sp_submit_quiz TO studync_student_role;
GRANT SELECT  ON studync.v_quiz_questions_student, studync.v_my_results     TO studync_student_role;

-- -----------------------------------------------------------------------------
-- 7. Database administrator (maintenance; not superuser, schema-scoped)
--    Can read/maintain data but audit_logs stays append-only (triggers) and
--    the DBA cannot TRUNCATE it.
-- -----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES ON ALL TABLES IN SCHEMA studync TO studync_dba_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA studync TO studync_dba_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA studync TO studync_dba_role;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA studync TO studync_dba_role;
REVOKE UPDATE, DELETE ON studync.audit_logs FROM studync_dba_role;   -- defence in depth

-- -----------------------------------------------------------------------------
-- 8. Explicit REVOKEs documenting what must never be granted
-- -----------------------------------------------------------------------------
REVOKE ALL ON studync.users, studync.audit_logs, studync.questions
          FROM studync_admin_role, studync_instructor_role, studync_student_role;
REVOKE ALL ON studync.v_quiz_questions_instructor, studync.v_quiz_results_detail, studync.v_audit_trail
          FROM studync_student_role;
REVOKE EXECUTE ON PROCEDURE studync.sp_set_actor, studync.sp_register_user, studync.sp_create_profile,
                            studync.sp_assert_quiz_owner, studync.sp_clear_actor
          FROM studync_admin_role, studync_instructor_role, studync_student_role;

-- -----------------------------------------------------------------------------
-- 9. Login users
-- -----------------------------------------------------------------------------
CREATE ROLE studync_app_admin      LOGIN PASSWORD 'AppAdm!n#2026'   CONNECTION LIMIT 20 IN ROLE studync_admin_role;
CREATE ROLE studync_app_instructor LOGIN PASSWORD 'AppInstr#2026'   CONNECTION LIMIT 20 IN ROLE studync_instructor_role;
CREATE ROLE studync_app_student    LOGIN PASSWORD 'AppStud#2026'    CONNECTION LIMIT 50 IN ROLE studync_student_role;
CREATE ROLE studync_dba            LOGIN PASSWORD 'Dba#StudyNC2026' CONNECTION LIMIT 3  IN ROLE studync_dba_role;

-- personal accounts: login name = users.username; expire like a semester account
CREATE ROLE "maria.reyes" LOGIN PASSWORD 'Maria#2026' CONNECTION LIMIT 3 VALID UNTIL '2027-12-31' IN ROLE studync_admin_role;
CREATE ROLE "jose.cruz"   LOGIN PASSWORD 'Jose#2026'  CONNECTION LIMIT 3 VALID UNTIL '2027-12-31' IN ROLE studync_instructor_role;
CREATE ROLE "liza.garcia" LOGIN PASSWORD 'Liza#2026'  CONNECTION LIMIT 3 VALID UNTIL '2027-12-31' IN ROLE studync_instructor_role;
CREATE ROLE "ana.santos"  LOGIN PASSWORD 'Ana#2026'   CONNECTION LIMIT 3 VALID UNTIL '2027-12-31' IN ROLE studync_student_role;
CREATE ROLE "ben.torres"  LOGIN PASSWORD 'Ben#2026'   CONNECTION LIMIT 3 VALID UNTIL '2027-12-31' IN ROLE studync_student_role;

-- unqualified names resolve to the studync schema after login
ALTER ROLE studync_admin_role      IN DATABASE studync_db SET search_path = studync;
ALTER ROLE studync_instructor_role IN DATABASE studync_db SET search_path = studync;
ALTER ROLE studync_student_role    IN DATABASE studync_db SET search_path = studync;
DO $$
DECLARE r TEXT;
BEGIN
    FOREACH r IN ARRAY ARRAY['studync_app_admin','studync_app_instructor','studync_app_student','studync_dba',
                             'maria.reyes','jose.cruz','liza.garcia','ana.santos','ben.torres']
    LOOP
        EXECUTE format('ALTER ROLE %I IN DATABASE studync_db SET search_path = studync', r);
    END LOOP;
END
$$;

-- -----------------------------------------------------------------------------
-- 10. Verification
-- -----------------------------------------------------------------------------
SELECT grantee, table_name, string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privileges
FROM information_schema.role_table_grants
WHERE table_schema = 'studync' AND grantee LIKE 'studync%role'
GROUP BY grantee, table_name ORDER BY grantee, table_name;

SELECT r.rolname AS login, m.rolname AS member_of
FROM pg_auth_members am JOIN pg_roles r ON r.oid = am.member JOIN pg_roles m ON m.oid = am.roleid
WHERE m.rolname LIKE 'studync%role' ORDER BY 2, 1;
