--
-- PostgreSQL database dump
--

\restrict eZBKeuGl9teUZNj9aHgQ1Qi1Vmz5aBorioita6gjin643wqJXzn9QncAFt5IDr4

-- Dumped from database version 19.0
-- Dumped by pg_dump version 19.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: extensions; Type: SCHEMA; Schema: -; Owner: studync_owner
--

CREATE SCHEMA extensions;


ALTER SCHEMA extensions OWNER TO studync_owner;

--
-- Name: studync; Type: SCHEMA; Schema: -; Owner: studync_owner
--

CREATE SCHEMA studync;


ALTER SCHEMA studync OWNER TO studync_owner;

--
-- Name: SCHEMA studync; Type: COMMENT; Schema: -; Owner: studync_owner
--

COMMENT ON SCHEMA studync IS 'StudyNC LMS objects';


--
-- Name: studync_test; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA studync_test;


ALTER SCHEMA studync_test OWNER TO postgres;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: user_status; Type: TYPE; Schema: studync; Owner: studync_owner
--

CREATE TYPE studync.user_status AS ENUM (
    'Active',
    'Inactive'
);


ALTER TYPE studync.user_status OWNER TO studync_owner;

--
-- Name: fn_audit_row(); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_audit_row() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER FUNCTION studync.fn_audit_row() OWNER TO studync_owner;

--
-- Name: fn_calculate_quiz_score(character varying, character varying); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_calculate_quiz_score(p_student_id character varying, p_quiz_id character varying) RETURNS numeric
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER FUNCTION studync.fn_calculate_quiz_score(p_student_id character varying, p_quiz_id character varying) OWNER TO studync_owner;

--
-- Name: fn_get_answer_review(character varying, character varying, character varying); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_get_answer_review(p_actor_user_id character varying, p_quiz_id character varying, p_student_id character varying DEFAULT NULL::character varying) RETURNS TABLE(question_id character varying, question_text text, student_answer character varying, correct_answer character varying, is_correct boolean)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER FUNCTION studync.fn_get_answer_review(p_actor_user_id character varying, p_quiz_id character varying, p_student_id character varying) OWNER TO studync_owner;

--
-- Name: fn_get_instructor_id(character varying); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_get_instructor_id(p_user_id character varying) RETURNS character varying
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
    AS $$ SELECT instructor_id FROM instructors WHERE user_id = p_user_id $$;


ALTER FUNCTION studync.fn_get_instructor_id(p_user_id character varying) OWNER TO studync_owner;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: instructors; Type: TABLE; Schema: studync; Owner: studync_owner
--

CREATE TABLE studync.instructors (
    instructor_id character varying(10) NOT NULL,
    user_id character varying(10) NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    CONSTRAINT ck_instructors_id_format CHECK (((instructor_id)::text ~ '^INS[0-9]{7}$'::text)),
    CONSTRAINT ck_instructors_names CHECK (((btrim((first_name)::text) <> ''::text) AND (btrim((last_name)::text) <> ''::text)))
);


ALTER TABLE studync.instructors OWNER TO studync_owner;

--
-- Name: materials; Type: TABLE; Schema: studync; Owner: studync_owner
--

CREATE TABLE studync.materials (
    material_id character varying(10) NOT NULL,
    subject_id character varying(10) NOT NULL,
    instructor_id character varying(10) NOT NULL,
    title character varying(255) NOT NULL,
    file_path character varying(255) NOT NULL,
    uploaded_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_materials_id_format CHECK (((material_id)::text ~ '^MAT[0-9]{7}$'::text)),
    CONSTRAINT ck_materials_path_not_blank CHECK ((btrim((file_path)::text) <> ''::text)),
    CONSTRAINT ck_materials_title_not_blank CHECK ((btrim((title)::text) <> ''::text))
);


ALTER TABLE studync.materials OWNER TO studync_owner;

--
-- Name: subjects; Type: TABLE; Schema: studync; Owner: studync_owner
--

CREATE TABLE studync.subjects (
    subject_id character varying(10) NOT NULL,
    subject_name character varying(100) NOT NULL,
    description text,
    CONSTRAINT ck_subjects_id_format CHECK (((subject_id)::text ~ '^SUB[0-9]{7}$'::text)),
    CONSTRAINT ck_subjects_name_not_blank CHECK ((btrim((subject_name)::text) <> ''::text))
);


ALTER TABLE studync.subjects OWNER TO studync_owner;

--
-- Name: v_learning_materials; Type: VIEW; Schema: studync; Owner: studync_owner
--

CREATE VIEW studync.v_learning_materials AS
 SELECT m.material_id,
    m.title,
    m.file_path,
    m.uploaded_at,
    sb.subject_id,
    sb.subject_name,
    i.instructor_id,
    (((i.first_name)::text || ' '::text) || (i.last_name)::text) AS instructor_name
   FROM ((studync.materials m
     JOIN studync.subjects sb ON (((sb.subject_id)::text = (m.subject_id)::text)))
     JOIN studync.instructors i ON (((i.instructor_id)::text = (m.instructor_id)::text)));


ALTER VIEW studync.v_learning_materials OWNER TO studync_owner;

--
-- Name: fn_get_materials_by_subject(character varying, character varying); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_get_materials_by_subject(p_actor_user_id character varying, p_subject_id character varying) RETURNS SETOF studync.v_learning_materials
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
    AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');
    RETURN QUERY SELECT * FROM v_learning_materials v WHERE v.subject_id = p_subject_id
                 ORDER BY v.uploaded_at, v.material_id;
END;
$$;


ALTER FUNCTION studync.fn_get_materials_by_subject(p_actor_user_id character varying, p_subject_id character varying) OWNER TO studync_owner;

--
-- Name: fn_get_quiz_questions(character varying, character varying); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_get_quiz_questions(p_actor_user_id character varying, p_quiz_id character varying) RETURNS TABLE(question_id character varying, question_text text, option_a character varying, option_b character varying, option_c character varying, option_d character varying, correct_answer character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER FUNCTION studync.fn_get_quiz_questions(p_actor_user_id character varying, p_quiz_id character varying) OWNER TO studync_owner;

--
-- Name: fn_get_student_id(character varying); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_get_student_id(p_user_id character varying) RETURNS character varying
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
    AS $$ SELECT student_id FROM students WHERE user_id = p_user_id $$;


ALTER FUNCTION studync.fn_get_student_id(p_user_id character varying) OWNER TO studync_owner;

--
-- Name: questions; Type: TABLE; Schema: studync; Owner: studync_owner
--

CREATE TABLE studync.questions (
    question_id character varying(10) NOT NULL,
    quiz_id character varying(10) NOT NULL,
    question_text text NOT NULL,
    correct_answer character varying(255) NOT NULL,
    option_a character varying(255) NOT NULL,
    option_b character varying(255) NOT NULL,
    option_c character varying(255) NOT NULL,
    option_d character varying(255) NOT NULL,
    CONSTRAINT ck_questions_correct_is_option CHECK ((((((correct_answer)::text = (option_a)::text) OR ((correct_answer)::text = (option_b)::text)) OR ((correct_answer)::text = (option_c)::text)) OR ((correct_answer)::text = (option_d)::text))),
    CONSTRAINT ck_questions_distinct_options CHECK (((lower((option_a)::text) <> lower((option_b)::text)) AND (lower((option_a)::text) <> lower((option_c)::text)) AND (lower((option_a)::text) <> lower((option_d)::text)) AND (lower((option_b)::text) <> lower((option_c)::text)) AND (lower((option_b)::text) <> lower((option_d)::text)) AND (lower((option_c)::text) <> lower((option_d)::text)))),
    CONSTRAINT ck_questions_id_format CHECK (((question_id)::text ~ '^QST[0-9]{7}$'::text)),
    CONSTRAINT ck_questions_text_not_blank CHECK ((btrim(question_text) <> ''::text))
);


ALTER TABLE studync.questions OWNER TO studync_owner;

--
-- Name: quiz_results; Type: TABLE; Schema: studync; Owner: studync_owner
--

CREATE TABLE studync.quiz_results (
    result_id character varying(10) NOT NULL,
    student_id character varying(10) NOT NULL,
    quiz_id character varying(10) NOT NULL,
    score numeric(5,2) DEFAULT 0.00 NOT NULL,
    CONSTRAINT ck_quiz_results_id_format CHECK (((result_id)::text ~ '^RES[0-9]{7}$'::text)),
    CONSTRAINT ck_quiz_results_score_range CHECK (((score >= (0)::numeric) AND (score <= (100)::numeric)))
);


ALTER TABLE studync.quiz_results OWNER TO studync_owner;

--
-- Name: quizzes; Type: TABLE; Schema: studync; Owner: studync_owner
--

CREATE TABLE studync.quizzes (
    quiz_id character varying(10) NOT NULL,
    subject_id character varying(10) NOT NULL,
    instructor_id character varying(10) NOT NULL,
    title character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_quizzes_id_format CHECK (((quiz_id)::text ~ '^QUZ[0-9]{7}$'::text)),
    CONSTRAINT ck_quizzes_title_not_blank CHECK ((btrim((title)::text) <> ''::text))
);


ALTER TABLE studync.quizzes OWNER TO studync_owner;

--
-- Name: student_answers; Type: TABLE; Schema: studync; Owner: studync_owner
--

CREATE TABLE studync.student_answers (
    answer_id character varying(10) NOT NULL,
    student_id character varying(10) NOT NULL,
    question_id character varying(10) NOT NULL,
    student_answer character varying(255),
    is_correct boolean DEFAULT false NOT NULL,
    CONSTRAINT ck_student_answers_id_format CHECK (((answer_id)::text ~ '^ANS[0-9]{7}$'::text))
);


ALTER TABLE studync.student_answers OWNER TO studync_owner;

--
-- Name: students; Type: TABLE; Schema: studync; Owner: studync_owner
--

CREATE TABLE studync.students (
    student_id character varying(10) NOT NULL,
    user_id character varying(10) NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    CONSTRAINT ck_students_id_format CHECK (((student_id)::text ~ '^STU[0-9]{7}$'::text)),
    CONSTRAINT ck_students_names CHECK (((btrim((first_name)::text) <> ''::text) AND (btrim((last_name)::text) <> ''::text)))
);


ALTER TABLE studync.students OWNER TO studync_owner;

--
-- Name: v_quiz_results_detail; Type: VIEW; Schema: studync; Owner: studync_owner
--

CREATE VIEW studync.v_quiz_results_detail AS
 SELECT qr.result_id,
    st.student_id,
    (((st.first_name)::text || ' '::text) || (st.last_name)::text) AS student_name,
    q.quiz_id,
    q.title AS quiz_title,
    sb.subject_name,
    q.instructor_id,
    qr.score,
    ( SELECT count(*) AS count
           FROM (studync.student_answers sa
             JOIN studync.questions qs ON (((qs.question_id)::text = (sa.question_id)::text)))
          WHERE (((sa.student_id)::text = (qr.student_id)::text) AND ((qs.quiz_id)::text = (qr.quiz_id)::text) AND sa.is_correct)) AS correct_answers,
    ( SELECT count(*) AS count
           FROM studync.questions qs
          WHERE ((qs.quiz_id)::text = (qr.quiz_id)::text)) AS total_questions
   FROM (((studync.quiz_results qr
     JOIN studync.students st ON (((st.student_id)::text = (qr.student_id)::text)))
     JOIN studync.quizzes q ON (((q.quiz_id)::text = (qr.quiz_id)::text)))
     JOIN studync.subjects sb ON (((sb.subject_id)::text = (q.subject_id)::text)));


ALTER VIEW studync.v_quiz_results_detail OWNER TO studync_owner;

--
-- Name: fn_get_student_results(character varying, character varying); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_get_student_results(p_actor_user_id character varying, p_student_id character varying DEFAULT NULL::character varying) RETURNS SETOF studync.v_quiz_results_detail
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER FUNCTION studync.fn_get_student_results(p_actor_user_id character varying, p_student_id character varying) OWNER TO studync_owner;

--
-- Name: admins; Type: TABLE; Schema: studync; Owner: studync_owner
--

CREATE TABLE studync.admins (
    admin_id character varying(10) NOT NULL,
    user_id character varying(10) NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    CONSTRAINT ck_admins_id_format CHECK (((admin_id)::text ~ '^ADM[0-9]{7}$'::text)),
    CONSTRAINT ck_admins_names CHECK (((btrim((first_name)::text) <> ''::text) AND (btrim((last_name)::text) <> ''::text)))
);


ALTER TABLE studync.admins OWNER TO studync_owner;

--
-- Name: roles; Type: TABLE; Schema: studync; Owner: studync_owner
--

CREATE TABLE studync.roles (
    role_id character varying(10) NOT NULL,
    role_name character varying(50) NOT NULL,
    CONSTRAINT ck_roles_role_name CHECK (((role_name)::text = ANY ((ARRAY['Administrator'::character varying, 'Instructor'::character varying, 'Student'::character varying])::text[])))
);


ALTER TABLE studync.roles OWNER TO studync_owner;

--
-- Name: user_roles; Type: TABLE; Schema: studync; Owner: studync_owner
--

CREATE TABLE studync.user_roles (
    user_id character varying(10) NOT NULL,
    role_id character varying(10) NOT NULL
);


ALTER TABLE studync.user_roles OWNER TO studync_owner;

--
-- Name: users; Type: TABLE; Schema: studync; Owner: studync_owner
--

CREATE TABLE studync.users (
    user_id character varying(10) NOT NULL,
    username character varying(50) NOT NULL,
    email character varying(100) NOT NULL,
    password_hash character varying(255) NOT NULL,
    status studync.user_status DEFAULT 'Active'::studync.user_status NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_users_email_format CHECK (((email)::text ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'::text)),
    CONSTRAINT ck_users_hash_length CHECK ((char_length((password_hash)::text) >= 60)),
    CONSTRAINT ck_users_id_format CHECK (((user_id)::text ~ '^USR[0-9]{7}$'::text)),
    CONSTRAINT ck_users_username_format CHECK (((username)::text ~ '^[A-Za-z0-9._]{3,50}$'::text))
);


ALTER TABLE studync.users OWNER TO studync_owner;

--
-- Name: COLUMN users.password_hash; Type: COMMENT; Schema: studync; Owner: studync_owner
--

COMMENT ON COLUMN studync.users.password_hash IS 'bcrypt hash (pgcrypto crypt/gen_salt bf) - never plain text';


--
-- Name: v_user_directory; Type: VIEW; Schema: studync; Owner: studync_owner
--

CREATE VIEW studync.v_user_directory AS
 SELECT u.user_id,
    u.username,
    u.email,
    u.status,
    u.created_at,
    ( SELECT string_agg((r.role_name)::text, ', '::text ORDER BY (r.role_name)::text) AS string_agg
           FROM (studync.user_roles ur
             JOIN studync.roles r ON (((r.role_id)::text = (ur.role_id)::text)))
          WHERE ((ur.user_id)::text = (u.user_id)::text)) AS roles,
    a.admin_id,
    i.instructor_id,
    s.student_id,
    COALESCE((((a.first_name)::text || ' '::text) || (a.last_name)::text), (((i.first_name)::text || ' '::text) || (i.last_name)::text), (((s.first_name)::text || ' '::text) || (s.last_name)::text)) AS full_name
   FROM (((studync.users u
     LEFT JOIN studync.admins a ON (((a.user_id)::text = (u.user_id)::text)))
     LEFT JOIN studync.instructors i ON (((i.user_id)::text = (u.user_id)::text)))
     LEFT JOIN studync.students s ON (((s.user_id)::text = (u.user_id)::text)));


ALTER VIEW studync.v_user_directory OWNER TO studync_owner;

--
-- Name: fn_get_user(character varying, character varying); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_get_user(p_actor_user_id character varying, p_user_id character varying) RETURNS SETOF studync.v_user_directory
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
    AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');
    IF p_user_id <> p_actor_user_id AND NOT fn_user_has_role(p_actor_user_id, 'Administrator') THEN
        RAISE EXCEPTION 'ACCESS DENIED: you may only view your own account' USING ERRCODE = 'insufficient_privilege';
    END IF;
    RETURN QUERY SELECT * FROM v_user_directory v WHERE v.user_id = p_user_id;
END;
$$;


ALTER FUNCTION studync.fn_get_user(p_actor_user_id character varying, p_user_id character varying) OWNER TO studync_owner;

--
-- Name: fn_hash_password(character varying); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_hash_password(p_plain character varying) RETURNS character varying
    LANGUAGE sql STRICT
    SET search_path TO 'studync', 'pg_temp'
    AS $$ SELECT extensions.crypt(p_plain, extensions.gen_salt('bf', 10))::varchar $$;


ALTER FUNCTION studync.fn_hash_password(p_plain character varying) OWNER TO studync_owner;

--
-- Name: fn_is_safe_file_path(character varying); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_is_safe_file_path(p_path character varying) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT coalesce(btrim(p_path) <> '' AND strpos(p_path, '..') = 0
                    AND strpos(p_path, E'\\') = 0 AND p_path !~ '[[:cntrl:]]', FALSE)
$$;


ALTER FUNCTION studync.fn_is_safe_file_path(p_path character varying) OWNER TO studync_owner;

--
-- Name: fn_is_strong_password(character varying); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_is_strong_password(p_plain character varying) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT coalesce(char_length(p_plain) >= 8 AND p_plain ~ '[A-Z]' AND p_plain ~ '[a-z]' AND p_plain ~ '[0-9]', FALSE)
$$;


ALTER FUNCTION studync.fn_is_strong_password(p_plain character varying) OWNER TO studync_owner;

--
-- Name: fn_question_count(character varying); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_question_count(p_quiz_id character varying) RETURNS integer
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
    AS $$ SELECT count(*)::int FROM questions WHERE quiz_id = p_quiz_id $$;


ALTER FUNCTION studync.fn_question_count(p_quiz_id character varying) OWNER TO studync_owner;

--
-- Name: audit_logs; Type: TABLE; Schema: studync; Owner: studync_owner
--

CREATE TABLE studync.audit_logs (
    log_id integer NOT NULL,
    action_type character varying(50) NOT NULL,
    table_name character varying(50) NOT NULL,
    record_id character varying(50),
    performed_by character varying(10),
    db_user character varying(100) DEFAULT SESSION_USER NOT NULL,
    description text,
    old_data jsonb,
    new_data jsonb,
    log_timestamp timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT ck_audit_logs_action_type CHECK (((action_type)::text = ANY ((ARRAY['INSERT'::character varying, 'UPDATE'::character varying, 'DELETE'::character varying, 'LOGIN_SUCCESS'::character varying, 'LOGIN_FAILED'::character varying])::text[])))
);


ALTER TABLE studync.audit_logs OWNER TO studync_owner;

--
-- Name: COLUMN audit_logs.performed_by; Type: COMMENT; Schema: studync; Owner: studync_owner
--

COMMENT ON COLUMN studync.audit_logs.performed_by IS 'Application user_id passed through the studync.app_user_id setting';


--
-- Name: COLUMN audit_logs.db_user; Type: COMMENT; Schema: studync; Owner: studync_owner
--

COMMENT ON COLUMN studync.audit_logs.db_user IS 'PostgreSQL login (session_user) that executed the statement';


--
-- Name: v_audit_trail; Type: VIEW; Schema: studync; Owner: studync_owner
--

CREATE VIEW studync.v_audit_trail AS
 SELECT al.log_id,
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
   FROM (studync.audit_logs al
     LEFT JOIN studync.users u ON (((u.user_id)::text = (al.performed_by)::text)));


ALTER VIEW studync.v_audit_trail OWNER TO studync_owner;

--
-- Name: fn_report_audit_logs(character varying, character varying, character varying, timestamp with time zone, timestamp with time zone, integer); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_report_audit_logs(p_actor_user_id character varying, p_table_name character varying DEFAULT NULL::character varying, p_action_type character varying DEFAULT NULL::character varying, p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone, p_limit integer DEFAULT 100) RETURNS SETOF studync.v_audit_trail
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER FUNCTION studync.fn_report_audit_logs(p_actor_user_id character varying, p_table_name character varying, p_action_type character varying, p_from timestamp with time zone, p_to timestamp with time zone, p_limit integer) OWNER TO studync_owner;

--
-- Name: fn_report_quiz_results(character varying, character varying); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_report_quiz_results(p_actor_user_id character varying, p_quiz_id character varying) RETURNS SETOF studync.v_quiz_results_detail
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER FUNCTION studync.fn_report_quiz_results(p_actor_user_id character varying, p_quiz_id character varying) OWNER TO studync_owner;

--
-- Name: fn_report_quiz_summary(character varying, character varying); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_report_quiz_summary(p_actor_user_id character varying, p_quiz_id character varying) RETURNS TABLE(quiz_id character varying, submissions bigint, average_score numeric, highest_score numeric, lowest_score numeric)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER FUNCTION studync.fn_report_quiz_summary(p_actor_user_id character varying, p_quiz_id character varying) OWNER TO studync_owner;

--
-- Name: fn_report_student_performance(character varying, character varying); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_report_student_performance(p_actor_user_id character varying, p_subject_id character varying DEFAULT NULL::character varying) RETURNS TABLE(student_id character varying, student_name text, subject_name character varying, quizzes_taken bigint, average_score numeric, highest_score numeric, lowest_score numeric)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER FUNCTION studync.fn_report_student_performance(p_actor_user_id character varying, p_subject_id character varying) OWNER TO studync_owner;

--
-- Name: fn_report_system_activity(character varying, integer); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_report_system_activity(p_actor_user_id character varying, p_days integer DEFAULT 30) RETURNS TABLE(table_name character varying, action_type character varying, operations bigint, distinct_users bigint, last_activity timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER FUNCTION studync.fn_report_system_activity(p_actor_user_id character varying, p_days integer) OWNER TO studync_owner;

--
-- Name: fn_resolve_option(character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_resolve_option(p_input character varying, p_a character varying, p_b character varying, p_c character varying, p_d character varying) RETURNS character varying
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


ALTER FUNCTION studync.fn_resolve_option(p_input character varying, p_a character varying, p_b character varying, p_c character varying, p_d character varying) OWNER TO studync_owner;

--
-- Name: fn_trg_quiz_results_score(); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_trg_quiz_results_score() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
    AS $$
BEGIN
    NEW.score := fn_calculate_quiz_score(NEW.student_id, NEW.quiz_id);
    RETURN NEW;
END;
$$;


ALTER FUNCTION studync.fn_trg_quiz_results_score() OWNER TO studync_owner;

--
-- Name: fn_trg_reject_change(); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_trg_reject_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- TG_ARGV[0] carries the error message
    RAISE EXCEPTION '%', TG_ARGV[0];
END;
$$;


ALTER FUNCTION studync.fn_trg_reject_change() OWNER TO studync_owner;

--
-- Name: fn_trg_student_answers_bi(); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_trg_student_answers_bi() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER FUNCTION studync.fn_trg_student_answers_bi() OWNER TO studync_owner;

--
-- Name: fn_user_has_role(character varying, character varying); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_user_has_role(p_user_id character varying, p_role_name character varying) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
    AS $$
    SELECT EXISTS (SELECT 1 FROM user_roles ur JOIN roles r ON r.role_id = ur.role_id
                    WHERE ur.user_id = p_user_id AND r.role_name = p_role_name)
$$;


ALTER FUNCTION studync.fn_user_has_role(p_user_id character varying, p_role_name character varying) OWNER TO studync_owner;

--
-- Name: fn_verify_password(character varying, character varying); Type: FUNCTION; Schema: studync; Owner: studync_owner
--

CREATE FUNCTION studync.fn_verify_password(p_plain character varying, p_stored character varying) RETURNS boolean
    LANGUAGE sql STABLE
    SET search_path TO 'studync', 'pg_temp'
    AS $_$
    SELECT coalesce(p_plain IS NOT NULL AND p_stored LIKE '$2%' AND extensions.crypt(p_plain, p_stored) = p_stored, FALSE)
$_$;


ALTER FUNCTION studync.fn_verify_password(p_plain character varying, p_stored character varying) OWNER TO studync_owner;

--
-- Name: sp_add_question(character varying, character varying, text, character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_add_question(IN p_actor_user_id character varying, IN p_quiz_id character varying, IN p_question_text text, IN p_option_a character varying, IN p_option_b character varying, IN p_option_c character varying, IN p_option_d character varying, IN p_correct_answer character varying, OUT p_question_id character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_add_question(IN p_actor_user_id character varying, IN p_quiz_id character varying, IN p_question_text text, IN p_option_a character varying, IN p_option_b character varying, IN p_option_c character varying, IN p_option_d character varying, IN p_correct_answer character varying, OUT p_question_id character varying) OWNER TO studync_owner;

--
-- Name: sp_assert_quiz_owner(character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_assert_quiz_owner(IN p_actor_user_id character varying, IN p_quiz_id character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_assert_quiz_owner(IN p_actor_user_id character varying, IN p_quiz_id character varying) OWNER TO studync_owner;

--
-- Name: sp_assign_role(character varying, character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_assign_role(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_role_name character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_assign_role(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_role_name character varying) OWNER TO studync_owner;

--
-- Name: sp_authenticate_user(character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_authenticate_user(IN p_username character varying, IN p_password character varying, OUT p_success boolean, OUT p_user_id character varying, OUT p_roles character varying, OUT p_message character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_authenticate_user(IN p_username character varying, IN p_password character varying, OUT p_success boolean, OUT p_user_id character varying, OUT p_roles character varying, OUT p_message character varying) OWNER TO studync_owner;

--
-- Name: sp_change_password(character varying, character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_change_password(IN p_actor_user_id character varying, IN p_old_password character varying, IN p_new_password character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_change_password(IN p_actor_user_id character varying, IN p_old_password character varying, IN p_new_password character varying) OWNER TO studync_owner;

--
-- Name: sp_clear_actor(); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_clear_actor()
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
    AS $$ BEGIN PERFORM set_config('studync.app_user_id', '', true); END; $$;


ALTER PROCEDURE studync.sp_clear_actor() OWNER TO studync_owner;

--
-- Name: sp_create_profile(character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_create_profile(IN p_user_id character varying, IN p_role_name character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_profile_id character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_create_profile(IN p_user_id character varying, IN p_role_name character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_profile_id character varying) OWNER TO studync_owner;

--
-- Name: sp_create_quiz(character varying, character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_create_quiz(IN p_actor_user_id character varying, IN p_subject_id character varying, IN p_title character varying, OUT p_quiz_id character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_create_quiz(IN p_actor_user_id character varying, IN p_subject_id character varying, IN p_title character varying, OUT p_quiz_id character varying) OWNER TO studync_owner;

--
-- Name: sp_create_subject(character varying, character varying, text); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_create_subject(IN p_actor_user_id character varying, IN p_subject_name character varying, IN p_description text, OUT p_subject_id character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_create_subject(IN p_actor_user_id character varying, IN p_subject_name character varying, IN p_description text, OUT p_subject_id character varying) OWNER TO studync_owner;

--
-- Name: sp_delete_material(character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_delete_material(IN p_actor_user_id character varying, IN p_material_id character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_delete_material(IN p_actor_user_id character varying, IN p_material_id character varying) OWNER TO studync_owner;

--
-- Name: sp_delete_question(character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_delete_question(IN p_actor_user_id character varying, IN p_question_id character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_delete_question(IN p_actor_user_id character varying, IN p_question_id character varying) OWNER TO studync_owner;

--
-- Name: sp_delete_quiz(character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_delete_quiz(IN p_actor_user_id character varying, IN p_quiz_id character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_delete_quiz(IN p_actor_user_id character varying, IN p_quiz_id character varying) OWNER TO studync_owner;

--
-- Name: sp_delete_subject(character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_delete_subject(IN p_actor_user_id character varying, IN p_subject_id character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_delete_subject(IN p_actor_user_id character varying, IN p_subject_id character varying) OWNER TO studync_owner;

--
-- Name: sp_register_instructor(character varying, character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_register_instructor(IN p_actor_user_id character varying, IN p_username character varying, IN p_email character varying, IN p_password character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_user_id character varying, OUT p_instructor_id character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
    AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    CALL sp_register_user('Instructor', p_username, p_email, p_password, p_first_name, p_last_name,
                          p_user_id, p_instructor_id);
    CALL sp_clear_actor();
END;
$$;


ALTER PROCEDURE studync.sp_register_instructor(IN p_actor_user_id character varying, IN p_username character varying, IN p_email character varying, IN p_password character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_user_id character varying, OUT p_instructor_id character varying) OWNER TO studync_owner;

--
-- Name: sp_register_student(character varying, character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_register_student(IN p_actor_user_id character varying, IN p_username character varying, IN p_email character varying, IN p_password character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_user_id character varying, OUT p_student_id character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
    AS $$
BEGIN
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    CALL sp_register_user('Student', p_username, p_email, p_password, p_first_name, p_last_name,
                          p_user_id, p_student_id);
    CALL sp_clear_actor();
END;
$$;


ALTER PROCEDURE studync.sp_register_student(IN p_actor_user_id character varying, IN p_username character varying, IN p_email character varying, IN p_password character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_user_id character varying, OUT p_student_id character varying) OWNER TO studync_owner;

--
-- Name: sp_register_user(character varying, character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_register_user(IN p_role_name character varying, IN p_username character varying, IN p_email character varying, IN p_password character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_user_id character varying, OUT p_profile_id character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
    AS $_$
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
$_$;


ALTER PROCEDURE studync.sp_register_user(IN p_role_name character varying, IN p_username character varying, IN p_email character varying, IN p_password character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_user_id character varying, OUT p_profile_id character varying) OWNER TO studync_owner;

--
-- Name: sp_revoke_role(character varying, character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_revoke_role(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_role_name character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_revoke_role(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_role_name character varying) OWNER TO studync_owner;

--
-- Name: sp_set_actor(character varying, text); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_set_actor(IN p_actor_user_id character varying, IN p_allowed_roles text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_set_actor(IN p_actor_user_id character varying, IN p_allowed_roles text) OWNER TO studync_owner;

--
-- Name: sp_set_user_status(character varying, character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_set_user_status(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_status character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_set_user_status(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_status character varying) OWNER TO studync_owner;

--
-- Name: sp_submit_answer(character varying, character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_submit_answer(IN p_actor_user_id character varying, IN p_question_id character varying, IN p_answer character varying, OUT p_answer_id character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_submit_answer(IN p_actor_user_id character varying, IN p_question_id character varying, IN p_answer character varying, OUT p_answer_id character varying) OWNER TO studync_owner;

--
-- Name: sp_submit_quiz(character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_submit_quiz(IN p_actor_user_id character varying, IN p_quiz_id character varying, OUT p_result_id character varying, OUT p_score numeric)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_submit_quiz(IN p_actor_user_id character varying, IN p_quiz_id character varying, OUT p_result_id character varying, OUT p_score numeric) OWNER TO studync_owner;

--
-- Name: sp_update_material(character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_update_material(IN p_actor_user_id character varying, IN p_material_id character varying, IN p_subject_id character varying, IN p_title character varying, IN p_file_path character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_update_material(IN p_actor_user_id character varying, IN p_material_id character varying, IN p_subject_id character varying, IN p_title character varying, IN p_file_path character varying) OWNER TO studync_owner;

--
-- Name: sp_update_question(character varying, character varying, text, character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_update_question(IN p_actor_user_id character varying, IN p_question_id character varying, IN p_question_text text, IN p_option_a character varying, IN p_option_b character varying, IN p_option_c character varying, IN p_option_d character varying, IN p_correct_answer character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_update_question(IN p_actor_user_id character varying, IN p_question_id character varying, IN p_question_text text, IN p_option_a character varying, IN p_option_b character varying, IN p_option_c character varying, IN p_option_d character varying, IN p_correct_answer character varying) OWNER TO studync_owner;

--
-- Name: sp_update_quiz(character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_update_quiz(IN p_actor_user_id character varying, IN p_quiz_id character varying, IN p_subject_id character varying, IN p_title character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_update_quiz(IN p_actor_user_id character varying, IN p_quiz_id character varying, IN p_subject_id character varying, IN p_title character varying) OWNER TO studync_owner;

--
-- Name: sp_update_subject(character varying, character varying, character varying, text); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_update_subject(IN p_actor_user_id character varying, IN p_subject_id character varying, IN p_subject_name character varying, IN p_description text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_update_subject(IN p_actor_user_id character varying, IN p_subject_id character varying, IN p_subject_name character varying, IN p_description text) OWNER TO studync_owner;

--
-- Name: sp_update_user(character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_update_user(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_email character varying, IN p_first_name character varying, IN p_last_name character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
    AS $_$
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
$_$;


ALTER PROCEDURE studync.sp_update_user(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_email character varying, IN p_first_name character varying, IN p_last_name character varying) OWNER TO studync_owner;

--
-- Name: sp_upload_material(character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: studync; Owner: studync_owner
--

CREATE PROCEDURE studync.sp_upload_material(IN p_actor_user_id character varying, IN p_subject_id character varying, IN p_title character varying, IN p_file_path character varying, OUT p_material_id character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'studync', 'pg_temp'
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


ALTER PROCEDURE studync.sp_upload_material(IN p_actor_user_id character varying, IN p_subject_id character varying, IN p_title character varying, IN p_file_path character varying, OUT p_material_id character varying) OWNER TO studync_owner;

--
-- Name: tst_check_true(text, text, boolean, text); Type: FUNCTION; Schema: studync_test; Owner: postgres
--

CREATE FUNCTION studync_test.tst_check_true(p_id text, p_desc text, p_condition boolean, p_detail text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE v_outcome TEXT := CASE WHEN coalesce(p_condition, FALSE) THEN 'PASS' ELSE 'FAIL' END;
BEGIN
    INSERT INTO studync_test.results (test_id, description, expected, outcome, detail)
    VALUES (p_id, p_desc, 'TRUE', v_outcome, p_detail);
    RETURN rpad(p_id, 8) || ' ' || v_outcome || '  ' || p_desc || coalesce('  [' || p_detail || ']', '');
END $$;


ALTER FUNCTION studync_test.tst_check_true(p_id text, p_desc text, p_condition boolean, p_detail text) OWNER TO postgres;

--
-- Name: tst_expect_error(text, text, text, text); Type: FUNCTION; Schema: studync_test; Owner: postgres
--

CREATE FUNCTION studync_test.tst_expect_error(p_id text, p_desc text, p_sql text, p_expected text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_state TEXT; v_msg TEXT; v_pass BOOLEAN := FALSE; v_detail TEXT;
BEGIN
    BEGIN
        EXECUTE p_sql;
        v_detail := 'statement unexpectedly succeeded';
        RAISE EXCEPTION USING ERRCODE = 'ZZ999';        -- undo the unexpected change
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        IF v_state <> 'ZZ999' THEN
            v_detail := 'error ' || v_state || ': ' || v_msg;
            v_pass := p_expected IS NULL
                   OR (p_expected ~ '^[0-9A-Z]{5}$' AND v_state = p_expected)
                   OR (p_expected !~ '^[0-9A-Z]{5}$' AND strpos(v_msg, p_expected) > 0);
        END IF;
    END;
    INSERT INTO studync_test.results (test_id, description, expected, outcome, detail)
    VALUES (p_id, p_desc, 'ERROR ' || left(coalesce(p_expected, 'any'), 24),
            CASE WHEN v_pass THEN 'PASS' ELSE 'FAIL' END, v_detail);
    RETURN rpad(p_id, 8) || ' ' || CASE WHEN v_pass THEN 'PASS' ELSE 'FAIL' END || '  ' || p_desc || '  [' || v_detail || ']';
END $_$;


ALTER FUNCTION studync_test.tst_expect_error(p_id text, p_desc text, p_sql text, p_expected text) OWNER TO postgres;

--
-- Name: tst_expect_ok(text, text, text); Type: FUNCTION; Schema: studync_test; Owner: postgres
--

CREATE FUNCTION studync_test.tst_expect_ok(p_id text, p_desc text, p_sql text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_state TEXT; v_msg TEXT; v_outcome TEXT; v_detail TEXT;
BEGIN
    BEGIN
        EXECUTE p_sql;
        v_outcome := 'PASS'; v_detail := 'succeeded';
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        v_outcome := 'FAIL'; v_detail := 'error ' || v_state || ': ' || v_msg;
    END;
    INSERT INTO studync_test.results (test_id, description, expected, outcome, detail)
    VALUES (p_id, p_desc, 'SUCCESS', v_outcome, v_detail);
    RETURN rpad(p_id, 8) || ' ' || v_outcome || '  ' || p_desc || '  [' || v_detail || ']';
END $$;


ALTER FUNCTION studync_test.tst_expect_ok(p_id text, p_desc text, p_sql text) OWNER TO postgres;

--
-- Name: audit_logs_log_id_seq; Type: SEQUENCE; Schema: studync; Owner: studync_owner
--

ALTER TABLE studync.audit_logs ALTER COLUMN log_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME studync.audit_logs_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: seq_admins; Type: SEQUENCE; Schema: studync; Owner: studync_owner
--

CREATE SEQUENCE studync.seq_admins
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 9999999
    CACHE 1;


ALTER SEQUENCE studync.seq_admins OWNER TO studync_owner;

--
-- Name: seq_admins; Type: SEQUENCE OWNED BY; Schema: studync; Owner: studync_owner
--

ALTER SEQUENCE studync.seq_admins OWNED BY studync.admins.admin_id;


--
-- Name: seq_instructors; Type: SEQUENCE; Schema: studync; Owner: studync_owner
--

CREATE SEQUENCE studync.seq_instructors
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 9999999
    CACHE 1;


ALTER SEQUENCE studync.seq_instructors OWNER TO studync_owner;

--
-- Name: seq_instructors; Type: SEQUENCE OWNED BY; Schema: studync; Owner: studync_owner
--

ALTER SEQUENCE studync.seq_instructors OWNED BY studync.instructors.instructor_id;


--
-- Name: seq_materials; Type: SEQUENCE; Schema: studync; Owner: studync_owner
--

CREATE SEQUENCE studync.seq_materials
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 9999999
    CACHE 1;


ALTER SEQUENCE studync.seq_materials OWNER TO studync_owner;

--
-- Name: seq_materials; Type: SEQUENCE OWNED BY; Schema: studync; Owner: studync_owner
--

ALTER SEQUENCE studync.seq_materials OWNED BY studync.materials.material_id;


--
-- Name: seq_questions; Type: SEQUENCE; Schema: studync; Owner: studync_owner
--

CREATE SEQUENCE studync.seq_questions
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 9999999
    CACHE 1;


ALTER SEQUENCE studync.seq_questions OWNER TO studync_owner;

--
-- Name: seq_questions; Type: SEQUENCE OWNED BY; Schema: studync; Owner: studync_owner
--

ALTER SEQUENCE studync.seq_questions OWNED BY studync.questions.question_id;


--
-- Name: seq_quiz_results; Type: SEQUENCE; Schema: studync; Owner: studync_owner
--

CREATE SEQUENCE studync.seq_quiz_results
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 9999999
    CACHE 1;


ALTER SEQUENCE studync.seq_quiz_results OWNER TO studync_owner;

--
-- Name: seq_quiz_results; Type: SEQUENCE OWNED BY; Schema: studync; Owner: studync_owner
--

ALTER SEQUENCE studync.seq_quiz_results OWNED BY studync.quiz_results.result_id;


--
-- Name: seq_quizzes; Type: SEQUENCE; Schema: studync; Owner: studync_owner
--

CREATE SEQUENCE studync.seq_quizzes
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 9999999
    CACHE 1;


ALTER SEQUENCE studync.seq_quizzes OWNER TO studync_owner;

--
-- Name: seq_quizzes; Type: SEQUENCE OWNED BY; Schema: studync; Owner: studync_owner
--

ALTER SEQUENCE studync.seq_quizzes OWNED BY studync.quizzes.quiz_id;


--
-- Name: seq_student_answers; Type: SEQUENCE; Schema: studync; Owner: studync_owner
--

CREATE SEQUENCE studync.seq_student_answers
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 9999999
    CACHE 1;


ALTER SEQUENCE studync.seq_student_answers OWNER TO studync_owner;

--
-- Name: seq_student_answers; Type: SEQUENCE OWNED BY; Schema: studync; Owner: studync_owner
--

ALTER SEQUENCE studync.seq_student_answers OWNED BY studync.student_answers.answer_id;


--
-- Name: seq_students; Type: SEQUENCE; Schema: studync; Owner: studync_owner
--

CREATE SEQUENCE studync.seq_students
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 9999999
    CACHE 1;


ALTER SEQUENCE studync.seq_students OWNER TO studync_owner;

--
-- Name: seq_students; Type: SEQUENCE OWNED BY; Schema: studync; Owner: studync_owner
--

ALTER SEQUENCE studync.seq_students OWNED BY studync.students.student_id;


--
-- Name: seq_subjects; Type: SEQUENCE; Schema: studync; Owner: studync_owner
--

CREATE SEQUENCE studync.seq_subjects
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 9999999
    CACHE 1;


ALTER SEQUENCE studync.seq_subjects OWNER TO studync_owner;

--
-- Name: seq_subjects; Type: SEQUENCE OWNED BY; Schema: studync; Owner: studync_owner
--

ALTER SEQUENCE studync.seq_subjects OWNED BY studync.subjects.subject_id;


--
-- Name: seq_users; Type: SEQUENCE; Schema: studync; Owner: studync_owner
--

CREATE SEQUENCE studync.seq_users
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 9999999
    CACHE 1;


ALTER SEQUENCE studync.seq_users OWNER TO studync_owner;

--
-- Name: seq_users; Type: SEQUENCE OWNED BY; Schema: studync; Owner: studync_owner
--

ALTER SEQUENCE studync.seq_users OWNED BY studync.users.user_id;


--
-- Name: v_my_results; Type: VIEW; Schema: studync; Owner: studync_owner
--

CREATE VIEW studync.v_my_results WITH (security_barrier='true') AS
 SELECT qr.result_id,
    q.quiz_id,
    q.title AS quiz_title,
    sb.subject_name,
    qr.score,
    ( SELECT count(*) AS count
           FROM (studync.student_answers sa
             JOIN studync.questions qs ON (((qs.question_id)::text = (sa.question_id)::text)))
          WHERE (((sa.student_id)::text = (qr.student_id)::text) AND ((qs.quiz_id)::text = (qr.quiz_id)::text) AND sa.is_correct)) AS correct_answers,
    ( SELECT count(*) AS count
           FROM studync.questions qs
          WHERE ((qs.quiz_id)::text = (qr.quiz_id)::text)) AS total_questions
   FROM ((((studync.quiz_results qr
     JOIN studync.students st ON (((st.student_id)::text = (qr.student_id)::text)))
     JOIN studync.users u ON (((u.user_id)::text = (st.user_id)::text)))
     JOIN studync.quizzes q ON (((q.quiz_id)::text = (qr.quiz_id)::text)))
     JOIN studync.subjects sb ON (((sb.subject_id)::text = (q.subject_id)::text)))
  WHERE (lower((u.username)::text) = lower((SESSION_USER)::text));


ALTER VIEW studync.v_my_results OWNER TO studync_owner;

--
-- Name: v_quiz_overview; Type: VIEW; Schema: studync; Owner: studync_owner
--

CREATE VIEW studync.v_quiz_overview AS
 SELECT q.quiz_id,
    q.title,
    q.created_at,
    sb.subject_id,
    sb.subject_name,
    i.instructor_id,
    (((i.first_name)::text || ' '::text) || (i.last_name)::text) AS instructor_name,
    ( SELECT count(*) AS count
           FROM studync.questions qs
          WHERE ((qs.quiz_id)::text = (q.quiz_id)::text)) AS question_count
   FROM ((studync.quizzes q
     JOIN studync.subjects sb ON (((sb.subject_id)::text = (q.subject_id)::text)))
     JOIN studync.instructors i ON (((i.instructor_id)::text = (q.instructor_id)::text)));


ALTER VIEW studync.v_quiz_overview OWNER TO studync_owner;

--
-- Name: v_quiz_questions_instructor; Type: VIEW; Schema: studync; Owner: studync_owner
--

CREATE VIEW studync.v_quiz_questions_instructor AS
 SELECT qs.question_id,
    qs.quiz_id,
    q.title AS quiz_title,
    q.instructor_id,
    qs.question_text,
    qs.option_a,
    qs.option_b,
    qs.option_c,
    qs.option_d,
    qs.correct_answer,
    ( SELECT count(*) AS count
           FROM studync.student_answers sa
          WHERE ((sa.question_id)::text = (qs.question_id)::text)) AS times_answered,
    ( SELECT count(*) AS count
           FROM studync.student_answers sa
          WHERE (((sa.question_id)::text = (qs.question_id)::text) AND sa.is_correct)) AS times_correct
   FROM (studync.questions qs
     JOIN studync.quizzes q ON (((q.quiz_id)::text = (qs.quiz_id)::text)));


ALTER VIEW studync.v_quiz_questions_instructor OWNER TO studync_owner;

--
-- Name: v_quiz_questions_student; Type: VIEW; Schema: studync; Owner: studync_owner
--

CREATE VIEW studync.v_quiz_questions_student AS
 SELECT qs.question_id,
    qs.quiz_id,
    q.title AS quiz_title,
    qs.question_text,
    qs.option_a,
    qs.option_b,
    qs.option_c,
    qs.option_d
   FROM (studync.questions qs
     JOIN studync.quizzes q ON (((q.quiz_id)::text = (qs.quiz_id)::text)));


ALTER VIEW studync.v_quiz_questions_student OWNER TO studync_owner;

--
-- Name: v_student_performance; Type: VIEW; Schema: studync; Owner: studync_owner
--

CREATE VIEW studync.v_student_performance AS
 SELECT st.student_id,
    (((st.first_name)::text || ' '::text) || (st.last_name)::text) AS student_name,
    u.status AS account_status,
    count(qr.result_id) AS quizzes_taken,
    round(avg(qr.score), 2) AS average_score,
    max(qr.score) AS highest_score,
    min(qr.score) AS lowest_score
   FROM ((studync.students st
     JOIN studync.users u ON (((u.user_id)::text = (st.user_id)::text)))
     LEFT JOIN studync.quiz_results qr ON (((qr.student_id)::text = (st.student_id)::text)))
  GROUP BY st.student_id, st.first_name, st.last_name, u.status;


ALTER VIEW studync.v_student_performance OWNER TO studync_owner;

--
-- Name: v_subject_catalog; Type: VIEW; Schema: studync; Owner: studync_owner
--

CREATE VIEW studync.v_subject_catalog AS
 SELECT subject_id,
    subject_name,
    description,
    ( SELECT count(*) AS count
           FROM studync.materials m
          WHERE ((m.subject_id)::text = (sb.subject_id)::text)) AS material_count,
    ( SELECT count(*) AS count
           FROM studync.quizzes q
          WHERE ((q.subject_id)::text = (sb.subject_id)::text)) AS quiz_count
   FROM studync.subjects sb;


ALTER VIEW studync.v_subject_catalog OWNER TO studync_owner;

--
-- Name: results; Type: TABLE; Schema: studync_test; Owner: postgres
--

CREATE TABLE studync_test.results (
    seq integer NOT NULL,
    test_id character varying(12) NOT NULL,
    description character varying(255) NOT NULL,
    expected character varying(30) NOT NULL,
    outcome character varying(4) NOT NULL,
    detail text,
    run_as character varying(100) DEFAULT SESSION_USER NOT NULL,
    run_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT results_outcome_check CHECK (((outcome)::text = ANY ((ARRAY['PASS'::character varying, 'FAIL'::character varying])::text[])))
);


ALTER TABLE studync_test.results OWNER TO postgres;

--
-- Name: results_seq_seq; Type: SEQUENCE; Schema: studync_test; Owner: postgres
--

ALTER TABLE studync_test.results ALTER COLUMN seq ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME studync_test.results_seq_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: admins admin_id; Type: DEFAULT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.admins ALTER COLUMN admin_id SET DEFAULT ('ADM'::text || lpad((nextval('studync.seq_admins'::regclass))::text, 7, '0'::text));


--
-- Name: instructors instructor_id; Type: DEFAULT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.instructors ALTER COLUMN instructor_id SET DEFAULT ('INS'::text || lpad((nextval('studync.seq_instructors'::regclass))::text, 7, '0'::text));


--
-- Name: materials material_id; Type: DEFAULT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.materials ALTER COLUMN material_id SET DEFAULT ('MAT'::text || lpad((nextval('studync.seq_materials'::regclass))::text, 7, '0'::text));


--
-- Name: questions question_id; Type: DEFAULT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.questions ALTER COLUMN question_id SET DEFAULT ('QST'::text || lpad((nextval('studync.seq_questions'::regclass))::text, 7, '0'::text));


--
-- Name: quiz_results result_id; Type: DEFAULT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.quiz_results ALTER COLUMN result_id SET DEFAULT ('RES'::text || lpad((nextval('studync.seq_quiz_results'::regclass))::text, 7, '0'::text));


--
-- Name: quizzes quiz_id; Type: DEFAULT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.quizzes ALTER COLUMN quiz_id SET DEFAULT ('QUZ'::text || lpad((nextval('studync.seq_quizzes'::regclass))::text, 7, '0'::text));


--
-- Name: student_answers answer_id; Type: DEFAULT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.student_answers ALTER COLUMN answer_id SET DEFAULT ('ANS'::text || lpad((nextval('studync.seq_student_answers'::regclass))::text, 7, '0'::text));


--
-- Name: students student_id; Type: DEFAULT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.students ALTER COLUMN student_id SET DEFAULT ('STU'::text || lpad((nextval('studync.seq_students'::regclass))::text, 7, '0'::text));


--
-- Name: subjects subject_id; Type: DEFAULT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.subjects ALTER COLUMN subject_id SET DEFAULT ('SUB'::text || lpad((nextval('studync.seq_subjects'::regclass))::text, 7, '0'::text));


--
-- Name: users user_id; Type: DEFAULT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.users ALTER COLUMN user_id SET DEFAULT ('USR'::text || lpad((nextval('studync.seq_users'::regclass))::text, 7, '0'::text));


--
-- Data for Name: admins; Type: TABLE DATA; Schema: studync; Owner: studync_owner
--

COPY studync.admins (admin_id, user_id, first_name, last_name) FROM stdin;
ADM0000001	USR0000001	Maria	Reyes
ADM0000002	USR0000002	Carlo	Mendoza
ADM0000003	USR0000014	Paolo	Lim
\.


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: studync; Owner: studync_owner
--

COPY studync.audit_logs (log_id, action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data, log_timestamp) FROM stdin;
1	INSERT	users	USR0000001	\N	postgres	Created users record USR0000001	\N	{"email": "maria.reyes@studync.edu", "status": "Active", "user_id": "USR0000001", "username": "maria.reyes", "created_at": "2026-11-25T08:20:19.006917+08:00"}	2026-11-25 08:20:19.056348+08
2	INSERT	user_roles	USR0000001:ROL0000001	\N	postgres	Created user_roles record USR0000001:ROL0000001	\N	{"role_id": "ROL0000001", "user_id": "USR0000001"}	2026-11-25 08:20:19.060638+08
3	INSERT	admins	ADM0000001	\N	postgres	Created admins record ADM0000001	\N	{"user_id": "USR0000001", "admin_id": "ADM0000001", "last_name": "Reyes", "first_name": "Maria"}	2026-11-25 08:20:19.061983+08
4	INSERT	users	USR0000002	\N	postgres	Created users record USR0000002	\N	{"email": "carlo.mendoza@studync.edu", "status": "Active", "user_id": "USR0000002", "username": "carlo.mendoza", "created_at": "2026-11-25T08:20:19.006917+08:00"}	2026-11-25 08:20:19.103716+08
5	INSERT	user_roles	USR0000002:ROL0000001	\N	postgres	Created user_roles record USR0000002:ROL0000001	\N	{"role_id": "ROL0000001", "user_id": "USR0000002"}	2026-11-25 08:20:19.103935+08
6	INSERT	admins	ADM0000002	\N	postgres	Created admins record ADM0000002	\N	{"user_id": "USR0000002", "admin_id": "ADM0000002", "last_name": "Mendoza", "first_name": "Carlo"}	2026-11-25 08:20:19.104096+08
7	INSERT	users	USR0000003	USR0000001	postgres	Created users record USR0000003	\N	{"email": "jose.cruz@studync.edu", "status": "Active", "user_id": "USR0000003", "username": "jose.cruz", "created_at": "2026-11-25T08:20:19.006917+08:00"}	2026-11-25 08:20:19.153485+08
8	INSERT	user_roles	USR0000003:ROL0000002	USR0000001	postgres	Created user_roles record USR0000003:ROL0000002	\N	{"role_id": "ROL0000002", "user_id": "USR0000003"}	2026-11-25 08:20:19.153763+08
9	INSERT	instructors	INS0000001	USR0000001	postgres	Created instructors record INS0000001	\N	{"user_id": "USR0000003", "last_name": "Cruz", "first_name": "Jose", "instructor_id": "INS0000001"}	2026-11-25 08:20:19.156296+08
10	INSERT	users	USR0000004	USR0000001	postgres	Created users record USR0000004	\N	{"email": "liza.garcia@studync.edu", "status": "Active", "user_id": "USR0000004", "username": "liza.garcia", "created_at": "2026-11-25T08:20:19.006917+08:00"}	2026-11-25 08:20:19.205647+08
11	INSERT	user_roles	USR0000004:ROL0000002	USR0000001	postgres	Created user_roles record USR0000004:ROL0000002	\N	{"role_id": "ROL0000002", "user_id": "USR0000004"}	2026-11-25 08:20:19.205857+08
12	INSERT	instructors	INS0000002	USR0000001	postgres	Created instructors record INS0000002	\N	{"user_id": "USR0000004", "last_name": "Garcia", "first_name": "Liza", "instructor_id": "INS0000002"}	2026-11-25 08:20:19.206014+08
13	INSERT	users	USR0000005	USR0000001	postgres	Created users record USR0000005	\N	{"email": "ramon.villanueva@studync.edu", "status": "Active", "user_id": "USR0000005", "username": "ramon.villanueva", "created_at": "2026-11-25T08:20:19.006917+08:00"}	2026-11-25 08:20:19.2532+08
14	INSERT	user_roles	USR0000005:ROL0000002	USR0000001	postgres	Created user_roles record USR0000005:ROL0000002	\N	{"role_id": "ROL0000002", "user_id": "USR0000005"}	2026-11-25 08:20:19.253418+08
15	INSERT	instructors	INS0000003	USR0000001	postgres	Created instructors record INS0000003	\N	{"user_id": "USR0000005", "last_name": "Villanueva", "first_name": "Ramon", "instructor_id": "INS0000003"}	2026-11-25 08:20:19.25358+08
16	INSERT	users	USR0000006	USR0000001	postgres	Created users record USR0000006	\N	{"email": "ana.santos@studync.edu", "status": "Active", "user_id": "USR0000006", "username": "ana.santos", "created_at": "2026-11-25T08:20:19.006917+08:00"}	2026-11-25 08:20:19.302645+08
17	INSERT	user_roles	USR0000006:ROL0000003	USR0000001	postgres	Created user_roles record USR0000006:ROL0000003	\N	{"role_id": "ROL0000003", "user_id": "USR0000006"}	2026-11-25 08:20:19.302863+08
18	INSERT	students	STU0000001	USR0000001	postgres	Created students record STU0000001	\N	{"user_id": "USR0000006", "last_name": "Santos", "first_name": "Ana", "student_id": "STU0000001"}	2026-11-25 08:20:19.305475+08
19	INSERT	users	USR0000007	USR0000001	postgres	Created users record USR0000007	\N	{"email": "ben.torres@studync.edu", "status": "Active", "user_id": "USR0000007", "username": "ben.torres", "created_at": "2026-11-25T08:20:19.006917+08:00"}	2026-11-25 08:20:19.352546+08
20	INSERT	user_roles	USR0000007:ROL0000003	USR0000001	postgres	Created user_roles record USR0000007:ROL0000003	\N	{"role_id": "ROL0000003", "user_id": "USR0000007"}	2026-11-25 08:20:19.352743+08
21	INSERT	students	STU0000002	USR0000001	postgres	Created students record STU0000002	\N	{"user_id": "USR0000007", "last_name": "Torres", "first_name": "Ben", "student_id": "STU0000002"}	2026-11-25 08:20:19.352916+08
22	INSERT	users	USR0000008	USR0000001	postgres	Created users record USR0000008	\N	{"email": "carla.dizon@studync.edu", "status": "Active", "user_id": "USR0000008", "username": "carla.dizon", "created_at": "2026-11-25T08:20:19.006917+08:00"}	2026-11-25 08:20:19.405142+08
23	INSERT	user_roles	USR0000008:ROL0000003	USR0000001	postgres	Created user_roles record USR0000008:ROL0000003	\N	{"role_id": "ROL0000003", "user_id": "USR0000008"}	2026-11-25 08:20:19.405348+08
24	INSERT	students	STU0000003	USR0000001	postgres	Created students record STU0000003	\N	{"user_id": "USR0000008", "last_name": "Dizon", "first_name": "Carla", "student_id": "STU0000003"}	2026-11-25 08:20:19.405569+08
25	INSERT	users	USR0000009	USR0000001	postgres	Created users record USR0000009	\N	{"email": "diego.ramos@studync.edu", "status": "Active", "user_id": "USR0000009", "username": "diego.ramos", "created_at": "2026-11-25T08:20:19.006917+08:00"}	2026-11-25 08:20:19.457766+08
26	INSERT	user_roles	USR0000009:ROL0000003	USR0000001	postgres	Created user_roles record USR0000009:ROL0000003	\N	{"role_id": "ROL0000003", "user_id": "USR0000009"}	2026-11-25 08:20:19.45801+08
27	INSERT	students	STU0000004	USR0000001	postgres	Created students record STU0000004	\N	{"user_id": "USR0000009", "last_name": "Ramos", "first_name": "Diego", "student_id": "STU0000004"}	2026-11-25 08:20:19.458236+08
28	INSERT	users	USR0000010	USR0000001	postgres	Created users record USR0000010	\N	{"email": "ella.navarro@studync.edu", "status": "Active", "user_id": "USR0000010", "username": "ella.navarro", "created_at": "2026-11-25T08:20:19.006917+08:00"}	2026-11-25 08:20:19.506257+08
29	INSERT	user_roles	USR0000010:ROL0000003	USR0000001	postgres	Created user_roles record USR0000010:ROL0000003	\N	{"role_id": "ROL0000003", "user_id": "USR0000010"}	2026-11-25 08:20:19.506373+08
30	INSERT	students	STU0000005	USR0000001	postgres	Created students record STU0000005	\N	{"user_id": "USR0000010", "last_name": "Navarro", "first_name": "Ella", "student_id": "STU0000005"}	2026-11-25 08:20:19.50654+08
31	INSERT	users	USR0000011	USR0000001	postgres	Created users record USR0000011	\N	{"email": "felix.aquino@studync.edu", "status": "Active", "user_id": "USR0000011", "username": "felix.aquino", "created_at": "2026-11-25T08:20:19.006917+08:00"}	2026-11-25 08:20:19.554084+08
32	INSERT	user_roles	USR0000011:ROL0000003	USR0000001	postgres	Created user_roles record USR0000011:ROL0000003	\N	{"role_id": "ROL0000003", "user_id": "USR0000011"}	2026-11-25 08:20:19.5543+08
33	INSERT	students	STU0000006	USR0000001	postgres	Created students record STU0000006	\N	{"user_id": "USR0000011", "last_name": "Aquino", "first_name": "Felix", "student_id": "STU0000006"}	2026-11-25 08:20:19.554571+08
34	INSERT	users	USR0000012	USR0000001	postgres	Created users record USR0000012	\N	{"email": "gina.lopez@studync.edu", "status": "Active", "user_id": "USR0000012", "username": "gina.lopez", "created_at": "2026-11-25T08:20:19.006917+08:00"}	2026-11-25 08:20:19.601065+08
35	INSERT	user_roles	USR0000012:ROL0000003	USR0000001	postgres	Created user_roles record USR0000012:ROL0000003	\N	{"role_id": "ROL0000003", "user_id": "USR0000012"}	2026-11-25 08:20:19.601833+08
36	INSERT	students	STU0000007	USR0000001	postgres	Created students record STU0000007	\N	{"user_id": "USR0000012", "last_name": "Lopez", "first_name": "Gina", "student_id": "STU0000007"}	2026-11-25 08:20:19.60194+08
37	UPDATE	users	USR0000012	USR0000001	postgres	Updated users record USR0000012	{"email": "gina.lopez@studync.edu", "status": "Active", "user_id": "USR0000012", "username": "gina.lopez", "created_at": "2026-11-25T08:20:19.006917+08:00"}	{"email": "gina.lopez@studync.edu", "status": "Inactive", "user_id": "USR0000012", "username": "gina.lopez", "created_at": "2026-11-25T08:20:19.006917+08:00", "password_changed": false}	2026-11-25 08:20:19.603253+08
38	INSERT	user_roles	USR0000002:ROL0000002	USR0000001	postgres	Created user_roles record USR0000002:ROL0000002	\N	{"role_id": "ROL0000002", "user_id": "USR0000002"}	2026-11-25 08:20:19.603715+08
39	INSERT	instructors	INS0000004	USR0000001	postgres	Created instructors record INS0000004	\N	{"user_id": "USR0000002", "last_name": "Mendoza", "first_name": "Carlo", "instructor_id": "INS0000004"}	2026-11-25 08:20:19.60424+08
40	INSERT	subjects	SUB0000001	USR0000001	postgres	Created subjects record SUB0000001	\N	{"subject_id": "SUB0000001", "description": "Roles, privileges, auditing, backup and recovery of relational databases.", "subject_name": "Database Security and Administration"}	2026-11-25 08:20:19.606414+08
41	INSERT	subjects	SUB0000002	USR0000001	postgres	Created subjects record SUB0000002	\N	{"subject_id": "SUB0000002", "description": "HTML, CSS and JavaScript for building accessible web pages.", "subject_name": "Web Development Fundamentals"}	2026-11-25 08:20:19.606772+08
42	INSERT	subjects	SUB0000003	USR0000001	postgres	Created subjects record SUB0000003	\N	{"subject_id": "SUB0000003", "description": "Arrays, lists, trees, graphs and algorithm analysis.", "subject_name": "Data Structures and Algorithms"}	2026-11-25 08:20:19.607096+08
43	INSERT	subjects	SUB0000004	USR0000001	postgres	Created subjects record SUB0000004	\N	{"subject_id": "SUB0000004", "description": "OSI model, TCP/IP, addressing and basic network security.", "subject_name": "Networking Essentials"}	2026-11-25 08:20:19.607316+08
44	INSERT	subjects	SUB0000005	USR0000001	postgres	Created subjects record SUB0000005	\N	{"subject_id": "SUB0000005", "description": "Writing clear technical documentation and reports.", "subject_name": "Technical Writing"}	2026-11-25 08:20:19.6076+08
45	UPDATE	subjects	SUB0000004	USR0000001	postgres	Updated subjects record SUB0000004	{"subject_id": "SUB0000004", "description": "OSI model, TCP/IP, addressing and basic network security.", "subject_name": "Networking Essentials"}	{"subject_id": "SUB0000004", "description": "OSI model, TCP/IP, IP addressing, subnetting and basic network security.", "subject_name": "Networking Essentials"}	2026-11-25 08:20:19.608369+08
46	INSERT	materials	MAT0000001	USR0000003	postgres	Created materials record MAT0000001	\N	{"title": "Introduction to Database Security", "file_path": "materials/sub1/intro-db-security.pdf", "subject_id": "SUB0000001", "material_id": "MAT0000001", "uploaded_at": "2026-11-25T08:20:19.006917+08:00", "instructor_id": "INS0000001"}	2026-11-25 08:20:19.611008+08
47	INSERT	materials	MAT0000002	USR0000003	postgres	Created materials record MAT0000002	\N	{"title": "Managing Roles and Privileges", "file_path": "materials/sub1/roles-and-privileges.pdf", "subject_id": "SUB0000001", "material_id": "MAT0000002", "uploaded_at": "2026-11-25T08:20:19.006917+08:00", "instructor_id": "INS0000001"}	2026-11-25 08:20:19.611341+08
48	INSERT	materials	MAT0000003	USR0000003	postgres	Created materials record MAT0000003	\N	{"title": "Audit Trails with Triggers", "file_path": "materials/sub1/audit-trails.pptx", "subject_id": "SUB0000001", "material_id": "MAT0000003", "uploaded_at": "2026-11-25T08:20:19.006917+08:00", "instructor_id": "INS0000001"}	2026-11-25 08:20:19.611614+08
49	INSERT	materials	MAT0000004	USR0000004	postgres	Created materials record MAT0000004	\N	{"title": "HTML5 Document Structure", "file_path": "materials/sub2/html5-structure.pdf", "subject_id": "SUB0000002", "material_id": "MAT0000004", "uploaded_at": "2026-11-25T08:20:19.006917+08:00", "instructor_id": "INS0000002"}	2026-11-25 08:20:19.611867+08
50	INSERT	materials	MAT0000005	USR0000004	postgres	Created materials record MAT0000005	\N	{"title": "CSS Flexbox Guide", "file_path": "materials/sub2/css-flexbox.pdf", "subject_id": "SUB0000002", "material_id": "MAT0000005", "uploaded_at": "2026-11-25T08:20:19.006917+08:00", "instructor_id": "INS0000002"}	2026-11-25 08:20:19.612109+08
51	INSERT	materials	MAT0000006	USR0000004	postgres	Created materials record MAT0000006	\N	{"title": "JavaScript Basics Video", "file_path": "https://videos.studync.edu/js-basics", "subject_id": "SUB0000002", "material_id": "MAT0000006", "uploaded_at": "2026-11-25T08:20:19.006917+08:00", "instructor_id": "INS0000002"}	2026-11-25 08:20:19.612612+08
52	INSERT	materials	MAT0000007	USR0000005	postgres	Created materials record MAT0000007	\N	{"title": "Big-O Notation Lecture", "file_path": "materials/sub3/big-o.pdf", "subject_id": "SUB0000003", "material_id": "MAT0000007", "uploaded_at": "2026-11-25T08:20:19.006917+08:00", "instructor_id": "INS0000003"}	2026-11-25 08:20:19.612801+08
53	INSERT	materials	MAT0000008	USR0000005	postgres	Created materials record MAT0000008	\N	{"title": "Linked Lists Worksheet", "file_path": "materials/sub3/linked-lists.docx", "subject_id": "SUB0000003", "material_id": "MAT0000008", "uploaded_at": "2026-11-25T08:20:19.006917+08:00", "instructor_id": "INS0000003"}	2026-11-25 08:20:19.612952+08
54	UPDATE	materials	MAT0000005	USR0000004	postgres	Updated materials record MAT0000005	{"title": "CSS Flexbox Guide", "file_path": "materials/sub2/css-flexbox.pdf", "subject_id": "SUB0000002", "material_id": "MAT0000005", "uploaded_at": "2026-11-25T08:20:19.006917+08:00", "instructor_id": "INS0000002"}	{"title": "CSS Flexbox and Grid Guide", "file_path": "materials/sub2/css-flexbox-grid.pdf", "subject_id": "SUB0000002", "material_id": "MAT0000005", "uploaded_at": "2026-11-25T08:20:19.006917+08:00", "instructor_id": "INS0000002"}	2026-11-25 08:20:19.613767+08
55	INSERT	materials	MAT0000009	USR0000005	postgres	Created materials record MAT0000009	\N	{"title": "Big-O Notation Lecture (old copy)", "file_path": "materials/sub3/big-o-old.pdf", "subject_id": "SUB0000003", "material_id": "MAT0000009", "uploaded_at": "2026-11-25T08:20:19.006917+08:00", "instructor_id": "INS0000003"}	2026-11-25 08:20:19.61401+08
56	DELETE	materials	MAT0000009	USR0000005	postgres	Deleted materials record MAT0000009	{"title": "Big-O Notation Lecture (old copy)", "file_path": "materials/sub3/big-o-old.pdf", "subject_id": "SUB0000003", "material_id": "MAT0000009", "uploaded_at": "2026-11-25T08:20:19.006917+08:00", "instructor_id": "INS0000003"}	\N	2026-11-25 08:20:19.614515+08
191	INSERT	quiz_results	RES0000016	USR0000006	ana.santos	Created quiz_results record RES0000016	\N	{"score": 66.67, "quiz_id": "QUZ0000004", "result_id": "RES0000016", "student_id": "STU0000001"}	2026-11-25 08:20:30.986129+08
57	INSERT	quizzes	QUZ0000001	USR0000003	postgres	Created quizzes record QUZ0000001	\N	{"title": "SQL Security Basics", "quiz_id": "QUZ0000001", "created_at": "2026-11-25T08:20:19.006917+08:00", "subject_id": "SUB0000001", "instructor_id": "INS0000001"}	2026-11-25 08:20:19.616999+08
58	INSERT	quizzes	QUZ0000002	USR0000003	postgres	Created quizzes record QUZ0000002	\N	{"title": "Database Roles and Privileges", "quiz_id": "QUZ0000002", "created_at": "2026-11-25T08:20:19.006917+08:00", "subject_id": "SUB0000001", "instructor_id": "INS0000001"}	2026-11-25 08:20:19.617316+08
59	INSERT	quizzes	QUZ0000003	USR0000004	postgres	Created quizzes record QUZ0000003	\N	{"title": "HTML and CSS Basics", "quiz_id": "QUZ0000003", "created_at": "2026-11-25T08:20:19.006917+08:00", "subject_id": "SUB0000002", "instructor_id": "INS0000002"}	2026-11-25 08:20:19.617566+08
60	INSERT	quizzes	QUZ0000004	USR0000005	postgres	Created quizzes record QUZ0000004	\N	{"title": "Big-O Notation", "quiz_id": "QUZ0000004", "created_at": "2026-11-25T08:20:19.006917+08:00", "subject_id": "SUB0000003", "instructor_id": "INS0000003"}	2026-11-25 08:20:19.61784+08
61	INSERT	quizzes	QUZ0000005	USR0000004	postgres	Created quizzes record QUZ0000005	\N	{"title": "JavaScript Fundamentals", "quiz_id": "QUZ0000005", "created_at": "2026-11-25T08:20:19.006917+08:00", "subject_id": "SUB0000002", "instructor_id": "INS0000002"}	2026-11-25 08:20:19.618065+08
62	INSERT	questions	QST0000001	USR0000003	postgres	Created questions record QST0000001	\N	{"quiz_id": "QUZ0000001", "option_a": "REVOKE", "option_b": "GRANT", "option_c": "DENY", "option_d": "ALLOW", "question_id": "QST0000001", "question_text": "Which SQL statement gives a privilege to a user or role?", "correct_answer": "GRANT"}	2026-11-25 08:20:19.621919+08
63	INSERT	questions	QST0000002	USR0000003	postgres	Created questions record QST0000002	\N	{"quiz_id": "QUZ0000001", "option_a": "Phishing", "option_b": "Brute force", "option_c": "SQL injection", "option_d": "Spoofing", "question_id": "QST0000002", "question_text": "Which attack inserts malicious SQL through user input?", "correct_answer": "SQL injection"}	2026-11-25 08:20:19.622327+08
64	INSERT	questions	QST0000003	USR0000003	postgres	Created questions record QST0000003	\N	{"quiz_id": "QUZ0000001", "option_a": "A salted hash", "option_b": "The password in upper case", "option_c": "An encrypted email", "option_d": "Nothing", "question_id": "QST0000003", "question_text": "What should be stored instead of a plain-text password?", "correct_answer": "A salted hash"}	2026-11-25 08:20:19.622653+08
65	INSERT	questions	QST0000004	USR0000003	postgres	Created questions record QST0000004	\N	{"quiz_id": "QUZ0000001", "option_a": "Index", "option_b": "Trigger", "option_c": "Sequence", "option_d": "View", "question_id": "QST0000004", "question_text": "Which object can hide sensitive columns from users?", "correct_answer": "View"}	2026-11-25 08:20:19.62297+08
66	INSERT	questions	QST0000005	USR0000003	postgres	Created questions record QST0000005	\N	{"quiz_id": "QUZ0000001", "option_a": "Defense in depth", "option_b": "Least privilege", "option_c": "Separation of data", "option_d": "Normalization", "question_id": "QST0000005", "question_text": "The principle of giving users only the access they need is called:", "correct_answer": "Least privilege"}	2026-11-25 08:20:19.62334+08
67	INSERT	questions	QST0000006	USR0000003	postgres	Created questions record QST0000006	\N	{"quiz_id": "QUZ0000002", "option_a": "REVOKE", "option_b": "DROP", "option_c": "DELETE", "option_d": "REMOVE", "question_id": "QST0000006", "question_text": "Which statement removes a previously granted privilege?", "correct_answer": "REVOKE"}	2026-11-25 08:20:19.623766+08
68	INSERT	questions	QST0000007	USR0000003	postgres	Created questions record QST0000007	\N	{"quiz_id": "QUZ0000002", "option_a": "Schema", "option_b": "Synonym", "option_c": "Role", "option_d": "Cursor", "question_id": "QST0000007", "question_text": "A named group of privileges is called a:", "correct_answer": "Role"}	2026-11-25 08:20:19.624029+08
69	INSERT	questions	QST0000008	USR0000003	postgres	Created questions record QST0000008	\N	{"quiz_id": "QUZ0000002", "option_a": "SELECT", "option_b": "EXECUTE", "option_c": "USAGE", "option_d": "CALL", "question_id": "QST0000008", "question_text": "Which privilege allows calling a stored procedure?", "correct_answer": "EXECUTE"}	2026-11-25 08:20:19.624225+08
70	INSERT	questions	QST0000009	USR0000003	postgres	Created questions record QST0000009	\N	{"quiz_id": "QUZ0000002", "option_a": "Temp table", "option_b": "Lookup table", "option_c": "Junction table", "option_d": "Audit log", "question_id": "QST0000009", "question_text": "Which table records who changed data and when?", "correct_answer": "Audit log"}	2026-11-25 08:20:19.62464+08
71	INSERT	questions	QST0000010	USR0000004	postgres	Created questions record QST0000010	\N	{"quiz_id": "QUZ0000003", "option_a": "<head>", "option_b": "<h6>", "option_c": "<h1>", "option_d": "<header>", "question_id": "QST0000010", "question_text": "Which tag creates the largest heading?", "correct_answer": "<h1>"}	2026-11-25 08:20:19.624879+08
72	INSERT	questions	QST0000011	USR0000004	postgres	Created questions record QST0000011	\N	{"quiz_id": "QUZ0000003", "option_a": "color", "option_b": "font-color", "option_c": "text-color", "option_d": "fg", "question_id": "QST0000011", "question_text": "Which CSS property changes text color?", "correct_answer": "color"}	2026-11-25 08:20:19.625054+08
73	INSERT	questions	QST0000012	USR0000004	postgres	Created questions record QST0000012	\N	{"quiz_id": "QUZ0000003", "option_a": "<style>", "option_b": "<script>", "option_c": "<css>", "option_d": "<link>", "question_id": "QST0000012", "question_text": "Which HTML element links an external stylesheet?", "correct_answer": "<link>"}	2026-11-25 08:20:19.625217+08
74	INSERT	questions	QST0000013	USR0000004	postgres	Created questions record QST0000013	\N	{"quiz_id": "QUZ0000003", "option_a": "block", "option_b": "flex", "option_c": "grid-inline", "option_d": "inline", "question_id": "QST0000013", "question_text": "Which CSS display value creates a flex container?", "correct_answer": "flex"}	2026-11-25 08:20:19.625351+08
75	INSERT	questions	QST0000014	USR0000005	postgres	Created questions record QST0000014	\N	{"quiz_id": "QUZ0000004", "option_a": "O(n)", "option_b": "O(log n)", "option_c": "O(n log n)", "option_d": "O(1)", "question_id": "QST0000014", "question_text": "What is the time complexity of binary search?", "correct_answer": "O(log n)"}	2026-11-25 08:20:19.625495+08
76	INSERT	questions	QST0000015	USR0000005	postgres	Created questions record QST0000015	\N	{"quiz_id": "QUZ0000004", "option_a": "O(1)", "option_b": "O(n)", "option_c": "O(log n)", "option_d": "O(n^2)", "question_id": "QST0000015", "question_text": "Accessing an array element by index is:", "correct_answer": "O(1)"}	2026-11-25 08:20:19.625633+08
77	INSERT	questions	QST0000016	USR0000005	postgres	Created questions record QST0000016	\N	{"quiz_id": "QUZ0000004", "option_a": "O(n)", "option_b": "O(log n)", "option_c": "O(n^2)", "option_d": "O(1)", "question_id": "QST0000016", "question_text": "A nested loop over n items is usually:", "correct_answer": "O(n^2)"}	2026-11-25 08:20:19.625764+08
78	INSERT	questions	QST0000017	USR0000004	postgres	Created questions record QST0000017	\N	{"quiz_id": "QUZ0000005", "option_a": "let", "option_b": "var", "option_c": "def", "option_d": "dim", "question_id": "QST0000017", "question_text": "Which keyword declares a block-scoped variable?", "correct_answer": "let"}	2026-11-25 08:20:19.625892+08
79	INSERT	questions	QST0000018	USR0000004	postgres	Created questions record QST0000018	\N	{"quiz_id": "QUZ0000005", "option_a": "print()", "option_b": "echo()", "option_c": "write()", "option_d": "console.log()", "question_id": "QST0000018", "question_text": "Which method prints to the browser console?", "correct_answer": "console.log()"}	2026-11-25 08:20:19.626024+08
80	INSERT	questions	QST0000019	USR0000004	postgres	Created questions record QST0000019	\N	{"quiz_id": "QUZ0000005", "option_a": "Value only", "option_b": "Value and type", "option_c": "Reference only", "option_d": "Length", "question_id": "QST0000019", "question_text": "What does === compare?", "correct_answer": "Value and type"}	2026-11-25 08:20:19.626225+08
81	UPDATE	quizzes	QUZ0000004	USR0000005	postgres	Updated quizzes record QUZ0000004	{"title": "Big-O Notation", "quiz_id": "QUZ0000004", "created_at": "2026-11-25T08:20:19.006917+08:00", "subject_id": "SUB0000003", "instructor_id": "INS0000003"}	{"title": "Big-O Notation Quiz", "quiz_id": "QUZ0000004", "created_at": "2026-11-25T08:20:19.006917+08:00", "subject_id": "SUB0000003", "instructor_id": "INS0000003"}	2026-11-25 08:20:19.626763+08
82	INSERT	student_answers	ANS0000001	USR0000006	postgres	Created student_answers record ANS0000001	\N	{"answer_id": "ANS0000001", "is_correct": true, "student_id": "STU0000001", "question_id": "QST0000001", "student_answer": "GRANT"}	2026-11-25 08:20:19.629269+08
83	INSERT	student_answers	ANS0000002	USR0000006	postgres	Created student_answers record ANS0000002	\N	{"answer_id": "ANS0000002", "is_correct": true, "student_id": "STU0000001", "question_id": "QST0000002", "student_answer": "SQL injection"}	2026-11-25 08:20:19.62971+08
84	INSERT	student_answers	ANS0000003	USR0000006	postgres	Created student_answers record ANS0000003	\N	{"answer_id": "ANS0000003", "is_correct": true, "student_id": "STU0000001", "question_id": "QST0000003", "student_answer": "A salted hash"}	2026-11-25 08:20:19.630022+08
85	INSERT	student_answers	ANS0000004	USR0000006	postgres	Created student_answers record ANS0000004	\N	{"answer_id": "ANS0000004", "is_correct": true, "student_id": "STU0000001", "question_id": "QST0000004", "student_answer": "View"}	2026-11-25 08:20:19.630354+08
86	INSERT	student_answers	ANS0000005	USR0000006	postgres	Created student_answers record ANS0000005	\N	{"answer_id": "ANS0000005", "is_correct": true, "student_id": "STU0000001", "question_id": "QST0000005", "student_answer": "Least privilege"}	2026-11-25 08:20:19.630705+08
87	INSERT	quiz_results	RES0000001	USR0000006	postgres	Created quiz_results record RES0000001	\N	{"score": 100.00, "quiz_id": "QUZ0000001", "result_id": "RES0000001", "student_id": "STU0000001"}	2026-11-25 08:20:19.632573+08
88	INSERT	student_answers	ANS0000006	USR0000007	postgres	Created student_answers record ANS0000006	\N	{"answer_id": "ANS0000006", "is_correct": true, "student_id": "STU0000002", "question_id": "QST0000001", "student_answer": "GRANT"}	2026-11-25 08:20:19.632917+08
89	INSERT	student_answers	ANS0000007	USR0000007	postgres	Created student_answers record ANS0000007	\N	{"answer_id": "ANS0000007", "is_correct": true, "student_id": "STU0000002", "question_id": "QST0000002", "student_answer": "SQL injection"}	2026-11-25 08:20:19.633078+08
90	INSERT	student_answers	ANS0000008	USR0000007	postgres	Created student_answers record ANS0000008	\N	{"answer_id": "ANS0000008", "is_correct": true, "student_id": "STU0000002", "question_id": "QST0000003", "student_answer": "A salted hash"}	2026-11-25 08:20:19.633212+08
91	INSERT	student_answers	ANS0000009	USR0000007	postgres	Created student_answers record ANS0000009	\N	{"answer_id": "ANS0000009", "is_correct": true, "student_id": "STU0000002", "question_id": "QST0000004", "student_answer": "View"}	2026-11-25 08:20:19.633341+08
92	INSERT	student_answers	ANS0000010	USR0000007	postgres	Created student_answers record ANS0000010	\N	{"answer_id": "ANS0000010", "is_correct": false, "student_id": "STU0000002", "question_id": "QST0000005", "student_answer": "Defense in depth"}	2026-11-25 08:20:19.633465+08
93	INSERT	quiz_results	RES0000002	USR0000007	postgres	Created quiz_results record RES0000002	\N	{"score": 80.00, "quiz_id": "QUZ0000001", "result_id": "RES0000002", "student_id": "STU0000002"}	2026-11-25 08:20:19.634028+08
94	INSERT	student_answers	ANS0000011	USR0000008	postgres	Created student_answers record ANS0000011	\N	{"answer_id": "ANS0000011", "is_correct": true, "student_id": "STU0000003", "question_id": "QST0000001", "student_answer": "GRANT"}	2026-11-25 08:20:19.634265+08
95	INSERT	student_answers	ANS0000012	USR0000008	postgres	Created student_answers record ANS0000012	\N	{"answer_id": "ANS0000012", "is_correct": true, "student_id": "STU0000003", "question_id": "QST0000002", "student_answer": "SQL injection"}	2026-11-25 08:20:19.634445+08
96	INSERT	student_answers	ANS0000013	USR0000008	postgres	Created student_answers record ANS0000013	\N	{"answer_id": "ANS0000013", "is_correct": true, "student_id": "STU0000003", "question_id": "QST0000003", "student_answer": "A salted hash"}	2026-11-25 08:20:19.634603+08
97	INSERT	student_answers	ANS0000014	USR0000008	postgres	Created student_answers record ANS0000014	\N	{"answer_id": "ANS0000014", "is_correct": false, "student_id": "STU0000003", "question_id": "QST0000004", "student_answer": "Index"}	2026-11-25 08:20:19.634765+08
98	INSERT	student_answers	ANS0000015	USR0000008	postgres	Created student_answers record ANS0000015	\N	{"answer_id": "ANS0000015", "is_correct": false, "student_id": "STU0000003", "question_id": "QST0000005", "student_answer": "Separation of data"}	2026-11-25 08:20:19.634917+08
99	INSERT	quiz_results	RES0000003	USR0000008	postgres	Created quiz_results record RES0000003	\N	{"score": 60.00, "quiz_id": "QUZ0000001", "result_id": "RES0000003", "student_id": "STU0000003"}	2026-11-25 08:20:19.635438+08
100	INSERT	student_answers	ANS0000016	USR0000009	postgres	Created student_answers record ANS0000016	\N	{"answer_id": "ANS0000016", "is_correct": false, "student_id": "STU0000004", "question_id": "QST0000001", "student_answer": "REVOKE"}	2026-11-25 08:20:19.635621+08
101	INSERT	student_answers	ANS0000017	USR0000009	postgres	Created student_answers record ANS0000017	\N	{"answer_id": "ANS0000017", "is_correct": true, "student_id": "STU0000004", "question_id": "QST0000002", "student_answer": "SQL injection"}	2026-11-25 08:20:19.635788+08
102	INSERT	student_answers	ANS0000018	USR0000009	postgres	Created student_answers record ANS0000018	\N	{"answer_id": "ANS0000018", "is_correct": false, "student_id": "STU0000004", "question_id": "QST0000003", "student_answer": "Nothing"}	2026-11-25 08:20:19.636019+08
103	INSERT	student_answers	ANS0000019	USR0000009	postgres	Created student_answers record ANS0000019	\N	{"answer_id": "ANS0000019", "is_correct": true, "student_id": "STU0000004", "question_id": "QST0000004", "student_answer": "View"}	2026-11-25 08:20:19.636196+08
104	INSERT	quiz_results	RES0000004	USR0000009	postgres	Created quiz_results record RES0000004	\N	{"score": 40.00, "quiz_id": "QUZ0000001", "result_id": "RES0000004", "student_id": "STU0000004"}	2026-11-25 08:20:19.636803+08
105	INSERT	student_answers	ANS0000020	USR0000006	postgres	Created student_answers record ANS0000020	\N	{"answer_id": "ANS0000020", "is_correct": true, "student_id": "STU0000001", "question_id": "QST0000006", "student_answer": "REVOKE"}	2026-11-25 08:20:19.636997+08
106	INSERT	student_answers	ANS0000021	USR0000006	postgres	Created student_answers record ANS0000021	\N	{"answer_id": "ANS0000021", "is_correct": true, "student_id": "STU0000001", "question_id": "QST0000007", "student_answer": "Role"}	2026-11-25 08:20:19.637163+08
107	INSERT	student_answers	ANS0000022	USR0000006	postgres	Created student_answers record ANS0000022	\N	{"answer_id": "ANS0000022", "is_correct": true, "student_id": "STU0000001", "question_id": "QST0000008", "student_answer": "EXECUTE"}	2026-11-25 08:20:19.637359+08
108	INSERT	student_answers	ANS0000023	USR0000006	postgres	Created student_answers record ANS0000023	\N	{"answer_id": "ANS0000023", "is_correct": false, "student_id": "STU0000001", "question_id": "QST0000009", "student_answer": "Temp table"}	2026-11-25 08:20:19.637583+08
109	INSERT	quiz_results	RES0000005	USR0000006	postgres	Created quiz_results record RES0000005	\N	{"score": 75.00, "quiz_id": "QUZ0000002", "result_id": "RES0000005", "student_id": "STU0000001"}	2026-11-25 08:20:19.638139+08
110	INSERT	student_answers	ANS0000024	USR0000007	postgres	Created student_answers record ANS0000024	\N	{"answer_id": "ANS0000024", "is_correct": true, "student_id": "STU0000002", "question_id": "QST0000006", "student_answer": "REVOKE"}	2026-11-25 08:20:19.63836+08
111	INSERT	student_answers	ANS0000025	USR0000007	postgres	Created student_answers record ANS0000025	\N	{"answer_id": "ANS0000025", "is_correct": true, "student_id": "STU0000002", "question_id": "QST0000007", "student_answer": "Role"}	2026-11-25 08:20:19.638594+08
112	INSERT	student_answers	ANS0000026	USR0000007	postgres	Created student_answers record ANS0000026	\N	{"answer_id": "ANS0000026", "is_correct": true, "student_id": "STU0000002", "question_id": "QST0000008", "student_answer": "EXECUTE"}	2026-11-25 08:20:19.638768+08
113	INSERT	student_answers	ANS0000027	USR0000007	postgres	Created student_answers record ANS0000027	\N	{"answer_id": "ANS0000027", "is_correct": true, "student_id": "STU0000002", "question_id": "QST0000009", "student_answer": "Audit log"}	2026-11-25 08:20:19.63892+08
114	INSERT	quiz_results	RES0000006	USR0000007	postgres	Created quiz_results record RES0000006	\N	{"score": 100.00, "quiz_id": "QUZ0000002", "result_id": "RES0000006", "student_id": "STU0000002"}	2026-11-25 08:20:19.639463+08
115	INSERT	student_answers	ANS0000028	USR0000010	postgres	Created student_answers record ANS0000028	\N	{"answer_id": "ANS0000028", "is_correct": true, "student_id": "STU0000005", "question_id": "QST0000006", "student_answer": "REVOKE"}	2026-11-25 08:20:19.639655+08
116	INSERT	student_answers	ANS0000029	USR0000010	postgres	Created student_answers record ANS0000029	\N	{"answer_id": "ANS0000029", "is_correct": false, "student_id": "STU0000005", "question_id": "QST0000007", "student_answer": "Schema"}	2026-11-25 08:20:19.639813+08
117	INSERT	student_answers	ANS0000030	USR0000010	postgres	Created student_answers record ANS0000030	\N	{"answer_id": "ANS0000030", "is_correct": true, "student_id": "STU0000005", "question_id": "QST0000008", "student_answer": "EXECUTE"}	2026-11-25 08:20:19.639962+08
118	INSERT	student_answers	ANS0000031	USR0000010	postgres	Created student_answers record ANS0000031	\N	{"answer_id": "ANS0000031", "is_correct": false, "student_id": "STU0000005", "question_id": "QST0000009", "student_answer": "Temp table"}	2026-11-25 08:20:19.640108+08
119	INSERT	quiz_results	RES0000007	USR0000010	postgres	Created quiz_results record RES0000007	\N	{"score": 50.00, "quiz_id": "QUZ0000002", "result_id": "RES0000007", "student_id": "STU0000005"}	2026-11-25 08:20:19.640279+08
120	INSERT	student_answers	ANS0000032	USR0000008	postgres	Created student_answers record ANS0000032	\N	{"answer_id": "ANS0000032", "is_correct": true, "student_id": "STU0000003", "question_id": "QST0000010", "student_answer": "<h1>"}	2026-11-25 08:20:19.640406+08
121	INSERT	student_answers	ANS0000033	USR0000008	postgres	Created student_answers record ANS0000033	\N	{"answer_id": "ANS0000033", "is_correct": true, "student_id": "STU0000003", "question_id": "QST0000011", "student_answer": "color"}	2026-11-25 08:20:19.64054+08
122	INSERT	student_answers	ANS0000034	USR0000008	postgres	Created student_answers record ANS0000034	\N	{"answer_id": "ANS0000034", "is_correct": true, "student_id": "STU0000003", "question_id": "QST0000012", "student_answer": "<link>"}	2026-11-25 08:20:19.640664+08
123	INSERT	student_answers	ANS0000035	USR0000008	postgres	Created student_answers record ANS0000035	\N	{"answer_id": "ANS0000035", "is_correct": true, "student_id": "STU0000003", "question_id": "QST0000013", "student_answer": "flex"}	2026-11-25 08:20:19.640783+08
124	INSERT	quiz_results	RES0000008	USR0000008	postgres	Created quiz_results record RES0000008	\N	{"score": 100.00, "quiz_id": "QUZ0000003", "result_id": "RES0000008", "student_id": "STU0000003"}	2026-11-25 08:20:19.64094+08
125	INSERT	student_answers	ANS0000036	USR0000011	postgres	Created student_answers record ANS0000036	\N	{"answer_id": "ANS0000036", "is_correct": false, "student_id": "STU0000006", "question_id": "QST0000010", "student_answer": "<head>"}	2026-11-25 08:20:19.641068+08
126	INSERT	student_answers	ANS0000037	USR0000011	postgres	Created student_answers record ANS0000037	\N	{"answer_id": "ANS0000037", "is_correct": true, "student_id": "STU0000006", "question_id": "QST0000011", "student_answer": "color"}	2026-11-25 08:20:19.641193+08
127	INSERT	student_answers	ANS0000038	USR0000011	postgres	Created student_answers record ANS0000038	\N	{"answer_id": "ANS0000038", "is_correct": false, "student_id": "STU0000006", "question_id": "QST0000012", "student_answer": "<style>"}	2026-11-25 08:20:19.641313+08
128	INSERT	student_answers	ANS0000039	USR0000011	postgres	Created student_answers record ANS0000039	\N	{"answer_id": "ANS0000039", "is_correct": false, "student_id": "STU0000006", "question_id": "QST0000013", "student_answer": "block"}	2026-11-25 08:20:19.641434+08
129	INSERT	quiz_results	RES0000009	USR0000011	postgres	Created quiz_results record RES0000009	\N	{"score": 25.00, "quiz_id": "QUZ0000003", "result_id": "RES0000009", "student_id": "STU0000006"}	2026-11-25 08:20:19.641595+08
130	INSERT	student_answers	ANS0000040	USR0000006	postgres	Created student_answers record ANS0000040	\N	{"answer_id": "ANS0000040", "is_correct": true, "student_id": "STU0000001", "question_id": "QST0000010", "student_answer": "<h1>"}	2026-11-25 08:20:19.641721+08
131	INSERT	student_answers	ANS0000041	USR0000006	postgres	Created student_answers record ANS0000041	\N	{"answer_id": "ANS0000041", "is_correct": true, "student_id": "STU0000001", "question_id": "QST0000011", "student_answer": "color"}	2026-11-25 08:20:19.641841+08
132	INSERT	student_answers	ANS0000042	USR0000006	postgres	Created student_answers record ANS0000042	\N	{"answer_id": "ANS0000042", "is_correct": true, "student_id": "STU0000001", "question_id": "QST0000012", "student_answer": "<link>"}	2026-11-25 08:20:19.64196+08
133	INSERT	student_answers	ANS0000043	USR0000006	postgres	Created student_answers record ANS0000043	\N	{"answer_id": "ANS0000043", "is_correct": false, "student_id": "STU0000001", "question_id": "QST0000013", "student_answer": "grid-inline"}	2026-11-25 08:20:19.642082+08
134	INSERT	quiz_results	RES0000010	USR0000006	postgres	Created quiz_results record RES0000010	\N	{"score": 75.00, "quiz_id": "QUZ0000003", "result_id": "RES0000010", "student_id": "STU0000001"}	2026-11-25 08:20:19.642243+08
135	INSERT	student_answers	ANS0000044	USR0000009	postgres	Created student_answers record ANS0000044	\N	{"answer_id": "ANS0000044", "is_correct": true, "student_id": "STU0000004", "question_id": "QST0000014", "student_answer": "O(log n)"}	2026-11-25 08:20:19.642365+08
136	INSERT	student_answers	ANS0000045	USR0000009	postgres	Created student_answers record ANS0000045	\N	{"answer_id": "ANS0000045", "is_correct": true, "student_id": "STU0000004", "question_id": "QST0000015", "student_answer": "O(1)"}	2026-11-25 08:20:19.642534+08
137	INSERT	student_answers	ANS0000046	USR0000009	postgres	Created student_answers record ANS0000046	\N	{"answer_id": "ANS0000046", "is_correct": true, "student_id": "STU0000004", "question_id": "QST0000016", "student_answer": "O(n^2)"}	2026-11-25 08:20:19.642909+08
138	INSERT	quiz_results	RES0000011	USR0000009	postgres	Created quiz_results record RES0000011	\N	{"score": 100.00, "quiz_id": "QUZ0000004", "result_id": "RES0000011", "student_id": "STU0000004"}	2026-11-25 08:20:19.643089+08
139	INSERT	student_answers	ANS0000047	USR0000010	postgres	Created student_answers record ANS0000047	\N	{"answer_id": "ANS0000047", "is_correct": true, "student_id": "STU0000005", "question_id": "QST0000014", "student_answer": "O(log n)"}	2026-11-25 08:20:19.643215+08
140	INSERT	student_answers	ANS0000048	USR0000010	postgres	Created student_answers record ANS0000048	\N	{"answer_id": "ANS0000048", "is_correct": true, "student_id": "STU0000005", "question_id": "QST0000015", "student_answer": "O(1)"}	2026-11-25 08:20:19.643382+08
141	INSERT	student_answers	ANS0000049	USR0000010	postgres	Created student_answers record ANS0000049	\N	{"answer_id": "ANS0000049", "is_correct": false, "student_id": "STU0000005", "question_id": "QST0000016", "student_answer": "O(1)"}	2026-11-25 08:20:19.643516+08
142	INSERT	quiz_results	RES0000012	USR0000010	postgres	Created quiz_results record RES0000012	\N	{"score": 66.67, "quiz_id": "QUZ0000004", "result_id": "RES0000012", "student_id": "STU0000005"}	2026-11-25 08:20:19.643668+08
143	LOGIN_SUCCESS	users	USR0000006	USR0000006	postgres	User ana.santos logged in	\N	\N	2026-11-25 08:20:19.695296+08
144	LOGIN_FAILED	users	USR0000007	\N	postgres	Failed login for username "ben.torres"	\N	\N	2026-11-25 08:20:19.742633+08
145	LOGIN_FAILED	users	USR0000012	\N	postgres	Failed login for username "gina.lopez" (inactive account)	\N	\N	2026-11-25 08:20:19.742822+08
146	INSERT	student_answers	ANS0000051	\N	postgres	Created student_answers record ANS0000051	\N	{"answer_id": "ANS0000051", "is_correct": false, "student_id": "STU0000002", "question_id": "QST0000017", "student_answer": "var"}	2026-11-25 08:20:30.473632+08
147	INSERT	quiz_results	RES0000014	\N	postgres	Created quiz_results record RES0000014	\N	{"score": 0.00, "quiz_id": "QUZ0000005", "result_id": "RES0000014", "student_id": "STU0000002"}	2026-11-25 08:20:30.47966+08
148	DELETE	quiz_results	RES0000014	\N	postgres	Deleted quiz_results record RES0000014	{"score": 0.00, "quiz_id": "QUZ0000005", "result_id": "RES0000014", "student_id": "STU0000002"}	\N	2026-11-25 08:20:30.48026+08
149	DELETE	student_answers	ANS0000051	\N	postgres	Deleted student_answers record ANS0000051	{"answer_id": "ANS0000051", "is_correct": false, "student_id": "STU0000002", "question_id": "QST0000017", "student_answer": "var"}	\N	2026-11-25 08:20:30.480621+08
150	INSERT	users	USR0000013	USR0000001	postgres	Created users record USR0000013	\N	{"email": "hana.cruz@studync.edu", "status": "Active", "user_id": "USR0000013", "username": "hana.cruz", "created_at": "2026-11-25T08:20:30.387563+08:00"}	2026-11-25 08:20:30.532049+08
151	INSERT	user_roles	USR0000013:ROL0000003	USR0000001	postgres	Created user_roles record USR0000013:ROL0000003	\N	{"role_id": "ROL0000003", "user_id": "USR0000013"}	2026-11-25 08:20:30.532506+08
152	INSERT	students	STU0000008	USR0000001	postgres	Created students record STU0000008	\N	{"user_id": "USR0000013", "last_name": "Cruz", "first_name": "Hana", "student_id": "STU0000008"}	2026-11-25 08:20:30.533967+08
153	INSERT	users	USR0000014	USR0000001	postgres	Created users record USR0000014	\N	{"email": "paolo.lim@studync.edu", "status": "Active", "user_id": "USR0000014", "username": "paolo.lim", "created_at": "2026-11-25T08:20:30.387563+08:00"}	2026-11-25 08:20:30.660942+08
154	INSERT	user_roles	USR0000014:ROL0000002	USR0000001	postgres	Created user_roles record USR0000014:ROL0000002	\N	{"role_id": "ROL0000002", "user_id": "USR0000014"}	2026-11-25 08:20:30.661161+08
155	INSERT	instructors	INS0000005	USR0000001	postgres	Created instructors record INS0000005	\N	{"user_id": "USR0000014", "last_name": "Lim", "first_name": "Paolo", "instructor_id": "INS0000005"}	2026-11-25 08:20:30.662491+08
156	LOGIN_SUCCESS	users	USR0000013	USR0000013	postgres	User hana.cruz logged in	\N	\N	2026-11-25 08:20:30.709592+08
157	LOGIN_FAILED	users	USR0000013	\N	postgres	Failed login for username "hana.cruz"	\N	\N	2026-11-25 08:20:30.750568+08
158	LOGIN_FAILED	users	USR0000012	\N	postgres	Failed login for username "gina.lopez" (inactive account)	\N	\N	2026-11-25 08:20:30.750874+08
159	UPDATE	users	USR0000013	USR0000001	postgres	Updated users record USR0000013	{"email": "hana.cruz@studync.edu", "status": "Active", "user_id": "USR0000013", "username": "hana.cruz", "created_at": "2026-11-25T08:20:30.387563+08:00"}	{"email": "hana.cruz2@studync.edu", "status": "Active", "user_id": "USR0000013", "username": "hana.cruz", "created_at": "2026-11-25T08:20:30.387563+08:00", "password_changed": false}	2026-11-25 08:20:30.753931+08
160	UPDATE	students	STU0000008	USR0000001	postgres	Updated students record STU0000008	{"user_id": "USR0000013", "last_name": "Cruz", "first_name": "Hana", "student_id": "STU0000008"}	{"user_id": "USR0000013", "last_name": "Cruz", "first_name": "Hannah", "student_id": "STU0000008"}	2026-11-25 08:20:30.756816+08
161	INSERT	user_roles	USR0000013:ROL0000002	USR0000001	postgres	Created user_roles record USR0000013:ROL0000002	\N	{"role_id": "ROL0000002", "user_id": "USR0000013"}	2026-11-25 08:20:30.757905+08
162	INSERT	instructors	INS0000006	USR0000001	postgres	Created instructors record INS0000006	\N	{"user_id": "USR0000013", "last_name": "Cruz", "first_name": "Hannah", "instructor_id": "INS0000006"}	2026-11-25 08:20:30.758407+08
163	DELETE	user_roles	USR0000013:ROL0000002	USR0000001	postgres	Deleted user_roles record USR0000013:ROL0000002	{"role_id": "ROL0000002", "user_id": "USR0000013"}	\N	2026-11-25 08:20:30.759447+08
164	UPDATE	users	USR0000013	USR0000013	postgres	Updated users record USR0000013	{"email": "hana.cruz2@studync.edu", "status": "Active", "user_id": "USR0000013", "username": "hana.cruz", "created_at": "2026-11-25T08:20:30.387563+08:00"}	{"email": "hana.cruz2@studync.edu", "status": "Active", "user_id": "USR0000013", "username": "hana.cruz", "created_at": "2026-11-25T08:20:30.387563+08:00", "password_changed": true}	2026-11-25 08:20:30.850319+08
165	LOGIN_SUCCESS	users	USR0000013	USR0000013	postgres	User hana.cruz logged in	\N	\N	2026-11-25 08:20:30.892907+08
166	INSERT	subjects	SUB0000006	USR0000001	postgres	Created subjects record SUB0000006	\N	{"subject_id": "SUB0000006", "description": "Security policies and risk management.", "subject_name": "Information Assurance"}	2026-11-25 08:20:30.939118+08
190	INSERT	student_answers	ANS0000057	USR0000006	ana.santos	Created student_answers record ANS0000057	\N	{"answer_id": "ANS0000057", "is_correct": false, "student_id": "STU0000001", "question_id": "QST0000016", "student_answer": "O(n)"}	2026-11-25 08:20:30.985618+08
167	UPDATE	subjects	SUB0000006	USR0000001	postgres	Updated subjects record SUB0000006	{"subject_id": "SUB0000006", "description": "Security policies and risk management.", "subject_name": "Information Assurance"}	{"subject_id": "SUB0000006", "description": "Security policies, risk management and compliance.", "subject_name": "Information Assurance"}	2026-11-25 08:20:30.940321+08
168	DELETE	subjects	SUB0000005	USR0000001	postgres	Deleted subjects record SUB0000005	{"subject_id": "SUB0000005", "description": "Writing clear technical documentation and reports.", "subject_name": "Technical Writing"}	\N	2026-11-25 08:20:30.941331+08
169	INSERT	materials	MAT0000012	USR0000003	postgres	Created materials record MAT0000012	\N	{"title": "Risk Assessment Primer", "file_path": "materials/sub6/risk-primer.pdf", "subject_id": "SUB0000006", "material_id": "MAT0000012", "uploaded_at": "2026-11-25T08:20:30.387563+08:00", "instructor_id": "INS0000001"}	2026-11-25 08:20:30.942953+08
170	UPDATE	materials	MAT0000012	USR0000003	postgres	Updated materials record MAT0000012	{"title": "Risk Assessment Primer", "file_path": "materials/sub6/risk-primer.pdf", "subject_id": "SUB0000006", "material_id": "MAT0000012", "uploaded_at": "2026-11-25T08:20:30.387563+08:00", "instructor_id": "INS0000001"}	{"title": "Risk Assessment Primer (v2)", "file_path": "materials/sub6/risk-primer.pdf", "subject_id": "SUB0000006", "material_id": "MAT0000012", "uploaded_at": "2026-11-25T08:20:30.387563+08:00", "instructor_id": "INS0000001"}	2026-11-25 08:20:30.943935+08
171	DELETE	materials	MAT0000012	USR0000003	postgres	Deleted materials record MAT0000012	{"title": "Risk Assessment Primer (v2)", "file_path": "materials/sub6/risk-primer.pdf", "subject_id": "SUB0000006", "material_id": "MAT0000012", "uploaded_at": "2026-11-25T08:20:30.387563+08:00", "instructor_id": "INS0000001"}	\N	2026-11-25 08:20:30.946501+08
172	INSERT	quizzes	QUZ0000006	USR0000003	postgres	Created quizzes record QUZ0000006	\N	{"title": "Risk Management Quiz", "quiz_id": "QUZ0000006", "created_at": "2026-11-25T08:20:30.387563+08:00", "subject_id": "SUB0000006", "instructor_id": "INS0000001"}	2026-11-25 08:20:30.947281+08
173	INSERT	questions	QST0000021	USR0000003	postgres	Created questions record QST0000021	\N	{"quiz_id": "QUZ0000006", "option_a": "Vulnerability", "option_b": "Firewall", "option_c": "Password", "option_d": "Backup", "question_id": "QST0000021", "question_text": "Risk = Threat x ?", "correct_answer": "Vulnerability"}	2026-11-25 08:20:30.948396+08
174	INSERT	questions	QST0000022	USR0000003	postgres	Created questions record QST0000022	\N	{"quiz_id": "QUZ0000006", "option_a": "Audit log", "option_b": "Firewall", "option_c": "CCTV review", "option_d": "Incident report", "question_id": "QST0000022", "question_text": "Which control is preventive?", "correct_answer": "Firewall"}	2026-11-25 08:20:30.948783+08
175	UPDATE	questions	QST0000022	USR0000003	postgres	Updated questions record QST0000022	{"quiz_id": "QUZ0000006", "option_a": "Audit log", "option_b": "Firewall", "option_c": "CCTV review", "option_d": "Incident report", "question_id": "QST0000022", "question_text": "Which control is preventive?", "correct_answer": "Firewall"}	{"quiz_id": "QUZ0000006", "option_a": "Audit log", "option_b": "Firewall", "option_c": "CCTV review", "option_d": "Incident report", "question_id": "QST0000022", "question_text": "Which control is PREVENTIVE?", "correct_answer": "Firewall"}	2026-11-25 08:20:30.950351+08
176	INSERT	questions	QST0000024	USR0000003	postgres	Created questions record QST0000024	\N	{"quiz_id": "QUZ0000006", "option_a": "w", "option_b": "x", "option_c": "y", "option_d": "z", "question_id": "QST0000024", "question_text": "Temp?", "correct_answer": "z"}	2026-11-25 08:20:30.95076+08
177	DELETE	questions	QST0000024	USR0000003	postgres	Deleted questions record QST0000024	{"quiz_id": "QUZ0000006", "option_a": "w", "option_b": "x", "option_c": "y", "option_d": "z", "question_id": "QST0000024", "question_text": "Temp?", "correct_answer": "z"}	\N	2026-11-25 08:20:30.951593+08
178	UPDATE	quizzes	QUZ0000006	USR0000003	postgres	Updated quizzes record QUZ0000006	{"title": "Risk Management Quiz", "quiz_id": "QUZ0000006", "created_at": "2026-11-25T08:20:30.387563+08:00", "subject_id": "SUB0000006", "instructor_id": "INS0000001"}	{"title": "Risk Management Quiz 1", "quiz_id": "QUZ0000006", "created_at": "2026-11-25T08:20:30.387563+08:00", "subject_id": "SUB0000006", "instructor_id": "INS0000001"}	2026-11-25 08:20:30.952153+08
179	INSERT	quizzes	QUZ0000007	USR0000003	postgres	Created quizzes record QUZ0000007	\N	{"title": "Throwaway Quiz", "quiz_id": "QUZ0000007", "created_at": "2026-11-25T08:20:30.387563+08:00", "subject_id": "SUB0000006", "instructor_id": "INS0000001"}	2026-11-25 08:20:30.9534+08
180	INSERT	questions	QST0000025	USR0000003	postgres	Created questions record QST0000025	\N	{"quiz_id": "QUZ0000007", "option_a": "a1", "option_b": "b1", "option_c": "c1", "option_d": "d1", "question_id": "QST0000025", "question_text": "Throwaway?", "correct_answer": "a1"}	2026-11-25 08:20:30.953765+08
181	DELETE	questions	QST0000025	USR0000003	postgres	Deleted questions record QST0000025	{"quiz_id": "QUZ0000007", "option_a": "a1", "option_b": "b1", "option_c": "c1", "option_d": "d1", "question_id": "QST0000025", "question_text": "Throwaway?", "correct_answer": "a1"}	\N	2026-11-25 08:20:30.954098+08
182	DELETE	quizzes	QUZ0000007	USR0000003	postgres	Deleted quizzes record QUZ0000007	{"title": "Throwaway Quiz", "quiz_id": "QUZ0000007", "created_at": "2026-11-25T08:20:30.387563+08:00", "subject_id": "SUB0000006", "instructor_id": "INS0000001"}	\N	2026-11-25 08:20:30.954506+08
183	INSERT	student_answers	ANS0000052	USR0000007	postgres	Created student_answers record ANS0000052	\N	{"answer_id": "ANS0000052", "is_correct": true, "student_id": "STU0000002", "question_id": "QST0000017", "student_answer": "let"}	2026-11-25 08:20:30.968159+08
184	INSERT	student_answers	ANS0000053	USR0000007	postgres	Created student_answers record ANS0000053	\N	{"answer_id": "ANS0000053", "is_correct": true, "student_id": "STU0000002", "question_id": "QST0000018", "student_answer": "console.log()"}	2026-11-25 08:20:30.968792+08
185	INSERT	student_answers	ANS0000054	USR0000007	postgres	Created student_answers record ANS0000054	\N	{"answer_id": "ANS0000054", "is_correct": false, "student_id": "STU0000002", "question_id": "QST0000019", "student_answer": "Value only"}	2026-11-25 08:20:30.969837+08
186	INSERT	quiz_results	RES0000015	USR0000007	postgres	Created quiz_results record RES0000015	\N	{"score": 66.67, "quiz_id": "QUZ0000005", "result_id": "RES0000015", "student_id": "STU0000002"}	2026-11-25 08:20:30.971318+08
187	INSERT	subjects	SUB0000007	USR0000001	postgres	Created subjects record SUB0000007	\N	{"subject_id": "SUB0000007", "description": null, "subject_name": "Audit Count Subject"}	2026-11-25 08:20:30.982097+08
188	INSERT	student_answers	ANS0000055	USR0000006	ana.santos	Created student_answers record ANS0000055	\N	{"answer_id": "ANS0000055", "is_correct": true, "student_id": "STU0000001", "question_id": "QST0000014", "student_answer": "O(log n)"}	2026-11-25 08:20:30.985066+08
189	INSERT	student_answers	ANS0000056	USR0000006	ana.santos	Created student_answers record ANS0000056	\N	{"answer_id": "ANS0000056", "is_correct": true, "student_id": "STU0000001", "question_id": "QST0000015", "student_answer": "O(1)"}	2026-11-25 08:20:30.985374+08
192	INSERT	materials	MAT0000013	USR0000003	jose.cruz	Created materials record MAT0000013	\N	{"title": "Backup Strategies", "file_path": "materials/sub1/backup.pdf", "subject_id": "SUB0000001", "material_id": "MAT0000013", "uploaded_at": "2026-11-25T08:20:30.387563+08:00", "instructor_id": "INS0000001"}	2026-11-25 08:20:30.988555+08
193	INSERT	subjects	SUB0000008	USR0000001	maria.reyes	Created subjects record SUB0000008	\N	{"subject_id": "SUB0000008", "description": null, "subject_name": "Cloud Computing"}	2026-11-25 08:20:30.990897+08
194	LOGIN_SUCCESS	users	USR0000001	USR0000001	studync_app_admin	User maria.reyes logged in	\N	\N	2026-11-25 09:13:40.051017+08
195	UPDATE	users	USR0000006	USR0000001	studync_app_admin	Updated users record USR0000006	{"email": "ana.santos@studync.edu", "status": "Active", "user_id": "USR0000006", "username": "ana.santos", "created_at": "2026-11-25T08:20:19.006917+08:00"}	{"email": "ana.updated@studync.edu", "status": "Active", "user_id": "USR0000006", "username": "ana.santos", "created_at": "2026-11-25T08:20:19.006917+08:00", "password_changed": false}	2026-11-25 09:13:52.908673+08
196	INSERT	user_roles	USR0000014:ROL0000001	USR0000001	studync_app_admin	Created user_roles record USR0000014:ROL0000001	\N	{"role_id": "ROL0000001", "user_id": "USR0000014"}	2026-11-25 09:14:00.406441+08
197	INSERT	admins	ADM0000003	USR0000001	studync_app_admin	Created admins record ADM0000003	\N	{"user_id": "USR0000014", "admin_id": "ADM0000003", "last_name": "Lim", "first_name": "Paolo"}	2026-11-25 09:14:00.40742+08
198	DELETE	user_roles	USR0000014:ROL0000001	USR0000001	studync_app_admin	Deleted user_roles record USR0000014:ROL0000001	{"role_id": "ROL0000001", "user_id": "USR0000014"}	\N	2026-11-25 09:14:03.532701+08
199	UPDATE	users	USR0000012	USR0000001	studync_app_admin	Updated users record USR0000012	{"email": "gina.lopez@studync.edu", "status": "Inactive", "user_id": "USR0000012", "username": "gina.lopez", "created_at": "2026-11-25T08:20:19.006917+08:00"}	{"email": "gina.lopez@studync.edu", "status": "Active", "user_id": "USR0000012", "username": "gina.lopez", "created_at": "2026-11-25T08:20:19.006917+08:00", "password_changed": false}	2026-11-25 09:14:07.204178+08
200	INSERT	subjects	SUB0000009	USR0000001	studync_app_admin	Created subjects record SUB0000009	\N	{"subject_id": "SUB0000009", "description": "Subject created to test StudyNC database functions.", "subject_name": "Database Testing Practice"}	2026-11-25 09:14:11.157382+08
204	LOGIN_SUCCESS	users	USR0000003	USR0000003	studync_app_instructor	User jose.cruz logged in	\N	\N	2026-11-25 09:15:11.849348+08
205	INSERT	materials	MAT0000015	USR0000003	studync_app_instructor	Created materials record MAT0000015	\N	{"title": "Database Testing Guide", "file_path": "materials/sub1/database-testing-guide.pdf", "subject_id": "SUB0000001", "material_id": "MAT0000015", "uploaded_at": "2026-11-25T09:15:14.82311+08:00", "instructor_id": "INS0000001"}	2026-11-25 09:15:14.824292+08
206	INSERT	quizzes	QUZ0000009	USR0000003	studync_app_instructor	Created quizzes record QUZ0000009	\N	{"title": "Database Testing Test Quiz", "quiz_id": "QUZ0000009", "created_at": "2026-11-25T09:15:21.43504+08:00", "subject_id": "SUB0000001", "instructor_id": "INS0000001"}	2026-11-25 09:15:21.435627+08
207	INSERT	quizzes	QUZ0000010	USR0000003	studync_app_instructor	Created quizzes record QUZ0000010	\N	{"title": "Database Testing Test Quiz", "quiz_id": "QUZ0000010", "created_at": "2026-11-25T09:15:30.836448+08:00", "subject_id": "SUB0000001", "instructor_id": "INS0000001"}	2026-11-25 09:15:30.837096+08
208	INSERT	questions	QST0000026	USR0000003	studync_app_instructor	Created questions record QST0000026	\N	{"quiz_id": "QUZ0000010", "option_a": "INSERT", "option_b": "SELECT", "option_c": "UPDATE", "option_d": "DELETE", "question_id": "QST0000026", "question_text": "Which SQL command retrieves records?", "correct_answer": "SELECT"}	2026-11-25 09:16:00.638705+08
209	UPDATE	questions	QST0000026	USR0000003	studync_app_instructor	Updated questions record QST0000026	{"quiz_id": "QUZ0000010", "option_a": "INSERT", "option_b": "SELECT", "option_c": "UPDATE", "option_d": "DELETE", "question_id": "QST0000026", "question_text": "Which SQL command retrieves records?", "correct_answer": "SELECT"}	{"quiz_id": "QUZ0000010", "option_a": "INSERT", "option_b": "SELECT", "option_c": "UPDATE", "option_d": "DELETE", "question_id": "QST0000026", "question_text": "Which SQL command retrieves data from a table?", "correct_answer": "SELECT"}	2026-11-25 09:16:18.556703+08
211	LOGIN_SUCCESS	users	USR0000006	USR0000006	studync_app_student	User ana.santos logged in	\N	\N	2026-11-25 09:17:13.893752+08
\.


--
-- Data for Name: instructors; Type: TABLE DATA; Schema: studync; Owner: studync_owner
--

COPY studync.instructors (instructor_id, user_id, first_name, last_name) FROM stdin;
INS0000001	USR0000003	Jose	Cruz
INS0000002	USR0000004	Liza	Garcia
INS0000003	USR0000005	Ramon	Villanueva
INS0000004	USR0000002	Carlo	Mendoza
INS0000005	USR0000014	Paolo	Lim
INS0000006	USR0000013	Hannah	Cruz
\.


--
-- Data for Name: materials; Type: TABLE DATA; Schema: studync; Owner: studync_owner
--

COPY studync.materials (material_id, subject_id, instructor_id, title, file_path, uploaded_at) FROM stdin;
MAT0000001	SUB0000001	INS0000001	Introduction to Database Security	materials/sub1/intro-db-security.pdf	2026-11-25 08:20:19.006917+08
MAT0000002	SUB0000001	INS0000001	Managing Roles and Privileges	materials/sub1/roles-and-privileges.pdf	2026-11-25 08:20:19.006917+08
MAT0000003	SUB0000001	INS0000001	Audit Trails with Triggers	materials/sub1/audit-trails.pptx	2026-11-25 08:20:19.006917+08
MAT0000004	SUB0000002	INS0000002	HTML5 Document Structure	materials/sub2/html5-structure.pdf	2026-11-25 08:20:19.006917+08
MAT0000006	SUB0000002	INS0000002	JavaScript Basics Video	https://videos.studync.edu/js-basics	2026-11-25 08:20:19.006917+08
MAT0000007	SUB0000003	INS0000003	Big-O Notation Lecture	materials/sub3/big-o.pdf	2026-11-25 08:20:19.006917+08
MAT0000008	SUB0000003	INS0000003	Linked Lists Worksheet	materials/sub3/linked-lists.docx	2026-11-25 08:20:19.006917+08
MAT0000005	SUB0000002	INS0000002	CSS Flexbox and Grid Guide	materials/sub2/css-flexbox-grid.pdf	2026-11-25 08:20:19.006917+08
MAT0000013	SUB0000001	INS0000001	Backup Strategies	materials/sub1/backup.pdf	2026-11-25 08:20:30.387563+08
MAT0000015	SUB0000001	INS0000001	Database Testing Guide	materials/sub1/database-testing-guide.pdf	2026-11-25 09:15:14.82311+08
\.


--
-- Data for Name: questions; Type: TABLE DATA; Schema: studync; Owner: studync_owner
--

COPY studync.questions (question_id, quiz_id, question_text, correct_answer, option_a, option_b, option_c, option_d) FROM stdin;
QST0000001	QUZ0000001	Which SQL statement gives a privilege to a user or role?	GRANT	REVOKE	GRANT	DENY	ALLOW
QST0000002	QUZ0000001	Which attack inserts malicious SQL through user input?	SQL injection	Phishing	Brute force	SQL injection	Spoofing
QST0000003	QUZ0000001	What should be stored instead of a plain-text password?	A salted hash	A salted hash	The password in upper case	An encrypted email	Nothing
QST0000004	QUZ0000001	Which object can hide sensitive columns from users?	View	Index	Trigger	Sequence	View
QST0000005	QUZ0000001	The principle of giving users only the access they need is called:	Least privilege	Defense in depth	Least privilege	Separation of data	Normalization
QST0000006	QUZ0000002	Which statement removes a previously granted privilege?	REVOKE	REVOKE	DROP	DELETE	REMOVE
QST0000007	QUZ0000002	A named group of privileges is called a:	Role	Schema	Synonym	Role	Cursor
QST0000008	QUZ0000002	Which privilege allows calling a stored procedure?	EXECUTE	SELECT	EXECUTE	USAGE	CALL
QST0000009	QUZ0000002	Which table records who changed data and when?	Audit log	Temp table	Lookup table	Junction table	Audit log
QST0000010	QUZ0000003	Which tag creates the largest heading?	<h1>	<head>	<h6>	<h1>	<header>
QST0000011	QUZ0000003	Which CSS property changes text color?	color	color	font-color	text-color	fg
QST0000012	QUZ0000003	Which HTML element links an external stylesheet?	<link>	<style>	<script>	<css>	<link>
QST0000013	QUZ0000003	Which CSS display value creates a flex container?	flex	block	flex	grid-inline	inline
QST0000014	QUZ0000004	What is the time complexity of binary search?	O(log n)	O(n)	O(log n)	O(n log n)	O(1)
QST0000015	QUZ0000004	Accessing an array element by index is:	O(1)	O(1)	O(n)	O(log n)	O(n^2)
QST0000016	QUZ0000004	A nested loop over n items is usually:	O(n^2)	O(n)	O(log n)	O(n^2)	O(1)
QST0000017	QUZ0000005	Which keyword declares a block-scoped variable?	let	let	var	def	dim
QST0000018	QUZ0000005	Which method prints to the browser console?	console.log()	print()	echo()	write()	console.log()
QST0000019	QUZ0000005	What does === compare?	Value and type	Value only	Value and type	Reference only	Length
QST0000021	QUZ0000006	Risk = Threat x ?	Vulnerability	Vulnerability	Firewall	Password	Backup
QST0000022	QUZ0000006	Which control is PREVENTIVE?	Firewall	Audit log	Firewall	CCTV review	Incident report
QST0000026	QUZ0000010	Which SQL command retrieves data from a table?	SELECT	INSERT	SELECT	UPDATE	DELETE
\.


--
-- Data for Name: quiz_results; Type: TABLE DATA; Schema: studync; Owner: studync_owner
--

COPY studync.quiz_results (result_id, student_id, quiz_id, score) FROM stdin;
RES0000001	STU0000001	QUZ0000001	100.00
RES0000002	STU0000002	QUZ0000001	80.00
RES0000003	STU0000003	QUZ0000001	60.00
RES0000004	STU0000004	QUZ0000001	40.00
RES0000005	STU0000001	QUZ0000002	75.00
RES0000006	STU0000002	QUZ0000002	100.00
RES0000007	STU0000005	QUZ0000002	50.00
RES0000008	STU0000003	QUZ0000003	100.00
RES0000009	STU0000006	QUZ0000003	25.00
RES0000010	STU0000001	QUZ0000003	75.00
RES0000011	STU0000004	QUZ0000004	100.00
RES0000012	STU0000005	QUZ0000004	66.67
RES0000015	STU0000002	QUZ0000005	66.67
RES0000016	STU0000001	QUZ0000004	66.67
\.


--
-- Data for Name: quizzes; Type: TABLE DATA; Schema: studync; Owner: studync_owner
--

COPY studync.quizzes (quiz_id, subject_id, instructor_id, title, created_at) FROM stdin;
QUZ0000001	SUB0000001	INS0000001	SQL Security Basics	2026-11-25 08:20:19.006917+08
QUZ0000002	SUB0000001	INS0000001	Database Roles and Privileges	2026-11-25 08:20:19.006917+08
QUZ0000003	SUB0000002	INS0000002	HTML and CSS Basics	2026-11-25 08:20:19.006917+08
QUZ0000005	SUB0000002	INS0000002	JavaScript Fundamentals	2026-11-25 08:20:19.006917+08
QUZ0000004	SUB0000003	INS0000003	Big-O Notation Quiz	2026-11-25 08:20:19.006917+08
QUZ0000006	SUB0000006	INS0000001	Risk Management Quiz 1	2026-11-25 08:20:30.387563+08
QUZ0000009	SUB0000001	INS0000001	Database Testing Test Quiz	2026-11-25 09:15:21.43504+08
QUZ0000010	SUB0000001	INS0000001	Database Testing Test Quiz	2026-11-25 09:15:30.836448+08
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: studync; Owner: studync_owner
--

COPY studync.roles (role_id, role_name) FROM stdin;
ROL0000001	Administrator
ROL0000002	Instructor
ROL0000003	Student
\.


--
-- Data for Name: student_answers; Type: TABLE DATA; Schema: studync; Owner: studync_owner
--

COPY studync.student_answers (answer_id, student_id, question_id, student_answer, is_correct) FROM stdin;
ANS0000001	STU0000001	QST0000001	GRANT	t
ANS0000002	STU0000001	QST0000002	SQL injection	t
ANS0000003	STU0000001	QST0000003	A salted hash	t
ANS0000004	STU0000001	QST0000004	View	t
ANS0000005	STU0000001	QST0000005	Least privilege	t
ANS0000006	STU0000002	QST0000001	GRANT	t
ANS0000007	STU0000002	QST0000002	SQL injection	t
ANS0000008	STU0000002	QST0000003	A salted hash	t
ANS0000009	STU0000002	QST0000004	View	t
ANS0000010	STU0000002	QST0000005	Defense in depth	f
ANS0000011	STU0000003	QST0000001	GRANT	t
ANS0000012	STU0000003	QST0000002	SQL injection	t
ANS0000013	STU0000003	QST0000003	A salted hash	t
ANS0000014	STU0000003	QST0000004	Index	f
ANS0000015	STU0000003	QST0000005	Separation of data	f
ANS0000016	STU0000004	QST0000001	REVOKE	f
ANS0000017	STU0000004	QST0000002	SQL injection	t
ANS0000018	STU0000004	QST0000003	Nothing	f
ANS0000019	STU0000004	QST0000004	View	t
ANS0000020	STU0000001	QST0000006	REVOKE	t
ANS0000021	STU0000001	QST0000007	Role	t
ANS0000022	STU0000001	QST0000008	EXECUTE	t
ANS0000023	STU0000001	QST0000009	Temp table	f
ANS0000024	STU0000002	QST0000006	REVOKE	t
ANS0000025	STU0000002	QST0000007	Role	t
ANS0000026	STU0000002	QST0000008	EXECUTE	t
ANS0000027	STU0000002	QST0000009	Audit log	t
ANS0000028	STU0000005	QST0000006	REVOKE	t
ANS0000029	STU0000005	QST0000007	Schema	f
ANS0000030	STU0000005	QST0000008	EXECUTE	t
ANS0000031	STU0000005	QST0000009	Temp table	f
ANS0000032	STU0000003	QST0000010	<h1>	t
ANS0000033	STU0000003	QST0000011	color	t
ANS0000034	STU0000003	QST0000012	<link>	t
ANS0000035	STU0000003	QST0000013	flex	t
ANS0000036	STU0000006	QST0000010	<head>	f
ANS0000037	STU0000006	QST0000011	color	t
ANS0000038	STU0000006	QST0000012	<style>	f
ANS0000039	STU0000006	QST0000013	block	f
ANS0000040	STU0000001	QST0000010	<h1>	t
ANS0000041	STU0000001	QST0000011	color	t
ANS0000042	STU0000001	QST0000012	<link>	t
ANS0000043	STU0000001	QST0000013	grid-inline	f
ANS0000044	STU0000004	QST0000014	O(log n)	t
ANS0000045	STU0000004	QST0000015	O(1)	t
ANS0000046	STU0000004	QST0000016	O(n^2)	t
ANS0000047	STU0000005	QST0000014	O(log n)	t
ANS0000048	STU0000005	QST0000015	O(1)	t
ANS0000049	STU0000005	QST0000016	O(1)	f
ANS0000052	STU0000002	QST0000017	let	t
ANS0000053	STU0000002	QST0000018	console.log()	t
ANS0000054	STU0000002	QST0000019	Value only	f
ANS0000055	STU0000001	QST0000014	O(log n)	t
ANS0000056	STU0000001	QST0000015	O(1)	t
ANS0000057	STU0000001	QST0000016	O(n)	f
\.


--
-- Data for Name: students; Type: TABLE DATA; Schema: studync; Owner: studync_owner
--

COPY studync.students (student_id, user_id, first_name, last_name) FROM stdin;
STU0000002	USR0000007	Ben	Torres
STU0000003	USR0000008	Carla	Dizon
STU0000004	USR0000009	Diego	Ramos
STU0000005	USR0000010	Ella	Navarro
STU0000006	USR0000011	Felix	Aquino
STU0000007	USR0000012	Gina	Lopez
STU0000008	USR0000013	Hannah	Cruz
STU0000001	USR0000006	Ana	Santos
\.


--
-- Data for Name: subjects; Type: TABLE DATA; Schema: studync; Owner: studync_owner
--

COPY studync.subjects (subject_id, subject_name, description) FROM stdin;
SUB0000001	Database Security and Administration	Roles, privileges, auditing, backup and recovery of relational databases.
SUB0000002	Web Development Fundamentals	HTML, CSS and JavaScript for building accessible web pages.
SUB0000003	Data Structures and Algorithms	Arrays, lists, trees, graphs and algorithm analysis.
SUB0000004	Networking Essentials	OSI model, TCP/IP, IP addressing, subnetting and basic network security.
SUB0000006	Information Assurance	Security policies, risk management and compliance.
SUB0000007	Audit Count Subject	\N
SUB0000008	Cloud Computing	\N
SUB0000009	Database Testing Practice	Subject created to test StudyNC database functions.
\.


--
-- Data for Name: user_roles; Type: TABLE DATA; Schema: studync; Owner: studync_owner
--

COPY studync.user_roles (user_id, role_id) FROM stdin;
USR0000001	ROL0000001
USR0000002	ROL0000001
USR0000003	ROL0000002
USR0000004	ROL0000002
USR0000005	ROL0000002
USR0000006	ROL0000003
USR0000007	ROL0000003
USR0000008	ROL0000003
USR0000009	ROL0000003
USR0000010	ROL0000003
USR0000011	ROL0000003
USR0000012	ROL0000003
USR0000002	ROL0000002
USR0000013	ROL0000003
USR0000014	ROL0000002
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: studync; Owner: studync_owner
--

COPY studync.users (user_id, username, email, password_hash, status, created_at) FROM stdin;
USR0000001	maria.reyes	maria.reyes@studync.edu	$2a$10$qe5Dn6wUUWzwKZ7phE3.oOx7rSgGSByKcj3jiMMjtLeKiwuMa2zy6	Active	2026-11-25 08:20:19.006917+08
USR0000002	carlo.mendoza	carlo.mendoza@studync.edu	$2a$10$apRIwoDrrvHZaqqnmmrvEO6xoWAp2NHJ7Gl3ikvXfdKzsD.tzJBEy	Active	2026-11-25 08:20:19.006917+08
USR0000003	jose.cruz	jose.cruz@studync.edu	$2a$10$33vX.ozMYGx7TVp9ztmaGeVmXkCiiR7EYIXkHVVTvJg.UItx8L14a	Active	2026-11-25 08:20:19.006917+08
USR0000004	liza.garcia	liza.garcia@studync.edu	$2a$10$TyNLU5MDzQgYqCevKwfdPecloi0jEGAO3Rt0PDvcetuh0t.UaIQqK	Active	2026-11-25 08:20:19.006917+08
USR0000005	ramon.villanueva	ramon.villanueva@studync.edu	$2a$10$g5tf7YWamExI8mi7grdXl.u1iWvaAwm4rjUWTG51tOV1Jw8M9Jf9O	Active	2026-11-25 08:20:19.006917+08
USR0000007	ben.torres	ben.torres@studync.edu	$2a$10$FBtEf0QeiAWQ/CVXZpnhI.orCzh7qxIDTW3.BNlapmHow.YP0RXyK	Active	2026-11-25 08:20:19.006917+08
USR0000008	carla.dizon	carla.dizon@studync.edu	$2a$10$cNaESajOBtqdVhGHglFNT.j.t7d0O91tzwW2yeZ9AnSLv4c7nN3Vm	Active	2026-11-25 08:20:19.006917+08
USR0000009	diego.ramos	diego.ramos@studync.edu	$2a$10$Qn5xTBmnc2XUP4b6YlM.zOoPrJqwAO9o0Xm/K0VtZgwpla4s4QBHm	Active	2026-11-25 08:20:19.006917+08
USR0000010	ella.navarro	ella.navarro@studync.edu	$2a$10$XnYR/gG2wRzmo32zcpeWGeUB5rjlzDT/YmjcUz0oGyKosNfzQUHP2	Active	2026-11-25 08:20:19.006917+08
USR0000011	felix.aquino	felix.aquino@studync.edu	$2a$10$LbvibTWDCuq4FOXL8SI6wu44I6FlbNF29KJmj1yFaAGYusjRUgIC6	Active	2026-11-25 08:20:19.006917+08
USR0000014	paolo.lim	paolo.lim@studync.edu	$2a$10$1Wu7Zt5OVpbyOWwIBrQeTOBwg/vd.nqMeXKm09vM8KuGFK0cx4QVu	Active	2026-11-25 08:20:30.387563+08
USR0000013	hana.cruz	hana.cruz2@studync.edu	$2a$10$957ZGd7xvu0TMsdPEFFJouQocZIv47ZQxeBzdBMeTLcWHblAsZ116	Active	2026-11-25 08:20:30.387563+08
USR0000006	ana.santos	ana.updated@studync.edu	$2a$10$NX.kPTn3KM.kM4Ldz0GrPuRU0Sn8.zPc8ffSvWeQy/1T46xltolW.	Active	2026-11-25 08:20:19.006917+08
USR0000012	gina.lopez	gina.lopez@studync.edu	$2a$10$MlmBlEwc72B4dapI0uzJZOcmTtqS6Kokg4pORjAmWtdXUzV6JnnRy	Active	2026-11-25 08:20:19.006917+08
\.


--
-- Data for Name: results; Type: TABLE DATA; Schema: studync_test; Owner: postgres
--

COPY studync_test.results (seq, test_id, description, expected, outcome, detail, run_as, run_at) FROM stdin;
1	STR-01	Database studync_db exists	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.44193+08
2	STR-02	All 13 ERD tables exist	TRUE	PASS	admins,instructors,students,subjects,materials,quizzes,student_answers,user_roles,quiz_results,roles,users,audit_logs,questions	postgres	2026-11-25 08:20:30.446669+08
3	STR-03	14 foreign keys defined	TRUE	PASS	14 FKs	postgres	2026-11-25 08:20:30.448698+08
4	STR-04	10 views defined	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.449218+08
5	STR-05	Procedures and functions exist (>=27 procedures / >=20 fn_ functions)	TRUE	PASS	f:24 p:27	postgres	2026-11-25 08:20:30.451062+08
6	STR-06	41 triggers (36 audit + 5 business rule)	TRUE	PASS	41 triggers	postgres	2026-11-25 08:20:30.452902+08
7	STR-07	Sample data loaded (12 users, 19 questions, 12 results)	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.45787+08
8	CON-01	FK: material for a non-existent subject is rejected	ERROR 23503	PASS	error 23503: insert or update on table "materials" violates foreign key constraint "fk_materials_subject"	postgres	2026-11-25 08:20:30.459759+08
9	CON-02	FK: deleting a subject that has materials is rejected (no orphans)	ERROR 23503	FAIL	error 23001: update or delete on table "subjects" violates RESTRICT setting of foreign key constraint "fk_materials_subject" on table "materials"	postgres	2026-11-25 08:20:30.462748+08
10	CON-03	FK: deleting a quiz that has questions is rejected	ERROR 23503	FAIL	error 23001: update or delete on table "quizzes" violates RESTRICT setting of foreign key constraint "fk_questions_quiz" on table "questions"	postgres	2026-11-25 08:20:30.464649+08
11	CON-04	CHECK: correct_answer must be one of the options	ERROR 23514	PASS	error 23514: new row for relation "questions" violates check constraint "ck_questions_correct_is_option"	postgres	2026-11-25 08:20:30.464849+08
12	CON-05	UNIQUE: duplicate username rejected (case-insensitive)	ERROR 23505	PASS	error 23505: duplicate key value violates unique constraint "uq_users_username"	postgres	2026-11-25 08:20:30.465255+08
13	CON-06	CHECK: invalid email format rejected	ERROR 23514	PASS	error 23514: new row for relation "users" violates check constraint "ck_users_email_format"	postgres	2026-11-25 08:20:30.4654+08
14	CON-07	CHECK: badly formatted primary key rejected	ERROR 23514	PASS	error 23514: new row for relation "subjects" violates check constraint "ck_subjects_id_format"	postgres	2026-11-25 08:20:30.465512+08
15	CON-08	NOT NULL: material without file_path rejected	ERROR 23502	PASS	error 23502: null value in column "file_path" of relation "materials" violates not-null constraint	postgres	2026-11-25 08:20:30.465595+08
16	CON-09	UNIQUE: second result for same student and quiz rejected	ERROR 23505	PASS	error 23505: duplicate key value violates unique constraint "uq_quiz_results_student_quiz"	postgres	2026-11-25 08:20:30.46802+08
17	CON-10	Trigger: answers are locked after the quiz is submitted	ERROR answers are locked	PASS	error P0001: Quiz already submitted; answers are locked	postgres	2026-11-25 08:20:30.468413+08
18	CON-11	Trigger: student answers cannot be modified	ERROR cannot be modified	PASS	error P0001: Student answers cannot be modified once submitted	postgres	2026-11-25 08:20:30.468619+08
19	CON-12	Trigger: audit_logs is append-only (UPDATE blocked, even for superuser)	ERROR append-only	PASS	error P0001: audit_logs is append-only: UPDATE/DELETE is not allowed	postgres	2026-11-25 08:20:30.471987+08
20	CON-13	Trigger: audit_logs is append-only (DELETE blocked, even for superuser)	ERROR append-only	PASS	error P0001: audit_logs is append-only: UPDATE/DELETE is not allowed	postgres	2026-11-25 08:20:30.472478+08
21	CON-17	Trigger: TRUNCATE audit_logs blocked, even for superuser (PostgreSQL only)	ERROR append-only	PASS	error P0001: audit_logs is append-only: TRUNCATE is not allowed	postgres	2026-11-25 08:20:30.472642+08
22	CON-16	DBA maintenance account cannot TRUNCATE audit_logs	ERROR 42501	PASS	error 42501: permission denied for table audit_logs	studync_dba	2026-11-25 08:20:30.472738+08
23	CON-14	Trigger ignores a forged is_correct = TRUE for a wrong answer	TRUE	PASS	stored is_correct = false	postgres	2026-11-25 08:20:30.47903+08
24	CON-15	Trigger recomputes a forged score of 100 (0 of 3 correct -> 0.00)	TRUE	PASS	stored score = 0.00	postgres	2026-11-25 08:20:30.479896+08
25	USR-01	Admin registers a new student	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.534202+08
26	USR-02	Registration created users + user_roles + students rows	TRUE	PASS	USR0000013	postgres	2026-11-25 08:20:30.53565+08
27	USR-03	Password is stored as a bcrypt hash, never in plain text	TRUE	PASS	$2a$10$PMX9/	postgres	2026-11-25 08:20:30.535793+08
28	USR-04	Same password hashed twice gives different hashes (random salt)	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.61896+08
29	USR-05	Admin registers a new instructor	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.662602+08
30	USR-06	Duplicate username rejected by procedure	ERROR Username already exists	PASS	error P0001: Username already exists	postgres	2026-11-25 08:20:30.663035+08
31	USR-07	Weak password rejected	ERROR Weak password	PASS	error P0001: Weak password: minimum 8 characters with upper-case, lower-case and a digit	postgres	2026-11-25 08:20:30.663331+08
32	USR-08	Invalid email rejected	ERROR Invalid email	PASS	error P0001: Invalid email address	postgres	2026-11-25 08:20:30.663591+08
33	USR-09	Instructor cannot register users (application role check)	ERROR ACCESS DENIED	PASS	error 42501: ACCESS DENIED: this operation requires role(s) Administrator	postgres	2026-11-25 08:20:30.664159+08
34	USR-10	Unknown acting user rejected	ERROR unknown acting user	PASS	error 42501: ACCESS DENIED: unknown acting user	postgres	2026-11-25 08:20:30.664349+08
35	USR-11	Authentication succeeds with the correct password	TRUE	PASS	t | USR0000013 | Student | Login successful	postgres	2026-11-25 08:20:30.709724+08
36	USR-12	Authentication fails with a wrong password (generic message)	TRUE	PASS	f | Invalid username or password	postgres	2026-11-25 08:20:30.750699+08
37	USR-13	Inactive account cannot log in	TRUE	PASS	f | Invalid username or password	postgres	2026-11-25 08:20:30.750939+08
38	USR-14	Failed logins are written to the audit log	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.751891+08
39	USR-15	Admin updates user email and name	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.756914+08
40	USR-16	Update stored (email lower-cased, first name changed)	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.757296+08
41	USR-17	Admin assigns the Instructor role to a student (profile auto-created)	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.758495+08
42	USR-18	Role assignment created user_roles + instructors rows	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.758788+08
43	USR-19	Admin revokes the Instructor role again	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.759527+08
44	USR-20	Admin cannot revoke own Administrator role	ERROR cannot revoke their own	PASS	error P0001: Administrators cannot revoke their own Administrator role	postgres	2026-11-25 08:20:30.759773+08
45	USR-21	Admin cannot deactivate own account	ERROR own account status	PASS	error P0001: Administrators cannot change their own account status	postgres	2026-11-25 08:20:30.759981+08
46	USR-22	Inactive user cannot perform any operation	ERROR inactive	PASS	error 42501: ACCESS DENIED: account is inactive	postgres	2026-11-25 08:20:30.760162+08
47	USR-23	User changes own password	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.850452+08
48	USR-24	Login works with the new password	TRUE	PASS	Login successful	postgres	2026-11-25 08:20:30.893088+08
49	USR-25	Password change with wrong current password rejected	ERROR Current password is inco	PASS	error P0001: Current password is incorrect	postgres	2026-11-25 08:20:30.936401+08
50	USR-26	Student cannot read another user record	ERROR ACCESS DENIED	PASS	error 42501: ACCESS DENIED: you may only view your own account	postgres	2026-11-25 08:20:30.938009+08
51	SUB-01	Admin creates a subject	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.939233+08
52	SUB-02	New subject stored with generated id	TRUE	PASS	SUB0000006	postgres	2026-11-25 08:20:30.939349+08
53	SUB-03	Duplicate subject name rejected	ERROR already exists	PASS	error P0001: Subject name already exists	postgres	2026-11-25 08:20:30.939555+08
54	SUB-04	Admin updates the subject	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.940447+08
55	SUB-05	Admin deletes an unused subject	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.941406+08
56	SUB-06	Deleted subject is gone	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.941491+08
57	SUB-07	Subject that has materials/quizzes cannot be deleted	ERROR cannot be deleted	PASS	error P0001: Subject has materials or quizzes and cannot be deleted	postgres	2026-11-25 08:20:30.941778+08
58	SUB-08	Instructor cannot create subjects	ERROR ACCESS DENIED	PASS	error 42501: ACCESS DENIED: this operation requires role(s) Administrator	postgres	2026-11-25 08:20:30.941975+08
59	SUB-09	Student cannot delete subjects	ERROR ACCESS DENIED	PASS	error 42501: ACCESS DENIED: this operation requires role(s) Administrator	postgres	2026-11-25 08:20:30.942107+08
60	MAT-01	Instructor uploads a material	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.943039+08
61	MAT-02	Material linked to subject and uploading instructor	TRUE	PASS	MAT0000012	postgres	2026-11-25 08:20:30.943235+08
62	MAT-03	Owner updates the material title	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.944003+08
63	MAT-04	Another instructor cannot update it	ERROR ACCESS DENIED	PASS	error 42501: ACCESS DENIED: you can only modify your own materials	postgres	2026-11-25 08:20:30.944325+08
64	MAT-05	Another instructor cannot delete it	ERROR ACCESS DENIED	PASS	error 42501: ACCESS DENIED: you can only delete your own materials	postgres	2026-11-25 08:20:30.944608+08
65	MAT-06	Path traversal in file_path rejected	ERROR Invalid file path	PASS	error P0001: Invalid file path	postgres	2026-11-25 08:20:30.944804+08
66	MAT-07	Upload to a non-existent subject rejected	ERROR Subject not found	PASS	error P0001: Subject not found	postgres	2026-11-25 08:20:30.945216+08
67	MAT-08	Student cannot upload materials	ERROR ACCESS DENIED	PASS	error 42501: ACCESS DENIED: this operation requires role(s) Instructor	postgres	2026-11-25 08:20:30.945392+08
68	MAT-09	Student retrieves the materials of a subject	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.946075+08
69	MAT-10	Owner deletes the material	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.946557+08
70	MAT-11	Material deleted	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.946652+08
71	QUZ-01	Instructor creates a quiz	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.947337+08
72	QUZ-02	Instructor adds question 1 (correct answer given as letter)	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.948453+08
73	QUZ-03	Instructor adds question 2 (correct answer given as text)	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.948826+08
74	QUZ-04	Correct answers stored as option text	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.948933+08
75	QUZ-05	Question whose correct answer is not an option rejected	ERROR Correct answer must be	PASS	error P0001: Correct answer must be A, B, C, D or the exact text of an option	postgres	2026-11-25 08:20:30.949176+08
76	QUZ-06	Question with duplicate options rejected (CHECK)	ERROR 23514	PASS	error 23514: new row for relation "questions" violates check constraint "ck_questions_distinct_options"	postgres	2026-11-25 08:20:30.949503+08
77	QUZ-07	Instructor updates a question	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.950472+08
78	QUZ-08	Instructor adds and deletes a temporary question	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.9508+08
79	QUZ-09	Instructor deletes a question	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.95171+08
80	QUZ-10	Instructor updates the quiz title	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.952206+08
81	QUZ-11	Another instructor cannot modify the quiz	ERROR ACCESS DENIED	PASS	error 42501: ACCESS DENIED: you can only manage your own quizzes	postgres	2026-11-25 08:20:30.952367+08
82	QUZ-12	Another instructor cannot add questions to it	ERROR ACCESS DENIED	PASS	error 42501: ACCESS DENIED: you can only manage your own quizzes	postgres	2026-11-25 08:20:30.952513+08
83	QUZ-13	Quiz with submitted results cannot be deleted	ERROR cannot be deleted	PASS	error P0001: Quiz already has student answers or results and cannot be deleted	postgres	2026-11-25 08:20:30.952827+08
84	QUZ-14	Answered question cannot be changed	ERROR locked	PASS	error P0001: Question has already been answered and is locked	postgres	2026-11-25 08:20:30.95307+08
85	QUZ-15	Student cannot create quizzes	ERROR ACCESS DENIED	PASS	error 42501: ACCESS DENIED: this operation requires role(s) Instructor	postgres	2026-11-25 08:20:30.953191+08
86	QUZ-16	Instructor creates and deletes an unused quiz (with a question)	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.95344+08
87	QUZ-17	Delete unused quiz	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.954557+08
88	QUZ-18	Quiz and its questions removed; question deletion audited	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.954756+08
89	QUZ-19	Student question view hides the answer key	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.967276+08
90	ASM-01	Student answers Q17 with a letter (correct)	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.968256+08
91	ASM-02	Student answers Q18 with option text (correct)	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.968856+08
92	ASM-03	Answer that is not an option is rejected	ERROR Answer must be	PASS	error P0001: Answer must be A, B, C, D or the exact text of an option	postgres	2026-11-25 08:20:30.969393+08
93	ASM-04	Student answers Q19 (wrong)	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.969888+08
94	ASM-05	Second answer to the same question rejected	ERROR already answered	PASS	error P0001: Question already answered	postgres	2026-11-25 08:20:30.970198+08
95	ASM-06	is_correct computed by the database (t,t,f)	TRUE	PASS	true,true,false	postgres	2026-11-25 08:20:30.970457+08
96	ASM-07	Student submits the quiz	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.971373+08
97	ASM-08	Score = 2 of 3 correct = 66.67	TRUE	PASS	RES0000015 score=66.67	postgres	2026-11-25 08:20:30.971501+08
98	ASM-09	Quiz cannot be submitted twice	ERROR already submitted	PASS	error P0001: Quiz already submitted	postgres	2026-11-25 08:20:30.971726+08
99	ASM-10	Submitting a quiz with no answers rejected	ERROR No answers submitted	PASS	error P0001: No answers submitted for this quiz	postgres	2026-11-25 08:20:30.97207+08
100	ASM-11	Instructor cannot submit answers	ERROR ACCESS DENIED	PASS	error 42501: ACCESS DENIED: this operation requires role(s) Student	postgres	2026-11-25 08:20:30.972185+08
101	ASM-12	fn_calculate_quiz_score: partial attempt (4 of 5 answered, 2 correct) = 40.00	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.972325+08
102	ASM-13	Every stored score equals the documented formula	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.973009+08
103	ASM-14	Student retrieves own results	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.974213+08
104	ASM-15	Student cannot retrieve another student's results	ERROR ACCESS DENIED	PASS	error 42501: ACCESS DENIED: students may only view their own results	postgres	2026-11-25 08:20:30.974532+08
105	ASM-16	Student reviews own submitted answers	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.975008+08
106	ASM-17	Answer review is not available before submission	ERROR No submitted result	PASS	error P0001: No submitted result for this student and quiz	postgres	2026-11-25 08:20:30.975426+08
107	RPT-01	Admin: student performance report (all subjects)	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.976549+08
108	RPT-02	Instructor: performance report limited to own quizzes	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.977138+08
109	RPT-03	Student cannot run performance reports	ERROR ACCESS DENIED	PASS	error 42501: ACCESS DENIED: this operation requires role(s) Administrator,Instructor	postgres	2026-11-25 08:20:30.977307+08
110	RPT-04	Instructor: quiz results report for own quiz	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.978102+08
111	RPT-05	Instructor: quiz results report for another instructor's quiz denied	ERROR ACCESS DENIED	PASS	error 42501: ACCESS DENIED: you can only manage your own quizzes	postgres	2026-11-25 08:20:30.978322+08
112	RPT-06	Admin: audit log report (filter by table)	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.978999+08
113	RPT-07	Instructor cannot read audit logs	ERROR ACCESS DENIED	PASS	error 42501: ACCESS DENIED: this operation requires role(s) Administrator	postgres	2026-11-25 08:20:30.979198+08
114	RPT-08	Admin: system activity summary	SUCCESS	PASS	succeeded	postgres	2026-11-25 08:20:30.979859+08
115	RPT-09	Performance view: Ana avg of 100,75,75 = 83.33	TRUE	PASS	avg=83.33	postgres	2026-11-25 08:20:30.980694+08
116	RPT-10	Quiz results view: QUZ0000001 has 4 submissions, average 70.00	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.981075+08
117	AUD-01	INSERT audited with acting user, record id and new data	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.981248+08
118	AUD-02	UPDATE audited with old and new values	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.981374+08
119	AUD-03	DELETE audited with the deleted row in old_data	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.981466+08
120	AUD-04	password_hash never appears in the audit trail	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.981618+08
121	AUD-05	Password change logged as a flag only	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.981732+08
122	AUD-06	One operation produces exactly one audit row (no duplicates)	TRUE	PASS	1 new row(s)	postgres	2026-11-25 08:20:30.982312+08
123	AUD-07	No-op update writes no audit row	TRUE	PASS	0 new row(s)	postgres	2026-11-25 08:20:30.982735+08
124	AUD-08	Assessment activity audited (answers and results by the student)	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.98294+08
125	AUD-09	Direct DBA changes are audited with db_user and NULL application user	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.983074+08
126	AUD-10	Session identity setting is cleared after each procedure	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.98312+08
127	AUD-11	Failed procedure calls leave no audit rows (rolled back)	TRUE	PASS	\N	postgres	2026-11-25 08:20:30.983199+08
128	RB-S01	Student can read the student question view	SUCCESS	PASS	succeeded	ana.santos	2026-11-25 08:20:30.983419+08
129	RB-S02	Student can read learning materials	SUCCESS	PASS	succeeded	ana.santos	2026-11-25 08:20:30.983649+08
130	RB-S03	Student cannot read the users table (password hashes)	ERROR 42501	PASS	error 42501: permission denied for table users	ana.santos	2026-11-25 08:20:30.983773+08
131	RB-S04	Student cannot read the answer key view	ERROR 42501	PASS	error 42501: permission denied for view v_quiz_questions_instructor	ana.santos	2026-11-25 08:20:30.983967+08
132	RB-S05	Student cannot read the questions table directly	ERROR 42501	PASS	error 42501: permission denied for table questions	ana.santos	2026-11-25 08:20:30.984054+08
133	RB-S06	Student cannot insert a result directly	ERROR 42501	PASS	error 42501: permission denied for table quiz_results	ana.santos	2026-11-25 08:20:30.984141+08
134	RB-S07	Student cannot execute admin procedures	ERROR 42501	PASS	error 42501: permission denied for procedure sp_create_subject	ana.santos	2026-11-25 08:20:30.984198+08
135	RB-S08	Student cannot execute instructor procedures	ERROR 42501	PASS	error 42501: permission denied for procedure sp_upload_material	ana.santos	2026-11-25 08:20:30.984249+08
136	RB-S09	Student cannot read the audit trail	ERROR 42501	PASS	error 42501: permission denied for view v_audit_trail	ana.santos	2026-11-25 08:20:30.984331+08
137	RB-S10	Student cannot delete audit logs	ERROR 42501	PASS	error 42501: permission denied for table audit_logs	ana.santos	2026-11-25 08:20:30.984414+08
138	RB-S11	Personal login cannot impersonate another student	ERROR may only act as its own 	PASS	error 42501: ACCESS DENIED: a personal database login may only act as its own user	ana.santos	2026-11-25 08:20:30.984562+08
139	RB-S12	Student answers Big-O quiz Q14	SUCCESS	PASS	succeeded	ana.santos	2026-11-25 08:20:30.985126+08
140	RB-S13	Student answers Big-O quiz Q15	SUCCESS	PASS	succeeded	ana.santos	2026-11-25 08:20:30.985424+08
141	RB-S14	Student answers Big-O quiz Q16	SUCCESS	PASS	succeeded	ana.santos	2026-11-25 08:20:30.985663+08
142	RB-S15	Student submits the quiz	SUCCESS	PASS	succeeded	ana.santos	2026-11-25 08:20:30.986175+08
143	RB-S16	Student sees own new score 66.67	TRUE	PASS	score=66.67	ana.santos	2026-11-25 08:20:30.986851+08
144	RB-S17	v_my_results shows only this student's 4 results	TRUE	PASS	4 rows	ana.santos	2026-11-25 08:20:30.987581+08
145	RB-S18	Student calls own results function	SUCCESS	PASS	succeeded	ana.santos	2026-11-25 08:20:30.988275+08
146	RB-I01	Instructor uploads a material	SUCCESS	PASS	succeeded	jose.cruz	2026-11-25 08:20:30.988659+08
147	RB-I02	Instructor reads the answer-key view	SUCCESS	PASS	succeeded	jose.cruz	2026-11-25 08:20:30.988825+08
148	RB-I03	Instructor reads quiz results	SUCCESS	PASS	succeeded	jose.cruz	2026-11-25 08:20:30.989374+08
149	RB-I04	Instructor cannot read users table	ERROR 42501	PASS	error 42501: permission denied for table users	jose.cruz	2026-11-25 08:20:30.989476+08
150	RB-I05	Instructor cannot register students	ERROR 42501	PASS	error 42501: permission denied for procedure sp_register_student	jose.cruz	2026-11-25 08:20:30.989533+08
151	RB-I06	Instructor cannot create subjects	ERROR 42501	PASS	error 42501: permission denied for procedure sp_create_subject	jose.cruz	2026-11-25 08:20:30.989611+08
152	RB-I07	Instructor cannot read the audit trail	ERROR 42501	PASS	error 42501: permission denied for view v_audit_trail	jose.cruz	2026-11-25 08:20:30.989692+08
153	RB-I08	Instructor cannot submit answers	ERROR 42501	PASS	error 42501: permission denied for procedure sp_submit_answer	jose.cruz	2026-11-25 08:20:30.98974+08
154	RB-I09	Instructor cannot update materials table directly	ERROR 42501	PASS	error 42501: permission denied for table materials	jose.cruz	2026-11-25 08:20:30.989815+08
155	RB-I10	Personal login cannot act as another instructor	ERROR may only act as its own 	PASS	error 42501: ACCESS DENIED: a personal database login may only act as its own user	jose.cruz	2026-11-25 08:20:30.989926+08
156	RB-A01	Admin reads the user directory (no password hashes)	SUCCESS	PASS	succeeded	maria.reyes	2026-11-25 08:20:30.990499+08
157	RB-A02	Admin reads the audit trail	SUCCESS	PASS	succeeded	maria.reyes	2026-11-25 08:20:30.990684+08
158	RB-A03	Admin creates a subject	SUCCESS	PASS	succeeded	maria.reyes	2026-11-25 08:20:30.990953+08
159	RB-A04	Admin cannot read password hashes from users table	ERROR 42501	PASS	error 42501: permission denied for table users	maria.reyes	2026-11-25 08:20:30.991033+08
160	RB-A05	Admin cannot delete audit logs	ERROR 42501	PASS	error 42501: permission denied for table audit_logs	maria.reyes	2026-11-25 08:20:30.991181+08
161	RB-A06	Admin cannot upload materials (instructor function)	ERROR 42501	PASS	error 42501: permission denied for procedure sp_upload_material	maria.reyes	2026-11-25 08:20:30.991233+08
162	RB-A07	Admin cannot submit answers (student function)	ERROR 42501	PASS	error 42501: permission denied for procedure sp_submit_answer	maria.reyes	2026-11-25 08:20:30.991283+08
163	RB-A08	Admin cannot call internal helper procedures	ERROR 42501	PASS	error 42501: permission denied for procedure sp_set_actor	maria.reyes	2026-11-25 08:20:30.991327+08
164	RB-A09	v_user_directory exposes no password_hash column	TRUE	PASS	\N	maria.reyes	2026-11-25 08:20:30.992608+08
165	RB-P01	Shared student account cannot call admin procedures even with an admin id	ERROR 42501	PASS	error 42501: permission denied for procedure sp_create_subject	studync_app_student	2026-11-25 08:20:30.9928+08
166	RB-P02	Shared student account passing an instructor id is still blocked by role check	ERROR ACCESS DENIED	PASS	error 42501: ACCESS DENIED: this operation requires role(s) Student	studync_app_student	2026-11-25 08:20:30.992935+08
167	RB-P03	Shared student account retrieves results for the authenticated student	SUCCESS	PASS	succeeded	studync_app_student	2026-11-25 08:20:30.993968+08
168	RB-P04	Row-filtered view returns nothing for a non-personal login	TRUE	PASS	\N	studync_app_student	2026-11-25 08:20:30.994497+08
169	GR-01	After GRANT, ben.torres can read v_audit_trail	SUCCESS	PASS	succeeded	ben.torres	2026-11-25 08:20:30.994863+08
170	GR-02	After REVOKE, ben.torres is denied again	ERROR 42501	PASS	error 42501: permission denied for view v_audit_trail	ben.torres	2026-11-25 08:20:30.995629+08
\.


--
-- Name: audit_logs_log_id_seq; Type: SEQUENCE SET; Schema: studync; Owner: studync_owner
--

SELECT pg_catalog.setval('studync.audit_logs_log_id_seq', 211, true);


--
-- Name: seq_admins; Type: SEQUENCE SET; Schema: studync; Owner: studync_owner
--

SELECT pg_catalog.setval('studync.seq_admins', 3, true);


--
-- Name: seq_instructors; Type: SEQUENCE SET; Schema: studync; Owner: studync_owner
--

SELECT pg_catalog.setval('studync.seq_instructors', 6, true);


--
-- Name: seq_materials; Type: SEQUENCE SET; Schema: studync; Owner: studync_owner
--

SELECT pg_catalog.setval('studync.seq_materials', 15, true);


--
-- Name: seq_questions; Type: SEQUENCE SET; Schema: studync; Owner: studync_owner
--

SELECT pg_catalog.setval('studync.seq_questions', 26, true);


--
-- Name: seq_quiz_results; Type: SEQUENCE SET; Schema: studync; Owner: studync_owner
--

SELECT pg_catalog.setval('studync.seq_quiz_results', 16, true);


--
-- Name: seq_quizzes; Type: SEQUENCE SET; Schema: studync; Owner: studync_owner
--

SELECT pg_catalog.setval('studync.seq_quizzes', 10, true);


--
-- Name: seq_student_answers; Type: SEQUENCE SET; Schema: studync; Owner: studync_owner
--

SELECT pg_catalog.setval('studync.seq_student_answers', 57, true);


--
-- Name: seq_students; Type: SEQUENCE SET; Schema: studync; Owner: studync_owner
--

SELECT pg_catalog.setval('studync.seq_students', 8, true);


--
-- Name: seq_subjects; Type: SEQUENCE SET; Schema: studync; Owner: studync_owner
--

SELECT pg_catalog.setval('studync.seq_subjects', 9, true);


--
-- Name: seq_users; Type: SEQUENCE SET; Schema: studync; Owner: studync_owner
--

SELECT pg_catalog.setval('studync.seq_users', 14, true);


--
-- Name: results_seq_seq; Type: SEQUENCE SET; Schema: studync_test; Owner: postgres
--

SELECT pg_catalog.setval('studync_test.results_seq_seq', 170, true);


--
-- Name: admins pk_admins; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.admins
    ADD CONSTRAINT pk_admins PRIMARY KEY (admin_id);


--
-- Name: audit_logs pk_audit_logs; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.audit_logs
    ADD CONSTRAINT pk_audit_logs PRIMARY KEY (log_id);


--
-- Name: instructors pk_instructors; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.instructors
    ADD CONSTRAINT pk_instructors PRIMARY KEY (instructor_id);


--
-- Name: materials pk_materials; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.materials
    ADD CONSTRAINT pk_materials PRIMARY KEY (material_id);


--
-- Name: questions pk_questions; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.questions
    ADD CONSTRAINT pk_questions PRIMARY KEY (question_id);


--
-- Name: quiz_results pk_quiz_results; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.quiz_results
    ADD CONSTRAINT pk_quiz_results PRIMARY KEY (result_id);


--
-- Name: quizzes pk_quizzes; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.quizzes
    ADD CONSTRAINT pk_quizzes PRIMARY KEY (quiz_id);


--
-- Name: roles pk_roles; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.roles
    ADD CONSTRAINT pk_roles PRIMARY KEY (role_id);


--
-- Name: student_answers pk_student_answers; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.student_answers
    ADD CONSTRAINT pk_student_answers PRIMARY KEY (answer_id);


--
-- Name: students pk_students; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.students
    ADD CONSTRAINT pk_students PRIMARY KEY (student_id);


--
-- Name: subjects pk_subjects; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.subjects
    ADD CONSTRAINT pk_subjects PRIMARY KEY (subject_id);


--
-- Name: user_roles pk_user_roles; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.user_roles
    ADD CONSTRAINT pk_user_roles PRIMARY KEY (user_id, role_id);


--
-- Name: users pk_users; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.users
    ADD CONSTRAINT pk_users PRIMARY KEY (user_id);


--
-- Name: admins uq_admins_user_id; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.admins
    ADD CONSTRAINT uq_admins_user_id UNIQUE (user_id);


--
-- Name: instructors uq_instructors_user_id; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.instructors
    ADD CONSTRAINT uq_instructors_user_id UNIQUE (user_id);


--
-- Name: quiz_results uq_quiz_results_student_quiz; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.quiz_results
    ADD CONSTRAINT uq_quiz_results_student_quiz UNIQUE (student_id, quiz_id);


--
-- Name: roles uq_roles_role_name; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.roles
    ADD CONSTRAINT uq_roles_role_name UNIQUE (role_name);


--
-- Name: student_answers uq_student_answers_student_question; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.student_answers
    ADD CONSTRAINT uq_student_answers_student_question UNIQUE (student_id, question_id);


--
-- Name: students uq_students_user_id; Type: CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.students
    ADD CONSTRAINT uq_students_user_id UNIQUE (user_id);


--
-- Name: results results_pkey; Type: CONSTRAINT; Schema: studync_test; Owner: postgres
--

ALTER TABLE ONLY studync_test.results
    ADD CONSTRAINT results_pkey PRIMARY KEY (seq);


--
-- Name: ix_audit_logs_new_data_gin; Type: INDEX; Schema: studync; Owner: studync_owner
--

CREATE INDEX ix_audit_logs_new_data_gin ON studync.audit_logs USING gin (new_data jsonb_path_ops);


--
-- Name: ix_audit_logs_performed_by; Type: INDEX; Schema: studync; Owner: studync_owner
--

CREATE INDEX ix_audit_logs_performed_by ON studync.audit_logs USING btree (performed_by, log_timestamp);


--
-- Name: ix_audit_logs_table_time; Type: INDEX; Schema: studync; Owner: studync_owner
--

CREATE INDEX ix_audit_logs_table_time ON studync.audit_logs USING btree (table_name, log_timestamp);


--
-- Name: ix_audit_logs_time; Type: INDEX; Schema: studync; Owner: studync_owner
--

CREATE INDEX ix_audit_logs_time ON studync.audit_logs USING btree (log_timestamp);


--
-- Name: ix_instructors_name; Type: INDEX; Schema: studync; Owner: studync_owner
--

CREATE INDEX ix_instructors_name ON studync.instructors USING btree (last_name, first_name);


--
-- Name: ix_materials_instructor_id; Type: INDEX; Schema: studync; Owner: studync_owner
--

CREATE INDEX ix_materials_instructor_id ON studync.materials USING btree (instructor_id);


--
-- Name: ix_materials_subject_uploaded; Type: INDEX; Schema: studync; Owner: studync_owner
--

CREATE INDEX ix_materials_subject_uploaded ON studync.materials USING btree (subject_id, uploaded_at);


--
-- Name: ix_questions_quiz_id; Type: INDEX; Schema: studync; Owner: studync_owner
--

CREATE INDEX ix_questions_quiz_id ON studync.questions USING btree (quiz_id);


--
-- Name: ix_quiz_results_quiz_score; Type: INDEX; Schema: studync; Owner: studync_owner
--

CREATE INDEX ix_quiz_results_quiz_score ON studync.quiz_results USING btree (quiz_id, score);


--
-- Name: ix_quizzes_instructor_id; Type: INDEX; Schema: studync; Owner: studync_owner
--

CREATE INDEX ix_quizzes_instructor_id ON studync.quizzes USING btree (instructor_id);


--
-- Name: ix_quizzes_subject_created; Type: INDEX; Schema: studync; Owner: studync_owner
--

CREATE INDEX ix_quizzes_subject_created ON studync.quizzes USING btree (subject_id, created_at);


--
-- Name: ix_student_answers_question_id; Type: INDEX; Schema: studync; Owner: studync_owner
--

CREATE INDEX ix_student_answers_question_id ON studync.student_answers USING btree (question_id);


--
-- Name: ix_students_name; Type: INDEX; Schema: studync; Owner: studync_owner
--

CREATE INDEX ix_students_name ON studync.students USING btree (last_name, first_name);


--
-- Name: ix_user_roles_role_id; Type: INDEX; Schema: studync; Owner: studync_owner
--

CREATE INDEX ix_user_roles_role_id ON studync.user_roles USING btree (role_id);


--
-- Name: ix_users_status; Type: INDEX; Schema: studync; Owner: studync_owner
--

CREATE INDEX ix_users_status ON studync.users USING btree (status);


--
-- Name: uq_subjects_subject_name; Type: INDEX; Schema: studync; Owner: studync_owner
--

CREATE UNIQUE INDEX uq_subjects_subject_name ON studync.subjects USING btree (lower((subject_name)::text));


--
-- Name: uq_users_email; Type: INDEX; Schema: studync; Owner: studync_owner
--

CREATE UNIQUE INDEX uq_users_email ON studync.users USING btree (lower((email)::text));


--
-- Name: uq_users_username; Type: INDEX; Schema: studync; Owner: studync_owner
--

CREATE UNIQUE INDEX uq_users_username ON studync.users USING btree (lower((username)::text));


--
-- Name: admins trg_admins_audit_del; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_admins_audit_del AFTER DELETE ON studync.admins FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('admin_id');


--
-- Name: admins trg_admins_audit_ins; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_admins_audit_ins AFTER INSERT ON studync.admins FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('admin_id');


--
-- Name: admins trg_admins_audit_upd; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_admins_audit_upd AFTER UPDATE ON studync.admins FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION studync.fn_audit_row('admin_id');


--
-- Name: audit_logs trg_audit_logs_no_modify; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_audit_logs_no_modify BEFORE DELETE OR UPDATE ON studync.audit_logs FOR EACH ROW EXECUTE FUNCTION studync.fn_trg_reject_change('audit_logs is append-only: UPDATE/DELETE is not allowed');


--
-- Name: audit_logs trg_audit_logs_no_truncate; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_audit_logs_no_truncate BEFORE TRUNCATE ON studync.audit_logs FOR EACH STATEMENT EXECUTE FUNCTION studync.fn_trg_reject_change('audit_logs is append-only: TRUNCATE is not allowed');


--
-- Name: instructors trg_instructors_audit_del; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_instructors_audit_del AFTER DELETE ON studync.instructors FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('instructor_id');


--
-- Name: instructors trg_instructors_audit_ins; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_instructors_audit_ins AFTER INSERT ON studync.instructors FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('instructor_id');


--
-- Name: instructors trg_instructors_audit_upd; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_instructors_audit_upd AFTER UPDATE ON studync.instructors FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION studync.fn_audit_row('instructor_id');


--
-- Name: materials trg_materials_audit_del; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_materials_audit_del AFTER DELETE ON studync.materials FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('material_id');


--
-- Name: materials trg_materials_audit_ins; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_materials_audit_ins AFTER INSERT ON studync.materials FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('material_id');


--
-- Name: materials trg_materials_audit_upd; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_materials_audit_upd AFTER UPDATE ON studync.materials FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION studync.fn_audit_row('material_id');


--
-- Name: questions trg_questions_audit_del; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_questions_audit_del AFTER DELETE ON studync.questions FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('question_id');


--
-- Name: questions trg_questions_audit_ins; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_questions_audit_ins AFTER INSERT ON studync.questions FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('question_id');


--
-- Name: questions trg_questions_audit_upd; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_questions_audit_upd AFTER UPDATE ON studync.questions FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION studync.fn_audit_row('question_id');


--
-- Name: quiz_results trg_quiz_results_audit_del; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_quiz_results_audit_del AFTER DELETE ON studync.quiz_results FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('result_id');


--
-- Name: quiz_results trg_quiz_results_audit_ins; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_quiz_results_audit_ins AFTER INSERT ON studync.quiz_results FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('result_id');


--
-- Name: quiz_results trg_quiz_results_audit_upd; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_quiz_results_audit_upd AFTER UPDATE ON studync.quiz_results FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION studync.fn_audit_row('result_id');


--
-- Name: quiz_results trg_quiz_results_score; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_quiz_results_score BEFORE INSERT OR UPDATE ON studync.quiz_results FOR EACH ROW EXECUTE FUNCTION studync.fn_trg_quiz_results_score();


--
-- Name: quizzes trg_quizzes_audit_del; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_quizzes_audit_del AFTER DELETE ON studync.quizzes FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('quiz_id');


--
-- Name: quizzes trg_quizzes_audit_ins; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_quizzes_audit_ins AFTER INSERT ON studync.quizzes FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('quiz_id');


--
-- Name: quizzes trg_quizzes_audit_upd; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_quizzes_audit_upd AFTER UPDATE ON studync.quizzes FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION studync.fn_audit_row('quiz_id');


--
-- Name: roles trg_roles_audit_del; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_roles_audit_del AFTER DELETE ON studync.roles FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('role_id');


--
-- Name: roles trg_roles_audit_ins; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_roles_audit_ins AFTER INSERT ON studync.roles FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('role_id');


--
-- Name: roles trg_roles_audit_upd; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_roles_audit_upd AFTER UPDATE ON studync.roles FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION studync.fn_audit_row('role_id');


--
-- Name: student_answers trg_student_answers_audit_del; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_student_answers_audit_del AFTER DELETE ON studync.student_answers FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('answer_id');


--
-- Name: student_answers trg_student_answers_audit_ins; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_student_answers_audit_ins AFTER INSERT ON studync.student_answers FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('answer_id');


--
-- Name: student_answers trg_student_answers_audit_upd; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_student_answers_audit_upd AFTER UPDATE ON studync.student_answers FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION studync.fn_audit_row('answer_id');


--
-- Name: student_answers trg_student_answers_bi; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_student_answers_bi BEFORE INSERT ON studync.student_answers FOR EACH ROW EXECUTE FUNCTION studync.fn_trg_student_answers_bi();


--
-- Name: student_answers trg_student_answers_bu; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_student_answers_bu BEFORE UPDATE ON studync.student_answers FOR EACH ROW EXECUTE FUNCTION studync.fn_trg_reject_change('Student answers cannot be modified once submitted');


--
-- Name: students trg_students_audit_del; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_students_audit_del AFTER DELETE ON studync.students FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('student_id');


--
-- Name: students trg_students_audit_ins; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_students_audit_ins AFTER INSERT ON studync.students FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('student_id');


--
-- Name: students trg_students_audit_upd; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_students_audit_upd AFTER UPDATE ON studync.students FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION studync.fn_audit_row('student_id');


--
-- Name: subjects trg_subjects_audit_del; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_subjects_audit_del AFTER DELETE ON studync.subjects FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('subject_id');


--
-- Name: subjects trg_subjects_audit_ins; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_subjects_audit_ins AFTER INSERT ON studync.subjects FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('subject_id');


--
-- Name: subjects trg_subjects_audit_upd; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_subjects_audit_upd AFTER UPDATE ON studync.subjects FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION studync.fn_audit_row('subject_id');


--
-- Name: user_roles trg_user_roles_audit_del; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_user_roles_audit_del AFTER DELETE ON studync.user_roles FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('user_id', 'role_id');


--
-- Name: user_roles trg_user_roles_audit_ins; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_user_roles_audit_ins AFTER INSERT ON studync.user_roles FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('user_id', 'role_id');


--
-- Name: user_roles trg_user_roles_audit_upd; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_user_roles_audit_upd AFTER UPDATE ON studync.user_roles FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION studync.fn_audit_row('user_id', 'role_id');


--
-- Name: users trg_users_audit_del; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_users_audit_del AFTER DELETE ON studync.users FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('user_id');


--
-- Name: users trg_users_audit_ins; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_users_audit_ins AFTER INSERT ON studync.users FOR EACH ROW EXECUTE FUNCTION studync.fn_audit_row('user_id');


--
-- Name: users trg_users_audit_upd; Type: TRIGGER; Schema: studync; Owner: studync_owner
--

CREATE TRIGGER trg_users_audit_upd AFTER UPDATE ON studync.users FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION studync.fn_audit_row('user_id');


--
-- Name: admins fk_admins_user; Type: FK CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.admins
    ADD CONSTRAINT fk_admins_user FOREIGN KEY (user_id) REFERENCES studync.users(user_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: instructors fk_instructors_user; Type: FK CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.instructors
    ADD CONSTRAINT fk_instructors_user FOREIGN KEY (user_id) REFERENCES studync.users(user_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: materials fk_materials_instructor; Type: FK CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.materials
    ADD CONSTRAINT fk_materials_instructor FOREIGN KEY (instructor_id) REFERENCES studync.instructors(instructor_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: materials fk_materials_subject; Type: FK CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.materials
    ADD CONSTRAINT fk_materials_subject FOREIGN KEY (subject_id) REFERENCES studync.subjects(subject_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: questions fk_questions_quiz; Type: FK CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.questions
    ADD CONSTRAINT fk_questions_quiz FOREIGN KEY (quiz_id) REFERENCES studync.quizzes(quiz_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: quiz_results fk_quiz_results_quiz; Type: FK CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.quiz_results
    ADD CONSTRAINT fk_quiz_results_quiz FOREIGN KEY (quiz_id) REFERENCES studync.quizzes(quiz_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: quiz_results fk_quiz_results_student; Type: FK CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.quiz_results
    ADD CONSTRAINT fk_quiz_results_student FOREIGN KEY (student_id) REFERENCES studync.students(student_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: quizzes fk_quizzes_instructor; Type: FK CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.quizzes
    ADD CONSTRAINT fk_quizzes_instructor FOREIGN KEY (instructor_id) REFERENCES studync.instructors(instructor_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: quizzes fk_quizzes_subject; Type: FK CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.quizzes
    ADD CONSTRAINT fk_quizzes_subject FOREIGN KEY (subject_id) REFERENCES studync.subjects(subject_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: student_answers fk_student_answers_question; Type: FK CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.student_answers
    ADD CONSTRAINT fk_student_answers_question FOREIGN KEY (question_id) REFERENCES studync.questions(question_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: student_answers fk_student_answers_student; Type: FK CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.student_answers
    ADD CONSTRAINT fk_student_answers_student FOREIGN KEY (student_id) REFERENCES studync.students(student_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: students fk_students_user; Type: FK CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.students
    ADD CONSTRAINT fk_students_user FOREIGN KEY (user_id) REFERENCES studync.users(user_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: user_roles fk_user_roles_role; Type: FK CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.user_roles
    ADD CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id) REFERENCES studync.roles(role_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: user_roles fk_user_roles_user; Type: FK CONSTRAINT; Schema: studync; Owner: studync_owner
--

ALTER TABLE ONLY studync.user_roles
    ADD CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES studync.users(user_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


--
-- Name: SCHEMA studync; Type: ACL; Schema: -; Owner: studync_owner
--

GRANT USAGE ON SCHEMA studync TO studync_admin_role;
GRANT USAGE ON SCHEMA studync TO studync_instructor_role;
GRANT USAGE ON SCHEMA studync TO studync_student_role;
GRANT USAGE ON SCHEMA studync TO studync_dba_role;


--
-- Name: SCHEMA studync_test; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA studync_test TO "ana.santos";
GRANT USAGE ON SCHEMA studync_test TO "ben.torres";
GRANT USAGE ON SCHEMA studync_test TO "jose.cruz";
GRANT USAGE ON SCHEMA studync_test TO "maria.reyes";
GRANT USAGE ON SCHEMA studync_test TO studync_app_student;
GRANT USAGE ON SCHEMA studync_test TO studync_dba;


--
-- Name: FUNCTION fn_audit_row(); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_audit_row() FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_audit_row() TO studync_dba_role;


--
-- Name: FUNCTION fn_calculate_quiz_score(p_student_id character varying, p_quiz_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_calculate_quiz_score(p_student_id character varying, p_quiz_id character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_calculate_quiz_score(p_student_id character varying, p_quiz_id character varying) TO studync_dba_role;


--
-- Name: FUNCTION fn_get_answer_review(p_actor_user_id character varying, p_quiz_id character varying, p_student_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_get_answer_review(p_actor_user_id character varying, p_quiz_id character varying, p_student_id character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_get_answer_review(p_actor_user_id character varying, p_quiz_id character varying, p_student_id character varying) TO studync_admin_role;
GRANT ALL ON FUNCTION studync.fn_get_answer_review(p_actor_user_id character varying, p_quiz_id character varying, p_student_id character varying) TO studync_instructor_role;
GRANT ALL ON FUNCTION studync.fn_get_answer_review(p_actor_user_id character varying, p_quiz_id character varying, p_student_id character varying) TO studync_student_role;
GRANT ALL ON FUNCTION studync.fn_get_answer_review(p_actor_user_id character varying, p_quiz_id character varying, p_student_id character varying) TO studync_dba_role;


--
-- Name: FUNCTION fn_get_instructor_id(p_user_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_get_instructor_id(p_user_id character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_get_instructor_id(p_user_id character varying) TO studync_dba_role;


--
-- Name: TABLE instructors; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.instructors TO studync_dba_role;


--
-- Name: TABLE materials; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.materials TO studync_dba_role;


--
-- Name: TABLE subjects; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.subjects TO studync_dba_role;


--
-- Name: TABLE v_learning_materials; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT ON TABLE studync.v_learning_materials TO studync_admin_role;
GRANT SELECT ON TABLE studync.v_learning_materials TO studync_instructor_role;
GRANT SELECT ON TABLE studync.v_learning_materials TO studync_student_role;
GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.v_learning_materials TO studync_dba_role;


--
-- Name: FUNCTION fn_get_materials_by_subject(p_actor_user_id character varying, p_subject_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_get_materials_by_subject(p_actor_user_id character varying, p_subject_id character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_get_materials_by_subject(p_actor_user_id character varying, p_subject_id character varying) TO studync_admin_role;
GRANT ALL ON FUNCTION studync.fn_get_materials_by_subject(p_actor_user_id character varying, p_subject_id character varying) TO studync_instructor_role;
GRANT ALL ON FUNCTION studync.fn_get_materials_by_subject(p_actor_user_id character varying, p_subject_id character varying) TO studync_student_role;
GRANT ALL ON FUNCTION studync.fn_get_materials_by_subject(p_actor_user_id character varying, p_subject_id character varying) TO studync_dba_role;


--
-- Name: FUNCTION fn_get_quiz_questions(p_actor_user_id character varying, p_quiz_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_get_quiz_questions(p_actor_user_id character varying, p_quiz_id character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_get_quiz_questions(p_actor_user_id character varying, p_quiz_id character varying) TO studync_admin_role;
GRANT ALL ON FUNCTION studync.fn_get_quiz_questions(p_actor_user_id character varying, p_quiz_id character varying) TO studync_instructor_role;
GRANT ALL ON FUNCTION studync.fn_get_quiz_questions(p_actor_user_id character varying, p_quiz_id character varying) TO studync_student_role;
GRANT ALL ON FUNCTION studync.fn_get_quiz_questions(p_actor_user_id character varying, p_quiz_id character varying) TO studync_dba_role;


--
-- Name: FUNCTION fn_get_student_id(p_user_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_get_student_id(p_user_id character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_get_student_id(p_user_id character varying) TO studync_dba_role;


--
-- Name: TABLE questions; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.questions TO studync_dba_role;


--
-- Name: TABLE quiz_results; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.quiz_results TO studync_dba_role;


--
-- Name: TABLE quizzes; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.quizzes TO studync_dba_role;


--
-- Name: TABLE student_answers; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.student_answers TO studync_dba_role;


--
-- Name: TABLE students; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.students TO studync_dba_role;


--
-- Name: TABLE v_quiz_results_detail; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT ON TABLE studync.v_quiz_results_detail TO studync_admin_role;
GRANT SELECT ON TABLE studync.v_quiz_results_detail TO studync_instructor_role;
GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.v_quiz_results_detail TO studync_dba_role;


--
-- Name: FUNCTION fn_get_student_results(p_actor_user_id character varying, p_student_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_get_student_results(p_actor_user_id character varying, p_student_id character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_get_student_results(p_actor_user_id character varying, p_student_id character varying) TO studync_admin_role;
GRANT ALL ON FUNCTION studync.fn_get_student_results(p_actor_user_id character varying, p_student_id character varying) TO studync_instructor_role;
GRANT ALL ON FUNCTION studync.fn_get_student_results(p_actor_user_id character varying, p_student_id character varying) TO studync_student_role;
GRANT ALL ON FUNCTION studync.fn_get_student_results(p_actor_user_id character varying, p_student_id character varying) TO studync_dba_role;


--
-- Name: TABLE admins; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.admins TO studync_dba_role;


--
-- Name: TABLE roles; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT ON TABLE studync.roles TO studync_admin_role;
GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.roles TO studync_dba_role;


--
-- Name: TABLE user_roles; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.user_roles TO studync_dba_role;


--
-- Name: TABLE users; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.users TO studync_dba_role;


--
-- Name: TABLE v_user_directory; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT ON TABLE studync.v_user_directory TO studync_admin_role;
GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.v_user_directory TO studync_dba_role;


--
-- Name: FUNCTION fn_get_user(p_actor_user_id character varying, p_user_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_get_user(p_actor_user_id character varying, p_user_id character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_get_user(p_actor_user_id character varying, p_user_id character varying) TO studync_admin_role;
GRANT ALL ON FUNCTION studync.fn_get_user(p_actor_user_id character varying, p_user_id character varying) TO studync_instructor_role;
GRANT ALL ON FUNCTION studync.fn_get_user(p_actor_user_id character varying, p_user_id character varying) TO studync_student_role;
GRANT ALL ON FUNCTION studync.fn_get_user(p_actor_user_id character varying, p_user_id character varying) TO studync_dba_role;


--
-- Name: FUNCTION fn_hash_password(p_plain character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_hash_password(p_plain character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_hash_password(p_plain character varying) TO studync_dba_role;


--
-- Name: FUNCTION fn_is_safe_file_path(p_path character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_is_safe_file_path(p_path character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_is_safe_file_path(p_path character varying) TO studync_dba_role;


--
-- Name: FUNCTION fn_is_strong_password(p_plain character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_is_strong_password(p_plain character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_is_strong_password(p_plain character varying) TO studync_dba_role;


--
-- Name: FUNCTION fn_question_count(p_quiz_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_question_count(p_quiz_id character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_question_count(p_quiz_id character varying) TO studync_dba_role;


--
-- Name: TABLE audit_logs; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,INSERT,REFERENCES ON TABLE studync.audit_logs TO studync_dba_role;


--
-- Name: TABLE v_audit_trail; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT ON TABLE studync.v_audit_trail TO studync_admin_role;
GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.v_audit_trail TO studync_dba_role;


--
-- Name: FUNCTION fn_report_audit_logs(p_actor_user_id character varying, p_table_name character varying, p_action_type character varying, p_from timestamp with time zone, p_to timestamp with time zone, p_limit integer); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_report_audit_logs(p_actor_user_id character varying, p_table_name character varying, p_action_type character varying, p_from timestamp with time zone, p_to timestamp with time zone, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_report_audit_logs(p_actor_user_id character varying, p_table_name character varying, p_action_type character varying, p_from timestamp with time zone, p_to timestamp with time zone, p_limit integer) TO studync_admin_role;
GRANT ALL ON FUNCTION studync.fn_report_audit_logs(p_actor_user_id character varying, p_table_name character varying, p_action_type character varying, p_from timestamp with time zone, p_to timestamp with time zone, p_limit integer) TO studync_dba_role;


--
-- Name: FUNCTION fn_report_quiz_results(p_actor_user_id character varying, p_quiz_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_report_quiz_results(p_actor_user_id character varying, p_quiz_id character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_report_quiz_results(p_actor_user_id character varying, p_quiz_id character varying) TO studync_admin_role;
GRANT ALL ON FUNCTION studync.fn_report_quiz_results(p_actor_user_id character varying, p_quiz_id character varying) TO studync_instructor_role;
GRANT ALL ON FUNCTION studync.fn_report_quiz_results(p_actor_user_id character varying, p_quiz_id character varying) TO studync_dba_role;


--
-- Name: FUNCTION fn_report_quiz_summary(p_actor_user_id character varying, p_quiz_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_report_quiz_summary(p_actor_user_id character varying, p_quiz_id character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_report_quiz_summary(p_actor_user_id character varying, p_quiz_id character varying) TO studync_admin_role;
GRANT ALL ON FUNCTION studync.fn_report_quiz_summary(p_actor_user_id character varying, p_quiz_id character varying) TO studync_instructor_role;
GRANT ALL ON FUNCTION studync.fn_report_quiz_summary(p_actor_user_id character varying, p_quiz_id character varying) TO studync_dba_role;


--
-- Name: FUNCTION fn_report_student_performance(p_actor_user_id character varying, p_subject_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_report_student_performance(p_actor_user_id character varying, p_subject_id character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_report_student_performance(p_actor_user_id character varying, p_subject_id character varying) TO studync_admin_role;
GRANT ALL ON FUNCTION studync.fn_report_student_performance(p_actor_user_id character varying, p_subject_id character varying) TO studync_instructor_role;
GRANT ALL ON FUNCTION studync.fn_report_student_performance(p_actor_user_id character varying, p_subject_id character varying) TO studync_dba_role;


--
-- Name: FUNCTION fn_report_system_activity(p_actor_user_id character varying, p_days integer); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_report_system_activity(p_actor_user_id character varying, p_days integer) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_report_system_activity(p_actor_user_id character varying, p_days integer) TO studync_admin_role;
GRANT ALL ON FUNCTION studync.fn_report_system_activity(p_actor_user_id character varying, p_days integer) TO studync_dba_role;


--
-- Name: FUNCTION fn_resolve_option(p_input character varying, p_a character varying, p_b character varying, p_c character varying, p_d character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_resolve_option(p_input character varying, p_a character varying, p_b character varying, p_c character varying, p_d character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_resolve_option(p_input character varying, p_a character varying, p_b character varying, p_c character varying, p_d character varying) TO studync_dba_role;


--
-- Name: FUNCTION fn_trg_quiz_results_score(); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_trg_quiz_results_score() FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_trg_quiz_results_score() TO studync_dba_role;


--
-- Name: FUNCTION fn_trg_reject_change(); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_trg_reject_change() FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_trg_reject_change() TO studync_dba_role;


--
-- Name: FUNCTION fn_trg_student_answers_bi(); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_trg_student_answers_bi() FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_trg_student_answers_bi() TO studync_dba_role;


--
-- Name: FUNCTION fn_user_has_role(p_user_id character varying, p_role_name character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_user_has_role(p_user_id character varying, p_role_name character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_user_has_role(p_user_id character varying, p_role_name character varying) TO studync_dba_role;


--
-- Name: FUNCTION fn_verify_password(p_plain character varying, p_stored character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON FUNCTION studync.fn_verify_password(p_plain character varying, p_stored character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION studync.fn_verify_password(p_plain character varying, p_stored character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_add_question(IN p_actor_user_id character varying, IN p_quiz_id character varying, IN p_question_text text, IN p_option_a character varying, IN p_option_b character varying, IN p_option_c character varying, IN p_option_d character varying, IN p_correct_answer character varying, OUT p_question_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_add_question(IN p_actor_user_id character varying, IN p_quiz_id character varying, IN p_question_text text, IN p_option_a character varying, IN p_option_b character varying, IN p_option_c character varying, IN p_option_d character varying, IN p_correct_answer character varying, OUT p_question_id character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_add_question(IN p_actor_user_id character varying, IN p_quiz_id character varying, IN p_question_text text, IN p_option_a character varying, IN p_option_b character varying, IN p_option_c character varying, IN p_option_d character varying, IN p_correct_answer character varying, OUT p_question_id character varying) TO studync_instructor_role;
GRANT ALL ON PROCEDURE studync.sp_add_question(IN p_actor_user_id character varying, IN p_quiz_id character varying, IN p_question_text text, IN p_option_a character varying, IN p_option_b character varying, IN p_option_c character varying, IN p_option_d character varying, IN p_correct_answer character varying, OUT p_question_id character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_assert_quiz_owner(IN p_actor_user_id character varying, IN p_quiz_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_assert_quiz_owner(IN p_actor_user_id character varying, IN p_quiz_id character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_assert_quiz_owner(IN p_actor_user_id character varying, IN p_quiz_id character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_assign_role(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_role_name character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_assign_role(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_role_name character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_assign_role(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_role_name character varying) TO studync_admin_role;
GRANT ALL ON PROCEDURE studync.sp_assign_role(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_role_name character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_authenticate_user(IN p_username character varying, IN p_password character varying, OUT p_success boolean, OUT p_user_id character varying, OUT p_roles character varying, OUT p_message character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_authenticate_user(IN p_username character varying, IN p_password character varying, OUT p_success boolean, OUT p_user_id character varying, OUT p_roles character varying, OUT p_message character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_authenticate_user(IN p_username character varying, IN p_password character varying, OUT p_success boolean, OUT p_user_id character varying, OUT p_roles character varying, OUT p_message character varying) TO studync_admin_role;
GRANT ALL ON PROCEDURE studync.sp_authenticate_user(IN p_username character varying, IN p_password character varying, OUT p_success boolean, OUT p_user_id character varying, OUT p_roles character varying, OUT p_message character varying) TO studync_instructor_role;
GRANT ALL ON PROCEDURE studync.sp_authenticate_user(IN p_username character varying, IN p_password character varying, OUT p_success boolean, OUT p_user_id character varying, OUT p_roles character varying, OUT p_message character varying) TO studync_student_role;
GRANT ALL ON PROCEDURE studync.sp_authenticate_user(IN p_username character varying, IN p_password character varying, OUT p_success boolean, OUT p_user_id character varying, OUT p_roles character varying, OUT p_message character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_change_password(IN p_actor_user_id character varying, IN p_old_password character varying, IN p_new_password character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_change_password(IN p_actor_user_id character varying, IN p_old_password character varying, IN p_new_password character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_change_password(IN p_actor_user_id character varying, IN p_old_password character varying, IN p_new_password character varying) TO studync_admin_role;
GRANT ALL ON PROCEDURE studync.sp_change_password(IN p_actor_user_id character varying, IN p_old_password character varying, IN p_new_password character varying) TO studync_instructor_role;
GRANT ALL ON PROCEDURE studync.sp_change_password(IN p_actor_user_id character varying, IN p_old_password character varying, IN p_new_password character varying) TO studync_student_role;
GRANT ALL ON PROCEDURE studync.sp_change_password(IN p_actor_user_id character varying, IN p_old_password character varying, IN p_new_password character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_clear_actor(); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_clear_actor() FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_clear_actor() TO studync_dba_role;


--
-- Name: PROCEDURE sp_create_profile(IN p_user_id character varying, IN p_role_name character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_profile_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_create_profile(IN p_user_id character varying, IN p_role_name character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_profile_id character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_create_profile(IN p_user_id character varying, IN p_role_name character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_profile_id character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_create_quiz(IN p_actor_user_id character varying, IN p_subject_id character varying, IN p_title character varying, OUT p_quiz_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_create_quiz(IN p_actor_user_id character varying, IN p_subject_id character varying, IN p_title character varying, OUT p_quiz_id character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_create_quiz(IN p_actor_user_id character varying, IN p_subject_id character varying, IN p_title character varying, OUT p_quiz_id character varying) TO studync_instructor_role;
GRANT ALL ON PROCEDURE studync.sp_create_quiz(IN p_actor_user_id character varying, IN p_subject_id character varying, IN p_title character varying, OUT p_quiz_id character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_create_subject(IN p_actor_user_id character varying, IN p_subject_name character varying, IN p_description text, OUT p_subject_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_create_subject(IN p_actor_user_id character varying, IN p_subject_name character varying, IN p_description text, OUT p_subject_id character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_create_subject(IN p_actor_user_id character varying, IN p_subject_name character varying, IN p_description text, OUT p_subject_id character varying) TO studync_admin_role;
GRANT ALL ON PROCEDURE studync.sp_create_subject(IN p_actor_user_id character varying, IN p_subject_name character varying, IN p_description text, OUT p_subject_id character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_delete_material(IN p_actor_user_id character varying, IN p_material_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_delete_material(IN p_actor_user_id character varying, IN p_material_id character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_delete_material(IN p_actor_user_id character varying, IN p_material_id character varying) TO studync_instructor_role;
GRANT ALL ON PROCEDURE studync.sp_delete_material(IN p_actor_user_id character varying, IN p_material_id character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_delete_question(IN p_actor_user_id character varying, IN p_question_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_delete_question(IN p_actor_user_id character varying, IN p_question_id character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_delete_question(IN p_actor_user_id character varying, IN p_question_id character varying) TO studync_instructor_role;
GRANT ALL ON PROCEDURE studync.sp_delete_question(IN p_actor_user_id character varying, IN p_question_id character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_delete_quiz(IN p_actor_user_id character varying, IN p_quiz_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_delete_quiz(IN p_actor_user_id character varying, IN p_quiz_id character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_delete_quiz(IN p_actor_user_id character varying, IN p_quiz_id character varying) TO studync_instructor_role;
GRANT ALL ON PROCEDURE studync.sp_delete_quiz(IN p_actor_user_id character varying, IN p_quiz_id character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_delete_subject(IN p_actor_user_id character varying, IN p_subject_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_delete_subject(IN p_actor_user_id character varying, IN p_subject_id character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_delete_subject(IN p_actor_user_id character varying, IN p_subject_id character varying) TO studync_admin_role;
GRANT ALL ON PROCEDURE studync.sp_delete_subject(IN p_actor_user_id character varying, IN p_subject_id character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_register_instructor(IN p_actor_user_id character varying, IN p_username character varying, IN p_email character varying, IN p_password character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_user_id character varying, OUT p_instructor_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_register_instructor(IN p_actor_user_id character varying, IN p_username character varying, IN p_email character varying, IN p_password character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_user_id character varying, OUT p_instructor_id character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_register_instructor(IN p_actor_user_id character varying, IN p_username character varying, IN p_email character varying, IN p_password character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_user_id character varying, OUT p_instructor_id character varying) TO studync_admin_role;
GRANT ALL ON PROCEDURE studync.sp_register_instructor(IN p_actor_user_id character varying, IN p_username character varying, IN p_email character varying, IN p_password character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_user_id character varying, OUT p_instructor_id character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_register_student(IN p_actor_user_id character varying, IN p_username character varying, IN p_email character varying, IN p_password character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_user_id character varying, OUT p_student_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_register_student(IN p_actor_user_id character varying, IN p_username character varying, IN p_email character varying, IN p_password character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_user_id character varying, OUT p_student_id character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_register_student(IN p_actor_user_id character varying, IN p_username character varying, IN p_email character varying, IN p_password character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_user_id character varying, OUT p_student_id character varying) TO studync_admin_role;
GRANT ALL ON PROCEDURE studync.sp_register_student(IN p_actor_user_id character varying, IN p_username character varying, IN p_email character varying, IN p_password character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_user_id character varying, OUT p_student_id character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_register_user(IN p_role_name character varying, IN p_username character varying, IN p_email character varying, IN p_password character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_user_id character varying, OUT p_profile_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_register_user(IN p_role_name character varying, IN p_username character varying, IN p_email character varying, IN p_password character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_user_id character varying, OUT p_profile_id character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_register_user(IN p_role_name character varying, IN p_username character varying, IN p_email character varying, IN p_password character varying, IN p_first_name character varying, IN p_last_name character varying, OUT p_user_id character varying, OUT p_profile_id character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_revoke_role(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_role_name character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_revoke_role(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_role_name character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_revoke_role(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_role_name character varying) TO studync_admin_role;
GRANT ALL ON PROCEDURE studync.sp_revoke_role(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_role_name character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_set_actor(IN p_actor_user_id character varying, IN p_allowed_roles text); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_set_actor(IN p_actor_user_id character varying, IN p_allowed_roles text) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_set_actor(IN p_actor_user_id character varying, IN p_allowed_roles text) TO studync_dba_role;


--
-- Name: PROCEDURE sp_set_user_status(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_status character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_set_user_status(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_status character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_set_user_status(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_status character varying) TO studync_admin_role;
GRANT ALL ON PROCEDURE studync.sp_set_user_status(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_status character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_submit_answer(IN p_actor_user_id character varying, IN p_question_id character varying, IN p_answer character varying, OUT p_answer_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_submit_answer(IN p_actor_user_id character varying, IN p_question_id character varying, IN p_answer character varying, OUT p_answer_id character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_submit_answer(IN p_actor_user_id character varying, IN p_question_id character varying, IN p_answer character varying, OUT p_answer_id character varying) TO studync_student_role;
GRANT ALL ON PROCEDURE studync.sp_submit_answer(IN p_actor_user_id character varying, IN p_question_id character varying, IN p_answer character varying, OUT p_answer_id character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_submit_quiz(IN p_actor_user_id character varying, IN p_quiz_id character varying, OUT p_result_id character varying, OUT p_score numeric); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_submit_quiz(IN p_actor_user_id character varying, IN p_quiz_id character varying, OUT p_result_id character varying, OUT p_score numeric) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_submit_quiz(IN p_actor_user_id character varying, IN p_quiz_id character varying, OUT p_result_id character varying, OUT p_score numeric) TO studync_student_role;
GRANT ALL ON PROCEDURE studync.sp_submit_quiz(IN p_actor_user_id character varying, IN p_quiz_id character varying, OUT p_result_id character varying, OUT p_score numeric) TO studync_dba_role;


--
-- Name: PROCEDURE sp_update_material(IN p_actor_user_id character varying, IN p_material_id character varying, IN p_subject_id character varying, IN p_title character varying, IN p_file_path character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_update_material(IN p_actor_user_id character varying, IN p_material_id character varying, IN p_subject_id character varying, IN p_title character varying, IN p_file_path character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_update_material(IN p_actor_user_id character varying, IN p_material_id character varying, IN p_subject_id character varying, IN p_title character varying, IN p_file_path character varying) TO studync_instructor_role;
GRANT ALL ON PROCEDURE studync.sp_update_material(IN p_actor_user_id character varying, IN p_material_id character varying, IN p_subject_id character varying, IN p_title character varying, IN p_file_path character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_update_question(IN p_actor_user_id character varying, IN p_question_id character varying, IN p_question_text text, IN p_option_a character varying, IN p_option_b character varying, IN p_option_c character varying, IN p_option_d character varying, IN p_correct_answer character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_update_question(IN p_actor_user_id character varying, IN p_question_id character varying, IN p_question_text text, IN p_option_a character varying, IN p_option_b character varying, IN p_option_c character varying, IN p_option_d character varying, IN p_correct_answer character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_update_question(IN p_actor_user_id character varying, IN p_question_id character varying, IN p_question_text text, IN p_option_a character varying, IN p_option_b character varying, IN p_option_c character varying, IN p_option_d character varying, IN p_correct_answer character varying) TO studync_instructor_role;
GRANT ALL ON PROCEDURE studync.sp_update_question(IN p_actor_user_id character varying, IN p_question_id character varying, IN p_question_text text, IN p_option_a character varying, IN p_option_b character varying, IN p_option_c character varying, IN p_option_d character varying, IN p_correct_answer character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_update_quiz(IN p_actor_user_id character varying, IN p_quiz_id character varying, IN p_subject_id character varying, IN p_title character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_update_quiz(IN p_actor_user_id character varying, IN p_quiz_id character varying, IN p_subject_id character varying, IN p_title character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_update_quiz(IN p_actor_user_id character varying, IN p_quiz_id character varying, IN p_subject_id character varying, IN p_title character varying) TO studync_instructor_role;
GRANT ALL ON PROCEDURE studync.sp_update_quiz(IN p_actor_user_id character varying, IN p_quiz_id character varying, IN p_subject_id character varying, IN p_title character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_update_subject(IN p_actor_user_id character varying, IN p_subject_id character varying, IN p_subject_name character varying, IN p_description text); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_update_subject(IN p_actor_user_id character varying, IN p_subject_id character varying, IN p_subject_name character varying, IN p_description text) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_update_subject(IN p_actor_user_id character varying, IN p_subject_id character varying, IN p_subject_name character varying, IN p_description text) TO studync_admin_role;
GRANT ALL ON PROCEDURE studync.sp_update_subject(IN p_actor_user_id character varying, IN p_subject_id character varying, IN p_subject_name character varying, IN p_description text) TO studync_dba_role;


--
-- Name: PROCEDURE sp_update_user(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_email character varying, IN p_first_name character varying, IN p_last_name character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_update_user(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_email character varying, IN p_first_name character varying, IN p_last_name character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_update_user(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_email character varying, IN p_first_name character varying, IN p_last_name character varying) TO studync_admin_role;
GRANT ALL ON PROCEDURE studync.sp_update_user(IN p_actor_user_id character varying, IN p_user_id character varying, IN p_email character varying, IN p_first_name character varying, IN p_last_name character varying) TO studync_dba_role;


--
-- Name: PROCEDURE sp_upload_material(IN p_actor_user_id character varying, IN p_subject_id character varying, IN p_title character varying, IN p_file_path character varying, OUT p_material_id character varying); Type: ACL; Schema: studync; Owner: studync_owner
--

REVOKE ALL ON PROCEDURE studync.sp_upload_material(IN p_actor_user_id character varying, IN p_subject_id character varying, IN p_title character varying, IN p_file_path character varying, OUT p_material_id character varying) FROM PUBLIC;
GRANT ALL ON PROCEDURE studync.sp_upload_material(IN p_actor_user_id character varying, IN p_subject_id character varying, IN p_title character varying, IN p_file_path character varying, OUT p_material_id character varying) TO studync_instructor_role;
GRANT ALL ON PROCEDURE studync.sp_upload_material(IN p_actor_user_id character varying, IN p_subject_id character varying, IN p_title character varying, IN p_file_path character varying, OUT p_material_id character varying) TO studync_dba_role;


--
-- Name: FUNCTION tst_check_true(p_id text, p_desc text, p_condition boolean, p_detail text); Type: ACL; Schema: studync_test; Owner: postgres
--

GRANT ALL ON FUNCTION studync_test.tst_check_true(p_id text, p_desc text, p_condition boolean, p_detail text) TO "ana.santos";
GRANT ALL ON FUNCTION studync_test.tst_check_true(p_id text, p_desc text, p_condition boolean, p_detail text) TO "ben.torres";
GRANT ALL ON FUNCTION studync_test.tst_check_true(p_id text, p_desc text, p_condition boolean, p_detail text) TO "jose.cruz";
GRANT ALL ON FUNCTION studync_test.tst_check_true(p_id text, p_desc text, p_condition boolean, p_detail text) TO "maria.reyes";
GRANT ALL ON FUNCTION studync_test.tst_check_true(p_id text, p_desc text, p_condition boolean, p_detail text) TO studync_app_student;
GRANT ALL ON FUNCTION studync_test.tst_check_true(p_id text, p_desc text, p_condition boolean, p_detail text) TO studync_dba;


--
-- Name: FUNCTION tst_expect_error(p_id text, p_desc text, p_sql text, p_expected text); Type: ACL; Schema: studync_test; Owner: postgres
--

GRANT ALL ON FUNCTION studync_test.tst_expect_error(p_id text, p_desc text, p_sql text, p_expected text) TO "ana.santos";
GRANT ALL ON FUNCTION studync_test.tst_expect_error(p_id text, p_desc text, p_sql text, p_expected text) TO "ben.torres";
GRANT ALL ON FUNCTION studync_test.tst_expect_error(p_id text, p_desc text, p_sql text, p_expected text) TO "jose.cruz";
GRANT ALL ON FUNCTION studync_test.tst_expect_error(p_id text, p_desc text, p_sql text, p_expected text) TO "maria.reyes";
GRANT ALL ON FUNCTION studync_test.tst_expect_error(p_id text, p_desc text, p_sql text, p_expected text) TO studync_app_student;
GRANT ALL ON FUNCTION studync_test.tst_expect_error(p_id text, p_desc text, p_sql text, p_expected text) TO studync_dba;


--
-- Name: FUNCTION tst_expect_ok(p_id text, p_desc text, p_sql text); Type: ACL; Schema: studync_test; Owner: postgres
--

GRANT ALL ON FUNCTION studync_test.tst_expect_ok(p_id text, p_desc text, p_sql text) TO "ana.santos";
GRANT ALL ON FUNCTION studync_test.tst_expect_ok(p_id text, p_desc text, p_sql text) TO "ben.torres";
GRANT ALL ON FUNCTION studync_test.tst_expect_ok(p_id text, p_desc text, p_sql text) TO "jose.cruz";
GRANT ALL ON FUNCTION studync_test.tst_expect_ok(p_id text, p_desc text, p_sql text) TO "maria.reyes";
GRANT ALL ON FUNCTION studync_test.tst_expect_ok(p_id text, p_desc text, p_sql text) TO studync_app_student;
GRANT ALL ON FUNCTION studync_test.tst_expect_ok(p_id text, p_desc text, p_sql text) TO studync_dba;


--
-- Name: SEQUENCE audit_logs_log_id_seq; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,USAGE ON SEQUENCE studync.audit_logs_log_id_seq TO studync_dba_role;


--
-- Name: SEQUENCE seq_admins; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,USAGE ON SEQUENCE studync.seq_admins TO studync_dba_role;


--
-- Name: SEQUENCE seq_instructors; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,USAGE ON SEQUENCE studync.seq_instructors TO studync_dba_role;


--
-- Name: SEQUENCE seq_materials; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,USAGE ON SEQUENCE studync.seq_materials TO studync_dba_role;


--
-- Name: SEQUENCE seq_questions; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,USAGE ON SEQUENCE studync.seq_questions TO studync_dba_role;


--
-- Name: SEQUENCE seq_quiz_results; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,USAGE ON SEQUENCE studync.seq_quiz_results TO studync_dba_role;


--
-- Name: SEQUENCE seq_quizzes; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,USAGE ON SEQUENCE studync.seq_quizzes TO studync_dba_role;


--
-- Name: SEQUENCE seq_student_answers; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,USAGE ON SEQUENCE studync.seq_student_answers TO studync_dba_role;


--
-- Name: SEQUENCE seq_students; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,USAGE ON SEQUENCE studync.seq_students TO studync_dba_role;


--
-- Name: SEQUENCE seq_subjects; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,USAGE ON SEQUENCE studync.seq_subjects TO studync_dba_role;


--
-- Name: SEQUENCE seq_users; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT,USAGE ON SEQUENCE studync.seq_users TO studync_dba_role;


--
-- Name: TABLE v_my_results; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT ON TABLE studync.v_my_results TO studync_student_role;
GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.v_my_results TO studync_dba_role;


--
-- Name: TABLE v_quiz_overview; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT ON TABLE studync.v_quiz_overview TO studync_admin_role;
GRANT SELECT ON TABLE studync.v_quiz_overview TO studync_instructor_role;
GRANT SELECT ON TABLE studync.v_quiz_overview TO studync_student_role;
GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.v_quiz_overview TO studync_dba_role;


--
-- Name: TABLE v_quiz_questions_instructor; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT ON TABLE studync.v_quiz_questions_instructor TO studync_instructor_role;
GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.v_quiz_questions_instructor TO studync_dba_role;


--
-- Name: TABLE v_quiz_questions_student; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT ON TABLE studync.v_quiz_questions_student TO studync_student_role;
GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.v_quiz_questions_student TO studync_dba_role;


--
-- Name: TABLE v_student_performance; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT ON TABLE studync.v_student_performance TO studync_admin_role;
GRANT SELECT ON TABLE studync.v_student_performance TO studync_instructor_role;
GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.v_student_performance TO studync_dba_role;


--
-- Name: TABLE v_subject_catalog; Type: ACL; Schema: studync; Owner: studync_owner
--

GRANT SELECT ON TABLE studync.v_subject_catalog TO studync_admin_role;
GRANT SELECT ON TABLE studync.v_subject_catalog TO studync_instructor_role;
GRANT SELECT ON TABLE studync.v_subject_catalog TO studync_student_role;
GRANT SELECT,INSERT,REFERENCES,DELETE,UPDATE ON TABLE studync.v_subject_catalog TO studync_dba_role;


--
-- Name: TABLE results; Type: ACL; Schema: studync_test; Owner: postgres
--

GRANT INSERT ON TABLE studync_test.results TO "ana.santos";
GRANT INSERT ON TABLE studync_test.results TO "ben.torres";
GRANT INSERT ON TABLE studync_test.results TO "jose.cruz";
GRANT INSERT ON TABLE studync_test.results TO "maria.reyes";
GRANT INSERT ON TABLE studync_test.results TO studync_app_student;
GRANT INSERT ON TABLE studync_test.results TO studync_dba;


--
-- PostgreSQL database dump complete
--

\unrestrict eZBKeuGl9teUZNj9aHgQ1Qi1Vmz5aBorioita6gjin643wqJXzn9QncAFt5IDr4

