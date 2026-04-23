with daily as (
    select * from {{ ref('int_country_daily') }}
),

vax_threshold as (
    select
        country_name,
        min(report_date) as date_50pct_vaccinated
    from daily
    where vaccinated_pct >= 50
    group by country_name
),

joined as (
    select
        d.country_name,
        d.continent,
        d.report_date,
        d.new_deaths,
        d.population,
        case
            when t.date_50pct_vaccinated is null
                then 'Never reached 50%'
            when d.report_date < t.date_50pct_vaccinated
                then 'Pre-50%'
            else 'Post-50%'
        end                             as vax_phase
    from daily d
    left join vax_threshold t using (country_name)
),

agg as (
    select
        country_name,
        continent,
        vax_phase,
        sum(new_deaths)                 as deaths_in_phase,
        count(distinct report_date)     as days_in_phase,
        max(population)                 as population
    from joined
    group by country_name, continent, vax_phase
),

pivoted as (
    select
        country_name,
        max(continent)                  as continent,
        max(case when vax_phase = 'Pre-50%'  then deaths_in_phase end) as pre_deaths,
        max(case when vax_phase = 'Pre-50%'  then days_in_phase   end) as pre_days,
        max(case when vax_phase = 'Post-50%' then deaths_in_phase end) as post_deaths,
        max(case when vax_phase = 'Post-50%' then days_in_phase   end) as post_days,
        max(population)                 as population
    from agg
    group by country_name
)

select
    {{ dbt_utils.generate_surrogate_key(['country_name']) }}    as country_sk,
    country_name,
    continent,
    population,
    pre_deaths,
    pre_days,
    post_deaths,
    post_days,
    case
        when pre_days > 0 and population > 0
            then round(pre_deaths * 1000000.0 / (pre_days * population), 4)
    end                                 as pre_daily_deaths_per_million,
    case
        when post_days > 0 and population > 0
            then round(post_deaths * 1000000.0 / (post_days * population), 4)
    end                                 as post_daily_deaths_per_million
from pivoted
where pre_days  is not null
  and post_days is not null
