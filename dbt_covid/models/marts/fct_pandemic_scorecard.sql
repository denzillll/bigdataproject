-- fct_pandemic_scorecard
--
-- Composite ranking of every country's overall pandemic management performance.
-- Scores each country across 5 dimensions, each normalised 0-100:
--
--   1. Mortality control     — how low was the CFR relative to other countries
--   2. Vaccination speed     — how quickly did the country vaccinate its population
--   3. Healthcare capacity   — GDP per capita as proxy for system capacity
--   4. Response speed        — how quickly did the country reach its peak after spread began
--   5. Early containment     — how slowly did cases grow in the first 14 days
--
-- Final score = weighted average. Higher = better pandemic management.
-- Intended use: identify what separates high-performing from low-performing
-- countries so health systems can prioritise the right investments.

with country as (
    select * from {{ ref('dim_country') }}
    where continent is not null
),

vulnerability as (
    select
        country_name,
        vulnerability_score,
        vulnerability_tier
    from {{ ref('fct_country_vulnerability_index') }}
),

response as (
    select
        country_name,
        days_first_to_peak,
        response_speed_bucket
    from {{ ref('fct_wave_response_speed') }}
),

early_warning as (
    select
        country_name,
        growth_multiplier_14d,
        initial_spread_tier
    from {{ ref('fct_early_warning_signals') }}
),

vaccination as (
    select
        country_name,
        pre_daily_deaths_per_million,
        post_daily_deaths_per_million
    from {{ ref('fct_vaccination_impact') }}
),

combined as (
    select
        c.country_name,
        c.continent,
        c.income_bucket,
        c.population,
        c.gdp_per_capita,
        c.median_age,
        c.peak_vaccinated_pct,
        c.case_fatality_rate_pct,
        c.days_with_data,

        v.vulnerability_score,
        v.vulnerability_tier,

        r.days_first_to_peak,
        r.response_speed_bucket,

        e.growth_multiplier_14d,
        e.initial_spread_tier,

        vax.pre_daily_deaths_per_million,
        vax.post_daily_deaths_per_million

    from country c
    left join vulnerability  v   using (country_name)
    left join response       r   using (country_name)
    left join early_warning  e   using (country_name)
    left join vaccination    vax using (country_name)
),

scored as (
    select
        *,

        -- 1. Mortality control (lower CFR = better score)
        round((1 - percent_rank() over (
            order by case_fatality_rate_pct asc nulls last
        )) * 100, 1)                                        as mortality_score,

        -- 2. Vaccination reach (higher vaccination % = better score)
        round(percent_rank() over (
            order by coalesce(peak_vaccinated_pct, 0) asc
        ) * 100, 1)                                         as vaccination_score,

        -- 3. Healthcare capacity (higher GDP = better score)
        round(percent_rank() over (
            order by coalesce(gdp_per_capita, 0) asc
        ) * 100, 1)                                         as capacity_score,

        -- 4. Response speed (fewer days to peak = better score)
        round((1 - percent_rank() over (
            order by coalesce(days_first_to_peak, 999) asc
        )) * 100, 1)                                        as response_score,

        -- 5. Early containment (lower growth multiplier = better score)
        round((1 - percent_rank() over (
            order by coalesce(growth_multiplier_14d, 999) asc
        )) * 100, 1)                                        as containment_score

    from combined
),

final as (
    select
        country_name,
        continent,
        income_bucket,
        population,
        gdp_per_capita,
        median_age,
        peak_vaccinated_pct,
        case_fatality_rate_pct,

        mortality_score,
        vaccination_score,
        capacity_score,
        response_score,
        containment_score,

        vulnerability_score,
        vulnerability_tier,
        days_first_to_peak,
        response_speed_bucket,
        growth_multiplier_14d,
        initial_spread_tier,
        pre_daily_deaths_per_million,
        post_daily_deaths_per_million,

        -- Weighted composite pandemic management score
        round(
            mortality_score    * 0.30 +
            vaccination_score  * 0.25 +
            capacity_score     * 0.20 +
            response_score     * 0.15 +
            containment_score  * 0.10
        , 1)                                                as pandemic_score,

        -- Tier based on composite score
        case
            when (mortality_score * 0.30 + vaccination_score * 0.25 +
                  capacity_score  * 0.20 + response_score    * 0.15 +
                  containment_score * 0.10) >= 75 then 'Excellent'
            when (mortality_score * 0.30 + vaccination_score * 0.25 +
                  capacity_score  * 0.20 + response_score    * 0.15 +
                  containment_score * 0.10) >= 50 then 'Good'
            when (mortality_score * 0.30 + vaccination_score * 0.25 +
                  capacity_score  * 0.20 + response_score    * 0.15 +
                  containment_score * 0.10) >= 25 then 'Poor'
            else 'Critical'
        end                                                 as pandemic_tier

    from scored
)

select * from final
order by pandemic_score desc nulls last
