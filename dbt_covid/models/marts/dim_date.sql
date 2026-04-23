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
    cast(date_day as date)                                          as date_day,
    extract(year  from date_day)                                    as year,
    extract(month from date_day)                                    as month,
    extract(day   from date_day)                                    as day,
    extract(quarter from date_day)                                  as quarter,
    format_date('%Y-%m', date_day)                                  as year_month,
    format_date('%A', date_day)                                     as day_name,
    case when extract(dayofweek from date_day) in (1,7)
         then true else false end                                   as is_weekend
from date_spine