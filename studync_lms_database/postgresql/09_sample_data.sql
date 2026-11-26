-- =============================================================================
-- StudyNC LMS (PostgreSQL 16+)
-- File 09 : Sample data (fictional people and content only)
-- Run as  : superuser connected to studync_db, after files 01-08
-- -----------------------------------------------------------------------------
-- Identical data set to the MySQL version. Apart from the two bootstrap
-- administrators, every record is created through the stored procedures
-- acting as the appropriate application user, so the business rules are
-- exercised and audit_logs is filled by the triggers.
--   (CALLs of procedures with OUT parameters pass NULL as a placeholder and
--    print the returned values.)
--
-- Expected: users 12, roles 3, user_roles 13, admins 2, instructors 4,
-- students 7, subjects 5, materials 8, quizzes 5, questions 19,
-- student_answers 49, quiz_results 12, audit_logs ~145
-- Application passwords of all sample users: Pass#<FirstName>2026
-- =============================================================================
SET search_path = studync, pg_temp;

-- 1. Bootstrap administrators (direct insert by the DBA: there is no administrator yet
--    who could call sp_register_*; these rows are audited with performed_by = NULL).
INSERT INTO users (username, email, password_hash) VALUES ('maria.reyes', 'maria.reyes@studync.edu', fn_hash_password('Pass#Maria2026'));   -- USR0000001
INSERT INTO user_roles (user_id, role_id) SELECT user_id, 'ROL0000001' FROM users WHERE username = 'maria.reyes';
INSERT INTO admins (user_id, first_name, last_name) SELECT user_id, 'Maria', 'Reyes' FROM users WHERE username = 'maria.reyes';   -- ADM0000001
INSERT INTO users (username, email, password_hash) VALUES ('carlo.mendoza', 'carlo.mendoza@studync.edu', fn_hash_password('Pass#Carlo2026'));   -- USR0000002
INSERT INTO user_roles (user_id, role_id) SELECT user_id, 'ROL0000001' FROM users WHERE username = 'carlo.mendoza';
INSERT INTO admins (user_id, first_name, last_name) SELECT user_id, 'Carlo', 'Mendoza' FROM users WHERE username = 'carlo.mendoza';   -- ADM0000002

-- 2. Administrator registers instructors and students (Module 1)
CALL sp_register_instructor('USR0000001', 'jose.cruz', 'jose.cruz@studync.edu', 'Pass#Jose2026', 'Jose', 'Cruz', NULL, NULL);
CALL sp_register_instructor('USR0000001', 'liza.garcia', 'liza.garcia@studync.edu', 'Pass#Liza2026', 'Liza', 'Garcia', NULL, NULL);
CALL sp_register_instructor('USR0000001', 'ramon.villanueva', 'ramon.villanueva@studync.edu', 'Pass#Ramon2026', 'Ramon', 'Villanueva', NULL, NULL);
CALL sp_register_student('USR0000001', 'ana.santos', 'ana.santos@studync.edu', 'Pass#Ana2026', 'Ana', 'Santos', NULL, NULL);
CALL sp_register_student('USR0000001', 'ben.torres', 'ben.torres@studync.edu', 'Pass#Ben2026', 'Ben', 'Torres', NULL, NULL);
CALL sp_register_student('USR0000001', 'carla.dizon', 'carla.dizon@studync.edu', 'Pass#Carla2026', 'Carla', 'Dizon', NULL, NULL);
CALL sp_register_student('USR0000001', 'diego.ramos', 'diego.ramos@studync.edu', 'Pass#Diego2026', 'Diego', 'Ramos', NULL, NULL);
CALL sp_register_student('USR0000001', 'ella.navarro', 'ella.navarro@studync.edu', 'Pass#Ella2026', 'Ella', 'Navarro', NULL, NULL);
CALL sp_register_student('USR0000001', 'felix.aquino', 'felix.aquino@studync.edu', 'Pass#Felix2026', 'Felix', 'Aquino', NULL, NULL);
CALL sp_register_student('USR0000001', 'gina.lopez', 'gina.lopez@studync.edu', 'Pass#Gina2026', 'Gina', 'Lopez', NULL, NULL);
-- gina.lopez left the institution: account deactivated (no physical delete)
CALL sp_set_user_status('USR0000001', 'USR0000012', 'Inactive');
-- carlo.mendoza also teaches: give him the Instructor role (creates INS profile)
CALL sp_assign_role('USR0000001', 'USR0000002', 'Instructor');

-- 3. Subjects (Module 2)
CALL sp_create_subject('USR0000001', 'Database Security and Administration', 'Roles, privileges, auditing, backup and recovery of relational databases.', NULL);
CALL sp_create_subject('USR0000001', 'Web Development Fundamentals', 'HTML, CSS and JavaScript for building accessible web pages.', NULL);
CALL sp_create_subject('USR0000001', 'Data Structures and Algorithms', 'Arrays, lists, trees, graphs and algorithm analysis.', NULL);
CALL sp_create_subject('USR0000001', 'Networking Essentials', 'OSI model, TCP/IP, addressing and basic network security.', NULL);
CALL sp_create_subject('USR0000001', 'Technical Writing', 'Writing clear technical documentation and reports.', NULL);
CALL sp_update_subject('USR0000001', 'SUB0000004', NULL, 'OSI model, TCP/IP, IP addressing, subnetting and basic network security.');

-- 4. Learning materials (Module 3)
CALL sp_upload_material('USR0000003', 'SUB0000001', 'Introduction to Database Security', 'materials/sub1/intro-db-security.pdf', NULL);
CALL sp_upload_material('USR0000003', 'SUB0000001', 'Managing Roles and Privileges', 'materials/sub1/roles-and-privileges.pdf', NULL);
CALL sp_upload_material('USR0000003', 'SUB0000001', 'Audit Trails with Triggers', 'materials/sub1/audit-trails.pptx', NULL);
CALL sp_upload_material('USR0000004', 'SUB0000002', 'HTML5 Document Structure', 'materials/sub2/html5-structure.pdf', NULL);
CALL sp_upload_material('USR0000004', 'SUB0000002', 'CSS Flexbox Guide', 'materials/sub2/css-flexbox.pdf', NULL);
CALL sp_upload_material('USR0000004', 'SUB0000002', 'JavaScript Basics Video', 'https://videos.studync.edu/js-basics', NULL);
CALL sp_upload_material('USR0000005', 'SUB0000003', 'Big-O Notation Lecture', 'materials/sub3/big-o.pdf', NULL);
CALL sp_upload_material('USR0000005', 'SUB0000003', 'Linked Lists Worksheet', 'materials/sub3/linked-lists.docx', NULL);
CALL sp_update_material('USR0000004', 'MAT0000005', NULL, 'CSS Flexbox and Grid Guide', 'materials/sub2/css-flexbox-grid.pdf');
-- a duplicate upload that the instructor removes again (shows DELETE auditing)
CALL sp_upload_material('USR0000005', 'SUB0000003', 'Big-O Notation Lecture (old copy)', 'materials/sub3/big-o-old.pdf', NULL);
CALL sp_delete_material('USR0000005', 'MAT0000009');

-- 5. Quizzes and questions (Module 4)
CALL sp_create_quiz('USR0000003', 'SUB0000001', 'SQL Security Basics', NULL);
CALL sp_create_quiz('USR0000003', 'SUB0000001', 'Database Roles and Privileges', NULL);
CALL sp_create_quiz('USR0000004', 'SUB0000002', 'HTML and CSS Basics', NULL);
CALL sp_create_quiz('USR0000005', 'SUB0000003', 'Big-O Notation', NULL);
CALL sp_create_quiz('USR0000004', 'SUB0000002', 'JavaScript Fundamentals', NULL);
CALL sp_add_question('USR0000003', 'QUZ0000001', 'Which SQL statement gives a privilege to a user or role?', 'REVOKE', 'GRANT', 'DENY', 'ALLOW', 'B', NULL);
CALL sp_add_question('USR0000003', 'QUZ0000001', 'Which attack inserts malicious SQL through user input?', 'Phishing', 'Brute force', 'SQL injection', 'Spoofing', 'C', NULL);
CALL sp_add_question('USR0000003', 'QUZ0000001', 'What should be stored instead of a plain-text password?', 'A salted hash', 'The password in upper case', 'An encrypted email', 'Nothing', 'A', NULL);
CALL sp_add_question('USR0000003', 'QUZ0000001', 'Which object can hide sensitive columns from users?', 'Index', 'Trigger', 'Sequence', 'View', 'D', NULL);
CALL sp_add_question('USR0000003', 'QUZ0000001', 'The principle of giving users only the access they need is called:', 'Defense in depth', 'Least privilege', 'Separation of data', 'Normalization', 'B', NULL);
CALL sp_add_question('USR0000003', 'QUZ0000002', 'Which statement removes a previously granted privilege?', 'REVOKE', 'DROP', 'DELETE', 'REMOVE', 'A', NULL);
CALL sp_add_question('USR0000003', 'QUZ0000002', 'A named group of privileges is called a:', 'Schema', 'Synonym', 'Role', 'Cursor', 'C', NULL);
CALL sp_add_question('USR0000003', 'QUZ0000002', 'Which privilege allows calling a stored procedure?', 'SELECT', 'EXECUTE', 'USAGE', 'CALL', 'B', NULL);
CALL sp_add_question('USR0000003', 'QUZ0000002', 'Which table records who changed data and when?', 'Temp table', 'Lookup table', 'Junction table', 'Audit log', 'D', NULL);
CALL sp_add_question('USR0000004', 'QUZ0000003', 'Which tag creates the largest heading?', '<head>', '<h6>', '<h1>', '<header>', 'C', NULL);
CALL sp_add_question('USR0000004', 'QUZ0000003', 'Which CSS property changes text color?', 'color', 'font-color', 'text-color', 'fg', 'A', NULL);
CALL sp_add_question('USR0000004', 'QUZ0000003', 'Which HTML element links an external stylesheet?', '<style>', '<script>', '<css>', '<link>', 'D', NULL);
CALL sp_add_question('USR0000004', 'QUZ0000003', 'Which CSS display value creates a flex container?', 'block', 'flex', 'grid-inline', 'inline', 'B', NULL);
CALL sp_add_question('USR0000005', 'QUZ0000004', 'What is the time complexity of binary search?', 'O(n)', 'O(log n)', 'O(n log n)', 'O(1)', 'B', NULL);
CALL sp_add_question('USR0000005', 'QUZ0000004', 'Accessing an array element by index is:', 'O(1)', 'O(n)', 'O(log n)', 'O(n^2)', 'A', NULL);
CALL sp_add_question('USR0000005', 'QUZ0000004', 'A nested loop over n items is usually:', 'O(n)', 'O(log n)', 'O(n^2)', 'O(1)', 'C', NULL);
CALL sp_add_question('USR0000004', 'QUZ0000005', 'Which keyword declares a block-scoped variable?', 'let', 'var', 'def', 'dim', 'A', NULL);
CALL sp_add_question('USR0000004', 'QUZ0000005', 'Which method prints to the browser console?', 'print()', 'echo()', 'write()', 'console.log()', 'D', NULL);
CALL sp_add_question('USR0000004', 'QUZ0000005', 'What does === compare?', 'Value only', 'Value and type', 'Reference only', 'Length', 'B', NULL);
CALL sp_update_quiz('USR0000005', 'QUZ0000004', NULL, 'Big-O Notation Quiz');

-- 6. Students answer and submit quizzes (Module 5)
CALL sp_submit_answer('USR0000006', 'QST0000001', 'B', NULL);
CALL sp_submit_answer('USR0000006', 'QST0000002', 'C', NULL);
CALL sp_submit_answer('USR0000006', 'QST0000003', 'A', NULL);
CALL sp_submit_answer('USR0000006', 'QST0000004', 'D', NULL);
CALL sp_submit_answer('USR0000006', 'QST0000005', 'B', NULL);
CALL sp_submit_quiz('USR0000006', 'QUZ0000001', NULL, NULL);
CALL sp_submit_answer('USR0000007', 'QST0000001', 'B', NULL);
CALL sp_submit_answer('USR0000007', 'QST0000002', 'C', NULL);
CALL sp_submit_answer('USR0000007', 'QST0000003', 'A', NULL);
CALL sp_submit_answer('USR0000007', 'QST0000004', 'D', NULL);
CALL sp_submit_answer('USR0000007', 'QST0000005', 'A', NULL);
CALL sp_submit_quiz('USR0000007', 'QUZ0000001', NULL, NULL);
CALL sp_submit_answer('USR0000008', 'QST0000001', 'B', NULL);
CALL sp_submit_answer('USR0000008', 'QST0000002', 'C', NULL);
CALL sp_submit_answer('USR0000008', 'QST0000003', 'A', NULL);
CALL sp_submit_answer('USR0000008', 'QST0000004', 'A', NULL);
CALL sp_submit_answer('USR0000008', 'QST0000005', 'C', NULL);
CALL sp_submit_quiz('USR0000008', 'QUZ0000001', NULL, NULL);
CALL sp_submit_answer('USR0000009', 'QST0000001', 'A', NULL);
CALL sp_submit_answer('USR0000009', 'QST0000002', 'C', NULL);
CALL sp_submit_answer('USR0000009', 'QST0000003', 'D', NULL);
CALL sp_submit_answer('USR0000009', 'QST0000004', 'D', NULL);
CALL sp_submit_quiz('USR0000009', 'QUZ0000001', NULL, NULL);
CALL sp_submit_answer('USR0000006', 'QST0000006', 'A', NULL);
CALL sp_submit_answer('USR0000006', 'QST0000007', 'C', NULL);
CALL sp_submit_answer('USR0000006', 'QST0000008', 'B', NULL);
CALL sp_submit_answer('USR0000006', 'QST0000009', 'A', NULL);
CALL sp_submit_quiz('USR0000006', 'QUZ0000002', NULL, NULL);
CALL sp_submit_answer('USR0000007', 'QST0000006', 'A', NULL);
CALL sp_submit_answer('USR0000007', 'QST0000007', 'C', NULL);
CALL sp_submit_answer('USR0000007', 'QST0000008', 'B', NULL);
CALL sp_submit_answer('USR0000007', 'QST0000009', 'D', NULL);
CALL sp_submit_quiz('USR0000007', 'QUZ0000002', NULL, NULL);
CALL sp_submit_answer('USR0000010', 'QST0000006', 'A', NULL);
CALL sp_submit_answer('USR0000010', 'QST0000007', 'A', NULL);
CALL sp_submit_answer('USR0000010', 'QST0000008', 'B', NULL);
CALL sp_submit_answer('USR0000010', 'QST0000009', 'A', NULL);
CALL sp_submit_quiz('USR0000010', 'QUZ0000002', NULL, NULL);
CALL sp_submit_answer('USR0000008', 'QST0000010', 'C', NULL);
CALL sp_submit_answer('USR0000008', 'QST0000011', 'A', NULL);
CALL sp_submit_answer('USR0000008', 'QST0000012', 'D', NULL);
CALL sp_submit_answer('USR0000008', 'QST0000013', 'B', NULL);
CALL sp_submit_quiz('USR0000008', 'QUZ0000003', NULL, NULL);
CALL sp_submit_answer('USR0000011', 'QST0000010', 'A', NULL);
CALL sp_submit_answer('USR0000011', 'QST0000011', 'A', NULL);
CALL sp_submit_answer('USR0000011', 'QST0000012', 'A', NULL);
CALL sp_submit_answer('USR0000011', 'QST0000013', 'A', NULL);
CALL sp_submit_quiz('USR0000011', 'QUZ0000003', NULL, NULL);
CALL sp_submit_answer('USR0000006', 'QST0000010', 'C', NULL);
CALL sp_submit_answer('USR0000006', 'QST0000011', 'A', NULL);
CALL sp_submit_answer('USR0000006', 'QST0000012', 'D', NULL);
CALL sp_submit_answer('USR0000006', 'QST0000013', 'C', NULL);
CALL sp_submit_quiz('USR0000006', 'QUZ0000003', NULL, NULL);
CALL sp_submit_answer('USR0000009', 'QST0000014', 'B', NULL);
CALL sp_submit_answer('USR0000009', 'QST0000015', 'A', NULL);
CALL sp_submit_answer('USR0000009', 'QST0000016', 'C', NULL);
CALL sp_submit_quiz('USR0000009', 'QUZ0000004', NULL, NULL);
CALL sp_submit_answer('USR0000010', 'QST0000014', 'B', NULL);
CALL sp_submit_answer('USR0000010', 'QST0000015', 'A', NULL);
CALL sp_submit_answer('USR0000010', 'QST0000016', 'D', NULL);
CALL sp_submit_quiz('USR0000010', 'QUZ0000004', NULL, NULL);

-- 7. Login activity (Module 6 monitoring data)
CALL sp_authenticate_user('ana.santos', 'Pass#Ana2026', NULL, NULL, NULL, NULL);
CALL sp_authenticate_user('ben.torres', 'wrong-password', NULL, NULL, NULL, NULL);
CALL sp_authenticate_user('gina.lopez', 'Pass#Gina2026', NULL, NULL, NULL, NULL);

-- row counts
SELECT 'users' AS table_name, count(*) AS row_count FROM users
UNION ALL SELECT 'roles', count(*) FROM roles
UNION ALL SELECT 'user_roles', count(*) FROM user_roles
UNION ALL SELECT 'admins', count(*) FROM admins
UNION ALL SELECT 'instructors', count(*) FROM instructors
UNION ALL SELECT 'students', count(*) FROM students
UNION ALL SELECT 'subjects', count(*) FROM subjects
UNION ALL SELECT 'materials', count(*) FROM materials
UNION ALL SELECT 'quizzes', count(*) FROM quizzes
UNION ALL SELECT 'questions', count(*) FROM questions
UNION ALL SELECT 'student_answers', count(*) FROM student_answers
UNION ALL SELECT 'quiz_results', count(*) FROM quiz_results
UNION ALL SELECT 'audit_logs', count(*) FROM audit_logs;

SELECT result_id, student_name, quiz_title, score, correct_answers, total_questions
FROM v_quiz_results_detail ORDER BY result_id;
