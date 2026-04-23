with daily as (
    select * from {{ ref('int_country_daily') }}
),

agg as (
    select
        country_name,
        max(continent)              as continent,
        max(population)             as population,
        max(gdp_per_capita)         as gdp_per_capita,
        max(median_age)             as median_age,

        min(report_date)            as first_reported_date,
        max(report_date)            as last_reported_date,
        count(distinct report_date) as days_with_data,

        max(total_cases)            as peak_total_cases,
        max(total_deaths)           as peak_total_deaths,
        max(vaccinated_pct)         as peak_vaccinated_pct

    from daily
    group by country_name
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['country_name']) }} as country_sk,
        country_name,
        continent,

        case
            when gdp_per_capita is null  then 'Unknown'
            when gdp_per_capita <  4000  then 'Low income'
            when gdp_per_capita < 13000  then 'Lower-middle'
            when gdp_per_capita < 40000  then 'Upper-middle'
            else                              'High income'
        end                                                      as income_bucket,

        population,
        gdp_per_capita,
        median_age,

        first_reported_date,
        last_reported_date,
        days_with_data,

        peak_total_cases,
        peak_total_deaths,
        peak_vaccinated_pct,

        case
            when peak_total_cases > 0
                then round(peak_total_deaths * 100.0 / peak_total_cases, 4)
        end                                                      as case_fatality_rate_pct

    from agg
)

select * from final
