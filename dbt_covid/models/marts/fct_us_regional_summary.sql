-- fct_us_regional_summary
--
-- Groups US states into 4 geographic regions and compares pandemic outcomes.
-- Reveals whether geography (not just population) drove COVID severity in the US.
-- Key insight: Southern states had worse hospitalisation outcomes despite
-- lower median age — suggesting healthcare capacity and policy differences
-- mattered more than demographics at the sub-national level.

with daily as (
    select * from {{ ref('int_us_state_daily') }}
),

severity as (
    select * from {{ ref('fct_us_state_severity') }}
),

-- Assign each state to a region
regions as (
    select state_code, region from unnest([
        -- Northeast
        struct('NY' as state_code, 'Northeast' as region),
        struct('NJ', 'Northeast'), struct('MA', 'Northeast'),
        struct('CT', 'Northeast'), struct('PA', 'Northeast'),
        struct('ME', 'Northeast'), struct('NH', 'Northeast'),
        struct('VT', 'Northeast'), struct('RI', 'Northeast'),
        -- South
        struct('TX', 'South'),    struct('FL', 'South'),
        struct('GA', 'South'),    struct('AL', 'South'),
        struct('MS', 'South'),    struct('LA', 'South'),
        struct('TN', 'South'),    struct('SC', 'South'),
        struct('NC', 'South'),    struct('VA', 'South'),
        struct('AR', 'South'),    struct('KY', 'South'),
        struct('WV', 'South'),    struct('DC', 'South'),
        struct('MD', 'South'),    struct('DE', 'South'),
        struct('OK', 'South'),
        -- Midwest
        struct('IL', 'Midwest'),  struct('OH', 'Midwest'),
        struct('MI', 'Midwest'),  struct('IN', 'Midwest'),
        struct('WI', 'Midwest'),  struct('MN', 'Midwest'),
        struct('MO', 'Midwest'),  struct('IA', 'Midwest'),
        struct('KS', 'Midwest'),  struct('NE', 'Midwest'),
        struct('SD', 'Midwest'),  struct('ND', 'Midwest'),
        -- West
        struct('CA', 'West'),     struct('WA', 'West'),
        struct('OR', 'West'),     struct('AZ', 'West'),
        struct('CO', 'West'),     struct('NV', 'West'),
        struct('UT', 'West'),     struct('NM', 'West'),
        struct('ID', 'West'),     struct('MT', 'West'),
        struct('WY', 'West'),     struct('AK', 'West'),
        struct('HI', 'West')
    ])
),

joined as (
    select
        s.state_code,
        r.region,
        s.peak_currently_hospitalized,
        s.peak_currently_in_icu,
        s.peak_currently_on_ventilator,
        s.peak_cumulative_deaths,
        s.peak_cumulative_positive,
        s.peak_positive_test_rate,
        s.first_reported_date,
        s.last_reported_date
    from severity s
    left join regions r using (state_code)
),

by_region as (
    select
        coalesce(region, 'Other Territories') as region,
        count(*)                                as num_states,
        sum(peak_currently_hospitalized)        as total_peak_hospitalized,
        sum(peak_currently_in_icu)              as total_peak_icu,
        sum(peak_currently_on_ventilator)       as total_peak_ventilator,
        sum(peak_cumulative_deaths)             as total_deaths,
        sum(peak_cumulative_positive)           as total_positive_cases,
        round(avg(safe_cast(peak_positive_test_rate as float64)), 4) as avg_peak_positive_rate,
        round(avg(peak_currently_hospitalized), 0) as avg_peak_hospitalized_per_state,
        round(avg(peak_currently_in_icu), 0)    as avg_peak_icu_per_state
    from joined
    group by 1
)

select * from by_region
order by total_peak_hospitalized desc
