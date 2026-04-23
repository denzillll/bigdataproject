with country as (
    select * from {{ ref('dim_country') }}
)

select
    income_bucket,
    count(*)                            as num_countries,
    sum(population)                     as total_population,
    avg(gdp_per_capita)                 as avg_gdp_per_capita,
    sum(peak_total_cases)               as total_cases,
    sum(peak_total_deaths)              as total_deaths,
    case
        when sum(peak_total_cases) > 0
            then round(sum(peak_total_deaths) * 100.0 / sum(peak_total_cases), 4)
    end                                 as income_bucket_cfr_pct,
    avg(peak_vaccinated_pct)            as avg_peak_vaccinated_pct
from country
group by income_bucket
order by avg_gdp_per_capita desc nulls last
