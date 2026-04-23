-- Intermediate model: US state-level daily fact with derived metrics.

with base as (
    select * from {{ ref('stg_us_state_tracking') }}
),

with_derived as (
    select
        state_code,
        report_date,
        format_date('%Y-%m', report_date) as year_month,

        cumulative_positive_tests,
        cumulative_deaths,
        cumulative_hospitalized,
        currently_hospitalized,
        currently_in_icu,
        currently_on_ventilator,
        cumulative_total_tests,
        positive_test_rate,

        -- Net-new daily values derived from cumulative columns.
        cumulative_positive_tests
            - lag(cumulative_positive_tests) over (
                partition by state_code order by report_date
            )                                          as new_positive_tests,

        cumulative_deaths
            - lag(cumulative_deaths) over (
                partition by state_code order by report_date
            )                                          as new_deaths
    from base
)

select * from with_derived
