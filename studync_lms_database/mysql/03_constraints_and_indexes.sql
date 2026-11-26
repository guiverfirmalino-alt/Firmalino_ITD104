-- =============================================================================
-- StudyNC LMS (MySQL 8.0+)
-- File 03 : UNIQUE, CHECK and FOREIGN KEY constraints + secondary indexes
-- -----------------------------------------------------------------------------
-- Referential-integrity policy (prevents orphaned records):
--   * ON DELETE RESTRICT everywhere, except user_roles -> users (CASCADE).
--     A parent row that is still referenced cannot be deleted.
--   * ON UPDATE RESTRICT: primary keys are immutable identifiers.
--   * Quiz deletion removes its questions explicitly in sp_delete_quiz (not
--     via ON DELETE CASCADE) because MySQL does NOT fire triggers for rows
--     changed by cascading foreign-key actions - explicit deletes keep the
--     audit trail complete.
-- CHECK constraints are enforced by MySQL 8.0.16+.
-- =============================================================================
USE studync_db;

-- ---------------------------------------------------------------- users
ALTER TABLE users
    ADD CONSTRAINT uq_users_username UNIQUE (username),
    ADD CONSTRAINT uq_users_email    UNIQUE (email),
    ADD CONSTRAINT ck_users_id_format       CHECK (REGEXP_LIKE(user_id, '^USR[0-9]{7}$', 'c')),
    ADD CONSTRAINT ck_users_username_format CHECK (REGEXP_LIKE(username, '^[A-Za-z0-9._]{3,50}$')),
    ADD CONSTRAINT ck_users_email_format    CHECK (REGEXP_LIKE(email, '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$')),
    ADD CONSTRAINT ck_users_hash_length     CHECK (CHAR_LENGTH(password_hash) >= 60);

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

-- ---------------------------------------------------------------- profiles (1:1 with users)
ALTER TABLE admins
    ADD CONSTRAINT uq_admins_user_id UNIQUE (user_id),
    ADD CONSTRAINT ck_admins_id_format CHECK (REGEXP_LIKE(admin_id, '^ADM[0-9]{7}$', 'c')),
    ADD CONSTRAINT ck_admins_names CHECK (TRIM(first_name) <> '' AND TRIM(last_name) <> ''),
    ADD CONSTRAINT fk_admins_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE instructors
    ADD CONSTRAINT uq_instructors_user_id UNIQUE (user_id),
    ADD CONSTRAINT ck_instructors_id_format CHECK (REGEXP_LIKE(instructor_id, '^INS[0-9]{7}$', 'c')),
    ADD CONSTRAINT ck_instructors_names CHECK (TRIM(first_name) <> '' AND TRIM(last_name) <> ''),
    ADD CONSTRAINT fk_instructors_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE students
    ADD CONSTRAINT uq_students_user_id UNIQUE (user_id),
    ADD CONSTRAINT ck_students_id_format CHECK (REGEXP_LIKE(student_id, '^STU[0-9]{7}$', 'c')),
    ADD CONSTRAINT ck_students_names CHECK (TRIM(first_name) <> '' AND TRIM(last_name) <> ''),
    ADD CONSTRAINT fk_students_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- ---------------------------------------------------------------- subjects
ALTER TABLE subjects
    ADD CONSTRAINT uq_subjects_subject_name UNIQUE (subject_name),
    ADD CONSTRAINT ck_subjects_id_format CHECK (REGEXP_LIKE(subject_id, '^SUB[0-9]{7}$', 'c')),
    ADD CONSTRAINT ck_subjects_name_not_blank CHECK (TRIM(subject_name) <> '');

-- ---------------------------------------------------------------- materials
ALTER TABLE materials
    ADD CONSTRAINT ck_materials_id_format CHECK (REGEXP_LIKE(material_id, '^MAT[0-9]{7}$', 'c')),
    ADD CONSTRAINT ck_materials_title_not_blank CHECK (TRIM(title) <> ''),
    ADD CONSTRAINT ck_materials_path_not_blank  CHECK (TRIM(file_path) <> ''),
    ADD CONSTRAINT fk_materials_subject FOREIGN KEY (subject_id)
        REFERENCES subjects (subject_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_materials_instructor FOREIGN KEY (instructor_id)
        REFERENCES instructors (instructor_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- ---------------------------------------------------------------- quizzes
ALTER TABLE quizzes
    ADD CONSTRAINT ck_quizzes_id_format CHECK (REGEXP_LIKE(quiz_id, '^QUZ[0-9]{7}$', 'c')),
    ADD CONSTRAINT ck_quizzes_title_not_blank CHECK (TRIM(title) <> ''),
    ADD CONSTRAINT fk_quizzes_subject FOREIGN KEY (subject_id)
        REFERENCES subjects (subject_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_quizzes_instructor FOREIGN KEY (instructor_id)
        REFERENCES instructors (instructor_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- ---------------------------------------------------------------- questions
ALTER TABLE questions
    ADD CONSTRAINT ck_questions_id_format CHECK (REGEXP_LIKE(question_id, '^QST[0-9]{7}$', 'c')),
    ADD CONSTRAINT ck_questions_text_not_blank CHECK (TRIM(question_text) <> ''),
    -- the correct answer must be one of the four options
    ADD CONSTRAINT ck_questions_correct_is_option
        CHECK (correct_answer IN (option_a, option_b, option_c, option_d)),
    -- options must be distinct so the correct answer is unambiguous
    ADD CONSTRAINT ck_questions_distinct_options
        CHECK (option_a <> option_b AND option_a <> option_c AND option_a <> option_d
           AND option_b <> option_c AND option_b <> option_d AND option_c <> option_d),
    ADD CONSTRAINT fk_questions_quiz FOREIGN KEY (quiz_id)
        REFERENCES quizzes (quiz_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- ---------------------------------------------------------------- student_answers
ALTER TABLE student_answers
    ADD CONSTRAINT uq_student_answers_student_question UNIQUE (student_id, question_id),
    ADD CONSTRAINT ck_student_answers_id_format CHECK (REGEXP_LIKE(answer_id, '^ANS[0-9]{7}$', 'c')),
    ADD CONSTRAINT fk_student_answers_student FOREIGN KEY (student_id)
        REFERENCES students (student_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_student_answers_question FOREIGN KEY (question_id)
        REFERENCES questions (question_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- ---------------------------------------------------------------- quiz_results
ALTER TABLE quiz_results
    ADD CONSTRAINT uq_quiz_results_student_quiz UNIQUE (student_id, quiz_id),
    ADD CONSTRAINT ck_quiz_results_id_format CHECK (REGEXP_LIKE(result_id, '^RES[0-9]{7}$', 'c')),
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
-- Secondary indexes
-- (InnoDB already indexes every PK, UNIQUE and FK column automatically; these
--  support the reporting / lookup queries used by views and procedures.)
-- =============================================================================
CREATE INDEX ix_users_status              ON users (status);
CREATE INDEX ix_materials_subject_uploaded ON materials (subject_id, uploaded_at);
CREATE INDEX ix_quizzes_subject_created   ON quizzes (subject_id, created_at);
CREATE INDEX ix_quiz_results_quiz_score   ON quiz_results (quiz_id, score);
CREATE INDEX ix_students_name             ON students (last_name, first_name);
CREATE INDEX ix_instructors_name          ON instructors (last_name, first_name);
CREATE INDEX ix_audit_logs_table_time     ON audit_logs (table_name, log_timestamp);
CREATE INDEX ix_audit_logs_performed_by   ON audit_logs (performed_by, log_timestamp);
CREATE INDEX ix_audit_logs_time           ON audit_logs (log_timestamp);

SELECT table_name, constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'studync_db'
ORDER BY table_name, constraint_type, constraint_name;
