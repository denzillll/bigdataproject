-- fct_wave_response_speed
--
-- Measures how long each country took from first sustained spread to its peak,
-- and whether faster-peaking countries had better or worse outcomes.
--
-- "First sustained spread" = first date where 7-day avg new cases > 5/day.
-- This filters out isolated early cases and captures the real start of spread.
--
-- Pandemic preparedness use: if countries that peaked quickly (short window)
-- had lower CFR, it supports the case for aggressive early intervention.
-- If slow-peaking countries did worse, it validates early lockdown policies.

with daily as (
    select * from {{ ref('int_country_daily') }}
),

-- First date of sustained spread per country
first_spread as (
    select
        country_name,
        min(report_date) as first_spread_date
    from daily
    where new_cases_7d_avg > 5
    group by country_name
),

-- Overall peak (highest 7-day avg across the entire pandemic)
peak as (
    select
        country_name,
        report_date      as peak_date,
        new_cases_7d_avg as peak_7d_avg
    from (
        select
            country_name,
            report_date,
            new_cases_7d_avg,
            row_number() over (
                partition by country_name
                order by new_cases_7d_avg desc, report_date asc
            ) as rn
        from daily
    )
    where rn = 1
),

country_attrs as (
    select
        country_name,
        continent,
        income_bucket,
        population,
        case_fatality_rate_pct
    from {{ ref('dim_country') }}
),

joined as (
    select
        f.country_name,
        c.continent,
        c.income_bucket,
        c.population,
        f.first_spread_date,
        p.peak_date,
        date_diff(p.peak_date, f.first_spread_date, day)                   as days_first_to_peak,
        round(p.peak_7d_avg / nullif(c.population, 0) * 1000000, 2)        as peak_cases_per_million,
        c.case_fatality_rate_pct
    from first_spread  f
    join peak          p using (country_name)
    join country_attrs c using (country_name)
    where date_diff(p.peak_date, f.first_spread_date, day) > 0
)

select
    country_name,
    continent,
    income_bucket,
    population,
    first_spread_date,
    peak_date,
    days_first_to_peak,
    peak_cases_per_million,
    case_fatality_rate_pct,

    case
        when days_first_to_peak <  60 then 'Fast (< 2 months)'
        when days_first_to_peak < 120 then 'Moderate (2-4 months)'
        when days_first_to_peak < 180 then 'Slow (4-6 months)'
        else                               'Very slow (> 6 months)'
    end as response_speed_bucket

from joined
order by days_first_to_peak asc
