# COVID-19 Big Data Pipeline
## Big Data Technologies — Assignment 1 & 2

## Project Structure

```
bigdataproject/
├── data/raw/                        ← downloaded CSV + JSON (gitignored)
├── scripts/
│   ├── 01_download_data.py          ← fetch OWID + COVID Tracking data
│   ├── 02_ingest_to_postgres.py     ← load into PostgreSQL (Assignment 1)
│   ├── 03_postgres_to_bigquery.py   ← move to BigQuery
│   └── map_wave_animation.py        ← animated COVID wave map (Plotly)
├── dbt_covid/                       ← dbt project (Assignment 2)
│   ├── models/
│   │   ├── staging/                 ← raw → cleaned views
│   │   ├── intermediate/            ← enriched ephemeral models
│   │   └── marts/                   ← final analytics tables
│   ├── dbt_project.yml
│   └── packages.yml
├── architecture/                    ← pipeline architecture diagram + notes
├── sql/
│   └── 01_create_schema.sql         ← PostgreSQL schema (Assignment 1)
├── docs/
│   ├── data_dictionary.md
│   └── report.md
├── .env.example                     ← environment variable template
├── requirements.txt
└── SETUP.md                         ← full setup guide
```

## Quick Start

See [SETUP.md](SETUP.md) for full instructions.
