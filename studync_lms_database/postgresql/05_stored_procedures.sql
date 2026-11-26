-- =============================================================================
-- StudyNC LMS (PostgreSQL 16+)
-- File 05 : Stored procedures (data-modifying operations of all 6 modules)
-- -----------------------------------------------------------------------------
-- Read/report operations are FUNCTIONS returning tables (file 06), because a
-- PostgreSQL procedure cannot return a result set the way MySQL can.
--
-- Conventions (functionally identical to the MySQL version)
--   * p_actor_user_id = authenticated application user; validated by
--     sp_set_actor, which also stores it in the transaction-local setting
--     studync.app_user_id that the audit trigger reads.
--   * SECURITY DEFINER + SET search_path = studync, pg_temp
--     (fixed search_path prevents search-path hijacking of definer code).
--     Definer = studync_owner (NOT a superuser).
--   * Authorization failures: SQLSTATE 42501 (insufficient_privilege) and a
--     message starting with 'ACCESS DENIED'. Validation failures: P0001.
--   * Transactions: a CALL is atomic. Any exception aborts the procedure and
--     PostgreSQL rolls back every change it made (no explicit COMMIT is used,
--     so the procedures can also be called inside a caller's transaction).
--   * Values are only ever used as parameters - no dynamic SQL - so the
--     procedures are not injectable.
-- =============================================================================
SET ROLE studync_owner;
SET search_path = studync, pg_temp;

-- #############################################################################
-- Internal helpers (EXECUTE revoked from PUBLIC in file 08, granted to nobody)
-- #############################################################################
CREATE OR REPLACE PROCEDURE sp_set_actor(p_actor_user_id VARCHAR, p_allowed_roles TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
DECLARE
    v_username users.username%TYPE;
    v_status   users.status%TYPE;
BEGIN
    SELECT username, status INTO v_username, v_status FROM users WHERE user_id = p_actor_user_id;
    IF v_username IS NULL THEN
        RAISE EXCEPTION 'ACCESS DENIED: unknown acting user' USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF v_status <> 'Active' THEN
        RAISE EXCEPTION 'ACCESS DENIED: account is inactive' USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM user_roles ur JOIN roles r ON r.role_id = ur.role_id
                    WHERE ur.user_id = p_actor_user_id
                      AND r.role_name = ANY (string_to_array(p_allowed_roles, ','))) THEN
        RAISE EXCEPTION 'ACCESS DENIED: this operation requires role(s) %', p_allowed_roles
              USING ERRCODE = 'insufficient_privilege';
    END IF;
    -- anti-impersonation for personal logins (login name = a username)
    IF EXISTS (SELECT 1 FROM users WHERE lower(username) = lower(session_user))
       AND lower(session_user) <> lower(v_username) THEN
        RAISE EXCEPTION 'ACCESS DENIED: a personal database login may only act as its own user'
              USING ERRCODE = 'insufficient_privilege';
    END IF;
    PERFORM set_config('studync.app_user_id', p_actor_user_id, true);   -- transaction-local
END;
$$;

CREATE OR REPLACE PROCEDURE sp_clear_actor()
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$ BEGIN PERFORM set_config('studync.app_user_id', '', true); END; $$;

-- profile row for a role
CREATE OR REPLACE PROCEDURE sp_create_profile(p_user_id VARCHAR, p_role_name VARCHAR,
                                              p_first_name VARCHAR, p_last_name VARCHAR,
                                              OUT p_profile_id VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    CASE p_role_name
        WHEN 'Administrator' THEN
            INSERT INTO admins (user_id, first_name, last_name)
            VALUES (p_user_id, btrim(p_first_name), btrim(p_last_name)) RETURNING admin_id INTO p_profile_id;
        WHEN 'Instructor' THEN
            INSERT INTO instructors (user_id, first_name, last_name)
            VALUES (p_user_id, btrim(p_first_name), btrim(p_last_name)) RETURNING instructor_id INTO p_profile_id;
        WHEN 'Student' THEN
            INSERT INTO students (user_id, first_name, last_name)
            VALUES (p_user_id, btrim(p_first_name), btrim(p_last_name)) RETURNING student_id INTO p_profile_id;
        ELSE
            RAISE EXCEPTION 'Invalid role name';
    END CASE;
END;
$$;

-- DFD 1.1 validate -> 1.2/1.3 register -> 1.4 assign role -> 1.5 store
CREATE OR REPLACE PROCEDURE sp_register_user(p_role_name VARCHAR, p_username VARCHAR, p_email VARCHAR,
                                             p_password VARCHAR, p_first_name VARCHAR, p_last_name VARCHAR,
                                             OUT p_user_id VARCHAR, OUT p_profile_id VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    IF p_username IS NULL OR p_username !~ '^[A-Za-z0-9._]{3,50}$' THEN
        RAISE EXCEPTION 'Invalid username (3-50 letters, digits, dot or underscore)';
    END IF;
    IF p_email IS NULL OR p_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' THEN
        RAISE EXCEPTION 'Invalid email address';
    END IF;
    IF NOT fn_is_strong_password(p_password) THEN
        RAISE EXCEPTION 'Weak password: minimum 8 characters with upper-case, lower-case and a digit';
    END IF;
    IF coalesce(btrim(p_first_name), '') = '' OR coalesce(btrim(p_last_name), '') = '' THEN
        RAISE EXCEPTION 'First name and last name are required';
    END IF;
    IF EXISTS (SELECT 1 FROM users WHERE lower(username) = lower(p_username)) THEN
        RAISE EXCEPTION 'Username already exists';
    END IF;
    IF EXISTS (SELECT 1 FROM users WHERE lower(email) = lower(p_email)) THEN
        RAISE EXCEPTION 'Email already registered';
    END IF;

    INSERT INTO users (username, email, password_hash)
    VALUES (p_username, lower(p_email), fn_hash_password(p_password))
    RETURNING user_id INTO p_user_id;

    INSERT INTO user_roles (user_id, role_id)
    SELECT p_user_id, role_id FROM roles WHERE role_name = p_role_name;

    CALL sp_create_profile(p_user_id, p_role_name, p_first_name, p_last_name, p_profile_id);
END;
$$;

-- #############################################################################
-- MODULE 1 : USER MANAGEMENT
-- #############################################################################

-- Login check. Never raises for bad credentials so the LOGIN_FAILED audit row
-- is committed; returns a generic message (no username enumeration).
CREATE OR REPLACE PROCEDURE sp_authenticate_user(p_username VARCHAR, p_password VARCHAR,
                                                 OUT p_success BOOLEAN, OUT p_user_id VARCHAR,
                                                 OUT p_roles VARCHAR, OUT p_message VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
DECLARE
    v_user users%ROWTYPE;
BEGIN
    SELECT * INTO v_user FROM users WHERE lower(username) = lower(p_username);
    IF v_user.user_id IS NOT NULL AND v_user.status = 'Active'
       AND fn_verify_password(p_password, v_user.password_hash) THEN
        p_success := TRUE;
        p_user_id := v_user.user_id;
        SELECT string_agg(r.role_name, ',' ORDER BY r.role_name) INTO p_roles
          FROM user_roles ur JOIN roles r ON r.role_id = ur.role_id WHERE ur.user_id = v_user.user_id;
        p_message := 'Login successful';
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, description)
        VALUES ('LOGIN_SUCCESS', 'users', v_user.user_id, v_user.user_id, 'User ' || v_user.username || ' logged in');
    ELSE
        p_success := FALSE;
        p_user_id := NULL;
        p_roles   := NULL;
        p_message := 'Invalid username or password';
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, description)
        VALUES ('LOGIN_FAILED', 'users', v_user.user_id, NULL,
                'Failed login for username "' || left(coalesce(p_username, ''), 50) || '"'
                || CASE WHEN v_user.status = 'Inactive' THEN ' (inactive account)' ELSE '' END);
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_register_student(p_actor_user_id VARCHAR, p_username VARCHAR, p_email VARCHAR,
                                                p_password VARCHAR, p_first_name VARCHAR, p_last_name VARCHAR,
                                                OUT p_user_id VARCHAR, OUT p_student_id VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    CALL sp_register_user('Student', p_username, p_email, p_password, p_first_name, p_last_name,
                          p_user_id, p_student_id);
    CALL sp_clear_actor();
END;
$$;

CREATE OR REPLACE PROCEDURE sp_register_instructor(p_actor_user_id VARCHAR, p_username VARCHAR, p_email VARCHAR,
                                                   p_password VARCHAR, p_first_name VARCHAR, p_last_name VARCHAR,
                                                   OUT p_user_id VARCHAR, OUT p_instructor_id VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    CALL sp_register_user('Instructor', p_username, p_email, p_password, p_first_name, p_last_name,
                          p_user_id, p_instructor_id);
    CALL sp_clear_actor();
END;
$$;

CREATE OR REPLACE PROCEDURE sp_assign_role(p_actor_user_id VARCHAR, p_user_id VARCHAR, p_role_name VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
DECLARE
    v_role_id    roles.role_id%TYPE;
    v_first      VARCHAR(50);
    v_last       VARCHAR(50);
    v_profile_id VARCHAR(10);
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    SELECT role_id INTO v_role_id FROM roles WHERE role_name = p_role_name;
    IF v_role_id IS NULL THEN RAISE EXCEPTION 'Unknown role'; END IF;
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN RAISE EXCEPTION 'User not found'; END IF;
    IF EXISTS (SELECT 1 FROM user_roles WHERE user_id = p_user_id AND role_id = v_role_id) THEN
        RAISE EXCEPTION 'User already has this role';
    END IF;

    INSERT INTO user_roles (user_id, role_id) VALUES (p_user_id, v_role_id);

    IF (p_role_name = 'Administrator' AND NOT EXISTS (SELECT 1 FROM admins      WHERE user_id = p_user_id))
    OR (p_role_name = 'Instructor'    AND NOT EXISTS (SELECT 1 FROM instructors WHERE user_id = p_user_id))
    OR (p_role_name = 'Student'       AND NOT EXISTS (SELECT 1 FROM students    WHERE user_id = p_user_id)) THEN
        SELECT n.first_name, n.last_name INTO v_first, v_last FROM (
              SELECT a.first_name, a.last_name FROM admins a      WHERE a.user_id = p_user_id
              UNION ALL
              SELECT i.first_name, i.last_name FROM instructors i WHERE i.user_id = p_user_id
              UNION ALL
              SELECT s.first_name, s.last_name FROM students s    WHERE s.user_id = p_user_id) n
        LIMIT 1;
        CALL sp_create_profile(p_user_id, p_role_name, v_first, v_last, v_profile_id);
    END IF;
    CALL sp_clear_actor();
END;
$$;

CREATE OR REPLACE PROCEDURE sp_revoke_role(p_actor_user_id VARCHAR, p_user_id VARCHAR, p_role_name VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
DECLARE
    v_role_id roles.role_id%TYPE;
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    SELECT role_id INTO v_role_id FROM roles WHERE role_name = p_role_name;
    IF NOT EXISTS (SELECT 1 FROM user_roles WHERE user_id = p_user_id AND role_id = v_role_id) THEN
        RAISE EXCEPTION 'User does not have this role';
    END IF;
    IF p_user_id = p_actor_user_id AND p_role_name = 'Administrator' THEN
        RAISE EXCEPTION 'Administrators cannot revoke their own Administrator role';
    END IF;
    IF (SELECT count(*) FROM user_roles WHERE user_id = p_user_id) = 1 THEN
        RAISE EXCEPTION 'A user must keep at least one role';
    END IF;
    DELETE FROM user_roles WHERE user_id = p_user_id AND role_id = v_role_id;
    CALL sp_clear_actor();
END;
$$;

CREATE OR REPLACE PROCEDURE sp_update_user(p_actor_user_id VARCHAR, p_user_id VARCHAR, p_email VARCHAR,
                                           p_first_name VARCHAR, p_last_name VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN RAISE EXCEPTION 'User not found'; END IF;
    IF p_email IS NOT NULL THEN
        IF p_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' THEN
            RAISE EXCEPTION 'Invalid email address';
        END IF;
        IF EXISTS (SELECT 1 FROM users WHERE lower(email) = lower(p_email) AND user_id <> p_user_id) THEN
            RAISE EXCEPTION 'Email already registered';
        END IF;
        UPDATE users SET email = lower(p_email) WHERE user_id = p_user_id AND email <> lower(p_email);
    END IF;
    IF p_first_name IS NOT NULL OR p_last_name IS NOT NULL THEN
        UPDATE admins      SET first_name = coalesce(btrim(p_first_name), first_name),
                               last_name  = coalesce(btrim(p_last_name),  last_name)  WHERE user_id = p_user_id;
        UPDATE instructors SET first_name = coalesce(btrim(p_first_name), first_name),
                               last_name  = coalesce(btrim(p_last_name),  last_name)  WHERE user_id = p_user_id;
        UPDATE students    SET first_name = coalesce(btrim(p_first_name), first_name),
                               last_name  = coalesce(btrim(p_last_name),  last_name)  WHERE user_id = p_user_id;
    END IF;
    CALL sp_clear_actor();
END;
$$;

CREATE OR REPLACE PROCEDURE sp_set_user_status(p_actor_user_id VARCHAR, p_user_id VARCHAR, p_status VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    IF p_status IS NULL OR p_status NOT IN ('Active', 'Inactive') THEN
        RAISE EXCEPTION 'Status must be Active or Inactive';
    END IF;
    IF p_user_id = p_actor_user_id THEN
        RAISE EXCEPTION 'Administrators cannot change their own account status';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN RAISE EXCEPTION 'User not found'; END IF;
    UPDATE users SET status = p_status::user_status WHERE user_id = p_user_id;
    CALL sp_clear_actor();
END;
$$;

CREATE OR REPLACE PROCEDURE sp_change_password(p_actor_user_id VARCHAR, p_old_password VARCHAR, p_new_password VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');
    IF NOT fn_verify_password(p_old_password, (SELECT password_hash FROM users WHERE user_id = p_actor_user_id)) THEN
        RAISE EXCEPTION 'Current password is incorrect';
    END IF;
    IF NOT fn_is_strong_password(p_new_password) THEN
        RAISE EXCEPTION 'Weak password: minimum 8 characters with upper-case, lower-case and a digit';
    END IF;
    UPDATE users SET password_hash = fn_hash_password(p_new_password) WHERE user_id = p_actor_user_id;
    CALL sp_clear_actor();
END;
$$;

-- #############################################################################
-- MODULE 2 : SUBJECT MANAGEMENT (Administrator)
-- #############################################################################
CREATE OR REPLACE PROCEDURE sp_create_subject(p_actor_user_id VARCHAR, p_subject_name VARCHAR,
                                              p_description TEXT, OUT p_subject_id VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    IF coalesce(btrim(p_subject_name), '') = '' THEN RAISE EXCEPTION 'Subject name is required'; END IF;
    IF EXISTS (SELECT 1 FROM subjects WHERE lower(subject_name) = lower(btrim(p_subject_name))) THEN
        RAISE EXCEPTION 'Subject name already exists';
    END IF;
    INSERT INTO subjects (subject_name, description)
    VALUES (btrim(p_subject_name), p_description)
    RETURNING subject_id INTO p_subject_id;
    CALL sp_clear_actor();
END;
$$;

CREATE OR REPLACE PROCEDURE sp_update_subject(p_actor_user_id VARCHAR, p_subject_id VARCHAR,
                                              p_subject_name VARCHAR, p_description TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    IF NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = p_subject_id) THEN RAISE EXCEPTION 'Subject not found'; END IF;
    IF p_subject_name IS NOT NULL AND btrim(p_subject_name) = '' THEN RAISE EXCEPTION 'Subject name cannot be blank'; END IF;
    IF EXISTS (SELECT 1 FROM subjects WHERE lower(subject_name) = lower(btrim(p_subject_name))
                                         AND subject_id <> p_subject_id) THEN
        RAISE EXCEPTION 'Subject name already exists';
    END IF;
    UPDATE subjects
       SET subject_name = coalesce(btrim(p_subject_name), subject_name),
           description  = coalesce(p_description, description)
     WHERE subject_id = p_subject_id;
    CALL sp_clear_actor();
END;
$$;

CREATE OR REPLACE PROCEDURE sp_delete_subject(p_actor_user_id VARCHAR, p_subject_id VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    IF NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = p_subject_id) THEN RAISE EXCEPTION 'Subject not found'; END IF;
    IF EXISTS (SELECT 1 FROM materials WHERE subject_id = p_subject_id)
       OR EXISTS (SELECT 1 FROM quizzes WHERE subject_id = p_subject_id) THEN
        RAISE EXCEPTION 'Subject has materials or quizzes and cannot be deleted';
    END IF;
    DELETE FROM subjects WHERE subject_id = p_subject_id;
    CALL sp_clear_actor();
END;
$$;

-- #############################################################################
-- MODULE 3 : LEARNING MATERIAL MANAGEMENT (Instructor, own materials)
-- #############################################################################
CREATE OR REPLACE PROCEDURE sp_upload_material(p_actor_user_id VARCHAR, p_subject_id VARCHAR, p_title VARCHAR,
                                               p_file_path VARCHAR, OUT p_material_id VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    IF NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = p_subject_id) THEN RAISE EXCEPTION 'Subject not found'; END IF;
    IF coalesce(btrim(p_title), '') = '' THEN RAISE EXCEPTION 'Material title is required'; END IF;
    IF NOT fn_is_safe_file_path(p_file_path) THEN RAISE EXCEPTION 'Invalid file path'; END IF;
    INSERT INTO materials (subject_id, instructor_id, title, file_path)
    VALUES (p_subject_id, fn_get_instructor_id(p_actor_user_id), btrim(p_title), btrim(p_file_path))
    RETURNING material_id INTO p_material_id;
    CALL sp_clear_actor();
END;
$$;

CREATE OR REPLACE PROCEDURE sp_update_material(p_actor_user_id VARCHAR, p_material_id VARCHAR, p_subject_id VARCHAR,
                                               p_title VARCHAR, p_file_path VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
DECLARE
    v_owner materials.instructor_id%TYPE;
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    SELECT instructor_id INTO v_owner FROM materials WHERE material_id = p_material_id FOR UPDATE;
    IF v_owner IS NULL THEN RAISE EXCEPTION 'Material not found'; END IF;
    IF v_owner <> fn_get_instructor_id(p_actor_user_id) THEN
        RAISE EXCEPTION 'ACCESS DENIED: you can only modify your own materials' USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF p_subject_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = p_subject_id) THEN
        RAISE EXCEPTION 'Subject not found';
    END IF;
    IF p_title IS NOT NULL AND btrim(p_title) = '' THEN RAISE EXCEPTION 'Material title cannot be blank'; END IF;
    IF p_file_path IS NOT NULL AND NOT fn_is_safe_file_path(p_file_path) THEN RAISE EXCEPTION 'Invalid file path'; END IF;
    UPDATE materials
       SET subject_id = coalesce(p_subject_id, subject_id),
           title      = coalesce(btrim(p_title), title),
           file_path  = coalesce(btrim(p_file_path), file_path)
     WHERE material_id = p_material_id;
    CALL sp_clear_actor();
END;
$$;

CREATE OR REPLACE PROCEDURE sp_delete_material(p_actor_user_id VARCHAR, p_material_id VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
DECLARE
    v_owner materials.instructor_id%TYPE;
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    SELECT instructor_id INTO v_owner FROM materials WHERE material_id = p_material_id FOR UPDATE;
    IF v_owner IS NULL THEN RAISE EXCEPTION 'Material not found'; END IF;
    IF v_owner <> fn_get_instructor_id(p_actor_user_id) THEN
        RAISE EXCEPTION 'ACCESS DENIED: you can only delete your own materials' USING ERRCODE = 'insufficient_privilege';
    END IF;
    DELETE FROM materials WHERE material_id = p_material_id;
    CALL sp_clear_actor();
END;
$$;

-- #############################################################################
-- MODULE 4 : QUIZ MANAGEMENT (Instructor, own quizzes)
-- #############################################################################
CREATE OR REPLACE PROCEDURE sp_assert_quiz_owner(p_actor_user_id VARCHAR, p_quiz_id VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
DECLARE
    v_owner quizzes.instructor_id%TYPE;
BEGIN
    SELECT instructor_id INTO v_owner FROM quizzes WHERE quiz_id = p_quiz_id;
    IF v_owner IS NULL THEN RAISE EXCEPTION 'Quiz not found'; END IF;
    IF v_owner <> coalesce(fn_get_instructor_id(p_actor_user_id), '') THEN
        RAISE EXCEPTION 'ACCESS DENIED: you can only manage your own quizzes' USING ERRCODE = 'insufficient_privilege';
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_create_quiz(p_actor_user_id VARCHAR, p_subject_id VARCHAR, p_title VARCHAR,
                                           OUT p_quiz_id VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    IF NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = p_subject_id) THEN RAISE EXCEPTION 'Subject not found'; END IF;
    IF coalesce(btrim(p_title), '') = '' THEN RAISE EXCEPTION 'Quiz title is required'; END IF;
    INSERT INTO quizzes (subject_id, instructor_id, title)
    VALUES (p_subject_id, fn_get_instructor_id(p_actor_user_id), btrim(p_title))
    RETURNING quiz_id INTO p_quiz_id;
    CALL sp_clear_actor();
END;
$$;

CREATE OR REPLACE PROCEDURE sp_update_quiz(p_actor_user_id VARCHAR, p_quiz_id VARCHAR, p_subject_id VARCHAR, p_title VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    CALL sp_assert_quiz_owner(p_actor_user_id, p_quiz_id);
    IF p_subject_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = p_subject_id) THEN
        RAISE EXCEPTION 'Subject not found';
    END IF;
    IF p_title IS NOT NULL AND btrim(p_title) = '' THEN RAISE EXCEPTION 'Quiz title cannot be blank'; END IF;
    UPDATE quizzes
       SET subject_id = coalesce(p_subject_id, subject_id),
           title      = coalesce(btrim(p_title), title)
     WHERE quiz_id = p_quiz_id;
    CALL sp_clear_actor();
END;
$$;

CREATE OR REPLACE PROCEDURE sp_delete_quiz(p_actor_user_id VARCHAR, p_quiz_id VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    CALL sp_assert_quiz_owner(p_actor_user_id, p_quiz_id);
    IF EXISTS (SELECT 1 FROM quiz_results WHERE quiz_id = p_quiz_id)
       OR EXISTS (SELECT 1 FROM student_answers sa JOIN questions q ON q.question_id = sa.question_id
                   WHERE q.quiz_id = p_quiz_id) THEN
        RAISE EXCEPTION 'Quiz already has student answers or results and cannot be deleted';
    END IF;
    DELETE FROM questions WHERE quiz_id = p_quiz_id;    -- each deletion audited
    DELETE FROM quizzes   WHERE quiz_id = p_quiz_id;
    CALL sp_clear_actor();
END;
$$;

CREATE OR REPLACE PROCEDURE sp_add_question(p_actor_user_id VARCHAR, p_quiz_id VARCHAR, p_question_text TEXT,
                                            p_option_a VARCHAR, p_option_b VARCHAR, p_option_c VARCHAR,
                                            p_option_d VARCHAR, p_correct_answer VARCHAR,
                                            OUT p_question_id VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
DECLARE
    v_correct VARCHAR(255);
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    CALL sp_assert_quiz_owner(p_actor_user_id, p_quiz_id);
    IF EXISTS (SELECT 1 FROM quiz_results WHERE quiz_id = p_quiz_id) THEN
        RAISE EXCEPTION 'Quiz already has submitted results; questions are locked';
    END IF;
    IF coalesce(btrim(p_question_text), '') = '' OR p_option_a IS NULL OR p_option_b IS NULL
       OR p_option_c IS NULL OR p_option_d IS NULL THEN
        RAISE EXCEPTION 'Question text and all four options are required';
    END IF;
    v_correct := fn_resolve_option(p_correct_answer, p_option_a, p_option_b, p_option_c, p_option_d);
    IF v_correct IS NULL THEN
        RAISE EXCEPTION 'Correct answer must be A, B, C, D or the exact text of an option';
    END IF;
    INSERT INTO questions (quiz_id, question_text, correct_answer, option_a, option_b, option_c, option_d)
    VALUES (p_quiz_id, btrim(p_question_text), v_correct, p_option_a, p_option_b, p_option_c, p_option_d)
    RETURNING question_id INTO p_question_id;
    CALL sp_clear_actor();
END;
$$;

CREATE OR REPLACE PROCEDURE sp_update_question(p_actor_user_id VARCHAR, p_question_id VARCHAR, p_question_text TEXT,
                                               p_option_a VARCHAR, p_option_b VARCHAR, p_option_c VARCHAR,
                                               p_option_d VARCHAR, p_correct_answer VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
DECLARE
    v_q       questions%ROWTYPE;
    v_correct VARCHAR(255);
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    SELECT * INTO v_q FROM questions WHERE question_id = p_question_id FOR UPDATE;
    IF v_q.question_id IS NULL THEN RAISE EXCEPTION 'Question not found'; END IF;
    CALL sp_assert_quiz_owner(p_actor_user_id, v_q.quiz_id);
    IF EXISTS (SELECT 1 FROM student_answers WHERE question_id = p_question_id) THEN
        RAISE EXCEPTION 'Question has already been answered and is locked';
    END IF;
    v_q.option_a := coalesce(p_option_a, v_q.option_a);
    v_q.option_b := coalesce(p_option_b, v_q.option_b);
    v_q.option_c := coalesce(p_option_c, v_q.option_c);
    v_q.option_d := coalesce(p_option_d, v_q.option_d);
    v_correct := fn_resolve_option(coalesce(p_correct_answer, v_q.correct_answer),
                                   v_q.option_a, v_q.option_b, v_q.option_c, v_q.option_d);
    IF v_correct IS NULL THEN
        RAISE EXCEPTION 'Correct answer must be A, B, C, D or the exact text of an option';
    END IF;
    IF p_question_text IS NOT NULL AND btrim(p_question_text) = '' THEN
        RAISE EXCEPTION 'Question text cannot be blank';
    END IF;
    UPDATE questions
       SET question_text  = coalesce(btrim(p_question_text), question_text),
           option_a = v_q.option_a, option_b = v_q.option_b,
           option_c = v_q.option_c, option_d = v_q.option_d,
           correct_answer = v_correct
     WHERE question_id = p_question_id;
    CALL sp_clear_actor();
END;
$$;

CREATE OR REPLACE PROCEDURE sp_delete_question(p_actor_user_id VARCHAR, p_question_id VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
DECLARE
    v_quiz_id questions.quiz_id%TYPE;
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    SELECT quiz_id INTO v_quiz_id FROM questions WHERE question_id = p_question_id;
    IF v_quiz_id IS NULL THEN RAISE EXCEPTION 'Question not found'; END IF;
    CALL sp_assert_quiz_owner(p_actor_user_id, v_quiz_id);
    IF EXISTS (SELECT 1 FROM student_answers WHERE question_id = p_question_id)
       OR EXISTS (SELECT 1 FROM quiz_results WHERE quiz_id = v_quiz_id) THEN
        RAISE EXCEPTION 'Question has already been answered and cannot be deleted';
    END IF;
    DELETE FROM questions WHERE question_id = p_question_id;
    CALL sp_clear_actor();
END;
$$;

-- #############################################################################
-- MODULE 5 : ASSESSMENT PROCESSING (Student)
-- #############################################################################
CREATE OR REPLACE PROCEDURE sp_submit_answer(p_actor_user_id VARCHAR, p_question_id VARCHAR, p_answer VARCHAR,
                                             OUT p_answer_id VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
DECLARE
    v_student_id students.student_id%TYPE;
    v_q          questions%ROWTYPE;
    v_answer     VARCHAR(255);
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Student');
    v_student_id := fn_get_student_id(p_actor_user_id);
    SELECT * INTO v_q FROM questions WHERE question_id = p_question_id;
    IF v_q.question_id IS NULL THEN RAISE EXCEPTION 'Question not found'; END IF;
    IF EXISTS (SELECT 1 FROM quiz_results WHERE student_id = v_student_id AND quiz_id = v_q.quiz_id) THEN
        RAISE EXCEPTION 'Quiz already submitted; answers are locked';
    END IF;
    IF EXISTS (SELECT 1 FROM student_answers WHERE student_id = v_student_id AND question_id = p_question_id) THEN
        RAISE EXCEPTION 'Question already answered';
    END IF;
    v_answer := fn_resolve_option(p_answer, v_q.option_a, v_q.option_b, v_q.option_c, v_q.option_d);
    IF v_answer IS NULL THEN
        RAISE EXCEPTION 'Answer must be A, B, C, D or the exact text of an option';
    END IF;
    INSERT INTO student_answers (student_id, question_id, student_answer)
    VALUES (v_student_id, p_question_id, v_answer)
    RETURNING answer_id INTO p_answer_id;
    CALL sp_clear_actor();
END;
$$;

CREATE OR REPLACE PROCEDURE sp_submit_quiz(p_actor_user_id VARCHAR, p_quiz_id VARCHAR,
                                           OUT p_result_id VARCHAR, OUT p_score NUMERIC)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
DECLARE
    v_student_id students.student_id%TYPE;
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Student');
    v_student_id := fn_get_student_id(p_actor_user_id);
    IF NOT EXISTS (SELECT 1 FROM quizzes WHERE quiz_id = p_quiz_id) THEN RAISE EXCEPTION 'Quiz not found'; END IF;
    IF fn_question_count(p_quiz_id) = 0 THEN RAISE EXCEPTION 'Quiz has no questions'; END IF;
    IF EXISTS (SELECT 1 FROM quiz_results WHERE student_id = v_student_id AND quiz_id = p_quiz_id) THEN
        RAISE EXCEPTION 'Quiz already submitted';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM student_answers sa JOIN questions q ON q.question_id = sa.question_id
                    WHERE sa.student_id = v_student_id AND q.quiz_id = p_quiz_id) THEN
        RAISE EXCEPTION 'No answers submitted for this quiz';
    END IF;
    INSERT INTO quiz_results (student_id, quiz_id, score)
    VALUES (v_student_id, p_quiz_id, 0)               -- trigger computes the real score
    RETURNING result_id, score INTO p_result_id, p_score;
    CALL sp_clear_actor();
END;
$$;

RESET ROLE;

SELECT p.proname AS procedure_name, p.prosecdef AS security_definer
FROM pg_proc p WHERE p.pronamespace = 'studync'::regnamespace AND p.prokind = 'p'
ORDER BY 1;
