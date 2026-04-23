# COVID-19 Big Data Pipeline
## Big Data Technologies — Assignment 1 & 2

## Project Structure

bigdataproject/
├── data/raw/                      ← downloaded CSV + JSON
├── scripts/
│   ├── 01_download_data.py        ← fetch OWID + COVID Tracking data
│   ├── 02_ingest_to_postgres.py   ← load into PostgreSQL
│   └── 03_postgres_to_bigquery.py ← move to BigQuery
├── sql/
│   └── 01_create_schema.sql       ← PostgreSQL schema
└── docs/
    ├── data_dictionary.md
    └── report.md
