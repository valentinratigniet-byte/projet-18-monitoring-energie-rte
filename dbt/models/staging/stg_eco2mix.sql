-- Ne garde que les mesures consolidées par RTE (consommation non nulle) :
-- les points des ~24h les plus récentes n'ont qu'une prévision, pas encore
-- de mesure réelle (cf. docs/pieges-api-rte.md à la racine du repo) — les
-- exclure ici évite de les propager silencieusement dans les marts.
select
    date_heure,
    date_heure::date                       as date_mesure,
    extract(hour from date_heure)::int     as heure_mesure,
    extract(dow from date_heure)::int      as jour_semaine,   -- 0=dimanche
    consommation,
    eolien,
    nucleaire,
    hydraulique,
    gaz,
    bioenergies,
    solaire,
    charbon,
    fioul,
    taux_co2,
    ech_physiques,
    coalesce(eolien, 0) + coalesce(solaire, 0)
        + coalesce(hydraulique, 0) + coalesce(bioenergies, 0)  as production_renouvelable
from {{ source('raw', 'eco2mix_national_tr') }}
where consommation is not null
