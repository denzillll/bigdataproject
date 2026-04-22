-- fct_country_daily: the main country-level daily fact table.
-- Foreign key into dim_country via country_sk.
-- This is the table BI tools hit for time-series charts.

with daily as (
    select * from {{ ref('int_country_daily') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['country_name']) }}     as country_sk,
    country_name,
    continent,
    report_date,
    year_month,

    new_cases,
    new_deaths,
    new_cases_7d_avg,
    new_deaths_7d_avg,

    total_cases,
    total_deaths,
    running_cfr_pct,

    total_vaccinations,
    vaccinated_pct
from daily
