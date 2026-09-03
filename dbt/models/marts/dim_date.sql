-- Dimension date, de la première mesure ingérée à +2 ans (marge pour un
-- projet censé tourner en continu). Générée, pas copiée à la main.
with bounds as (
    select
        least(
            (select min(date_heure)::date from {{ source('raw', 'eco2mix_national_tr') }}),
            current_date
        ) as date_min,
        (current_date + interval '2 years')::date as date_max
)
select
    d::date                                as date,
    extract(year from d)::int              as annee,
    extract(quarter from d)::int           as trimestre,
    'Trimestre ' || extract(quarter from d)::text as nom_trimestre,
    extract(month from d)::int             as mois,
    initcap(to_char(d, 'TMMonth'))         as nom_mois,
    extract(day from d)::int               as jour,
    extract(isodow from d)::int            as jour_semaine_iso,  -- 1=lundi .. 7=dimanche
    initcap(to_char(d, 'TMDay'))           as nom_jour,
    extract(isodow from d) in (6, 7)       as est_weekend
from bounds, generate_series(bounds.date_min, bounds.date_max, interval '1 day') as d
