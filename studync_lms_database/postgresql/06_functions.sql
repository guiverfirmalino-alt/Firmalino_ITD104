-- =============================================================================
-- StudyNC LMS (PostgreSQL 16+)
-- File 06 : Functions
--   Part A : helper / validation / calculation functions
--   Part B : retrieval and reporting functions (return result sets)
-- -----------------------------------------------------------------------------
-- Volatility is declared explicitly (IMMUTABLE / STABLE / VOLATILE) so the
-- planner can optimise safely. SECURITY DEFINER functions pin search_path.
-- =============================================================================
SET ROLE studync_owner;
SET search_path = studync, pg_temp;

-- #############################################################################
-- PART A : helpers
-- #############################################################################

-- bcrypt (Blowfish, cost 10) via pgcrypto; a fresh random salt per call.
CREATE OR REPLACE FUNCTION fn_hash_password(p_plain VARCHAR)
RETURNS VARCHAR
LANGUAGE sql VOLATILE STRICT SET search_path = studync, pg_temp
AS $$ SELECT extensions.crypt(p_plain, extensions.gen_salt('bf', 10))::varchar $$;

-- crypt(plain, stored_hash) re-hashes with the salt embedded in the hash.
CREATE OR REPLACE FUNCTION fn_verify_password(p_plain VARCHAR, p_stored VARCHAR)
RETURNS BOOLEAN
LANGUAGE sql STABLE SET search_path = studync, pg_temp
AS $$
    SELECT coalesce(p_plain IS NOT NULL AND p_stored LIKE '$2%' AND extensions.crypt(p_plain, p_stored) = p_stored, FALSE)
$$;

-- >= 8 chars with upper-case, lower-case and a digit
CREATE OR REPLACE FUNCTION fn_is_strong_password(p_plain VARCHAR)
RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE
AS $$
    SELECT coalesce(char_length(p_plain) >= 8 AND p_plain ~ '[A-Z]' AND p_plain ~ '[a-z]' AND p_plain ~ '[0-9]', FALSE)
$$;

-- rejects blank paths, path traversal, backslashes and control characters
CREATE OR REPLACE FUNCTION fn_is_safe_file_path(p_path VARCHAR)
RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE
AS $$
    SELECT coalesce(btrim(p_path) <> '' AND strpos(p_path, '..') = 0
                    AND strpos(p_path, E'\\') = 0 AND p_path !~ '[[:cntrl:]]', FALSE)
$$;

-- maps 'A'..'D' or the option text (case-insensitive) to the stored option text
CREATE OR REPLACE FUNCTION fn_resolve_option(p_input VARCHAR, p_a VARCHAR, p_b VARCHAR, p_c VARCHAR, p_d VARCHAR)
RETURNS VARCHAR
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
    v_in VARCHAR := btrim(p_input);
BEGIN
    IF v_in IS NULL OR v_in = '' THEN RETURN NULL; END IF;
    CASE upper(v_in)
        WHEN 'A' THEN RETURN p_a;
        WHEN 'B' THEN RETURN p_b;
        WHEN 'C' THEN RETURN p_c;
        WHEN 'D' THEN RETURN p_d;
        ELSE NULL;
    END CASE;
    IF lower(v_in) = lower(p_a) THEN RETURN p_a; END IF;
    IF lower(v_in) = lower(p_b) THEN RETURN p_b; END IF;
    IF lower(v_in) = lower(p_c) THEN RETURN p_c; END IF;
    IF lower(v_in) = lower(p_d) THEN RETURN p_d; END IF;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION fn_user_has_role(p_user_id VARCHAR, p_role_name VARCHAR)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
    SELECT EXISTS (SELECT 1 FROM user_roles ur JOIN roles r ON r.role_id = ur.role_id
                    WHERE ur.user_id = p_user_id AND r.role_name = p_role_name)
$$;

CREATE OR REPLACE FUNCTION fn_get_instructor_id(p_user_id VARCHAR)
RETURNS VARCHAR
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = studync, pg_temp
AS $$ SELECT instructor_id FROM instructors WHERE user_id = p_user_id $$;

CREATE OR REPLACE FUNCTION fn_get_student_id(p_user_id VARCHAR)
RETURNS VARCHAR
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = studync, pg_temp
AS $$ SELECT student_id FROM students WHERE user_id = p_user_id $$;

CREATE OR REPLACE FUNCTION fn_question_count(p_quiz_id VARCHAR)
RETURNS INTEGER
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = studync, pg_temp
AS $$ SELECT count(*)::int FROM questions WHERE quiz_id = p_quiz_id $$;

-- Assessment rule: score = round(correct / total questions * 100, 2);
-- equal weights; unanswered questions count as incorrect.
CREATE OR REPLACE FUNCTION fn_calculate_quiz_score(p_student_id VARCHAR, p_quiz_id VARCHAR)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
DECLARE
    v_total   INTEGER := fn_question_count(p_quiz_id);
    v_correct INTEGER;
BEGIN
    IF v_total = 0 THEN RETURN 0.00; END IF;
    SELECT count(*) INTO v_correct
      FROM student_answers sa JOIN questions q ON q.question_id = sa.question_id
     WHERE sa.student_id = p_student_id AND q.quiz_id = p_quiz_id AND sa.is_correct;
    RETURN round(v_correct * 100.0 / v_total, 2);
END;
$$;

-- #############################################################################
-- PART B : retrieval and reporting (all SECURITY DEFINER + role checks)
-- #############################################################################

-- User Management : Administrators read anyone; other roles only themselves
CREATE OR REPLACE FUNCTION fn_get_user(p_actor_user_id VARCHAR, p_user_id VARCHAR)
RETURNS SETOF v_user_directory
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');
    IF p_user_id <> p_actor_user_id AND NOT fn_user_has_role(p_actor_user_id, 'Administrator') THEN
        RAISE EXCEPTION 'ACCESS DENIED: you may only view your own account' USING ERRCODE = 'insufficient_privilege';
    END IF;
    RETURN QUERY SELECT * FROM v_user_directory v WHERE v.user_id = p_user_id;
END;
$$;

-- Learning Material Management : materials of one subject (all roles)
CREATE OR REPLACE FUNCTION fn_get_materials_by_subject(p_actor_user_id VARCHAR, p_subject_id VARCHAR)
RETURNS SETOF v_learning_materials
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');
    RETURN QUERY SELECT * FROM v_learning_materials v WHERE v.subject_id = p_subject_id
                 ORDER BY v.uploaded_at, v.material_id;
END;
$$;

-- Quiz Management : questions; correct_answer is NULL unless the caller is an
-- Administrator or the instructor who owns the quiz.
CREATE OR REPLACE FUNCTION fn_get_quiz_questions(p_actor_user_id VARCHAR, p_quiz_id VARCHAR)
RETURNS TABLE (question_id VARCHAR, question_text TEXT, option_a VARCHAR, option_b VARCHAR,
               option_c VARCHAR, option_d VARCHAR, correct_answer VARCHAR)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
#variable_conflict use_column
DECLARE
    v_show_key BOOLEAN;
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');
    IF NOT EXISTS (SELECT 1 FROM quizzes WHERE quiz_id = p_quiz_id) THEN RAISE EXCEPTION 'Quiz not found'; END IF;
    v_show_key := fn_user_has_role(p_actor_user_id, 'Administrator')
               OR (SELECT instructor_id FROM quizzes WHERE quiz_id = p_quiz_id)
                  = coalesce(fn_get_instructor_id(p_actor_user_id), '');
    RETURN QUERY
        SELECT q.question_id, q.question_text, q.option_a, q.option_b, q.option_c, q.option_d,
               CASE WHEN v_show_key THEN q.correct_answer END
          FROM questions q WHERE q.quiz_id = p_quiz_id ORDER BY q.question_id;
END;
$$;

-- Assessment Processing : "View Results"
--   Student -> own only; Instructor -> own quizzes; Administrator -> all
CREATE OR REPLACE FUNCTION fn_get_student_results(p_actor_user_id VARCHAR, p_student_id VARCHAR DEFAULT NULL)
RETURNS SETOF v_quiz_results_detail
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
DECLARE
    v_own VARCHAR(10);
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');
    IF fn_user_has_role(p_actor_user_id, 'Administrator') THEN
        RETURN QUERY SELECT * FROM v_quiz_results_detail v
                      WHERE p_student_id IS NULL OR v.student_id = p_student_id
                      ORDER BY v.student_id, v.quiz_id;
    ELSIF fn_user_has_role(p_actor_user_id, 'Instructor') THEN
        RETURN QUERY SELECT * FROM v_quiz_results_detail v
                      WHERE v.instructor_id = fn_get_instructor_id(p_actor_user_id)
                        AND (p_student_id IS NULL OR v.student_id = p_student_id)
                      ORDER BY v.quiz_id, v.student_id;
    ELSE
        v_own := fn_get_student_id(p_actor_user_id);
        IF p_student_id IS NOT NULL AND p_student_id <> v_own THEN
            RAISE EXCEPTION 'ACCESS DENIED: students may only view their own results' USING ERRCODE = 'insufficient_privilege';
        END IF;
        RETURN QUERY SELECT * FROM v_quiz_results_detail v WHERE v.student_id = v_own ORDER BY v.quiz_id;
    END IF;
END;
$$;

-- Per-question review of a SUBMITTED quiz
CREATE OR REPLACE FUNCTION fn_get_answer_review(p_actor_user_id VARCHAR, p_quiz_id VARCHAR, p_student_id VARCHAR DEFAULT NULL)
RETURNS TABLE (question_id VARCHAR, question_text TEXT, student_answer VARCHAR, correct_answer VARCHAR, is_correct BOOLEAN)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
#variable_conflict use_column
DECLARE
    v_student VARCHAR(10);
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');
    IF fn_user_has_role(p_actor_user_id, 'Administrator') THEN
        v_student := p_student_id;
    ELSIF fn_user_has_role(p_actor_user_id, 'Instructor') THEN
        CALL sp_assert_quiz_owner(p_actor_user_id, p_quiz_id);
        v_student := p_student_id;
    ELSE
        v_student := fn_get_student_id(p_actor_user_id);
        IF p_student_id IS NOT NULL AND p_student_id <> v_student THEN
            RAISE EXCEPTION 'ACCESS DENIED: students may only view their own answers' USING ERRCODE = 'insufficient_privilege';
        END IF;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM quiz_results r WHERE r.student_id = v_student AND r.quiz_id = p_quiz_id) THEN
        RAISE EXCEPTION 'No submitted result for this student and quiz';
    END IF;
    RETURN QUERY
        SELECT q.question_id, q.question_text, sa.student_answer, q.correct_answer, coalesce(sa.is_correct, FALSE)
          FROM questions q
          LEFT JOIN student_answers sa ON sa.question_id = q.question_id AND sa.student_id = v_student
         WHERE q.quiz_id = p_quiz_id
         ORDER BY q.question_id;
END;
$$;

-- Reporting : student performance per subject (Admin: all; Instructor: own quizzes)
CREATE OR REPLACE FUNCTION fn_report_student_performance(p_actor_user_id VARCHAR, p_subject_id VARCHAR DEFAULT NULL)
RETURNS TABLE (student_id VARCHAR, student_name TEXT, subject_name VARCHAR, quizzes_taken BIGINT,
               average_score NUMERIC, highest_score NUMERIC, lowest_score NUMERIC)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
#variable_conflict use_column
DECLARE
    v_instructor VARCHAR(10);
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor');
    IF NOT fn_user_has_role(p_actor_user_id, 'Administrator') THEN
        v_instructor := fn_get_instructor_id(p_actor_user_id);
    END IF;
    RETURN QUERY
        SELECT st.student_id, st.first_name || ' ' || st.last_name, sb.subject_name,
               count(qr.result_id), round(avg(qr.score), 2), max(qr.score), min(qr.score)
          FROM quiz_results qr
          JOIN students st ON st.student_id = qr.student_id
          JOIN quizzes  q  ON q.quiz_id     = qr.quiz_id
          JOIN subjects sb ON sb.subject_id = q.subject_id
         WHERE (p_subject_id IS NULL OR q.subject_id = p_subject_id)
           AND (v_instructor IS NULL OR q.instructor_id = v_instructor)
         GROUP BY st.student_id, st.first_name, st.last_name, sb.subject_id, sb.subject_name
         ORDER BY sb.subject_name, round(avg(qr.score), 2) DESC, st.student_id;
END;
$$;

-- Reporting : results of one quiz (rows)
CREATE OR REPLACE FUNCTION fn_report_quiz_results(p_actor_user_id VARCHAR, p_quiz_id VARCHAR)
RETURNS SETOF v_quiz_results_detail
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor');
    IF NOT fn_user_has_role(p_actor_user_id, 'Administrator') THEN
        CALL sp_assert_quiz_owner(p_actor_user_id, p_quiz_id);
    ELSIF NOT EXISTS (SELECT 1 FROM quizzes WHERE quiz_id = p_quiz_id) THEN
        RAISE EXCEPTION 'Quiz not found';
    END IF;
    RETURN QUERY SELECT * FROM v_quiz_results_detail v WHERE v.quiz_id = p_quiz_id
                 ORDER BY v.score DESC, v.student_id;
END;
$$;

-- Reporting : summary statistics of one quiz
CREATE OR REPLACE FUNCTION fn_report_quiz_summary(p_actor_user_id VARCHAR, p_quiz_id VARCHAR)
RETURNS TABLE (quiz_id VARCHAR, submissions BIGINT, average_score NUMERIC, highest_score NUMERIC, lowest_score NUMERIC)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
#variable_conflict use_column
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor');
    IF NOT fn_user_has_role(p_actor_user_id, 'Administrator') THEN
        CALL sp_assert_quiz_owner(p_actor_user_id, p_quiz_id);
    END IF;
    RETURN QUERY SELECT p_quiz_id, count(*), round(avg(r.score), 2), max(r.score), min(r.score)
                   FROM quiz_results r WHERE r.quiz_id = p_quiz_id;
END;
$$;

-- Monitoring : audit trail (Administrator). All filters optional.
CREATE OR REPLACE FUNCTION fn_report_audit_logs(p_actor_user_id VARCHAR, p_table_name VARCHAR DEFAULT NULL,
                                                p_action_type VARCHAR DEFAULT NULL, p_from TIMESTAMPTZ DEFAULT NULL,
                                                p_to TIMESTAMPTZ DEFAULT NULL, p_limit INTEGER DEFAULT 100)
RETURNS SETOF v_audit_trail
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    RETURN QUERY SELECT * FROM v_audit_trail v
                  WHERE (p_table_name  IS NULL OR v.table_name  = p_table_name)
                    AND (p_action_type IS NULL OR v.action_type = p_action_type)
                    AND (p_from IS NULL OR v.log_timestamp >= p_from)
                    AND (p_to   IS NULL OR v.log_timestamp <  p_to)
                  ORDER BY v.log_id DESC
                  LIMIT least(greatest(coalesce(p_limit, 100), 1), 10000);
END;
$$;

-- Monitoring : activity summary for the last N days (Administrator)
CREATE OR REPLACE FUNCTION fn_report_system_activity(p_actor_user_id VARCHAR, p_days INTEGER DEFAULT 30)
RETURNS TABLE (table_name VARCHAR, action_type VARCHAR, operations BIGINT, distinct_users BIGINT, last_activity TIMESTAMPTZ)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = studync, pg_temp
AS $$
#variable_conflict use_column
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    RETURN QUERY SELECT a.table_name, a.action_type, count(*), count(DISTINCT a.performed_by), max(a.log_timestamp)
                   FROM audit_logs a
                  WHERE a.log_timestamp >= now() - make_interval(days => coalesce(p_days, 30))
                  GROUP BY a.table_name, a.action_type
                  ORDER BY a.table_name, a.action_type;
END;
$$;

RESET ROLE;

SELECT p.proname AS function_name, pg_get_function_result(p.oid) AS returns, p.provolatile, p.prosecdef
FROM pg_proc p WHERE p.pronamespace = 'studync'::regnamespace AND p.prokind = 'f'
  AND p.proname LIKE 'fn\_%' ORDER BY 1;
