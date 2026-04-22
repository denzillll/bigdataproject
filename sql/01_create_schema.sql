-- ============================================================
-- Assignment 1 - COVID-19 Data Integration Pipeline
-- Step 2: Create PostgreSQL Schema
-- Run this in pgAdmin or psql BEFORE running the Python
-- ingestion script
-- ============================================================

-- Create a dedicated schema to keep things organised
CREATE SCHEMA IF NOT EXISTS covid;

-- ── TABLE 1: Global COVID cases & vaccinations (from OWID CSV) ──────────────
DROP TABLE IF EXISTS covid.global_epidemiology;

CREATE TABLE covid.global_epidemiology (
    id                          SERIAL PRIMARY KEY,
    location                    VARCHAR(100)    NOT NULL,   -- Country name
    continent                   VARCHAR(50),                -- Continent
    date                        DATE            NOT NULL,   -- Reporting date
    new_cases                   INTEGER,                    -- New confirmed cases that day
    new_deaths                  INTEGER,                    -- New deaths that day
    total_cases                 BIGINT,                     -- Cumulative confirmed cases
    total_deaths                BIGINT,                     -- Cumulative deaths
    new_cases_per_million       FLOAT,                      -- New cases per 1M population
    new_deaths_per_million      FLOAT,                      -- New deaths per 1M population
    total_vaccinations          BIGINT,                     -- Cumulative vaccine doses given
    people_vaccinated_per_hundred FLOAT,                    -- % population with at least 1 dose
    population                  BIGINT,                     -- Country population
    gdp_per_capita              FLOAT,                      -- GDP per capita (USD)
    median_age                  FLOAT,                      -- Median age of population
    created_at                  TIMESTAMP DEFAULT NOW(),

    -- Constraints
    CONSTRAINT chk_new_cases_positive  CHECK (new_cases >= 0 OR new_cases IS NULL),
    CONSTRAINT chk_new_deaths_positive CHECK (new_deaths >= 0 OR new_deaths IS NULL)
);

-- Index for common query patterns
CREATE INDEX idx_global_location ON covid.global_epidemiology(location);
CREATE INDEX idx_global_date     ON covid.global_epidemiology(date);
CREATE INDEX idx_global_loc_date ON covid.global_epidemiology(location, date);

-- ── TABLE 2: US State-level tracking (from JSON) ────────────────────────────
DROP TABLE IF EXISTS covid.us_state_tracking;

CREATE TABLE covid.us_state_tracking (
    id                      SERIAL PRIMARY KEY,
    state                   VARCHAR(5)      NOT NULL,   -- 2-letter state code e.g. 'CA'
    date                    DATE            NOT NULL,   -- Reporting date
    positive                INTEGER,                    -- Cumulative positive tests
    negative                INTEGER,                    -- Cumulative negative tests
    hospitalized_currently  INTEGER,                    -- Currently hospitalised
    hospitalized_cumulative INTEGER,                    -- Ever hospitalised
    in_icu_currently        INTEGER,                    -- Currently in ICU
    on_ventilator_currently INTEGER,                    -- Currently on ventilator
    death                   INTEGER,                    -- Cumulative deaths
    total_test_results      INTEGER,                    -- Total tests conducted
    positive_rate           FLOAT,                      -- % tests that are positive
    created_at              TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_us_state ON covid.us_state_tracking(state);
CREATE INDEX idx_us_date  ON covid.us_state_tracking(date);

-- ── TABLE 3: Country summary — SQL-generated aggregate ──────────────────────
-- This satisfies the "programmatically-generated SQL dataset" requirement
-- Run AFTER loading the two tables above

DROP TABLE IF EXISTS covid.country_summary;

CREATE TABLE covid.country_summary AS
SELECT
    location,
    continent,
    MAX(population)                                 AS population,
    MAX(gdp_per_capita)                             AS gdp_per_capita,
    MAX(median_age)                                 AS median_age,
    MAX(total_cases)                                AS peak_total_cases,
    MAX(total_deaths)                               AS peak_total_deaths,
    ROUND(
        MAX(total_deaths)::NUMERIC /
        NULLIF(MAX(total_cases), 0) * 100, 4
    )                                               AS case_fatality_rate_pct,
    MAX(people_vaccinated_per_hundred)              AS max_vaccination_pct,
    COUNT(DISTINCT date)                            AS days_with_data,
    MIN(date)                                       AS first_reported_date,
    MAX(date)                                       AS last_reported_date
FROM covid.global_epidemiology
GROUP BY location, continent;

-- Add primary key after creation
ALTER TABLE covid.country_summary ADD COLUMN id SERIAL PRIMARY KEY;

-- ============================================================
-- VALIDATION QUERIES — run these to confirm ingestion worked
-- ============================================================

-- 1. Row counts
SELECT 'global_epidemiology' AS table_name, COUNT(*) AS row_count FROM covid.global_epidemiology
UNION ALL
SELECT 'us_state_tracking',                 COUNT(*)               FROM covid.us_state_tracking
UNION ALL
SELECT 'country_summary',                   COUNT(*)               FROM covid.country_summary;

-- 2. Sample global data for Spain
SELECT location, date, new_cases, new_deaths, people_vaccinated_per_hundred
FROM covid.global_epidemiology
WHERE location = 'Spain'
ORDER BY date DESC
LIMIT 10;

-- 3. Top 10 countries by case fatality rate
SELECT location, peak_total_cases, peak_total_deaths, case_fatality_rate_pct
FROM covid.country_summary
WHERE peak_total_cases > 100000
ORDER BY case_fatality_rate_pct DESC
LIMIT 10;

-- 4. US states with highest peak hospitalisations
SELECT state, MAX(hospitalized_currently) AS peak_hospitalised
FROM covid.us_state_tracking
GROUP BY state
ORDER BY peak_hospitalised DESC
LIMIT 10;

-- 5. Check for nulls in key columns
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN new_cases   IS NULL THEN 1 ELSE 0 END) AS null_new_cases,
    SUM(CASE WHEN new_deaths  IS NULL THEN 1 ELSE 0 END) AS null_new_deaths,
    SUM(CASE WHEN location    IS NULL THEN 1 ELSE 0 END) AS null_location,
    SUM(CASE WHEN date        IS NULL THEN 1 ELSE 0 END) AS null_date
FROM covid.global_epidemiology;
