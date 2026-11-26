-- =============================================================================
-- StudyNC LMS (MySQL 8.0+)
-- File 04 : Views (controlled, read-only data access)
-- -----------------------------------------------------------------------------
-- Security model:
--   * Database roles get SELECT on these views - never on the base tables.
--   * Views run with SQL SECURITY DEFINER, so the reader needs no privilege on
--     the underlying tables.
--   * password_hash is NEVER exposed by any view.
--   * Student-facing views never expose questions.correct_answer.
--   * v_my_results is row-filtered: it shows only rows belonging to the
--     personal MySQL login whose name equals users.username
--     (USER() returns the connected client account even inside a DEFINER view).
-- =============================================================================
USE studync_db;

-- -----------------------------------------------------------------------------
-- v_user_directory  (Administrator)  - "View Users" in the CRUD matrix
-- Reads users, roles, user_roles, admins, instructors, students.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE SQL SECURITY DEFINER VIEW v_user_directory AS
SELECT  u.user_id,
        u.username,
        u.email,
        u.status,
        u.created_at,
        (SELECT GROUP_CONCAT(r.role_name ORDER BY r.role_name SEPARATOR ', ')
           FROM user_roles ur JOIN roles r ON r.role_id = ur.role_id
          WHERE ur.user_id = u.user_id)                         AS roles,
        a.admin_id,
        i.instructor_id,
        s.student_id,
        COALESCE(CONCAT(a.first_name, ' ', a.last_name),
                 CONCAT(i.first_name, ' ', i.last_name),
                 CONCAT(s.first_name, ' ', s.last_name))         AS full_name
FROM users u
LEFT JOIN admins      a ON a.user_id = u.user_id
LEFT JOIN instructors i ON i.user_id = u.user_id
LEFT JOIN students    s ON s.user_id = u.user_id;

-- -----------------------------------------------------------------------------
-- v_subject_catalog  (all roles) - "View Subjects"
-- -----------------------------------------------------------------------------
CREATE OR REPLACE SQL SECURITY DEFINER VIEW v_subject_catalog AS
SELECT  sb.subject_id,
        sb.subject_name,
        sb.description,
        (SELECT COUNT(*) FROM materials m WHERE m.subject_id = sb.subject_id) AS material_count,
        (SELECT COUNT(*) FROM quizzes   q WHERE q.subject_id = sb.subject_id) AS quiz_count
FROM subjects sb;

-- -----------------------------------------------------------------------------
-- v_learning_materials  (all roles) - "View Materials"
-- -----------------------------------------------------------------------------
CREATE OR REPLACE SQL SECURITY DEFINER VIEW v_learning_materials AS
SELECT  m.material_id,
        m.title,
        m.file_path,
        m.uploaded_at,
        sb.subject_id,
        sb.subject_name,
        i.instructor_id,
        CONCAT(i.first_name, ' ', i.last_name) AS instructor_name
FROM materials m
JOIN subjects    sb ON sb.subject_id   = m.subject_id
JOIN instructors i  ON i.instructor_id = m.instructor_id;

-- -----------------------------------------------------------------------------
-- v_quiz_overview  (all roles) - "View Quizzes" (header information only)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE SQL SECURITY DEFINER VIEW v_quiz_overview AS
SELECT  q.quiz_id,
        q.title,
        q.created_at,
        sb.subject_id,
        sb.subject_name,
        i.instructor_id,
        CONCAT(i.first_name, ' ', i.last_name) AS instructor_name,
        (SELECT COUNT(*) FROM questions qs WHERE qs.quiz_id = q.quiz_id) AS question_count
FROM quizzes q
JOIN subjects    sb ON sb.subject_id   = q.subject_id
JOIN instructors i  ON i.instructor_id = q.instructor_id;

-- -----------------------------------------------------------------------------
-- v_quiz_questions_student  (Student) - questions WITHOUT the correct answer
-- -----------------------------------------------------------------------------
CREATE OR REPLACE SQL SECURITY DEFINER VIEW v_quiz_questions_student AS
SELECT  qs.question_id,
        qs.quiz_id,
        q.title AS quiz_title,
        qs.question_text,
        qs.option_a,
        qs.option_b,
        qs.option_c,
        qs.option_d
FROM questions qs
JOIN quizzes q ON q.quiz_id = qs.quiz_id;

-- -----------------------------------------------------------------------------
-- v_quiz_questions_instructor  (Instructor) - full question bank incl. key
-- -----------------------------------------------------------------------------
CREATE OR REPLACE SQL SECURITY DEFINER VIEW v_quiz_questions_instructor AS
SELECT  qs.question_id,
        qs.quiz_id,
        q.title AS quiz_title,
        q.instructor_id,
        qs.question_text,
        qs.option_a,
        qs.option_b,
        qs.option_c,
        qs.option_d,
        qs.correct_answer,
        (SELECT COUNT(*) FROM student_answers sa WHERE sa.question_id = qs.question_id) AS times_answered,
        (SELECT COUNT(*) FROM student_answers sa WHERE sa.question_id = qs.question_id AND sa.is_correct) AS times_correct
FROM questions qs
JOIN quizzes q ON q.quiz_id = qs.quiz_id;

-- -----------------------------------------------------------------------------
-- v_quiz_results_detail  (Administrator, Instructor) - "View Results"
-- -----------------------------------------------------------------------------
CREATE OR REPLACE SQL SECURITY DEFINER VIEW v_quiz_results_detail AS
SELECT  qr.result_id,
        st.student_id,
        CONCAT(st.first_name, ' ', st.last_name) AS student_name,
        q.quiz_id,
        q.title          AS quiz_title,
        sb.subject_name,
        q.instructor_id,
        qr.score,
        (SELECT COUNT(*) FROM student_answers sa JOIN questions qs ON qs.question_id = sa.question_id
          WHERE sa.student_id = qr.student_id AND qs.quiz_id = qr.quiz_id AND sa.is_correct) AS correct_answers,
        (SELECT COUNT(*) FROM questions qs WHERE qs.quiz_id = qr.quiz_id)                     AS total_questions
FROM quiz_results qr
JOIN students st ON st.student_id = qr.student_id
JOIN quizzes  q  ON q.quiz_id     = qr.quiz_id
JOIN subjects sb ON sb.subject_id = q.subject_id;

-- -----------------------------------------------------------------------------
-- v_student_performance  (Administrator, Instructor) - performance report
-- -----------------------------------------------------------------------------
CREATE OR REPLACE SQL SECURITY DEFINER VIEW v_student_performance AS
SELECT  st.student_id,
        CONCAT(st.first_name, ' ', st.last_name) AS student_name,
        u.status                                 AS account_status,
        COUNT(qr.result_id)                      AS quizzes_taken,
        ROUND(AVG(qr.score), 2)                  AS average_score,
        MAX(qr.score)                            AS highest_score,
        MIN(qr.score)                            AS lowest_score
FROM students st
JOIN users u ON u.user_id = st.user_id
LEFT JOIN quiz_results qr ON qr.student_id = st.student_id
GROUP BY st.student_id, st.first_name, st.last_name, u.status;

-- -----------------------------------------------------------------------------
-- v_my_results  (Student) - row-level restricted to the logged-in student.
-- Works for personal logins (MySQL account name = users.username).
-- Shared application accounts see no rows here and must use the procedure
-- sp_get_student_results, which receives the authenticated user id.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE SQL SECURITY DEFINER VIEW v_my_results AS
SELECT  qr.result_id,
        q.quiz_id,
        q.title AS quiz_title,
        sb.subject_name,
        qr.score,
        (SELECT COUNT(*) FROM student_answers sa JOIN questions qs ON qs.question_id = sa.question_id
          WHERE sa.student_id = qr.student_id AND qs.quiz_id = qr.quiz_id AND sa.is_correct) AS correct_answers,
        (SELECT COUNT(*) FROM questions qs WHERE qs.quiz_id = qr.quiz_id)                     AS total_questions
FROM quiz_results qr
JOIN students st ON st.student_id = qr.student_id
JOIN users    u  ON u.user_id     = st.user_id
JOIN quizzes  q  ON q.quiz_id     = qr.quiz_id
JOIN subjects sb ON sb.subject_id = q.subject_id
WHERE u.username = SUBSTRING_INDEX(USER(), '@', 1);

-- -----------------------------------------------------------------------------
-- v_audit_trail  (Administrator only) - "View Audit Logs"
-- -----------------------------------------------------------------------------
CREATE OR REPLACE SQL SECURITY DEFINER VIEW v_audit_trail AS
SELECT  al.log_id,
        al.log_timestamp,
        al.action_type,
        al.table_name,
        al.record_id,
        al.performed_by,
        u.username AS performed_by_username,
        al.db_user,
        al.description,
        al.old_data,
        al.new_data
FROM audit_logs al
LEFT JOIN users u ON u.user_id = al.performed_by;

SELECT table_name AS view_name, security_type
FROM information_schema.views
WHERE table_schema = 'studync_db'
ORDER BY table_name;
