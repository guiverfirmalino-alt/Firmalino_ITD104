-- =============================================================================
-- StudyNC LMS (PostgreSQL 16+)
-- File 03 : UNIQUE, CHECK, FOREIGN KEY constraints and indexes
-- -----------------------------------------------------------------------------
-- Same integrity rules as the MySQL version. PostgreSQL differences:
--   * PostgreSQL does NOT index foreign-key columns automatically, so every FK
--     column gets an explicit index here (needed for joins and to avoid full
--     scans when a parent row is deleted/checked).
--   * Case-insensitive uniqueness (MySQL gets it from its _ci collation) is
--     implemented with UNIQUE indexes on lower(...).
--   * Regular expressions use the ~ operator.
-- Delete policy: ON DELETE RESTRICT (user_roles -> users: CASCADE); questions
-- of a quiz are deleted explicitly by sp_delete_quiz so each deletion is
-- audited the same way in both DBMSs.
-- =============================================================================
SET ROLE studync_owner;
SET search_path = studync, pg_temp;

-- ---------------------------------------------------------------- users
ALTER TABLE users
    ADD CONSTRAINT ck_users_id_format       CHECK (user_id ~ '^USR[0-9]{7}$'),
    ADD CONSTRAINT ck_users_username_format CHECK (username ~ '^[A-Za-z0-9._]{3,50}$'),
    ADD CONSTRAINT ck_users_email_format    CHECK (email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
    ADD CONSTRAINT ck_users_hash_length     CHECK (char_length(password_hash) >= 60);
CREATE UNIQUE INDEX uq_users_username ON users (lower(username));
CREATE UNIQUE INDEX uq_users_email    ON users (lower(email));

-- ---------------------------------------------------------------- roles
ALTER TABLE roles
    ADD CONSTRAINT uq_roles_role_name UNIQUE (role_name),
    ADD CONSTRAINT ck_roles_role_name CHECK (role_name IN ('Administrator','Instructor','Student'));

-- ---------------------------------------------------------------- user_roles
ALTER TABLE user_roles
    ADD CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE CASCADE ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id)
        REFERENCES roles (role_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- ---------------------------------------------------------------- profiles
ALTER TABLE admins
    ADD CONSTRAINT uq_admins_user_id UNIQUE (user_id),
    ADD CONSTRAINT ck_admins_id_format CHECK (admin_id ~ '^ADM[0-9]{7}$'),
    ADD CONSTRAINT ck_admins_names CHECK (btrim(first_name) <> '' AND btrim(last_name) <> ''),
    ADD CONSTRAINT fk_admins_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE instructors
    ADD CONSTRAINT uq_instructors_user_id UNIQUE (user_id),
    ADD CONSTRAINT ck_instructors_id_format CHECK (instructor_id ~ '^INS[0-9]{7}$'),
    ADD CONSTRAINT ck_instructors_names CHECK (btrim(first_name) <> '' AND btrim(last_name) <> ''),
    ADD CONSTRAINT fk_instructors_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE students
    ADD CONSTRAINT uq_students_user_id UNIQUE (user_id),
    ADD CONSTRAINT ck_students_id_format CHECK (student_id ~ '^STU[0-9]{7}$'),
    ADD CONSTRAINT ck_students_names CHECK (btrim(first_name) <> '' AND btrim(last_name) <> ''),
    ADD CONSTRAINT fk_students_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- ---------------------------------------------------------------- subjects
ALTER TABLE subjects
    ADD CONSTRAINT ck_subjects_id_format CHECK (subject_id ~ '^SUB[0-9]{7}$'),
    ADD CONSTRAINT ck_subjects_name_not_blank CHECK (btrim(subject_name) <> '');
CREATE UNIQUE INDEX uq_subjects_subject_name ON subjects (lower(subject_name));

-- ---------------------------------------------------------------- materials
ALTER TABLE materials
    ADD CONSTRAINT ck_materials_id_format CHECK (material_id ~ '^MAT[0-9]{7}$'),
    ADD CONSTRAINT ck_materials_title_not_blank CHECK (btrim(title) <> ''),
    ADD CONSTRAINT ck_materials_path_not_blank  CHECK (btrim(file_path) <> ''),
    ADD CONSTRAINT fk_materials_subject FOREIGN KEY (subject_id)
        REFERENCES subjects (subject_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_materials_instructor FOREIGN KEY (instructor_id)
        REFERENCES instructors (instructor_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- ---------------------------------------------------------------- quizzes
ALTER TABLE quizzes
    ADD CONSTRAINT ck_quizzes_id_format CHECK (quiz_id ~ '^QUZ[0-9]{7}$'),
    ADD CONSTRAINT ck_quizzes_title_not_blank CHECK (btrim(title) <> ''),
    ADD CONSTRAINT fk_quizzes_subject FOREIGN KEY (subject_id)
        REFERENCES subjects (subject_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_quizzes_instructor FOREIGN KEY (instructor_id)
        REFERENCES instructors (instructor_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- ---------------------------------------------------------------- questions
ALTER TABLE questions
    ADD CONSTRAINT ck_questions_id_format CHECK (question_id ~ '^QST[0-9]{7}$'),
    ADD CONSTRAINT ck_questions_text_not_blank CHECK (btrim(question_text) <> ''),
    ADD CONSTRAINT ck_questions_correct_is_option
        CHECK (correct_answer IN (option_a, option_b, option_c, option_d)),
    ADD CONSTRAINT ck_questions_distinct_options
        CHECK (lower(option_a) <> lower(option_b) AND lower(option_a) <> lower(option_c)
           AND lower(option_a) <> lower(option_d) AND lower(option_b) <> lower(option_c)
           AND lower(option_b) <> lower(option_d) AND lower(option_c) <> lower(option_d)),
    ADD CONSTRAINT fk_questions_quiz FOREIGN KEY (quiz_id)
        REFERENCES quizzes (quiz_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- ---------------------------------------------------------------- student_answers
ALTER TABLE student_answers
    ADD CONSTRAINT uq_student_answers_student_question UNIQUE (student_id, question_id),
    ADD CONSTRAINT ck_student_answers_id_format CHECK (answer_id ~ '^ANS[0-9]{7}$'),
    ADD CONSTRAINT fk_student_answers_student FOREIGN KEY (student_id)
        REFERENCES students (student_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_student_answers_question FOREIGN KEY (question_id)
        REFERENCES questions (question_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- ---------------------------------------------------------------- quiz_results
ALTER TABLE quiz_results
    ADD CONSTRAINT uq_quiz_results_student_quiz UNIQUE (student_id, quiz_id),
    ADD CONSTRAINT ck_quiz_results_id_format CHECK (result_id ~ '^RES[0-9]{7}$'),
    ADD CONSTRAINT ck_quiz_results_score_range CHECK (score BETWEEN 0 AND 100),
    ADD CONSTRAINT fk_quiz_results_student FOREIGN KEY (student_id)
        REFERENCES students (student_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_quiz_results_quiz FOREIGN KEY (quiz_id)
        REFERENCES quizzes (quiz_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- ---------------------------------------------------------------- audit_logs
ALTER TABLE audit_logs
    ADD CONSTRAINT ck_audit_logs_action_type CHECK (action_type IN
        ('INSERT','UPDATE','DELETE','LOGIN_SUCCESS','LOGIN_FAILED'));

-- =============================================================================
-- Indexes
-- =============================================================================
-- FK columns (not automatic in PostgreSQL; composite PK/UNIQUE indexes already
-- cover user_roles.user_id, student_answers.student_id, quiz_results.student_id)
CREATE INDEX ix_user_roles_role_id          ON user_roles (role_id);
CREATE INDEX ix_materials_instructor_id     ON materials (instructor_id);
CREATE INDEX ix_materials_subject_uploaded  ON materials (subject_id, uploaded_at);
CREATE INDEX ix_quizzes_instructor_id       ON quizzes (instructor_id);
CREATE INDEX ix_quizzes_subject_created     ON quizzes (subject_id, created_at);
CREATE INDEX ix_questions_quiz_id           ON questions (quiz_id);
CREATE INDEX ix_student_answers_question_id ON student_answers (question_id);
CREATE INDEX ix_quiz_results_quiz_score     ON quiz_results (quiz_id, score);
-- lookups / reporting
CREATE INDEX ix_users_status                ON users (status);
CREATE INDEX ix_students_name               ON students (last_name, first_name);
CREATE INDEX ix_instructors_name            ON instructors (last_name, first_name);
CREATE INDEX ix_audit_logs_table_time       ON audit_logs (table_name, log_timestamp);
CREATE INDEX ix_audit_logs_performed_by     ON audit_logs (performed_by, log_timestamp);
CREATE INDEX ix_audit_logs_time             ON audit_logs (log_timestamp);
-- JSONB search inside audit payloads (e.g. new_data @> '{"quiz_id":"QUZ0000001"}')
CREATE INDEX ix_audit_logs_new_data_gin     ON audit_logs USING GIN (new_data jsonb_path_ops);

RESET ROLE;

SELECT conrelid::regclass AS table_name, conname, contype
FROM pg_constraint
WHERE connamespace = 'studync'::regnamespace
ORDER BY 1, 3, 2;
