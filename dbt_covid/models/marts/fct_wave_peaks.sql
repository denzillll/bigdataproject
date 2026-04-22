-- Q5: When did each country hit its peak wave?
--
-- Identifies, per country, the month in which the 7-day rolling average
-- of new cases reached its maximum. Useful for a wave-timing heatmap.

with daily as (
    select * from {{ ref('int_country_daily') }}
),

ranked as (
    select
        country_name,
        continent,
        report_date,
        year_month,
        new_cases_7d_avg,
        row_number() over (
            partition by country_name
            order by new_cases_7d_avg desc, report_date asc
        ) as rn
    from daily
)

select
    {{ dbt_utils.generate_surrogate_key(['country_name']) }}  as country_sk,
    country_name,
    continent,
    report_date            as peak_date,
    year_month             as peak_year_month,
    round(new_cases_7d_avg, 2) as peak_new_cases_7d_avg
from ranked
where rn = 1
