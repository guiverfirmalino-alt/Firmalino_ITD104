-- =============================================================================
-- StudyNC LMS (PostgreSQL 16+)
-- File 02 : Schema, extension, types, sequences and tables
-- Run as  : superuser connected to studync_db
-- -----------------------------------------------------------------------------
-- The 13 tables are exactly the 13 ERD entities. PK / NOT NULL / DEFAULT are
-- declared here; UNIQUE, CHECK, FK and indexes are in file 03.
--
-- PostgreSQL-specific choices (vs. the MySQL version)
--   * Dedicated schema "studync" (public schema is not used).
--   * users.status uses a real ENUM type (studync.user_status).
--   * Formatted ids (USR0000001 ...) come from SEQUENCES in column DEFAULTs,
--     so INSERT ... RETURNING gives the new id without MAX()+1 locking.
--   * audit_logs.old_data / new_data are JSONB; log_id is an IDENTITY column.
--   * Timestamps are TIMESTAMPTZ (time-zone aware).
--   * Passwords are hashed with bcrypt through the pgcrypto extension.
-- Documented deviations from the ERD are the same as in MySQL (README).
-- =============================================================================
SET ROLE studync_owner;                 -- every object is owned by studync_owner

CREATE SCHEMA studync AUTHORIZATION studync_owner;
COMMENT ON SCHEMA studync IS 'StudyNC LMS objects';
SET search_path = studync, pg_temp;

-- pgcrypto is a "trusted" extension (PG13+): the database owner may install it.
-- It lives in its own schema so that the REVOKE ... FROM PUBLIC on the studync
-- schema (file 08) does not affect the extension's functions.
CREATE SCHEMA extensions AUTHORIZATION studync_owner;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- -----------------------------------------------------------------------------
-- Types and sequences
-- -----------------------------------------------------------------------------
CREATE TYPE studync.user_status AS ENUM ('Active', 'Inactive');

CREATE SEQUENCE studync.seq_users           MAXVALUE 9999999;
CREATE SEQUENCE studync.seq_admins          MAXVALUE 9999999;
CREATE SEQUENCE studync.seq_instructors     MAXVALUE 9999999;
CREATE SEQUENCE studync.seq_students        MAXVALUE 9999999;
CREATE SEQUENCE studync.seq_subjects        MAXVALUE 9999999;
CREATE SEQUENCE studync.seq_materials       MAXVALUE 9999999;
CREATE SEQUENCE studync.seq_quizzes         MAXVALUE 9999999;
CREATE SEQUENCE studync.seq_questions       MAXVALUE 9999999;
CREATE SEQUENCE studync.seq_student_answers MAXVALUE 9999999;
CREATE SEQUENCE studync.seq_quiz_results    MAXVALUE 9999999;

-- -----------------------------------------------------------------------------
-- D1 users
-- -----------------------------------------------------------------------------
CREATE TABLE studync.users (
    user_id        VARCHAR(10)  NOT NULL DEFAULT 'USR' || lpad(nextval('studync.seq_users')::text, 7, '0'),
    username       VARCHAR(50)  NOT NULL,
    email          VARCHAR(100) NOT NULL,
    password_hash  VARCHAR(255) NOT NULL,
    status         studync.user_status NOT NULL DEFAULT 'Active',
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_users PRIMARY KEY (user_id)
);
COMMENT ON COLUMN studync.users.password_hash IS 'bcrypt hash (pgcrypto crypt/gen_salt bf) - never plain text';
ALTER SEQUENCE studync.seq_users OWNED BY studync.users.user_id;

-- -----------------------------------------------------------------------------
-- D2 roles  +  user_roles
-- -----------------------------------------------------------------------------
CREATE TABLE studync.roles (
    role_id    VARCHAR(10) NOT NULL,
    role_name  VARCHAR(50) NOT NULL,
    CONSTRAINT pk_roles PRIMARY KEY (role_id)
);

CREATE TABLE studync.user_roles (
    user_id  VARCHAR(10) NOT NULL,
    role_id  VARCHAR(10) NOT NULL,
    CONSTRAINT pk_user_roles PRIMARY KEY (user_id, role_id)
);

-- -----------------------------------------------------------------------------
-- Profiles (1:1 with users)
-- -----------------------------------------------------------------------------
CREATE TABLE studync.admins (
    admin_id    VARCHAR(10) NOT NULL DEFAULT 'ADM' || lpad(nextval('studync.seq_admins')::text, 7, '0'),
    user_id     VARCHAR(10) NOT NULL,
    first_name  VARCHAR(50) NOT NULL,
    last_name   VARCHAR(50) NOT NULL,
    CONSTRAINT pk_admins PRIMARY KEY (admin_id)
);
ALTER SEQUENCE studync.seq_admins OWNED BY studync.admins.admin_id;

CREATE TABLE studync.instructors (
    instructor_id  VARCHAR(10) NOT NULL DEFAULT 'INS' || lpad(nextval('studync.seq_instructors')::text, 7, '0'),
    user_id        VARCHAR(10) NOT NULL,
    first_name     VARCHAR(50) NOT NULL,
    last_name      VARCHAR(50) NOT NULL,
    CONSTRAINT pk_instructors PRIMARY KEY (instructor_id)
);
ALTER SEQUENCE studync.seq_instructors OWNED BY studync.instructors.instructor_id;

CREATE TABLE studync.students (
    student_id  VARCHAR(10) NOT NULL DEFAULT 'STU' || lpad(nextval('studync.seq_students')::text, 7, '0'),
    user_id     VARCHAR(10) NOT NULL,
    first_name  VARCHAR(50) NOT NULL,
    last_name   VARCHAR(50) NOT NULL,
    CONSTRAINT pk_students PRIMARY KEY (student_id)
);
ALTER SEQUENCE studync.seq_students OWNED BY studync.students.student_id;

-- -----------------------------------------------------------------------------
-- D3 subjects
-- -----------------------------------------------------------------------------
CREATE TABLE studync.subjects (
    subject_id    VARCHAR(10)  NOT NULL DEFAULT 'SUB' || lpad(nextval('studync.seq_subjects')::text, 7, '0'),
    subject_name  VARCHAR(100) NOT NULL,
    description   TEXT         NULL,
    CONSTRAINT pk_subjects PRIMARY KEY (subject_id)
);
ALTER SEQUENCE studync.seq_subjects OWNED BY studync.subjects.subject_id;

-- -----------------------------------------------------------------------------
-- D4 materials
-- -----------------------------------------------------------------------------
CREATE TABLE studync.materials (
    material_id    VARCHAR(10)  NOT NULL DEFAULT 'MAT' || lpad(nextval('studync.seq_materials')::text, 7, '0'),
    subject_id     VARCHAR(10)  NOT NULL,
    instructor_id  VARCHAR(10)  NOT NULL,
    title          VARCHAR(255) NOT NULL,
    file_path      VARCHAR(255) NOT NULL,
    uploaded_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_materials PRIMARY KEY (material_id)
);
ALTER SEQUENCE studync.seq_materials OWNED BY studync.materials.material_id;

-- -----------------------------------------------------------------------------
-- D5 quizzes
-- -----------------------------------------------------------------------------
CREATE TABLE studync.quizzes (
    quiz_id        VARCHAR(10)  NOT NULL DEFAULT 'QUZ' || lpad(nextval('studync.seq_quizzes')::text, 7, '0'),
    subject_id     VARCHAR(10)  NOT NULL,
    instructor_id  VARCHAR(10)  NOT NULL,
    title          VARCHAR(255) NOT NULL,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_quizzes PRIMARY KEY (quiz_id)
);
ALTER SEQUENCE studync.seq_quizzes OWNED BY studync.quizzes.quiz_id;

-- -----------------------------------------------------------------------------
-- D6 questions (correct_answer = text of the correct option)
-- -----------------------------------------------------------------------------
CREATE TABLE studync.questions (
    question_id     VARCHAR(10)  NOT NULL DEFAULT 'QST' || lpad(nextval('studync.seq_questions')::text, 7, '0'),
    quiz_id         VARCHAR(10)  NOT NULL,
    question_text   TEXT         NOT NULL,
    correct_answer  VARCHAR(255) NOT NULL,
    option_a        VARCHAR(255) NOT NULL,
    option_b        VARCHAR(255) NOT NULL,
    option_c        VARCHAR(255) NOT NULL,
    option_d        VARCHAR(255) NOT NULL,
    CONSTRAINT pk_questions PRIMARY KEY (question_id)
);
ALTER SEQUENCE studync.seq_questions OWNED BY studync.questions.question_id;

-- -----------------------------------------------------------------------------
-- D7 student_answers (is_correct computed by trigger)
-- -----------------------------------------------------------------------------
CREATE TABLE studync.student_answers (
    answer_id       VARCHAR(10)  NOT NULL DEFAULT 'ANS' || lpad(nextval('studync.seq_student_answers')::text, 7, '0'),
    student_id      VARCHAR(10)  NOT NULL,
    question_id     VARCHAR(10)  NOT NULL,
    student_answer  VARCHAR(255) NULL,
    is_correct      BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_student_answers PRIMARY KEY (answer_id)
);
ALTER SEQUENCE studync.seq_student_answers OWNED BY studync.student_answers.answer_id;

-- -----------------------------------------------------------------------------
-- D8 quiz_results (score = percentage, computed by trigger)
-- -----------------------------------------------------------------------------
CREATE TABLE studync.quiz_results (
    result_id   VARCHAR(10)   NOT NULL DEFAULT 'RES' || lpad(nextval('studync.seq_quiz_results')::text, 7, '0'),
    student_id  VARCHAR(10)   NOT NULL,
    quiz_id     VARCHAR(10)   NOT NULL,
    score       NUMERIC(5,2)  NOT NULL DEFAULT 0.00,
    CONSTRAINT pk_quiz_results PRIMARY KEY (result_id)
);
ALTER SEQUENCE studync.seq_quiz_results OWNED BY studync.quiz_results.result_id;

-- -----------------------------------------------------------------------------
-- D9 audit_logs (append-only; ERD columns + record_id, performed_by, db_user,
-- old_data, new_data). performed_by has no FK on purpose.
-- -----------------------------------------------------------------------------
CREATE TABLE studync.audit_logs (
    log_id         INTEGER      GENERATED ALWAYS AS IDENTITY,
    action_type    VARCHAR(50)  NOT NULL,
    table_name     VARCHAR(50)  NOT NULL,
    record_id      VARCHAR(50)  NULL,
    performed_by   VARCHAR(10)  NULL,
    db_user        VARCHAR(100) NOT NULL DEFAULT session_user,
    description    TEXT         NULL,
    old_data       JSONB        NULL,
    new_data       JSONB        NULL,
    log_timestamp  TIMESTAMPTZ  NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT pk_audit_logs PRIMARY KEY (log_id)
);
COMMENT ON COLUMN studync.audit_logs.performed_by IS 'Application user_id passed through the studync.app_user_id setting';
COMMENT ON COLUMN studync.audit_logs.db_user      IS 'PostgreSQL login (session_user) that executed the statement';

-- -----------------------------------------------------------------------------
-- Reference data required by the procedures
-- -----------------------------------------------------------------------------
INSERT INTO studync.roles (role_id, role_name) VALUES
    ('ROL0000001', 'Administrator'),
    ('ROL0000002', 'Instructor'),
    ('ROL0000003', 'Student');

RESET ROLE;

SELECT table_name FROM information_schema.tables
WHERE table_schema = 'studync' AND table_type = 'BASE TABLE' ORDER BY table_name;
