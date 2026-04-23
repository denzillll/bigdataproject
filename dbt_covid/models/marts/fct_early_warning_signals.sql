-- fct_early_warning_signals
--
-- Measures how fast cases multiplied in each country's first 14 days of
-- sustained spread, then compares that initial growth rate against the
-- eventual peak severity and CFR.
--
-- Key metric: growth_multiplier_14d = cases_day_14 / cases_day_1
--   - A multiplier of 10 means cases grew 10x in the first two weeks
--   - High early multipliers may predict worse eventual peaks
--
-- Pandemic preparedness use: if early growth rate is predictive of peak
-- severity, it tells health authorities WHEN to escalate response — i.e.,
-- "if cases 10x in 14 days, trigger emergency protocols immediately."

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

-- Grab each day's cases relative to the start of spread
early_window as (
    select
        d.country_name,
        d.report_date,
        d.new_cases_7d_avg,
        date_diff(d.report_date, f.first_spread_date, day) as days_since_spread
    from daily         d
    join first_spread  f using (country_name)
    where date_diff(d.report_date, f.first_spread_date, day) between 0 and 13
),

-- Snapshot at day 0 and day 13 (= 14-day window)
day_endpoints as (
    select
        country_name,
        max(case when days_since_spread = 0  then new_cases_7d_avg end) as cases_day_1,
        max(case when days_since_spread = 13 then new_cases_7d_avg end) as cases_day_14
    from early_window
    group by country_name
),

-- Overall peak severity
peak as (
    select
        country_name,
        max(new_cases_7d_avg) as peak_7d_avg
    from daily
    group by country_name
),

country_attrs as (
    select
        country_name,
        continent,
        income_bucket,
        population,
        case_fatality_rate_pct
    from {{ ref('dim_country') }}
)

select
    e.country_name,
    c.continent,
    c.income_bucket,

    round(e.cases_day_1,  1)  as cases_day_1,
    round(e.cases_day_14, 1)  as cases_day_14,

    -- How many times did cases multiply in 14 days?
    round(e.cases_day_14 / nullif(e.cases_day_1, 0), 1)      as growth_multiplier_14d,

    -- Implied average daily growth rate % (compound growth formula)
    round(
        (pow(e.cases_day_14 / nullif(e.cases_day_1, 0), 1.0 / 13) - 1) * 100
    , 2)                                                       as daily_growth_rate_pct,

    -- How bad did the peak get?
    round(p.peak_7d_avg / nullif(c.population, 0) * 1000000, 2) as peak_cases_per_million,
    c.case_fatality_rate_pct,

    -- Early warning tier — what threshold should trigger escalation?
    case
        when e.cases_day_14 / nullif(e.cases_day_1, 0) >= 10 then 'Explosive (≥10x in 14 days)'
        when e.cases_day_14 / nullif(e.cases_day_1, 0) >=  5 then 'Rapid (5-10x in 14 days)'
        when e.cases_day_14 / nullif(e.cases_day_1, 0) >=  2 then 'Moderate (2-5x in 14 days)'
        else                                                        'Slow (< 2x in 14 days)'
    end as initial_spread_tier

from day_endpoints  e
join country_attrs  c using (country_name)
join peak           p using (country_name)
where e.cases_day_1  > 0
  and e.cases_day_14 is not null
order by growth_multiplier_14d desc nulls last
