-- ============================================================
-- Hospital Patient Records — 3NF Schema
-- Database: hospital_db
-- Run in SSMS
--
-- Design principle: Third Normal Form (3NF)
-- Every table represents ONE entity
-- Every non-key column depends ONLY on the primary key
-- No column depends on another non-key column
-- ============================================================

-- CREATE DATABASE hospital_db;
-- GO
USE hospital_db;
GO

-- ── Drop tables in FK-safe order ─────────────────────────────
IF OBJECT_ID('dbo.prescriptions',      'U') IS NOT NULL DROP TABLE dbo.prescriptions;
IF OBJECT_ID('dbo.visit_diagnoses',    'U') IS NOT NULL DROP TABLE dbo.visit_diagnoses;
IF OBJECT_ID('dbo.visits',             'U') IS NOT NULL DROP TABLE dbo.visits;
IF OBJECT_ID('dbo.diagnoses',          'U') IS NOT NULL DROP TABLE dbo.diagnoses;
IF OBJECT_ID('dbo.medications',        'U') IS NOT NULL DROP TABLE dbo.medications;
IF OBJECT_ID('dbo.patients',           'U') IS NOT NULL DROP TABLE dbo.patients;
IF OBJECT_ID('dbo.doctors',            'U') IS NOT NULL DROP TABLE dbo.doctors;
IF OBJECT_ID('dbo.zip_codes',          'U') IS NOT NULL DROP TABLE dbo.zip_codes;
GO


-- ── TABLE 1: zip_codes ────────────────────────────────────────
-- WHY separate? 3NF violation if city/state stored in patients.
-- City and State depend on ZipCode (not on patient_id).
-- Storing them in patients = transitive dependency (violates 3NF).
-- Fix: extract zip_codes to its own table.
--
-- Example of the problem WITHOUT this table:
--   patient_id | zip | city    | state
--   1001       | 60601 | Chicago | IL
--   1002       | 60601 | Chicago | IL   ← city repeated!
--   If Chicago renames a zip, you update 1000 patient rows instead of 1.
CREATE TABLE dbo.zip_codes (
    zip_code   CHAR(5)      NOT NULL PRIMARY KEY,
    city       VARCHAR(100) NOT NULL,
    state      CHAR(2)      NOT NULL,
    country    VARCHAR(50)  NOT NULL DEFAULT 'USA'
);
GO


-- ── TABLE 2: patients ─────────────────────────────────────────
-- Core entity: one row per patient.
-- References zip_codes — city/state come from the lookup.
-- Gender uses CHECK constraint — enforces data integrity at DB level.
-- date_of_birth: stored as DATE not string — enables age calculations.
CREATE TABLE dbo.patients (
    patient_id      INT IDENTITY(1,1) PRIMARY KEY,
    first_name      VARCHAR(50)  NOT NULL,
    last_name       VARCHAR(50)  NOT NULL,
    date_of_birth   DATE         NOT NULL,
    gender          CHAR(1)      NOT NULL CHECK (gender IN ('M', 'F', 'O')),
    phone           VARCHAR(15),
    email           VARCHAR(100),
    zip_code        CHAR(5)      REFERENCES dbo.zip_codes(zip_code),
    blood_type      CHAR(3)      CHECK (blood_type IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
    created_at      DATETIME2    NOT NULL DEFAULT GETDATE()
);
GO


-- ── TABLE 3: doctors ──────────────────────────────────────────
-- Core entity: one row per doctor.
-- WHY separate from patients? Completely different entity.
-- Doctors can have many patients; patients can see many doctors.
-- Specialty stored here — if specialty changes, update ONE place.
--
-- Without this table (bad design):
--   visit_id | doctor_name | doctor_phone | doctor_specialty
--   → If Dr. Adams changes phone, update 500 visit rows instead of 1.
CREATE TABLE dbo.doctors (
    doctor_id       INT IDENTITY(1,1) PRIMARY KEY,
    first_name      VARCHAR(50)  NOT NULL,
    last_name       VARCHAR(50)  NOT NULL,
    specialty       VARCHAR(100),
    phone           VARCHAR(15),
    email           VARCHAR(100),
    license_number  VARCHAR(20)  UNIQUE,
    hired_date      DATE
);
GO


-- ── TABLE 4: diagnoses ────────────────────────────────────────
-- Reference table: standard ICD-10 diagnosis codes.
-- WHY separate? Diagnosis descriptions don't depend on any visit.
-- They're standard codes used across thousands of visits.
--
-- Without this table:
--   visit_id | diagnosis_code | diagnosis_name
--   5001     | U07.1         | COVID-19
--   5002     | U07.1         | COVID-19    ← repeated in every COVID visit
--   → Typo in one row = data inconsistency
-- With this table: description stored once, referenced everywhere.
CREATE TABLE dbo.diagnoses (
    icd10_code    CHAR(10)      NOT NULL PRIMARY KEY,  -- e.g. U07.1, J06.9, I10
    description   VARCHAR(500)  NOT NULL,
    category      VARCHAR(100),                         -- e.g. Infectious, Cardiovascular
    is_chronic    BIT           NOT NULL DEFAULT 0      -- chronic conditions tracked separately
);
GO


-- ── TABLE 5: medications ──────────────────────────────────────
-- Reference table: standard medications.
-- WHY separate? Medication details don't depend on any prescription.
-- Same medication prescribed to thousands of patients.
--
-- Without this table:
--   prescription_id | medication_name | dosage_form | strength
--   9001            | Paxlovid        | Tablet      | 150mg/100mg  ← repeated
--   9002            | Paxlovid        | Tablet      | 150mg/100mg  ← every time
--   → Typo in strength = incorrect dosage information
CREATE TABLE dbo.medications (
    medication_id   INT IDENTITY(1,1) PRIMARY KEY,
    brand_name      VARCHAR(100) NOT NULL,
    generic_name    VARCHAR(100),
    dosage_form     VARCHAR(50)  NOT NULL,   -- Tablet, Capsule, Liquid, Injection
    strength        VARCHAR(50),              -- e.g. 500mg, 10mg/5ml
    drug_class      VARCHAR(100),             -- Antibiotic, Antiviral, Analgesic
    requires_rx     BIT          NOT NULL DEFAULT 1  -- 1 = prescription required
);
GO


-- ── TABLE 6: visits ───────────────────────────────────────────
-- Junction/transaction table: records when a patient sees a doctor.
-- Links patients to doctors with date context.
-- This is the FACT of the system — the event that occurred.
--
-- Normalisation: visit_date, visit_type stored here (depend on this specific visit).
-- Doctor's name NOT stored here (would be redundant — already in doctors table).
-- Patient's name NOT stored here (would be redundant — already in patients table).
CREATE TABLE dbo.visits (
    visit_id        INT IDENTITY(1,1) PRIMARY KEY,
    patient_id      INT          NOT NULL REFERENCES dbo.patients(patient_id),
    doctor_id       INT          NOT NULL REFERENCES dbo.doctors(doctor_id),
    visit_date      DATE         NOT NULL,
    visit_type      VARCHAR(50)  NOT NULL CHECK (visit_type IN ('Outpatient', 'Inpatient', 'Emergency', 'Telehealth')),
    chief_complaint VARCHAR(500),             -- what the patient came in for
    discharge_date  DATE,                     -- NULL for outpatient (no admission)
    notes           VARCHAR(MAX),
    created_at      DATETIME2    NOT NULL DEFAULT GETDATE(),
    CONSTRAINT chk_discharge CHECK (discharge_date IS NULL OR discharge_date >= visit_date)
);
GO


-- ── TABLE 7: visit_diagnoses ──────────────────────────────────
-- Junction table: a visit can have MULTIPLE diagnoses.
-- WHY not store diagnoses in visits table?
-- 1NF violation: visits.diagnosis_1, visits.diagnosis_2 = repeating groups.
--
-- This solves the 1NF problem:
--   visit_id | icd10_code | is_primary
--   5001     | U07.1      | 1  (primary = COVID-19)
--   5001     | I10        | 0  (secondary = Hypertension)
--   5001     | E11.9      | 0  (secondary = Type 2 Diabetes)
-- One visit, three diagnoses — all stored cleanly.
CREATE TABLE dbo.visit_diagnoses (
    visit_id        INT      NOT NULL REFERENCES dbo.visits(visit_id),
    icd10_code      CHAR(10) NOT NULL REFERENCES dbo.diagnoses(icd10_code),
    is_primary      BIT      NOT NULL DEFAULT 1,  -- 1 = primary diagnosis
    diagnosed_at    DATETIME2 NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY (visit_id, icd10_code)            -- composite PK — one code per visit
);
GO


-- ── TABLE 8: prescriptions ────────────────────────────────────
-- Records medications prescribed during a visit.
-- Links visits to medications with dosage context.
-- WHY not in visits? A visit can have MULTIPLE prescriptions.
-- WHY not in medications? Dosage/frequency is specific to this prescription.
--
-- 2NF lesson: dosage and frequency depend on THIS prescription (visit+medication combo).
-- They don't depend just on the medication alone (Paxlovid = always 150mg)
-- or just on the visit alone.
CREATE TABLE dbo.prescriptions (
    prescription_id  INT IDENTITY(1,1) PRIMARY KEY,
    visit_id         INT          NOT NULL REFERENCES dbo.visits(visit_id),
    medication_id    INT          NOT NULL REFERENCES dbo.medications(medication_id),
    dosage           VARCHAR(50)  NOT NULL,    -- e.g. 150mg twice daily
    frequency        VARCHAR(50)  NOT NULL,    -- e.g. Twice daily, Once daily
    days_supply      TINYINT      NOT NULL CHECK (days_supply BETWEEN 1 AND 365),
    prescribed_date  DATE         NOT NULL DEFAULT GETDATE(),
    refills_allowed  TINYINT      NOT NULL DEFAULT 0,
    instructions     VARCHAR(500)              -- take with food, avoid alcohol, etc.
);
GO


-- ── Indexes for common query patterns ────────────────────────
-- Patient lookup by name
CREATE INDEX idx_patients_name ON dbo.patients (last_name, first_name);

-- Find all visits for a patient
CREATE INDEX idx_visits_patient ON dbo.visits (patient_id, visit_date DESC);

-- Find all visits for a doctor
CREATE INDEX idx_visits_doctor ON dbo.visits (doctor_id, visit_date DESC);

-- Find all COVID diagnoses (for the bridge to covid_dw in Phase 8)
CREATE INDEX idx_visit_diagnoses_code ON dbo.visit_diagnoses (icd10_code);
GO


-- ── Verification ─────────────────────────────────────────────
-- Run this to confirm all 8 tables are created correctly
SELECT
    TABLE_NAME,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS c
     WHERE c.TABLE_NAME = t.TABLE_NAME AND c.TABLE_SCHEMA = 'dbo') AS column_count
FROM INFORMATION_SCHEMA.TABLES t
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
GO
