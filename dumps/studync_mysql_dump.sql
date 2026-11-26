-- MySQL dump 10.13  Distrib 9.4.0, for Win64 (x86_64)
--
-- Host: 127.0.0.1    Database: studync_db
-- ------------------------------------------------------
-- Server version	9.4.0

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Current Database: `studync_db`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `studync_db` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;

USE `studync_db`;

--
-- Table structure for table `admins`
--

DROP TABLE IF EXISTS `admins`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `admins` (
  `admin_id` varchar(10) NOT NULL COMMENT 'Format ADM0000001',
  `user_id` varchar(10) NOT NULL,
  `first_name` varchar(50) NOT NULL,
  `last_name` varchar(50) NOT NULL,
  PRIMARY KEY (`admin_id`),
  UNIQUE KEY `uq_admins_user_id` (`user_id`),
  CONSTRAINT `fk_admins_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_admins_id_format` CHECK (regexp_like(`admin_id`,_utf8mb4'^ADM[0-9]{7}$',_utf8mb4'c')),
  CONSTRAINT `ck_admins_names` CHECK (((trim(`first_name`) <> _utf8mb4'') and (trim(`last_name`) <> _utf8mb4'')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `admins`
--

LOCK TABLES `admins` WRITE;
/*!40000 ALTER TABLE `admins` DISABLE KEYS */;
INSERT INTO `admins` VALUES ('ADM0000001','USR0000001','Maria','Reyes'),('ADM0000002','USR0000002','Carlo','Mendoza'),('ADM0000003','USR0000014','Paolo','Lim');
/*!40000 ALTER TABLE `admins` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_admins_audit_ins` AFTER INSERT ON `admins` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'admins', NEW.admin_id, @app_user_id, USER(),
            CONCAT('Created admins record ', NEW.admin_id), NULL,
            JSON_OBJECT('admin_id', NEW.admin_id, 'user_id', NEW.user_id, 'first_name', NEW.first_name, 'last_name', NEW.last_name));
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_admins_audit_upd` AFTER UPDATE ON `admins` FOR EACH ROW BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.admin_id <=> NEW.admin_id) OR NOT (OLD.user_id <=> NEW.user_id) OR NOT (OLD.first_name <=> NEW.first_name) OR NOT (OLD.last_name <=> NEW.last_name) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'admins', NEW.admin_id, @app_user_id, USER(),
                CONCAT('Updated admins record ', NEW.admin_id),
                JSON_OBJECT('admin_id', OLD.admin_id, 'user_id', OLD.user_id, 'first_name', OLD.first_name, 'last_name', OLD.last_name),
                JSON_OBJECT('admin_id', NEW.admin_id, 'user_id', NEW.user_id, 'first_name', NEW.first_name, 'last_name', NEW.last_name));
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_admins_audit_del` AFTER DELETE ON `admins` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'admins', OLD.admin_id, @app_user_id, USER(),
            CONCAT('Deleted admins record ', OLD.admin_id),
            JSON_OBJECT('admin_id', OLD.admin_id, 'user_id', OLD.user_id, 'first_name', OLD.first_name, 'last_name', OLD.last_name), NULL);
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `audit_logs`
--

DROP TABLE IF EXISTS `audit_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `audit_logs` (
  `log_id` int NOT NULL AUTO_INCREMENT,
  `action_type` varchar(50) NOT NULL,
  `table_name` varchar(50) NOT NULL,
  `record_id` varchar(50) DEFAULT NULL,
  `performed_by` varchar(10) DEFAULT NULL COMMENT 'Application user_id passed via @app_user_id',
  `db_user` varchar(100) NOT NULL COMMENT 'MySQL account that ran the statement',
  `description` text,
  `old_data` json DEFAULT NULL,
  `new_data` json DEFAULT NULL,
  `log_timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`log_id`),
  KEY `ix_audit_logs_table_time` (`table_name`,`log_timestamp`),
  KEY `ix_audit_logs_performed_by` (`performed_by`,`log_timestamp`),
  KEY `ix_audit_logs_time` (`log_timestamp`),
  CONSTRAINT `ck_audit_logs_action_type` CHECK ((`action_type` in (_utf8mb4'INSERT',_utf8mb4'UPDATE',_utf8mb4'DELETE',_utf8mb4'LOGIN_SUCCESS',_utf8mb4'LOGIN_FAILED')))
) ENGINE=InnoDB AUTO_INCREMENT=184 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `audit_logs`
--

LOCK TABLES `audit_logs` WRITE;
/*!40000 ALTER TABLE `audit_logs` DISABLE KEYS */;
INSERT INTO `audit_logs` VALUES (1,'INSERT','users','USR0000001',NULL,'root@localhost','Created users record USR0000001',NULL,'{\"email\": \"maria.reyes@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000001\", \"username\": \"maria.reyes\", \"created_at\": \"2026-11-25 07:31:59.000000\"}','2026-11-24 23:31:59'),(2,'INSERT','user_roles','USR0000001:ROL0000001',NULL,'root@localhost','Created user_roles record USR0000001:ROL0000001',NULL,'{\"role_id\": \"ROL0000001\", \"user_id\": \"USR0000001\"}','2026-11-24 23:31:59'),(3,'INSERT','admins','ADM0000001',NULL,'root@localhost','Created admins record ADM0000001',NULL,'{\"user_id\": \"USR0000001\", \"admin_id\": \"ADM0000001\", \"last_name\": \"Reyes\", \"first_name\": \"Maria\"}','2026-11-24 23:31:59'),(4,'INSERT','users','USR0000002',NULL,'root@localhost','Created users record USR0000002',NULL,'{\"email\": \"carlo.mendoza@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000002\", \"username\": \"carlo.mendoza\", \"created_at\": \"2026-11-25 07:31:59.000000\"}','2026-11-24 23:31:59'),(5,'INSERT','user_roles','USR0000002:ROL0000001',NULL,'root@localhost','Created user_roles record USR0000002:ROL0000001',NULL,'{\"role_id\": \"ROL0000001\", \"user_id\": \"USR0000002\"}','2026-11-24 23:31:59'),(6,'INSERT','admins','ADM0000002',NULL,'root@localhost','Created admins record ADM0000002',NULL,'{\"user_id\": \"USR0000002\", \"admin_id\": \"ADM0000002\", \"last_name\": \"Mendoza\", \"first_name\": \"Carlo\"}','2026-11-24 23:31:59'),(7,'INSERT','users','USR0000003','USR0000001','root@localhost','Created users record USR0000003',NULL,'{\"email\": \"jose.cruz@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000003\", \"username\": \"jose.cruz\", \"created_at\": \"2026-11-25 07:31:59.000000\"}','2026-11-24 23:31:59'),(8,'INSERT','user_roles','USR0000003:ROL0000002','USR0000001','root@localhost','Created user_roles record USR0000003:ROL0000002',NULL,'{\"role_id\": \"ROL0000002\", \"user_id\": \"USR0000003\"}','2026-11-24 23:31:59'),(9,'INSERT','instructors','INS0000001','USR0000001','root@localhost','Created instructors record INS0000001',NULL,'{\"user_id\": \"USR0000003\", \"last_name\": \"Cruz\", \"first_name\": \"Jose\", \"instructor_id\": \"INS0000001\"}','2026-11-24 23:31:59'),(10,'INSERT','users','USR0000004','USR0000001','root@localhost','Created users record USR0000004',NULL,'{\"email\": \"liza.garcia@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000004\", \"username\": \"liza.garcia\", \"created_at\": \"2026-11-25 07:31:59.000000\"}','2026-11-24 23:31:59'),(11,'INSERT','user_roles','USR0000004:ROL0000002','USR0000001','root@localhost','Created user_roles record USR0000004:ROL0000002',NULL,'{\"role_id\": \"ROL0000002\", \"user_id\": \"USR0000004\"}','2026-11-24 23:31:59'),(12,'INSERT','instructors','INS0000002','USR0000001','root@localhost','Created instructors record INS0000002',NULL,'{\"user_id\": \"USR0000004\", \"last_name\": \"Garcia\", \"first_name\": \"Liza\", \"instructor_id\": \"INS0000002\"}','2026-11-24 23:31:59'),(13,'INSERT','users','USR0000005','USR0000001','root@localhost','Created users record USR0000005',NULL,'{\"email\": \"ramon.villanueva@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000005\", \"username\": \"ramon.villanueva\", \"created_at\": \"2026-11-25 07:31:59.000000\"}','2026-11-24 23:31:59'),(14,'INSERT','user_roles','USR0000005:ROL0000002','USR0000001','root@localhost','Created user_roles record USR0000005:ROL0000002',NULL,'{\"role_id\": \"ROL0000002\", \"user_id\": \"USR0000005\"}','2026-11-24 23:31:59'),(15,'INSERT','instructors','INS0000003','USR0000001','root@localhost','Created instructors record INS0000003',NULL,'{\"user_id\": \"USR0000005\", \"last_name\": \"Villanueva\", \"first_name\": \"Ramon\", \"instructor_id\": \"INS0000003\"}','2026-11-24 23:31:59'),(16,'INSERT','users','USR0000006','USR0000001','root@localhost','Created users record USR0000006',NULL,'{\"email\": \"ana.santos@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000006\", \"username\": \"ana.santos\", \"created_at\": \"2026-11-25 07:31:59.000000\"}','2026-11-24 23:31:59'),(17,'INSERT','user_roles','USR0000006:ROL0000003','USR0000001','root@localhost','Created user_roles record USR0000006:ROL0000003',NULL,'{\"role_id\": \"ROL0000003\", \"user_id\": \"USR0000006\"}','2026-11-24 23:31:59'),(18,'INSERT','students','STU0000001','USR0000001','root@localhost','Created students record STU0000001',NULL,'{\"user_id\": \"USR0000006\", \"last_name\": \"Santos\", \"first_name\": \"Ana\", \"student_id\": \"STU0000001\"}','2026-11-24 23:31:59'),(19,'INSERT','users','USR0000007','USR0000001','root@localhost','Created users record USR0000007',NULL,'{\"email\": \"ben.torres@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000007\", \"username\": \"ben.torres\", \"created_at\": \"2026-11-25 07:31:59.000000\"}','2026-11-24 23:31:59'),(20,'INSERT','user_roles','USR0000007:ROL0000003','USR0000001','root@localhost','Created user_roles record USR0000007:ROL0000003',NULL,'{\"role_id\": \"ROL0000003\", \"user_id\": \"USR0000007\"}','2026-11-24 23:31:59'),(21,'INSERT','students','STU0000002','USR0000001','root@localhost','Created students record STU0000002',NULL,'{\"user_id\": \"USR0000007\", \"last_name\": \"Torres\", \"first_name\": \"Ben\", \"student_id\": \"STU0000002\"}','2026-11-24 23:31:59'),(22,'INSERT','users','USR0000008','USR0000001','root@localhost','Created users record USR0000008',NULL,'{\"email\": \"carla.dizon@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000008\", \"username\": \"carla.dizon\", \"created_at\": \"2026-11-25 07:31:59.000000\"}','2026-11-24 23:31:59'),(23,'INSERT','user_roles','USR0000008:ROL0000003','USR0000001','root@localhost','Created user_roles record USR0000008:ROL0000003',NULL,'{\"role_id\": \"ROL0000003\", \"user_id\": \"USR0000008\"}','2026-11-24 23:31:59'),(24,'INSERT','students','STU0000003','USR0000001','root@localhost','Created students record STU0000003',NULL,'{\"user_id\": \"USR0000008\", \"last_name\": \"Dizon\", \"first_name\": \"Carla\", \"student_id\": \"STU0000003\"}','2026-11-24 23:31:59'),(25,'INSERT','users','USR0000009','USR0000001','root@localhost','Created users record USR0000009',NULL,'{\"email\": \"diego.ramos@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000009\", \"username\": \"diego.ramos\", \"created_at\": \"2026-11-25 07:31:59.000000\"}','2026-11-24 23:31:59'),(26,'INSERT','user_roles','USR0000009:ROL0000003','USR0000001','root@localhost','Created user_roles record USR0000009:ROL0000003',NULL,'{\"role_id\": \"ROL0000003\", \"user_id\": \"USR0000009\"}','2026-11-24 23:31:59'),(27,'INSERT','students','STU0000004','USR0000001','root@localhost','Created students record STU0000004',NULL,'{\"user_id\": \"USR0000009\", \"last_name\": \"Ramos\", \"first_name\": \"Diego\", \"student_id\": \"STU0000004\"}','2026-11-24 23:31:59'),(28,'INSERT','users','USR0000010','USR0000001','root@localhost','Created users record USR0000010',NULL,'{\"email\": \"ella.navarro@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000010\", \"username\": \"ella.navarro\", \"created_at\": \"2026-11-25 07:31:59.000000\"}','2026-11-24 23:31:59'),(29,'INSERT','user_roles','USR0000010:ROL0000003','USR0000001','root@localhost','Created user_roles record USR0000010:ROL0000003',NULL,'{\"role_id\": \"ROL0000003\", \"user_id\": \"USR0000010\"}','2026-11-24 23:31:59'),(30,'INSERT','students','STU0000005','USR0000001','root@localhost','Created students record STU0000005',NULL,'{\"user_id\": \"USR0000010\", \"last_name\": \"Navarro\", \"first_name\": \"Ella\", \"student_id\": \"STU0000005\"}','2026-11-24 23:31:59'),(31,'INSERT','users','USR0000011','USR0000001','root@localhost','Created users record USR0000011',NULL,'{\"email\": \"felix.aquino@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000011\", \"username\": \"felix.aquino\", \"created_at\": \"2026-11-25 07:31:59.000000\"}','2026-11-24 23:31:59'),(32,'INSERT','user_roles','USR0000011:ROL0000003','USR0000001','root@localhost','Created user_roles record USR0000011:ROL0000003',NULL,'{\"role_id\": \"ROL0000003\", \"user_id\": \"USR0000011\"}','2026-11-24 23:31:59'),(33,'INSERT','students','STU0000006','USR0000001','root@localhost','Created students record STU0000006',NULL,'{\"user_id\": \"USR0000011\", \"last_name\": \"Aquino\", \"first_name\": \"Felix\", \"student_id\": \"STU0000006\"}','2026-11-24 23:31:59'),(34,'INSERT','users','USR0000012','USR0000001','root@localhost','Created users record USR0000012',NULL,'{\"email\": \"gina.lopez@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000012\", \"username\": \"gina.lopez\", \"created_at\": \"2026-11-25 07:31:59.000000\"}','2026-11-24 23:31:59'),(35,'INSERT','user_roles','USR0000012:ROL0000003','USR0000001','root@localhost','Created user_roles record USR0000012:ROL0000003',NULL,'{\"role_id\": \"ROL0000003\", \"user_id\": \"USR0000012\"}','2026-11-24 23:31:59'),(36,'INSERT','students','STU0000007','USR0000001','root@localhost','Created students record STU0000007',NULL,'{\"user_id\": \"USR0000012\", \"last_name\": \"Lopez\", \"first_name\": \"Gina\", \"student_id\": \"STU0000007\"}','2026-11-24 23:31:59'),(37,'UPDATE','users','USR0000012','USR0000001','root@localhost','Updated users record USR0000012','{\"email\": \"gina.lopez@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000012\", \"username\": \"gina.lopez\", \"created_at\": \"2026-11-25 07:31:59.000000\"}','{\"email\": \"gina.lopez@studync.edu\", \"status\": \"Inactive\", \"user_id\": \"USR0000012\", \"username\": \"gina.lopez\", \"created_at\": \"2026-11-25 07:31:59.000000\", \"password_changed\": false}','2026-11-24 23:31:59'),(38,'INSERT','user_roles','USR0000002:ROL0000002','USR0000001','root@localhost','Created user_roles record USR0000002:ROL0000002',NULL,'{\"role_id\": \"ROL0000002\", \"user_id\": \"USR0000002\"}','2026-11-24 23:31:59'),(39,'INSERT','instructors','INS0000004','USR0000001','root@localhost','Created instructors record INS0000004',NULL,'{\"user_id\": \"USR0000002\", \"last_name\": \"Mendoza\", \"first_name\": \"Carlo\", \"instructor_id\": \"INS0000004\"}','2026-11-24 23:31:59'),(40,'INSERT','subjects','SUB0000001','USR0000001','root@localhost','Created subjects record SUB0000001',NULL,'{\"subject_id\": \"SUB0000001\", \"description\": \"Roles, privileges, auditing, backup and recovery of relational databases.\", \"subject_name\": \"Database Security and Administration\"}','2026-11-24 23:31:59'),(41,'INSERT','subjects','SUB0000002','USR0000001','root@localhost','Created subjects record SUB0000002',NULL,'{\"subject_id\": \"SUB0000002\", \"description\": \"HTML, CSS and JavaScript for building accessible web pages.\", \"subject_name\": \"Web Development Fundamentals\"}','2026-11-24 23:31:59'),(42,'INSERT','subjects','SUB0000003','USR0000001','root@localhost','Created subjects record SUB0000003',NULL,'{\"subject_id\": \"SUB0000003\", \"description\": \"Arrays, lists, trees, graphs and algorithm analysis.\", \"subject_name\": \"Data Structures and Algorithms\"}','2026-11-24 23:31:59'),(43,'INSERT','subjects','SUB0000004','USR0000001','root@localhost','Created subjects record SUB0000004',NULL,'{\"subject_id\": \"SUB0000004\", \"description\": \"OSI model, TCP/IP, addressing and basic network security.\", \"subject_name\": \"Networking Essentials\"}','2026-11-24 23:31:59'),(44,'INSERT','subjects','SUB0000005','USR0000001','root@localhost','Created subjects record SUB0000005',NULL,'{\"subject_id\": \"SUB0000005\", \"description\": \"Writing clear technical documentation and reports.\", \"subject_name\": \"Technical Writing\"}','2026-11-24 23:31:59'),(45,'UPDATE','subjects','SUB0000004','USR0000001','root@localhost','Updated subjects record SUB0000004','{\"subject_id\": \"SUB0000004\", \"description\": \"OSI model, TCP/IP, addressing and basic network security.\", \"subject_name\": \"Networking Essentials\"}','{\"subject_id\": \"SUB0000004\", \"description\": \"OSI model, TCP/IP, IP addressing, subnetting and basic network security.\", \"subject_name\": \"Networking Essentials\"}','2026-11-24 23:31:59'),(46,'INSERT','materials','MAT0000001','USR0000003','root@localhost','Created materials record MAT0000001',NULL,'{\"title\": \"Introduction to Database Security\", \"file_path\": \"materials/sub1/intro-db-security.pdf\", \"subject_id\": \"SUB0000001\", \"material_id\": \"MAT0000001\", \"uploaded_at\": \"2026-11-25 07:31:59.000000\", \"instructor_id\": \"INS0000001\"}','2026-11-24 23:31:59'),(47,'INSERT','materials','MAT0000002','USR0000003','root@localhost','Created materials record MAT0000002',NULL,'{\"title\": \"Managing Roles and Privileges\", \"file_path\": \"materials/sub1/roles-and-privileges.pdf\", \"subject_id\": \"SUB0000001\", \"material_id\": \"MAT0000002\", \"uploaded_at\": \"2026-11-25 07:31:59.000000\", \"instructor_id\": \"INS0000001\"}','2026-11-24 23:31:59'),(48,'INSERT','materials','MAT0000003','USR0000003','root@localhost','Created materials record MAT0000003',NULL,'{\"title\": \"Audit Trails with Triggers\", \"file_path\": \"materials/sub1/audit-trails.pptx\", \"subject_id\": \"SUB0000001\", \"material_id\": \"MAT0000003\", \"uploaded_at\": \"2026-11-25 07:31:59.000000\", \"instructor_id\": \"INS0000001\"}','2026-11-24 23:31:59'),(49,'INSERT','materials','MAT0000004','USR0000004','root@localhost','Created materials record MAT0000004',NULL,'{\"title\": \"HTML5 Document Structure\", \"file_path\": \"materials/sub2/html5-structure.pdf\", \"subject_id\": \"SUB0000002\", \"material_id\": \"MAT0000004\", \"uploaded_at\": \"2026-11-25 07:31:59.000000\", \"instructor_id\": \"INS0000002\"}','2026-11-24 23:31:59'),(50,'INSERT','materials','MAT0000005','USR0000004','root@localhost','Created materials record MAT0000005',NULL,'{\"title\": \"CSS Flexbox Guide\", \"file_path\": \"materials/sub2/css-flexbox.pdf\", \"subject_id\": \"SUB0000002\", \"material_id\": \"MAT0000005\", \"uploaded_at\": \"2026-11-25 07:31:59.000000\", \"instructor_id\": \"INS0000002\"}','2026-11-24 23:31:59'),(51,'INSERT','materials','MAT0000006','USR0000004','root@localhost','Created materials record MAT0000006',NULL,'{\"title\": \"JavaScript Basics Video\", \"file_path\": \"https://videos.studync.edu/js-basics\", \"subject_id\": \"SUB0000002\", \"material_id\": \"MAT0000006\", \"uploaded_at\": \"2026-11-25 07:31:59.000000\", \"instructor_id\": \"INS0000002\"}','2026-11-24 23:31:59'),(52,'INSERT','materials','MAT0000007','USR0000005','root@localhost','Created materials record MAT0000007',NULL,'{\"title\": \"Big-O Notation Lecture\", \"file_path\": \"materials/sub3/big-o.pdf\", \"subject_id\": \"SUB0000003\", \"material_id\": \"MAT0000007\", \"uploaded_at\": \"2026-11-25 07:31:59.000000\", \"instructor_id\": \"INS0000003\"}','2026-11-24 23:31:59'),(53,'INSERT','materials','MAT0000008','USR0000005','root@localhost','Created materials record MAT0000008',NULL,'{\"title\": \"Linked Lists Worksheet\", \"file_path\": \"materials/sub3/linked-lists.docx\", \"subject_id\": \"SUB0000003\", \"material_id\": \"MAT0000008\", \"uploaded_at\": \"2026-11-25 07:31:59.000000\", \"instructor_id\": \"INS0000003\"}','2026-11-24 23:31:59'),(54,'UPDATE','materials','MAT0000005','USR0000004','root@localhost','Updated materials record MAT0000005','{\"title\": \"CSS Flexbox Guide\", \"file_path\": \"materials/sub2/css-flexbox.pdf\", \"subject_id\": \"SUB0000002\", \"material_id\": \"MAT0000005\", \"uploaded_at\": \"2026-11-25 07:31:59.000000\", \"instructor_id\": \"INS0000002\"}','{\"title\": \"CSS Flexbox and Grid Guide\", \"file_path\": \"materials/sub2/css-flexbox-grid.pdf\", \"subject_id\": \"SUB0000002\", \"material_id\": \"MAT0000005\", \"uploaded_at\": \"2026-11-25 07:31:59.000000\", \"instructor_id\": \"INS0000002\"}','2026-11-24 23:31:59'),(55,'INSERT','materials','MAT0000009','USR0000005','root@localhost','Created materials record MAT0000009',NULL,'{\"title\": \"Big-O Notation Lecture (old copy)\", \"file_path\": \"materials/sub3/big-o-old.pdf\", \"subject_id\": \"SUB0000003\", \"material_id\": \"MAT0000009\", \"uploaded_at\": \"2026-11-25 07:31:59.000000\", \"instructor_id\": \"INS0000003\"}','2026-11-24 23:31:59'),(56,'DELETE','materials','MAT0000009','USR0000005','root@localhost','Deleted materials record MAT0000009','{\"title\": \"Big-O Notation Lecture (old copy)\", \"file_path\": \"materials/sub3/big-o-old.pdf\", \"subject_id\": \"SUB0000003\", \"material_id\": \"MAT0000009\", \"uploaded_at\": \"2026-11-25 07:31:59.000000\", \"instructor_id\": \"INS0000003\"}',NULL,'2026-11-24 23:31:59'),(57,'INSERT','quizzes','QUZ0000001','USR0000003','root@localhost','Created quizzes record QUZ0000001',NULL,'{\"title\": \"SQL Security Basics\", \"quiz_id\": \"QUZ0000001\", \"created_at\": \"2026-11-25 07:31:59.000000\", \"subject_id\": \"SUB0000001\", \"instructor_id\": \"INS0000001\"}','2026-11-24 23:31:59'),(58,'INSERT','quizzes','QUZ0000002','USR0000003','root@localhost','Created quizzes record QUZ0000002',NULL,'{\"title\": \"Database Roles and Privileges\", \"quiz_id\": \"QUZ0000002\", \"created_at\": \"2026-11-25 07:31:59.000000\", \"subject_id\": \"SUB0000001\", \"instructor_id\": \"INS0000001\"}','2026-11-24 23:31:59'),(59,'INSERT','quizzes','QUZ0000003','USR0000004','root@localhost','Created quizzes record QUZ0000003',NULL,'{\"title\": \"HTML and CSS Basics\", \"quiz_id\": \"QUZ0000003\", \"created_at\": \"2026-11-25 07:31:59.000000\", \"subject_id\": \"SUB0000002\", \"instructor_id\": \"INS0000002\"}','2026-11-24 23:31:59'),(60,'INSERT','quizzes','QUZ0000004','USR0000005','root@localhost','Created quizzes record QUZ0000004',NULL,'{\"title\": \"Big-O Notation\", \"quiz_id\": \"QUZ0000004\", \"created_at\": \"2026-11-25 07:31:59.000000\", \"subject_id\": \"SUB0000003\", \"instructor_id\": \"INS0000003\"}','2026-11-24 23:31:59'),(61,'INSERT','quizzes','QUZ0000005','USR0000004','root@localhost','Created quizzes record QUZ0000005',NULL,'{\"title\": \"JavaScript Fundamentals\", \"quiz_id\": \"QUZ0000005\", \"created_at\": \"2026-11-25 07:31:59.000000\", \"subject_id\": \"SUB0000002\", \"instructor_id\": \"INS0000002\"}','2026-11-24 23:31:59'),(62,'INSERT','questions','QST0000001','USR0000003','root@localhost','Created questions record QST0000001',NULL,'{\"quiz_id\": \"QUZ0000001\", \"option_a\": \"REVOKE\", \"option_b\": \"GRANT\", \"option_c\": \"DENY\", \"option_d\": \"ALLOW\", \"question_id\": \"QST0000001\", \"question_text\": \"Which SQL statement gives a privilege to a user or role?\", \"correct_answer\": \"GRANT\"}','2026-11-24 23:31:59'),(63,'INSERT','questions','QST0000002','USR0000003','root@localhost','Created questions record QST0000002',NULL,'{\"quiz_id\": \"QUZ0000001\", \"option_a\": \"Phishing\", \"option_b\": \"Brute force\", \"option_c\": \"SQL injection\", \"option_d\": \"Spoofing\", \"question_id\": \"QST0000002\", \"question_text\": \"Which attack inserts malicious SQL through user input?\", \"correct_answer\": \"SQL injection\"}','2026-11-24 23:31:59'),(64,'INSERT','questions','QST0000003','USR0000003','root@localhost','Created questions record QST0000003',NULL,'{\"quiz_id\": \"QUZ0000001\", \"option_a\": \"A salted hash\", \"option_b\": \"The password in upper case\", \"option_c\": \"An encrypted email\", \"option_d\": \"Nothing\", \"question_id\": \"QST0000003\", \"question_text\": \"What should be stored instead of a plain-text password?\", \"correct_answer\": \"A salted hash\"}','2026-11-24 23:31:59'),(65,'INSERT','questions','QST0000004','USR0000003','root@localhost','Created questions record QST0000004',NULL,'{\"quiz_id\": \"QUZ0000001\", \"option_a\": \"Index\", \"option_b\": \"Trigger\", \"option_c\": \"Sequence\", \"option_d\": \"View\", \"question_id\": \"QST0000004\", \"question_text\": \"Which object can hide sensitive columns from users?\", \"correct_answer\": \"View\"}','2026-11-24 23:31:59'),(66,'INSERT','questions','QST0000005','USR0000003','root@localhost','Created questions record QST0000005',NULL,'{\"quiz_id\": \"QUZ0000001\", \"option_a\": \"Defense in depth\", \"option_b\": \"Least privilege\", \"option_c\": \"Separation of data\", \"option_d\": \"Normalization\", \"question_id\": \"QST0000005\", \"question_text\": \"The principle of giving users only the access they need is called:\", \"correct_answer\": \"Least privilege\"}','2026-11-24 23:31:59'),(67,'INSERT','questions','QST0000006','USR0000003','root@localhost','Created questions record QST0000006',NULL,'{\"quiz_id\": \"QUZ0000002\", \"option_a\": \"REVOKE\", \"option_b\": \"DROP\", \"option_c\": \"DELETE\", \"option_d\": \"REMOVE\", \"question_id\": \"QST0000006\", \"question_text\": \"Which statement removes a previously granted privilege?\", \"correct_answer\": \"REVOKE\"}','2026-11-24 23:31:59'),(68,'INSERT','questions','QST0000007','USR0000003','root@localhost','Created questions record QST0000007',NULL,'{\"quiz_id\": \"QUZ0000002\", \"option_a\": \"Schema\", \"option_b\": \"Synonym\", \"option_c\": \"Role\", \"option_d\": \"Cursor\", \"question_id\": \"QST0000007\", \"question_text\": \"A named group of privileges is called a:\", \"correct_answer\": \"Role\"}','2026-11-24 23:31:59'),(69,'INSERT','questions','QST0000008','USR0000003','root@localhost','Created questions record QST0000008',NULL,'{\"quiz_id\": \"QUZ0000002\", \"option_a\": \"SELECT\", \"option_b\": \"EXECUTE\", \"option_c\": \"USAGE\", \"option_d\": \"CALL\", \"question_id\": \"QST0000008\", \"question_text\": \"Which privilege allows calling a stored procedure?\", \"correct_answer\": \"EXECUTE\"}','2026-11-24 23:31:59'),(70,'INSERT','questions','QST0000009','USR0000003','root@localhost','Created questions record QST0000009',NULL,'{\"quiz_id\": \"QUZ0000002\", \"option_a\": \"Temp table\", \"option_b\": \"Lookup table\", \"option_c\": \"Junction table\", \"option_d\": \"Audit log\", \"question_id\": \"QST0000009\", \"question_text\": \"Which table records who changed data and when?\", \"correct_answer\": \"Audit log\"}','2026-11-24 23:31:59'),(71,'INSERT','questions','QST0000010','USR0000004','root@localhost','Created questions record QST0000010',NULL,'{\"quiz_id\": \"QUZ0000003\", \"option_a\": \"<head>\", \"option_b\": \"<h6>\", \"option_c\": \"<h1>\", \"option_d\": \"<header>\", \"question_id\": \"QST0000010\", \"question_text\": \"Which tag creates the largest heading?\", \"correct_answer\": \"<h1>\"}','2026-11-24 23:31:59'),(72,'INSERT','questions','QST0000011','USR0000004','root@localhost','Created questions record QST0000011',NULL,'{\"quiz_id\": \"QUZ0000003\", \"option_a\": \"color\", \"option_b\": \"font-color\", \"option_c\": \"text-color\", \"option_d\": \"fg\", \"question_id\": \"QST0000011\", \"question_text\": \"Which CSS property changes text color?\", \"correct_answer\": \"color\"}','2026-11-24 23:31:59'),(73,'INSERT','questions','QST0000012','USR0000004','root@localhost','Created questions record QST0000012',NULL,'{\"quiz_id\": \"QUZ0000003\", \"option_a\": \"<style>\", \"option_b\": \"<script>\", \"option_c\": \"<css>\", \"option_d\": \"<link>\", \"question_id\": \"QST0000012\", \"question_text\": \"Which HTML element links an external stylesheet?\", \"correct_answer\": \"<link>\"}','2026-11-24 23:31:59'),(74,'INSERT','questions','QST0000013','USR0000004','root@localhost','Created questions record QST0000013',NULL,'{\"quiz_id\": \"QUZ0000003\", \"option_a\": \"block\", \"option_b\": \"flex\", \"option_c\": \"grid-inline\", \"option_d\": \"inline\", \"question_id\": \"QST0000013\", \"question_text\": \"Which CSS display value creates a flex container?\", \"correct_answer\": \"flex\"}','2026-11-24 23:31:59'),(75,'INSERT','questions','QST0000014','USR0000005','root@localhost','Created questions record QST0000014',NULL,'{\"quiz_id\": \"QUZ0000004\", \"option_a\": \"O(n)\", \"option_b\": \"O(log n)\", \"option_c\": \"O(n log n)\", \"option_d\": \"O(1)\", \"question_id\": \"QST0000014\", \"question_text\": \"What is the time complexity of binary search?\", \"correct_answer\": \"O(log n)\"}','2026-11-24 23:31:59'),(76,'INSERT','questions','QST0000015','USR0000005','root@localhost','Created questions record QST0000015',NULL,'{\"quiz_id\": \"QUZ0000004\", \"option_a\": \"O(1)\", \"option_b\": \"O(n)\", \"option_c\": \"O(log n)\", \"option_d\": \"O(n^2)\", \"question_id\": \"QST0000015\", \"question_text\": \"Accessing an array element by index is:\", \"correct_answer\": \"O(1)\"}','2026-11-24 23:31:59'),(77,'INSERT','questions','QST0000016','USR0000005','root@localhost','Created questions record QST0000016',NULL,'{\"quiz_id\": \"QUZ0000004\", \"option_a\": \"O(n)\", \"option_b\": \"O(log n)\", \"option_c\": \"O(n^2)\", \"option_d\": \"O(1)\", \"question_id\": \"QST0000016\", \"question_text\": \"A nested loop over n items is usually:\", \"correct_answer\": \"O(n^2)\"}','2026-11-24 23:31:59'),(78,'INSERT','questions','QST0000017','USR0000004','root@localhost','Created questions record QST0000017',NULL,'{\"quiz_id\": \"QUZ0000005\", \"option_a\": \"let\", \"option_b\": \"var\", \"option_c\": \"def\", \"option_d\": \"dim\", \"question_id\": \"QST0000017\", \"question_text\": \"Which keyword declares a block-scoped variable?\", \"correct_answer\": \"let\"}','2026-11-24 23:31:59'),(79,'INSERT','questions','QST0000018','USR0000004','root@localhost','Created questions record QST0000018',NULL,'{\"quiz_id\": \"QUZ0000005\", \"option_a\": \"print()\", \"option_b\": \"echo()\", \"option_c\": \"write()\", \"option_d\": \"console.log()\", \"question_id\": \"QST0000018\", \"question_text\": \"Which method prints to the browser console?\", \"correct_answer\": \"console.log()\"}','2026-11-24 23:31:59'),(80,'INSERT','questions','QST0000019','USR0000004','root@localhost','Created questions record QST0000019',NULL,'{\"quiz_id\": \"QUZ0000005\", \"option_a\": \"Value only\", \"option_b\": \"Value and type\", \"option_c\": \"Reference only\", \"option_d\": \"Length\", \"question_id\": \"QST0000019\", \"question_text\": \"What does === compare?\", \"correct_answer\": \"Value and type\"}','2026-11-24 23:31:59'),(81,'UPDATE','quizzes','QUZ0000004','USR0000005','root@localhost','Updated quizzes record QUZ0000004','{\"title\": \"Big-O Notation\", \"quiz_id\": \"QUZ0000004\", \"created_at\": \"2026-11-25 07:31:59.000000\", \"subject_id\": \"SUB0000003\", \"instructor_id\": \"INS0000003\"}','{\"title\": \"Big-O Notation Quiz\", \"quiz_id\": \"QUZ0000004\", \"created_at\": \"2026-11-25 07:31:59.000000\", \"subject_id\": \"SUB0000003\", \"instructor_id\": \"INS0000003\"}','2026-11-24 23:31:59'),(82,'INSERT','student_answers','ANS0000001','USR0000006','root@localhost','Created student_answers record ANS0000001',NULL,'{\"answer_id\": \"ANS0000001\", \"is_correct\": 1, \"student_id\": \"STU0000001\", \"question_id\": \"QST0000001\", \"student_answer\": \"GRANT\"}','2026-11-24 23:31:59'),(83,'INSERT','student_answers','ANS0000002','USR0000006','root@localhost','Created student_answers record ANS0000002',NULL,'{\"answer_id\": \"ANS0000002\", \"is_correct\": 1, \"student_id\": \"STU0000001\", \"question_id\": \"QST0000002\", \"student_answer\": \"SQL injection\"}','2026-11-24 23:31:59'),(84,'INSERT','student_answers','ANS0000003','USR0000006','root@localhost','Created student_answers record ANS0000003',NULL,'{\"answer_id\": \"ANS0000003\", \"is_correct\": 1, \"student_id\": \"STU0000001\", \"question_id\": \"QST0000003\", \"student_answer\": \"A salted hash\"}','2026-11-24 23:31:59'),(85,'INSERT','student_answers','ANS0000004','USR0000006','root@localhost','Created student_answers record ANS0000004',NULL,'{\"answer_id\": \"ANS0000004\", \"is_correct\": 1, \"student_id\": \"STU0000001\", \"question_id\": \"QST0000004\", \"student_answer\": \"View\"}','2026-11-24 23:31:59'),(86,'INSERT','student_answers','ANS0000005','USR0000006','root@localhost','Created student_answers record ANS0000005',NULL,'{\"answer_id\": \"ANS0000005\", \"is_correct\": 1, \"student_id\": \"STU0000001\", \"question_id\": \"QST0000005\", \"student_answer\": \"Least privilege\"}','2026-11-24 23:31:59'),(87,'INSERT','quiz_results','RES0000001','USR0000006','root@localhost','Created quiz_results record RES0000001',NULL,'{\"score\": 100.00, \"quiz_id\": \"QUZ0000001\", \"result_id\": \"RES0000001\", \"student_id\": \"STU0000001\"}','2026-11-24 23:31:59'),(88,'INSERT','student_answers','ANS0000006','USR0000007','root@localhost','Created student_answers record ANS0000006',NULL,'{\"answer_id\": \"ANS0000006\", \"is_correct\": 1, \"student_id\": \"STU0000002\", \"question_id\": \"QST0000001\", \"student_answer\": \"GRANT\"}','2026-11-24 23:31:59'),(89,'INSERT','student_answers','ANS0000007','USR0000007','root@localhost','Created student_answers record ANS0000007',NULL,'{\"answer_id\": \"ANS0000007\", \"is_correct\": 1, \"student_id\": \"STU0000002\", \"question_id\": \"QST0000002\", \"student_answer\": \"SQL injection\"}','2026-11-24 23:31:59'),(90,'INSERT','student_answers','ANS0000008','USR0000007','root@localhost','Created student_answers record ANS0000008',NULL,'{\"answer_id\": \"ANS0000008\", \"is_correct\": 1, \"student_id\": \"STU0000002\", \"question_id\": \"QST0000003\", \"student_answer\": \"A salted hash\"}','2026-11-24 23:31:59'),(91,'INSERT','student_answers','ANS0000009','USR0000007','root@localhost','Created student_answers record ANS0000009',NULL,'{\"answer_id\": \"ANS0000009\", \"is_correct\": 1, \"student_id\": \"STU0000002\", \"question_id\": \"QST0000004\", \"student_answer\": \"View\"}','2026-11-24 23:31:59'),(92,'INSERT','student_answers','ANS0000010','USR0000007','root@localhost','Created student_answers record ANS0000010',NULL,'{\"answer_id\": \"ANS0000010\", \"is_correct\": 0, \"student_id\": \"STU0000002\", \"question_id\": \"QST0000005\", \"student_answer\": \"Defense in depth\"}','2026-11-24 23:31:59'),(93,'INSERT','quiz_results','RES0000002','USR0000007','root@localhost','Created quiz_results record RES0000002',NULL,'{\"score\": 80.00, \"quiz_id\": \"QUZ0000001\", \"result_id\": \"RES0000002\", \"student_id\": \"STU0000002\"}','2026-11-24 23:31:59'),(94,'INSERT','student_answers','ANS0000011','USR0000008','root@localhost','Created student_answers record ANS0000011',NULL,'{\"answer_id\": \"ANS0000011\", \"is_correct\": 1, \"student_id\": \"STU0000003\", \"question_id\": \"QST0000001\", \"student_answer\": \"GRANT\"}','2026-11-24 23:31:59'),(95,'INSERT','student_answers','ANS0000012','USR0000008','root@localhost','Created student_answers record ANS0000012',NULL,'{\"answer_id\": \"ANS0000012\", \"is_correct\": 1, \"student_id\": \"STU0000003\", \"question_id\": \"QST0000002\", \"student_answer\": \"SQL injection\"}','2026-11-24 23:31:59'),(96,'INSERT','student_answers','ANS0000013','USR0000008','root@localhost','Created student_answers record ANS0000013',NULL,'{\"answer_id\": \"ANS0000013\", \"is_correct\": 1, \"student_id\": \"STU0000003\", \"question_id\": \"QST0000003\", \"student_answer\": \"A salted hash\"}','2026-11-24 23:31:59'),(97,'INSERT','student_answers','ANS0000014','USR0000008','root@localhost','Created student_answers record ANS0000014',NULL,'{\"answer_id\": \"ANS0000014\", \"is_correct\": 0, \"student_id\": \"STU0000003\", \"question_id\": \"QST0000004\", \"student_answer\": \"Index\"}','2026-11-24 23:31:59'),(98,'INSERT','student_answers','ANS0000015','USR0000008','root@localhost','Created student_answers record ANS0000015',NULL,'{\"answer_id\": \"ANS0000015\", \"is_correct\": 0, \"student_id\": \"STU0000003\", \"question_id\": \"QST0000005\", \"student_answer\": \"Separation of data\"}','2026-11-24 23:31:59'),(99,'INSERT','quiz_results','RES0000003','USR0000008','root@localhost','Created quiz_results record RES0000003',NULL,'{\"score\": 60.00, \"quiz_id\": \"QUZ0000001\", \"result_id\": \"RES0000003\", \"student_id\": \"STU0000003\"}','2026-11-24 23:31:59'),(100,'INSERT','student_answers','ANS0000016','USR0000009','root@localhost','Created student_answers record ANS0000016',NULL,'{\"answer_id\": \"ANS0000016\", \"is_correct\": 0, \"student_id\": \"STU0000004\", \"question_id\": \"QST0000001\", \"student_answer\": \"REVOKE\"}','2026-11-24 23:31:59'),(101,'INSERT','student_answers','ANS0000017','USR0000009','root@localhost','Created student_answers record ANS0000017',NULL,'{\"answer_id\": \"ANS0000017\", \"is_correct\": 1, \"student_id\": \"STU0000004\", \"question_id\": \"QST0000002\", \"student_answer\": \"SQL injection\"}','2026-11-24 23:31:59'),(102,'INSERT','student_answers','ANS0000018','USR0000009','root@localhost','Created student_answers record ANS0000018',NULL,'{\"answer_id\": \"ANS0000018\", \"is_correct\": 0, \"student_id\": \"STU0000004\", \"question_id\": \"QST0000003\", \"student_answer\": \"Nothing\"}','2026-11-24 23:31:59'),(103,'INSERT','student_answers','ANS0000019','USR0000009','root@localhost','Created student_answers record ANS0000019',NULL,'{\"answer_id\": \"ANS0000019\", \"is_correct\": 1, \"student_id\": \"STU0000004\", \"question_id\": \"QST0000004\", \"student_answer\": \"View\"}','2026-11-24 23:31:59'),(104,'INSERT','quiz_results','RES0000004','USR0000009','root@localhost','Created quiz_results record RES0000004',NULL,'{\"score\": 40.00, \"quiz_id\": \"QUZ0000001\", \"result_id\": \"RES0000004\", \"student_id\": \"STU0000004\"}','2026-11-24 23:31:59'),(105,'INSERT','student_answers','ANS0000020','USR0000006','root@localhost','Created student_answers record ANS0000020',NULL,'{\"answer_id\": \"ANS0000020\", \"is_correct\": 1, \"student_id\": \"STU0000001\", \"question_id\": \"QST0000006\", \"student_answer\": \"REVOKE\"}','2026-11-24 23:31:59'),(106,'INSERT','student_answers','ANS0000021','USR0000006','root@localhost','Created student_answers record ANS0000021',NULL,'{\"answer_id\": \"ANS0000021\", \"is_correct\": 1, \"student_id\": \"STU0000001\", \"question_id\": \"QST0000007\", \"student_answer\": \"Role\"}','2026-11-24 23:31:59'),(107,'INSERT','student_answers','ANS0000022','USR0000006','root@localhost','Created student_answers record ANS0000022',NULL,'{\"answer_id\": \"ANS0000022\", \"is_correct\": 1, \"student_id\": \"STU0000001\", \"question_id\": \"QST0000008\", \"student_answer\": \"EXECUTE\"}','2026-11-24 23:31:59'),(108,'INSERT','student_answers','ANS0000023','USR0000006','root@localhost','Created student_answers record ANS0000023',NULL,'{\"answer_id\": \"ANS0000023\", \"is_correct\": 0, \"student_id\": \"STU0000001\", \"question_id\": \"QST0000009\", \"student_answer\": \"Temp table\"}','2026-11-24 23:31:59'),(109,'INSERT','quiz_results','RES0000005','USR0000006','root@localhost','Created quiz_results record RES0000005',NULL,'{\"score\": 75.00, \"quiz_id\": \"QUZ0000002\", \"result_id\": \"RES0000005\", \"student_id\": \"STU0000001\"}','2026-11-24 23:31:59'),(110,'INSERT','student_answers','ANS0000024','USR0000007','root@localhost','Created student_answers record ANS0000024',NULL,'{\"answer_id\": \"ANS0000024\", \"is_correct\": 1, \"student_id\": \"STU0000002\", \"question_id\": \"QST0000006\", \"student_answer\": \"REVOKE\"}','2026-11-24 23:31:59'),(111,'INSERT','student_answers','ANS0000025','USR0000007','root@localhost','Created student_answers record ANS0000025',NULL,'{\"answer_id\": \"ANS0000025\", \"is_correct\": 1, \"student_id\": \"STU0000002\", \"question_id\": \"QST0000007\", \"student_answer\": \"Role\"}','2026-11-24 23:31:59'),(112,'INSERT','student_answers','ANS0000026','USR0000007','root@localhost','Created student_answers record ANS0000026',NULL,'{\"answer_id\": \"ANS0000026\", \"is_correct\": 1, \"student_id\": \"STU0000002\", \"question_id\": \"QST0000008\", \"student_answer\": \"EXECUTE\"}','2026-11-24 23:31:59'),(113,'INSERT','student_answers','ANS0000027','USR0000007','root@localhost','Created student_answers record ANS0000027',NULL,'{\"answer_id\": \"ANS0000027\", \"is_correct\": 1, \"student_id\": \"STU0000002\", \"question_id\": \"QST0000009\", \"student_answer\": \"Audit log\"}','2026-11-24 23:31:59'),(114,'INSERT','quiz_results','RES0000006','USR0000007','root@localhost','Created quiz_results record RES0000006',NULL,'{\"score\": 100.00, \"quiz_id\": \"QUZ0000002\", \"result_id\": \"RES0000006\", \"student_id\": \"STU0000002\"}','2026-11-24 23:31:59'),(115,'INSERT','student_answers','ANS0000028','USR0000010','root@localhost','Created student_answers record ANS0000028',NULL,'{\"answer_id\": \"ANS0000028\", \"is_correct\": 1, \"student_id\": \"STU0000005\", \"question_id\": \"QST0000006\", \"student_answer\": \"REVOKE\"}','2026-11-24 23:31:59'),(116,'INSERT','student_answers','ANS0000029','USR0000010','root@localhost','Created student_answers record ANS0000029',NULL,'{\"answer_id\": \"ANS0000029\", \"is_correct\": 0, \"student_id\": \"STU0000005\", \"question_id\": \"QST0000007\", \"student_answer\": \"Schema\"}','2026-11-24 23:31:59'),(117,'INSERT','student_answers','ANS0000030','USR0000010','root@localhost','Created student_answers record ANS0000030',NULL,'{\"answer_id\": \"ANS0000030\", \"is_correct\": 1, \"student_id\": \"STU0000005\", \"question_id\": \"QST0000008\", \"student_answer\": \"EXECUTE\"}','2026-11-24 23:31:59'),(118,'INSERT','student_answers','ANS0000031','USR0000010','root@localhost','Created student_answers record ANS0000031',NULL,'{\"answer_id\": \"ANS0000031\", \"is_correct\": 0, \"student_id\": \"STU0000005\", \"question_id\": \"QST0000009\", \"student_answer\": \"Temp table\"}','2026-11-24 23:31:59'),(119,'INSERT','quiz_results','RES0000007','USR0000010','root@localhost','Created quiz_results record RES0000007',NULL,'{\"score\": 50.00, \"quiz_id\": \"QUZ0000002\", \"result_id\": \"RES0000007\", \"student_id\": \"STU0000005\"}','2026-11-24 23:31:59'),(120,'INSERT','student_answers','ANS0000032','USR0000008','root@localhost','Created student_answers record ANS0000032',NULL,'{\"answer_id\": \"ANS0000032\", \"is_correct\": 1, \"student_id\": \"STU0000003\", \"question_id\": \"QST0000010\", \"student_answer\": \"<h1>\"}','2026-11-24 23:32:00'),(121,'INSERT','student_answers','ANS0000033','USR0000008','root@localhost','Created student_answers record ANS0000033',NULL,'{\"answer_id\": \"ANS0000033\", \"is_correct\": 1, \"student_id\": \"STU0000003\", \"question_id\": \"QST0000011\", \"student_answer\": \"color\"}','2026-11-24 23:32:00'),(122,'INSERT','student_answers','ANS0000034','USR0000008','root@localhost','Created student_answers record ANS0000034',NULL,'{\"answer_id\": \"ANS0000034\", \"is_correct\": 1, \"student_id\": \"STU0000003\", \"question_id\": \"QST0000012\", \"student_answer\": \"<link>\"}','2026-11-24 23:32:00'),(123,'INSERT','student_answers','ANS0000035','USR0000008','root@localhost','Created student_answers record ANS0000035',NULL,'{\"answer_id\": \"ANS0000035\", \"is_correct\": 1, \"student_id\": \"STU0000003\", \"question_id\": \"QST0000013\", \"student_answer\": \"flex\"}','2026-11-24 23:32:00'),(124,'INSERT','quiz_results','RES0000008','USR0000008','root@localhost','Created quiz_results record RES0000008',NULL,'{\"score\": 100.00, \"quiz_id\": \"QUZ0000003\", \"result_id\": \"RES0000008\", \"student_id\": \"STU0000003\"}','2026-11-24 23:32:00'),(125,'INSERT','student_answers','ANS0000036','USR0000011','root@localhost','Created student_answers record ANS0000036',NULL,'{\"answer_id\": \"ANS0000036\", \"is_correct\": 0, \"student_id\": \"STU0000006\", \"question_id\": \"QST0000010\", \"student_answer\": \"<head>\"}','2026-11-24 23:32:00'),(126,'INSERT','student_answers','ANS0000037','USR0000011','root@localhost','Created student_answers record ANS0000037',NULL,'{\"answer_id\": \"ANS0000037\", \"is_correct\": 1, \"student_id\": \"STU0000006\", \"question_id\": \"QST0000011\", \"student_answer\": \"color\"}','2026-11-24 23:32:00'),(127,'INSERT','student_answers','ANS0000038','USR0000011','root@localhost','Created student_answers record ANS0000038',NULL,'{\"answer_id\": \"ANS0000038\", \"is_correct\": 0, \"student_id\": \"STU0000006\", \"question_id\": \"QST0000012\", \"student_answer\": \"<style>\"}','2026-11-24 23:32:00'),(128,'INSERT','student_answers','ANS0000039','USR0000011','root@localhost','Created student_answers record ANS0000039',NULL,'{\"answer_id\": \"ANS0000039\", \"is_correct\": 0, \"student_id\": \"STU0000006\", \"question_id\": \"QST0000013\", \"student_answer\": \"block\"}','2026-11-24 23:32:00'),(129,'INSERT','quiz_results','RES0000009','USR0000011','root@localhost','Created quiz_results record RES0000009',NULL,'{\"score\": 25.00, \"quiz_id\": \"QUZ0000003\", \"result_id\": \"RES0000009\", \"student_id\": \"STU0000006\"}','2026-11-24 23:32:00'),(130,'INSERT','student_answers','ANS0000040','USR0000006','root@localhost','Created student_answers record ANS0000040',NULL,'{\"answer_id\": \"ANS0000040\", \"is_correct\": 1, \"student_id\": \"STU0000001\", \"question_id\": \"QST0000010\", \"student_answer\": \"<h1>\"}','2026-11-24 23:32:00'),(131,'INSERT','student_answers','ANS0000041','USR0000006','root@localhost','Created student_answers record ANS0000041',NULL,'{\"answer_id\": \"ANS0000041\", \"is_correct\": 1, \"student_id\": \"STU0000001\", \"question_id\": \"QST0000011\", \"student_answer\": \"color\"}','2026-11-24 23:32:00'),(132,'INSERT','student_answers','ANS0000042','USR0000006','root@localhost','Created student_answers record ANS0000042',NULL,'{\"answer_id\": \"ANS0000042\", \"is_correct\": 1, \"student_id\": \"STU0000001\", \"question_id\": \"QST0000012\", \"student_answer\": \"<link>\"}','2026-11-24 23:32:00'),(133,'INSERT','student_answers','ANS0000043','USR0000006','root@localhost','Created student_answers record ANS0000043',NULL,'{\"answer_id\": \"ANS0000043\", \"is_correct\": 0, \"student_id\": \"STU0000001\", \"question_id\": \"QST0000013\", \"student_answer\": \"grid-inline\"}','2026-11-24 23:32:00'),(134,'INSERT','quiz_results','RES0000010','USR0000006','root@localhost','Created quiz_results record RES0000010',NULL,'{\"score\": 75.00, \"quiz_id\": \"QUZ0000003\", \"result_id\": \"RES0000010\", \"student_id\": \"STU0000001\"}','2026-11-24 23:32:00'),(135,'INSERT','student_answers','ANS0000044','USR0000009','root@localhost','Created student_answers record ANS0000044',NULL,'{\"answer_id\": \"ANS0000044\", \"is_correct\": 1, \"student_id\": \"STU0000004\", \"question_id\": \"QST0000014\", \"student_answer\": \"O(log n)\"}','2026-11-24 23:32:00'),(136,'INSERT','student_answers','ANS0000045','USR0000009','root@localhost','Created student_answers record ANS0000045',NULL,'{\"answer_id\": \"ANS0000045\", \"is_correct\": 1, \"student_id\": \"STU0000004\", \"question_id\": \"QST0000015\", \"student_answer\": \"O(1)\"}','2026-11-24 23:32:00'),(137,'INSERT','student_answers','ANS0000046','USR0000009','root@localhost','Created student_answers record ANS0000046',NULL,'{\"answer_id\": \"ANS0000046\", \"is_correct\": 1, \"student_id\": \"STU0000004\", \"question_id\": \"QST0000016\", \"student_answer\": \"O(n^2)\"}','2026-11-24 23:32:00'),(138,'INSERT','quiz_results','RES0000011','USR0000009','root@localhost','Created quiz_results record RES0000011',NULL,'{\"score\": 100.00, \"quiz_id\": \"QUZ0000004\", \"result_id\": \"RES0000011\", \"student_id\": \"STU0000004\"}','2026-11-24 23:32:00'),(139,'INSERT','student_answers','ANS0000047','USR0000010','root@localhost','Created student_answers record ANS0000047',NULL,'{\"answer_id\": \"ANS0000047\", \"is_correct\": 1, \"student_id\": \"STU0000005\", \"question_id\": \"QST0000014\", \"student_answer\": \"O(log n)\"}','2026-11-24 23:32:00'),(140,'INSERT','student_answers','ANS0000048','USR0000010','root@localhost','Created student_answers record ANS0000048',NULL,'{\"answer_id\": \"ANS0000048\", \"is_correct\": 1, \"student_id\": \"STU0000005\", \"question_id\": \"QST0000015\", \"student_answer\": \"O(1)\"}','2026-11-24 23:32:00'),(141,'INSERT','student_answers','ANS0000049','USR0000010','root@localhost','Created student_answers record ANS0000049',NULL,'{\"answer_id\": \"ANS0000049\", \"is_correct\": 0, \"student_id\": \"STU0000005\", \"question_id\": \"QST0000016\", \"student_answer\": \"O(1)\"}','2026-11-24 23:32:00'),(142,'INSERT','quiz_results','RES0000012','USR0000010','root@localhost','Created quiz_results record RES0000012',NULL,'{\"score\": 66.67, \"quiz_id\": \"QUZ0000004\", \"result_id\": \"RES0000012\", \"student_id\": \"STU0000005\"}','2026-11-24 23:32:00'),(143,'LOGIN_SUCCESS','users','USR0000006','USR0000006','root@localhost','User ana.santos logged in',NULL,NULL,'2026-11-24 23:32:00'),(144,'LOGIN_FAILED','users','USR0000007',NULL,'root@localhost','Failed login for username \"ben.torres\"',NULL,NULL,'2026-11-24 23:32:00'),(145,'LOGIN_FAILED','users','USR0000012',NULL,'root@localhost','Failed login for username \"gina.lopez\" (inactive account)',NULL,NULL,'2026-11-24 23:32:00'),(146,'INSERT','student_answers','ANS0000999',NULL,'root@localhost','Created student_answers record ANS0000999',NULL,'{\"answer_id\": \"ANS0000999\", \"is_correct\": 0, \"student_id\": \"STU0000002\", \"question_id\": \"QST0000017\", \"student_answer\": \"var\"}','2026-11-24 23:32:30'),(147,'INSERT','quiz_results','RES0000999',NULL,'root@localhost','Created quiz_results record RES0000999',NULL,'{\"score\": 0.00, \"quiz_id\": \"QUZ0000005\", \"result_id\": \"RES0000999\", \"student_id\": \"STU0000002\"}','2026-11-24 23:32:30'),(148,'DELETE','quiz_results','RES0000999',NULL,'root@localhost','Deleted quiz_results record RES0000999','{\"score\": 0.00, \"quiz_id\": \"QUZ0000005\", \"result_id\": \"RES0000999\", \"student_id\": \"STU0000002\"}',NULL,'2026-11-24 23:32:30'),(149,'DELETE','student_answers','ANS0000999',NULL,'root@localhost','Deleted student_answers record ANS0000999','{\"answer_id\": \"ANS0000999\", \"is_correct\": 0, \"student_id\": \"STU0000002\", \"question_id\": \"QST0000017\", \"student_answer\": \"var\"}',NULL,'2026-11-24 23:32:30'),(150,'INSERT','users','USR0000013','USR0000001','root@localhost','Created users record USR0000013',NULL,'{\"email\": \"hana.cruz@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000013\", \"username\": \"hana.cruz\", \"created_at\": \"2026-11-25 07:32:30.000000\"}','2026-11-24 23:32:30'),(151,'INSERT','user_roles','USR0000013:ROL0000003','USR0000001','root@localhost','Created user_roles record USR0000013:ROL0000003',NULL,'{\"role_id\": \"ROL0000003\", \"user_id\": \"USR0000013\"}','2026-11-24 23:32:30'),(152,'INSERT','students','STU0000008','USR0000001','root@localhost','Created students record STU0000008',NULL,'{\"user_id\": \"USR0000013\", \"last_name\": \"Cruz\", \"first_name\": \"Hana\", \"student_id\": \"STU0000008\"}','2026-11-24 23:32:30'),(153,'INSERT','users','USR0000014','USR0000001','root@localhost','Created users record USR0000014',NULL,'{\"email\": \"paolo.lim@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000014\", \"username\": \"paolo.lim\", \"created_at\": \"2026-11-25 07:32:30.000000\"}','2026-11-24 23:32:30'),(154,'INSERT','user_roles','USR0000014:ROL0000002','USR0000001','root@localhost','Created user_roles record USR0000014:ROL0000002',NULL,'{\"role_id\": \"ROL0000002\", \"user_id\": \"USR0000014\"}','2026-11-24 23:32:30'),(155,'INSERT','instructors','INS0000005','USR0000001','root@localhost','Created instructors record INS0000005',NULL,'{\"user_id\": \"USR0000014\", \"last_name\": \"Lim\", \"first_name\": \"Paolo\", \"instructor_id\": \"INS0000005\"}','2026-11-24 23:32:30'),(156,'LOGIN_SUCCESS','users','USR0000013','USR0000013','root@localhost','User hana.cruz logged in',NULL,NULL,'2026-11-24 23:32:30'),(157,'LOGIN_FAILED','users','USR0000013',NULL,'root@localhost','Failed login for username \"hana.cruz\"',NULL,NULL,'2026-11-24 23:32:30'),(158,'LOGIN_FAILED','users','USR0000012',NULL,'root@localhost','Failed login for username \"gina.lopez\" (inactive account)',NULL,NULL,'2026-11-24 23:32:30'),(159,'UPDATE','users','USR0000013','USR0000001','root@localhost','Updated users record USR0000013','{\"email\": \"hana.cruz@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000013\", \"username\": \"hana.cruz\", \"created_at\": \"2026-11-25 07:32:30.000000\"}','{\"email\": \"hana.cruz2@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000013\", \"username\": \"hana.cruz\", \"created_at\": \"2026-11-25 07:32:30.000000\", \"password_changed\": false}','2026-11-24 23:32:30'),(160,'UPDATE','students','STU0000008','USR0000001','root@localhost','Updated students record STU0000008','{\"user_id\": \"USR0000013\", \"last_name\": \"Cruz\", \"first_name\": \"Hana\", \"student_id\": \"STU0000008\"}','{\"user_id\": \"USR0000013\", \"last_name\": \"Cruz\", \"first_name\": \"Hannah\", \"student_id\": \"STU0000008\"}','2026-11-24 23:32:30'),(161,'INSERT','user_roles','USR0000013:ROL0000002','USR0000001','root@localhost','Created user_roles record USR0000013:ROL0000002',NULL,'{\"role_id\": \"ROL0000002\", \"user_id\": \"USR0000013\"}','2026-11-24 23:32:30'),(162,'INSERT','instructors','INS0000006','USR0000001','root@localhost','Created instructors record INS0000006',NULL,'{\"user_id\": \"USR0000013\", \"last_name\": \"Cruz\", \"first_name\": \"Hannah\", \"instructor_id\": \"INS0000006\"}','2026-11-24 23:32:30'),(163,'DELETE','user_roles','USR0000013:ROL0000002','USR0000001','root@localhost','Deleted user_roles record USR0000013:ROL0000002','{\"role_id\": \"ROL0000002\", \"user_id\": \"USR0000013\"}',NULL,'2026-11-24 23:32:30'),(164,'UPDATE','users','USR0000013','USR0000013','root@localhost','Updated users record USR0000013','{\"email\": \"hana.cruz2@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000013\", \"username\": \"hana.cruz\", \"created_at\": \"2026-11-25 07:32:30.000000\"}','{\"email\": \"hana.cruz2@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000013\", \"username\": \"hana.cruz\", \"created_at\": \"2026-11-25 07:32:30.000000\", \"password_changed\": true}','2026-11-24 23:32:30'),(165,'LOGIN_SUCCESS','users','USR0000013','USR0000013','root@localhost','User hana.cruz logged in',NULL,NULL,'2026-11-24 23:32:30'),(166,'INSERT','subjects','SUB0000006','USR0000001','root@localhost','Created subjects record SUB0000006',NULL,'{\"subject_id\": \"SUB0000006\", \"description\": \"Security policies and risk management.\", \"subject_name\": \"Information Assurance\"}','2026-11-24 23:32:30'),(167,'LOGIN_SUCCESS','users','USR0000006','USR0000006','studync_app_student@localhost','User ana.santos logged in',NULL,NULL,'2026-11-25 01:08:48'),(168,'INSERT','student_answers','ANS0000050','USR0000006','studync_app_student@localhost','Created student_answers record ANS0000050',NULL,'{\"answer_id\": \"ANS0000050\", \"is_correct\": 1, \"student_id\": \"STU0000001\", \"question_id\": \"QST0000014\", \"student_answer\": \"O(log n)\"}','2026-11-25 01:09:21'),(169,'INSERT','quiz_results','RES0000013','USR0000006','studync_app_student@localhost','Created quiz_results record RES0000013',NULL,'{\"score\": 33.33, \"quiz_id\": \"QUZ0000004\", \"result_id\": \"RES0000013\", \"student_id\": \"STU0000001\"}','2026-11-25 01:09:33'),(170,'LOGIN_SUCCESS','users','USR0000001','USR0000001','studync_app_admin@localhost','User maria.reyes logged in',NULL,NULL,'2026-11-25 01:10:04'),(171,'UPDATE','users','USR0000006','USR0000001','studync_app_admin@localhost','Updated users record USR0000006','{\"email\": \"ana.santos@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000006\", \"username\": \"ana.santos\", \"created_at\": \"2026-11-25 07:31:59.000000\"}','{\"email\": \"ana.updated@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000006\", \"username\": \"ana.santos\", \"created_at\": \"2026-11-25 07:31:59.000000\", \"password_changed\": false}','2026-11-25 01:10:24'),(172,'INSERT','user_roles','USR0000014:ROL0000001','USR0000001','studync_app_admin@localhost','Created user_roles record USR0000014:ROL0000001',NULL,'{\"role_id\": \"ROL0000001\", \"user_id\": \"USR0000014\"}','2026-11-25 01:10:37'),(173,'INSERT','admins','ADM0000003','USR0000001','studync_app_admin@localhost','Created admins record ADM0000003',NULL,'{\"user_id\": \"USR0000014\", \"admin_id\": \"ADM0000003\", \"last_name\": \"Lim\", \"first_name\": \"Paolo\"}','2026-11-25 01:10:37'),(174,'DELETE','user_roles','USR0000014:ROL0000001','USR0000001','studync_app_admin@localhost','Deleted user_roles record USR0000014:ROL0000001','{\"role_id\": \"ROL0000001\", \"user_id\": \"USR0000014\"}',NULL,'2026-11-25 01:10:44'),(175,'UPDATE','users','USR0000012','USR0000001','studync_app_admin@localhost','Updated users record USR0000012','{\"email\": \"gina.lopez@studync.edu\", \"status\": \"Inactive\", \"user_id\": \"USR0000012\", \"username\": \"gina.lopez\", \"created_at\": \"2026-11-25 07:31:59.000000\"}','{\"email\": \"gina.lopez@studync.edu\", \"status\": \"Active\", \"user_id\": \"USR0000012\", \"username\": \"gina.lopez\", \"created_at\": \"2026-11-25 07:31:59.000000\", \"password_changed\": false}','2026-11-25 01:10:55'),(176,'INSERT','subjects','SUB0000007','USR0000001','studync_app_admin@localhost','Created subjects record SUB0000007',NULL,'{\"subject_id\": \"SUB0000007\", \"description\": \"Subject created to test StudyNC database functions.\", \"subject_name\": \"Database Testing Practice\"}','2026-11-25 01:11:02'),(177,'LOGIN_SUCCESS','users','USR0000003','USR0000003','studync_app_instructor@localhost','User jose.cruz logged in',NULL,NULL,'2026-11-25 01:11:59'),(178,'INSERT','materials','MAT0000009','USR0000003','studync_app_instructor@localhost','Created materials record MAT0000009',NULL,'{\"title\": \"Database Testing Guide\", \"file_path\": \"materials/sub1/database-testing-guide.pdf\", \"subject_id\": \"SUB0000001\", \"material_id\": \"MAT0000009\", \"uploaded_at\": \"2026-11-25 09:12:04.000000\", \"instructor_id\": \"INS0000001\"}','2026-11-25 01:12:04'),(179,'UPDATE','materials','MAT0000009','USR0000003','studync_app_instructor@localhost','Updated materials record MAT0000009','{\"title\": \"Database Testing Guide\", \"file_path\": \"materials/sub1/database-testing-guide.pdf\", \"subject_id\": \"SUB0000001\", \"material_id\": \"MAT0000009\", \"uploaded_at\": \"2026-11-25 09:12:04.000000\", \"instructor_id\": \"INS0000001\"}','{\"title\": \"Database Testing Guide - Updated\", \"file_path\": \"materials/sub1/database-testing-guide.pdf\", \"subject_id\": \"SUB0000001\", \"material_id\": \"MAT0000009\", \"uploaded_at\": \"2026-11-25 09:12:04.000000\", \"instructor_id\": \"INS0000001\"}','2026-11-25 01:12:08'),(180,'INSERT','quizzes','QUZ0000006','USR0000003','studync_app_instructor@localhost','Created quizzes record QUZ0000006',NULL,'{\"title\": \"Database Testing Test Quiz\", \"quiz_id\": \"QUZ0000006\", \"created_at\": \"2026-11-25 09:12:17.000000\", \"subject_id\": \"SUB0000001\", \"instructor_id\": \"INS0000001\"}','2026-11-25 01:12:17'),(181,'INSERT','questions','QST0000020','USR0000003','studync_app_instructor@localhost','Created questions record QST0000020',NULL,'{\"quiz_id\": \"QUZ0000006\", \"option_a\": \"INSERT\", \"option_b\": \"SELECT\", \"option_c\": \"UPDATE\", \"option_d\": \"DELETE\", \"question_id\": \"QST0000020\", \"question_text\": \"Which SQL command retrieves records?\", \"correct_answer\": \"SELECT\"}','2026-11-25 01:12:25'),(182,'UPDATE','questions','QST0000020','USR0000003','studync_app_instructor@localhost','Updated questions record QST0000020','{\"quiz_id\": \"QUZ0000006\", \"option_a\": \"INSERT\", \"option_b\": \"SELECT\", \"option_c\": \"UPDATE\", \"option_d\": \"DELETE\", \"question_id\": \"QST0000020\", \"question_text\": \"Which SQL command retrieves records?\", \"correct_answer\": \"SELECT\"}','{\"quiz_id\": \"QUZ0000006\", \"option_a\": \"INSERT\", \"option_b\": \"SELECT\", \"option_c\": \"UPDATE\", \"option_d\": \"DELETE\", \"question_id\": \"QST0000020\", \"question_text\": \"Which SQL command retrieves data from a table?\", \"correct_answer\": \"SELECT\"}','2026-11-25 01:12:28'),(183,'LOGIN_SUCCESS','users','USR0000006','USR0000006','studync_app_student@localhost','User ana.santos logged in',NULL,NULL,'2026-11-25 01:20:52');
/*!40000 ALTER TABLE `audit_logs` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_audit_logs_bu` BEFORE UPDATE ON `audit_logs` FOR EACH ROW BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'audit_logs is append-only: UPDATE is not allowed';
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_audit_logs_bd` BEFORE DELETE ON `audit_logs` FOR EACH ROW BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'audit_logs is append-only: DELETE is not allowed';
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `instructors`
--

DROP TABLE IF EXISTS `instructors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `instructors` (
  `instructor_id` varchar(10) NOT NULL COMMENT 'Format INS0000001',
  `user_id` varchar(10) NOT NULL,
  `first_name` varchar(50) NOT NULL,
  `last_name` varchar(50) NOT NULL,
  PRIMARY KEY (`instructor_id`),
  UNIQUE KEY `uq_instructors_user_id` (`user_id`),
  KEY `ix_instructors_name` (`last_name`,`first_name`),
  CONSTRAINT `fk_instructors_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_instructors_id_format` CHECK (regexp_like(`instructor_id`,_utf8mb4'^INS[0-9]{7}$',_utf8mb4'c')),
  CONSTRAINT `ck_instructors_names` CHECK (((trim(`first_name`) <> _utf8mb4'') and (trim(`last_name`) <> _utf8mb4'')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `instructors`
--

LOCK TABLES `instructors` WRITE;
/*!40000 ALTER TABLE `instructors` DISABLE KEYS */;
INSERT INTO `instructors` VALUES ('INS0000001','USR0000003','Jose','Cruz'),('INS0000002','USR0000004','Liza','Garcia'),('INS0000003','USR0000005','Ramon','Villanueva'),('INS0000004','USR0000002','Carlo','Mendoza'),('INS0000005','USR0000014','Paolo','Lim'),('INS0000006','USR0000013','Hannah','Cruz');
/*!40000 ALTER TABLE `instructors` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_instructors_audit_ins` AFTER INSERT ON `instructors` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'instructors', NEW.instructor_id, @app_user_id, USER(),
            CONCAT('Created instructors record ', NEW.instructor_id), NULL,
            JSON_OBJECT('instructor_id', NEW.instructor_id, 'user_id', NEW.user_id, 'first_name', NEW.first_name, 'last_name', NEW.last_name));
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_instructors_audit_upd` AFTER UPDATE ON `instructors` FOR EACH ROW BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.instructor_id <=> NEW.instructor_id) OR NOT (OLD.user_id <=> NEW.user_id) OR NOT (OLD.first_name <=> NEW.first_name) OR NOT (OLD.last_name <=> NEW.last_name) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'instructors', NEW.instructor_id, @app_user_id, USER(),
                CONCAT('Updated instructors record ', NEW.instructor_id),
                JSON_OBJECT('instructor_id', OLD.instructor_id, 'user_id', OLD.user_id, 'first_name', OLD.first_name, 'last_name', OLD.last_name),
                JSON_OBJECT('instructor_id', NEW.instructor_id, 'user_id', NEW.user_id, 'first_name', NEW.first_name, 'last_name', NEW.last_name));
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_instructors_audit_del` AFTER DELETE ON `instructors` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'instructors', OLD.instructor_id, @app_user_id, USER(),
            CONCAT('Deleted instructors record ', OLD.instructor_id),
            JSON_OBJECT('instructor_id', OLD.instructor_id, 'user_id', OLD.user_id, 'first_name', OLD.first_name, 'last_name', OLD.last_name), NULL);
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `materials`
--

DROP TABLE IF EXISTS `materials`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `materials` (
  `material_id` varchar(10) NOT NULL COMMENT 'Format MAT0000001',
  `subject_id` varchar(10) NOT NULL,
  `instructor_id` varchar(10) NOT NULL,
  `title` varchar(255) NOT NULL,
  `file_path` varchar(255) NOT NULL,
  `uploaded_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`material_id`),
  KEY `fk_materials_instructor` (`instructor_id`),
  KEY `ix_materials_subject_uploaded` (`subject_id`,`uploaded_at`),
  CONSTRAINT `fk_materials_instructor` FOREIGN KEY (`instructor_id`) REFERENCES `instructors` (`instructor_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_materials_subject` FOREIGN KEY (`subject_id`) REFERENCES `subjects` (`subject_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_materials_id_format` CHECK (regexp_like(`material_id`,_utf8mb4'^MAT[0-9]{7}$',_utf8mb4'c')),
  CONSTRAINT `ck_materials_path_not_blank` CHECK ((trim(`file_path`) <> _utf8mb4'')),
  CONSTRAINT `ck_materials_title_not_blank` CHECK ((trim(`title`) <> _utf8mb4''))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `materials`
--

LOCK TABLES `materials` WRITE;
/*!40000 ALTER TABLE `materials` DISABLE KEYS */;
INSERT INTO `materials` VALUES ('MAT0000001','SUB0000001','INS0000001','Introduction to Database Security','materials/sub1/intro-db-security.pdf','2026-11-24 23:31:59'),('MAT0000002','SUB0000001','INS0000001','Managing Roles and Privileges','materials/sub1/roles-and-privileges.pdf','2026-11-24 23:31:59'),('MAT0000003','SUB0000001','INS0000001','Audit Trails with Triggers','materials/sub1/audit-trails.pptx','2026-11-24 23:31:59'),('MAT0000004','SUB0000002','INS0000002','HTML5 Document Structure','materials/sub2/html5-structure.pdf','2026-11-24 23:31:59'),('MAT0000005','SUB0000002','INS0000002','CSS Flexbox and Grid Guide','materials/sub2/css-flexbox-grid.pdf','2026-11-24 23:31:59'),('MAT0000006','SUB0000002','INS0000002','JavaScript Basics Video','https://videos.studync.edu/js-basics','2026-11-24 23:31:59'),('MAT0000007','SUB0000003','INS0000003','Big-O Notation Lecture','materials/sub3/big-o.pdf','2026-11-24 23:31:59'),('MAT0000008','SUB0000003','INS0000003','Linked Lists Worksheet','materials/sub3/linked-lists.docx','2026-11-24 23:31:59'),('MAT0000009','SUB0000001','INS0000001','Database Testing Guide - Updated','materials/sub1/database-testing-guide.pdf','2026-11-25 01:12:04');
/*!40000 ALTER TABLE `materials` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_materials_audit_ins` AFTER INSERT ON `materials` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'materials', NEW.material_id, @app_user_id, USER(),
            CONCAT('Created materials record ', NEW.material_id), NULL,
            JSON_OBJECT('material_id', NEW.material_id, 'subject_id', NEW.subject_id, 'instructor_id', NEW.instructor_id, 'title', NEW.title, 'file_path', NEW.file_path, 'uploaded_at', NEW.uploaded_at));
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_materials_audit_upd` AFTER UPDATE ON `materials` FOR EACH ROW BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.material_id <=> NEW.material_id) OR NOT (OLD.subject_id <=> NEW.subject_id) OR NOT (OLD.instructor_id <=> NEW.instructor_id) OR NOT (OLD.title <=> NEW.title) OR NOT (OLD.file_path <=> NEW.file_path) OR NOT (OLD.uploaded_at <=> NEW.uploaded_at) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'materials', NEW.material_id, @app_user_id, USER(),
                CONCAT('Updated materials record ', NEW.material_id),
                JSON_OBJECT('material_id', OLD.material_id, 'subject_id', OLD.subject_id, 'instructor_id', OLD.instructor_id, 'title', OLD.title, 'file_path', OLD.file_path, 'uploaded_at', OLD.uploaded_at),
                JSON_OBJECT('material_id', NEW.material_id, 'subject_id', NEW.subject_id, 'instructor_id', NEW.instructor_id, 'title', NEW.title, 'file_path', NEW.file_path, 'uploaded_at', NEW.uploaded_at));
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_materials_audit_del` AFTER DELETE ON `materials` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'materials', OLD.material_id, @app_user_id, USER(),
            CONCAT('Deleted materials record ', OLD.material_id),
            JSON_OBJECT('material_id', OLD.material_id, 'subject_id', OLD.subject_id, 'instructor_id', OLD.instructor_id, 'title', OLD.title, 'file_path', OLD.file_path, 'uploaded_at', OLD.uploaded_at), NULL);
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `questions`
--

DROP TABLE IF EXISTS `questions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `questions` (
  `question_id` varchar(10) NOT NULL COMMENT 'Format QST0000001',
  `quiz_id` varchar(10) NOT NULL,
  `question_text` text NOT NULL,
  `correct_answer` varchar(255) NOT NULL,
  `option_a` varchar(255) NOT NULL,
  `option_b` varchar(255) NOT NULL,
  `option_c` varchar(255) NOT NULL,
  `option_d` varchar(255) NOT NULL,
  PRIMARY KEY (`question_id`),
  KEY `fk_questions_quiz` (`quiz_id`),
  CONSTRAINT `fk_questions_quiz` FOREIGN KEY (`quiz_id`) REFERENCES `quizzes` (`quiz_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_questions_correct_is_option` CHECK ((`correct_answer` in (`option_a`,`option_b`,`option_c`,`option_d`))),
  CONSTRAINT `ck_questions_distinct_options` CHECK (((`option_a` <> `option_b`) and (`option_a` <> `option_c`) and (`option_a` <> `option_d`) and (`option_b` <> `option_c`) and (`option_b` <> `option_d`) and (`option_c` <> `option_d`))),
  CONSTRAINT `ck_questions_id_format` CHECK (regexp_like(`question_id`,_utf8mb4'^QST[0-9]{7}$',_utf8mb4'c')),
  CONSTRAINT `ck_questions_text_not_blank` CHECK ((trim(`question_text`) <> _utf8mb4''))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `questions`
--

LOCK TABLES `questions` WRITE;
/*!40000 ALTER TABLE `questions` DISABLE KEYS */;
INSERT INTO `questions` VALUES ('QST0000001','QUZ0000001','Which SQL statement gives a privilege to a user or role?','GRANT','REVOKE','GRANT','DENY','ALLOW'),('QST0000002','QUZ0000001','Which attack inserts malicious SQL through user input?','SQL injection','Phishing','Brute force','SQL injection','Spoofing'),('QST0000003','QUZ0000001','What should be stored instead of a plain-text password?','A salted hash','A salted hash','The password in upper case','An encrypted email','Nothing'),('QST0000004','QUZ0000001','Which object can hide sensitive columns from users?','View','Index','Trigger','Sequence','View'),('QST0000005','QUZ0000001','The principle of giving users only the access they need is called:','Least privilege','Defense in depth','Least privilege','Separation of data','Normalization'),('QST0000006','QUZ0000002','Which statement removes a previously granted privilege?','REVOKE','REVOKE','DROP','DELETE','REMOVE'),('QST0000007','QUZ0000002','A named group of privileges is called a:','Role','Schema','Synonym','Role','Cursor'),('QST0000008','QUZ0000002','Which privilege allows calling a stored procedure?','EXECUTE','SELECT','EXECUTE','USAGE','CALL'),('QST0000009','QUZ0000002','Which table records who changed data and when?','Audit log','Temp table','Lookup table','Junction table','Audit log'),('QST0000010','QUZ0000003','Which tag creates the largest heading?','<h1>','<head>','<h6>','<h1>','<header>'),('QST0000011','QUZ0000003','Which CSS property changes text color?','color','color','font-color','text-color','fg'),('QST0000012','QUZ0000003','Which HTML element links an external stylesheet?','<link>','<style>','<script>','<css>','<link>'),('QST0000013','QUZ0000003','Which CSS display value creates a flex container?','flex','block','flex','grid-inline','inline'),('QST0000014','QUZ0000004','What is the time complexity of binary search?','O(log n)','O(n)','O(log n)','O(n log n)','O(1)'),('QST0000015','QUZ0000004','Accessing an array element by index is:','O(1)','O(1)','O(n)','O(log n)','O(n^2)'),('QST0000016','QUZ0000004','A nested loop over n items is usually:','O(n^2)','O(n)','O(log n)','O(n^2)','O(1)'),('QST0000017','QUZ0000005','Which keyword declares a block-scoped variable?','let','let','var','def','dim'),('QST0000018','QUZ0000005','Which method prints to the browser console?','console.log()','print()','echo()','write()','console.log()'),('QST0000019','QUZ0000005','What does === compare?','Value and type','Value only','Value and type','Reference only','Length'),('QST0000020','QUZ0000006','Which SQL command retrieves data from a table?','SELECT','INSERT','SELECT','UPDATE','DELETE');
/*!40000 ALTER TABLE `questions` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_questions_audit_ins` AFTER INSERT ON `questions` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'questions', NEW.question_id, @app_user_id, USER(),
            CONCAT('Created questions record ', NEW.question_id), NULL,
            JSON_OBJECT('question_id', NEW.question_id, 'quiz_id', NEW.quiz_id, 'question_text', NEW.question_text, 'correct_answer', NEW.correct_answer, 'option_a', NEW.option_a, 'option_b', NEW.option_b, 'option_c', NEW.option_c, 'option_d', NEW.option_d));
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_questions_audit_upd` AFTER UPDATE ON `questions` FOR EACH ROW BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.question_id <=> NEW.question_id) OR NOT (OLD.quiz_id <=> NEW.quiz_id) OR NOT (OLD.question_text <=> NEW.question_text) OR NOT (OLD.correct_answer <=> NEW.correct_answer) OR NOT (OLD.option_a <=> NEW.option_a) OR NOT (OLD.option_b <=> NEW.option_b) OR NOT (OLD.option_c <=> NEW.option_c) OR NOT (OLD.option_d <=> NEW.option_d) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'questions', NEW.question_id, @app_user_id, USER(),
                CONCAT('Updated questions record ', NEW.question_id),
                JSON_OBJECT('question_id', OLD.question_id, 'quiz_id', OLD.quiz_id, 'question_text', OLD.question_text, 'correct_answer', OLD.correct_answer, 'option_a', OLD.option_a, 'option_b', OLD.option_b, 'option_c', OLD.option_c, 'option_d', OLD.option_d),
                JSON_OBJECT('question_id', NEW.question_id, 'quiz_id', NEW.quiz_id, 'question_text', NEW.question_text, 'correct_answer', NEW.correct_answer, 'option_a', NEW.option_a, 'option_b', NEW.option_b, 'option_c', NEW.option_c, 'option_d', NEW.option_d));
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_questions_audit_del` AFTER DELETE ON `questions` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'questions', OLD.question_id, @app_user_id, USER(),
            CONCAT('Deleted questions record ', OLD.question_id),
            JSON_OBJECT('question_id', OLD.question_id, 'quiz_id', OLD.quiz_id, 'question_text', OLD.question_text, 'correct_answer', OLD.correct_answer, 'option_a', OLD.option_a, 'option_b', OLD.option_b, 'option_c', OLD.option_c, 'option_d', OLD.option_d), NULL);
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `quiz_results`
--

DROP TABLE IF EXISTS `quiz_results`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `quiz_results` (
  `result_id` varchar(10) NOT NULL COMMENT 'Format RES0000001',
  `student_id` varchar(10) NOT NULL,
  `quiz_id` varchar(10) NOT NULL,
  `score` decimal(5,2) NOT NULL DEFAULT '0.00' COMMENT 'Percentage 0.00 - 100.00',
  PRIMARY KEY (`result_id`),
  UNIQUE KEY `uq_quiz_results_student_quiz` (`student_id`,`quiz_id`),
  KEY `ix_quiz_results_quiz_score` (`quiz_id`,`score`),
  CONSTRAINT `fk_quiz_results_quiz` FOREIGN KEY (`quiz_id`) REFERENCES `quizzes` (`quiz_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_quiz_results_student` FOREIGN KEY (`student_id`) REFERENCES `students` (`student_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_quiz_results_id_format` CHECK (regexp_like(`result_id`,_utf8mb4'^RES[0-9]{7}$',_utf8mb4'c')),
  CONSTRAINT `ck_quiz_results_score_range` CHECK ((`score` between 0 and 100))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `quiz_results`
--

LOCK TABLES `quiz_results` WRITE;
/*!40000 ALTER TABLE `quiz_results` DISABLE KEYS */;
INSERT INTO `quiz_results` VALUES ('RES0000001','STU0000001','QUZ0000001',100.00),('RES0000002','STU0000002','QUZ0000001',80.00),('RES0000003','STU0000003','QUZ0000001',60.00),('RES0000004','STU0000004','QUZ0000001',40.00),('RES0000005','STU0000001','QUZ0000002',75.00),('RES0000006','STU0000002','QUZ0000002',100.00),('RES0000007','STU0000005','QUZ0000002',50.00),('RES0000008','STU0000003','QUZ0000003',100.00),('RES0000009','STU0000006','QUZ0000003',25.00),('RES0000010','STU0000001','QUZ0000003',75.00),('RES0000011','STU0000004','QUZ0000004',100.00),('RES0000012','STU0000005','QUZ0000004',66.67),('RES0000013','STU0000001','QUZ0000004',33.33);
/*!40000 ALTER TABLE `quiz_results` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_quiz_results_bi` BEFORE INSERT ON `quiz_results` FOR EACH ROW BEGIN
    SET NEW.score = fn_calculate_quiz_score(NEW.student_id, NEW.quiz_id);
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_quiz_results_audit_ins` AFTER INSERT ON `quiz_results` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'quiz_results', NEW.result_id, @app_user_id, USER(),
            CONCAT('Created quiz_results record ', NEW.result_id), NULL,
            JSON_OBJECT('result_id', NEW.result_id, 'student_id', NEW.student_id, 'quiz_id', NEW.quiz_id, 'score', NEW.score));
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_quiz_results_bu` BEFORE UPDATE ON `quiz_results` FOR EACH ROW BEGIN
    SET NEW.score = fn_calculate_quiz_score(NEW.student_id, NEW.quiz_id);
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_quiz_results_audit_upd` AFTER UPDATE ON `quiz_results` FOR EACH ROW BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.result_id <=> NEW.result_id) OR NOT (OLD.student_id <=> NEW.student_id) OR NOT (OLD.quiz_id <=> NEW.quiz_id) OR NOT (OLD.score <=> NEW.score) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'quiz_results', NEW.result_id, @app_user_id, USER(),
                CONCAT('Updated quiz_results record ', NEW.result_id),
                JSON_OBJECT('result_id', OLD.result_id, 'student_id', OLD.student_id, 'quiz_id', OLD.quiz_id, 'score', OLD.score),
                JSON_OBJECT('result_id', NEW.result_id, 'student_id', NEW.student_id, 'quiz_id', NEW.quiz_id, 'score', NEW.score));
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_quiz_results_audit_del` AFTER DELETE ON `quiz_results` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'quiz_results', OLD.result_id, @app_user_id, USER(),
            CONCAT('Deleted quiz_results record ', OLD.result_id),
            JSON_OBJECT('result_id', OLD.result_id, 'student_id', OLD.student_id, 'quiz_id', OLD.quiz_id, 'score', OLD.score), NULL);
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `quizzes`
--

DROP TABLE IF EXISTS `quizzes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `quizzes` (
  `quiz_id` varchar(10) NOT NULL COMMENT 'Format QUZ0000001',
  `subject_id` varchar(10) NOT NULL,
  `instructor_id` varchar(10) NOT NULL,
  `title` varchar(255) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`quiz_id`),
  KEY `fk_quizzes_instructor` (`instructor_id`),
  KEY `ix_quizzes_subject_created` (`subject_id`,`created_at`),
  CONSTRAINT `fk_quizzes_instructor` FOREIGN KEY (`instructor_id`) REFERENCES `instructors` (`instructor_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_quizzes_subject` FOREIGN KEY (`subject_id`) REFERENCES `subjects` (`subject_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_quizzes_id_format` CHECK (regexp_like(`quiz_id`,_utf8mb4'^QUZ[0-9]{7}$',_utf8mb4'c')),
  CONSTRAINT `ck_quizzes_title_not_blank` CHECK ((trim(`title`) <> _utf8mb4''))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `quizzes`
--

LOCK TABLES `quizzes` WRITE;
/*!40000 ALTER TABLE `quizzes` DISABLE KEYS */;
INSERT INTO `quizzes` VALUES ('QUZ0000001','SUB0000001','INS0000001','SQL Security Basics','2026-11-24 23:31:59'),('QUZ0000002','SUB0000001','INS0000001','Database Roles and Privileges','2026-11-24 23:31:59'),('QUZ0000003','SUB0000002','INS0000002','HTML and CSS Basics','2026-11-24 23:31:59'),('QUZ0000004','SUB0000003','INS0000003','Big-O Notation Quiz','2026-11-24 23:31:59'),('QUZ0000005','SUB0000002','INS0000002','JavaScript Fundamentals','2026-11-24 23:31:59'),('QUZ0000006','SUB0000001','INS0000001','Database Testing Test Quiz','2026-11-25 01:12:17');
/*!40000 ALTER TABLE `quizzes` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_quizzes_audit_ins` AFTER INSERT ON `quizzes` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'quizzes', NEW.quiz_id, @app_user_id, USER(),
            CONCAT('Created quizzes record ', NEW.quiz_id), NULL,
            JSON_OBJECT('quiz_id', NEW.quiz_id, 'subject_id', NEW.subject_id, 'instructor_id', NEW.instructor_id, 'title', NEW.title, 'created_at', NEW.created_at));
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_quizzes_audit_upd` AFTER UPDATE ON `quizzes` FOR EACH ROW BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.quiz_id <=> NEW.quiz_id) OR NOT (OLD.subject_id <=> NEW.subject_id) OR NOT (OLD.instructor_id <=> NEW.instructor_id) OR NOT (OLD.title <=> NEW.title) OR NOT (OLD.created_at <=> NEW.created_at) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'quizzes', NEW.quiz_id, @app_user_id, USER(),
                CONCAT('Updated quizzes record ', NEW.quiz_id),
                JSON_OBJECT('quiz_id', OLD.quiz_id, 'subject_id', OLD.subject_id, 'instructor_id', OLD.instructor_id, 'title', OLD.title, 'created_at', OLD.created_at),
                JSON_OBJECT('quiz_id', NEW.quiz_id, 'subject_id', NEW.subject_id, 'instructor_id', NEW.instructor_id, 'title', NEW.title, 'created_at', NEW.created_at));
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_quizzes_audit_del` AFTER DELETE ON `quizzes` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'quizzes', OLD.quiz_id, @app_user_id, USER(),
            CONCAT('Deleted quizzes record ', OLD.quiz_id),
            JSON_OBJECT('quiz_id', OLD.quiz_id, 'subject_id', OLD.subject_id, 'instructor_id', OLD.instructor_id, 'title', OLD.title, 'created_at', OLD.created_at), NULL);
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `roles`
--

DROP TABLE IF EXISTS `roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `roles` (
  `role_id` varchar(10) NOT NULL COMMENT 'Format ROL0000001',
  `role_name` varchar(50) NOT NULL,
  PRIMARY KEY (`role_id`),
  UNIQUE KEY `uq_roles_role_name` (`role_name`),
  CONSTRAINT `ck_roles_role_name` CHECK ((`role_name` in (_utf8mb4'Administrator',_utf8mb4'Instructor',_utf8mb4'Student')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `roles`
--

LOCK TABLES `roles` WRITE;
/*!40000 ALTER TABLE `roles` DISABLE KEYS */;
INSERT INTO `roles` VALUES ('ROL0000001','Administrator'),('ROL0000002','Instructor'),('ROL0000003','Student');
/*!40000 ALTER TABLE `roles` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_roles_audit_ins` AFTER INSERT ON `roles` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'roles', NEW.role_id, @app_user_id, USER(),
            CONCAT('Created roles record ', NEW.role_id), NULL,
            JSON_OBJECT('role_id', NEW.role_id, 'role_name', NEW.role_name));
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_roles_audit_upd` AFTER UPDATE ON `roles` FOR EACH ROW BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.role_id <=> NEW.role_id) OR NOT (OLD.role_name <=> NEW.role_name) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'roles', NEW.role_id, @app_user_id, USER(),
                CONCAT('Updated roles record ', NEW.role_id),
                JSON_OBJECT('role_id', OLD.role_id, 'role_name', OLD.role_name),
                JSON_OBJECT('role_id', NEW.role_id, 'role_name', NEW.role_name));
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_roles_audit_del` AFTER DELETE ON `roles` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'roles', OLD.role_id, @app_user_id, USER(),
            CONCAT('Deleted roles record ', OLD.role_id),
            JSON_OBJECT('role_id', OLD.role_id, 'role_name', OLD.role_name), NULL);
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `student_answers`
--

DROP TABLE IF EXISTS `student_answers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `student_answers` (
  `answer_id` varchar(10) NOT NULL COMMENT 'Format ANS0000001',
  `student_id` varchar(10) NOT NULL,
  `question_id` varchar(10) NOT NULL,
  `student_answer` varchar(255) DEFAULT NULL,
  `is_correct` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`answer_id`),
  UNIQUE KEY `uq_student_answers_student_question` (`student_id`,`question_id`),
  KEY `fk_student_answers_question` (`question_id`),
  CONSTRAINT `fk_student_answers_question` FOREIGN KEY (`question_id`) REFERENCES `questions` (`question_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_student_answers_student` FOREIGN KEY (`student_id`) REFERENCES `students` (`student_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_student_answers_id_format` CHECK (regexp_like(`answer_id`,_utf8mb4'^ANS[0-9]{7}$',_utf8mb4'c'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `student_answers`
--

LOCK TABLES `student_answers` WRITE;
/*!40000 ALTER TABLE `student_answers` DISABLE KEYS */;
INSERT INTO `student_answers` VALUES ('ANS0000001','STU0000001','QST0000001','GRANT',1),('ANS0000002','STU0000001','QST0000002','SQL injection',1),('ANS0000003','STU0000001','QST0000003','A salted hash',1),('ANS0000004','STU0000001','QST0000004','View',1),('ANS0000005','STU0000001','QST0000005','Least privilege',1),('ANS0000006','STU0000002','QST0000001','GRANT',1),('ANS0000007','STU0000002','QST0000002','SQL injection',1),('ANS0000008','STU0000002','QST0000003','A salted hash',1),('ANS0000009','STU0000002','QST0000004','View',1),('ANS0000010','STU0000002','QST0000005','Defense in depth',0),('ANS0000011','STU0000003','QST0000001','GRANT',1),('ANS0000012','STU0000003','QST0000002','SQL injection',1),('ANS0000013','STU0000003','QST0000003','A salted hash',1),('ANS0000014','STU0000003','QST0000004','Index',0),('ANS0000015','STU0000003','QST0000005','Separation of data',0),('ANS0000016','STU0000004','QST0000001','REVOKE',0),('ANS0000017','STU0000004','QST0000002','SQL injection',1),('ANS0000018','STU0000004','QST0000003','Nothing',0),('ANS0000019','STU0000004','QST0000004','View',1),('ANS0000020','STU0000001','QST0000006','REVOKE',1),('ANS0000021','STU0000001','QST0000007','Role',1),('ANS0000022','STU0000001','QST0000008','EXECUTE',1),('ANS0000023','STU0000001','QST0000009','Temp table',0),('ANS0000024','STU0000002','QST0000006','REVOKE',1),('ANS0000025','STU0000002','QST0000007','Role',1),('ANS0000026','STU0000002','QST0000008','EXECUTE',1),('ANS0000027','STU0000002','QST0000009','Audit log',1),('ANS0000028','STU0000005','QST0000006','REVOKE',1),('ANS0000029','STU0000005','QST0000007','Schema',0),('ANS0000030','STU0000005','QST0000008','EXECUTE',1),('ANS0000031','STU0000005','QST0000009','Temp table',0),('ANS0000032','STU0000003','QST0000010','<h1>',1),('ANS0000033','STU0000003','QST0000011','color',1),('ANS0000034','STU0000003','QST0000012','<link>',1),('ANS0000035','STU0000003','QST0000013','flex',1),('ANS0000036','STU0000006','QST0000010','<head>',0),('ANS0000037','STU0000006','QST0000011','color',1),('ANS0000038','STU0000006','QST0000012','<style>',0),('ANS0000039','STU0000006','QST0000013','block',0),('ANS0000040','STU0000001','QST0000010','<h1>',1),('ANS0000041','STU0000001','QST0000011','color',1),('ANS0000042','STU0000001','QST0000012','<link>',1),('ANS0000043','STU0000001','QST0000013','grid-inline',0),('ANS0000044','STU0000004','QST0000014','O(log n)',1),('ANS0000045','STU0000004','QST0000015','O(1)',1),('ANS0000046','STU0000004','QST0000016','O(n^2)',1),('ANS0000047','STU0000005','QST0000014','O(log n)',1),('ANS0000048','STU0000005','QST0000015','O(1)',1),('ANS0000049','STU0000005','QST0000016','O(1)',0),('ANS0000050','STU0000001','QST0000014','O(log n)',1);
/*!40000 ALTER TABLE `student_answers` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_student_answers_bi` BEFORE INSERT ON `student_answers` FOR EACH ROW BEGIN
    DECLARE v_quiz_id  VARCHAR(10);
    DECLARE v_correct  VARCHAR(255);
    SELECT quiz_id, correct_answer INTO v_quiz_id, v_correct
      FROM questions WHERE question_id = NEW.question_id;
    -- answers are locked once the quiz result exists
    IF EXISTS (SELECT 1 FROM quiz_results WHERE student_id = NEW.student_id AND quiz_id = v_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz already submitted; answers are locked';
    END IF;
    -- correctness is decided by the database, never by the client
    SET NEW.is_correct = (NEW.student_answer IS NOT NULL AND NEW.student_answer = v_correct);
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_student_answers_audit_ins` AFTER INSERT ON `student_answers` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'student_answers', NEW.answer_id, @app_user_id, USER(),
            CONCAT('Created student_answers record ', NEW.answer_id), NULL,
            JSON_OBJECT('answer_id', NEW.answer_id, 'student_id', NEW.student_id, 'question_id', NEW.question_id, 'student_answer', NEW.student_answer, 'is_correct', NEW.is_correct));
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_student_answers_bu` BEFORE UPDATE ON `student_answers` FOR EACH ROW BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student answers cannot be modified once submitted';
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_student_answers_audit_upd` AFTER UPDATE ON `student_answers` FOR EACH ROW BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.answer_id <=> NEW.answer_id) OR NOT (OLD.student_id <=> NEW.student_id) OR NOT (OLD.question_id <=> NEW.question_id) OR NOT (OLD.student_answer <=> NEW.student_answer) OR NOT (OLD.is_correct <=> NEW.is_correct) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'student_answers', NEW.answer_id, @app_user_id, USER(),
                CONCAT('Updated student_answers record ', NEW.answer_id),
                JSON_OBJECT('answer_id', OLD.answer_id, 'student_id', OLD.student_id, 'question_id', OLD.question_id, 'student_answer', OLD.student_answer, 'is_correct', OLD.is_correct),
                JSON_OBJECT('answer_id', NEW.answer_id, 'student_id', NEW.student_id, 'question_id', NEW.question_id, 'student_answer', NEW.student_answer, 'is_correct', NEW.is_correct));
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_student_answers_audit_del` AFTER DELETE ON `student_answers` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'student_answers', OLD.answer_id, @app_user_id, USER(),
            CONCAT('Deleted student_answers record ', OLD.answer_id),
            JSON_OBJECT('answer_id', OLD.answer_id, 'student_id', OLD.student_id, 'question_id', OLD.question_id, 'student_answer', OLD.student_answer, 'is_correct', OLD.is_correct), NULL);
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `students`
--

DROP TABLE IF EXISTS `students`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `students` (
  `student_id` varchar(10) NOT NULL COMMENT 'Format STU0000001',
  `user_id` varchar(10) NOT NULL,
  `first_name` varchar(50) NOT NULL,
  `last_name` varchar(50) NOT NULL,
  PRIMARY KEY (`student_id`),
  UNIQUE KEY `uq_students_user_id` (`user_id`),
  KEY `ix_students_name` (`last_name`,`first_name`),
  CONSTRAINT `fk_students_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_students_id_format` CHECK (regexp_like(`student_id`,_utf8mb4'^STU[0-9]{7}$',_utf8mb4'c')),
  CONSTRAINT `ck_students_names` CHECK (((trim(`first_name`) <> _utf8mb4'') and (trim(`last_name`) <> _utf8mb4'')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `students`
--

LOCK TABLES `students` WRITE;
/*!40000 ALTER TABLE `students` DISABLE KEYS */;
INSERT INTO `students` VALUES ('STU0000001','USR0000006','Ana','Santos'),('STU0000002','USR0000007','Ben','Torres'),('STU0000003','USR0000008','Carla','Dizon'),('STU0000004','USR0000009','Diego','Ramos'),('STU0000005','USR0000010','Ella','Navarro'),('STU0000006','USR0000011','Felix','Aquino'),('STU0000007','USR0000012','Gina','Lopez'),('STU0000008','USR0000013','Hannah','Cruz');
/*!40000 ALTER TABLE `students` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_students_audit_ins` AFTER INSERT ON `students` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'students', NEW.student_id, @app_user_id, USER(),
            CONCAT('Created students record ', NEW.student_id), NULL,
            JSON_OBJECT('student_id', NEW.student_id, 'user_id', NEW.user_id, 'first_name', NEW.first_name, 'last_name', NEW.last_name));
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_students_audit_upd` AFTER UPDATE ON `students` FOR EACH ROW BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.student_id <=> NEW.student_id) OR NOT (OLD.user_id <=> NEW.user_id) OR NOT (OLD.first_name <=> NEW.first_name) OR NOT (OLD.last_name <=> NEW.last_name) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'students', NEW.student_id, @app_user_id, USER(),
                CONCAT('Updated students record ', NEW.student_id),
                JSON_OBJECT('student_id', OLD.student_id, 'user_id', OLD.user_id, 'first_name', OLD.first_name, 'last_name', OLD.last_name),
                JSON_OBJECT('student_id', NEW.student_id, 'user_id', NEW.user_id, 'first_name', NEW.first_name, 'last_name', NEW.last_name));
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_students_audit_del` AFTER DELETE ON `students` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'students', OLD.student_id, @app_user_id, USER(),
            CONCAT('Deleted students record ', OLD.student_id),
            JSON_OBJECT('student_id', OLD.student_id, 'user_id', OLD.user_id, 'first_name', OLD.first_name, 'last_name', OLD.last_name), NULL);
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `subjects`
--

DROP TABLE IF EXISTS `subjects`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `subjects` (
  `subject_id` varchar(10) NOT NULL COMMENT 'Format SUB0000001',
  `subject_name` varchar(100) NOT NULL,
  `description` text,
  PRIMARY KEY (`subject_id`),
  UNIQUE KEY `uq_subjects_subject_name` (`subject_name`),
  CONSTRAINT `ck_subjects_id_format` CHECK (regexp_like(`subject_id`,_utf8mb4'^SUB[0-9]{7}$',_utf8mb4'c')),
  CONSTRAINT `ck_subjects_name_not_blank` CHECK ((trim(`subject_name`) <> _utf8mb4''))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `subjects`
--

LOCK TABLES `subjects` WRITE;
/*!40000 ALTER TABLE `subjects` DISABLE KEYS */;
INSERT INTO `subjects` VALUES ('SUB0000001','Database Security and Administration','Roles, privileges, auditing, backup and recovery of relational databases.'),('SUB0000002','Web Development Fundamentals','HTML, CSS and JavaScript for building accessible web pages.'),('SUB0000003','Data Structures and Algorithms','Arrays, lists, trees, graphs and algorithm analysis.'),('SUB0000004','Networking Essentials','OSI model, TCP/IP, IP addressing, subnetting and basic network security.'),('SUB0000005','Technical Writing','Writing clear technical documentation and reports.'),('SUB0000006','Information Assurance','Security policies and risk management.'),('SUB0000007','Database Testing Practice','Subject created to test StudyNC database functions.');
/*!40000 ALTER TABLE `subjects` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_subjects_audit_ins` AFTER INSERT ON `subjects` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'subjects', NEW.subject_id, @app_user_id, USER(),
            CONCAT('Created subjects record ', NEW.subject_id), NULL,
            JSON_OBJECT('subject_id', NEW.subject_id, 'subject_name', NEW.subject_name, 'description', NEW.description));
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_subjects_audit_upd` AFTER UPDATE ON `subjects` FOR EACH ROW BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.subject_id <=> NEW.subject_id) OR NOT (OLD.subject_name <=> NEW.subject_name) OR NOT (OLD.description <=> NEW.description) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'subjects', NEW.subject_id, @app_user_id, USER(),
                CONCAT('Updated subjects record ', NEW.subject_id),
                JSON_OBJECT('subject_id', OLD.subject_id, 'subject_name', OLD.subject_name, 'description', OLD.description),
                JSON_OBJECT('subject_id', NEW.subject_id, 'subject_name', NEW.subject_name, 'description', NEW.description));
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_subjects_audit_del` AFTER DELETE ON `subjects` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'subjects', OLD.subject_id, @app_user_id, USER(),
            CONCAT('Deleted subjects record ', OLD.subject_id),
            JSON_OBJECT('subject_id', OLD.subject_id, 'subject_name', OLD.subject_name, 'description', OLD.description), NULL);
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `user_roles`
--

DROP TABLE IF EXISTS `user_roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_roles` (
  `user_id` varchar(10) NOT NULL,
  `role_id` varchar(10) NOT NULL,
  PRIMARY KEY (`user_id`,`role_id`),
  KEY `fk_user_roles_role` (`role_id`),
  CONSTRAINT `fk_user_roles_role` FOREIGN KEY (`role_id`) REFERENCES `roles` (`role_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_user_roles_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_roles`
--

LOCK TABLES `user_roles` WRITE;
/*!40000 ALTER TABLE `user_roles` DISABLE KEYS */;
INSERT INTO `user_roles` VALUES ('USR0000001','ROL0000001'),('USR0000002','ROL0000001'),('USR0000002','ROL0000002'),('USR0000003','ROL0000002'),('USR0000004','ROL0000002'),('USR0000005','ROL0000002'),('USR0000014','ROL0000002'),('USR0000006','ROL0000003'),('USR0000007','ROL0000003'),('USR0000008','ROL0000003'),('USR0000009','ROL0000003'),('USR0000010','ROL0000003'),('USR0000011','ROL0000003'),('USR0000012','ROL0000003'),('USR0000013','ROL0000003');
/*!40000 ALTER TABLE `user_roles` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_user_roles_audit_ins` AFTER INSERT ON `user_roles` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'user_roles', CONCAT(NEW.user_id,':',NEW.role_id), @app_user_id, USER(),
            CONCAT('Created user_roles record ', CONCAT(NEW.user_id,':',NEW.role_id)), NULL,
            JSON_OBJECT('user_id', NEW.user_id, 'role_id', NEW.role_id));
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_user_roles_audit_upd` AFTER UPDATE ON `user_roles` FOR EACH ROW BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.user_id <=> NEW.user_id) OR NOT (OLD.role_id <=> NEW.role_id) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'user_roles', CONCAT(NEW.user_id,':',NEW.role_id), @app_user_id, USER(),
                CONCAT('Updated user_roles record ', CONCAT(NEW.user_id,':',NEW.role_id)),
                JSON_OBJECT('user_id', OLD.user_id, 'role_id', OLD.role_id),
                JSON_OBJECT('user_id', NEW.user_id, 'role_id', NEW.role_id));
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_user_roles_audit_del` AFTER DELETE ON `user_roles` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'user_roles', CONCAT(OLD.user_id,':',OLD.role_id), @app_user_id, USER(),
            CONCAT('Deleted user_roles record ', CONCAT(OLD.user_id,':',OLD.role_id)),
            JSON_OBJECT('user_id', OLD.user_id, 'role_id', OLD.role_id), NULL);
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `user_id` varchar(10) NOT NULL COMMENT 'Format USR0000001',
  `username` varchar(50) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password_hash` varchar(255) NOT NULL COMMENT 'Salted, iterated SHA-256 hash - never plain text',
  `status` enum('Active','Inactive') NOT NULL DEFAULT 'Active',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `uq_users_username` (`username`),
  UNIQUE KEY `uq_users_email` (`email`),
  KEY `ix_users_status` (`status`),
  CONSTRAINT `ck_users_email_format` CHECK (regexp_like(`email`,_utf8mb4'^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$')),
  CONSTRAINT `ck_users_hash_length` CHECK ((char_length(`password_hash`) >= 60)),
  CONSTRAINT `ck_users_id_format` CHECK (regexp_like(`user_id`,_utf8mb4'^USR[0-9]{7}$',_utf8mb4'c')),
  CONSTRAINT `ck_users_username_format` CHECK (regexp_like(`username`,_utf8mb4'^[A-Za-z0-9._]{3,50}$'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES ('USR0000001','maria.reyes','maria.reyes@studync.edu','$sha256$5000$57B5970F3DD4B46735CCC31438E47230$bda1732575f17f51599096c8c9adf54a22ff459b37a076c913539f5df1c58e9d','Active','2026-11-24 23:31:59'),('USR0000002','carlo.mendoza','carlo.mendoza@studync.edu','$sha256$5000$AE363A7768509198800E3458A0E00693$77e02c4432a848589f6b1df43f0b58a0dda504c619863403f47b505626984760','Active','2026-11-24 23:31:59'),('USR0000003','jose.cruz','jose.cruz@studync.edu','$sha256$5000$BA9F1A49E450054C5BCE91144C3B0613$329c48c1796952588ba3efba797cfcb154bbe5bbe6453c6d7543dc23d884c6a1','Active','2026-11-24 23:31:59'),('USR0000004','liza.garcia','liza.garcia@studync.edu','$sha256$5000$2F78D5F1F63B5CA72C469D91FDE6DF4B$81aeab34e36e985e54ff074accebb5c24f315805cd81cb085bbe07103bcab4f7','Active','2026-11-24 23:31:59'),('USR0000005','ramon.villanueva','ramon.villanueva@studync.edu','$sha256$5000$FF3C31ED306C76F6147A13B5D3895CB7$a957a252b47fc5e06ee5239bd447b7ced2b3726660467bf23e8d346b5aedaed8','Active','2026-11-24 23:31:59'),('USR0000006','ana.santos','ana.updated@studync.edu','$sha256$5000$A0E9860283CC0452601C0E57C9A51914$408bafa4bf1b4b8517d4583a351b66514a9e2354a7ad4d203d0f9fb97d95c98c','Active','2026-11-24 23:31:59'),('USR0000007','ben.torres','ben.torres@studync.edu','$sha256$5000$7E49041CE8255EB4DF4A7729508ACEA1$86a0cbbdce4536a7457416f89fe2cdab6121f7e74273da5995e5bea89421cd96','Active','2026-11-24 23:31:59'),('USR0000008','carla.dizon','carla.dizon@studync.edu','$sha256$5000$9D3BA36E9CECCEF45A46E67AD544DB47$8450f93ee7117b92e9d3d8440eb35575e0a092b7c825cda7daa57467611528e5','Active','2026-11-24 23:31:59'),('USR0000009','diego.ramos','diego.ramos@studync.edu','$sha256$5000$CD03FD26C30A9D6D60510DEC55C5EA57$3ae773b08b97be2fed85b4ae5e20bb8cfece015f24e46f52ab9d7ce4a28eee97','Active','2026-11-24 23:31:59'),('USR0000010','ella.navarro','ella.navarro@studync.edu','$sha256$5000$40D05F5BC80D06D3EE1FDD075D400CD7$ff49f5893607745f6f08a1ef6d2211d208cf8bac3970744c4a62b9df42abe3c4','Active','2026-11-24 23:31:59'),('USR0000011','felix.aquino','felix.aquino@studync.edu','$sha256$5000$CC4390E2D3A726AC4CCC456EA4AA211B$d7adc766bdb7d680d0aa4d7bb8785172a8905522201c21206e512928778b9182','Active','2026-11-24 23:31:59'),('USR0000012','gina.lopez','gina.lopez@studync.edu','$sha256$5000$F6D4F17460ADC0ADADE007B49B14690E$51a10fe467a39c1c132df798c8c48e0731a2135d65a8cbff64d0e05e3a82e166','Active','2026-11-24 23:31:59'),('USR0000013','hana.cruz','hana.cruz2@studync.edu','$sha256$5000$BBD7E87FE81217341E981C8ADC8FB428$e480f10c7c77e3ac154b4aa734cd6e2c12c7f5999904dd406834d4e254a458a0','Active','2026-11-24 23:32:30'),('USR0000014','paolo.lim','paolo.lim@studync.edu','$sha256$5000$2146C1FF75577867B893FBF47C5997DB$dbf2451e354087d1bb79194efaa5bed16ae2786f0306415291da1d8b306498cb','Active','2026-11-24 23:32:30');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_users_audit_ins` AFTER INSERT ON `users` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('INSERT', 'users', NEW.user_id, @app_user_id, USER(),
            CONCAT('Created users record ', NEW.user_id), NULL,
            JSON_OBJECT('user_id', NEW.user_id, 'username', NEW.username, 'email', NEW.email, 'status', NEW.status, 'created_at', NEW.created_at));
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_users_audit_upd` AFTER UPDATE ON `users` FOR EACH ROW BEGIN
    -- log only real changes (no duplicate rows for no-op updates)
    IF NOT (OLD.user_id <=> NEW.user_id) OR NOT (OLD.username <=> NEW.username) OR NOT (OLD.email <=> NEW.email) OR NOT (OLD.status <=> NEW.status) OR NOT (OLD.created_at <=> NEW.created_at) OR NOT (OLD.password_hash <=> NEW.password_hash) THEN
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
        VALUES ('UPDATE', 'users', NEW.user_id, @app_user_id, USER(),
                CONCAT('Updated users record ', NEW.user_id),
                JSON_OBJECT('user_id', OLD.user_id, 'username', OLD.username, 'email', OLD.email, 'status', OLD.status, 'created_at', OLD.created_at),
                JSON_OBJECT('user_id', NEW.user_id, 'username', NEW.username, 'email', NEW.email, 'status', NEW.status, 'created_at', NEW.created_at, 'password_changed', NOT (OLD.password_hash <=> NEW.password_hash)));
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_users_audit_del` AFTER DELETE ON `users` FOR EACH ROW BEGIN
    INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description, old_data, new_data)
    VALUES ('DELETE', 'users', OLD.user_id, @app_user_id, USER(),
            CONCAT('Deleted users record ', OLD.user_id),
            JSON_OBJECT('user_id', OLD.user_id, 'username', OLD.username, 'email', OLD.email, 'status', OLD.status, 'created_at', OLD.created_at), NULL);
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Temporary view structure for view `v_audit_trail`
--

DROP TABLE IF EXISTS `v_audit_trail`;
/*!50001 DROP VIEW IF EXISTS `v_audit_trail`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_audit_trail` AS SELECT 
 1 AS `log_id`,
 1 AS `log_timestamp`,
 1 AS `action_type`,
 1 AS `table_name`,
 1 AS `record_id`,
 1 AS `performed_by`,
 1 AS `performed_by_username`,
 1 AS `db_user`,
 1 AS `description`,
 1 AS `old_data`,
 1 AS `new_data`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `v_learning_materials`
--

DROP TABLE IF EXISTS `v_learning_materials`;
/*!50001 DROP VIEW IF EXISTS `v_learning_materials`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_learning_materials` AS SELECT 
 1 AS `material_id`,
 1 AS `title`,
 1 AS `file_path`,
 1 AS `uploaded_at`,
 1 AS `subject_id`,
 1 AS `subject_name`,
 1 AS `instructor_id`,
 1 AS `instructor_name`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `v_my_results`
--

DROP TABLE IF EXISTS `v_my_results`;
/*!50001 DROP VIEW IF EXISTS `v_my_results`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_my_results` AS SELECT 
 1 AS `result_id`,
 1 AS `quiz_id`,
 1 AS `quiz_title`,
 1 AS `subject_name`,
 1 AS `score`,
 1 AS `correct_answers`,
 1 AS `total_questions`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `v_quiz_overview`
--

DROP TABLE IF EXISTS `v_quiz_overview`;
/*!50001 DROP VIEW IF EXISTS `v_quiz_overview`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_quiz_overview` AS SELECT 
 1 AS `quiz_id`,
 1 AS `title`,
 1 AS `created_at`,
 1 AS `subject_id`,
 1 AS `subject_name`,
 1 AS `instructor_id`,
 1 AS `instructor_name`,
 1 AS `question_count`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `v_quiz_questions_instructor`
--

DROP TABLE IF EXISTS `v_quiz_questions_instructor`;
/*!50001 DROP VIEW IF EXISTS `v_quiz_questions_instructor`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_quiz_questions_instructor` AS SELECT 
 1 AS `question_id`,
 1 AS `quiz_id`,
 1 AS `quiz_title`,
 1 AS `instructor_id`,
 1 AS `question_text`,
 1 AS `option_a`,
 1 AS `option_b`,
 1 AS `option_c`,
 1 AS `option_d`,
 1 AS `correct_answer`,
 1 AS `times_answered`,
 1 AS `times_correct`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `v_quiz_questions_student`
--

DROP TABLE IF EXISTS `v_quiz_questions_student`;
/*!50001 DROP VIEW IF EXISTS `v_quiz_questions_student`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_quiz_questions_student` AS SELECT 
 1 AS `question_id`,
 1 AS `quiz_id`,
 1 AS `quiz_title`,
 1 AS `question_text`,
 1 AS `option_a`,
 1 AS `option_b`,
 1 AS `option_c`,
 1 AS `option_d`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `v_quiz_results_detail`
--

DROP TABLE IF EXISTS `v_quiz_results_detail`;
/*!50001 DROP VIEW IF EXISTS `v_quiz_results_detail`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_quiz_results_detail` AS SELECT 
 1 AS `result_id`,
 1 AS `student_id`,
 1 AS `student_name`,
 1 AS `quiz_id`,
 1 AS `quiz_title`,
 1 AS `subject_name`,
 1 AS `instructor_id`,
 1 AS `score`,
 1 AS `correct_answers`,
 1 AS `total_questions`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `v_student_performance`
--

DROP TABLE IF EXISTS `v_student_performance`;
/*!50001 DROP VIEW IF EXISTS `v_student_performance`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_student_performance` AS SELECT 
 1 AS `student_id`,
 1 AS `student_name`,
 1 AS `account_status`,
 1 AS `quizzes_taken`,
 1 AS `average_score`,
 1 AS `highest_score`,
 1 AS `lowest_score`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `v_subject_catalog`
--

DROP TABLE IF EXISTS `v_subject_catalog`;
/*!50001 DROP VIEW IF EXISTS `v_subject_catalog`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_subject_catalog` AS SELECT 
 1 AS `subject_id`,
 1 AS `subject_name`,
 1 AS `description`,
 1 AS `material_count`,
 1 AS `quiz_count`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `v_user_directory`
--

DROP TABLE IF EXISTS `v_user_directory`;
/*!50001 DROP VIEW IF EXISTS `v_user_directory`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_user_directory` AS SELECT 
 1 AS `user_id`,
 1 AS `username`,
 1 AS `email`,
 1 AS `status`,
 1 AS `created_at`,
 1 AS `roles`,
 1 AS `admin_id`,
 1 AS `instructor_id`,
 1 AS `student_id`,
 1 AS `full_name`*/;
SET character_set_client = @saved_cs_client;

--
-- Dumping events for database 'studync_db'
--

--
-- Dumping routines for database 'studync_db'
--
/*!50003 DROP FUNCTION IF EXISTS `fn_calculate_quiz_score` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_calculate_quiz_score`(p_student_id VARCHAR(10), p_quiz_id VARCHAR(10)) RETURNS decimal(5,2)
    READS SQL DATA
BEGIN
    DECLARE v_total   INT;
    DECLARE v_correct INT;
    SET v_total = fn_question_count(p_quiz_id);
    IF v_total = 0 THEN
        RETURN 0.00;
    END IF;
    SELECT COUNT(*) INTO v_correct
      FROM student_answers sa
      JOIN questions q ON q.question_id = sa.question_id
     WHERE sa.student_id = p_student_id
       AND q.quiz_id     = p_quiz_id
       AND sa.is_correct = TRUE;
    RETURN ROUND(v_correct * 100.0 / v_total, 2);
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_format_id` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_format_id`(p_prefix CHAR(3), p_number INT UNSIGNED) RETURNS varchar(10) CHARSET utf8mb4
    NO SQL
    DETERMINISTIC
BEGIN
    IF p_number > 9999999 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Identifier range exhausted';
    END IF;
    RETURN CONCAT(p_prefix, LPAD(p_number, 7, '0'));
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_get_instructor_id` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_get_instructor_id`(p_user_id VARCHAR(10)) RETURNS varchar(10) CHARSET utf8mb4
    READS SQL DATA
BEGIN
    RETURN (SELECT instructor_id FROM instructors WHERE user_id = p_user_id);
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_get_student_id` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_get_student_id`(p_user_id VARCHAR(10)) RETURNS varchar(10) CHARSET utf8mb4
    READS SQL DATA
BEGIN
    RETURN (SELECT student_id FROM students WHERE user_id = p_user_id);
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_hash_password` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_hash_password`(p_plain VARCHAR(255), p_salt VARCHAR(64)) RETURNS varchar(255) CHARSET utf8mb4
    NO SQL
    DETERMINISTIC
BEGIN
    RETURN fn_hash_password_iter(p_plain, p_salt, 5000);
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_hash_password_iter` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_hash_password_iter`(p_plain VARCHAR(255), p_salt VARCHAR(64), p_iterations INT) RETURNS varchar(255) CHARSET utf8mb4
    NO SQL
    DETERMINISTIC
BEGIN
    DECLARE v_hash CHAR(64);
    DECLARE i INT DEFAULT 1;
    SET v_hash = SHA2(CONCAT(p_salt, p_plain), 256);
    WHILE i < p_iterations DO
        SET v_hash = SHA2(CONCAT(v_hash, p_salt), 256);
        SET i = i + 1;
    END WHILE;
    RETURN CONCAT('$sha256$', p_iterations, '$', p_salt, '$', v_hash);
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_is_safe_file_path` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_is_safe_file_path`(p_path VARCHAR(255)) RETURNS tinyint(1)
    NO SQL
    DETERMINISTIC
BEGIN
    RETURN p_path IS NOT NULL
       AND TRIM(p_path) <> ''
       AND LOCATE('..', p_path) = 0
       AND LOCATE('\\', p_path) = 0
       AND NOT REGEXP_LIKE(p_path, '[[:cntrl:]]');
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_is_strong_password` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_is_strong_password`(p_plain VARCHAR(255)) RETURNS tinyint(1)
    NO SQL
    DETERMINISTIC
BEGIN
    RETURN p_plain IS NOT NULL
       AND CHAR_LENGTH(p_plain) >= 8
       AND REGEXP_LIKE(p_plain, '[A-Z]', 'c')
       AND REGEXP_LIKE(p_plain, '[a-z]', 'c')
       AND REGEXP_LIKE(p_plain, '[0-9]');
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_question_count` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_question_count`(p_quiz_id VARCHAR(10)) RETURNS int
    READS SQL DATA
BEGIN
    RETURN (SELECT COUNT(*) FROM questions WHERE quiz_id = p_quiz_id);
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_resolve_option` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_resolve_option`(p_input VARCHAR(255), p_a VARCHAR(255), p_b VARCHAR(255),
                                  p_c VARCHAR(255), p_d VARCHAR(255)) RETURNS varchar(255) CHARSET utf8mb4
    NO SQL
    DETERMINISTIC
BEGIN
    DECLARE v_in VARCHAR(255);
    SET v_in = TRIM(p_input);
    IF v_in IS NULL OR v_in = '' THEN
        RETURN NULL;
    END IF;
    IF UPPER(v_in) = 'A' THEN RETURN p_a; END IF;
    IF UPPER(v_in) = 'B' THEN RETURN p_b; END IF;
    IF UPPER(v_in) = 'C' THEN RETURN p_c; END IF;
    IF UPPER(v_in) = 'D' THEN RETURN p_d; END IF;
    IF v_in = p_a THEN RETURN p_a; END IF;
    IF v_in = p_b THEN RETURN p_b; END IF;
    IF v_in = p_c THEN RETURN p_c; END IF;
    IF v_in = p_d THEN RETURN p_d; END IF;
    RETURN NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_user_has_role` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_user_has_role`(p_user_id VARCHAR(10), p_role_name VARCHAR(50)) RETURNS tinyint(1)
    READS SQL DATA
BEGIN
    RETURN EXISTS (SELECT 1
                     FROM user_roles ur
                     JOIN roles r ON r.role_id = ur.role_id
                    WHERE ur.user_id = p_user_id AND r.role_name = p_role_name);
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_verify_password` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_verify_password`(p_plain VARCHAR(255), p_stored VARCHAR(255)) RETURNS tinyint(1)
    NO SQL
    DETERMINISTIC
BEGIN
    DECLARE v_iter INT;
    DECLARE v_salt VARCHAR(64);
    IF p_plain IS NULL OR p_stored IS NULL OR p_stored NOT LIKE '$sha256$%' THEN
        RETURN FALSE;
    END IF;
    SET v_iter = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(p_stored, '$', 3), '$', -1) AS UNSIGNED);
    SET v_salt = SUBSTRING_INDEX(SUBSTRING_INDEX(p_stored, '$', 4), '$', -1);
    RETURN fn_hash_password_iter(p_plain, v_salt, v_iter) = p_stored;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_add_question` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_add_question`(IN p_actor_user_id VARCHAR(10), IN p_quiz_id VARCHAR(10),
                                 IN p_question_text TEXT,
                                 IN p_option_a VARCHAR(255), IN p_option_b VARCHAR(255),
                                 IN p_option_c VARCHAR(255), IN p_option_d VARCHAR(255),
                                 IN p_correct_answer VARCHAR(255), OUT p_question_id VARCHAR(10))
BEGIN
    DECLARE v_correct VARCHAR(255);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    CALL sp_assert_quiz_owner(p_actor_user_id, p_quiz_id);
    IF EXISTS (SELECT 1 FROM quiz_results WHERE quiz_id = p_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz already has submitted results; questions are locked';
    END IF;
    IF p_question_text IS NULL OR TRIM(p_question_text) = ''
       OR p_option_a IS NULL OR p_option_b IS NULL OR p_option_c IS NULL OR p_option_d IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Question text and all four options are required';
    END IF;
    SET v_correct = fn_resolve_option(p_correct_answer, p_option_a, p_option_b, p_option_c, p_option_d);
    IF v_correct IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Correct answer must be A, B, C, D or the exact text of an option';
    END IF;
    CALL sp_next_id('questions', p_question_id);
    INSERT INTO questions (question_id, quiz_id, question_text, correct_answer,
                           option_a, option_b, option_c, option_d)
    VALUES (p_question_id, p_quiz_id, TRIM(p_question_text), v_correct,
            p_option_a, p_option_b, p_option_c, p_option_d);
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_assert_quiz_owner` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_assert_quiz_owner`(IN p_actor_user_id VARCHAR(10), IN p_quiz_id VARCHAR(10))
BEGIN
    DECLARE v_owner VARCHAR(10);
    SET v_owner = (SELECT instructor_id FROM quizzes WHERE quiz_id = p_quiz_id);
    IF v_owner IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz not found';
    END IF;
    IF v_owner <> COALESCE(fn_get_instructor_id(p_actor_user_id), '') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ACCESS DENIED: you can only manage your own quizzes';
    END IF;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_assign_role` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_assign_role`(IN p_actor_user_id VARCHAR(10), IN p_user_id VARCHAR(10),
                                IN p_role_name VARCHAR(50))
BEGIN
    DECLARE v_role_id    VARCHAR(10);
    DECLARE v_first      VARCHAR(50);
    DECLARE v_last       VARCHAR(50);
    DECLARE v_profile_id VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');

    SET v_role_id = (SELECT role_id FROM roles WHERE role_name = p_role_name);
    IF v_role_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown role';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User not found';
    END IF;
    IF EXISTS (SELECT 1 FROM user_roles WHERE user_id = p_user_id AND role_id = v_role_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User already has this role';
    END IF;

    INSERT INTO user_roles (user_id, role_id) VALUES (p_user_id, v_role_id);

    -- make sure the role has its profile row
    IF (p_role_name = 'Administrator' AND NOT EXISTS (SELECT 1 FROM admins      WHERE user_id = p_user_id))
    OR (p_role_name = 'Instructor'    AND NOT EXISTS (SELECT 1 FROM instructors WHERE user_id = p_user_id))
    OR (p_role_name = 'Student'       AND NOT EXISTS (SELECT 1 FROM students    WHERE user_id = p_user_id)) THEN
        SELECT first_name, last_name INTO v_first, v_last FROM (
              SELECT first_name, last_name FROM admins      WHERE user_id = p_user_id
              UNION ALL
              SELECT first_name, last_name FROM instructors WHERE user_id = p_user_id
              UNION ALL
              SELECT first_name, last_name FROM students    WHERE user_id = p_user_id) n
        LIMIT 1;
        CALL sp_create_profile(p_user_id, p_role_name, v_first, v_last, v_profile_id);
    END IF;

    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_authenticate_user` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_authenticate_user`(IN p_username VARCHAR(50), IN p_password VARCHAR(255),
                                      OUT p_success BOOLEAN, OUT p_user_id VARCHAR(10),
                                      OUT p_roles VARCHAR(200), OUT p_message VARCHAR(100))
BEGIN
    DECLARE v_user_id VARCHAR(10);
    DECLARE v_hash    VARCHAR(255);
    DECLARE v_status  VARCHAR(10);

    SELECT user_id, password_hash, status INTO v_user_id, v_hash, v_status
      FROM users WHERE username = p_username;

    IF v_user_id IS NOT NULL AND v_status = 'Active' AND fn_verify_password(p_password, v_hash) THEN
        SET p_success = TRUE;
        SET p_user_id = v_user_id;
        SET p_roles   = (SELECT GROUP_CONCAT(r.role_name ORDER BY r.role_name)
                           FROM user_roles ur JOIN roles r ON r.role_id = ur.role_id
                          WHERE ur.user_id = v_user_id);
        SET p_message = 'Login successful';
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description)
        VALUES ('LOGIN_SUCCESS', 'users', v_user_id, v_user_id, USER(), CONCAT('User ', p_username, ' logged in'));
    ELSE
        SET p_success = FALSE;
        SET p_user_id = NULL;
        SET p_roles   = NULL;
        SET p_message = 'Invalid username or password';
        INSERT INTO audit_logs (action_type, table_name, record_id, performed_by, db_user, description)
        VALUES ('LOGIN_FAILED', 'users', v_user_id, NULL, USER(),
                CONCAT('Failed login for username "', LEFT(COALESCE(p_username, ''), 50), '"',
                       IF(v_status = 'Inactive', ' (inactive account)', '')));
    END IF;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_change_password` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_change_password`(IN p_actor_user_id VARCHAR(10), IN p_old_password VARCHAR(255),
                                    IN p_new_password VARCHAR(255))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');
    IF NOT fn_verify_password(p_old_password, (SELECT password_hash FROM users WHERE user_id = p_actor_user_id)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Current password is incorrect';
    END IF;
    IF NOT fn_is_strong_password(p_new_password) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Weak password: minimum 8 characters with upper-case, lower-case and a digit';
    END IF;
    UPDATE users SET password_hash = fn_hash_password(p_new_password, HEX(RANDOM_BYTES(16)))
     WHERE user_id = p_actor_user_id;
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_create_profile` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_create_profile`(IN p_user_id VARCHAR(10), IN p_role_name VARCHAR(50),
                                   IN p_first_name VARCHAR(50), IN p_last_name VARCHAR(50),
                                   OUT p_profile_id VARCHAR(10))
BEGIN
    IF p_role_name = 'Administrator' THEN
        CALL sp_next_id('admins', p_profile_id);
        INSERT INTO admins (admin_id, user_id, first_name, last_name)
        VALUES (p_profile_id, p_user_id, TRIM(p_first_name), TRIM(p_last_name));
    ELSEIF p_role_name = 'Instructor' THEN
        CALL sp_next_id('instructors', p_profile_id);
        INSERT INTO instructors (instructor_id, user_id, first_name, last_name)
        VALUES (p_profile_id, p_user_id, TRIM(p_first_name), TRIM(p_last_name));
    ELSEIF p_role_name = 'Student' THEN
        CALL sp_next_id('students', p_profile_id);
        INSERT INTO students (student_id, user_id, first_name, last_name)
        VALUES (p_profile_id, p_user_id, TRIM(p_first_name), TRIM(p_last_name));
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid role name';
    END IF;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_create_quiz` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_create_quiz`(IN p_actor_user_id VARCHAR(10), IN p_subject_id VARCHAR(10),
                                IN p_title VARCHAR(255), OUT p_quiz_id VARCHAR(10))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    IF NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = p_subject_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject not found';
    END IF;
    IF p_title IS NULL OR TRIM(p_title) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz title is required';
    END IF;
    CALL sp_next_id('quizzes', p_quiz_id);
    INSERT INTO quizzes (quiz_id, subject_id, instructor_id, title)
    VALUES (p_quiz_id, p_subject_id, fn_get_instructor_id(p_actor_user_id), TRIM(p_title));
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_create_subject` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_create_subject`(IN p_actor_user_id VARCHAR(10), IN p_subject_name VARCHAR(100),
                                   IN p_description TEXT, OUT p_subject_id VARCHAR(10))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    -- 2.1 Validate subject information
    IF p_subject_name IS NULL OR TRIM(p_subject_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject name is required';
    END IF;
    IF EXISTS (SELECT 1 FROM subjects WHERE subject_name = TRIM(p_subject_name)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject name already exists';
    END IF;
    -- 2.2 Create subject / 2.3 Store subject record
    CALL sp_next_id('subjects', p_subject_id);
    INSERT INTO subjects (subject_id, subject_name, description)
    VALUES (p_subject_id, TRIM(p_subject_name), p_description);
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_delete_material` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_delete_material`(IN p_actor_user_id VARCHAR(10), IN p_material_id VARCHAR(10))
BEGIN
    DECLARE v_owner VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    SET v_owner = (SELECT instructor_id FROM materials WHERE material_id = p_material_id FOR UPDATE);
    IF v_owner IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Material not found';
    END IF;
    IF v_owner <> fn_get_instructor_id(p_actor_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ACCESS DENIED: you can only delete your own materials';
    END IF;
    DELETE FROM materials WHERE material_id = p_material_id;
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_delete_question` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_delete_question`(IN p_actor_user_id VARCHAR(10), IN p_question_id VARCHAR(10))
BEGIN
    DECLARE v_quiz_id VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    SET v_quiz_id = (SELECT quiz_id FROM questions WHERE question_id = p_question_id);
    IF v_quiz_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Question not found';
    END IF;
    CALL sp_assert_quiz_owner(p_actor_user_id, v_quiz_id);
    IF EXISTS (SELECT 1 FROM student_answers WHERE question_id = p_question_id)
       OR EXISTS (SELECT 1 FROM quiz_results WHERE quiz_id = v_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Question has already been answered and cannot be deleted';
    END IF;
    DELETE FROM questions WHERE question_id = p_question_id;
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_delete_quiz` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_delete_quiz`(IN p_actor_user_id VARCHAR(10), IN p_quiz_id VARCHAR(10))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    CALL sp_assert_quiz_owner(p_actor_user_id, p_quiz_id);
    IF EXISTS (SELECT 1 FROM quiz_results WHERE quiz_id = p_quiz_id)
       OR EXISTS (SELECT 1 FROM student_answers sa JOIN questions q ON q.question_id = sa.question_id
                   WHERE q.quiz_id = p_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz already has student answers or results and cannot be deleted';
    END IF;
    -- explicit child delete so each question deletion is audited by its trigger
    DELETE FROM questions WHERE quiz_id = p_quiz_id;
    DELETE FROM quizzes   WHERE quiz_id = p_quiz_id;
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_delete_subject` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_delete_subject`(IN p_actor_user_id VARCHAR(10), IN p_subject_id VARCHAR(10))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    IF NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = p_subject_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject not found';
    END IF;
    -- "delete where permitted": a subject still in use cannot be removed
    IF EXISTS (SELECT 1 FROM materials WHERE subject_id = p_subject_id)
       OR EXISTS (SELECT 1 FROM quizzes WHERE subject_id = p_subject_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject has materials or quizzes and cannot be deleted';
    END IF;
    DELETE FROM subjects WHERE subject_id = p_subject_id;
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_answer_review` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_answer_review`(IN p_actor_user_id VARCHAR(10), IN p_quiz_id VARCHAR(10),
                                      IN p_student_id VARCHAR(10))
BEGIN
    DECLARE v_student VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET @app_user_id = NULL; RESIGNAL; END;
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');

    IF fn_user_has_role(p_actor_user_id, 'Administrator') THEN
        SET v_student = p_student_id;
    ELSEIF fn_user_has_role(p_actor_user_id, 'Instructor') THEN
        CALL sp_assert_quiz_owner(p_actor_user_id, p_quiz_id);
        SET v_student = p_student_id;
    ELSE
        SET v_student = fn_get_student_id(p_actor_user_id);
        IF p_student_id IS NOT NULL AND p_student_id <> v_student THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ACCESS DENIED: students may only view their own answers';
        END IF;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM quiz_results WHERE student_id = v_student AND quiz_id = p_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No submitted result for this student and quiz';
    END IF;

    SELECT q.question_id, q.question_text, sa.student_answer, q.correct_answer,
           COALESCE(sa.is_correct, FALSE) AS is_correct
      FROM questions q
      LEFT JOIN student_answers sa ON sa.question_id = q.question_id AND sa.student_id = v_student
     WHERE q.quiz_id = p_quiz_id
     ORDER BY q.question_id;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_materials_by_subject` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_materials_by_subject`(IN p_actor_user_id VARCHAR(10), IN p_subject_id VARCHAR(10))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET @app_user_id = NULL; RESIGNAL; END;
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');
    SELECT * FROM v_learning_materials
     WHERE subject_id = p_subject_id
     ORDER BY uploaded_at, material_id;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_quiz_questions` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_quiz_questions`(IN p_actor_user_id VARCHAR(10), IN p_quiz_id VARCHAR(10))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET @app_user_id = NULL; RESIGNAL; END;
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');
    IF NOT EXISTS (SELECT 1 FROM quizzes WHERE quiz_id = p_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz not found';
    END IF;
    IF fn_user_has_role(p_actor_user_id, 'Administrator')
       OR (SELECT instructor_id FROM quizzes WHERE quiz_id = p_quiz_id) = COALESCE(fn_get_instructor_id(p_actor_user_id), '') THEN
        SELECT question_id, question_text, option_a, option_b, option_c, option_d, correct_answer
          FROM questions WHERE quiz_id = p_quiz_id ORDER BY question_id;
    ELSE
        SELECT question_id, question_text, option_a, option_b, option_c, option_d
          FROM questions WHERE quiz_id = p_quiz_id ORDER BY question_id;
    END IF;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_student_results` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_student_results`(IN p_actor_user_id VARCHAR(10), IN p_student_id VARCHAR(10))
BEGIN
    DECLARE v_own_student VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET @app_user_id = NULL; RESIGNAL; END;
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');

    IF fn_user_has_role(p_actor_user_id, 'Administrator') THEN
        SELECT * FROM v_quiz_results_detail
         WHERE p_student_id IS NULL OR student_id = p_student_id
         ORDER BY student_id, quiz_id;
    ELSEIF fn_user_has_role(p_actor_user_id, 'Instructor') THEN
        SELECT * FROM v_quiz_results_detail
         WHERE instructor_id = fn_get_instructor_id(p_actor_user_id)
           AND (p_student_id IS NULL OR student_id = p_student_id)
         ORDER BY quiz_id, student_id;
    ELSE
        SET v_own_student = fn_get_student_id(p_actor_user_id);
        IF p_student_id IS NOT NULL AND p_student_id <> v_own_student THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ACCESS DENIED: students may only view their own results';
        END IF;
        SELECT result_id, quiz_id, quiz_title, subject_name, score, correct_answers, total_questions
          FROM v_quiz_results_detail
         WHERE student_id = v_own_student
         ORDER BY quiz_id;
    END IF;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_get_user` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_user`(IN p_actor_user_id VARCHAR(10), IN p_user_id VARCHAR(10))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET @app_user_id = NULL; RESIGNAL; END;
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor,Student');
    IF p_user_id <> p_actor_user_id AND NOT fn_user_has_role(p_actor_user_id, 'Administrator') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ACCESS DENIED: you may only view your own account';
    END IF;
    SELECT * FROM v_user_directory WHERE user_id = p_user_id;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_next_id` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_next_id`(IN p_entity VARCHAR(20), OUT p_new_id VARCHAR(10))
BEGIN
    DECLARE v_max VARCHAR(10);
    CASE p_entity
        WHEN 'users'           THEN SELECT MAX(user_id)       INTO v_max FROM users           FOR UPDATE;
        WHEN 'admins'          THEN SELECT MAX(admin_id)      INTO v_max FROM admins          FOR UPDATE;
        WHEN 'instructors'     THEN SELECT MAX(instructor_id) INTO v_max FROM instructors     FOR UPDATE;
        WHEN 'students'        THEN SELECT MAX(student_id)    INTO v_max FROM students        FOR UPDATE;
        WHEN 'subjects'        THEN SELECT MAX(subject_id)    INTO v_max FROM subjects        FOR UPDATE;
        WHEN 'materials'       THEN SELECT MAX(material_id)   INTO v_max FROM materials       FOR UPDATE;
        WHEN 'quizzes'         THEN SELECT MAX(quiz_id)       INTO v_max FROM quizzes         FOR UPDATE;
        WHEN 'questions'       THEN SELECT MAX(question_id)   INTO v_max FROM questions       FOR UPDATE;
        WHEN 'student_answers' THEN SELECT MAX(answer_id)     INTO v_max FROM student_answers FOR UPDATE;
        WHEN 'quiz_results'    THEN SELECT MAX(result_id)     INTO v_max FROM quiz_results    FOR UPDATE;
        ELSE SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'sp_next_id: unknown entity';
    END CASE;

    SET p_new_id = fn_format_id(
        CASE p_entity
            WHEN 'users' THEN 'USR' WHEN 'admins' THEN 'ADM' WHEN 'instructors' THEN 'INS'
            WHEN 'students' THEN 'STU' WHEN 'subjects' THEN 'SUB' WHEN 'materials' THEN 'MAT'
            WHEN 'quizzes' THEN 'QUZ' WHEN 'questions' THEN 'QST' WHEN 'student_answers' THEN 'ANS'
            ELSE 'RES' END,
        COALESCE(CAST(SUBSTRING(v_max, 4) AS UNSIGNED), 0) + 1);
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_register_instructor` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_register_instructor`(IN p_actor_user_id VARCHAR(10), IN p_username VARCHAR(50),
                                        IN p_email VARCHAR(100), IN p_password VARCHAR(255),
                                        IN p_first_name VARCHAR(50), IN p_last_name VARCHAR(50),
                                        OUT p_user_id VARCHAR(10), OUT p_instructor_id VARCHAR(10))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;
    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    CALL sp_register_user('Instructor', p_username, p_email, p_password, p_first_name, p_last_name,
                          p_user_id, p_instructor_id);
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_register_student` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_register_student`(IN p_actor_user_id VARCHAR(10), IN p_username VARCHAR(50),
                                     IN p_email VARCHAR(100), IN p_password VARCHAR(255),
                                     IN p_first_name VARCHAR(50), IN p_last_name VARCHAR(50),
                                     OUT p_user_id VARCHAR(10), OUT p_student_id VARCHAR(10))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;
    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    CALL sp_register_user('Student', p_username, p_email, p_password, p_first_name, p_last_name,
                          p_user_id, p_student_id);
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_register_user` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_register_user`(IN p_role_name VARCHAR(50), IN p_username VARCHAR(50),
                                  IN p_email VARCHAR(100), IN p_password VARCHAR(255),
                                  IN p_first_name VARCHAR(50), IN p_last_name VARCHAR(50),
                                  OUT p_user_id VARCHAR(10), OUT p_profile_id VARCHAR(10))
BEGIN
    DECLARE v_salt CHAR(32);

    -- 1.1 Validate user information
    IF p_username IS NULL OR NOT REGEXP_LIKE(p_username, '^[A-Za-z0-9._]{3,50}$') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid username (3-50 letters, digits, dot or underscore)';
    END IF;
    IF p_email IS NULL OR NOT REGEXP_LIKE(p_email, '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid email address';
    END IF;
    IF NOT fn_is_strong_password(p_password) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Weak password: minimum 8 characters with upper-case, lower-case and a digit';
    END IF;
    IF p_first_name IS NULL OR TRIM(p_first_name) = '' OR p_last_name IS NULL OR TRIM(p_last_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'First name and last name are required';
    END IF;
    IF EXISTS (SELECT 1 FROM users WHERE username = p_username) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Username already exists';
    END IF;
    IF EXISTS (SELECT 1 FROM users WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email already registered';
    END IF;

    -- 1.5 Store user record (password is salted + hashed, never stored in clear)
    CALL sp_next_id('users', p_user_id);
    SET v_salt = HEX(RANDOM_BYTES(16));
    INSERT INTO users (user_id, username, email, password_hash)
    VALUES (p_user_id, p_username, LOWER(p_email), fn_hash_password(p_password, v_salt));

    -- 1.4 Assign role
    INSERT INTO user_roles (user_id, role_id)
    SELECT p_user_id, role_id FROM roles WHERE role_name = p_role_name;

    -- profile row (admins / instructors / students)
    CALL sp_create_profile(p_user_id, p_role_name, p_first_name, p_last_name, p_profile_id);
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_report_audit_logs` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_report_audit_logs`(IN p_actor_user_id VARCHAR(10), IN p_table_name VARCHAR(50),
                                      IN p_action_type VARCHAR(50), IN p_from DATETIME,
                                      IN p_to DATETIME, IN p_limit INT)
BEGIN
    DECLARE v_limit INT DEFAULT 100;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET @app_user_id = NULL; RESIGNAL; END;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    SET v_limit = LEAST(GREATEST(COALESCE(p_limit, 100), 1), 10000);
    SELECT * FROM v_audit_trail
     WHERE (p_table_name  IS NULL OR table_name  = p_table_name)
       AND (p_action_type IS NULL OR action_type = p_action_type)
       AND (p_from IS NULL OR log_timestamp >= p_from)
       AND (p_to   IS NULL OR log_timestamp <  p_to)
     ORDER BY log_id DESC
     LIMIT v_limit;   -- local variables are allowed in LIMIT inside stored programs
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_report_quiz_results` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_report_quiz_results`(IN p_actor_user_id VARCHAR(10), IN p_quiz_id VARCHAR(10))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET @app_user_id = NULL; RESIGNAL; END;
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor');
    IF NOT fn_user_has_role(p_actor_user_id, 'Administrator') THEN
        CALL sp_assert_quiz_owner(p_actor_user_id, p_quiz_id);
    ELSEIF NOT EXISTS (SELECT 1 FROM quizzes WHERE quiz_id = p_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz not found';
    END IF;

    SELECT result_id, student_id, student_name, score, correct_answers, total_questions
      FROM v_quiz_results_detail
     WHERE quiz_id = p_quiz_id
     ORDER BY score DESC, student_id;

    SELECT p_quiz_id                AS quiz_id,
           COUNT(*)                 AS submissions,
           ROUND(AVG(score), 2)     AS average_score,
           MAX(score)               AS highest_score,
           MIN(score)               AS lowest_score
      FROM quiz_results
     WHERE quiz_id = p_quiz_id;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_report_student_performance` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_report_student_performance`(IN p_actor_user_id VARCHAR(10), IN p_subject_id VARCHAR(10))
BEGIN
    DECLARE v_instructor VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET @app_user_id = NULL; RESIGNAL; END;
    CALL sp_set_actor(p_actor_user_id, 'Administrator,Instructor');

    SET v_instructor = IF(fn_user_has_role(p_actor_user_id, 'Administrator'), NULL,
                          fn_get_instructor_id(p_actor_user_id));

    SELECT st.student_id,
           CONCAT(st.first_name, ' ', st.last_name) AS student_name,
           sb.subject_name,
           COUNT(qr.result_id)        AS quizzes_taken,
           ROUND(AVG(qr.score), 2)    AS average_score,
           MAX(qr.score)              AS highest_score,
           MIN(qr.score)              AS lowest_score
      FROM quiz_results qr
      JOIN students st ON st.student_id = qr.student_id
      JOIN quizzes  q  ON q.quiz_id     = qr.quiz_id
      JOIN subjects sb ON sb.subject_id = q.subject_id
     WHERE (p_subject_id IS NULL OR q.subject_id = p_subject_id)
       AND (v_instructor IS NULL OR q.instructor_id = v_instructor)
     GROUP BY st.student_id, st.first_name, st.last_name, sb.subject_id, sb.subject_name
     ORDER BY sb.subject_name, average_score DESC, st.student_id;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_report_system_activity` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_report_system_activity`(IN p_actor_user_id VARCHAR(10), IN p_days INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SET @app_user_id = NULL; RESIGNAL; END;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    SELECT table_name, action_type, COUNT(*) AS operations,
           COUNT(DISTINCT performed_by) AS distinct_users,
           MAX(log_timestamp) AS last_activity
      FROM audit_logs
     WHERE log_timestamp >= NOW() - INTERVAL COALESCE(p_days, 30) DAY
     GROUP BY table_name, action_type
     ORDER BY table_name, action_type;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_revoke_role` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_revoke_role`(IN p_actor_user_id VARCHAR(10), IN p_user_id VARCHAR(10),
                                IN p_role_name VARCHAR(50))
BEGIN
    DECLARE v_role_id VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');

    SET v_role_id = (SELECT role_id FROM roles WHERE role_name = p_role_name);
    IF NOT EXISTS (SELECT 1 FROM user_roles WHERE user_id = p_user_id AND role_id = v_role_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User does not have this role';
    END IF;
    IF p_user_id = p_actor_user_id AND p_role_name = 'Administrator' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Administrators cannot revoke their own Administrator role';
    END IF;
    IF (SELECT COUNT(*) FROM user_roles WHERE user_id = p_user_id) = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A user must keep at least one role';
    END IF;

    DELETE FROM user_roles WHERE user_id = p_user_id AND role_id = v_role_id;
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_set_actor` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_set_actor`(IN p_actor_user_id VARCHAR(10), IN p_allowed_roles VARCHAR(100))
BEGIN
    DECLARE v_username VARCHAR(50);
    DECLARE v_status   VARCHAR(10);
    DECLARE v_login    VARCHAR(100);
    DECLARE v_msg      VARCHAR(255);

    SET v_username = (SELECT username FROM users WHERE user_id = p_actor_user_id);
    SET v_status   = (SELECT status   FROM users WHERE user_id = p_actor_user_id);

    IF v_username IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ACCESS DENIED: unknown acting user';
    END IF;

    IF v_status <> 'Active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ACCESS DENIED: account is inactive';
    END IF;

    IF NOT EXISTS (SELECT 1
                     FROM user_roles ur
                     JOIN roles r ON r.role_id = ur.role_id
                    WHERE ur.user_id = p_actor_user_id
                      AND FIND_IN_SET(r.role_name, p_allowed_roles) > 0) THEN
        SET v_msg = CONCAT('ACCESS DENIED: this operation requires role(s) ', p_allowed_roles);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- Anti-impersonation: a personal login (account name = a username) may only
    -- act as itself. Shared application accounts are trusted to pass the
    -- authenticated user's id.
    SET v_login = SUBSTRING_INDEX(USER(), '@', 1);
    IF EXISTS (SELECT 1 FROM users WHERE username = v_login) AND v_login <> v_username THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ACCESS DENIED: a personal database login may only act as its own user';
    END IF;

    SET @app_user_id = p_actor_user_id;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_set_user_status` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_set_user_status`(IN p_actor_user_id VARCHAR(10), IN p_user_id VARCHAR(10),
                                    IN p_status VARCHAR(10))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    IF p_status NOT IN ('Active','Inactive') OR p_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Status must be Active or Inactive';
    END IF;
    IF p_user_id = p_actor_user_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Administrators cannot change their own account status';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User not found';
    END IF;
    UPDATE users SET status = p_status WHERE user_id = p_user_id;
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_submit_answer` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_submit_answer`(IN p_actor_user_id VARCHAR(10), IN p_question_id VARCHAR(10),
                                  IN p_answer VARCHAR(255), OUT p_answer_id VARCHAR(10))
BEGIN
    DECLARE v_student_id VARCHAR(10);
    DECLARE v_quiz_id    VARCHAR(10);
    DECLARE v_a, v_b, v_c, v_d, v_answer VARCHAR(255);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Student');
    SET v_student_id = fn_get_student_id(p_actor_user_id);

    SELECT quiz_id, option_a, option_b, option_c, option_d
      INTO v_quiz_id, v_a, v_b, v_c, v_d
      FROM questions WHERE question_id = p_question_id;
    IF v_quiz_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Question not found';
    END IF;
    IF EXISTS (SELECT 1 FROM quiz_results WHERE student_id = v_student_id AND quiz_id = v_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz already submitted; answers are locked';
    END IF;
    IF EXISTS (SELECT 1 FROM student_answers WHERE student_id = v_student_id AND question_id = p_question_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Question already answered';
    END IF;
    -- validate the submitted answer against the question options
    SET v_answer = fn_resolve_option(p_answer, v_a, v_b, v_c, v_d);
    IF v_answer IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Answer must be A, B, C, D or the exact text of an option';
    END IF;

    CALL sp_next_id('student_answers', p_answer_id);
    INSERT INTO student_answers (answer_id, student_id, question_id, student_answer)
    VALUES (p_answer_id, v_student_id, p_question_id, v_answer);
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_submit_quiz` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_submit_quiz`(IN p_actor_user_id VARCHAR(10), IN p_quiz_id VARCHAR(10),
                                OUT p_result_id VARCHAR(10), OUT p_score DECIMAL(5,2))
BEGIN
    DECLARE v_student_id VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Student');
    SET v_student_id = fn_get_student_id(p_actor_user_id);

    IF NOT EXISTS (SELECT 1 FROM quizzes WHERE quiz_id = p_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz not found';
    END IF;
    IF fn_question_count(p_quiz_id) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz has no questions';
    END IF;
    IF EXISTS (SELECT 1 FROM quiz_results WHERE student_id = v_student_id AND quiz_id = p_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz already submitted';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM student_answers sa JOIN questions q ON q.question_id = sa.question_id
                    WHERE sa.student_id = v_student_id AND q.quiz_id = p_quiz_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No answers submitted for this quiz';
    END IF;

    CALL sp_next_id('quiz_results', p_result_id);
    INSERT INTO quiz_results (result_id, student_id, quiz_id, score)
    VALUES (p_result_id, v_student_id, p_quiz_id, 0);       -- trigger computes the real score
    SET p_score = (SELECT score FROM quiz_results WHERE result_id = p_result_id);
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_update_material` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_update_material`(IN p_actor_user_id VARCHAR(10), IN p_material_id VARCHAR(10),
                                    IN p_subject_id VARCHAR(10), IN p_title VARCHAR(255),
                                    IN p_file_path VARCHAR(255))
BEGIN
    DECLARE v_owner VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    SET v_owner = (SELECT instructor_id FROM materials WHERE material_id = p_material_id FOR UPDATE);
    IF v_owner IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Material not found';
    END IF;
    IF v_owner <> fn_get_instructor_id(p_actor_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ACCESS DENIED: you can only modify your own materials';
    END IF;
    IF p_subject_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = p_subject_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject not found';
    END IF;
    IF p_title IS NOT NULL AND TRIM(p_title) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Material title cannot be blank';
    END IF;
    IF p_file_path IS NOT NULL AND NOT fn_is_safe_file_path(p_file_path) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid file path';
    END IF;
    UPDATE materials
       SET subject_id = COALESCE(p_subject_id, subject_id),
           title      = COALESCE(TRIM(p_title), title),
           file_path  = COALESCE(TRIM(p_file_path), file_path)
     WHERE material_id = p_material_id;
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_update_question` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_update_question`(IN p_actor_user_id VARCHAR(10), IN p_question_id VARCHAR(10),
                                    IN p_question_text TEXT,
                                    IN p_option_a VARCHAR(255), IN p_option_b VARCHAR(255),
                                    IN p_option_c VARCHAR(255), IN p_option_d VARCHAR(255),
                                    IN p_correct_answer VARCHAR(255))
BEGIN
    DECLARE v_quiz_id VARCHAR(10);
    DECLARE v_a, v_b, v_c, v_d, v_cur, v_correct VARCHAR(255);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    SELECT quiz_id, option_a, option_b, option_c, option_d, correct_answer
      INTO v_quiz_id, v_a, v_b, v_c, v_d, v_cur
      FROM questions WHERE question_id = p_question_id FOR UPDATE;
    IF v_quiz_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Question not found';
    END IF;
    CALL sp_assert_quiz_owner(p_actor_user_id, v_quiz_id);
    IF EXISTS (SELECT 1 FROM student_answers WHERE question_id = p_question_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Question has already been answered and is locked';
    END IF;
    SET v_a = COALESCE(p_option_a, v_a);
    SET v_b = COALESCE(p_option_b, v_b);
    SET v_c = COALESCE(p_option_c, v_c);
    SET v_d = COALESCE(p_option_d, v_d);
    SET v_correct = fn_resolve_option(COALESCE(p_correct_answer, v_cur), v_a, v_b, v_c, v_d);
    IF v_correct IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Correct answer must be A, B, C, D or the exact text of an option';
    END IF;
    IF p_question_text IS NOT NULL AND TRIM(p_question_text) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Question text cannot be blank';
    END IF;
    UPDATE questions
       SET question_text  = COALESCE(TRIM(p_question_text), question_text),
           option_a = v_a, option_b = v_b, option_c = v_c, option_d = v_d,
           correct_answer = v_correct
     WHERE question_id = p_question_id;
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_update_quiz` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_update_quiz`(IN p_actor_user_id VARCHAR(10), IN p_quiz_id VARCHAR(10),
                                IN p_subject_id VARCHAR(10), IN p_title VARCHAR(255))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    CALL sp_assert_quiz_owner(p_actor_user_id, p_quiz_id);
    IF p_subject_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = p_subject_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject not found';
    END IF;
    IF p_title IS NOT NULL AND TRIM(p_title) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quiz title cannot be blank';
    END IF;
    UPDATE quizzes
       SET subject_id = COALESCE(p_subject_id, subject_id),
           title      = COALESCE(TRIM(p_title), title)
     WHERE quiz_id = p_quiz_id;
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_update_subject` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_update_subject`(IN p_actor_user_id VARCHAR(10), IN p_subject_id VARCHAR(10),
                                   IN p_subject_name VARCHAR(100), IN p_description TEXT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');
    IF NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = p_subject_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject not found';
    END IF;
    IF p_subject_name IS NOT NULL AND TRIM(p_subject_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject name cannot be blank';
    END IF;
    IF EXISTS (SELECT 1 FROM subjects WHERE subject_name = TRIM(p_subject_name) AND subject_id <> p_subject_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject name already exists';
    END IF;
    UPDATE subjects
       SET subject_name = COALESCE(TRIM(p_subject_name), subject_name),
           description  = COALESCE(p_description, description)
     WHERE subject_id = p_subject_id;
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_update_user` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_update_user`(IN p_actor_user_id VARCHAR(10), IN p_user_id VARCHAR(10),
                                IN p_email VARCHAR(100), IN p_first_name VARCHAR(50),
                                IN p_last_name VARCHAR(50))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Administrator');

    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User not found';
    END IF;
    IF p_email IS NOT NULL THEN
        IF NOT REGEXP_LIKE(p_email, '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid email address';
        END IF;
        IF EXISTS (SELECT 1 FROM users WHERE email = LOWER(p_email) AND user_id <> p_user_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Email already registered';
        END IF;
        UPDATE users SET email = LOWER(p_email) WHERE user_id = p_user_id AND email <> LOWER(p_email);
    END IF;
    IF p_first_name IS NOT NULL OR p_last_name IS NOT NULL THEN
        UPDATE admins      SET first_name = COALESCE(TRIM(p_first_name), first_name),
                               last_name  = COALESCE(TRIM(p_last_name),  last_name)  WHERE user_id = p_user_id;
        UPDATE instructors SET first_name = COALESCE(TRIM(p_first_name), first_name),
                               last_name  = COALESCE(TRIM(p_last_name),  last_name)  WHERE user_id = p_user_id;
        UPDATE students    SET first_name = COALESCE(TRIM(p_first_name), first_name),
                               last_name  = COALESCE(TRIM(p_last_name),  last_name)  WHERE user_id = p_user_id;
    END IF;
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_upload_material` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_upload_material`(IN p_actor_user_id VARCHAR(10), IN p_subject_id VARCHAR(10),
                                    IN p_title VARCHAR(255), IN p_file_path VARCHAR(255),
                                    OUT p_material_id VARCHAR(10))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SET @app_user_id = NULL; RESIGNAL; END;

    START TRANSACTION;
    CALL sp_set_actor(p_actor_user_id, 'Instructor');
    -- 3.1 Select subject
    IF NOT EXISTS (SELECT 1 FROM subjects WHERE subject_id = p_subject_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subject not found';
    END IF;
    IF p_title IS NULL OR TRIM(p_title) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Material title is required';
    END IF;
    IF NOT fn_is_safe_file_path(p_file_path) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid file path';
    END IF;
    -- 3.2 Upload material / 3.3 Store material record
    CALL sp_next_id('materials', p_material_id);
    INSERT INTO materials (material_id, subject_id, instructor_id, title, file_path)
    VALUES (p_material_id, p_subject_id, fn_get_instructor_id(p_actor_user_id), TRIM(p_title), TRIM(p_file_path));
    COMMIT;
    SET @app_user_id = NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `tst_check_true` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `tst_check_true`(IN p_id VARCHAR(12), IN p_desc VARCHAR(255),
                                         IN p_condition BOOLEAN, IN p_detail TEXT)
    SQL SECURITY INVOKER
BEGIN
    INSERT INTO studync_test.results (test_id, description, expected, outcome, detail, run_as)
    VALUES (p_id, p_desc, 'TRUE', IF(COALESCE(p_condition, FALSE), 'PASS', 'FAIL'), p_detail, USER());
    SELECT p_id AS test_id, p_desc AS description, 'TRUE' AS expected,
           IF(COALESCE(p_condition, FALSE), 'PASS', 'FAIL') AS result, p_detail AS detail;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `tst_expect_error` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `tst_expect_error`(IN p_id VARCHAR(12), IN p_desc VARCHAR(255),
                                           IN p_sql TEXT, IN p_expected VARCHAR(255))
    SQL SECURITY INVOKER
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg   TEXT DEFAULT NULL;
    DECLARE v_pass  BOOLEAN;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
        BEGIN GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT; END;
    SET @studync_test_sql = p_sql;
    PREPARE studync_test_stmt FROM @studync_test_sql;
    IF v_errno = 0 THEN
        EXECUTE studync_test_stmt;
        DEALLOCATE PREPARE studync_test_stmt;
    END IF;
    SET v_pass = v_errno <> 0 AND (
                   p_expected IS NULL
                OR (REGEXP_LIKE(p_expected, '^[0-9]+$') AND v_errno = CAST(p_expected AS UNSIGNED))
                OR (NOT REGEXP_LIKE(p_expected, '^[0-9]+$') AND v_msg LIKE CONCAT('%', p_expected, '%')));
    INSERT INTO studync_test.results (test_id, description, expected, outcome, detail, run_as)
    VALUES (p_id, p_desc, CONCAT('ERROR ', LEFT(COALESCE(p_expected, 'any'), 14)), IF(v_pass, 'PASS', 'FAIL'),
            IF(v_errno = 0, 'statement unexpectedly succeeded', CONCAT('error ', v_errno, ': ', v_msg)), USER());
    SELECT p_id AS test_id, p_desc AS description, CONCAT('ERROR ', COALESCE(p_expected, 'any')) AS expected,
           IF(v_pass, 'PASS', 'FAIL') AS result,
           IF(v_errno = 0, 'statement unexpectedly succeeded', CONCAT('error ', v_errno, ': ', v_msg)) AS detail;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `tst_expect_ok` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `tst_expect_ok`(IN p_id VARCHAR(12), IN p_desc VARCHAR(255), IN p_sql TEXT)
    SQL SECURITY INVOKER
BEGIN
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_msg   TEXT DEFAULT NULL;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
        BEGIN GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT; END;
    SET @studync_test_sql = p_sql;
    PREPARE studync_test_stmt FROM @studync_test_sql;
    IF v_errno = 0 THEN
        EXECUTE studync_test_stmt;
        DEALLOCATE PREPARE studync_test_stmt;
    END IF;
    INSERT INTO studync_test.results (test_id, description, expected, outcome, detail, run_as)
    VALUES (p_id, p_desc, 'SUCCESS', IF(v_errno = 0, 'PASS', 'FAIL'),
            IF(v_errno = 0, 'succeeded', CONCAT('error ', v_errno, ': ', v_msg)), USER());
    SELECT p_id AS test_id, p_desc AS description, 'SUCCESS' AS expected,
           IF(v_errno = 0, 'PASS', 'FAIL') AS result,
           IF(v_errno = 0, 'succeeded', CONCAT('error ', v_errno, ': ', v_msg)) AS detail;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Current Database: `studync_db`
--

USE `studync_db`;

--
-- Final view structure for view `v_audit_trail`
--

/*!50001 DROP VIEW IF EXISTS `v_audit_trail`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_audit_trail` AS select `al`.`log_id` AS `log_id`,`al`.`log_timestamp` AS `log_timestamp`,`al`.`action_type` AS `action_type`,`al`.`table_name` AS `table_name`,`al`.`record_id` AS `record_id`,`al`.`performed_by` AS `performed_by`,`u`.`username` AS `performed_by_username`,`al`.`db_user` AS `db_user`,`al`.`description` AS `description`,`al`.`old_data` AS `old_data`,`al`.`new_data` AS `new_data` from (`audit_logs` `al` left join `users` `u` on((`u`.`user_id` = `al`.`performed_by`))) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_learning_materials`
--

/*!50001 DROP VIEW IF EXISTS `v_learning_materials`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_learning_materials` AS select `m`.`material_id` AS `material_id`,`m`.`title` AS `title`,`m`.`file_path` AS `file_path`,`m`.`uploaded_at` AS `uploaded_at`,`sb`.`subject_id` AS `subject_id`,`sb`.`subject_name` AS `subject_name`,`i`.`instructor_id` AS `instructor_id`,concat(`i`.`first_name`,' ',`i`.`last_name`) AS `instructor_name` from ((`materials` `m` join `subjects` `sb` on((`sb`.`subject_id` = `m`.`subject_id`))) join `instructors` `i` on((`i`.`instructor_id` = `m`.`instructor_id`))) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_my_results`
--

/*!50001 DROP VIEW IF EXISTS `v_my_results`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_my_results` AS select `qr`.`result_id` AS `result_id`,`q`.`quiz_id` AS `quiz_id`,`q`.`title` AS `quiz_title`,`sb`.`subject_name` AS `subject_name`,`qr`.`score` AS `score`,(select count(0) from (`student_answers` `sa` join `questions` `qs` on((`qs`.`question_id` = `sa`.`question_id`))) where ((`sa`.`student_id` = `qr`.`student_id`) and (`qs`.`quiz_id` = `qr`.`quiz_id`) and (0 <> `sa`.`is_correct`))) AS `correct_answers`,(select count(0) from `questions` `qs` where (`qs`.`quiz_id` = `qr`.`quiz_id`)) AS `total_questions` from ((((`quiz_results` `qr` join `students` `st` on((`st`.`student_id` = `qr`.`student_id`))) join `users` `u` on((`u`.`user_id` = `st`.`user_id`))) join `quizzes` `q` on((`q`.`quiz_id` = `qr`.`quiz_id`))) join `subjects` `sb` on((`sb`.`subject_id` = `q`.`subject_id`))) where (`u`.`username` = substring_index(user(),'@',1)) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_quiz_overview`
--

/*!50001 DROP VIEW IF EXISTS `v_quiz_overview`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_quiz_overview` AS select `q`.`quiz_id` AS `quiz_id`,`q`.`title` AS `title`,`q`.`created_at` AS `created_at`,`sb`.`subject_id` AS `subject_id`,`sb`.`subject_name` AS `subject_name`,`i`.`instructor_id` AS `instructor_id`,concat(`i`.`first_name`,' ',`i`.`last_name`) AS `instructor_name`,(select count(0) from `questions` `qs` where (`qs`.`quiz_id` = `q`.`quiz_id`)) AS `question_count` from ((`quizzes` `q` join `subjects` `sb` on((`sb`.`subject_id` = `q`.`subject_id`))) join `instructors` `i` on((`i`.`instructor_id` = `q`.`instructor_id`))) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_quiz_questions_instructor`
--

/*!50001 DROP VIEW IF EXISTS `v_quiz_questions_instructor`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_quiz_questions_instructor` AS select `qs`.`question_id` AS `question_id`,`qs`.`quiz_id` AS `quiz_id`,`q`.`title` AS `quiz_title`,`q`.`instructor_id` AS `instructor_id`,`qs`.`question_text` AS `question_text`,`qs`.`option_a` AS `option_a`,`qs`.`option_b` AS `option_b`,`qs`.`option_c` AS `option_c`,`qs`.`option_d` AS `option_d`,`qs`.`correct_answer` AS `correct_answer`,(select count(0) from `student_answers` `sa` where (`sa`.`question_id` = `qs`.`question_id`)) AS `times_answered`,(select count(0) from `student_answers` `sa` where ((`sa`.`question_id` = `qs`.`question_id`) and (0 <> `sa`.`is_correct`))) AS `times_correct` from (`questions` `qs` join `quizzes` `q` on((`q`.`quiz_id` = `qs`.`quiz_id`))) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_quiz_questions_student`
--

/*!50001 DROP VIEW IF EXISTS `v_quiz_questions_student`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_quiz_questions_student` AS select `qs`.`question_id` AS `question_id`,`qs`.`quiz_id` AS `quiz_id`,`q`.`title` AS `quiz_title`,`qs`.`question_text` AS `question_text`,`qs`.`option_a` AS `option_a`,`qs`.`option_b` AS `option_b`,`qs`.`option_c` AS `option_c`,`qs`.`option_d` AS `option_d` from (`questions` `qs` join `quizzes` `q` on((`q`.`quiz_id` = `qs`.`quiz_id`))) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_quiz_results_detail`
--

/*!50001 DROP VIEW IF EXISTS `v_quiz_results_detail`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_quiz_results_detail` AS select `qr`.`result_id` AS `result_id`,`st`.`student_id` AS `student_id`,concat(`st`.`first_name`,' ',`st`.`last_name`) AS `student_name`,`q`.`quiz_id` AS `quiz_id`,`q`.`title` AS `quiz_title`,`sb`.`subject_name` AS `subject_name`,`q`.`instructor_id` AS `instructor_id`,`qr`.`score` AS `score`,(select count(0) from (`student_answers` `sa` join `questions` `qs` on((`qs`.`question_id` = `sa`.`question_id`))) where ((`sa`.`student_id` = `qr`.`student_id`) and (`qs`.`quiz_id` = `qr`.`quiz_id`) and (0 <> `sa`.`is_correct`))) AS `correct_answers`,(select count(0) from `questions` `qs` where (`qs`.`quiz_id` = `qr`.`quiz_id`)) AS `total_questions` from (((`quiz_results` `qr` join `students` `st` on((`st`.`student_id` = `qr`.`student_id`))) join `quizzes` `q` on((`q`.`quiz_id` = `qr`.`quiz_id`))) join `subjects` `sb` on((`sb`.`subject_id` = `q`.`subject_id`))) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_student_performance`
--

/*!50001 DROP VIEW IF EXISTS `v_student_performance`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_student_performance` AS select `st`.`student_id` AS `student_id`,concat(`st`.`first_name`,' ',`st`.`last_name`) AS `student_name`,`u`.`status` AS `account_status`,count(`qr`.`result_id`) AS `quizzes_taken`,round(avg(`qr`.`score`),2) AS `average_score`,max(`qr`.`score`) AS `highest_score`,min(`qr`.`score`) AS `lowest_score` from ((`students` `st` join `users` `u` on((`u`.`user_id` = `st`.`user_id`))) left join `quiz_results` `qr` on((`qr`.`student_id` = `st`.`student_id`))) group by `st`.`student_id`,`st`.`first_name`,`st`.`last_name`,`u`.`status` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_subject_catalog`
--

/*!50001 DROP VIEW IF EXISTS `v_subject_catalog`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_subject_catalog` AS select `sb`.`subject_id` AS `subject_id`,`sb`.`subject_name` AS `subject_name`,`sb`.`description` AS `description`,(select count(0) from `materials` `m` where (`m`.`subject_id` = `sb`.`subject_id`)) AS `material_count`,(select count(0) from `quizzes` `q` where (`q`.`subject_id` = `sb`.`subject_id`)) AS `quiz_count` from `subjects` `sb` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_user_directory`
--

/*!50001 DROP VIEW IF EXISTS `v_user_directory`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_user_directory` AS select `u`.`user_id` AS `user_id`,`u`.`username` AS `username`,`u`.`email` AS `email`,`u`.`status` AS `status`,`u`.`created_at` AS `created_at`,(select group_concat(`r`.`role_name` order by `r`.`role_name` ASC separator ', ') from (`user_roles` `ur` join `roles` `r` on((`r`.`role_id` = `ur`.`role_id`))) where (`ur`.`user_id` = `u`.`user_id`)) AS `roles`,`a`.`admin_id` AS `admin_id`,`i`.`instructor_id` AS `instructor_id`,`s`.`student_id` AS `student_id`,coalesce(concat(`a`.`first_name`,' ',`a`.`last_name`),concat(`i`.`first_name`,' ',`i`.`last_name`),concat(`s`.`first_name`,' ',`s`.`last_name`)) AS `full_name` from (((`users` `u` left join `admins` `a` on((`a`.`user_id` = `u`.`user_id`))) left join `instructors` `i` on((`i`.`user_id` = `u`.`user_id`))) left join `students` `s` on((`s`.`user_id` = `u`.`user_id`))) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-11-27  3:47:45
