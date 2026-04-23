-- fct_map_spread: country-level daily table optimised for Looker Studio geo/map charts.
--
-- Key additions over fct_country_daily:
--   * new_cases_per_million         — raw daily value from staging (colours the map)
--   * new_cases_7d_avg_per_million  — smoothed 7-day rolling avg (removes weekend spikes)
--   * new_deaths_per_million        — raw daily deaths per million
-- Looker Studio Geo Chart uses `country_name` as the geo dimension.
-- Add a Date Range Control in Looker Studio to animate / filter by time.

with stg as (
    select * from {{ ref('stg_global_epidemiology') }}
),

with_rolling as (
    select
        country_name,
        continent,
        report_date,

        -- raw per-million (already in source)
        coalesce(new_cases_per_million,  0)  as new_cases_per_million,
        coalesce(new_deaths_per_million, 0)  as new_deaths_per_million,

        -- 7-day smoothed cases per million (best metric for map colour)
        round(
            avg(coalesce(new_cases_per_million, 0)) over (
                partition by country_name
                order by report_date
                rows between 6 preceding and current row
            ), 2
        )                                    as new_cases_7d_avg_per_million,

        -- absolute totals for tooltips
        total_cases,
        total_deaths,
        population

    from stg
)

select * from with_rolling
order by report_date, country_name
