-- Intermediate model: country-level daily fact with derived metrics.
-- Ephemeral -> no physical table, just inlined into downstream marts.
--
-- Adds:
--   * 7-day rolling new cases and deaths (smooths reporting spikes).
--   * Running case-fatality-rate (total_deaths / total_cases).
--   * Year-month grain for rollups.

with base as (
    select * from {{ ref('stg_global_epidemiology') }}
),

with_rolling as (
    select
        country_name,
        continent,
        report_date,
        date_format(report_date, 'yyyy-MM')            as year_month,

        new_cases,
        new_deaths,
        total_cases,
        total_deaths,

        avg(new_cases)  over (
            partition by country_name
            order by report_date
            rows between 6 preceding and current row
        )                                              as new_cases_7d_avg,

        avg(new_deaths) over (
            partition by country_name
            order by report_date
            rows between 6 preceding and current row
        )                                              as new_deaths_7d_avg,

        case
            when total_cases > 0
                then round(total_deaths * 100.0 / total_cases, 4)
        end                                            as running_cfr_pct,

        vaccinated_pct,
        total_vaccinations,
        population,
        gdp_per_capita,
        median_age
    from base
)

select * from with_rolling
