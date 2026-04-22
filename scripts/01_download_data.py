"""
Assignment 1 - COVID-19 Data Integration Pipeline
Step 1: Download raw data from open sources
"""

import pandas as pd
import requests
import json
import os

# ── Paths ──────────────────────────────────────────────────────────────────
RAW_DIR = os.path.join(os.path.dirname(__file__), "../data/raw")
os.makedirs(RAW_DIR, exist_ok=True)

# ── 1. CSV: Our World in Data — Global COVID epidemiology ──────────────────
def download_owid_csv():
    print("Downloading OWID global dataset (CSV)...")
    url = "https://catalog.ourworldindata.org/garden/covid/latest/compact/compact.csv"
    df = pd.read_csv(url)

    # OWID compact dataset uses 'country' — rename to match our schema
    if "country" in df.columns and "location" not in df.columns:
        df = df.rename(columns={"country": "location"})

    # Keep only the most relevant columns for our project
    cols = [
        "location", "date", "new_cases", "new_deaths",
        "total_cases", "total_deaths", "new_cases_per_million",
        "new_deaths_per_million", "total_vaccinations",
        "people_vaccinated_per_hundred", "population",
        "gdp_per_capita", "median_age", "continent"
    ]
    # Only keep columns that exist
    cols = [c for c in cols if c in df.columns]
    df = df[cols]
    
    # Filter out aggregate rows (continents, World) — keep countries only
    if "continent" in df.columns:
        df = df[df["continent"].notna()]
    
    out_path = os.path.join(RAW_DIR, "covid_global.csv")
    df.to_csv(out_path, index=False)
    print(f"  ✓ Saved: {out_path}")
    print(f"  Shape: {df.shape}")
    print(f"  Date range: {df['date'].min()} → {df['date'].max()}")
    print(f"  Countries: {df['location'].nunique()}")
    return df

# ── 2. JSON: Microsoft Pandemic Data Lake — US State-level tracking ─────────
def download_us_tracking_json():
    print("\nDownloading US COVID Tracking dataset (JSON)...")
    url = "https://api.covidtracking.com/v1/states/daily.json"
    response = requests.get(url, timeout=30)
    response.raise_for_status()
    data = response.json()
    
    out_path = os.path.join(RAW_DIR, "covid_us_states.json")
    with open(out_path, "w") as f:
        json.dump(data, f, indent=2, default=str)
    
    df = pd.DataFrame(data)
    print(f"  ✓ Saved: {out_path}")
    print(f"  Shape: {df.shape}")
    print(f"  Columns: {list(df.columns)}")
    return df

# ── Main ────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=" * 55)
    print("  COVID-19 DATA PIPELINE — Step 1: Download")
    print("=" * 55)

    df_global = download_owid_csv()
    df_us = download_us_tracking_json()

    print("\n✅ All data downloaded successfully.")
    print(f"\nFiles saved in: {os.path.abspath(RAW_DIR)}")
