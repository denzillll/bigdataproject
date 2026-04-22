-- dim_date: simple date spine covering the full reporting window.
-- Useful for BI tools that want a date dimension to join against.

{% set start_date = "'2020-01-01'" %}
{% set end_date   = "'2026-12-31'" %}

with date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast(" ~ start_date ~ " as date)",
        end_date="cast(" ~ end_date ~ " as date)"
    ) }}
)

select
    cast(date_day as date)                                      as date_day,
    year(date_day)                                              as year,
    month(date_day)                                             as month,
    day(date_day)                                               as day,
    quarter(date_day)                                           as quarter,
    date_format(date_day, 'yyyy-MM')                            as year_month,
    date_format(date_day, 'EEEE')                               as day_name,
    case when dayofweek(date_day) in (1,7) then true else false end as is_weekend
from date_spine
