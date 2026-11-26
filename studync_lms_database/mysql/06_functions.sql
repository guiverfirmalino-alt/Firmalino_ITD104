-- =============================================================================
-- StudyNC LMS (MySQL 8.0+)
-- File 06 : Stored functions
-- -----------------------------------------------------------------------------
-- Every function declares its characteristic (DETERMINISTIC / NO SQL /
-- READS SQL DATA). This is mandatory in MySQL 8 when binary logging is on
-- (the default), otherwise CREATE FUNCTION fails with error 1418.
-- =============================================================================
USE studync_db;

DELIMITER $$

-- -----------------------------------------------------------------------------
-- fn_format_id('USR', 7) -> 'USR0000007'   (3-letter prefix + 7 digits = 10)
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_format_id $$
CREATE FUNCTION fn_format_id(p_prefix CHAR(3), p_number INT UNSIGNED)
RETURNS VARCHAR(10)
DETERMINISTIC NO SQL
BEGIN
    IF p_number > 9999999 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Identifier range exhausted';
    END IF;
    RETURN CONCAT(p_prefix, LPAD(p_number, 7, '0'));
END $$

-- -----------------------------------------------------------------------------
-- Password hashing
-- MySQL has no built-in bcrypt/argon2, so StudyNC uses a salted, iterated
-- (key-stretched) SHA-256:
--     h0 = SHA256(salt || password);  h(i) = SHA256(h(i-1) || salt)  x 5000
-- Stored format:  $sha256$<iterations>$<32-hex salt>$<64-hex hash>
-- The random salt (RANDOM_BYTES) makes identical passwords hash differently.
-- In production the application tier should hash with bcrypt/argon2 instead.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_hash_password_iter $$
CREATE FUNCTION fn_hash_password_iter(p_plain VARCHAR(255), p_salt VARCHAR(64), p_iterations INT)
RETURNS VARCHAR(255)
DETERMINISTIC NO SQL
BEGIN
    DECLARE v_hash CHAR(64);
    DECLARE i INT DEFAULT 1;
    SET v_hash = SHA2(CONCAT(p_salt, p_plain), 256);
    WHILE i < p_iterations DO
        SET v_hash = SHA2(CONCAT(v_hash, p_salt), 256);
        SET i = i + 1;
    END WHILE;
    RETURN CONCAT('$sha256$', p_iterations, '$', p_salt, '$', v_hash);
END $$

DROP FUNCTION IF EXISTS fn_hash_password $$
CREATE FUNCTION fn_hash_password(p_plain VARCHAR(255), p_salt VARCHAR(64))
RETURNS VARCHAR(255)
DETERMINISTIC NO SQL
BEGIN
    RETURN fn_hash_password_iter(p_plain, p_salt, 5000);
END $$

-- Recomputes the hash with the stored salt/iterations and compares.
DROP FUNCTION IF EXISTS fn_verify_password $$
CREATE FUNCTION fn_verify_password(p_plain VARCHAR(255), p_stored VARCHAR(255))
RETURNS BOOLEAN
DETERMINISTIC NO SQL
BEGIN
    DECLARE v_iter INT;
    DECLARE v_salt VARCHAR(64);
    IF p_plain IS NULL OR p_stored IS NULL OR p_stored NOT LIKE '$sha256$%' THEN
        RETURN FALSE;
    END IF;
    SET v_iter = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(p_stored, '$', 3), '$', -1) AS UNSIGNED);
    SET v_salt = SUBSTRING_INDEX(SUBSTRING_INDEX(p_stored, '$', 4), '$', -1);
    RETURN fn_hash_password_iter(p_plain, v_salt, v_iter) = p_stored;
END $$

-- Password policy: >= 8 chars, at least one upper-case, lower-case and digit
DROP FUNCTION IF EXISTS fn_is_strong_password $$
CREATE FUNCTION fn_is_strong_password(p_plain VARCHAR(255))
RETURNS BOOLEAN
DETERMINISTIC NO SQL
BEGIN
    RETURN p_plain IS NOT NULL
       AND CHAR_LENGTH(p_plain) >= 8
       AND REGEXP_LIKE(p_plain, '[A-Z]', 'c')
       AND REGEXP_LIKE(p_plain, '[a-z]', 'c')
       AND REGEXP_LIKE(p_plain, '[0-9]');
END $$

-- -----------------------------------------------------------------------------
-- fn_is_safe_file_path : rejects blank paths, path traversal ("..") and
-- backslashes / control characters in learning-material locations.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_is_safe_file_path $$
CREATE FUNCTION fn_is_safe_file_path(p_path VARCHAR(255))
RETURNS BOOLEAN
DETERMINISTIC NO SQL
BEGIN
    RETURN p_path IS NOT NULL
       AND TRIM(p_path) <> ''
       AND LOCATE('..', p_path) = 0
       AND LOCATE('\\', p_path) = 0
       AND NOT REGEXP_LIKE(p_path, '[[:cntrl:]]');
END $$

-- -----------------------------------------------------------------------------
-- fn_resolve_option : maps an answer given as a letter (A-D) or as option text
-- to the stored option text. Returns NULL when it matches no option.
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_resolve_option $$
CREATE FUNCTION fn_resolve_option(p_input VARCHAR(255), p_a VARCHAR(255), p_b VARCHAR(255),
                                  p_c VARCHAR(255), p_d VARCHAR(255))
RETURNS VARCHAR(255)
DETERMINISTIC NO SQL
BEGIN
    DECLARE v_in VARCHAR(255);
    SET v_in = TRIM(p_input);
    IF v_in IS NULL OR v_in = '' THEN
        RETURN NULL;
    END IF;
    IF UPPER(v_in) = 'A' THEN RETURN p_a; END IF;
    IF UPPER(v_in) = 'B' THEN RETURN p_b; END IF;
    IF UPPER(v_in) = 'C' THEN RETURN p_c; END IF;
    IF UPPER(v_in) = 'D' THEN RETURN p_d; END IF;
    IF v_in = p_a THEN RETURN p_a; END IF;
    IF v_in = p_b THEN RETURN p_b; END IF;
    IF v_in = p_c THEN RETURN p_c; END IF;
    IF v_in = p_d THEN RETURN p_d; END IF;
    RETURN NULL;
END $$

-- -----------------------------------------------------------------------------
-- Lookups
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_user_has_role $$
CREATE FUNCTION fn_user_has_role(p_user_id VARCHAR(10), p_role_name VARCHAR(50))
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    RETURN EXISTS (SELECT 1
                     FROM user_roles ur
                     JOIN roles r ON r.role_id = ur.role_id
                    WHERE ur.user_id = p_user_id AND r.role_name = p_role_name);
END $$

DROP FUNCTION IF EXISTS fn_get_instructor_id $$
CREATE FUNCTION fn_get_instructor_id(p_user_id VARCHAR(10))
RETURNS VARCHAR(10)
READS SQL DATA
BEGIN
    RETURN (SELECT instructor_id FROM instructors WHERE user_id = p_user_id);
END $$

DROP FUNCTION IF EXISTS fn_get_student_id $$
CREATE FUNCTION fn_get_student_id(p_user_id VARCHAR(10))
RETURNS VARCHAR(10)
READS SQL DATA
BEGIN
    RETURN (SELECT student_id FROM students WHERE user_id = p_user_id);
END $$

DROP FUNCTION IF EXISTS fn_question_count $$
CREATE FUNCTION fn_question_count(p_quiz_id VARCHAR(10))
RETURNS INT
READS SQL DATA
BEGIN
    RETURN (SELECT COUNT(*) FROM questions WHERE quiz_id = p_quiz_id);
END $$

-- -----------------------------------------------------------------------------
-- fn_calculate_quiz_score : documented assessment rule (assumption A3)
--   score = ROUND(correct answers / total questions * 100, 2)
--   every question has equal weight; unanswered questions count as incorrect
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_calculate_quiz_score $$
CREATE FUNCTION fn_calculate_quiz_score(p_student_id VARCHAR(10), p_quiz_id VARCHAR(10))
RETURNS DECIMAL(5,2)
READS SQL DATA
BEGIN
    DECLARE v_total   INT;
    DECLARE v_correct INT;
    SET v_total = fn_question_count(p_quiz_id);
    IF v_total = 0 THEN
        RETURN 0.00;
    END IF;
    SELECT COUNT(*) INTO v_correct
      FROM student_answers sa
      JOIN questions q ON q.question_id = sa.question_id
     WHERE sa.student_id = p_student_id
       AND q.quiz_id     = p_quiz_id
       AND sa.is_correct = TRUE;
    RETURN ROUND(v_correct * 100.0 / v_total, 2);
END $$

DELIMITER ;

SELECT routine_name, data_type AS returns, is_deterministic, sql_data_access
FROM information_schema.routines
WHERE routine_schema = 'studync_db' AND routine_type = 'FUNCTION'
ORDER BY routine_name;
