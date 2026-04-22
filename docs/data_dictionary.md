# Data Dictionary — COVID-19 Data Integration Pipeline
## Assignment 1 — Big Data Technologies

---

## Table 1: `covid.global_epidemiology`

**Source:** Our World in Data (OWID) — `covid_global.csv`
**Description:** Daily COVID-19 epidemiological metrics for 239 countries and territories from January 2020 to February 2026. Each row represents one country on one reporting date.
**Row count:** ~525,128
**Granularity:** One row per (location, date)

| Column | Data Type | Nullable | Constraints | Description |
|--------|-----------|----------|-------------|-------------|
| `id` | SERIAL (INTEGER) | NO | PRIMARY KEY | Auto-incrementing surrogate key |
| `location` | VARCHAR(100) | NO | — | Country or territory name (e.g., `"United States"`, `"Singapore"`) |
| `continent` | VARCHAR(50) | YES | — | Geographic continent (e.g., `"Asia"`, `"Europe"`) |
| `date` | DATE | NO | — | Reporting date (ISO 8601 format: `YYYY-MM-DD`) |
| `new_cases` | INTEGER | YES | `>= 0` | New confirmed COVID-19 cases reported on this date. Negative values (data corrections) are clipped to 0 during ingestion. |
| `new_deaths` | INTEGER | YES | `>= 0` | New confirmed COVID-19 deaths reported on this date. Negative values are clipped to 0 during ingestion. |
| `total_cases` | BIGINT | YES | — | Cumulative confirmed COVID-19 cases up to and including this date |
| `total_deaths` | BIGINT | YES | — | Cumulative confirmed COVID-19 deaths up to and including this date |
| `new_cases_per_million` | FLOAT | YES | — | New cases normalised per 1,000,000 population. Enables fair cross-country comparison. |
| `new_deaths_per_million` | FLOAT | YES | — | New deaths normalised per 1,000,000 population |
| `total_vaccinations` | BIGINT | YES | — | Cumulative number of vaccine doses administered (not individuals — one person receiving two doses counts as 2) |
| `people_vaccinated_per_hundred` | FLOAT | YES | — | Percentage of the population that has received at least one vaccine dose |
| `population` | BIGINT | YES | — | Total population of the country (sourced from UN estimates via OWID) |
| `gdp_per_capita` | FLOAT | YES | — | Gross Domestic Product per capita in USD (PPP-adjusted, sourced from World Bank) |
| `median_age` | FLOAT | YES | — | Median age of the country's population (sourced from UN World Population Prospects) |
| `created_at` | TIMESTAMP | NO | DEFAULT NOW() | Timestamp when this row was inserted into the database |

**Notes:**
- `new_cases` and `new_deaths` can be NULL on days with no report (common in early 2020 and for smaller territories).
- `total_vaccinations` is NULL for all rows before vaccine rollouts began (early 2021 and earlier for most countries).
- Rows where `continent` is NULL in the source (aggregate rows like "World", "High income") are filtered out during ingestion.

---

## Table 2: `covid.us_state_tracking`

**Source:** The COVID Tracking Project API — `covid_us_states.json`
**Description:** Daily COVID-19 hospital, testing, and death tracking data for US states and territories. Data covers the period from January 2020 through March 2021 (when the COVID Tracking Project ceased reporting).
**Row count:** ~20,780
**Granularity:** One row per (state, date)

| Column | Data Type | Nullable | Constraints | Description |
|--------|-----------|----------|-------------|-------------|
| `id` | SERIAL (INTEGER) | NO | PRIMARY KEY | Auto-incrementing surrogate key |
| `state` | VARCHAR(5) | NO | — | Two-letter US state or territory code (e.g., `"CA"`, `"NY"`, `"TX"`). Includes all 50 states plus DC, Puerto Rico, and other territories (56 total). |
| `date` | DATE | NO | — | Reporting date. Source format is `YYYYMMDD` integer, parsed to `DATE` during ingestion. |
| `positive` | INTEGER | YES | — | Cumulative number of positive PCR test results |
| `negative` | INTEGER | YES | — | Cumulative number of negative PCR test results |
| `hospitalized_currently` | INTEGER | YES | — | Number of patients currently hospitalised with COVID-19 on this date |
| `hospitalized_cumulative` | INTEGER | YES | — | Total number of patients ever hospitalised with COVID-19 up to this date |
| `in_icu_currently` | INTEGER | YES | — | Number of patients currently in the ICU with COVID-19 |
| `on_ventilator_currently` | INTEGER | YES | — | Number of patients currently on a ventilator with COVID-19 |
| `death` | INTEGER | YES | — | Cumulative number of COVID-19 deaths |
| `total_test_results` | INTEGER | YES | — | Cumulative total of all test results (positive + negative + inconclusive) |
| `positive_rate` | FLOAT | YES | — | Rolling 7-day average of the percentage of tests that returned positive. Range: 0.0–1.0. |
| `created_at` | TIMESTAMP | NO | DEFAULT NOW() | Timestamp when this row was inserted into the database |

**Notes:**
- `positive_rate` is not directly provided by the COVID Tracking Project API; if absent it will be NULL.
- Reporting consistency varies significantly by state, especially in 2020. Many states have NULL values for hospitalisation and ICU metrics in early months.
- Coverage ends on 7 March 2021 (final report from the COVID Tracking Project).

---

## Table 3: `covid.country_summary`

**Source:** Programmatically generated via SQL `SELECT … GROUP BY` from `covid.global_epidemiology`
**Description:** One-row-per-country aggregate summary table. Generated entirely in SQL using `MAX()`, `MIN()`, `COUNT()`, and `ROUND()` aggregates. Rebuilt on every pipeline run via `TRUNCATE … INSERT INTO … SELECT`.
**Row count:** 239 (one per country/territory)
**Granularity:** One row per location

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `id` | SERIAL (INTEGER) | NO | Auto-incrementing surrogate key (PRIMARY KEY) |
| `location` | VARCHAR | NO | Country or territory name |
| `continent` | VARCHAR | YES | Geographic continent |
| `population` | BIGINT | YES | Country population (`MAX(population)` from epidemiology table) |
| `gdp_per_capita` | FLOAT | YES | GDP per capita in USD (`MAX(gdp_per_capita)`) |
| `median_age` | FLOAT | YES | Median age of population (`MAX(median_age)`) |
| `peak_total_cases` | BIGINT | YES | Highest recorded cumulative confirmed case count (`MAX(total_cases)`) |
| `peak_total_deaths` | BIGINT | YES | Highest recorded cumulative death count (`MAX(total_deaths)`) |
| `case_fatality_rate_pct` | NUMERIC | YES | Case fatality rate as a percentage: `ROUND(peak_total_deaths / peak_total_cases * 100, 4)`. NULL if `peak_total_cases = 0`. |
| `max_vaccination_pct` | FLOAT | YES | Peak percentage of population that received at least one vaccine dose (`MAX(people_vaccinated_per_hundred)`) |
| `days_with_data` | BIGINT | NO | Number of distinct reporting dates available for this country (`COUNT(DISTINCT date)`) |
| `first_reported_date` | DATE | YES | Earliest date with a record for this country (`MIN(date)`) |
| `last_reported_date` | DATE | YES | Most recent date with a record for this country (`MAX(date)`) |

**Notes:**
- This table is the primary table for cross-country comparative analysis.
- `case_fatality_rate_pct` uses `NULLIF(peak_total_cases, 0)` to avoid division-by-zero errors.
- The table is fully regenerated on each pipeline run, so it always reflects the current state of `global_epidemiology`.

---

## Data Sources Summary

| Asset | Source | URL | Format | Coverage |
|-------|--------|-----|--------|----------|
| `covid_global.csv` | Our World in Data (OWID) | catalog.ourworldindata.org | CSV | 239 countries, Jan 2020 – Feb 2026 |
| `covid_us_states.json` | The COVID Tracking Project | api.covidtracking.com | JSON | 56 US states/territories, Jan 2020 – Mar 2021 |
| `country_summary` | SQL aggregate | Generated in-pipeline | PostgreSQL table | 239 countries, derived from CSV |

---

## Data Type Mapping

| Source Type | Python (pandas) Type | PostgreSQL Type |
|-------------|---------------------|-----------------|
| Integer metrics (cases, deaths) | `Int64` (nullable) | `INTEGER` / `BIGINT` |
| Decimal metrics (rates, GDP) | `float64` | `FLOAT` |
| Dates | `datetime64` | `DATE` |
| String labels | `object` | `VARCHAR` |
| Auto-generated timestamps | — | `TIMESTAMP DEFAULT NOW()` |
