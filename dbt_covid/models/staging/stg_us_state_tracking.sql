-- Staging layer for us_state_tracking.

with source as (
    select * from {{ source('bronze', 'us_state_tracking') }}
),

cleaned as (
    select
        upper(state)                            as state_code,
        cast(date as date)                      as report_date,

        coalesce(positive, 0)                   as cumulative_positive_tests,
        coalesce(negative, 0)                   as cumulative_negative_tests,
        hospitalized_currently                  as currently_hospitalized,
        hospitalized_cumulative                 as cumulative_hospitalized,
        in_icu_currently                        as currently_in_icu,
        on_ventilator_currently                 as currently_on_ventilator,
        coalesce(death, 0)                      as cumulative_deaths,
        total_test_results                      as cumulative_total_tests,
        positive_rate                           as positive_test_rate
    from source
    where date >= cast('{{ var("min_trusted_date") }}' as date)
)

select * from cleaned
