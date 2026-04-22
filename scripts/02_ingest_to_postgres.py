"""
Assignment 1 - COVID-19 Data Integration Pipeline
Step 2: Load raw data into PostgreSQL

Requirements:
    pip install pandas psycopg2-binary sqlalchemy

Before running:
    1. Make sure PostgreSQL is running
    2. Run sql/01_create_schema.sql in pgAdmin first
    3. Update DB_CONFIG below with your credentials
"""

import pandas as pd
import json
import os
from sqlalchemy import create_engine, text

# ── Database config — UPDATE THESE ─────────────────────────────────────────
DB_CONFIG = {
    "host":     "localhost",
    "port":     5432,
    "database": "covid_db",
    "user":     "denzil",        
    "password": ""               
}

RAW_DIR = os.path.join(os.path.dirname(__file__), "../data/raw")

# ── Connect to PostgreSQL ───────────────────────────────────────────────────
def get_engine():
    url = (
        f"postgresql+psycopg2://{DB_CONFIG['user']}:{DB_CONFIG['password']}"
        f"@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}"
    )
    return create_engine(url)

# ── Load CSV → covid.global_epidemiology ───────────────────────────────────
def load_global_csv(engine):
    print("Loading OWID CSV → covid.global_epidemiology...")
    
    path = os.path.join(RAW_DIR, "covid_global.csv")
    df = pd.read_csv(path)
    
    # Clean up
    df["date"] = pd.to_datetime(df["date"])
    df["new_cases"]  = df["new_cases"].clip(lower=0)   # remove negative corrections
    df["new_deaths"] = df["new_deaths"].clip(lower=0)
    
    # Convert numeric columns safely
    int_cols = ["new_cases", "new_deaths", "total_cases", "total_deaths",
                "total_vaccinations", "population"]
    for col in int_cols:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce").astype("Int64")
    
    float_cols = ["new_cases_per_million", "new_deaths_per_million",
                  "people_vaccinated_per_hundred", "gdp_per_capita", "median_age"]
    for col in float_cols:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")
    
    # Truncate first so re-runs don't produce duplicate rows
    with engine.connect() as conn:
        conn.execute(text("TRUNCATE covid.global_epidemiology RESTART IDENTITY"))
        conn.commit()

    # Load to PostgreSQL
    df.to_sql(
        name="global_epidemiology",
        schema="covid",
        con=engine,
        if_exists="append",   # schema already created via SQL script
        index=False,
        chunksize=5000,        # load in batches to avoid memory issues
        method="multi"
    )
    
    print(f"  ✓ Loaded {len(df):,} rows")
    print(f"  Countries: {df['location'].nunique()}")
    print(f"  Date range: {df['date'].min().date()} → {df['date'].max().date()}")

# ── Load JSON → covid.us_state_tracking ────────────────────────────────────
def load_us_json(engine):
    print("\nLoading US JSON → covid.us_state_tracking...")
    
    path = os.path.join(RAW_DIR, "covid_us_states.json")
    with open(path) as f:
        data = json.load(f)
    
    df = pd.DataFrame(data)
    
    # Rename columns to match our schema
    col_map = {
        "state":                    "state",
        "date":                     "date",
        "positive":                 "positive",
        "negative":                 "negative",
        "hospitalizedCurrently":    "hospitalized_currently",
        "hospitalizedCumulative":   "hospitalized_cumulative",
        "inIcuCurrently":           "in_icu_currently",
        "onVentilatorCurrently":    "on_ventilator_currently",
        "death":                    "death",
        "totalTestResults":         "total_test_results",
        "positiveRate":             "positive_rate",
    }
    
    # Keep only columns we have
    existing = {k: v for k, v in col_map.items() if k in df.columns}
    df = df[list(existing.keys())].rename(columns=existing)
    
    # Parse date (format: 20210131 → date)
    df["date"] = pd.to_datetime(df["date"].astype(str), format="%Y%m%d", errors="coerce")
    
    # Numeric cleanup
    int_cols = ["positive", "negative", "hospitalized_currently",
                "hospitalized_cumulative", "in_icu_currently",
                "on_ventilator_currently", "death", "total_test_results"]
    for col in int_cols:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce").astype("Int64")
    
    # Truncate first so re-runs don't produce duplicate rows
    with engine.connect() as conn:
        conn.execute(text("TRUNCATE covid.us_state_tracking RESTART IDENTITY"))
        conn.commit()

    df.to_sql(
        name="us_state_tracking",
        schema="covid",
        con=engine,
        if_exists="append",
        index=False,
        chunksize=2000,
        method="multi"
    )
    
    print(f"  ✓ Loaded {len(df):,} rows")
    print(f"  States: {df['state'].nunique()}")

# ── Create the SQL-generated summary table ─────────────────────────────────
def create_country_summary(engine):
    print("\nGenerating country_summary table via SQL...")
    
    sql = """
    TRUNCATE covid.country_summary RESTART IDENTITY;
    
    INSERT INTO covid.country_summary (
        location, continent, population, gdp_per_capita, median_age,
        peak_total_cases, peak_total_deaths, case_fatality_rate_pct,
        max_vaccination_pct, days_with_data, first_reported_date, last_reported_date
    )
    SELECT
        location,
        continent,
        MAX(population),
        MAX(gdp_per_capita),
        MAX(median_age),
        MAX(total_cases),
        MAX(total_deaths),
        ROUND(MAX(total_deaths)::NUMERIC / NULLIF(MAX(total_cases), 0) * 100, 4),
        MAX(people_vaccinated_per_hundred),
        COUNT(DISTINCT date),
        MIN(date),
        MAX(date)
    FROM covid.global_epidemiology
    GROUP BY location, continent;
    """
    
    with engine.connect() as conn:
        conn.execute(text(sql))
        conn.commit()
        result = conn.execute(text("SELECT COUNT(*) FROM covid.country_summary"))
        count = result.scalar()
    
    print(f"  ✓ country_summary populated with {count} countries")

# ── Validate ────────────────────────────────────────────────────────────────
def validate(engine):
    print("\n" + "=" * 50)
    print("VALIDATION")
    print("=" * 50)
    
    queries = {
        "Row counts per table": """
            SELECT 'global_epidemiology' AS tbl, COUNT(*) AS rows FROM covid.global_epidemiology
            UNION ALL
            SELECT 'us_state_tracking',          COUNT(*) FROM covid.us_state_tracking
            UNION ALL
            SELECT 'country_summary',             COUNT(*) FROM covid.country_summary
        """,
        "Top 5 countries by total deaths": """
            SELECT location, peak_total_deaths, case_fatality_rate_pct
            FROM covid.country_summary
            ORDER BY peak_total_deaths DESC NULLS LAST
            LIMIT 5
        """
    }
    
    with engine.connect() as conn:
        for label, sql in queries.items():
            print(f"\n{label}:")
            result = pd.read_sql(sql, conn)
            print(result.to_string(index=False))

# ── Main ────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=" * 55)
    print("  COVID-19 DATA PIPELINE — Step 2: Ingest to PostgreSQL")
    print("=" * 55)
    
    engine = get_engine()
    
    load_global_csv(engine)
    load_us_json(engine)
    create_country_summary(engine)
    validate(engine)
    
    print("\n✅ Pipeline complete. Your database is ready.")
