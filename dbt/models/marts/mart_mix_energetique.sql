-- Une ligne = une mesure consolidée, avec la part de chaque grande
-- famille de production dans la consommation du moment.
select
    date_heure,
    date_mesure,
    heure_mesure,
    consommation,
    production_renouvelable,
    round(100.0 * production_renouvelable / nullif(consommation, 0), 1) as pct_renouvelable,
    nucleaire,
    round(100.0 * nucleaire / nullif(consommation, 0), 1)               as pct_nucleaire,
    taux_co2
from {{ ref('stg_eco2mix') }}
