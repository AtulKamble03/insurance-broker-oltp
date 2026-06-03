-- ============================================================
-- STEP 1: Bulk Load Synthea CSV files into Staging Tables
-- ============================================================
-- THEORY CONCEPT: BULK INSERT vs INSERT SELECT
--
-- BULK INSERT reads directly from a file into a table.
-- It is 10-100x faster than row-by-row INSERT because:
--  - Minimal logging (writes to transaction log in chunks)
--  - No row-by-row constraint checking during load
--  - Direct memory mapping of the file
--
-- Real-world analogy: Moving furniture into a new house.
-- Bulk Insert = a moving truck (everything in one trip).
-- Row-by-row Insert = carrying one item at a time on foot.
--
-- UPDATE the file paths below to match your Synthea output folder.
-- ============================================================

USE hospital_db;
GO

DECLARE @synthea_path NVARCHAR(500) = 'C:\Personal Workspace\hospital-oltp-project\data\synthea\csv\';

-- ── Load Patients ─────────────────────────────────────────────
TRUNCATE TABLE staging.patients;
EXEC('
BULK INSERT staging.patients
FROM ''' + @synthea_path + 'patients.csv''
WITH (
    FORMAT       = ''CSV'',
    FIRSTROW     = 2,           -- skip header row
    FIELDTERMINATOR = '','',
    ROWTERMINATOR   = ''0x0a'',
    MAXERRORS    = 10
)');
PRINT 'Patients loaded: ' + CAST((SELECT COUNT(*) FROM staging.patients) AS VARCHAR);

-- ── Load Providers ────────────────────────────────────────────
TRUNCATE TABLE staging.providers;
EXEC('
BULK INSERT staging.providers
FROM ''' + @synthea_path + 'providers.csv''
WITH (
    FORMAT       = ''CSV'',
    FIRSTROW     = 2,
    FIELDTERMINATOR = '','',
    ROWTERMINATOR   = ''0x0a'',
    MAXERRORS    = 10
)');
PRINT 'Providers loaded: ' + CAST((SELECT COUNT(*) FROM staging.providers) AS VARCHAR);

-- ── Load Encounters ───────────────────────────────────────────
TRUNCATE TABLE staging.encounters;
EXEC('
BULK INSERT staging.encounters
FROM ''' + @synthea_path + 'encounters.csv''
WITH (
    FORMAT       = ''CSV'',
    FIRSTROW     = 2,
    FIELDTERMINATOR = '','',
    ROWTERMINATOR   = ''0x0a'',
    MAXERRORS    = 10
)');
PRINT 'Encounters loaded: ' + CAST((SELECT COUNT(*) FROM staging.encounters) AS VARCHAR);

-- ── Load Conditions ───────────────────────────────────────────
TRUNCATE TABLE staging.conditions;
EXEC('
BULK INSERT staging.conditions
FROM ''' + @synthea_path + 'conditions.csv''
WITH (
    FORMAT       = ''CSV'',
    FIRSTROW     = 2,
    FIELDTERMINATOR = '','',
    ROWTERMINATOR   = ''0x0a'',
    MAXERRORS    = 10
)');
PRINT 'Conditions loaded: ' + CAST((SELECT COUNT(*) FROM staging.conditions) AS VARCHAR);

-- ── Load Medications ──────────────────────────────────────────
TRUNCATE TABLE staging.medications;
EXEC('
BULK INSERT staging.medications
FROM ''' + @synthea_path + 'medications.csv''
WITH (
    FORMAT       = ''CSV'',
    FIRSTROW     = 2,
    FIELDTERMINATOR = '','',
    ROWTERMINATOR   = ''0x0a'',
    MAXERRORS    = 10
)');
PRINT 'Medications loaded: ' + CAST((SELECT COUNT(*) FROM staging.medications) AS VARCHAR);

GO

-- ── Staging Summary ───────────────────────────────────────────
SELECT 'staging.patients'    AS table_name, COUNT(*) AS row_count FROM staging.patients    UNION ALL
SELECT 'staging.providers',                 COUNT(*)              FROM staging.providers    UNION ALL
SELECT 'staging.encounters',                COUNT(*)              FROM staging.encounters   UNION ALL
SELECT 'staging.conditions',                COUNT(*)              FROM staging.conditions   UNION ALL
SELECT 'staging.medications',               COUNT(*)              FROM staging.medications;
GO
