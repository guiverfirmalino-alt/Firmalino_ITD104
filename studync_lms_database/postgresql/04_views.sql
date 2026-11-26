-- =============================================================================
-- StudyNC LMS (PostgreSQL 16+)
-- File 04 : Views (controlled, read-only data access)
-- -----------------------------------------------------------------------------
-- * Views are owned by studync_owner and use the default security_invoker =
--   false, i.e. they read the base tables with the OWNER's rights: a role
--   that has SELECT on a view needs no privilege on the tables behind it.
-- * password_hash is never exposed; student views never expose correct_answer.
-- * v_my_results is row-filtered on session_user (the PostgreSQL login) and
--   is declared security_barrier so that user-supplied functions in a WHERE
--   clause cannot "leak" rows of other students before the filter is applied.
-- =============================================================================
SET ROLE studync_owner;
SET search_path = studync, pg_temp;

-- Administrator : "View Users"
CREATE OR REPLACE VIEW v_user_directory AS
SELECT  u.user_id,
        u.username,
        u.email,
        u.status,
        u.created_at,
        (SELECT string_agg(r.role_name, ', ' ORDER BY r.role_name)
           FROM user_roles ur JOIN roles r ON r.role_id = ur.role_id
          WHERE ur.user_id = u.user_id)                       AS roles,
        a.admin_id,
        i.instructor_id,
        s.student_id,
        COALESCE(a.first_name || ' ' || a.last_name,
                 i.first_name || ' ' || i.last_name,
                 s.first_name || ' ' || s.last_name)          AS full_name
FROM users u
LEFT JOIN admins      a ON a.user_id = u.user_id
LEFT JOIN instructors i ON i.user_id = u.user_id
LEFT JOIN students    s ON s.user_id = u.user_id;

-- All roles : "View Subjects"
CREATE OR REPLACE VIEW v_subject_catalog AS
SELECT  sb.subject_id,
        sb.subject_name,
        sb.description,
        (SELECT count(*) FROM materials m WHERE m.subject_id = sb.subject_id) AS material_count,
        (SELECT count(*) FROM quizzes   q WHERE q.subject_id = sb.subject_id) AS quiz_count
FROM subjects sb;

-- All roles : "View Materials"
CREATE OR REPLACE VIEW v_learning_materials AS
SELECT  m.material_id,
        m.title,
        m.file_path,
        m.uploaded_at,
        sb.subject_id,
        sb.subject_name,
        i.instructor_id,
        i.first_name || ' ' || i.last_name AS instructor_name
FROM materials m
JOIN subjects    sb ON sb.subject_id   = m.subject_id
JOIN instructors i  ON i.instructor_id = m.instructor_id;

-- All roles : "View Quizzes" (header only)
CREATE OR REPLACE VIEW v_quiz_overview AS
SELECT  q.quiz_id,
        q.title,
        q.created_at,
        sb.subject_id,
        sb.subject_name,
        i.instructor_id,
        i.first_name || ' ' || i.last_name AS instructor_name,
        (SELECT count(*) FROM questions qs WHERE qs.quiz_id = q.quiz_id) AS question_count
FROM quizzes q
JOIN subjects    sb ON sb.subject_id   = q.subject_id
JOIN instructors i  ON i.instructor_id = q.instructor_id;

-- Student : questions WITHOUT the answer key
CREATE OR REPLACE VIEW v_quiz_questions_student AS
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

-- Instructor : full question bank with key and answer statistics
CREATE OR REPLACE VIEW v_quiz_questions_instructor AS
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
        (SELECT count(*) FROM student_answers sa WHERE sa.question_id = qs.question_id)                   AS times_answered,
        (SELECT count(*) FROM student_answers sa WHERE sa.question_id = qs.question_id AND sa.is_correct) AS times_correct
FROM questions qs
JOIN quizzes q ON q.quiz_id = qs.quiz_id;

-- Administrator, Instructor : "View Results"
CREATE OR REPLACE VIEW v_quiz_results_detail AS
SELECT  qr.result_id,
        st.student_id,
        st.first_name || ' ' || st.last_name AS student_name,
        q.quiz_id,
        q.title AS quiz_title,
        sb.subject_name,
        q.instructor_id,
        qr.score,
        (SELECT count(*) FROM student_answers sa JOIN questions qs ON qs.question_id = sa.question_id
          WHERE sa.student_id = qr.student_id AND qs.quiz_id = qr.quiz_id AND sa.is_correct) AS correct_answers,
        (SELECT count(*) FROM questions qs WHERE qs.quiz_id = qr.quiz_id)                     AS total_questions
FROM quiz_results qr
JOIN students st ON st.student_id = qr.student_id
JOIN quizzes  q  ON q.quiz_id     = qr.quiz_id
JOIN subjects sb ON sb.subject_id = q.subject_id;

-- Administrator, Instructor : performance summary per student
CREATE OR REPLACE VIEW v_student_performance AS
SELECT  st.student_id,
        st.first_name || ' ' || st.last_name AS student_name,
        u.status                             AS account_status,
        count(qr.result_id)                  AS quizzes_taken,
        round(avg(qr.score), 2)              AS average_score,
        max(qr.score)                        AS highest_score,
        min(qr.score)                        AS lowest_score
FROM students st
JOIN users u ON u.user_id = st.user_id
LEFT JOIN quiz_results qr ON qr.student_id = st.student_id
GROUP BY st.student_id, st.first_name, st.last_name, u.status;

-- Student : own results only (personal login = users.username)
CREATE OR REPLACE VIEW v_my_results WITH (security_barrier = true) AS
SELECT  qr.result_id,
        q.quiz_id,
        q.title AS quiz_title,
        sb.subject_name,
        qr.score,
        (SELECT count(*) FROM student_answers sa JOIN questions qs ON qs.question_id = sa.question_id
          WHERE sa.student_id = qr.student_id AND qs.quiz_id = qr.quiz_id AND sa.is_correct) AS correct_answers,
        (SELECT count(*) FROM questions qs WHERE qs.quiz_id = qr.quiz_id)                     AS total_questions
FROM quiz_results qr
JOIN students st ON st.student_id = qr.student_id
JOIN users    u  ON u.user_id     = st.user_id
JOIN quizzes  q  ON q.quiz_id     = qr.quiz_id
JOIN subjects sb ON sb.subject_id = q.subject_id
WHERE lower(u.username) = lower(session_user);

-- Administrator only : "View Audit Logs"
CREATE OR REPLACE VIEW v_audit_trail AS
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

RESET ROLE;

SELECT table_name AS view_name FROM information_schema.views
WHERE table_schema = 'studync' ORDER BY table_name;
