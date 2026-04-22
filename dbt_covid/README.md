# dbt_covid — Assignment 2 transformation layer

This dbt project turns the three PostgreSQL tables from Assignment 1
(`covid.global_epidemiology`, `covid.us_state_tracking`, `covid.country_summary`)
into a Gold layer on Databricks that answers the business questions listed
in the Assignment 1 README.

---

## Business questions the marts answer

| Question                                                  | Mart                       |
|-----------------------------------------------------------|----------------------------|
| Q1. Did vaccinations reduce deaths?                       | `fct_vaccination_impact`   |
| Q2. Case fatality rate by continent?                      | `fct_continent_summary`    |
| Q3. Does GDP per capita correlate with outcomes?          | `fct_gdp_outcomes`         |
| Q4. Which US states had the worst hospital strain?        | `fct_us_state_severity`    |
| Q5. When did each country hit its peak wave?              | `fct_wave_peaks`           |

Plus a core `fct_country_daily` + `dim_country` / `dim_date` star schema
for ad-hoc BI use.

---

## One-time setup

### 1. Create a Databricks workspace
- Sign up at https://www.databricks.com/try-databricks (Free Edition works
  for this assignment).
- Enable **Unity Catalog** for the workspace (it's on by default in new
  workspaces).

### 2. Create the schemas
On Free Edition you get a default UC catalog called `workspace`
(you cannot create new catalogs). Run this once in the SQL Editor:
```sql
CREATE SCHEMA IF NOT EXISTS workspace.bronze;
CREATE SCHEMA IF NOT EXISTS workspace.staging;
CREATE SCHEMA IF NOT EXISTS workspace.marts;
```
> Paid tiers: replace `workspace` with a custom catalog name
> (`CREATE CATALOG covid_analytics;`) and update `profiles.yml` +
> `sources.yml` accordingly.

### 3. Land Bronze
Point Fivetran or Airbyte at your Postgres, mapping the `covid` schema
into `workspace.bronze`. Expected table names:
- `workspace.bronze.covid__global_epidemiology`
- `workspace.bronze.covid__us_state_tracking`
- `workspace.bronze.covid__country_summary`

Both tools add an `_ingested_at` column automatically.

### 4. Install dbt locally
```bash
pip install dbt-databricks==1.8.*
```

### 5. Configure credentials
Copy `profiles.yml` from this repo to `~/.dbt/profiles.yml` and set
these environment variables (from your Databricks SQL warehouse → Connection details):
```bash
export DBT_DATABRICKS_HOST='adb-xxxxxxxx.x.azuredatabricks.net'
export DBT_DATABRICKS_HTTP_PATH='/sql/1.0/warehouses/abcdef1234567890'
export DBT_DATABRICKS_TOKEN='dapi...'
```

### 6. First run
```bash
dbt deps               # install dbt_utils + codegen
dbt debug              # verify connection
dbt build              # run models + tests end-to-end
dbt docs generate      # build lineage + data dictionary
dbt docs serve         # open http://localhost:8080
```

---

## Folder layout

```
dbt_covid/
├── dbt_project.yml         # config, materialisations, vars
├── profiles.yml            # Databricks connection template
├── packages.yml            # dbt_utils + codegen
└── models/
    ├── sources/
    │   └── sources.yml     # Bronze source declarations + freshness
    ├── staging/            # 1:1 with sources, light cleaning
    │   ├── stg_global_epidemiology.sql
    │   ├── stg_us_state_tracking.sql
    │   ├── stg_country_summary.sql
    │   └── _staging.yml
    ├── intermediate/       # reusable joins/aggregations (ephemeral)
    │   ├── int_country_daily.sql
    │   ├── int_us_state_daily.sql
    │   └── _intermediate.yml
    └── marts/              # Gold layer, business-facing tables
        ├── dim_country.sql
        ├── dim_date.sql
        ├── fct_country_daily.sql
        ├── fct_continent_summary.sql
        ├── fct_vaccination_impact.sql
        ├── fct_gdp_outcomes.sql
        ├── fct_us_state_severity.sql
        ├── fct_wave_peaks.sql
        └── _marts.yml
```

---

## Two lineage artifacts (this is the key report point)

**1. dbt docs — design-time lineage**
Generated from the SQL + YAML in this repo. Shows every ref() and
source() relationship. Run `dbt docs generate && dbt docs serve` and
screenshot the graph for the report.

**2. Unity Catalog lineage — runtime lineage**
Automatic. Every time a dbt model runs, Databricks captures the
read→write relationship. Open Catalog Explorer → any table → "Lineage"
tab. Also captures ad-hoc SQL queries and BI tools, which dbt can't see.

Include a screenshot of each in the report and explain the difference:
*dbt tells you what was designed; Unity Catalog tells you what actually ran.*

---

## Commands cheat sheet

| Command                                      | What it does                              |
|----------------------------------------------|-------------------------------------------|
| `dbt deps`                                   | Install packages                          |
| `dbt debug`                                  | Test connection                           |
| `dbt run`                                    | Build models only                         |
| `dbt test`                                   | Run tests only                            |
| `dbt build`                                  | Run models + tests (preferred)            |
| `dbt build --select staging`                 | Build only staging layer                  |
| `dbt build --select +fct_vaccination_impact` | Build mart + all its upstreams            |
| `dbt source freshness`                       | Check Bronze freshness                    |
| `dbt docs generate && dbt docs serve`        | Browsable lineage + data dictionary site  |
