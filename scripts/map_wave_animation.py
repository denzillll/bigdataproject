"""
COVID Wave Spread - Animated Choropleth Map
Queries fct_map_spread from BigQuery and renders an animated world map.
Run: python scripts/map_wave_animation.py
"""

import os
from dotenv import load_dotenv
from google.cloud import bigquery
import pandas as pd
import plotly.express as px

load_dotenv()

KEY_PATH  = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
PROJECT   = os.getenv("BQ_PROJECT_ID", "covid-bigquery-494113")
DATASET   = "covid_transform_marts"
TABLE     = "fct_map_spread"

# ── 1. Pull data from BigQuery ────────────────────────────────────────────────
print("Fetching data from BigQuery...")

client = bigquery.Client.from_service_account_json(KEY_PATH, project=PROJECT)

query = f"""
    select
        country_name,
        continent,
        -- aggregate to monthly so the animation has ~40 frames (fast + readable)
        -- daily = 1000+ frames which is too slow to scrub
        format_date('%Y-%m', report_date)          as month,
        round(avg(new_cases_7d_avg_per_million), 1) as avg_cases_per_million,
        sum(new_cases_per_million)                  as total_cases_per_million
    from `{PROJECT}.{DATASET}.{TABLE}`
    where report_date >= '2020-03-01'
    group by 1, 2, 3
    order by 3, 1
"""

df = client.query(query).to_dataframe()
print(f"Loaded {len(df):,} rows across {df['month'].nunique()} months")

# ── 2. Build animated choropleth ──────────────────────────────────────────────
fig = px.choropleth(
    df,
    locations        = "country_name",
    locationmode     = "country names",
    color            = "avg_cases_per_million",
    animation_frame  = "month",
    hover_name       = "country_name",
    hover_data       = {
        "continent": True,
        "avg_cases_per_million": ":.1f",
        "total_cases_per_million": ":.0f",
        "month": False,
    },
    color_continuous_scale = "YlOrRd",   # yellow → orange → red (low → high)
    range_color      = [0, 500],         # cap at 500/million so mid waves still show colour
    title            = "COVID-19 Wave Spread — Monthly Average New Cases per Million",
    labels           = {"avg_cases_per_million": "Cases / Million"},
)

fig.update_layout(
    title_font_size  = 18,
    geo              = dict(showframe=False, showcoastlines=True, projection_type="natural earth"),
    coloraxis_colorbar = dict(title="Cases<br>per Million"),
    sliders          = [{"currentvalue": {"prefix": "Month: "}}],
    updatemenus      = [{
        "type"      : "buttons",
        "showactive": False,
        "y"         : 0,
        "x"         : 0.5,
        "xanchor"   : "center",
        "buttons"   : [
            {"label": "▶ Play",  "method": "animate", "args": [None, {"frame": {"duration": 400}, "fromcurrent": True}]},
            {"label": "⏸ Pause", "method": "animate", "args": [[None], {"frame": {"duration": 0}, "mode": "immediate"}]},
        ],
    }],
)

# ── 3. Save and open ──────────────────────────────────────────────────────────
out_path = os.path.join(os.path.dirname(__file__), "..", "docs", "covid_wave_map.html")
out_path = os.path.normpath(out_path)

fig.write_html(out_path, auto_open=True)
print(f"Saved → {out_path}")
print("Opening in browser...")
