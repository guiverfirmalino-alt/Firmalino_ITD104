-- =============================================================================
-- StudyNC LMS (PostgreSQL 16+)
-- File 07 : Triggers (PL/pgSQL) and audit logging
-- -----------------------------------------------------------------------------
-- A. Business-rule triggers
--    trg_student_answers_bi    : answers locked after submission; is_correct
--                                computed from questions.correct_answer
--    trg_student_answers_bu    : answers are immutable
--    trg_quiz_results_score    : score always = fn_calculate_quiz_score(...)
--    trg_audit_logs_no_modify  : audit_logs is append-only (UPDATE/DELETE)
--    trg_audit_logs_no_truncate: TRUNCATE blocked too (PostgreSQL-specific:
--                                TRUNCATE does not fire row triggers)
--
-- B. Audit triggers: ONE generic PL/pgSQL function fn_audit_row() attached
--    AFTER INSERT / UPDATE / DELETE to all 12 business tables. The primary-key
--    column name(s) are passed as trigger arguments (TG_ARGV). Row images are
--    stored as JSONB with to_jsonb(OLD/NEW) - 'password_hash'.
--
-- Acting user identity
--    Procedures call sp_set_actor(), which runs
--        set_config('studync.app_user_id', <user_id>, true)   -- transaction-local
--    fn_audit_row() reads it with current_setting('studync.app_user_id', true).
--    db_user = session_user (the real login, even inside SECURITY DEFINER code).
--    Direct DML outside procedures is logged with performed_by = NULL.
--
-- No recursion / duplicates
--    * audit_logs has no audit trigger -> inserting a log row never recurses.
--    * Procedures never insert audit rows for table DML (only LOGIN events).
--    * UPDATE triggers use WHEN (OLD.* IS DISTINCT FROM NEW.*) so no-op
--      updates are not logged.
-- =============================================================================
SET ROLE studync_owner;
SET search_path = studync, pg_temp;

-- #############################################################################
-- A. Business-rule trigger functions and triggers
-- #############################################################################
CREATE OR REPLACE FUNCTION fn_trg_student_answers_bi()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
DECLARE
    v_quiz_id  questions.quiz_id%TYPE;
    v_correct  questions.correct_answer%TYPE;
BEGIN
    SELECT quiz_id, correct_answer INTO v_quiz_id, v_correct FROM questions WHERE question_id = NEW.question_id;
    IF EXISTS (SELECT 1 FROM quiz_results WHERE student_id = NEW.student_id AND quiz_id = v_quiz_id) THEN
        RAISE EXCEPTION 'Quiz already submitted; answers are locked';
    END IF;
    NEW.is_correct := coalesce(NEW.student_answer = v_correct, FALSE);
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION fn_trg_reject_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    -- TG_ARGV[0] carries the error message
    RAISE EXCEPTION '%', TG_ARGV[0];
END;
$$;

CREATE OR REPLACE FUNCTION fn_trg_quiz_results_score()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    NEW.score := fn_calculate_quiz_score(NEW.student_id, NEW.quiz_id);
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_student_answers_bi BEFORE INSERT ON student_answers
    FOR EACH ROW EXECUTE FUNCTION fn_trg_student_answers_bi();
CREATE TRIGGER trg_student_answers_bu BEFORE UPDATE ON student_answers
    FOR EACH ROW EXECUTE FUNCTION fn_trg_reject_change('Student answers cannot be modified once submitted');
CREATE TRIGGER trg_quiz_results_score BEFORE INSERT OR UPDATE ON quiz_results
    FOR EACH ROW EXECUTE FUNCTION fn_trg_quiz_results_score();
CREATE TRIGGER trg_audit_logs_no_modify BEFORE UPDATE OR DELETE ON audit_logs
    FOR EACH ROW EXECUTE FUNCTION fn_trg_reject_change('audit_logs is append-only: UPDATE/DELETE is not allowed');
CREATE TRIGGER trg_audit_logs_no_truncate BEFORE TRUNCATE ON audit_logs
    FOR EACH STATEMENT EXECUTE FUNCTION fn_trg_reject_change('audit_logs is append-only: TRUNCATE is not allowed');

-- #############################################################################
-- B. Generic audit trigger function
-- #############################################################################
CREATE OR REPLACE FUNCTION fn_audit_row()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
DECLARE
    v_old   JSONB;
    v_new   JSONB;
    v_row   JSONB;
    v_id    TEXT;
    v_actor VARCHAR(10) := nullif(current_setting('studync.app_user_id', true), '');
    v_verb  TEXT;
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN v_old := to_jsonb(OLD) - 'password_hash'; END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') THEN v_new := to_jsonb(NEW) - 'password_hash'; END IF;

    IF TG_OP = 'UPDATE' AND TG_TABLE_NAME = 'users' THEN
        v_new := v_new || jsonb_build_object('password_changed',
                 (to_jsonb(OLD) ->> 'password_hash') IS DISTINCT FROM (to_jsonb(NEW) ->> 'password_hash'));
    END IF;

    v_row := coalesce(v_new, v_old);
    SELECT string_agg(v_row ->> col, ':') INTO v_id FROM unnest(TG_ARGV) AS col;
    v_verb := CASE TG_OP WHEN 'INSERT' THEN 'Created' WHEN 'UPDATE' THEN 'Updated' ELSE 'Deleted' END;

    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES (TG_OP, TG_TABLE_NAME, v_id, v_actor, session_user,
            v_verb || ' ' || TG_TABLE_NAME || ' record ' || v_id, v_old, v_new);
    RETURN NULL;   -- AFTER trigger: return value ignored
END;
$$;

-- #############################################################################
-- C. Audit triggers on the 12 business tables
-- #############################################################################
-- users
CREATE TRIGGER trg_users_audit_ins AFTER INSERT ON users
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('user_id');
CREATE TRIGGER trg_users_audit_upd AFTER UPDATE ON users
    FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*) EXECUTE FUNCTION fn_audit_row('user_id');
CREATE TRIGGER trg_users_audit_del AFTER DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('user_id');

-- roles
CREATE TRIGGER trg_roles_audit_ins AFTER INSERT ON roles
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('role_id');
CREATE TRIGGER trg_roles_audit_upd AFTER UPDATE ON roles
    FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*) EXECUTE FUNCTION fn_audit_row('role_id');
CREATE TRIGGER trg_roles_audit_del AFTER DELETE ON roles
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('role_id');

-- user_roles
CREATE TRIGGER trg_user_roles_audit_ins AFTER INSERT ON user_roles
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('user_id', 'role_id');
CREATE TRIGGER trg_user_roles_audit_upd AFTER UPDATE ON user_roles
    FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*) EXECUTE FUNCTION fn_audit_row('user_id', 'role_id');
CREATE TRIGGER trg_user_roles_audit_del AFTER DELETE ON user_roles
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('user_id', 'role_id');

-- admins
CREATE TRIGGER trg_admins_audit_ins AFTER INSERT ON admins
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('admin_id');
CREATE TRIGGER trg_admins_audit_upd AFTER UPDATE ON admins
    FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*) EXECUTE FUNCTION fn_audit_row('admin_id');
CREATE TRIGGER trg_admins_audit_del AFTER DELETE ON admins
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('admin_id');

-- instructors
CREATE TRIGGER trg_instructors_audit_ins AFTER INSERT ON instructors
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('instructor_id');
CREATE TRIGGER trg_instructors_audit_upd AFTER UPDATE ON instructors
    FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*) EXECUTE FUNCTION fn_audit_row('instructor_id');
CREATE TRIGGER trg_instructors_audit_del AFTER DELETE ON instructors
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('instructor_id');

-- students
CREATE TRIGGER trg_students_audit_ins AFTER INSERT ON students
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('student_id');
CREATE TRIGGER trg_students_audit_upd AFTER UPDATE ON students
    FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*) EXECUTE FUNCTION fn_audit_row('student_id');
CREATE TRIGGER trg_students_audit_del AFTER DELETE ON students
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('student_id');

-- subjects
CREATE TRIGGER trg_subjects_audit_ins AFTER INSERT ON subjects
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('subject_id');
CREATE TRIGGER trg_subjects_audit_upd AFTER UPDATE ON subjects
    FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*) EXECUTE FUNCTION fn_audit_row('subject_id');
CREATE TRIGGER trg_subjects_audit_del AFTER DELETE ON subjects
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('subject_id');

-- materials
CREATE TRIGGER trg_materials_audit_ins AFTER INSERT ON materials
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('material_id');
CREATE TRIGGER trg_materials_audit_upd AFTER UPDATE ON materials
    FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*) EXECUTE FUNCTION fn_audit_row('material_id');
CREATE TRIGGER trg_materials_audit_del AFTER DELETE ON materials
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('material_id');

-- quizzes
CREATE TRIGGER trg_quizzes_audit_ins AFTER INSERT ON quizzes
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('quiz_id');
CREATE TRIGGER trg_quizzes_audit_upd AFTER UPDATE ON quizzes
    FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*) EXECUTE FUNCTION fn_audit_row('quiz_id');
CREATE TRIGGER trg_quizzes_audit_del AFTER DELETE ON quizzes
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('quiz_id');

-- questions
CREATE TRIGGER trg_questions_audit_ins AFTER INSERT ON questions
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('question_id');
CREATE TRIGGER trg_questions_audit_upd AFTER UPDATE ON questions
    FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*) EXECUTE FUNCTION fn_audit_row('question_id');
CREATE TRIGGER trg_questions_audit_del AFTER DELETE ON questions
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('question_id');

-- student_answers
CREATE TRIGGER trg_student_answers_audit_ins AFTER INSERT ON student_answers
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('answer_id');
CREATE TRIGGER trg_student_answers_audit_upd AFTER UPDATE ON student_answers
    FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*) EXECUTE FUNCTION fn_audit_row('answer_id');
CREATE TRIGGER trg_student_answers_audit_del AFTER DELETE ON student_answers
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('answer_id');

-- quiz_results
CREATE TRIGGER trg_quiz_results_audit_ins AFTER INSERT ON quiz_results
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('result_id');
CREATE TRIGGER trg_quiz_results_audit_upd AFTER UPDATE ON quiz_results
    FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*) EXECUTE FUNCTION fn_audit_row('result_id');
CREATE TRIGGER trg_quiz_results_audit_del AFTER DELETE ON quiz_results
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row('result_id');
RESET ROLE;

SELECT event_object_table AS table_name, trigger_name, action_timing, string_agg(event_manipulation, '/') AS events
FROM information_schema.triggers
WHERE trigger_schema = 'studync'
GROUP BY 1, 2, 3 ORDER BY 1, 2;
