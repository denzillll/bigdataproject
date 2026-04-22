"""
Assignment 2 - COVID-19 Data Pipeline
Step 3: Load PostgreSQL tables → BigQuery (covid_raw dataset)

Requirements:
    pip install google-cloud-bigquery pandas-gbq db-dtypes sqlalchemy psycopg2-binary

Before running:
    export GOOGLE_APPLICATION_CREDENTIALS="/Users/denzil/Desktop/big data project/keys/covid-bigquery-494113-097ddccca849.json"
"""

import pandas as pd
from sqlalchemy import create_engine, text
from google.cloud import bigquery
import os

# ── Config ─────────────────────────────────────────────────────
DB_CONFIG = {
    "host":     "localhost",
    "port":     5432,
    "database": "covid_db",
    "user":     "denzil",
    "password": ""
}

GCP_PROJECT  = "covid-bigquery-494113"
BQ_DATASET   = "covid_raw"

# ── Tables to migrate ──────────────────────────────────────────
# Format: PostgreSQL table → BigQuery table
TABLES = [
    ("covid.global_epidemiology", "global_epidemiology"),
    ("covid.us_state_tracking",   "us_state_tracking"),
    ("covid.country_summary",     "country_summary"),
]

# ── Connect to PostgreSQL ──────────────────────────────────────
def get_pg_engine():
    url = (
        f"postgresql+psycopg2://{DB_CONFIG['user']}:{DB_CONFIG['password']}"
        f"@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}"
    )
    return create_engine(url)

# ── Upload a single DataFrame to BigQuery ─────────────────────
def upload_to_bigquery(df, bq_table, client):
    table_ref = f"{GCP_PROJECT}.{BQ_DATASET}.{bq_table}"

    # Convert date columns to string first — BigQuery handles them cleanly
    for col in df.columns:
        if pd.api.types.is_datetime64_any_dtype(df[col]):
            df[col] = df[col].dt.strftime("%Y-%m-%d")

    # Convert pandas Int64 (nullable) to standard int where possible
    for col in df.columns:
        if pd.api.types.is_integer_dtype(df[col]) or str(df[col].dtype) == "Int64":
            df[col] = df[col].astype("float64")  # float handles NULLs in BQ

    job_config = bigquery.LoadJobConfig(
        write_disposition="WRITE_TRUNCATE",  # overwrite table on each run (idempotent)
        autodetect=True,                     # let BigQuery detect schema from DataFrame
    )

    job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)
    job.result()  # wait for job to complete

    table = client.get_table(table_ref)
    print(f"  ✓ {table_ref}")
    print(f"    Rows: {table.num_rows:,}  |  Columns: {len(table.schema)}")

# ── Main ───────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=" * 60)
    print("  COVID-19 PIPELINE — Step 3: PostgreSQL → BigQuery")
    print("=" * 60)

    pg_engine = get_pg_engine()
    bq_client = bigquery.Client(project=GCP_PROJECT)

    for pg_table, bq_table in TABLES:
        print(f"\nMigrating {pg_table} → {BQ_DATASET}.{bq_table}...")

        # Read from PostgreSQL
        with pg_engine.connect() as conn:
            df = pd.read_sql(text(f"SELECT * FROM {pg_table}"), conn)

        # Drop the internal id and created_at columns — not needed in the DW
        drop_cols = [c for c in ["id", "created_at"] if c in df.columns]
        if drop_cols:
            df = df.drop(columns=drop_cols)

        print(f"  Read {len(df):,} rows, {len(df.columns)} columns from PostgreSQL")

        # Upload to BigQuery
        upload_to_bigquery(df, bq_table, bq_client)

    print("\n" + "=" * 60)
    print("✅ All tables loaded into BigQuery covid_raw dataset.")
    print(f"   View at: https://console.cloud.google.com/bigquery?project={GCP_PROJECT}")
    print("=" * 60)
