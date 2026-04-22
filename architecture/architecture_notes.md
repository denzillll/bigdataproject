# Architecture notes — Assignment 2

These notes pair with `architecture.mermaid`. For each component we list:
**role** (what it does), **why we picked it** (vs. alternatives), and the
**persona** (which role on a data team owns it). This is what the report
should lean on for the "Data architecture design" section.

---

## Generation — source APIs (Our World in Data, COVID Tracking Project)
- **Role:** Public data providers; we have no control over schema or SLAs.
- **Why:** Fixed by the assignment — these are the datasets we chose in
  Assignment 1.
- **Role on team:** Data Producer (external).

## OLTP — PostgreSQL (Assignment 1 output)
- **Role:** Operational store of record. Holds raw ingested CSV/JSON plus
  the aggregate `country_summary` we build in SQL.
- **Why:** Already built in Assignment 1. Postgres is the default OLTP
  choice: ACID, mature tooling, trivial to host locally or in RDS/Supabase.
- **Role on team:** Data/Backend Engineer.

## Ingestion — Fivetran or Airbyte (Postgres CDC)
- **Role:** Captures inserts/updates/deletes from Postgres and lands them
  in Databricks Bronze tables.
- **Why Fivetran:** Managed, zero-maintenance CDC with schema-drift
  handling; ideal when you want to spend zero time on ingestion. The
  downside is cost per-row.
- **Why Airbyte (open-source alt):** Self-hostable, free, community
  connectors — a better fit for an academic project where cost matters.
  Trade-off: you run it yourself.
- **Alternatives considered:**
  - *Databricks Auto Loader* — great for files in object storage, but
    doesn't natively do Postgres CDC.
  - *Custom PySpark JDBC read* — works, but no CDC semantics and you own
    all failure handling.
- **Role on team:** Data Engineer.

## Bronze — raw Delta tables in Unity Catalog
- **Role:** Immutable replica of OLTP. One Delta table per Postgres table,
  plus an `_ingested_at` metadata column.
- **Why Delta:** ACID, time-travel (you can query "as of yesterday"),
  schema evolution, and it's the native format on Databricks.
- **Why Unity Catalog:** Centralised access control (grants at catalog/
  schema/table/column level), built-in column-level lineage, tags for
  sensitive fields, and AI-generated descriptions.
- **Role on team:** Data Engineer.

## Silver + Gold — dbt models on Databricks
- **Role:** All business logic. Staging = clean + rename; Intermediate =
  reusable joins; Marts = business-facing facts and dims.
- **Why dbt:**
  - Version-controlled transformations in Git (testable, reviewable).
  - Generic + singular tests catch regressions before they hit dashboards.
  - `dbt docs generate` produces a lineage graph and data dictionary for
    free — exactly the deliverables the assignment asks for.
  - `dbt-databricks` adapter is first-class and actively maintained.
- **Alternative considered — Delta Live Tables (DLT):** declarative,
  native streaming, `EXPECT` quality rules. We stay with dbt because the
  assignment requires dbt and because dbt's Git-first workflow wins on
  software-engineering practices.
- **Why we keep both dbt lineage AND Unity Catalog lineage:**
  - *dbt lineage* = design-time. Shows the DAG of models the analytics
    engineer built. Source lives in YAML.
  - *Unity Catalog lineage* = runtime. Shows what actually executed,
    including ad-hoc notebooks and downstream BI queries.
  - In the report we screenshot both and explain the difference.
- **Role on team:** Analytics Engineer.

## Orchestration — GitHub + GitHub Actions + Databricks Workflows
- **Role:** Trigger `dbt build` on a schedule (nightly) and on PRs (CI).
- **Why:** Git is already the source of truth for the dbt project; GH
  Actions is free for public repos; Databricks Workflows can trigger the
  same dbt project on-cluster for production runs.
- **Alternative considered — Airflow/Prefect/Dagster:** overkill for the
  size of this pipeline; valuable once multiple data teams + hundreds of
  DAGs are involved.
- **Role on team:** Platform / Analytics Engineer.

## Serving — Databricks SQL + BI + MLflow
- **Databricks SQL warehouse:** serverless SQL endpoint that Power BI,
  Tableau, or native Databricks dashboards connect to.
- **AI/BI Dashboards:** native Databricks dashboarding on top of Gold
  tables — the easiest way to produce the dashboard deliverable.
- **MLflow (optional):** if we train a model (e.g., "does vaccination
  coverage predict next-month deaths?") it's registered here and served
  via an endpoint.
- **Role on team:** Analytics Engineer → BI Developer / Data Scientist.

---

## Reliability, scalability, maintainability

**Reliability**
- Delta ACID transactions — no torn writes.
- dbt tests (`unique`, `not_null`, `accepted_values`, `relationships`)
  block bad data at build time.
- Source freshness tests fail the pipeline if Bronze is stale.
- Unity Catalog lineage shows blast radius of any schema change.

**Scalability**
- Spark + Delta scale horizontally — same code runs on 10 rows or 10 B.
- Databricks SQL warehouses auto-scale compute for BI users.
- dbt materialisations: views (cheap) for staging, ephemeral for
  intermediate, tables for marts. Switch to `incremental` if volume grows.

**Maintainability**
- Everything is in Git (dbt project, schema YAML, architecture diagram).
- Medallion separation of concerns — a break in one layer doesn't cascade.
- Two lineage views (dbt + UC) — analytics engineers and platform
  engineers each have the view they need.
- Data dictionary is generated from the same YAML that drives tests, so
  it can't drift from the code.

---

## Summary of roles

| Role                    | Owns                                         |
|-------------------------|----------------------------------------------|
| Data Engineer           | OLTP, Fivetran/Airbyte, Bronze tables        |
| Analytics Engineer      | dbt project, Silver/Gold, tests, docs        |
| Platform Engineer       | Databricks workspace, Unity Catalog, CI/CD   |
| BI Developer / Analyst  | Dashboards, report queries                   |
| Data Scientist          | MLflow models on Gold                        |
| Data Governance / Sec   | UC permissions, PII tags                     |
