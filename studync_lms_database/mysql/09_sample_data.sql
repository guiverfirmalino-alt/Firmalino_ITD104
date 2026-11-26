-- =============================================================================
-- StudyNC LMS (MySQL 8.0+)
-- File 09 : Sample data (fictional people and content only)
-- -----------------------------------------------------------------------------
-- Run as an administrative account (root / DBA) AFTER files 01-08.
-- Apart from the two bootstrap administrators, every record is created
-- THROUGH THE STORED PROCEDURES, acting as the appropriate application user.
-- That means the sample data also exercises the business rules, and the
-- audit_logs table is populated naturally by the triggers.
--
-- Resulting data set
--   Users       : 12  (2 administrators, 3 instructors, 7 students; 1 inactive;
--                      carlo.mendoza is Administrator + Instructor)
--   Subjects    : 5   (SUB0000005 "Technical Writing" is unused -> delete test)
--   Materials   : 8   (+1 uploaded and deleted again)
--   Quizzes     : 5   (QUZ0000005 has no attempts yet)
--   Questions   : 19
--   Answers     : 49, Results : 12
--   Audit logs  : generated automatically (~150 rows)
--
-- Application passwords (users.password_hash is stored hashed):
--   every sample user's password is  Pass#<FirstName>2026   e.g. Pass#Ana2026
-- =============================================================================
USE studync_db;

-- 1. Bootstrap administrators (direct insert by the DBA: there is no administrator yet
--    who could call sp_register_*; these rows are audited with performed_by = NULL).
INSERT INTO users (user_id, username, email, password_hash) VALUES ('USR0000001', 'maria.reyes', 'maria.reyes@studync.edu', fn_hash_password('Pass#Maria2026', HEX(RANDOM_BYTES(16))));
INSERT INTO user_roles (user_id, role_id) VALUES ('USR0000001', 'ROL0000001');
INSERT INTO admins (admin_id, user_id, first_name, last_name) VALUES ('ADM0000001', 'USR0000001', 'Maria', 'Reyes');
INSERT INTO users (user_id, username, email, password_hash) VALUES ('USR0000002', 'carlo.mendoza', 'carlo.mendoza@studync.edu', fn_hash_password('Pass#Carlo2026', HEX(RANDOM_BYTES(16))));
INSERT INTO user_roles (user_id, role_id) VALUES ('USR0000002', 'ROL0000001');
INSERT INTO admins (admin_id, user_id, first_name, last_name) VALUES ('ADM0000002', 'USR0000002', 'Carlo', 'Mendoza');

-- 2. Administrator registers instructors and students (Module 1)
CALL sp_register_instructor('USR0000001', 'jose.cruz', 'jose.cruz@studync.edu', 'Pass#Jose2026', 'Jose', 'Cruz', @o0, @o1);
CALL sp_register_instructor('USR0000001', 'liza.garcia', 'liza.garcia@studync.edu', 'Pass#Liza2026', 'Liza', 'Garcia', @o0, @o1);
CALL sp_register_instructor('USR0000001', 'ramon.villanueva', 'ramon.villanueva@studync.edu', 'Pass#Ramon2026', 'Ramon', 'Villanueva', @o0, @o1);
CALL sp_register_student('USR0000001', 'ana.santos', 'ana.santos@studync.edu', 'Pass#Ana2026', 'Ana', 'Santos', @o0, @o1);
CALL sp_register_student('USR0000001', 'ben.torres', 'ben.torres@studync.edu', 'Pass#Ben2026', 'Ben', 'Torres', @o0, @o1);
CALL sp_register_student('USR0000001', 'carla.dizon', 'carla.dizon@studync.edu', 'Pass#Carla2026', 'Carla', 'Dizon', @o0, @o1);
CALL sp_register_student('USR0000001', 'diego.ramos', 'diego.ramos@studync.edu', 'Pass#Diego2026', 'Diego', 'Ramos', @o0, @o1);
CALL sp_register_student('USR0000001', 'ella.navarro', 'ella.navarro@studync.edu', 'Pass#Ella2026', 'Ella', 'Navarro', @o0, @o1);
CALL sp_register_student('USR0000001', 'felix.aquino', 'felix.aquino@studync.edu', 'Pass#Felix2026', 'Felix', 'Aquino', @o0, @o1);
CALL sp_register_student('USR0000001', 'gina.lopez', 'gina.lopez@studync.edu', 'Pass#Gina2026', 'Gina', 'Lopez', @o0, @o1);
-- gina.lopez left the institution: account deactivated (no physical delete)
CALL sp_set_user_status('USR0000001', 'USR0000012', 'Inactive');
-- carlo.mendoza also teaches: give him the Instructor role (creates INS profile)
CALL sp_assign_role('USR0000001', 'USR0000002', 'Instructor');

-- 3. Subjects (Module 2)
CALL sp_create_subject('USR0000001', 'Database Security and Administration', 'Roles, privileges, auditing, backup and recovery of relational databases.', @o0);
CALL sp_create_subject('USR0000001', 'Web Development Fundamentals', 'HTML, CSS and JavaScript for building accessible web pages.', @o0);
CALL sp_create_subject('USR0000001', 'Data Structures and Algorithms', 'Arrays, lists, trees, graphs and algorithm analysis.', @o0);
CALL sp_create_subject('USR0000001', 'Networking Essentials', 'OSI model, TCP/IP, addressing and basic network security.', @o0);
CALL sp_create_subject('USR0000001', 'Technical Writing', 'Writing clear technical documentation and reports.', @o0);
CALL sp_update_subject('USR0000001', 'SUB0000004', NULL, 'OSI model, TCP/IP, IP addressing, subnetting and basic network security.');

-- 4. Learning materials (Module 3)
CALL sp_upload_material('USR0000003', 'SUB0000001', 'Introduction to Database Security', 'materials/sub1/intro-db-security.pdf', @o0);
CALL sp_upload_material('USR0000003', 'SUB0000001', 'Managing Roles and Privileges', 'materials/sub1/roles-and-privileges.pdf', @o0);
CALL sp_upload_material('USR0000003', 'SUB0000001', 'Audit Trails with Triggers', 'materials/sub1/audit-trails.pptx', @o0);
CALL sp_upload_material('USR0000004', 'SUB0000002', 'HTML5 Document Structure', 'materials/sub2/html5-structure.pdf', @o0);
CALL sp_upload_material('USR0000004', 'SUB0000002', 'CSS Flexbox Guide', 'materials/sub2/css-flexbox.pdf', @o0);
CALL sp_upload_material('USR0000004', 'SUB0000002', 'JavaScript Basics Video', 'https://videos.studync.edu/js-basics', @o0);
CALL sp_upload_material('USR0000005', 'SUB0000003', 'Big-O Notation Lecture', 'materials/sub3/big-o.pdf', @o0);
CALL sp_upload_material('USR0000005', 'SUB0000003', 'Linked Lists Worksheet', 'materials/sub3/linked-lists.docx', @o0);
CALL sp_update_material('USR0000004', 'MAT0000005', NULL, 'CSS Flexbox and Grid Guide', 'materials/sub2/css-flexbox-grid.pdf');
-- a duplicate upload that the instructor removes again (shows DELETE auditing)
CALL sp_upload_material('USR0000005', 'SUB0000003', 'Big-O Notation Lecture (old copy)', 'materials/sub3/big-o-old.pdf', @o0);
CALL sp_delete_material('USR0000005', 'MAT0000009');

-- 5. Quizzes and questions (Module 4)
CALL sp_create_quiz('USR0000003', 'SUB0000001', 'SQL Security Basics', @o0);
CALL sp_create_quiz('USR0000003', 'SUB0000001', 'Database Roles and Privileges', @o0);
CALL sp_create_quiz('USR0000004', 'SUB0000002', 'HTML and CSS Basics', @o0);
CALL sp_create_quiz('USR0000005', 'SUB0000003', 'Big-O Notation', @o0);
CALL sp_create_quiz('USR0000004', 'SUB0000002', 'JavaScript Fundamentals', @o0);
CALL sp_add_question('USR0000003', 'QUZ0000001', 'Which SQL statement gives a privilege to a user or role?', 'REVOKE', 'GRANT', 'DENY', 'ALLOW', 'B', @o0);
CALL sp_add_question('USR0000003', 'QUZ0000001', 'Which attack inserts malicious SQL through user input?', 'Phishing', 'Brute force', 'SQL injection', 'Spoofing', 'C', @o0);
CALL sp_add_question('USR0000003', 'QUZ0000001', 'What should be stored instead of a plain-text password?', 'A salted hash', 'The password in upper case', 'An encrypted email', 'Nothing', 'A', @o0);
CALL sp_add_question('USR0000003', 'QUZ0000001', 'Which object can hide sensitive columns from users?', 'Index', 'Trigger', 'Sequence', 'View', 'D', @o0);
CALL sp_add_question('USR0000003', 'QUZ0000001', 'The principle of giving users only the access they need is called:', 'Defense in depth', 'Least privilege', 'Separation of data', 'Normalization', 'B', @o0);
CALL sp_add_question('USR0000003', 'QUZ0000002', 'Which statement removes a previously granted privilege?', 'REVOKE', 'DROP', 'DELETE', 'REMOVE', 'A', @o0);
CALL sp_add_question('USR0000003', 'QUZ0000002', 'A named group of privileges is called a:', 'Schema', 'Synonym', 'Role', 'Cursor', 'C', @o0);
CALL sp_add_question('USR0000003', 'QUZ0000002', 'Which privilege allows calling a stored procedure?', 'SELECT', 'EXECUTE', 'USAGE', 'CALL', 'B', @o0);
CALL sp_add_question('USR0000003', 'QUZ0000002', 'Which table records who changed data and when?', 'Temp table', 'Lookup table', 'Junction table', 'Audit log', 'D', @o0);
CALL sp_add_question('USR0000004', 'QUZ0000003', 'Which tag creates the largest heading?', '<head>', '<h6>', '<h1>', '<header>', 'C', @o0);
CALL sp_add_question('USR0000004', 'QUZ0000003', 'Which CSS property changes text color?', 'color', 'font-color', 'text-color', 'fg', 'A', @o0);
CALL sp_add_question('USR0000004', 'QUZ0000003', 'Which HTML element links an external stylesheet?', '<style>', '<script>', '<css>', '<link>', 'D', @o0);
CALL sp_add_question('USR0000004', 'QUZ0000003', 'Which CSS display value creates a flex container?', 'block', 'flex', 'grid-inline', 'inline', 'B', @o0);
CALL sp_add_question('USR0000005', 'QUZ0000004', 'What is the time complexity of binary search?', 'O(n)', 'O(log n)', 'O(n log n)', 'O(1)', 'B', @o0);
CALL sp_add_question('USR0000005', 'QUZ0000004', 'Accessing an array element by index is:', 'O(1)', 'O(n)', 'O(log n)', 'O(n^2)', 'A', @o0);
CALL sp_add_question('USR0000005', 'QUZ0000004', 'A nested loop over n items is usually:', 'O(n)', 'O(log n)', 'O(n^2)', 'O(1)', 'C', @o0);
CALL sp_add_question('USR0000004', 'QUZ0000005', 'Which keyword declares a block-scoped variable?', 'let', 'var', 'def', 'dim', 'A', @o0);
CALL sp_add_question('USR0000004', 'QUZ0000005', 'Which method prints to the browser console?', 'print()', 'echo()', 'write()', 'console.log()', 'D', @o0);
CALL sp_add_question('USR0000004', 'QUZ0000005', 'What does === compare?', 'Value only', 'Value and type', 'Reference only', 'Length', 'B', @o0);
CALL sp_update_quiz('USR0000005', 'QUZ0000004', NULL, 'Big-O Notation Quiz');

-- 6. Students answer and submit quizzes (Module 5)
CALL sp_submit_answer('USR0000006', 'QST0000001', 'B', @o0);
CALL sp_submit_answer('USR0000006', 'QST0000002', 'C', @o0);
CALL sp_submit_answer('USR0000006', 'QST0000003', 'A', @o0);
CALL sp_submit_answer('USR0000006', 'QST0000004', 'D', @o0);
CALL sp_submit_answer('USR0000006', 'QST0000005', 'B', @o0);
CALL sp_submit_quiz('USR0000006', 'QUZ0000001', @o0, @o1);
CALL sp_submit_answer('USR0000007', 'QST0000001', 'B', @o0);
CALL sp_submit_answer('USR0000007', 'QST0000002', 'C', @o0);
CALL sp_submit_answer('USR0000007', 'QST0000003', 'A', @o0);
CALL sp_submit_answer('USR0000007', 'QST0000004', 'D', @o0);
CALL sp_submit_answer('USR0000007', 'QST0000005', 'A', @o0);
CALL sp_submit_quiz('USR0000007', 'QUZ0000001', @o0, @o1);
CALL sp_submit_answer('USR0000008', 'QST0000001', 'B', @o0);
CALL sp_submit_answer('USR0000008', 'QST0000002', 'C', @o0);
CALL sp_submit_answer('USR0000008', 'QST0000003', 'A', @o0);
CALL sp_submit_answer('USR0000008', 'QST0000004', 'A', @o0);
CALL sp_submit_answer('USR0000008', 'QST0000005', 'C', @o0);
CALL sp_submit_quiz('USR0000008', 'QUZ0000001', @o0, @o1);
CALL sp_submit_answer('USR0000009', 'QST0000001', 'A', @o0);
CALL sp_submit_answer('USR0000009', 'QST0000002', 'C', @o0);
CALL sp_submit_answer('USR0000009', 'QST0000003', 'D', @o0);
CALL sp_submit_answer('USR0000009', 'QST0000004', 'D', @o0);
CALL sp_submit_quiz('USR0000009', 'QUZ0000001', @o0, @o1);
CALL sp_submit_answer('USR0000006', 'QST0000006', 'A', @o0);
CALL sp_submit_answer('USR0000006', 'QST0000007', 'C', @o0);
CALL sp_submit_answer('USR0000006', 'QST0000008', 'B', @o0);
CALL sp_submit_answer('USR0000006', 'QST0000009', 'A', @o0);
CALL sp_submit_quiz('USR0000006', 'QUZ0000002', @o0, @o1);
CALL sp_submit_answer('USR0000007', 'QST0000006', 'A', @o0);
CALL sp_submit_answer('USR0000007', 'QST0000007', 'C', @o0);
CALL sp_submit_answer('USR0000007', 'QST0000008', 'B', @o0);
CALL sp_submit_answer('USR0000007', 'QST0000009', 'D', @o0);
CALL sp_submit_quiz('USR0000007', 'QUZ0000002', @o0, @o1);
CALL sp_submit_answer('USR0000010', 'QST0000006', 'A', @o0);
CALL sp_submit_answer('USR0000010', 'QST0000007', 'A', @o0);
CALL sp_submit_answer('USR0000010', 'QST0000008', 'B', @o0);
CALL sp_submit_answer('USR0000010', 'QST0000009', 'A', @o0);
CALL sp_submit_quiz('USR0000010', 'QUZ0000002', @o0, @o1);
CALL sp_submit_answer('USR0000008', 'QST0000010', 'C', @o0);
CALL sp_submit_answer('USR0000008', 'QST0000011', 'A', @o0);
CALL sp_submit_answer('USR0000008', 'QST0000012', 'D', @o0);
CALL sp_submit_answer('USR0000008', 'QST0000013', 'B', @o0);
CALL sp_submit_quiz('USR0000008', 'QUZ0000003', @o0, @o1);
CALL sp_submit_answer('USR0000011', 'QST0000010', 'A', @o0);
CALL sp_submit_answer('USR0000011', 'QST0000011', 'A', @o0);
CALL sp_submit_answer('USR0000011', 'QST0000012', 'A', @o0);
CALL sp_submit_answer('USR0000011', 'QST0000013', 'A', @o0);
CALL sp_submit_quiz('USR0000011', 'QUZ0000003', @o0, @o1);
CALL sp_submit_answer('USR0000006', 'QST0000010', 'C', @o0);
CALL sp_submit_answer('USR0000006', 'QST0000011', 'A', @o0);
CALL sp_submit_answer('USR0000006', 'QST0000012', 'D', @o0);
CALL sp_submit_answer('USR0000006', 'QST0000013', 'C', @o0);
CALL sp_submit_quiz('USR0000006', 'QUZ0000003', @o0, @o1);
CALL sp_submit_answer('USR0000009', 'QST0000014', 'B', @o0);
CALL sp_submit_answer('USR0000009', 'QST0000015', 'A', @o0);
CALL sp_submit_answer('USR0000009', 'QST0000016', 'C', @o0);
CALL sp_submit_quiz('USR0000009', 'QUZ0000004', @o0, @o1);
CALL sp_submit_answer('USR0000010', 'QST0000014', 'B', @o0);
CALL sp_submit_answer('USR0000010', 'QST0000015', 'A', @o0);
CALL sp_submit_answer('USR0000010', 'QST0000016', 'D', @o0);
CALL sp_submit_quiz('USR0000010', 'QUZ0000004', @o0, @o1);

-- 7. Login activity (Module 6 monitoring data)
CALL sp_authenticate_user('ana.santos', 'Pass#Ana2026', @o0, @o1, @o2, @o3);
CALL sp_authenticate_user('ben.torres', 'wrong-password', @o0, @o1, @o2, @o3);
CALL sp_authenticate_user('gina.lopez', 'Pass#Gina2026', @o0, @o1, @o2, @o3);

SET @o0 = NULL, @o1 = NULL, @o2 = NULL, @o3 = NULL;

-- -----------------------------------------------------------------------------
-- Row counts (expected: users 12, roles 3, user_roles 13, admins 2,
-- instructors 4, students 7, subjects 5, materials 8, quizzes 5, questions 19,
-- student_answers 49, quiz_results 12)
-- -----------------------------------------------------------------------------
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM users
UNION ALL SELECT 'roles', COUNT(*) FROM roles
UNION ALL SELECT 'user_roles', COUNT(*) FROM user_roles
UNION ALL SELECT 'admins', COUNT(*) FROM admins
UNION ALL SELECT 'instructors', COUNT(*) FROM instructors
UNION ALL SELECT 'students', COUNT(*) FROM students
UNION ALL SELECT 'subjects', COUNT(*) FROM subjects
UNION ALL SELECT 'materials', COUNT(*) FROM materials
UNION ALL SELECT 'quizzes', COUNT(*) FROM quizzes
UNION ALL SELECT 'questions', COUNT(*) FROM questions
UNION ALL SELECT 'student_answers', COUNT(*) FROM student_answers
UNION ALL SELECT 'quiz_results', COUNT(*) FROM quiz_results
UNION ALL SELECT 'audit_logs', COUNT(*) FROM audit_logs;

SELECT result_id, student_name, quiz_title, score, correct_answers, total_questions
FROM v_quiz_results_detail ORDER BY result_id;
