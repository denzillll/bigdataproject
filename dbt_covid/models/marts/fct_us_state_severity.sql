-- Q4: US state hospitalisation / severity patterns.
--
-- One row per state summarising the worst points of strain.

with daily as (
    select * from {{ ref('int_us_state_daily') }}
)

select
    state_code,

    min(report_date)                                        as first_reported_date,
    max(report_date)                                        as last_reported_date,

    max(currently_hospitalized)                             as peak_currently_hospitalized,
    max(currently_in_icu)                                   as peak_currently_in_icu,
    max(currently_on_ventilator)                            as peak_currently_on_ventilator,
    max(cumulative_deaths)                                  as peak_cumulative_deaths,
    max(cumulative_positive_tests)                          as peak_cumulative_positive,
    max(cumulative_total_tests)                             as peak_cumulative_total_tests,
    max(positive_test_rate)                                 as peak_positive_test_rate
from daily
group by state_code
order by peak_currently_hospitalized desc nulls last
