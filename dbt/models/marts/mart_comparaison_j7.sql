-- Compare chaque mesure à la même heure, 7 jours plus tôt — la comparaison
-- J/J-7 (même jour de semaine) est plus lisible que J/J-1 pour la conso
-- électrique, qui a un cycle hebdomadaire marqué (semaine vs week-end).
select
    a.date_heure,
    a.date_heure::date                                                    as date_mesure,
    a.consommation                                                        as consommation_actuelle,
    b.consommation                                                        as consommation_j7,
    round(a.consommation - b.consommation, 0)                             as ecart_absolu,
    round(100.0 * (a.consommation - b.consommation) / nullif(b.consommation, 0), 1) as variation_pct
from {{ ref('stg_eco2mix') }} a
left join {{ ref('stg_eco2mix') }} b
    on b.date_heure = a.date_heure - interval '7 days'
