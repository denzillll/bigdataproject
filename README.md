<<<<<<< Updated upstream
# COVID-19 Data Integration Pipeline
## Assignment 1 — Big Data Technologies

---

## Project Structure

```
covid_project/
├── data/
│   ├── raw/                  ← downloaded files land here
│   │   ├── covid_global.csv
│   │   └── covid_us_states.json
│   └── processed/            ← any cleaned versions (optional)
├── scripts/
│   ├── 01_download_data.py   ← Step 1: fetch data from internet
│   └── 02_ingest_to_postgres.py  ← Step 2: load into PostgreSQL
├── sql/
│   └── 01_create_schema.sql  ← Run this in pgAdmin first
└── docs/                     ← put your report here
=======
# Big Data Technologies — end-to-end COVID-19 pipeline

Combined project for **Assignment 1** (data generation + ingestion into
PostgreSQL) and **Assignment 2** (transformation on Databricks with dbt +
serving through Unity Catalog lineage and dashboards).

---

## Folder layout

```
bigdataproject/
├── README.md                       ← this file (project overview)
├── SETUP.md                        ← step-by-step venv + Databricks setup
├── requirements.txt                ← single pinned dep list (both assignments)
├── .env.example                    ← credential template (never commit real .env)
├── .gitignore
├── .venv/                          ← Python 3.11 virtualenv (after SETUP)
│
├── Assignment 1.pptx.pdf           ← Assignment 1 slide deck
├── data/
│   └── raw/                        ← CSV + JSON downloaded by scripts/
├── sql/
│   └── 01_create_schema.sql        ← PostgreSQL schema for Assignment 1
├── scripts/
│   ├── 01_download_data.py         ← fetch OWID + COVID Tracking data
│   └── 02_ingest_to_postgres.py    ← load into PostgreSQL
├── docs/
│   ├── data_dictionary.md          ← Assignment 1 data dictionary
│   └── report.md                   ← Assignment 1 report
│
├── dbt_covid/                      ← Assignment 2 dbt project
│   ├── dbt_project.yml
│   ├── profiles.yml                ← copy to ~/.dbt/profiles.yml
│   ├── packages.yml
│   ├── README.md                   ← dbt-specific walkthrough
│   └── models/
│       ├── sources/                ← Bronze source declarations
│       ├── staging/                ← Silver cleaning layer
│       ├── intermediate/           ← joins + derived metrics
│       └── marts/                  ← Gold layer (facts + dims)
└── architecture/
    ├── architecture.mermaid        ← end-to-end diagram (paste in mermaid.live)
    └── architecture_notes.md       ← component justifications for the report
>>>>>>> Stashed changes
```

---

<<<<<<< Updated upstream
## Setup Instructions

### 1. Install Python dependencies
```bash
pip install pandas requests psycopg2-binary sqlalchemy
```

### 2. Install PostgreSQL
- Download from: https://www.postgresql.org/download/
- Also install **pgAdmin** (comes bundled with PostgreSQL installer)

### 3. Create the database schema
- Open pgAdmin
- Connect to your local PostgreSQL server
- Open the Query Tool
- Open and run: `sql/01_create_schema.sql`

### 4. Download the data
```bash
python scripts/01_download_data.py
```
This saves:
- `data/raw/covid_global.csv` — 200+ countries, daily data 2020-2023
- `data/raw/covid_us_states.json` — US state-level daily tracking

### 5. Update your database credentials
Open `scripts/02_ingest_to_postgres.py` and update:
```python
DB_CONFIG = {
    "host":     "localhost",
    "port":     5432,
    "database": "postgres",
    "user":     "postgres",
    "password": "YOUR_PASSWORD_HERE"  ← change this
}
```

### 6. Run the ingestion pipeline
```bash
python scripts/02_ingest_to_postgres.py
=======
## Assignment 1 — ingestion (already done)

Builds a PostgreSQL OLTP with three tables:

| Table                             | Rows     | Source                                |
|-----------------------------------|----------|---------------------------------------|
| `covid.global_epidemiology`       | ~525 k   | Our World in Data (CSV)               |
| `covid.us_state_tracking`         | ~20 k    | COVID Tracking Project API (JSON)     |
| `covid.country_summary`           | 239      | SQL aggregate of `global_epidemiology`|

See `docs/report.md` and `docs/data_dictionary.md` for the full writeup.

### To re-run Assignment 1 from scratch:
```bash
source .venv/bin/activate
python scripts/01_download_data.py      # fetch raw data
# ... load sql/01_create_schema.sql in pgAdmin first ...
python scripts/02_ingest_to_postgres.py # load into Postgres
>>>>>>> Stashed changes
```

---

<<<<<<< Updated upstream
## Data Sources

| File | Source | Format | Coverage |
|------|--------|--------|----------|
| covid_global.csv | Our World in Data (OWID) | CSV | 200+ countries, 2020–2023 |
| covid_us_states.json | Microsoft Pandemic Data Lake | JSON | 50 US states, 2020–2021 |
| country_summary | Generated via SQL | SQL | Aggregated from table 1 |

---

## Database Tables

| Table | Rows (approx) | Description |
|-------|--------------|-------------|
| covid.global_epidemiology | ~250,000 | Daily cases, deaths, vaccinations per country |
| covid.us_state_tracking | ~20,000 | Daily hospital/test/death data per US state |
| covid.country_summary | ~200 | SQL-generated aggregate per country |

---

## Expected Insights (future work)
- Correlation between vaccination rate and death rate
- Case fatality rate comparison across continents
- GDP vs pandemic outcomes
- US state hospitalisation patterns
- Wave timing differences across regions
=======
## Assignment 2 — transformation + serving (in progress)

Uses dbt on Databricks to turn the three Postgres tables into a Gold layer
that answers these business questions:

| Question                                                  | Mart                       |
|-----------------------------------------------------------|----------------------------|
| Q1. Did vaccinations reduce deaths?                       | `fct_vaccination_impact`   |
| Q2. Case fatality rate by continent?                      | `fct_continent_summary`    |
| Q3. Does GDP per capita correlate with outcomes?          | `fct_gdp_outcomes`         |
| Q4. Which US states had the worst hospital strain?        | `fct_us_state_severity`    |
| Q5. When did each country hit its peak wave?              | `fct_wave_peaks`           |

Plus a `fct_country_daily` + `dim_country` + `dim_date` star schema for
ad-hoc BI. Lineage is captured twice — in `dbt docs` (design-time) and in
Unity Catalog (runtime) — both screenshots go in the final report.

---

## Quick start

1. Read and follow [`SETUP.md`](SETUP.md) to create a Python 3.11 venv and
   install all dependencies.
2. Copy your Databricks credentials into `.env`.
3. From this folder (the project root):
   ```bash
   source .venv/bin/activate
   set -a; source .env; set +a
   mkdir -p ~/.dbt && cp dbt_covid/profiles.yml ~/.dbt/profiles.yml
   cd dbt_covid
   dbt deps
   dbt debug        # expect "All checks passed!"
   dbt build        # builds staging + intermediate + marts
   dbt docs generate && dbt docs serve
   ```

---

## Data sources

| File                    | Source                         | Format | Coverage                         |
|-------------------------|--------------------------------|--------|----------------------------------|
| `covid_global.csv`      | Our World in Data (OWID)       | CSV    | 239 countries, 2020–2026         |
| `covid_us_states.json`  | COVID Tracking Project API     | JSON   | 56 US states/territories, 2020–21|
| `country_summary`       | Generated via SQL              | —      | Aggregated from OWID             |
>>>>>>> Stashed changes
