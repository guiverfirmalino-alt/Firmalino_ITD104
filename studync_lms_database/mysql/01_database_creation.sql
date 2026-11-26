-- =============================================================================
-- StudyNC Learning Management System Database  (MySQL 8.0+)
-- File 01 : Database creation
-- Project : FIRMALINO - ITD104 Database Security, Administration & Management
-- -----------------------------------------------------------------------------
-- Run order: 01 -> 02 -> 03 -> 04 -> 05 -> 06 -> 07 -> 08 -> 09 -> 10
-- Run as   : an administrative account (e.g. root) in MySQL Workbench or the
--            mysql command-line client.
-- WARNING  : This script DROPS and re-creates studync_db (clean rebuild).
-- =============================================================================

DROP DATABASE IF EXISTS studync_db;

-- utf8mb4 supports every Unicode character (names with accents, symbols, etc.)
CREATE DATABASE studync_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE studync_db;

-- Strict SQL mode for this session: reject invalid / truncated data instead of
-- silently converting it (MySQL 8 enables most of this by default).
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION,ONLY_FULL_GROUP_BY';

SELECT 'studync_db created' AS status, @@version AS mysql_version;
