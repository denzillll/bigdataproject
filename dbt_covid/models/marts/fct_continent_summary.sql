with country as (
    select * from {{ ref('dim_country') }}
    where continent is not null
),

by_continent as (
    select
        continent,
        count(*)                        as num_countries,
        sum(population)                 as total_population,
        sum(peak_total_cases)           as total_cases,
        sum(peak_total_deaths)          as total_deaths,
        avg(peak_vaccinated_pct)        as avg_peak_vaccinated_pct,
        avg(gdp_per_capita)             as avg_gdp_per_capita
    from country
    group by continent
)

select
    continent,
    num_countries,
    total_population,
    total_cases,
    total_deaths,
    case
        when total_cases > 0
            then round(total_deaths * 100.0 / total_cases, 4)
    end                                 as continent_cfr_pct,
    avg_peak_vaccinated_pct,
    avg_gdp_per_capita
from by_continent
order by continent_cfr_pct desc nulls last
