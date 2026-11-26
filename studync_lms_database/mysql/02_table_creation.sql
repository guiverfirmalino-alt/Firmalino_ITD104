-- =============================================================================
-- StudyNC LMS (MySQL 8.0+)
-- File 02 : Table creation
-- -----------------------------------------------------------------------------
-- The 13 tables below are exactly the 13 entities of the documented ERD.
-- Primary keys, NOT NULL and DEFAULT values are declared here.
-- UNIQUE, CHECK, FOREIGN KEY constraints and secondary indexes are added in
-- file 03 so that each kind of rule is easy to find and explain.
--
-- Documented deviations (see README "Assumptions"):
--   * first_name / last_name are NOT NULL (a person profile needs a name).
--   * audit_logs gets record_id, performed_by, db_user, old_data, new_data
--     in addition to the ERD columns (required for a usable audit trail).
-- All tables use InnoDB (transactions + foreign keys).
-- =============================================================================
USE studync_db;

-- -----------------------------------------------------------------------------
-- D1 users : login accounts for every person in the system
-- -----------------------------------------------------------------------------
CREATE TABLE users (
    user_id        VARCHAR(10)  NOT NULL COMMENT 'Format USR0000001',
    username       VARCHAR(50)  NOT NULL,
    email          VARCHAR(100) NOT NULL,
    password_hash  VARCHAR(255) NOT NULL COMMENT 'Salted, iterated SHA-256 hash - never plain text',
    status         ENUM('Active','Inactive') NOT NULL DEFAULT 'Active',
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_users PRIMARY KEY (user_id)
) ENGINE = InnoDB;

-- -----------------------------------------------------------------------------
-- D2 roles : Administrator, Instructor, Student
-- -----------------------------------------------------------------------------
CREATE TABLE roles (
    role_id    VARCHAR(10) NOT NULL COMMENT 'Format ROL0000001',
    role_name  VARCHAR(50) NOT NULL,
    CONSTRAINT pk_roles PRIMARY KEY (role_id)
) ENGINE = InnoDB;

-- -----------------------------------------------------------------------------
-- user_roles : many-to-many link between users and roles
-- -----------------------------------------------------------------------------
CREATE TABLE user_roles (
    user_id  VARCHAR(10) NOT NULL,
    role_id  VARCHAR(10) NOT NULL,
    CONSTRAINT pk_user_roles PRIMARY KEY (user_id, role_id)
) ENGINE = InnoDB;

-- -----------------------------------------------------------------------------
-- admins / instructors / students : one profile row per user (1:1 with users)
-- -----------------------------------------------------------------------------
CREATE TABLE admins (
    admin_id    VARCHAR(10) NOT NULL COMMENT 'Format ADM0000001',
    user_id     VARCHAR(10) NOT NULL,
    first_name  VARCHAR(50) NOT NULL,
    last_name   VARCHAR(50) NOT NULL,
    CONSTRAINT pk_admins PRIMARY KEY (admin_id)
) ENGINE = InnoDB;

CREATE TABLE instructors (
    instructor_id  VARCHAR(10) NOT NULL COMMENT 'Format INS0000001',
    user_id        VARCHAR(10) NOT NULL,
    first_name     VARCHAR(50) NOT NULL,
    last_name      VARCHAR(50) NOT NULL,
    CONSTRAINT pk_instructors PRIMARY KEY (instructor_id)
) ENGINE = InnoDB;

CREATE TABLE students (
    student_id  VARCHAR(10) NOT NULL COMMENT 'Format STU0000001',
    user_id     VARCHAR(10) NOT NULL,
    first_name  VARCHAR(50) NOT NULL,
    last_name   VARCHAR(50) NOT NULL,
    CONSTRAINT pk_students PRIMARY KEY (student_id)
) ENGINE = InnoDB;

-- -----------------------------------------------------------------------------
-- D3 subjects
-- -----------------------------------------------------------------------------
CREATE TABLE subjects (
    subject_id    VARCHAR(10)  NOT NULL COMMENT 'Format SUB0000001',
    subject_name  VARCHAR(100) NOT NULL,
    description   TEXT         NULL,
    CONSTRAINT pk_subjects PRIMARY KEY (subject_id)
) ENGINE = InnoDB;

-- -----------------------------------------------------------------------------
-- D4 materials : learning materials uploaded by an instructor for a subject
-- -----------------------------------------------------------------------------
CREATE TABLE materials (
    material_id    VARCHAR(10)  NOT NULL COMMENT 'Format MAT0000001',
    subject_id     VARCHAR(10)  NOT NULL,
    instructor_id  VARCHAR(10)  NOT NULL,
    title          VARCHAR(255) NOT NULL,
    file_path      VARCHAR(255) NOT NULL,
    uploaded_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_materials PRIMARY KEY (material_id)
) ENGINE = InnoDB;

-- -----------------------------------------------------------------------------
-- D5 quizzes
-- -----------------------------------------------------------------------------
CREATE TABLE quizzes (
    quiz_id        VARCHAR(10)  NOT NULL COMMENT 'Format QUZ0000001',
    subject_id     VARCHAR(10)  NOT NULL,
    instructor_id  VARCHAR(10)  NOT NULL,
    title          VARCHAR(255) NOT NULL,
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_quizzes PRIMARY KEY (quiz_id)
) ENGINE = InnoDB;

-- -----------------------------------------------------------------------------
-- D6 questions : multiple-choice (A-D). correct_answer holds the TEXT of the
-- correct option (varchar(255) per ERD); a CHECK in file 03 forces it to equal
-- one of option_a..option_d.
-- -----------------------------------------------------------------------------
CREATE TABLE questions (
    question_id     VARCHAR(10)  NOT NULL COMMENT 'Format QST0000001',
    quiz_id         VARCHAR(10)  NOT NULL,
    question_text   TEXT         NOT NULL,
    correct_answer  VARCHAR(255) NOT NULL,
    option_a        VARCHAR(255) NOT NULL,
    option_b        VARCHAR(255) NOT NULL,
    option_c        VARCHAR(255) NOT NULL,
    option_d        VARCHAR(255) NOT NULL,
    CONSTRAINT pk_questions PRIMARY KEY (question_id)
) ENGINE = InnoDB;

-- -----------------------------------------------------------------------------
-- D7 student_answers : one answer per student per question.
-- is_correct is computed by a trigger (file 07) - clients cannot set it.
-- -----------------------------------------------------------------------------
CREATE TABLE student_answers (
    answer_id       VARCHAR(10)  NOT NULL COMMENT 'Format ANS0000001',
    student_id      VARCHAR(10)  NOT NULL,
    question_id     VARCHAR(10)  NOT NULL,
    student_answer  VARCHAR(255) NULL,
    is_correct      BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_student_answers PRIMARY KEY (answer_id)
) ENGINE = InnoDB;

-- -----------------------------------------------------------------------------
-- D8 quiz_results : one result per student per quiz. score = percentage.
-- -----------------------------------------------------------------------------
CREATE TABLE quiz_results (
    result_id   VARCHAR(10)   NOT NULL COMMENT 'Format RES0000001',
    student_id  VARCHAR(10)   NOT NULL,
    quiz_id     VARCHAR(10)   NOT NULL,
    score       DECIMAL(5,2)  NOT NULL DEFAULT 0.00 COMMENT 'Percentage 0.00 - 100.00',
    CONSTRAINT pk_quiz_results PRIMARY KEY (result_id)
) ENGINE = InnoDB;

-- -----------------------------------------------------------------------------
-- D9 audit_logs : append-only activity trail (written by triggers / procedures)
--   ERD columns : log_id, action_type, table_name, description, log_timestamp
--   Added       : record_id, performed_by (application user_id),
--                 db_user (MySQL account), old_data, new_data (JSON)
--   performed_by intentionally has NO foreign key: the audit trail must keep
--   its rows even if referenced data changes.
-- -----------------------------------------------------------------------------
CREATE TABLE audit_logs (
    log_id         INT          NOT NULL AUTO_INCREMENT,
    action_type    VARCHAR(50)  NOT NULL,
    table_name     VARCHAR(50)  NOT NULL,
    record_id      VARCHAR(50)  NULL,
    performed_by   VARCHAR(10)  NULL COMMENT 'Application user_id passed via @app_user_id',
    db_user        VARCHAR(100) NOT NULL COMMENT 'MySQL account that ran the statement',
    description    TEXT         NULL,
    old_data       JSON         NULL,
    new_data       JSON         NULL,
    log_timestamp  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_audit_logs PRIMARY KEY (log_id)
) ENGINE = InnoDB;

-- -----------------------------------------------------------------------------
-- Reference data required by the stored procedures (the three documented roles)
-- -----------------------------------------------------------------------------
INSERT INTO roles (role_id, role_name) VALUES
    ('ROL0000001', 'Administrator'),
    ('ROL0000002', 'Instructor'),
    ('ROL0000003', 'Student');

SELECT table_name, engine
FROM information_schema.tables
WHERE table_schema = 'studync_db'
ORDER BY table_name;
