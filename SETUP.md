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
```bash
# macOS
brew install python@3.11
python3.11 --version   # should print Python 3.11.x
```

## 3. Create a virtual environment
```bash
python3.11 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

## 4. Get a BigQuery service account key
1. Go to https://console.cloud.google.com → select project `covid-bigquery-494113`.
2. IAM & Admin → Service Accounts → `covid-pipeline`.
3. Keys → Add Key → Create new key → JSON → download.
4. Save it somewhere stable and lock down permissions:
```bash
mkdir -p ~/.gcp
mv ~/Downloads/covid-bigquery-494113-*.json ~/.gcp/covid-bigquery-key.json
chmod 600 ~/.gcp/covid-bigquery-key.json
```
**Never commit this file.** `.gitignore` excludes the `.gcp/` path pattern,
but keep the key outside the repo to be safe.

## 5. Configure environment variables
Copy `.env.example` to `.env` and fill in your keyfile path:
```bash
cp .env.example .env
# then edit .env
```

Also add to `~/.zshrc` (or `~/.bashrc`):
```bash
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/covid-bigquery-key.json"
export BQ_PROJECT_ID="covid-bigquery-494113"
```
Reload: `source ~/.zshrc`.

## 6. Verify the BigQuery connection
```bash
python -c "from google.cloud import bigquery; c = bigquery.Client(); print('Connected:', c.project)"
```
Expected: `Connected: covid-bigquery-494113`.

## 7. Verify the dbt connection
```bash
cd dbt_covid
dbt deps
dbt debug
```
Expected: `All checks passed!`.

## 8. (Optional) Load sample data into BigQuery Bronze
The raw CSVs are gitignored (too large for GitHub). Either download them
fresh (see `scripts/01_download_data.py`) or use the small samples in
`data/samples/` for a quick smoke test. The ingestion script
`scripts/03_upload_to_bigquery.py` writes them into
`covid-bigquery-494113.bronze.*`.

## 9. Run the full pipeline
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
