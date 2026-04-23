-- Staging (Silver) layer for global_epidemiology.
-- Responsibilities of staging:
--   * Rename columns to analytics conventions (snake_case kept).
--   * Cast types cleanly.
--   * Clip obvious bad values (negative case/death counts -> 0).
--   * Filter rows before the trusted cutoff date.
--   * Exclude aggregate "locations" (World, High income, EU, etc.)
--     where continent is NULL -- we only want country rows.
-- Do NOT join other tables here. That belongs in intermediate/marts.

with source as (
    select * from {{ source('bronze', 'global_epidemiology') }}
),

cleaned as (
    select
        location                                as country_name,
        continent,
        cast(date as date)                      as report_date,

        -- Clip negatives: source sometimes publishes negative corrections.
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
        median_age,

    from source
    where continent is not null                         -- drop aggregate rows
      and date >= cast('{{ var("min_trusted_date") }}' as date)
)

select * from cleaned
