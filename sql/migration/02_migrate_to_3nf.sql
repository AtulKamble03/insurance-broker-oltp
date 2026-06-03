-- ============================================================
-- STEP 2: Migrate from Staging to 3NF Normalised Tables
-- ============================================================
-- THEORY CONCEPT: THE MIGRATION ORDER MATTERS
--
-- You MUST load tables in dependency order (parents before children).
-- A Foreign Key means "this row must already exist in the parent table."
-- Loading children before parents = FK violation = migration fails.
--
-- Correct order for our schema:
--   1. zip_codes     (no dependencies)
--   2. patients      (depends on zip_codes)
--   3. doctors       (no dependencies)
--   4. diagnoses     (no dependencies)
--   5. medications   (no dependencies)
--   6. visits        (depends on patients + doctors)
--   7. visit_diagnoses (depends on visits + diagnoses)
--   8. prescriptions (depends on visits + medications)
--
-- Real-world analogy: Building a house.
-- You can't install the roof before the walls.
-- You can't install walls before the foundation.
-- Dependencies define the build sequence.
-- ============================================================

USE hospital_db;
GO

-- ============================================================
-- STEP 2.1 — Load zip_codes
-- ============================================================
-- THEORY: 3NF extraction
-- City and State depend on ZIP (not on patient_id).
-- Storing them with patients = transitive dependency = 3NF violation.
-- Fix: extract to a separate zip_codes table.
-- ============================================================

INSERT INTO dbo.zip_codes (zip_code, city, state)
SELECT DISTINCT
    LEFT(REPLACE(ZIP, ' ', ''), 5)  AS zip_code,  -- clean to 5 chars
    CITY,
    LEFT(STATE, 2)                  AS state
FROM staging.patients
WHERE ZIP IS NOT NULL AND LEN(TRIM(ZIP)) >= 5
  AND CITY IS NOT NULL AND STATE IS NOT NULL
  AND LEFT(REPLACE(ZIP, ' ', ''), 5) NOT IN (SELECT zip_code FROM dbo.zip_codes);

PRINT 'zip_codes loaded: ' + CAST((SELECT COUNT(*) FROM dbo.zip_codes) AS VARCHAR);
GO


-- ============================================================
-- STEP 2.2 — Load patients
-- ============================================================
-- THEORY: Surrogate keys vs Natural keys
-- Synthea uses UUID (Id) as the natural key for patients.
-- We use patient_id IDENTITY as surrogate key.
-- WHY? Because UUIDs are slow for JOINs (36 chars vs 4-byte INT).
-- We store the original UUID in a separate column for traceability.
-- ============================================================

-- Add synthea_id column to track the original UUID (for JOIN during migration)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.patients') AND name = 'synthea_id')
    ALTER TABLE dbo.patients ADD synthea_id NVARCHAR(50);

INSERT INTO dbo.patients (first_name, last_name, date_of_birth, gender, zip_code, synthea_id)
SELECT
    TRIM(FIRST)                                AS first_name,
    TRIM(LAST)                                 AS last_name,
    TRY_CAST(BIRTHDATE AS DATE)               AS date_of_birth,
    CASE UPPER(TRIM(GENDER))
        WHEN 'M' THEN 'M'
        WHEN 'F' THEN 'F'
        ELSE 'O'
    END                                        AS gender,
    CASE WHEN LEN(TRIM(ZIP)) >= 5
         THEN LEFT(REPLACE(ZIP, ' ', ''), 5)
         ELSE NULL END                         AS zip_code,
    Id                                         AS synthea_id
FROM staging.patients
WHERE FIRST IS NOT NULL AND LAST IS NOT NULL
  AND TRY_CAST(BIRTHDATE AS DATE) IS NOT NULL;

PRINT 'patients loaded: ' + CAST((SELECT COUNT(*) FROM dbo.patients) AS VARCHAR);
GO


-- ============================================================
-- STEP 2.3 — Load doctors
-- ============================================================
-- THEORY: Avoiding redundancy
-- Without a doctors table, every visit row would store doctor name,
-- phone, speciality. 1000 visits with same doctor = 1000 copies.
-- One doctors row + FK = stored once, referenced everywhere.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.doctors') AND name = 'synthea_id')
    ALTER TABLE dbo.doctors ADD synthea_id NVARCHAR(50);

INSERT INTO dbo.doctors (first_name, last_name, specialty, synthea_id)
SELECT DISTINCT
    TRIM(SUBSTRING(NAME, 1, CHARINDEX(' ', NAME + ' ') - 1)) AS first_name,
    TRIM(SUBSTRING(NAME, CHARINDEX(' ', NAME + ' ') + 1, 100)) AS last_name,
    NULLIF(TRIM(SPECIALITY), '')                               AS specialty,
    Id                                                         AS synthea_id
FROM staging.providers
WHERE NAME IS NOT NULL AND Id IS NOT NULL;

PRINT 'doctors loaded: ' + CAST((SELECT COUNT(*) FROM dbo.doctors) AS VARCHAR);
GO


-- ============================================================
-- STEP 2.4 — Load diagnoses (ICD-10 reference)
-- ============================================================
-- THEORY: Reference tables eliminate description redundancy
-- Without a diagnoses table, every condition row stores
-- "Type 2 diabetes mellitus without complications" — repeated 500 times.
-- With diagnoses table: stored once, code referenced everywhere.
-- This also ensures spelling consistency — one source of truth.
-- ============================================================

INSERT INTO dbo.diagnoses (icd10_code, description)
SELECT DISTINCT
    TRIM(CODE)        AS icd10_code,
    TRIM(DESCRIPTION) AS description
FROM staging.conditions
WHERE CODE IS NOT NULL AND DESCRIPTION IS NOT NULL
  AND TRIM(CODE) NOT IN (SELECT icd10_code FROM dbo.diagnoses);

PRINT 'diagnoses loaded: ' + CAST((SELECT COUNT(*) FROM dbo.diagnoses) AS VARCHAR);
GO


-- ============================================================
-- STEP 2.5 — Load medications
-- ============================================================
-- THEORY: Same as diagnoses — reference table eliminates repetition
-- ============================================================

INSERT INTO dbo.medications (brand_name, generic_name, dosage_form)
SELECT DISTINCT
    TRIM(DESCRIPTION)  AS brand_name,
    TRIM(DESCRIPTION)  AS generic_name,
    'Unknown'          AS dosage_form
FROM staging.medications
WHERE DESCRIPTION IS NOT NULL
  AND TRIM(DESCRIPTION) NOT IN (SELECT brand_name FROM dbo.medications);

PRINT 'medications loaded: ' + CAST((SELECT COUNT(*) FROM dbo.medications) AS VARCHAR);
GO


-- ============================================================
-- STEP 2.6 — Load visits (encounters)
-- ============================================================
-- THEORY: Foreign keys enforce referential integrity
-- Every visit must point to a real patient and a real doctor.
-- If the patient doesn't exist in our patients table,
-- the INSERT fails — protecting data quality automatically.
-- This is the database enforcing business rules so your code doesn't have to.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.visits') AND name = 'synthea_id')
    ALTER TABLE dbo.visits ADD synthea_id NVARCHAR(50);

INSERT INTO dbo.visits (patient_id, doctor_id, visit_date, visit_type, synthea_id)
SELECT
    p.patient_id,
    d.doctor_id,
    TRY_CAST(LEFT(e.START, 10) AS DATE)   AS visit_date,
    CASE LOWER(TRIM(e.ENCOUNTERCLASS))
        WHEN 'ambulatory'  THEN 'Outpatient'
        WHEN 'outpatient'  THEN 'Outpatient'
        WHEN 'inpatient'   THEN 'Inpatient'
        WHEN 'emergency'   THEN 'Emergency'
        WHEN 'urgentcare'  THEN 'Outpatient'
        WHEN 'virtual'     THEN 'Telehealth'
        ELSE 'Outpatient'
    END                                    AS visit_type,
    e.Id                                   AS synthea_id
FROM staging.encounters e
JOIN dbo.patients p ON p.synthea_id = e.PATIENT
JOIN dbo.doctors  d ON d.synthea_id = e.PROVIDER
WHERE TRY_CAST(LEFT(e.START, 10) AS DATE) IS NOT NULL;

PRINT 'visits loaded: ' + CAST((SELECT COUNT(*) FROM dbo.visits) AS VARCHAR);
GO


-- ============================================================
-- STEP 2.7 — Load visit_diagnoses
-- ============================================================
-- THEORY: Junction table solves 1NF violation
-- A visit can have multiple diagnoses. If we stored diagnoses
-- in the visits table as (diagnosis_1, diagnosis_2, diagnosis_3),
-- that's a repeating group — violates 1NF.
-- Solution: junction table with (visit_id, icd10_code) as composite PK.
-- Each row = one diagnosis for one visit. No limit on how many.
-- ============================================================

INSERT INTO dbo.visit_diagnoses (visit_id, icd10_code, is_primary)
SELECT
    v.visit_id,
    d.icd10_code,
    1   -- Synthea doesn't distinguish primary/secondary, treat all as primary
FROM staging.conditions c
JOIN dbo.visits    v ON v.synthea_id = c.ENCOUNTER
JOIN dbo.diagnoses d ON d.icd10_code = TRIM(c.CODE)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.visit_diagnoses vd
    WHERE vd.visit_id = v.visit_id AND vd.icd10_code = d.icd10_code
);

PRINT 'visit_diagnoses loaded: ' + CAST((SELECT COUNT(*) FROM dbo.visit_diagnoses) AS VARCHAR);
GO


-- ============================================================
-- STEP 2.8 — Load prescriptions
-- ============================================================
-- THEORY: 2NF — dosage depends on (visit + medication), not just one
-- The number of dispenses (quantity) is specific to THIS prescription.
-- It doesn't belong in medications (that would say ALL Paxlovid = 10 days).
-- It doesn't belong in visits (that would only allow one prescription).
-- It belongs here — in prescriptions — where it depends on both.
-- ============================================================

INSERT INTO dbo.prescriptions (visit_id, medication_id, dosage, frequency, days_supply, prescribed_date)
SELECT
    v.visit_id,
    m.medication_id,
    'Per clinical guidance'        AS dosage,
    'As directed'                  AS frequency,
    ISNULL(sm.DISPENSES, 1)        AS days_supply,
    TRY_CAST(LEFT(sm.START,10) AS DATE) AS prescribed_date
FROM staging.medications sm
JOIN dbo.visits      v ON v.synthea_id     = sm.ENCOUNTER
JOIN dbo.medications m ON m.brand_name     = TRIM(sm.DESCRIPTION)
WHERE TRY_CAST(LEFT(sm.START,10) AS DATE) IS NOT NULL;

PRINT 'prescriptions loaded: ' + CAST((SELECT COUNT(*) FROM dbo.prescriptions) AS VARCHAR);
GO


-- ============================================================
-- MIGRATION SUMMARY
-- ============================================================
SELECT 'zip_codes'       AS table_name, COUNT(*) AS rows FROM dbo.zip_codes       UNION ALL
SELECT 'patients',                       COUNT(*)         FROM dbo.patients        UNION ALL
SELECT 'doctors',                        COUNT(*)         FROM dbo.doctors         UNION ALL
SELECT 'diagnoses',                      COUNT(*)         FROM dbo.diagnoses       UNION ALL
SELECT 'medications',                    COUNT(*)         FROM dbo.medications     UNION ALL
SELECT 'visits',                         COUNT(*)         FROM dbo.visits          UNION ALL
SELECT 'visit_diagnoses',                COUNT(*)         FROM dbo.visit_diagnoses UNION ALL
SELECT 'prescriptions',                  COUNT(*)         FROM dbo.prescriptions
ORDER BY table_name;
GO
