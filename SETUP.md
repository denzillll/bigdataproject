# Environment setup — Assignments 1 + 2

Single Python virtual environment that covers both assignments.

---

## 1. Make sure you have Python 3.11

The existing `.venv/` uses Python 3.14, which dbt doesn't support yet.
Replace it with 3.11 (recommended) or 3.12.

**Check what you have:**
```bash
python3.11 --version   # should print "Python 3.11.x"
```

**If 3.11 is missing, install it:**

*macOS (Homebrew):*
```bash
brew install python@3.11
```

*macOS (pyenv — recommended if you already use pyenv):*
```bash
pyenv install 3.11.9
pyenv local 3.11.9
```

*Windows:*
Download from https://www.python.org/downloads/windows/ and check
"Add python.exe to PATH" during install.

*Linux:*
```bash
sudo apt install python3.11 python3.11-venv
```

---

## 2. Replace the venv

From the project root (`bigdataproject/`):

```bash
# Remove the old 3.14-based venv
rm -rf .venv

# Create a new 3.11-based venv
python3.11 -m venv .venv

# Activate it
source .venv/bin/activate          # macOS / Linux
# .venv\Scripts\activate           # Windows PowerShell

# Install everything
pip install --upgrade pip
pip install -r requirements.txt
```

This installs:
- **Assignment 1 stack**: pandas, requests, psycopg2-binary, sqlalchemy
- **Assignment 2 stack**: dbt-core, dbt-databricks, databricks-sql-connector
- **Dev tools**: jupyter, python-dotenv

---

## 3. Set up credentials

Copy the template and fill in your real values:
```bash
cp .env.example .env
# edit .env and paste your DBT_DATABRICKS_HOST / HTTP_PATH / TOKEN
```

`.env` is git-ignored — it will never be committed.

---

## 4. Load env vars into your shell session

Every time you open a new terminal, run:
```bash
source .venv/bin/activate
set -a; source .env; set +a
```

Or add this alias to your `~/.zshrc`:
```bash
alias bdt='cd ~/path/to/bigdataproject && source .venv/bin/activate && set -a && source .env && set +a'
```

Then just type `bdt` to enter the project environment.

---

## 5. Configure dbt

Copy the dbt profile into the global dbt config folder (dbt always reads
`~/.dbt/profiles.yml`, not the project folder):
```bash
mkdir -p ~/.dbt
cp dbt_covid/profiles.yml ~/.dbt/profiles.yml
```

The profile references the `DBT_DATABRICKS_*` env vars you set in step 4,
so no secrets are hardcoded.

---

## 6. Verify everything works

```bash
cd dbt_covid
dbt deps                           # install dbt packages (dbt_utils, codegen)
dbt debug                          # verifies connection + profile
```

You should see `All checks passed!` at the bottom. If not, the output will
tell you which piece (host / http_path / token) failed.

---

## 7. Smoke-test with one row

Before wiring up Fivetran/Airbyte, create the schemas and a single row so
`dbt build` has something to transform. In the Databricks SQL Editor:

```sql
CREATE SCHEMA IF NOT EXISTS workspace.bronze;
CREATE SCHEMA IF NOT EXISTS workspace.staging;
CREATE SCHEMA IF NOT EXISTS workspace.marts;

CREATE TABLE IF NOT EXISTS workspace.bronze.covid__global_epidemiology (
    id BIGINT, location STRING, continent STRING, date DATE,
    new_cases INT, new_deaths INT,
    total_cases BIGINT, total_deaths BIGINT,
    new_cases_per_million DOUBLE, new_deaths_per_million DOUBLE,
    total_vaccinations BIGINT, people_vaccinated_per_hundred DOUBLE,
    population BIGINT, gdp_per_capita DOUBLE, median_age DOUBLE,
    _ingested_at TIMESTAMP);

CREATE TABLE IF NOT EXISTS workspace.bronze.covid__us_state_tracking (
    id BIGINT, state STRING, date DATE,
    positive INT, negative INT,
    hospitalized_currently INT, hospitalized_cumulative INT,
    in_icu_currently INT, on_ventilator_currently INT,
    death INT, total_test_results INT, positive_rate DOUBLE);

CREATE TABLE IF NOT EXISTS workspace.bronze.covid__country_summary (
    location STRING, continent STRING,
    population BIGINT, gdp_per_capita DOUBLE, median_age DOUBLE,
    peak_total_cases BIGINT, peak_total_deaths BIGINT,
    case_fatality_rate_pct DOUBLE, max_vaccination_pct DOUBLE,
    days_with_data BIGINT,
    first_reported_date DATE, last_reported_date DATE);

-- One seed row so `dbt build` completes end-to-end
INSERT INTO workspace.bronze.covid__global_epidemiology VALUES
  (1, 'Spain', 'Europe', DATE'2021-07-01', 5000, 20, 3900000, 81000,
   106.1, 0.4, 25000000, 55.0, 47000000, 38400, 45.5, current_timestamp());
```

Then locally:
```bash
cd dbt_covid
dbt build
dbt docs generate
dbt docs serve     # opens http://localhost:8080
```

---

## Full bulk load (later step)

Once `dbt debug` and the smoke test pass, we'll write a small Python
script that uses the databricks-sdk to bulk-copy the Postgres COVID
tables into `workspace.bronze.*`. That replaces Fivetran/Airbyte for
Free Edition where third-party CDC tools get expensive.
