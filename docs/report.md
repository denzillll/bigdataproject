# COVID-19 Data Integration Pipeline
## Assignment 1 Report — Big Data Technologies

---

**Student:** Denzil Lee
**Course:** Big Data Technologies
**Date:** 2 March 2026

---

## Table of Contents

1. [Introduction and Motivation](#1-introduction-and-motivation)
2. [Dataset Analysis](#2-dataset-analysis)
3. [Data Dictionary](#3-data-dictionary)
4. [Data Architecture Design](#4-data-architecture-design)
5. [Data Ingestion Pipeline](#5-data-ingestion-pipeline)
6. [Resulting Data Structures and Validation](#6-resulting-data-structures-and-validation)
7. [Conclusions and Further Work](#7-conclusions-and-further-work)
8. [References](#8-references)

---

## 1. Introduction and Motivation

### 1.1 Topic Selection

The COVID-19 pandemic represents one of the most data-rich global events in modern history. From January 2020, governments, health agencies, research institutions, and independent projects began producing an unprecedented volume of structured epidemiological data. Daily case counts, death tolls, hospitalisation figures, vaccination rollouts, and economic indicators were published in near real-time by hundreds of organisations across the world.

This project builds a data integration pipeline around COVID-19 epidemiological data. The topic was chosen for several reasons:

- **Data richness:** The COVID-19 datasets include multiple data formats (CSV and JSON), multiple sources, multiple granularities (global and US state-level), and span a wide temporal range (2020–2026), making them well-suited for practising data integration techniques.
- **Variety of producers:** The data comes from distinct systems — Our World in Data (OWID), an academic research platform, and the COVID Tracking Project, a volunteer-driven reporting initiative. Each uses different schemas, formats, and naming conventions, reflecting the real-world heterogeneity that makes data integration challenging.
- **Analytical relevance:** The data supports a broad range of downstream queries relevant to public health, economics, and social science research.

### 1.2 Expected Insights

Once the data is loaded and queryable, the following analytical questions can be explored:

1. **Vaccination vs. mortality:** Is there a measurable negative correlation between `people_vaccinated_per_hundred` and `new_deaths_per_million`? Countries that achieved high vaccination rates early should show reduced death rates in subsequent waves.

2. **Case Fatality Rate (CFR) by continent:** Does CFR differ significantly across continents? High-income regions generally had better healthcare infrastructure and earlier vaccine access, which may be reflected in lower CFRs.

3. **GDP per capita vs. pandemic outcomes:** Does a country's economic development level (as proxied by `gdp_per_capita`) correlate with its ability to contain COVID-19? Wealthier countries had greater capacity for testing, treatment, and vaccination procurement.

4. **US state hospitalisation patterns:** Which US states consistently had the highest hospitalisation burdens relative to population? How did the timing of state-level surges differ?

5. **Wave timing differences across regions:** Did different continents experience COVID waves at different times? Analysing `new_cases_per_million` over time can reveal regional wave patterns and the delay between them.

6. **Demographic vulnerability:** How does `median_age` of a country's population correlate with COVID death rates? Older populations faced significantly higher mortality risk.

---

## 2. Dataset Analysis

### 2.1 Overview of Data Assets

The pipeline integrates three data assets:

| Asset | Source | Format | Rows | Columns |
|-------|--------|--------|------|---------|
| `covid_global.csv` | Our World in Data | CSV | 525,128 | 14 |
| `covid_us_states.json` | COVID Tracking Project | JSON | 20,780 | 11 (extracted) |
| `country_summary` | SQL aggregate | PostgreSQL table | 239 | 13 |

### 2.2 Asset 1 — OWID Global CSV

**Source:** Our World in Data (OWID) epidemiological catalogue
**URL:** `https://catalog.ourworldindata.org/garden/covid/latest/compact/compact.csv`
**Format:** CSV (Comma-Separated Values), ~50 MB

OWID is an academic publication from the University of Oxford and the Global Change Data Lab. Their COVID dataset is compiled from national health ministry reports, the WHO, the European Centre for Disease Prevention and Control (ECDC), and other primary sources. It is updated daily and is widely regarded as one of the most comprehensive and reliable global COVID datasets available.

**Metadata:**
- **Temporal coverage:** 1 January 2020 – 8 February 2026
- **Geographic coverage:** 239 countries and territories
- **Total rows:** 525,128 (one row per country per reporting date)
- **Key columns used:** `location`, `date`, `new_cases`, `new_deaths`, `total_cases`, `total_deaths`, `new_cases_per_million`, `new_deaths_per_million`, `total_vaccinations`, `people_vaccinated_per_hundred`, `population`, `gdp_per_capita`, `median_age`, `continent`

**Observations:**
- The source file uses the column name `country` rather than `location`. The ingestion pipeline renames this during the download step to align with the target schema.
- Rows where `continent` is NULL represent aggregate rows (e.g., "World", "High income", "Asia") and are filtered out during download, retaining only individual country rows.
- `new_cases` and `new_deaths` occasionally contain negative values, which represent retrospective data corrections by national health ministries. These are clipped to 0 during ingestion to satisfy the database constraints.
- Vaccination columns (`total_vaccinations`, `people_vaccinated_per_hundred`) are NULL for all dates before vaccination campaigns began (pre-December 2020 for most countries).
- Sparsity increases for smaller territories: many small islands and dependencies have large gaps in reporting.

### 2.3 Asset 2 — COVID Tracking Project JSON

**Source:** The COVID Tracking Project (covidtracking.com)
**URL:** `https://api.covidtracking.com/v1/states/daily.json`
**Format:** JSON (JavaScript Object Notation), array of objects

The COVID Tracking Project was a volunteer-led initiative that collected and standardised US state-level COVID-19 data from January 2020 until its final report on 7 March 2021, when it ceased operations as federal data reporting improved. Its data is archived via a REST API.

**Metadata:**
- **Temporal coverage:** 13 January 2020 – 7 March 2021
- **Geographic coverage:** 56 US states and territories (50 states + DC + US territories including Puerto Rico, Virgin Islands, Guam, etc.)
- **Total rows:** 20,780 (one row per state per reporting date)
- **Date format in source:** `YYYYMMDD` integer (e.g., `20210307`), parsed to `DATE` type during ingestion

**Observations:**
- The JSON array contains approximately 56 fields per object. The pipeline extracts only the 11 fields relevant to the target schema, discarding metadata fields such as `hash`, `grade`, `score`, and `dataQualityGrade`.
- Column names in the JSON use camelCase (e.g., `hospitalizedCurrently`, `inIcuCurrently`). The pipeline renames these to snake_case to match the PostgreSQL schema.
- The `positiveRate` field was not consistently available from the COVID Tracking Project API and may be absent, in which case the `positive_rate` column is omitted and stored as NULL.
- Hospitalisation, ICU, and ventilator data was not reported by all states in the early months of the pandemic, resulting in a significant number of NULLs in these columns for dates prior to mid-2020.

### 2.4 Asset 3 — Country Summary (SQL-Generated)

**Source:** SQL `SELECT … GROUP BY` executed against `covid.global_epidemiology`

The third dataset is not downloaded but rather generated programmatically using SQL within the pipeline itself. It aggregates the 525,128 daily rows into a single summary row per country using PostgreSQL aggregate functions.

The generation uses:
- `MAX()` — to extract peak case counts, peak deaths, and static attributes (population, GDP, median age)
- `ROUND(MAX(deaths) / NULLIF(MAX(cases), 0) * 100, 4)` — to compute case fatality rate while guarding against division by zero
- `COUNT(DISTINCT date)` — to measure data density per country
- `MIN(date)` / `MAX(date)` — to bound the reporting period per country

This table is rebuilt from scratch on every pipeline run via `TRUNCATE … INSERT INTO … SELECT`, ensuring it always reflects the current state of the source table.

---

## 3. Data Dictionary

See the dedicated file: [`docs/data_dictionary.md`](data_dictionary.md)

A summary of the three tables is provided below.

### Table: `covid.global_epidemiology` (14 columns + id + created_at)

| Column | Type | Key information |
|--------|------|-----------------|
| `id` | SERIAL PK | Auto-generated |
| `location` | VARCHAR(100) NOT NULL | Country name |
| `continent` | VARCHAR(50) | Geographic region |
| `date` | DATE NOT NULL | Reporting date |
| `new_cases` | INTEGER ≥ 0 | Daily new cases |
| `new_deaths` | INTEGER ≥ 0 | Daily new deaths |
| `total_cases` | BIGINT | Cumulative cases |
| `total_deaths` | BIGINT | Cumulative deaths |
| `new_cases_per_million` | FLOAT | Population-normalised daily cases |
| `new_deaths_per_million` | FLOAT | Population-normalised daily deaths |
| `total_vaccinations` | BIGINT | Cumulative doses administered |
| `people_vaccinated_per_hundred` | FLOAT | % of population vaccinated |
| `population` | BIGINT | Country population |
| `gdp_per_capita` | FLOAT | GDP per capita (USD) |
| `median_age` | FLOAT | Median population age |
| `created_at` | TIMESTAMP | Ingestion timestamp |

### Table: `covid.us_state_tracking` (11 columns + id + created_at)

| Column | Type | Key information |
|--------|------|-----------------|
| `id` | SERIAL PK | Auto-generated |
| `state` | VARCHAR(5) NOT NULL | Two-letter state/territory code |
| `date` | DATE NOT NULL | Reporting date |
| `positive` | INTEGER | Cumulative positive tests |
| `negative` | INTEGER | Cumulative negative tests |
| `hospitalized_currently` | INTEGER | Currently hospitalised |
| `hospitalized_cumulative` | INTEGER | Ever hospitalised |
| `in_icu_currently` | INTEGER | Currently in ICU |
| `on_ventilator_currently` | INTEGER | Currently on ventilator |
| `death` | INTEGER | Cumulative deaths |
| `total_test_results` | INTEGER | Total tests conducted |
| `positive_rate` | FLOAT | % of tests positive |
| `created_at` | TIMESTAMP | Ingestion timestamp |

### Table: `covid.country_summary` (13 columns)

| Column | Type | Key information |
|--------|------|-----------------|
| `id` | SERIAL PK | Auto-generated |
| `location` | VARCHAR | Country name |
| `continent` | VARCHAR | Geographic region |
| `population` | BIGINT | Country population |
| `gdp_per_capita` | FLOAT | GDP per capita (USD) |
| `median_age` | FLOAT | Median population age |
| `peak_total_cases` | BIGINT | Highest cumulative case count |
| `peak_total_deaths` | BIGINT | Highest cumulative death count |
| `case_fatality_rate_pct` | NUMERIC | Deaths / Cases × 100 |
| `max_vaccination_pct` | FLOAT | Peak % vaccinated |
| `days_with_data` | BIGINT | Days with reported data |
| `first_reported_date` | DATE | Earliest record date |
| `last_reported_date` | DATE | Most recent record date |

---

## 4. Data Architecture Design

### 4.1 Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                         DATA SOURCES                             │
│                                                                  │
│  ┌───────────────────────────┐  ┌───────────────────────────┐   │
│  │   Our World in Data       │  │  COVID Tracking Project   │   │
│  │   REST Catalogue          │  │  REST API                 │   │
│  │   compact.csv (~50 MB)    │  │  /v1/states/daily.json    │   │
│  │   CSV format              │  │  JSON format              │   │
│  └─────────────┬─────────────┘  └──────────────┬────────────┘   │
└────────────────┼─────────────────────────────── ┼───────────────┘
                 │  HTTP/HTTPS                     │  HTTP/HTTPS
                 ▼                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│                   INGESTION LAYER — Python 3                     │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  01_download_data.py                                       │  │
│  │  ─────────────────────────────────────────────────────     │  │
│  │  • pandas.read_csv()   — fetch + parse CSV from URL        │  │
│  │  • requests.get()      — fetch JSON from REST API          │  │
│  │  • Column rename       — 'country' → 'location'            │  │
│  │  • Column selection    — keep only schema-relevant cols    │  │
│  │  • Continent filter    — drop aggregate rows               │  │
│  │  • Writes to:          data/raw/covid_global.csv           │  │
│  │                        data/raw/covid_us_states.json       │  │
│  └────────────────────────────┬───────────────────────────────┘  │
│                               │  Local filesystem                │
│  ┌────────────────────────────▼───────────────────────────────┐  │
│  │  02_ingest_to_postgres.py                                  │  │
│  │  ─────────────────────────────────────────────────────     │  │
│  │  • TRUNCATE tables     — idempotent re-runs                │  │
│  │  • Date parsing        — str/int → datetime64              │  │
│  │  • Type casting        — Int64 (nullable), float64         │  │
│  │  • Clip negatives      — new_cases / new_deaths ≥ 0        │  │
│  │  • Bulk insert         — SQLAlchemy method="multi"         │  │
│  │  • SQL aggregate       — country_summary via GROUP BY      │  │
│  │  • Validation queries  — row counts, top-5 deaths          │  │
│  └────────────────────────────┬───────────────────────────────┘  │
└───────────────────────────────┼──────────────────────────────────┘
                                │  psycopg2 / SQLAlchemy
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│               STORAGE LAYER — PostgreSQL 15                      │
│                                                                  │
│  Schema: covid                                                   │
│  ┌───────────────────────┐  ┌───────────────────────────────┐   │
│  │ global_epidemiology   │  │ us_state_tracking             │   │
│  │ 525,128 rows          │  │ 20,780 rows                   │   │
│  │ 239 countries         │  │ 56 states/territories         │   │
│  │ Jan 2020 – Feb 2026   │  │ Jan 2020 – Mar 2021           │   │
│  │ Source: CSV           │  │ Source: JSON                  │   │
│  └───────────┬───────────┘  └───────────────────────────────┘   │
│              │                                                   │
│              │  SQL: GROUP BY + MAX/MIN/COUNT aggregates         │
│              ▼                                                   │
│  ┌───────────────────────┐                                       │
│  │ country_summary       │                                       │
│  │ 239 rows              │                                       │
│  │ One row per country   │                                       │
│  │ Source: SQL-generated │                                       │
│  └───────────────────────┘                                       │
│                                                                  │
│  Indexes: location, date, (location, date) composite             │
└──────────────────────────────┬───────────────────────────────────┘
                               │  SQL queries
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│              CONSUMPTION LAYER                                   │
│                                                                  │
│  ┌────────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │ pgAdmin 4      │  │ psql CLI     │  │ Python / pandas      │ │
│  │ (GUI queries)  │  │ (scripted    │  │ (analysis, plotting) │ │
│  │                │  │  queries)    │  │                      │ │
│  └────────────────┘  └──────────────┘  └──────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

### 4.2 Component Selection Rationale

#### Python 3
Python was chosen as the orchestration language for the pipeline due to its dominant position in the data engineering ecosystem. The extensive library support — particularly `pandas`, `requests`, `sqlalchemy`, and `psycopg2-binary` — allows the full extract-transform-load (ETL) cycle to be written in a single, readable script with minimal boilerplate.

- **Reliability:** Python's error handling (`try/except`, `raise_for_status()`) makes it straightforward to surface and handle failures in network requests or database operations.
- **Scalability:** For larger datasets, pandas operations can be replaced with `polars` (a faster DataFrame library) or `dask` (for out-of-core processing) with minimal code changes.
- **Maintainability:** Python's readability and the wide availability of Python developers in data roles ensures the scripts are easy to understand, modify, and hand over.

#### pandas
`pandas` handles the data transformation layer: parsing CSV files, type casting, null handling, negative value correction (`.clip()`), and column renaming. Its `to_sql()` method provides a clean interface to SQLAlchemy for bulk database inserts.

- **Reliability:** `errors="coerce"` in `pd.to_numeric()` converts unparseable values to `NaN` rather than raising exceptions, preventing pipeline crashes on dirty data.
- **Scalability:** The `chunksize` parameter in `to_sql()` prevents large DataFrames from being loaded into memory all at once during inserts.

#### SQLAlchemy + psycopg2
SQLAlchemy provides the database abstraction layer, generating correct PostgreSQL-compatible SQL and managing connection pooling. `psycopg2` is the underlying PostgreSQL driver for Python.

- **Reliability:** SQLAlchemy manages transactions and connection state, ensuring atomicity of the TRUNCATE + INSERT operations.
- **Scalability:** SQLAlchemy's connection pooling supports concurrent pipeline runs or multi-threaded ingestion scenarios without manual connection management.
- **Maintainability:** The connection URL format (`postgresql+psycopg2://...`) is a single point of configuration. Switching to a different PostgreSQL host (e.g., a cloud-managed instance) requires only changing `DB_CONFIG`.

#### PostgreSQL 15
PostgreSQL was chosen as the storage layer. It is a mature, production-grade open-source relational database with strong support for complex analytical queries, data integrity constraints, and indexing.

- **Reliability:** ACID-compliant transactions ensure that the TRUNCATE + INSERT sequence in `create_country_summary()` is atomic — either all rows are written or none are, preventing partial states.
- **Scalability:** PostgreSQL handles the ~545,000 rows in this project with ease. For larger datasets, PostgreSQL supports table partitioning, read replicas, and can be deployed on high-capacity cloud instances (AWS RDS, Azure Database for PostgreSQL, GCP Cloud SQL).
- **Maintainability:** The use of a dedicated `covid` schema (rather than the default `public` schema) logically isolates the project's tables, making it easy to drop and recreate the entire dataset without affecting other database objects.

#### Data Format Choices
- **CSV** was appropriate for the OWID dataset because it is a large, tabular, static snapshot. pandas' `read_csv()` streams directly from a URL, avoiding the need to download the file before parsing.
- **JSON** was appropriate for the COVID Tracking Project data because the API returns a structured array of objects with heterogeneous field presence (not every object has every field). JSON's flexible schema accommodates this naturally.
- **PostgreSQL (relational)** was the correct target storage for both sources because the data has clear tabular structure, well-defined primary keys, and is intended for SQL-based analytical queries.

### 4.3 Roles

| Role | Responsibilities in this pipeline |
|------|----------------------------------|
| **Data Engineer** | Designs and implements `01_download_data.py` and `02_ingest_to_postgres.py`; maintains the ingestion pipeline; monitors for upstream source changes (e.g., column renames, URL changes). |
| **Database Administrator (DBA)** | Designs and maintains `01_create_schema.sql`; manages PostgreSQL server configuration, user permissions, backups, and performance tuning (indexes, query plans). |
| **Data Analyst** | Writes downstream queries against `covid.country_summary` and `covid.global_epidemiology`; produces reports and visualisations; identifies data quality issues. |
| **Data Owner / Steward** | Responsible for the accuracy of source data attribution; manages licensing compliance for OWID and COVID Tracking Project data (both are CC-BY licensed). |

---

## 5. Data Ingestion Pipeline

### 5.1 Pipeline Design Diagram

```
START
  │
  ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 1 — Extract (01_download_data.py)                     │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Source 1: OWID CSV                                 │   │
│  │  1a. pandas.read_csv(url) → DataFrame               │   │
│  │  1b. Rename 'country' → 'location'                  │   │
│  │  1c. Select 14 relevant columns                     │   │
│  │  1d. Filter: keep rows where continent IS NOT NULL  │   │
│  │  1e. Save → data/raw/covid_global.csv               │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Source 2: COVID Tracking Project JSON              │   │
│  │  2a. requests.get(url) → HTTP 200                   │   │
│  │  2b. json.load() → list of dicts                    │   │
│  │  2c. Save → data/raw/covid_us_states.json           │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 2 — Transform + Load: Global CSV                      │
│  (02_ingest_to_postgres.py → load_global_csv)               │
│                                                             │
│  2a. pd.read_csv('covid_global.csv')                        │
│  2b. pd.to_datetime(date)                                   │
│  2c. clip(lower=0) on new_cases, new_deaths                 │
│  2d. Cast int cols → Int64 (nullable integer)               │
│  2e. Cast float cols → float64                              │
│  2f. TRUNCATE covid.global_epidemiology RESTART IDENTITY    │
│  2g. df.to_sql() → bulk insert in chunks of 5,000           │
└─────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 3 — Transform + Load: US JSON                         │
│  (02_ingest_to_postgres.py → load_us_json)                  │
│                                                             │
│  3a. json.load('covid_us_states.json') → DataFrame          │
│  3b. Rename camelCase → snake_case                          │
│  3c. Keep only schema-mapped columns                        │
│  3d. pd.to_datetime(date, format="%Y%m%d")                  │
│  3e. Cast int cols → Int64                                  │
│  3f. TRUNCATE covid.us_state_tracking RESTART IDENTITY      │
│  3g. df.to_sql() → bulk insert in chunks of 2,000           │
└─────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 4 — SQL Aggregate: country_summary                    │
│  (02_ingest_to_postgres.py → create_country_summary)        │
│                                                             │
│  4a. TRUNCATE covid.country_summary RESTART IDENTITY        │
│  4b. INSERT INTO … SELECT                                   │
│       MAX(total_cases) AS peak_total_cases                  │
│       MAX(total_deaths) AS peak_total_deaths                │
│       ROUND(deaths/cases * 100, 4) AS cfr_pct              │
│       MAX(people_vaccinated_per_hundred)                    │
│       COUNT(DISTINCT date) AS days_with_data                │
│      FROM covid.global_epidemiology                         │
│      GROUP BY location, continent                           │
└─────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 5 — Validate                                          │
│                                                             │
│  5a. SELECT COUNT(*) per table                              │
│  5b. SELECT top 5 countries by peak_total_deaths            │
│  Print results to stdout                                    │
└─────────────────────────────────────────────────────────────┘
  │
  ▼
 END
```

### 5.2 Extraction Step

The extraction step (`01_download_data.py`) pulls data directly from public HTTP endpoints. For the CSV source, `pandas.read_csv()` is called with a URL, which streams the CSV directly into a DataFrame without requiring a separate download step. For the JSON source, the `requests` library performs an HTTP GET, and `response.raise_for_status()` raises an exception immediately if the server returns a non-2xx status code, ensuring failures are surfaced early.

Both raw files are saved to the `data/raw/` directory. This separation between raw storage and the database means the ingestion step (Step 2) can be re-run independently of the extraction step, which is important for iterative development and debugging.

### 5.3 Transformation Step

Before loading into PostgreSQL, several transformations are applied to ensure data integrity:

**Date parsing:** The OWID CSV stores dates as strings in ISO 8601 format (`"2021-01-15"`). The COVID Tracking Project stores dates as integers in `YYYYMMDD` format (`20210115`). Both are parsed to Python `datetime` objects and then stored as PostgreSQL `DATE` type.

**Type casting:** Integer columns (case counts, death counts, population) are cast to `pandas.Int64` — the nullable integer type. This is critical because standard `numpy.int64` cannot represent NULL values; using it would silently convert NULLs to 0, corrupting the data.

**Negative value correction:** National health ministries occasionally publish negative case or death counts to correct previously over-reported figures. These are meaningful data corrections but would violate the `CHECK (new_cases >= 0)` constraint in the schema. The pipeline clips them to 0 with `df.clip(lower=0)`.

**Column renaming:** The JSON source uses camelCase (`hospitalizedCurrently`), while the schema uses snake_case (`hospitalized_currently`). A column mapping dictionary handles this translation.

**Column filtering:** The JSON source contains ~56 fields per record, most of which are internal quality-control metadata not relevant to the project. Only the 11 schema-relevant fields are retained.

### 5.4 Load Step

Loading uses SQLAlchemy's `DataFrame.to_sql()` with `method="multi"`, which generates a single multi-row `INSERT INTO … VALUES (…), (…), …` statement per chunk rather than one INSERT per row. This is significantly faster for large datasets.

Chunk sizes are set conservatively — 5,000 rows for the global CSV and 2,000 rows for the US JSON — to avoid exhausting PostgreSQL's parameter binding limit (65,535 bound parameters per statement) while still achieving good throughput.

A `TRUNCATE … RESTART IDENTITY` is executed before each load. This ensures the pipeline is **idempotent** — running it multiple times produces the same result as running it once, with no duplicate rows. The identity reset means the `id` sequence is also reset so IDs remain consistent across runs.

### 5.5 Idempotency and Re-runability

A key design principle of the pipeline is idempotency. Any step can be re-run safely:
- Re-running `01_download_data.py` overwrites the raw files with fresh data from the upstream APIs.
- Re-running `02_ingest_to_postgres.py` truncates and reloads all three tables from the current raw files.

This is essential in production pipelines where network failures, upstream data corrections, or schema changes may require a full reload.

---

## 6. Resulting Data Structures and Validation

### 6.1 Table Row Counts

After a successful pipeline run, the following row counts were confirmed:

```
                tbl    rows
global_epidemiology  525,128
  us_state_tracking   20,780
    country_summary      239
```

These match expectations:
- **525,128** rows in `global_epidemiology` = 239 countries × average ~2,197 reporting days each (Jan 2020 – Feb 2026 is approximately 2,230 days; some countries have gaps).
- **20,780** rows in `us_state_tracking` = 56 states/territories × average ~371 reporting days each (the COVID Tracking Project reported for approximately 14 months).
- **239** rows in `country_summary` = one aggregate row per country, matching the 239 distinct `location` values in `global_epidemiology`.

### 6.2 Top 5 Countries by Total Deaths

The following query was run against `covid.country_summary` as part of the validation step:

```sql
SELECT location, peak_total_deaths, case_fatality_rate_pct
FROM covid.country_summary
ORDER BY peak_total_deaths DESC NULLS LAST
LIMIT 5;
```

Result:

| location | peak_total_deaths | case_fatality_rate_pct |
|----------|------------------:|----------------------:|
| United States | 1,235,172 | 1.1941 |
| Brazil | 703,725 | 1.8537 |
| India | 533,847 | 1.1848 |
| Russia | 404,290 | 1.6236 |
| Mexico | 335,093 | 4.3919 |

These figures are consistent with widely reported pandemic statistics. Notably, Mexico's CFR of 4.39% is substantially higher than that of the United States (1.19%), reflecting differences in healthcare capacity, testing rates, and demographic factors. India's relatively low CFR (1.18%) relative to its large absolute death count is consistent with its young population profile.

### 6.3 Schema Compliance Validation

The ingested data complies with the schema in the following ways:

**Constraints satisfied:**
- `new_cases >= 0` and `new_deaths >= 0` — enforced by `.clip(lower=0)` during transformation.
- `location NOT NULL` — guaranteed by the OWID source (after the `country` → `location` rename fix).
- `date NOT NULL` — guaranteed by `pd.to_datetime()` with valid source dates.

**Indexes:**
Three indexes on `global_epidemiology` support common query patterns:
- `idx_global_location` on `(location)` — for single-country time series queries
- `idx_global_date` on `(date)` — for time-range queries across all countries
- `idx_global_loc_date` on `(location, date)` — for the most common pattern: a specific country over a date range

### 6.4 Sample Analytical Queries

**Query 1 — Vaccination vs. death rate (top 10 most vaccinated countries):**
```sql
SELECT location, max_vaccination_pct, case_fatality_rate_pct
FROM covid.country_summary
WHERE max_vaccination_pct IS NOT NULL
ORDER BY max_vaccination_pct DESC
LIMIT 10;
```

**Query 2 — Average CFR by continent:**
```sql
SELECT continent,
       ROUND(AVG(case_fatality_rate_pct)::NUMERIC, 4) AS avg_cfr,
       COUNT(*) AS countries
FROM covid.country_summary
WHERE case_fatality_rate_pct IS NOT NULL
GROUP BY continent
ORDER BY avg_cfr DESC;
```

**Query 3 — US peak hospitalisation by state:**
```sql
SELECT state, MAX(hospitalized_currently) AS peak_hospitalized
FROM covid.us_state_tracking
WHERE hospitalized_currently IS NOT NULL
GROUP BY state
ORDER BY peak_hospitalized DESC
LIMIT 10;
```

**Query 4 — COVID wave analysis for a specific country:**
```sql
SELECT date, new_cases_per_million, new_deaths_per_million
FROM covid.global_epidemiology
WHERE location = 'Singapore'
  AND date >= '2021-01-01'
ORDER BY date;
```

---

## 7. Conclusions and Further Work

### 7.1 Summary of Achievements

This project successfully demonstrates a complete data integration pipeline for COVID-19 epidemiological data. The key achievements are:

1. **Multi-source integration:** Two datasets from distinct producers (an academic research institution and a volunteer tracking project), in different formats (CSV and JSON), using different naming conventions (camelCase vs. snake_case, `country` vs. `location`, integer dates vs. ISO dates), were integrated into a single unified storage layer.

2. **Data reliability:** The pipeline handles known data quality issues: negative case corrections are clipped; unparseable values are coerced to NULL rather than raising exceptions; NULL-safe integer types are used throughout; and the `NULLIF` guard prevents division-by-zero in the CFR calculation.

3. **Idempotency:** The TRUNCATE-before-insert pattern means the pipeline can be safely re-run at any time without producing duplicate data. This is a production-grade design principle.

4. **Programmatic SQL generation:** The `country_summary` table demonstrates how SQL itself can serve as a data generation tool — transforming 525,128 raw rows into a clean, queryable 239-row summary entirely within the database.

5. **Schema design:** The use of a dedicated `covid` schema, appropriate data types (including `BIGINT` for large cumulative counts, nullable `INTEGER` for daily metrics, and `FLOAT` for rates), and targeted indexes reflects a thoughtful data architecture designed for downstream query performance.

### 7.2 Limitations

- **Coverage gap in US data:** The COVID Tracking Project ceased reporting on 7 March 2021. This means the `us_state_tracking` table has no data for the Delta or Omicron waves (mid-2021 onwards), which were arguably the most significant subsequent periods of the pandemic.

- **Global data sparsity for small territories:** Many small island nations and territories have large gaps in reporting, particularly for vaccination and hospitalisation data. Any analysis involving these countries must account for high NULL rates.

- **No streaming capability:** The pipeline is a batch process designed to run on demand. It does not support incremental loads (loading only new rows since the last run) or real-time streaming updates. For a production system serving live dashboards, a streaming architecture (Apache Kafka → Apache Flink → PostgreSQL) would be more appropriate.

- **Single storage system:** Both the global and US datasets are loaded into the same PostgreSQL instance. If the schemas were incompatible (e.g., one required a document store like MongoDB and the other a relational model), a polyglot persistence architecture would be needed.

### 7.3 Further Work

Several directions would meaningfully extend this project:

1. **Incremental loading:** Modify the pipeline to detect the maximum `date` currently in each table and load only new rows from the source, rather than truncating and reloading the full dataset on each run.

2. **Alternative US data source:** The CDC's COVID Data Tracker provides US state-level data beyond March 2021. Integrating this source would extend the `us_state_tracking` table through the full pandemic period.

3. **Analytical dashboards:** Connect the PostgreSQL database to a visualisation tool (Apache Superset, Grafana, or Metabase) to build interactive dashboards for the expected insights identified in Section 1.2.

4. **Machine learning pipeline:** Use the integrated dataset as a feature store for predictive models — for example, predicting mortality rates from demographic and economic features (`gdp_per_capita`, `median_age`, `population`).

5. **Pipeline orchestration:** Replace the manual two-script execution with an orchestration framework such as Apache Airflow. This would allow the pipeline to run on a schedule (e.g., daily), handle retries on failure, and provide a graphical interface for monitoring pipeline runs.

6. **Data quality monitoring:** Add a data quality layer (using a tool such as Great Expectations) that validates row counts, null rates, and value ranges after each ingestion and alerts if the data drifts outside expected bounds.

---

## 8. References

1. Our World in Data — COVID-19 Dataset. [https://ourworldindata.org/covid-cases](https://ourworldindata.org/covid-cases)
2. The COVID Tracking Project — Data API. [https://covidtracking.com/data/api](https://covidtracking.com/data/api)
3. PostgreSQL 15 Documentation. [https://www.postgresql.org/docs/15/](https://www.postgresql.org/docs/15/)
4. SQLAlchemy Documentation. [https://docs.sqlalchemy.org/](https://docs.sqlalchemy.org/)
5. pandas Documentation — `DataFrame.to_sql`. [https://pandas.pydata.org/docs/reference/api/pandas.DataFrame.to_sql.html](https://pandas.pydata.org/docs/reference/api/pandas.DataFrame.to_sql.html)
6. Kleppmann, M. (2017). *Designing Data-Intensive Applications*. O'Reilly Media.
7. World Health Organization — COVID-19 Dashboard. [https://covid19.who.int](https://covid19.who.int)

---

*Report generated: 2 March 2026*
*Pipeline version: Assignment 1 — Big Data Technologies*
