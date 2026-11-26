-- =============================================================================
-- StudyNC LMS (MySQL 8.0+)
-- File 05 : Stored procedures (controlled data modification for all 6 modules)
-- -----------------------------------------------------------------------------
-- Conventions
--   * Every public procedure takes p_actor_user_id = the application user
--     (users.user_id) who performs the action. The application must pass the
--     id of the user it has AUTHENTICATED (sp_authenticate_user).
--   * sp_set_actor() validates that user (exists, Active, has an allowed role,
--     and - for personal MySQL logins - is the same person as the login), then
--     stores it in the session variable @app_user_id. Audit triggers read
--     @app_user_id to record WHO did the change. It is cleared on exit.
--   * SQL SECURITY DEFINER: callers need only EXECUTE on the procedure, never
--     table privileges. This is the "controlled modification" layer.
--   * Errors: SIGNAL SQLSTATE '45000'. Messages starting with 'ACCESS DENIED'
--     are authorization failures; others are validation failures.
--   * Transactions: START TRANSACTION ... COMMIT; an EXIT HANDLER rolls back
--     and re-raises the original error (RESIGNAL) on any SQL exception.
--   * All values are passed as procedure parameters (never concatenated into
--     dynamic SQL), which makes the procedures immune to SQL injection when
--     the application calls them with parameterized statements.
--
-- Functions used here (fn_*) are created in file 06; MySQL resolves them at
-- run time, so the creation order 05 -> 06 is valid.
-- =============================================================================
USE studync_db;

DELIMITER $$

-- #############################################################################
-- Internal helpers (NOT granted to any application role)
-- #############################################################################

-- -----------------------------------------------------------------------------
-- sp_set_actor : authorize the acting application user and register identity
--   p_allowed_roles : comma separated list, e.g. 'Administrator,Instructor'
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_set_actor $$
CREATE PROCEDURE sp_set_actor(IN p_actor_user_id VARCHAR(10), IN p_allowed_roles VARCHAR(100))
    SQL SECURITY DEFINER
BEGIN
    DECLARE v_username VARCHAR(50);
    DECLARE v_status   VARCHAR(10);
    DECLARE v_login    VARCHAR(100);
    DECLARE v_msg      VARCHAR(255);

    SET v_username = (SELECT username FROM users WHERE user_id = p_actor_user_id);
    SET v_status   = (SELECT status   FROM users WHERE user_id = p_actor_user_id);

    IF v_username IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ACCESS DENIED: unknown acting user';
    END IF;

    IF v_status <> 'Active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ACCESS DENIED: account is inactive';
    END IF;

    IF NOT EXISTS (SELECT 1
                     FROM user_roles ur
                     JOIN roles r ON r.role_id = ur.role_id
                    WHERE ur.user_id = p_actor_user_id
                      AND FIND_IN_SET(r.role_name, p_allowed_roles) > 0) THEN
        SET v_msg = CONCAT('ACCESS DENIED: this operation requires role(s) ', p_allowed_roles);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- Anti-impersonation: a personal login (account name = a username) may only
    -- act as itself. Shared application accounts are trusted to pass the
    -- authenticated user's id.
    SET v_login = SUBSTRING_INDEX(USER(), '@', 1);
    IF EXISTS (SELECT 1 FROM users WHERE username = v_login) AND v_login <> v_username THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ACCESS DENIED: a personal database login may only act as its own user';
    END IF;

    SET @app_user_id = p_actor_user_id;
END $$

-- -----------------------------------------------------------------------------
-- sp_next_id : generate the next formatted primary key for an entity.
-- Uses a locking read (FOR UPDATE) on the highest key so concurrent
-- transactions are serialized and never generate the same id.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_next_id $$
CREATE PROCEDURE sp_next_id(IN p_entity VARCHAR(20), OUT p_new_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE v_max VARCHAR(10);
    CASE p_entity
        WHEN 'users'           THEN SELECT MAX(user_id)       INTO v_max FROM users           FOR UPDATE;
        WHEN 'admins'          THEN SELECT MAX(admin_id)      INTO v_max FROM admins          FOR UPDATE;
        WHEN 'instructors'     THEN SELECT MAX(instructor_id) INTO v_max FROM instructors     FOR UPDATE;
        WHEN 'students'        THEN SELECT MAX(student_id)    INTO v_max FROM students        FOR UPDATE;
        WHEN 'subjects'        THEN SELECT MAX(subject_id)    INTO v_max FROM subjects        FOR UPDATE;
        WHEN 'materials'       THEN SELECT MAX(material_id)   INTO v_max FROM materials       FOR UPDATE;
        WHEN 'quizzes'         THEN SELECT MAX(quiz_id)       INTO v_max FROM quizzes         FOR UPDATE;
        WHEN 'questions'       THEN SELECT MAX(question_id)   INTO v_max FROM questions       FOR UPDATE;
        WHEN 'student_answers' THEN SELECT MAX(answer_id)     INTO v_max FROM student_answers FOR UPDATE;
        WHEN 'quiz_results'    THEN SELECT MAX(result_id)     INTO v_max FROM quiz_results    FOR UPDATE;
        ELSE SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'sp_next_id: unknown entity';
    END CASE;

    SET p_new_id = fn_format_id(
        CASE p_entity
            WHEN 'users' THEN 'USR' WHEN 'admins' THEN 'ADM' WHEN 'instructors' THEN 'INS'
            WHEN 'students' THEN 'STU' WHEN 'subjects' THEN 'SUB' WHEN 'materials' THEN 'MAT'
            WHEN 'quizzes' THEN 'QUZ' WHEN 'questions' THEN 'QST' WHEN 'student_answers' THEN 'ANS'
            ELSE 'RES' END,
        COALESCE(CAST(SUBSTRING(v_max, 4) AS UNSIGNED), 0) + 1);
END $$

-- -----------------------------------------------------------------------------
-- sp_create_profile : insert the admins/instructors/students row for a user
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_create_profile $$
CREATE PROCEDURE sp_create_profile(IN p_user_id VARCHAR(10), IN p_role_name VARCHAR(50),
                                   IN p_first_name VARCHAR(50), IN p_last_name VARCHAR(50),
                                   OUT p_profile_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    IF p_role_name = 'Administrator' THEN
        CALL sp_next_id('admins', p_profile_id);
        INSERT INTO admins (admin_id, user_id, first_name, last_name)
        VALUES (p_profile_id, p_user_id, TRIM(p_first_name), TRIM(p_last_name));
    ELSEIF p_role_name = 'Instructor' THEN
        CALL sp_next_id('instructors', p_profile_id);
        INSERT INTO instructors (instructor_id, user_id, first_name, last_name)
        VALUES (p_profile_id, p_user_id, TRIM(p_first_name), TRIM(p_last_name));
    ELSEIF p_role_name = 'Student' THEN
        CALL sp_next_id('students', p_profile_id);
        INSERT INTO students (student_id, user_id, first_name, last_name)
        VALUES (p_profile_id, p_user_id, TRIM(p_first_name), TRIM(p_last_name));
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid role name';
    END IF;
END $$

-- -----------------------------------------------------------------------------
-- sp_register_user : shared logic for DFD 1.1 Validate -> 1.2/1.3 Register ->
--                    1.4 Assign Role -> 1.5 Store User Records
-- (no transaction control here; the public wrappers own the transaction)
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_register_user $$
CREATE PROCEDURE sp_register_user(IN p_role_name VARCHAR(50), IN p_username VARCHAR(50),
                                  IN p_email VARCHAR(100), IN p_password VARCHAR(255),
                                  IN p_first_name VARCHAR(50), IN p_last_name VARCHAR(50),
                                  OUT p_user_id VARCHAR(10), OUT p_profile_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE v_salt CHAR(32);

    -- 1.1 Validate user information
    IF p_username IS NULL OR NOT REGEXP_LIKE(p_username, '^[A-Za-z0-9._]{3,50}$') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid username (3-50 letters, digits, dot or underscore)';
    END IF;
    IF p_email IS NULL OR NOT REGEXP_LIKE(p_email, '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid email address';
    END IF;
    IF NOT fn_is_strong_password(p_password) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Weak password: minimum 8 characters with upper-case, lower-case and a digit';
    END IF;
    IF p_first_name IS NULL OR TRIM(p_first_name) = '' OR p_last_name IS NULL OR TRIM(p_last_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'First name and last name are required';
    END IF;
    IF EXISTS (SELECT 1 FROM users WHERE username = p_username) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Username already exists';
    END IF;
    IF EXISTS (SELECT 1 FROM users WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email already registered';
    END IF;

    -- 1.5 Store user record (password is salted + hashed, never stored in clear)
    CALL sp_next_id('users', p_user_id);
    SET v_salt = HEX(RANDOM_BYTES(16));
    INSERT INTO users (user_id, username, email, password_hash)
    VALUES (p_user_id, p_username, LOWER(p_email), fn_hash_password(p_password, v_salt));

    -- 1.4 Assign role
    INSERT INTO user_roles (user_id, role_id)
    SELECT p_user_id, role_id FROM roles WHERE role_name = p_role_name;

    -- profile row (admins / instructors / students)
    CALL sp_create_profile(p_user_id, p_role_name, p_first_name, p_last_name, p_profile_id);
END $$

-- #############################################################################
-- MODULE 1 : USER MANAGEMENT
-- #############################################################################

-- -----------------------------------------------------------------------------
-- sp_authenticate_user : verify credentials (all roles / login screen)
-- Never raises an error for bad credentials (so the LOGIN_FAILED audit row is
-- kept); returns p_success = FALSE and a generic message instead (prevents
-- username enumeration).
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_authenticate_user $$
CREATE PROCEDURE sp_authenticate_user(IN p_username VARCHAR(50), IN p_password VARCHAR(255),
                                      OUT p_success BOOLEAN, OUT p_user_id VARCHAR(10),
                                      OUT p_roles VARCHAR(200), OUT p_message VARCHAR(100))
    SQL SECURITY DEFINER
BEGIN
    DECLARE v_user_id VARCHAR(10);
    DECLARE v_hash    VARCHAR(255);
    DECLARE v_status  VARCHAR(10);

    SELECT user_id, password_hash, status INTO v_user_id, v_hash, v_status
      FROM users WHERE username = p_username;

    IF v_user_id IS NOT NULL AND v_status = 'Active' AND fn_verify_password(p_password, v_hash) THEN
        SET p_success = TRUE;
        SET p_user_id = v_user_id;
        SET p_roles   = (SELECT GROUP_CONCAT(r.role_name ORDER BY r.role_name)
                           FROM user_roles ur JOIN roles r ON r.role_id = ur.role_id
                          WHERE ur.user_id = v_user_id);
        SET p_message = 'Login successful';
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description)
        VALUES ('LOGIN_SUCCESS', 'users', v_user_id, v_user_id, USER(), CONCAT('User ', p_username, ' logged in'));
    ELSE
        SET p_success = FALSE;
        SET p_user_id = NULL;
        SET p_roles   = NULL;
        SET p_message = 'Invalid username or password';
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description)
        VALUES ('LOGIN_FAILED', 'users', v_user_id, NULL, USER(),
                CONCAT('Failed login for username "', LEFT(COALESCE(p_username, ''), 50), '"',
                       IF(v_status = 'Inactive', ' (inactive account)', '')));
    END IF;
END $$

-- -----------------------------------------------------------------------------
-- sp_register_student / sp_register_instructor  (Administrator)
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_register_student $$
CREATE PROCEDURE sp_register_student(IN p_actor_user_id VARCHAR(10), IN p_username VARCHAR(50),
                                     IN p_email VARCHAR(100), IN p_password VARCHAR(255),
                                     IN p_first_name VARCHAR(50), IN p_last_name VARCHAR(50),
                                     OUT p_user_id VARCHAR(10), OUT p_student_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;
    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    CALL sp_register_user('Student', p_username, p_email, p_password, p_first_name, p_last_name,
                          p_user_id, p_student_id);
    COMMIT;
    SET @app_user_id = NULL;
END $$

DROP PROCEDURE IF EXISTS sp_register_instructor $$
CREATE PROCEDURE sp_register_instructor(IN p_actor_user_id VARCHAR(10), IN p_username VARCHAR(50),
                                        IN p_email VARCHAR(100), IN p_password VARCHAR(255),
                                        IN p_first_name VARCHAR(50), IN p_last_name VARCHAR(50),
                                        OUT p_user_id VARCHAR(10), OUT p_instructor_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;
    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    CALL sp_register_user('Instructor', p_username, p_email, p_password, p_first_name, p_last_name,
                          p_user_id, p_instructor_id);
    COMMIT;
    SET @app_user_id = NULL;
END $$

-- -----------------------------------------------------------------------------
-- sp_assign_role (Administrator) - DFD 1.4. Creates the matching profile row if
-- the user does not have one yet (names copied from an existing profile).
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_assign_role $$
CREATE PROCEDURE sp_assign_role(IN p_actor_user_id VARCHAR(10), IN p_user_id VARCHAR(10),
                                IN p_role_name VARCHAR(50))
    SQL SECURITY DEFINER
BEGIN
    DECLARE v_role_id    VARCHAR(10);
    DECLARE v_first      VARCHAR(50);
    DECLARE v_last       VARCHAR(50);
    DECLARE v_profile_id VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');

    SET v_role_id = (SELECT role_id FROM roles WHERE role_name = p_role_name);
    IF v_role_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown role';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User not found';
    END IF;
    IF EXISTS (SELECT 1 FROM user_roles WHERE user_id = p_user_id AND role_id = v_role_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User already has this role';
    END IF;

    INSERT INTO user_roles (user_id, role_id) VALUES (p_user_id, v_role_id);

    -- make sure the role has its profile row
    IF (p_role_name = 'Administrator' AND NOT EXISTS (SELECT 1 FROM admins      WHERE user_id = p_user_id))
    OR (p_role_name = 'Instructor'    AND NOT EXISTS (SELECT 1 FROM instructors WHERE user_id = p_user_id))
    OR (p_role_name = 'Student'       AND NOT EXISTS (SELECT 1 FROM students    WHERE user_id = p_user_id)) THEN
        SELECT first_name, last_name INTO v_first, v_last FROM (
              SELECT first_name, last_name FROM admins      WHERE user_id = p_user_id
              UNION ALL
              SELECT first_name, last_name FROM instructors WHERE user_id = p_user_id
              UNION ALL
              SELECT first_name, last_name FROM students    WHERE user_id = p_user_id) n
        LIMIT 1;
        CALL sp_create_profile(p_user_id, p_role_name, v_first, v_last, v_profile_id);
    END IF;

    COMMIT;
    SET @app_user_id = NULL;
END $$

-- -----------------------------------------------------------------------------
-- sp_revoke_role (Administrator)
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_revoke_role $$
CREATE PROCEDURE sp_revoke_role(IN p_actor_user_id VARCHAR(10), IN p_user_id VARCHAR(10),
                                IN p_role_name VARCHAR(50))
    SQL SECURITY DEFINER
BEGIN
    DECLARE v_role_id VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');

    SET v_role_id = (SELECT role_id FROM roles WHERE role_name = p_role_name);
    IF NOT EXISTS (SELECT 1 FROM user_roles WHERE user_id = p_user_id AND role_id = v_role_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User does not have this role';
    END IF;
    IF p_user_id = p_actor_user_id AND p_role_name = 'Administrator' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Administrators cannot revoke their own Administrator role';
    END IF;
    IF (SELECT COUNT(*) FROM user_roles WHERE user_id = p_user_id) = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A user must keep at least one role';
    END IF;

    DELETE FROM user_roles WHERE user_id = p_user_id AND role_id = v_role_id;
    COMMIT;
    SET @app_user_id = NULL;
END $$

-- -----------------------------------------------------------------------------
-- sp_update_user (Administrator) - email and profile names; NULL = unchanged
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_update_user $$
CREATE PROCEDURE sp_update_user(IN p_actor_user_id VARCHAR(10), IN p_user_id VARCHAR(10),
                                IN p_email VARCHAR(100), IN p_first_name VARCHAR(50),
                                IN p_last_name VARCHAR(50))
    SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');

    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User not found';
    END IF;
    IF p_email IS NOT NULL THEN
        IF NOT REGEXP_LIKE(p_email, '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid email address';
        END IF;
        IF EXISTS (SELECT 1 FROM users WHERE email = LOWER(p_email) AND user_id <> p_user_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email already registered';
        END IF;
        UPDATE users SET email = LOWER(p_email) WHERE user_id = p_user_id AND email <> LOWER(p_email);
    END IF;
    IF p_first_name IS NOT NULL OR p_last_name IS NOT NULL THEN
        UPDATE admins      SET first_name = COALESCE(TRIM(p_first_name), first_name),
                               last_name  = COALESCE(TRIM(p_last_name),  last_name)  WHERE user_id = p_user_id;
        UPDATE instructors SET first_name = COALESCE(TRIM(p_first_name), first_name),
                               last_name  = COALESCE(TRIM(p_last_name),  last_name)  WHERE user_id = p_user_id;
        UPDATE students    SET first_name = COALESCE(TRIM(p_first_name), first_name),
                               last_name  = COALESCE(TRIM(p_last_name),  last_name)  WHERE user_id = p_user_id;
    END IF;
    COMMIT;
    SET @app_user_id = NULL;
END $$

-- -----------------------------------------------------------------------------
-- sp_set_user_status (Administrator) - activate / deactivate an account.
-- Users are never physically deleted (no D on Users in the CRUD matrix).
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_set_user_status $$
CREATE PROCEDURE sp_set_user_status(IN p_actor_user_id VARCHAR(10), IN p_user_id VARCHAR(10),
                                    IN p_status VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    IF p_status NOT IN ('Active','Inactive') OR p_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Status must be Active or Inactive';
    END IF;
    IF p_user_id = p_actor_user_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Administrators cannot change their own account status';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User not found';
    END IF;
    UPDATE users SET status = p_status WHERE user_id = p_user_id;
    COMMIT;
    SET @app_user_id = NULL;
END $$

-- -----------------------------------------------------------------------------
-- sp_change_password (any role, own account only)
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_change_password $$
CREATE PROCEDURE sp_change_password(IN p_actor_user_id VARCHAR(10), IN p_old_password VARCHAR(255),
                                    IN p_new_password VARCHAR(255))
    SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');
    IF NOT fn_verify_password(p_old_password, (SELECT password_hash FROM users WHERE user_id = p_actor_user_id)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Current password is incorrect';
    END IF;
    IF NOT fn_is_strong_password(p_new_password) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Weak password: minimum 8 characters with upper-case, lower-case and a digit';
    END IF;
    UPDATE users SET password_hash = fn_hash_password(p_new_password, HEX(RANDOM_BYTES(16)))
     WHERE user_id = p_actor_user_id;
    COMMIT;
    SET @app_user_id = NULL;
END $$

-- -----------------------------------------------------------------------------
-- sp_get_user : Administrators may read any user; others only themselves.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_get_user $$
CREATE PROCEDURE sp_get_user(IN p_actor_user_id VARCHAR(10), IN p_user_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET @app_user_id = NULL; RESIGNAL; END;
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');
    IF p_user_id <> p_actor_user_id AND NOT fn_user_has_role(p_actor_user_id, 'Administrator') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ACCESS DENIED: you may only view your own account';
    END IF;
    SELECT * FROM v_user_directory WHERE user_id = p_user_id;
    SET @app_user_id = NULL;
END $$

-- #############################################################################
-- MODULE 2 : SUBJECT MANAGEMENT  (Administrator)
-- #############################################################################
DROP PROCEDURE IF EXISTS sp_create_subject $$
CREATE PROCEDURE sp_create_subject(IN p_actor_user_id VARCHAR(10), IN p_subject_name VARCHAR(100),
                                   IN p_description TEXT, OUT p_subject_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    -- 2.1 Validate subject information
    IF p_subject_name IS NULL OR TRIM(p_subject_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject name is required';
    END IF;
    IF EXISTS (SELECT 1 FROM subjects WHERE subject_name = TRIM(p_subject_name)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject name already exists';
    END IF;
    -- 2.2 Create subject / 2.3 Store subject record
    CALL sp_next_id('subjects', p_subject_id);
    INSERT INTO subjects (subject_id, subject_name, description)
    VALUES (p_subject_id, TRIM(p_subject_name), p_description);
    COMMIT;
    SET @app_user_id = NULL;
END $$

DROP PROCEDURE IF EXISTS sp_update_subject $$
CREATE PROCEDURE sp_update_subject(IN p_actor_user_id VARCHAR(10), IN p_subject_id VARCHAR(10),
                                   IN p_subject_name VARCHAR(100), IN p_description TEXT)
    SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    IF NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = p_subject_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject not found';
    END IF;
    IF p_subject_name IS NOT NULL AND TRIM(p_subject_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject name cannot be blank';
    END IF;
    IF EXISTS (SELECT 1 FROM subjects WHERE subject_name = TRIM(p_subject_name) AND subject_id <> p_subject_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject name already exists';
    END IF;
    UPDATE subjects
       SET subject_name = COALESCE(TRIM(p_subject_name), subject_name),
           description  = COALESCE(p_description, description)
     WHERE subject_id = p_subject_id;
    COMMIT;
    SET @app_user_id = NULL;
END $$

DROP PROCEDURE IF EXISTS sp_delete_subject $$
CREATE PROCEDURE sp_delete_subject(IN p_actor_user_id VARCHAR(10), IN p_subject_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    IF NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = p_subject_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject not found';
    END IF;
    -- "delete where permitted": a subject still in use cannot be removed
    IF EXISTS (SELECT 1 FROM materials WHERE subject_id = p_subject_id)
       OR EXISTS (SELECT 1 FROM quizzes WHERE subject_id = p_subject_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject has materials or quizzes and cannot be deleted';
    END IF;
    DELETE FROM subjects WHERE subject_id = p_subject_id;
    COMMIT;
    SET @app_user_id = NULL;
END $$

-- #############################################################################
-- MODULE 3 : LEARNING MATERIAL MANAGEMENT  (Instructor, own materials only)
-- #############################################################################
DROP PROCEDURE IF EXISTS sp_upload_material $$
CREATE PROCEDURE sp_upload_material(IN p_actor_user_id VARCHAR(10), IN p_subject_id VARCHAR(10),
                                    IN p_title VARCHAR(255), IN p_file_path VARCHAR(255),
                                    OUT p_material_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    -- 3.1 Select subject
    IF NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = p_subject_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject not found';
    END IF;
    IF p_title IS NULL OR TRIM(p_title) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Material title is required';
    END IF;
    IF NOT fn_is_safe_file_path(p_file_path) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid file path';
    END IF;
    -- 3.2 Upload material / 3.3 Store material record
    CALL sp_next_id('materials', p_material_id);
    INSERT INTO materials (material_id, subject_id, instructor_id, title, file_path)
    VALUES (p_material_id, p_subject_id, fn_get_instructor_id(p_actor_user_id), TRIM(p_title), TRIM(p_file_path));
    COMMIT;
    SET @app_user_id = NULL;
END $$

DROP PROCEDURE IF EXISTS sp_update_material $$
CREATE PROCEDURE sp_update_material(IN p_actor_user_id VARCHAR(10), IN p_material_id VARCHAR(10),
                                    IN p_subject_id VARCHAR(10), IN p_title VARCHAR(255),
                                    IN p_file_path VARCHAR(255))
    SQL SECURITY DEFINER
BEGIN
    DECLARE v_owner VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    SET v_owner = (SELECT instructor_id FROM materials WHERE material_id = p_material_id FOR UPDATE);
    IF v_owner IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Material not found';
    END IF;
    IF v_owner <> fn_get_instructor_id(p_actor_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ACCESS DENIED: you can only modify your own materials';
    END IF;
    IF p_subject_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = p_subject_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject not found';
    END IF;
    IF p_title IS NOT NULL AND TRIM(p_title) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Material title cannot be blank';
    END IF;
    IF p_file_path IS NOT NULL AND NOT fn_is_safe_file_path(p_file_path) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid file path';
    END IF;
    UPDATE materials
       SET subject_id = COALESCE(p_subject_id, subject_id),
           title      = COALESCE(TRIM(p_title), title),
           file_path  = COALESCE(TRIM(p_file_path), file_path)
     WHERE material_id = p_material_id;
    COMMIT;
    SET @app_user_id = NULL;
END $$

DROP PROCEDURE IF EXISTS sp_delete_material $$
CREATE PROCEDURE sp_delete_material(IN p_actor_user_id VARCHAR(10), IN p_material_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE v_owner VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    SET v_owner = (SELECT instructor_id FROM materials WHERE material_id = p_material_id FOR UPDATE);
    IF v_owner IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Material not found';
    END IF;
    IF v_owner <> fn_get_instructor_id(p_actor_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ACCESS DENIED: you can only delete your own materials';
    END IF;
    DELETE FROM materials WHERE material_id = p_material_id;
    COMMIT;
    SET @app_user_id = NULL;
END $$

DROP PROCEDURE IF EXISTS sp_get_materials_by_subject $$
CREATE PROCEDURE sp_get_materials_by_subject(IN p_actor_user_id VARCHAR(10), IN p_subject_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET @app_user_id = NULL; RESIGNAL; END;
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');
    SELECT * FROM v_learning_materials
     WHERE subject_id = p_subject_id
     ORDER BY uploaded_at, material_id;
    SET @app_user_id = NULL;
END $$

-- #############################################################################
-- MODULE 4 : QUIZ MANAGEMENT  (Instructor, own quizzes only)
-- #############################################################################

-- Internal: verify that the actor owns the quiz and return the owner id
DROP PROCEDURE IF EXISTS sp_assert_quiz_owner $$
CREATE PROCEDURE sp_assert_quiz_owner(IN p_actor_user_id VARCHAR(10), IN p_quiz_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE v_owner VARCHAR(10);
    SET v_owner = (SELECT instructor_id FROM quizzes WHERE quiz_id = p_quiz_id);
    IF v_owner IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz not found';
    END IF;
    IF v_owner <> COALESCE(fn_get_instructor_id(p_actor_user_id), '') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ACCESS DENIED: you can only manage your own quizzes';
    END IF;
END $$

DROP PROCEDURE IF EXISTS sp_create_quiz $$
CREATE PROCEDURE sp_create_quiz(IN p_actor_user_id VARCHAR(10), IN p_subject_id VARCHAR(10),
                                IN p_title VARCHAR(255), OUT p_quiz_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    IF NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = p_subject_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject not found';
    END IF;
    IF p_title IS NULL OR TRIM(p_title) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz title is required';
    END IF;
    CALL sp_next_id('quizzes', p_quiz_id);
    INSERT INTO quizzes (quiz_id, subject_id, instructor_id, title)
    VALUES (p_quiz_id, p_subject_id, fn_get_instructor_id(p_actor_user_id), TRIM(p_title));
    COMMIT;
    SET @app_user_id = NULL;
END $$

DROP PROCEDURE IF EXISTS sp_update_quiz $$
CREATE PROCEDURE sp_update_quiz(IN p_actor_user_id VARCHAR(10), IN p_quiz_id VARCHAR(10),
                                IN p_subject_id VARCHAR(10), IN p_title VARCHAR(255))
    SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    CALL sp_assert_quiz_owner(p_actor_user_id, p_quiz_id);
    IF p_subject_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = p_subject_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject not found';
    END IF;
    IF p_title IS NOT NULL AND TRIM(p_title) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz title cannot be blank';
    END IF;
    UPDATE quizzes
       SET subject_id = COALESCE(p_subject_id, subject_id),
           title      = COALESCE(TRIM(p_title), title)
     WHERE quiz_id = p_quiz_id;
    COMMIT;
    SET @app_user_id = NULL;
END $$

DROP PROCEDURE IF EXISTS sp_delete_quiz $$
CREATE PROCEDURE sp_delete_quiz(IN p_actor_user_id VARCHAR(10), IN p_quiz_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    CALL sp_assert_quiz_owner(p_actor_user_id, p_quiz_id);
    IF EXISTS (SELECT 1 FROM quiz_results WHERE quiz_id = p_quiz_id)
       OR EXISTS (SELECT 1 FROM student_answers sa JOIN questions q ON q.question_id = sa.question_id
                   WHERE q.quiz_id = p_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz already has student answers or results and cannot be deleted';
    END IF;
    -- explicit child delete so each question deletion is audited by its trigger
    DELETE FROM questions WHERE quiz_id = p_quiz_id;
    DELETE FROM quizzes   WHERE quiz_id = p_quiz_id;
    COMMIT;
    SET @app_user_id = NULL;
END $$

-- p_correct_answer may be the option letter (A-D) or the exact option text
DROP PROCEDURE IF EXISTS sp_add_question $$
CREATE PROCEDURE sp_add_question(IN p_actor_user_id VARCHAR(10), IN p_quiz_id VARCHAR(10),
                                 IN p_question_text TEXT,
                                 IN p_option_a VARCHAR(255), IN p_option_b VARCHAR(255),
                                 IN p_option_c VARCHAR(255), IN p_option_d VARCHAR(255),
                                 IN p_correct_answer VARCHAR(255), OUT p_question_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE v_correct VARCHAR(255);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    CALL sp_assert_quiz_owner(p_actor_user_id, p_quiz_id);
    IF EXISTS (SELECT 1 FROM quiz_results WHERE quiz_id = p_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz already has submitted results; questions are locked';
    END IF;
    IF p_question_text IS NULL OR TRIM(p_question_text) = ''
       OR p_option_a IS NULL OR p_option_b IS NULL OR p_option_c IS NULL OR p_option_d IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Question text and all four options are required';
    END IF;
    SET v_correct = fn_resolve_option(p_correct_answer, p_option_a, p_option_b, p_option_c, p_option_d);
    IF v_correct IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Correct answer must be A, B, C, D or the exact text of an option';
    END IF;
    CALL sp_next_id('questions', p_question_id);
    INSERT INTO questions (question_id, quiz_id, question_text, correct_answer,
                           option_a, option_b, option_c, option_d)
    VALUES (p_question_id, p_quiz_id, TRIM(p_question_text), v_correct,
            p_option_a, p_option_b, p_option_c, p_option_d);
    COMMIT;
    SET @app_user_id = NULL;
END $$

-- NULL parameters keep the current value
DROP PROCEDURE IF EXISTS sp_update_question $$
CREATE PROCEDURE sp_update_question(IN p_actor_user_id VARCHAR(10), IN p_question_id VARCHAR(10),
                                    IN p_question_text TEXT,
                                    IN p_option_a VARCHAR(255), IN p_option_b VARCHAR(255),
                                    IN p_option_c VARCHAR(255), IN p_option_d VARCHAR(255),
                                    IN p_correct_answer VARCHAR(255))
    SQL SECURITY DEFINER
BEGIN
    DECLARE v_quiz_id VARCHAR(10);
    DECLARE v_a, v_b, v_c, v_d, v_cur, v_correct VARCHAR(255);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    SELECT quiz_id, option_a, option_b, option_c, option_d, correct_answer
      INTO v_quiz_id, v_a, v_b, v_c, v_d, v_cur
      FROM questions WHERE question_id = p_question_id FOR UPDATE;
    IF v_quiz_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Question not found';
    END IF;
    CALL sp_assert_quiz_owner(p_actor_user_id, v_quiz_id);
    IF EXISTS (SELECT 1 FROM student_answers WHERE question_id = p_question_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Question has already been answered and is locked';
    END IF;
    SET v_a = COALESCE(p_option_a, v_a);
    SET v_b = COALESCE(p_option_b, v_b);
    SET v_c = COALESCE(p_option_c, v_c);
    SET v_d = COALESCE(p_option_d, v_d);
    SET v_correct = fn_resolve_option(COALESCE(p_correct_answer, v_cur), v_a, v_b, v_c, v_d);
    IF v_correct IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Correct answer must be A, B, C, D or the exact text of an option';
    END IF;
    IF p_question_text IS NOT NULL AND TRIM(p_question_text) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Question text cannot be blank';
    END IF;
    UPDATE questions
       SET question_text  = COALESCE(TRIM(p_question_text), question_text),
           option_a = v_a, option_b = v_b, option_c = v_c, option_d = v_d,
           correct_answer = v_correct
     WHERE question_id = p_question_id;
    COMMIT;
    SET @app_user_id = NULL;
END $$

DROP PROCEDURE IF EXISTS sp_delete_question $$
CREATE PROCEDURE sp_delete_question(IN p_actor_user_id VARCHAR(10), IN p_question_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE v_quiz_id VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    SET v_quiz_id = (SELECT quiz_id FROM questions WHERE question_id = p_question_id);
    IF v_quiz_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Question not found';
    END IF;
    CALL sp_assert_quiz_owner(p_actor_user_id, v_quiz_id);
    IF EXISTS (SELECT 1 FROM student_answers WHERE question_id = p_question_id)
       OR EXISTS (SELECT 1 FROM quiz_results WHERE quiz_id = v_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Question has already been answered and cannot be deleted';
    END IF;
    DELETE FROM questions WHERE question_id = p_question_id;
    COMMIT;
    SET @app_user_id = NULL;
END $$

-- Students (and non-owner instructors) receive the questions WITHOUT the key.
DROP PROCEDURE IF EXISTS sp_get_quiz_questions $$
CREATE PROCEDURE sp_get_quiz_questions(IN p_actor_user_id VARCHAR(10), IN p_quiz_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET @app_user_id = NULL; RESIGNAL; END;
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');
    IF NOT EXISTS (SELECT 1 FROM quizzes WHERE quiz_id = p_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz not found';
    END IF;
    IF fn_user_has_role(p_actor_user_id, 'Administrator')
       OR (SELECT instructor_id FROM quizzes WHERE quiz_id = p_quiz_id) = COALESCE(fn_get_instructor_id(p_actor_user_id), '') THEN
        SELECT question_id, question_text, option_a, option_b, option_c, option_d, correct_answer
          FROM questions WHERE quiz_id = p_quiz_id ORDER BY question_id;
    ELSE
        SELECT question_id, question_text, option_a, option_b, option_c, option_d
          FROM questions WHERE quiz_id = p_quiz_id ORDER BY question_id;
    END IF;
    SET @app_user_id = NULL;
END $$

-- #############################################################################
-- MODULE 5 : ASSESSMENT PROCESSING  (Student)
-- #############################################################################

-- -----------------------------------------------------------------------------
-- sp_submit_answer : store one answer (DFD 5.2 Process Answers).
-- p_answer may be the option letter A-D or the exact option text.
-- is_correct is computed by trigger trg_student_answers_bi - the procedure does
-- NOT reveal correctness before the quiz is submitted.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_submit_answer $$
CREATE PROCEDURE sp_submit_answer(IN p_actor_user_id VARCHAR(10), IN p_question_id VARCHAR(10),
                                  IN p_answer VARCHAR(255), OUT p_answer_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE v_student_id VARCHAR(10);
    DECLARE v_quiz_id    VARCHAR(10);
    DECLARE v_a, v_b, v_c, v_d, v_answer VARCHAR(255);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Student');
    SET v_student_id = fn_get_student_id(p_actor_user_id);

    SELECT quiz_id, option_a, option_b, option_c, option_d
      INTO v_quiz_id, v_a, v_b, v_c, v_d
      FROM questions WHERE question_id = p_question_id;
    IF v_quiz_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Question not found';
    END IF;
    IF EXISTS (SELECT 1 FROM quiz_results WHERE student_id = v_student_id AND quiz_id = v_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz already submitted; answers are locked';
    END IF;
    IF EXISTS (SELECT 1 FROM student_answers WHERE student_id = v_student_id AND question_id = p_question_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Question already answered';
    END IF;
    -- validate the submitted answer against the question options
    SET v_answer = fn_resolve_option(p_answer, v_a, v_b, v_c, v_d);
    IF v_answer IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Answer must be A, B, C, D or the exact text of an option';
    END IF;

    CALL sp_next_id('student_answers', p_answer_id);
    INSERT INTO student_answers (answer_id, student_id, question_id, student_answer)
    VALUES (p_answer_id, v_student_id, p_question_id, v_answer);
    COMMIT;
    SET @app_user_id = NULL;
END $$

-- -----------------------------------------------------------------------------
-- sp_submit_quiz : DFD 5.3 Process quiz submission -> 5.4 Generate result.
-- Score = correct answers / total questions * 100 (unanswered = incorrect).
-- The score is (re)computed by trigger trg_quiz_results_bi, so it cannot be
-- forged by the caller.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_submit_quiz $$
CREATE PROCEDURE sp_submit_quiz(IN p_actor_user_id VARCHAR(10), IN p_quiz_id VARCHAR(10),
                                OUT p_result_id VARCHAR(10), OUT p_score DECIMAL(5,2))
    SQL SECURITY DEFINER
BEGIN
    DECLARE v_student_id VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Student');
    SET v_student_id = fn_get_student_id(p_actor_user_id);

    IF NOT EXISTS (SELECT 1 FROM quizzes WHERE quiz_id = p_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz not found';
    END IF;
    IF fn_question_count(p_quiz_id) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz has no questions';
    END IF;
    IF EXISTS (SELECT 1 FROM quiz_results WHERE student_id = v_student_id AND quiz_id = p_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz already submitted';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM student_answers sa JOIN questions q ON q.question_id = sa.question_id
                    WHERE sa.student_id = v_student_id AND q.quiz_id = p_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No answers submitted for this quiz';
    END IF;

    CALL sp_next_id('quiz_results', p_result_id);
    INSERT INTO quiz_results (result_id, student_id, quiz_id, score)
    VALUES (p_result_id, v_student_id, p_quiz_id, 0);       -- trigger computes the real score
    SET p_score = (SELECT score FROM quiz_results WHERE result_id = p_result_id);
    COMMIT;
    SET @app_user_id = NULL;
END $$

-- -----------------------------------------------------------------------------
-- sp_get_student_results : "View Results"
--   Student       -> own results only (p_student_id ignored if NULL / must match)
--   Instructor    -> results of quizzes the instructor owns
--   Administrator -> all results (optionally filtered by student)
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_get_student_results $$
CREATE PROCEDURE sp_get_student_results(IN p_actor_user_id VARCHAR(10), IN p_student_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE v_own_student VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET @app_user_id = NULL; RESIGNAL; END;
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');

    IF fn_user_has_role(p_actor_user_id, 'Administrator') THEN
        SELECT * FROM v_quiz_results_detail
         WHERE p_student_id IS NULL OR student_id = p_student_id
         ORDER BY student_id, quiz_id;
    ELSEIF fn_user_has_role(p_actor_user_id, 'Instructor') THEN
        SELECT * FROM v_quiz_results_detail
         WHERE instructor_id = fn_get_instructor_id(p_actor_user_id)
           AND (p_student_id IS NULL OR student_id = p_student_id)
         ORDER BY quiz_id, student_id;
    ELSE
        SET v_own_student = fn_get_student_id(p_actor_user_id);
        IF p_student_id IS NOT NULL AND p_student_id <> v_own_student THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ACCESS DENIED: students may only view their own results';
        END IF;
        SELECT result_id, quiz_id, quiz_title, subject_name, score, correct_answers, total_questions
          FROM v_quiz_results_detail
         WHERE student_id = v_own_student
         ORDER BY quiz_id;
    END IF;
    SET @app_user_id = NULL;
END $$

-- -----------------------------------------------------------------------------
-- sp_get_answer_review : per-question review of a SUBMITTED quiz.
-- Students: own submission only; Instructor: own quiz; Administrator: any.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_get_answer_review $$
CREATE PROCEDURE sp_get_answer_review(IN p_actor_user_id VARCHAR(10), IN p_quiz_id VARCHAR(10),
                                      IN p_student_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE v_student VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET @app_user_id = NULL; RESIGNAL; END;
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');

    IF fn_user_has_role(p_actor_user_id, 'Administrator') THEN
        SET v_student = p_student_id;
    ELSEIF fn_user_has_role(p_actor_user_id, 'Instructor') THEN
        CALL sp_assert_quiz_owner(p_actor_user_id, p_quiz_id);
        SET v_student = p_student_id;
    ELSE
        SET v_student = fn_get_student_id(p_actor_user_id);
        IF p_student_id IS NOT NULL AND p_student_id <> v_student THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ACCESS DENIED: students may only view their own answers';
        END IF;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM quiz_results WHERE student_id = v_student AND quiz_id = p_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No submitted result for this student and quiz';
    END IF;

    SELECT q.question_id, q.question_text, sa.student_answer, q.correct_answer,
           COALESCE(sa.is_correct, FALSE) AS is_correct
      FROM questions q
      LEFT JOIN student_answers sa ON sa.question_id = q.question_id AND sa.student_id = v_student
     WHERE q.quiz_id = p_quiz_id
     ORDER BY q.question_id;
    SET @app_user_id = NULL;
END $$

-- #############################################################################
-- MODULE 6 : REPORTING AND MONITORING
-- #############################################################################

-- DFD 6.1/6.2 : student performance report (Administrator: all subjects,
-- Instructor: own quizzes). Optional subject filter.
DROP PROCEDURE IF EXISTS sp_report_student_performance $$
CREATE PROCEDURE sp_report_student_performance(IN p_actor_user_id VARCHAR(10), IN p_subject_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE v_instructor VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET @app_user_id = NULL; RESIGNAL; END;
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor');

    SET v_instructor = IF(fn_user_has_role(p_actor_user_id, 'Administrator'), NULL,
                          fn_get_instructor_id(p_actor_user_id));

    SELECT st.student_id,
           CONCAT(st.first_name, ' ', st.last_name) AS student_name,
           sb.subject_name,
           COUNT(qr.result_id)        AS quizzes_taken,
           ROUND(AVG(qr.score), 2)    AS average_score,
           MAX(qr.score)              AS highest_score,
           MIN(qr.score)              AS lowest_score
      FROM quiz_results qr
      JOIN students st ON st.student_id = qr.student_id
      JOIN quizzes  q  ON q.quiz_id     = qr.quiz_id
      JOIN subjects sb ON sb.subject_id = q.subject_id
     WHERE (p_subject_id IS NULL OR q.subject_id = p_subject_id)
       AND (v_instructor IS NULL OR q.instructor_id = v_instructor)
     GROUP BY st.student_id, st.first_name, st.last_name, sb.subject_id, sb.subject_name
     ORDER BY sb.subject_name, average_score DESC, st.student_id;
    SET @app_user_id = NULL;
END $$

-- Quiz results report: per-student rows + summary statistics (two result sets)
DROP PROCEDURE IF EXISTS sp_report_quiz_results $$
CREATE PROCEDURE sp_report_quiz_results(IN p_actor_user_id VARCHAR(10), IN p_quiz_id VARCHAR(10))
    SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET @app_user_id = NULL; RESIGNAL; END;
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor');
    IF NOT fn_user_has_role(p_actor_user_id, 'Administrator') THEN
        CALL sp_assert_quiz_owner(p_actor_user_id, p_quiz_id);
    ELSEIF NOT EXISTS (SELECT 1 FROM quizzes WHERE quiz_id = p_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz not found';
    END IF;

    SELECT result_id, student_id, student_name, score, correct_answers, total_questions
      FROM v_quiz_results_detail
     WHERE quiz_id = p_quiz_id
     ORDER BY score DESC, student_id;

    SELECT p_quiz_id                AS quiz_id,
           COUNT(*)                 AS submissions,
           ROUND(AVG(score), 2)     AS average_score,
           MAX(score)               AS highest_score,
           MIN(score)               AS lowest_score
      FROM quiz_results
     WHERE quiz_id = p_quiz_id;
    SET @app_user_id = NULL;
END $$

-- DFD 6.3 : retrieve audit information (Administrator). All filters optional.
DROP PROCEDURE IF EXISTS sp_report_audit_logs $$
CREATE PROCEDURE sp_report_audit_logs(IN p_actor_user_id VARCHAR(10), IN p_table_name VARCHAR(50),
                                      IN p_action_type VARCHAR(50), IN p_from DATETIME,
                                      IN p_to DATETIME, IN p_limit INT)
    SQL SECURITY DEFINER
BEGIN
    DECLARE v_limit INT DEFAULT 100;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET @app_user_id = NULL; RESIGNAL; END;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    SET v_limit = LEAST(GREATEST(COALESCE(p_limit, 100), 1), 10000);
    SELECT * FROM v_audit_trail
     WHERE (p_table_name  IS NULL OR table_name  = p_table_name)
       AND (p_action_type IS NULL OR action_type = p_action_type)
       AND (p_from IS NULL OR log_timestamp >= p_from)
       AND (p_to   IS NULL OR log_timestamp <  p_to)
     ORDER BY log_id DESC
     LIMIT v_limit;   -- local variables are allowed in LIMIT inside stored programs
    SET @app_user_id = NULL;
END $$

-- Activity monitoring summary (Administrator)
DROP PROCEDURE IF EXISTS sp_report_system_activity $$
CREATE PROCEDURE sp_report_system_activity(IN p_actor_user_id VARCHAR(10), IN p_days INT)
    SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET @app_user_id = NULL; RESIGNAL; END;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    SELECT table_name, action_type, COUNT(*) AS operations,
           COUNT(DISTINCT performed_by) AS distinct_users,
           MAX(log_timestamp) AS last_activity
      FROM audit_logs
     WHERE log_timestamp >= NOW() - INTERVAL COALESCE(p_days, 30) DAY
     GROUP BY table_name, action_type
     ORDER BY table_name, action_type;
    SET @app_user_id = NULL;
END $$

DELIMITER ;

SELECT routine_name, routine_type, security_type
FROM information_schema.routines
WHERE routine_schema = 'studync_db' AND routine_type = 'PROCEDURE'
ORDER BY routine_name;
