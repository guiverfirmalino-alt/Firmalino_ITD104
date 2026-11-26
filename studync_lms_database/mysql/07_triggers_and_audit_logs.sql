-- =============================================================================
-- StudyNC LMS (MySQL 8.0+)
-- File 07 : Triggers and audit logging
-- -----------------------------------------------------------------------------
-- A. Business-rule triggers
--    trg_student_answers_bi  : locks answers after quiz submission and computes
--                              is_correct from questions.correct_answer
--    trg_student_answers_bu  : student answers are immutable (no U in CRUD)
--    trg_quiz_results_bi/bu  : score is always computed by
--                              fn_calculate_quiz_score (cannot be forged)
--    trg_audit_logs_bu/bd    : audit_logs is append-only (tamper protection)
--
-- B. Audit triggers  (AFTER INSERT / UPDATE / DELETE on all 12 business tables)
--    Each writes ONE row into audit_logs with:
--      action_type, table_name, record_id,
--      performed_by = @app_user_id  (application user, set by sp_set_actor)
--      db_user      = USER()        (MySQL account actually connected)
--      old_data / new_data as JSON, log_timestamp (default NOW)
--
-- How the acting user's identity reaches the triggers
--    MySQL cannot know which *application* user is logged in. Every stored
--    procedure receives p_actor_user_id, validates it (sp_set_actor) and puts
--    it in the session variable @app_user_id for the duration of the call; the
--    triggers read it. Direct DML by a DBA (outside procedures) is still
--    logged, with performed_by = NULL and db_user = the DBA account.
--
-- No recursion / no duplicates
--    * audit_logs itself has no audit trigger, so inserting a log row can never
--      fire another audit trigger.
--    * Procedures never write audit rows for table DML themselves (only for
--      LOGIN events, which are not DML on a business table), so each change is
--      logged exactly once.
--    * UPDATE triggers skip no-op updates (all columns unchanged).
--    * password_hash is never copied into the audit trail; only a
--      "password_changed" flag is recorded.
--    * Note: MySQL does not fire triggers for rows changed by cascading foreign
--      keys; StudyNC therefore deletes child rows explicitly (sp_delete_quiz).
-- =============================================================================
USE studync_db;

DELIMITER $$

-- #############################################################################
-- A. Business-rule triggers
-- #############################################################################
DROP TRIGGER IF EXISTS trg_student_answers_bi $$
CREATE TRIGGER trg_student_answers_bi BEFORE INSERT ON student_answers FOR EACH ROW
BEGIN
    DECLARE v_quiz_id  VARCHAR(10);
    DECLARE v_correct  VARCHAR(255);
    SELECT quiz_id, correct_answer INTO v_quiz_id, v_correct
      FROM questions WHERE question_id = NEW.question_id;
    -- answers are locked once the quiz result exists
    IF EXISTS (SELECT 1 FROM quiz_results WHERE student_id = NEW.student_id AND quiz_id = v_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz already submitted; answers are locked';
    END IF;
    -- correctness is decided by the database, never by the client
    SET NEW.is_correct = (NEW.student_answer IS NOT NULL AND NEW.student_answer = v_correct);
END $$

DROP TRIGGER IF EXISTS trg_student_answers_bu $$
CREATE TRIGGER trg_student_answers_bu BEFORE UPDATE ON student_answers FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student answers cannot be modified once submitted';
END $$

DROP TRIGGER IF EXISTS trg_quiz_results_bi $$
CREATE TRIGGER trg_quiz_results_bi BEFORE INSERT ON quiz_results FOR EACH ROW
BEGIN
    SET NEW.score = fn_calculate_quiz_score(NEW.student_id, NEW.quiz_id);
END $$

DROP TRIGGER IF EXISTS trg_quiz_results_bu $$
CREATE TRIGGER trg_quiz_results_bu BEFORE UPDATE ON quiz_results FOR EACH ROW
BEGIN
    SET NEW.score = fn_calculate_quiz_score(NEW.student_id, NEW.quiz_id);
END $$

DROP TRIGGER IF EXISTS trg_audit_logs_bu $$
CREATE TRIGGER trg_audit_logs_bu BEFORE UPDATE ON audit_logs FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'audit_logs is append-only: UPDATE is not allowed';
END $$

DROP TRIGGER IF EXISTS trg_audit_logs_bd $$
CREATE TRIGGER trg_audit_logs_bd BEFORE DELETE ON audit_logs FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'audit_logs is append-only: DELETE is not allowed';
END $$

-- #############################################################################
-- B. Audit triggers (generated from one template; identical pattern per table)
-- #############################################################################
-- ---------------------------------------------------------------- users
DROP TRIGGER IF EXISTS trg_users_audit_ins $$
CREATE TRIGGER trg_users_audit_ins AFTER INSERT ON users FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'users', NEW.user_id, @app_user_id, USER(),
            CONCAT('Created users record ', NEW.user_id), NULL,
            JSON_OBJECT('user_id', NEW.user_id, 'username', NEW.username, 'email', NEW.email, 'status', NEW.status, 'created_at', NEW.created_at));
END $$

DROP TRIGGER IF EXISTS trg_users_audit_upd $$
CREATE TRIGGER trg_users_audit_upd AFTER UPDATE ON users FOR EACH ROW
BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.user_id <=> NEW.user_id) OR NOT (OLD.username <=> NEW.username) OR NOT (OLD.email <=> NEW.email) OR NOT (OLD.status <=> NEW.status) OR NOT (OLD.created_at <=> NEW.created_at) OR NOT (OLD.password_hash <=> NEW.password_hash) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'users', NEW.user_id, @app_user_id, USER(),
                CONCAT('Updated users record ', NEW.user_id),
                JSON_OBJECT('user_id', OLD.user_id, 'username', OLD.username, 'email', OLD.email, 'status', OLD.status, 'created_at', OLD.created_at),
                JSON_OBJECT('user_id', NEW.user_id, 'username', NEW.username, 'email', NEW.email, 'status', NEW.status, 'created_at', NEW.created_at, 'password_changed', NOT (OLD.password_hash <=> NEW.password_hash)));
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_users_audit_del $$
CREATE TRIGGER trg_users_audit_del AFTER DELETE ON users FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'users', OLD.user_id, @app_user_id, USER(),
            CONCAT('Deleted users record ', OLD.user_id),
            JSON_OBJECT('user_id', OLD.user_id, 'username', OLD.username, 'email', OLD.email, 'status', OLD.status, 'created_at', OLD.created_at), NULL);
END $$

-- ---------------------------------------------------------------- roles
DROP TRIGGER IF EXISTS trg_roles_audit_ins $$
CREATE TRIGGER trg_roles_audit_ins AFTER INSERT ON roles FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'roles', NEW.role_id, @app_user_id, USER(),
            CONCAT('Created roles record ', NEW.role_id), NULL,
            JSON_OBJECT('role_id', NEW.role_id, 'role_name', NEW.role_name));
END $$

DROP TRIGGER IF EXISTS trg_roles_audit_upd $$
CREATE TRIGGER trg_roles_audit_upd AFTER UPDATE ON roles FOR EACH ROW
BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.role_id <=> NEW.role_id) OR NOT (OLD.role_name <=> NEW.role_name) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'roles', NEW.role_id, @app_user_id, USER(),
                CONCAT('Updated roles record ', NEW.role_id),
                JSON_OBJECT('role_id', OLD.role_id, 'role_name', OLD.role_name),
                JSON_OBJECT('role_id', NEW.role_id, 'role_name', NEW.role_name));
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_roles_audit_del $$
CREATE TRIGGER trg_roles_audit_del AFTER DELETE ON roles FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'roles', OLD.role_id, @app_user_id, USER(),
            CONCAT('Deleted roles record ', OLD.role_id),
            JSON_OBJECT('role_id', OLD.role_id, 'role_name', OLD.role_name), NULL);
END $$

-- ---------------------------------------------------------------- user_roles
DROP TRIGGER IF EXISTS trg_user_roles_audit_ins $$
CREATE TRIGGER trg_user_roles_audit_ins AFTER INSERT ON user_roles FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'user_roles', CONCAT(NEW.user_id,':',NEW.role_id), @app_user_id, USER(),
            CONCAT('Created user_roles record ', CONCAT(NEW.user_id,':',NEW.role_id)), NULL,
            JSON_OBJECT('user_id', NEW.user_id, 'role_id', NEW.role_id));
END $$

DROP TRIGGER IF EXISTS trg_user_roles_audit_upd $$
CREATE TRIGGER trg_user_roles_audit_upd AFTER UPDATE ON user_roles FOR EACH ROW
BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.user_id <=> NEW.user_id) OR NOT (OLD.role_id <=> NEW.role_id) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'user_roles', CONCAT(NEW.user_id,':',NEW.role_id), @app_user_id, USER(),
                CONCAT('Updated user_roles record ', CONCAT(NEW.user_id,':',NEW.role_id)),
                JSON_OBJECT('user_id', OLD.user_id, 'role_id', OLD.role_id),
                JSON_OBJECT('user_id', NEW.user_id, 'role_id', NEW.role_id));
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_user_roles_audit_del $$
CREATE TRIGGER trg_user_roles_audit_del AFTER DELETE ON user_roles FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'user_roles', CONCAT(OLD.user_id,':',OLD.role_id), @app_user_id, USER(),
            CONCAT('Deleted user_roles record ', CONCAT(OLD.user_id,':',OLD.role_id)),
            JSON_OBJECT('user_id', OLD.user_id, 'role_id', OLD.role_id), NULL);
END $$

-- ---------------------------------------------------------------- admins
DROP TRIGGER IF EXISTS trg_admins_audit_ins $$
CREATE TRIGGER trg_admins_audit_ins AFTER INSERT ON admins FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'admins', NEW.admin_id, @app_user_id, USER(),
            CONCAT('Created admins record ', NEW.admin_id), NULL,
            JSON_OBJECT('admin_id', NEW.admin_id, 'user_id', NEW.user_id, 'first_name', NEW.first_name, 'last_name', NEW.last_name));
END $$

DROP TRIGGER IF EXISTS trg_admins_audit_upd $$
CREATE TRIGGER trg_admins_audit_upd AFTER UPDATE ON admins FOR EACH ROW
BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.admin_id <=> NEW.admin_id) OR NOT (OLD.user_id <=> NEW.user_id) OR NOT (OLD.first_name <=> NEW.first_name) OR NOT (OLD.last_name <=> NEW.last_name) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'admins', NEW.admin_id, @app_user_id, USER(),
                CONCAT('Updated admins record ', NEW.admin_id),
                JSON_OBJECT('admin_id', OLD.admin_id, 'user_id', OLD.user_id, 'first_name', OLD.first_name, 'last_name', OLD.last_name),
                JSON_OBJECT('admin_id', NEW.admin_id, 'user_id', NEW.user_id, 'first_name', NEW.first_name, 'last_name', NEW.last_name));
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_admins_audit_del $$
CREATE TRIGGER trg_admins_audit_del AFTER DELETE ON admins FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'admins', OLD.admin_id, @app_user_id, USER(),
            CONCAT('Deleted admins record ', OLD.admin_id),
            JSON_OBJECT('admin_id', OLD.admin_id, 'user_id', OLD.user_id, 'first_name', OLD.first_name, 'last_name', OLD.last_name), NULL);
END $$

-- ---------------------------------------------------------------- instructors
DROP TRIGGER IF EXISTS trg_instructors_audit_ins $$
CREATE TRIGGER trg_instructors_audit_ins AFTER INSERT ON instructors FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'instructors', NEW.instructor_id, @app_user_id, USER(),
            CONCAT('Created instructors record ', NEW.instructor_id), NULL,
            JSON_OBJECT('instructor_id', NEW.instructor_id, 'user_id', NEW.user_id, 'first_name', NEW.first_name, 'last_name', NEW.last_name));
END $$

DROP TRIGGER IF EXISTS trg_instructors_audit_upd $$
CREATE TRIGGER trg_instructors_audit_upd AFTER UPDATE ON instructors FOR EACH ROW
BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.instructor_id <=> NEW.instructor_id) OR NOT (OLD.user_id <=> NEW.user_id) OR NOT (OLD.first_name <=> NEW.first_name) OR NOT (OLD.last_name <=> NEW.last_name) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'instructors', NEW.instructor_id, @app_user_id, USER(),
                CONCAT('Updated instructors record ', NEW.instructor_id),
                JSON_OBJECT('instructor_id', OLD.instructor_id, 'user_id', OLD.user_id, 'first_name', OLD.first_name, 'last_name', OLD.last_name),
                JSON_OBJECT('instructor_id', NEW.instructor_id, 'user_id', NEW.user_id, 'first_name', NEW.first_name, 'last_name', NEW.last_name));
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_instructors_audit_del $$
CREATE TRIGGER trg_instructors_audit_del AFTER DELETE ON instructors FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'instructors', OLD.instructor_id, @app_user_id, USER(),
            CONCAT('Deleted instructors record ', OLD.instructor_id),
            JSON_OBJECT('instructor_id', OLD.instructor_id, 'user_id', OLD.user_id, 'first_name', OLD.first_name, 'last_name', OLD.last_name), NULL);
END $$

-- ---------------------------------------------------------------- students
DROP TRIGGER IF EXISTS trg_students_audit_ins $$
CREATE TRIGGER trg_students_audit_ins AFTER INSERT ON students FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'students', NEW.student_id, @app_user_id, USER(),
            CONCAT('Created students record ', NEW.student_id), NULL,
            JSON_OBJECT('student_id', NEW.student_id, 'user_id', NEW.user_id, 'first_name', NEW.first_name, 'last_name', NEW.last_name));
END $$

DROP TRIGGER IF EXISTS trg_students_audit_upd $$
CREATE TRIGGER trg_students_audit_upd AFTER UPDATE ON students FOR EACH ROW
BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.student_id <=> NEW.student_id) OR NOT (OLD.user_id <=> NEW.user_id) OR NOT (OLD.first_name <=> NEW.first_name) OR NOT (OLD.last_name <=> NEW.last_name) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'students', NEW.student_id, @app_user_id, USER(),
                CONCAT('Updated students record ', NEW.student_id),
                JSON_OBJECT('student_id', OLD.student_id, 'user_id', OLD.user_id, 'first_name', OLD.first_name, 'last_name', OLD.last_name),
                JSON_OBJECT('student_id', NEW.student_id, 'user_id', NEW.user_id, 'first_name', NEW.first_name, 'last_name', NEW.last_name));
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_students_audit_del $$
CREATE TRIGGER trg_students_audit_del AFTER DELETE ON students FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'students', OLD.student_id, @app_user_id, USER(),
            CONCAT('Deleted students record ', OLD.student_id),
            JSON_OBJECT('student_id', OLD.student_id, 'user_id', OLD.user_id, 'first_name', OLD.first_name, 'last_name', OLD.last_name), NULL);
END $$

-- ---------------------------------------------------------------- subjects
DROP TRIGGER IF EXISTS trg_subjects_audit_ins $$
CREATE TRIGGER trg_subjects_audit_ins AFTER INSERT ON subjects FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'subjects', NEW.subject_id, @app_user_id, USER(),
            CONCAT('Created subjects record ', NEW.subject_id), NULL,
            JSON_OBJECT('subject_id', NEW.subject_id, 'subject_name', NEW.subject_name, 'description', NEW.description));
END $$

DROP TRIGGER IF EXISTS trg_subjects_audit_upd $$
CREATE TRIGGER trg_subjects_audit_upd AFTER UPDATE ON subjects FOR EACH ROW
BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.subject_id <=> NEW.subject_id) OR NOT (OLD.subject_name <=> NEW.subject_name) OR NOT (OLD.description <=> NEW.description) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'subjects', NEW.subject_id, @app_user_id, USER(),
                CONCAT('Updated subjects record ', NEW.subject_id),
                JSON_OBJECT('subject_id', OLD.subject_id, 'subject_name', OLD.subject_name, 'description', OLD.description),
                JSON_OBJECT('subject_id', NEW.subject_id, 'subject_name', NEW.subject_name, 'description', NEW.description));
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_subjects_audit_del $$
CREATE TRIGGER trg_subjects_audit_del AFTER DELETE ON subjects FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'subjects', OLD.subject_id, @app_user_id, USER(),
            CONCAT('Deleted subjects record ', OLD.subject_id),
            JSON_OBJECT('subject_id', OLD.subject_id, 'subject_name', OLD.subject_name, 'description', OLD.description), NULL);
END $$

-- ---------------------------------------------------------------- materials
DROP TRIGGER IF EXISTS trg_materials_audit_ins $$
CREATE TRIGGER trg_materials_audit_ins AFTER INSERT ON materials FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'materials', NEW.material_id, @app_user_id, USER(),
            CONCAT('Created materials record ', NEW.material_id), NULL,
            JSON_OBJECT('material_id', NEW.material_id, 'subject_id', NEW.subject_id, 'instructor_id', NEW.instructor_id, 'title', NEW.title, 'file_path', NEW.file_path, 'uploaded_at', NEW.uploaded_at));
END $$

DROP TRIGGER IF EXISTS trg_materials_audit_upd $$
CREATE TRIGGER trg_materials_audit_upd AFTER UPDATE ON materials FOR EACH ROW
BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.material_id <=> NEW.material_id) OR NOT (OLD.subject_id <=> NEW.subject_id) OR NOT (OLD.instructor_id <=> NEW.instructor_id) OR NOT (OLD.title <=> NEW.title) OR NOT (OLD.file_path <=> NEW.file_path) OR NOT (OLD.uploaded_at <=> NEW.uploaded_at) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'materials', NEW.material_id, @app_user_id, USER(),
                CONCAT('Updated materials record ', NEW.material_id),
                JSON_OBJECT('material_id', OLD.material_id, 'subject_id', OLD.subject_id, 'instructor_id', OLD.instructor_id, 'title', OLD.title, 'file_path', OLD.file_path, 'uploaded_at', OLD.uploaded_at),
                JSON_OBJECT('material_id', NEW.material_id, 'subject_id', NEW.subject_id, 'instructor_id', NEW.instructor_id, 'title', NEW.title, 'file_path', NEW.file_path, 'uploaded_at', NEW.uploaded_at));
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_materials_audit_del $$
CREATE TRIGGER trg_materials_audit_del AFTER DELETE ON materials FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'materials', OLD.material_id, @app_user_id, USER(),
            CONCAT('Deleted materials record ', OLD.material_id),
            JSON_OBJECT('material_id', OLD.material_id, 'subject_id', OLD.subject_id, 'instructor_id', OLD.instructor_id, 'title', OLD.title, 'file_path', OLD.file_path, 'uploaded_at', OLD.uploaded_at), NULL);
END $$

-- ---------------------------------------------------------------- quizzes
DROP TRIGGER IF EXISTS trg_quizzes_audit_ins $$
CREATE TRIGGER trg_quizzes_audit_ins AFTER INSERT ON quizzes FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'quizzes', NEW.quiz_id, @app_user_id, USER(),
            CONCAT('Created quizzes record ', NEW.quiz_id), NULL,
            JSON_OBJECT('quiz_id', NEW.quiz_id, 'subject_id', NEW.subject_id, 'instructor_id', NEW.instructor_id, 'title', NEW.title, 'created_at', NEW.created_at));
END $$

DROP TRIGGER IF EXISTS trg_quizzes_audit_upd $$
CREATE TRIGGER trg_quizzes_audit_upd AFTER UPDATE ON quizzes FOR EACH ROW
BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.quiz_id <=> NEW.quiz_id) OR NOT (OLD.subject_id <=> NEW.subject_id) OR NOT (OLD.instructor_id <=> NEW.instructor_id) OR NOT (OLD.title <=> NEW.title) OR NOT (OLD.created_at <=> NEW.created_at) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'quizzes', NEW.quiz_id, @app_user_id, USER(),
                CONCAT('Updated quizzes record ', NEW.quiz_id),
                JSON_OBJECT('quiz_id', OLD.quiz_id, 'subject_id', OLD.subject_id, 'instructor_id', OLD.instructor_id, 'title', OLD.title, 'created_at', OLD.created_at),
                JSON_OBJECT('quiz_id', NEW.quiz_id, 'subject_id', NEW.subject_id, 'instructor_id', NEW.instructor_id, 'title', NEW.title, 'created_at', NEW.created_at));
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_quizzes_audit_del $$
CREATE TRIGGER trg_quizzes_audit_del AFTER DELETE ON quizzes FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'quizzes', OLD.quiz_id, @app_user_id, USER(),
            CONCAT('Deleted quizzes record ', OLD.quiz_id),
            JSON_OBJECT('quiz_id', OLD.quiz_id, 'subject_id', OLD.subject_id, 'instructor_id', OLD.instructor_id, 'title', OLD.title, 'created_at', OLD.created_at), NULL);
END $$

-- ---------------------------------------------------------------- questions
DROP TRIGGER IF EXISTS trg_questions_audit_ins $$
CREATE TRIGGER trg_questions_audit_ins AFTER INSERT ON questions FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'questions', NEW.question_id, @app_user_id, USER(),
            CONCAT('Created questions record ', NEW.question_id), NULL,
            JSON_OBJECT('question_id', NEW.question_id, 'quiz_id', NEW.quiz_id, 'question_text', NEW.question_text, 'correct_answer', NEW.correct_answer, 'option_a', NEW.option_a, 'option_b', NEW.option_b, 'option_c', NEW.option_c, 'option_d', NEW.option_d));
END $$

DROP TRIGGER IF EXISTS trg_questions_audit_upd $$
CREATE TRIGGER trg_questions_audit_upd AFTER UPDATE ON questions FOR EACH ROW
BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.question_id <=> NEW.question_id) OR NOT (OLD.quiz_id <=> NEW.quiz_id) OR NOT (OLD.question_text <=> NEW.question_text) OR NOT (OLD.correct_answer <=> NEW.correct_answer) OR NOT (OLD.option_a <=> NEW.option_a) OR NOT (OLD.option_b <=> NEW.option_b) OR NOT (OLD.option_c <=> NEW.option_c) OR NOT (OLD.option_d <=> NEW.option_d) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'questions', NEW.question_id, @app_user_id, USER(),
                CONCAT('Updated questions record ', NEW.question_id),
                JSON_OBJECT('question_id', OLD.question_id, 'quiz_id', OLD.quiz_id, 'question_text', OLD.question_text, 'correct_answer', OLD.correct_answer, 'option_a', OLD.option_a, 'option_b', OLD.option_b, 'option_c', OLD.option_c, 'option_d', OLD.option_d),
                JSON_OBJECT('question_id', NEW.question_id, 'quiz_id', NEW.quiz_id, 'question_text', NEW.question_text, 'correct_answer', NEW.correct_answer, 'option_a', NEW.option_a, 'option_b', NEW.option_b, 'option_c', NEW.option_c, 'option_d', NEW.option_d));
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_questions_audit_del $$
CREATE TRIGGER trg_questions_audit_del AFTER DELETE ON questions FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'questions', OLD.question_id, @app_user_id, USER(),
            CONCAT('Deleted questions record ', OLD.question_id),
            JSON_OBJECT('question_id', OLD.question_id, 'quiz_id', OLD.quiz_id, 'question_text', OLD.question_text, 'correct_answer', OLD.correct_answer, 'option_a', OLD.option_a, 'option_b', OLD.option_b, 'option_c', OLD.option_c, 'option_d', OLD.option_d), NULL);
END $$

-- ---------------------------------------------------------------- student_answers
DROP TRIGGER IF EXISTS trg_student_answers_audit_ins $$
CREATE TRIGGER trg_student_answers_audit_ins AFTER INSERT ON student_answers FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'student_answers', NEW.answer_id, @app_user_id, USER(),
            CONCAT('Created student_answers record ', NEW.answer_id), NULL,
            JSON_OBJECT('answer_id', NEW.answer_id, 'student_id', NEW.student_id, 'question_id', NEW.question_id, 'student_answer', NEW.student_answer, 'is_correct', NEW.is_correct));
END $$

DROP TRIGGER IF EXISTS trg_student_answers_audit_upd $$
CREATE TRIGGER trg_student_answers_audit_upd AFTER UPDATE ON student_answers FOR EACH ROW
BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.answer_id <=> NEW.answer_id) OR NOT (OLD.student_id <=> NEW.student_id) OR NOT (OLD.question_id <=> NEW.question_id) OR NOT (OLD.student_answer <=> NEW.student_answer) OR NOT (OLD.is_correct <=> NEW.is_correct) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'student_answers', NEW.answer_id, @app_user_id, USER(),
                CONCAT('Updated student_answers record ', NEW.answer_id),
                JSON_OBJECT('answer_id', OLD.answer_id, 'student_id', OLD.student_id, 'question_id', OLD.question_id, 'student_answer', OLD.student_answer, 'is_correct', OLD.is_correct),
                JSON_OBJECT('answer_id', NEW.answer_id, 'student_id', NEW.student_id, 'question_id', NEW.question_id, 'student_answer', NEW.student_answer, 'is_correct', NEW.is_correct));
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_student_answers_audit_del $$
CREATE TRIGGER trg_student_answers_audit_del AFTER DELETE ON student_answers FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'student_answers', OLD.answer_id, @app_user_id, USER(),
            CONCAT('Deleted student_answers record ', OLD.answer_id),
            JSON_OBJECT('answer_id', OLD.answer_id, 'student_id', OLD.student_id, 'question_id', OLD.question_id, 'student_answer', OLD.student_answer, 'is_correct', OLD.is_correct), NULL);
END $$

-- ---------------------------------------------------------------- quiz_results
DROP TRIGGER IF EXISTS trg_quiz_results_audit_ins $$
CREATE TRIGGER trg_quiz_results_audit_ins AFTER INSERT ON quiz_results FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'quiz_results', NEW.result_id, @app_user_id, USER(),
            CONCAT('Created quiz_results record ', NEW.result_id), NULL,
            JSON_OBJECT('result_id', NEW.result_id, 'student_id', NEW.student_id, 'quiz_id', NEW.quiz_id, 'score', NEW.score));
END $$

DROP TRIGGER IF EXISTS trg_quiz_results_audit_upd $$
CREATE TRIGGER trg_quiz_results_audit_upd AFTER UPDATE ON quiz_results FOR EACH ROW
BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.result_id <=> NEW.result_id) OR NOT (OLD.student_id <=> NEW.student_id) OR NOT (OLD.quiz_id <=> NEW.quiz_id) OR NOT (OLD.score <=> NEW.score) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'quiz_results', NEW.result_id, @app_user_id, USER(),
                CONCAT('Updated quiz_results record ', NEW.result_id),
                JSON_OBJECT('result_id', OLD.result_id, 'student_id', OLD.student_id, 'quiz_id', OLD.quiz_id, 'score', OLD.score),
                JSON_OBJECT('result_id', NEW.result_id, 'student_id', NEW.student_id, 'quiz_id', NEW.quiz_id, 'score', NEW.score));
    END IF;
END $$

DROP TRIGGER IF EXISTS trg_quiz_results_audit_del $$
CREATE TRIGGER trg_quiz_results_audit_del AFTER DELETE ON quiz_results FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'quiz_results', OLD.result_id, @app_user_id, USER(),
            CONCAT('Deleted quiz_results record ', OLD.result_id),
            JSON_OBJECT('result_id', OLD.result_id, 'student_id', OLD.student_id, 'quiz_id', OLD.quiz_id, 'score', OLD.score), NULL);
END $$

DELIMITER ;

SELECT event_object_table AS table_name, trigger_name, action_timing, event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'studync_db'
ORDER BY event_object_table, action_timing, event_manipulation;
