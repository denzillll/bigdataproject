with source as (
    select * from {{ source('bronze', 'global_epidemiology') }}
),

cleaned as (
    select
        location                                as country_name,
        continent,
        cast(date as date)                      as report_date,

        greatest(coalesce(new_cases,  0), 0)    as new_cases,
        greatest(coalesce(new_deaths, 0), 0)    as new_deaths,

        total_cases,
        total_deaths,
        new_cases_per_million,
        new_deaths_per_million,

        total_vaccinations,
        people_vaccinated_per_hundred           as vaccinated_pct,

        population,
        gdp_per_capita,
        median_age

    from source
    where continent is not null
      and date >= cast('2020-01-01' as date)
)

select * from cleaned
