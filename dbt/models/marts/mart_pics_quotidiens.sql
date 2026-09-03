-- Une ligne = un jour, la mesure au pic de consommation de ce jour (heure
-- comprise) — DISTINCT ON garde la ligne de conso max par date_mesure.
select distinct on (date_mesure)
    date_mesure,
    date_heure   as heure_pic,
    heure_mesure as heure_pic_num,
    consommation as pic_consommation,
    pct_renouvelable as pct_renouvelable_au_pic
from {{ ref('mart_mix_energetique') }}
order by date_mesure, consommation desc
