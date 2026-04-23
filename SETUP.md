# Setup Guide

End-to-end setup for the COVID-19 Big Data pipeline. Target: reproduce
`dbt debug` passing against BigQuery on a fresh machine.

## 1. Clone the repo
```bash
git clone https://github.com/denzillll/bigdataproject.git
cd bigdataproject
```

## 2. Install Python 3.11
dbt-core 1.9 requires Python 3.11 (3.14 is too new for the BigQuery adapter).
The repo includes a `.python-version` file — if you use pyenv it will auto-select 3.11.9.
```bash
# macOS (pyenv — recommended)
brew install pyenv
pyenv install 3.11.9
pyenv local 3.11.9      # sets .python-version — already committed in the repo
python --version        # should print Python 3.11.9
```

## 3. Create a virtual environment
```bash
python3.11 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

## 4. Get a BigQuery service account key
1. Go to https://console.cloud.google.com → select project `covid-bigquery-494113`.
2. IAM & Admin → Service Accounts → `covid-pipeline`.
3. Keys → Add Key → Create new key → JSON → download.
4. Move it into the `keys/` folder inside the repo (gitignored):
```bash
mv ~/Downloads/covid-bigquery-494113-*.json keys/
```
**Never commit this file.** The `keys/` folder is in `.gitignore`.

## 5. Configure environment variables
Copy `.env.example` to `.env` and fill in your keyfile path:
```bash
cp .env.example .env
# then edit .env
```

Update `GOOGLE_APPLICATION_CREDENTIALS` in `.env` to point at your key file.

## 6. Verify the BigQuery connection
```bash
python -c "from google.cloud import bigquery; c = bigquery.Client(); print('Connected:', c.project)"
```
Expected: `Connected: covid-bigquery-494113`.

## 7. Set up the dbt connection profile
dbt needs a `profiles.yml` in your home directory to know how to connect to BigQuery.
This file is **not in the repo** (it's machine-specific).

```bash
mkdir -p ~/.dbt
cp dbt_covid/profiles.yml.example ~/.dbt/profiles.yml
```

Then edit `~/.dbt/profiles.yml` and set `keyfile` to the absolute path of your key:
```yaml
keyfile: /Users/yourname/Desktop/Big Data Project/keys/covid-bigquery-494113-xxxx.json
```

## 8. Verify the dbt connection
```bash
cd dbt_covid
dbt deps
dbt debug
```
Expected: `All checks passed!`.

## 9. (Optional) Load data into BigQuery Bronze
The raw CSVs are gitignored (too large for GitHub). Download them fresh:
```bash
python scripts/01_download_data.py
python scripts/03_postgres_to_bigquery.py
```
This writes raw tables into `covid-bigquery-494113.bronze.*`.

## 10. Run the full pipeline
```bash
cd dbt_covid
dbt build         # runs staging -> intermediate -> marts + all tests
dbt docs generate # builds manifest + catalog
dbt docs serve    # opens lineage UI at http://localhost:8080
```

## Troubleshooting

**`NoneType has no attribute 'close'` on `dbt debug`**
→ `GOOGLE_APPLICATION_CREDENTIALS` either isn't set or points at a missing
file. Run `echo $GOOGLE_APPLICATION_CREDENTIALS` and `ls -la` that path.

**SSL `certificate verify failed` on macOS**
→ venv's certifi bundle is stale. Fix:
```bash
pip install --upgrade certifi
export SSL_CERT_FILE=$(python -c "import certifi; print(certifi.where())")
export REQUESTS_CA_BUNDLE=$SSL_CERT_FILE
```
Put those two exports in `~/.zshrc` to persist.

**`dbt deps` fails to resolve packages**
→ Delete `dbt_packages/` and rerun `dbt deps`.

**BigQuery `PermissionDenied`**
→ The service account needs `BigQuery Data Editor` + `BigQuery Job User`
roles. Grant them in GCP Console → IAM.
