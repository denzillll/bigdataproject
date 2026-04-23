# dbt_covid

dbt project for the COVID-19 Big Data pipeline.

## Models

| Layer | Materialisation | Purpose |
|---|---|---|
| `staging/` | view | Clean and type-cast raw BigQuery bronze tables |
| `intermediate/` | ephemeral | Derive rolling averages, CFR, year-month grain |
| `marts/` | table | Final analytics tables consumed by Looker Studio |

## Commands

```bash
dbt deps          # install packages (dbt_utils)
dbt debug         # verify BigQuery connection
dbt build         # run all models + tests
dbt docs generate # build lineage docs
dbt docs serve    # open lineage UI at http://localhost:8080
```
