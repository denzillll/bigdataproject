with source as (
    select * from {{ source('bronze', 'country_summary') }}
)

select
    location                    as country_name,
    continent,
    population,
    gdp_per_capita,
    median_age,
    peak_total_cases,
    peak_total_deaths,
    case_fatality_rate_pct,
    max_vaccination_pct,
    days_with_data,
    first_reported_date,
    last_reported_date

from source
