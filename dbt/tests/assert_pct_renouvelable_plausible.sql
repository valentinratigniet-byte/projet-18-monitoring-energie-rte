-- Un test dbt passe quand la requête ne retourne AUCUNE ligne.
-- La part renouvelable peut ponctuellement dépasser 100% (export net
-- d'électricité) mais pas de façon extravagante : au-delà de 150% ou
-- en dessous de -50%, c'est un signe de calcul cassé, pas un vrai export.
select date_heure, pct_renouvelable
from {{ ref('mart_mix_energetique') }}
where pct_renouvelable > 150 or pct_renouvelable < -50
