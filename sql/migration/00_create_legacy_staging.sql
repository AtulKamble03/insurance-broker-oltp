-- ============================================================
-- STEP 0: Create Legacy Staging Tables
-- ============================================================
-- THEORY CONCEPT: WHY STAGING?
--
-- In data migration, you NEVER load directly from source to target.
-- You first load raw data into "staging" tables exactly as-is,
-- then transform into the normalised target schema.
--
-- Why? Three reasons:
--  1. You can re-run the migration without re-reading source files
--  2. You can profile the data (nulls, duplicates, formats) before touching prod
--  3. If something goes wrong in transformation, raw data is preserved
--
-- Real-world analogy: A hospital receiving a paper record from another
-- hospital doesn't immediately update their EHR. They scan it first
-- (staging), then a clerk verifies and enters the data (transform).
-- ============================================================

USE hospital_db;
GO

-- Drop staging tables if they exist (safe to re-run)
IF OBJECT_ID('staging.patients',    'U') IS NOT NULL DROP TABLE staging.patients;
IF OBJECT_ID('staging.providers',   'U') IS NOT NULL DROP TABLE staging.providers;
IF OBJECT_ID('staging.encounters',  'U') IS NOT NULL DROP TABLE staging.encounters;
IF OBJECT_ID('staging.conditions',  'U') IS NOT NULL DROP TABLE staging.conditions;
IF OBJECT_ID('staging.medications', 'U') IS NOT NULL DROP TABLE staging.medications;
IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
    DROP SCHEMA staging;
GO

CREATE SCHEMA staging;
GO

-- Raw patients (as-is from Synthea CSV)
CREATE TABLE staging.patients (
    Id              NVARCHAR(50),
    BIRTHDATE       NVARCHAR(20),
    DEATHDATE       NVARCHAR(20),
    SSN             NVARCHAR(20),
    FIRST           NVARCHAR(50),
    LAST            NVARCHAR(50),
    GENDER          NVARCHAR(5),
    BIRTHPLACE      NVARCHAR(100),
    ADDRESS         NVARCHAR(200),
    CITY            NVARCHAR(100),
    STATE           NVARCHAR(50),
    ZIP             NVARCHAR(10)
);

-- Raw providers/doctors
CREATE TABLE staging.providers (
    Id              NVARCHAR(50),
    NAME            NVARCHAR(100),
    GENDER          NVARCHAR(5),
    SPECIALITY      NVARCHAR(100),
    ADDRESS         NVARCHAR(200),
    CITY            NVARCHAR(100),
    STATE           NVARCHAR(50),
    ZIP             NVARCHAR(10)
);

-- Raw encounters/visits
CREATE TABLE staging.encounters (
    Id              NVARCHAR(50),
    START           NVARCHAR(30),
    STOP            NVARCHAR(30),
    PATIENT         NVARCHAR(50),
    PROVIDER        NVARCHAR(50),
    ENCOUNTERCLASS  NVARCHAR(50),
    CODE            NVARCHAR(20),
    DESCRIPTION     NVARCHAR(200)
);

-- Raw conditions/diagnoses
CREATE TABLE staging.conditions (
    START           NVARCHAR(20),
    STOP            NVARCHAR(20),
    PATIENT         NVARCHAR(50),
    ENCOUNTER       NVARCHAR(50),
    CODE            NVARCHAR(20),
    DESCRIPTION     NVARCHAR(200)
);

-- Raw medications/prescriptions
CREATE TABLE staging.medications (
    START           NVARCHAR(20),
    STOP            NVARCHAR(20),
    PATIENT         NVARCHAR(50),
    ENCOUNTER       NVARCHAR(50),
    CODE            NVARCHAR(20),
    DESCRIPTION     NVARCHAR(200),
    DISPENSES       INT
);
GO

PRINT 'Staging schema and 5 tables created successfully.';
GO
