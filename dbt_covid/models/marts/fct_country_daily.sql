with daily as (
    select * from {{ ref('int_country_daily') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['country_name']) }}    as country_sk,
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
