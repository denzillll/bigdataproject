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
```

---

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
```

---

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
