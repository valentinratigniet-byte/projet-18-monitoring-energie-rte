# Pièges vérifiés sur l'API ODRE Eco2mix (2026-08-29)

Testés en direct (`curl`, pas supposés depuis la doc) contre
`https://odre.opendatasoft.com/api/records/1.0/search/?dataset=eco2mix-national-tr`.

## 1. Le sens du tri est inversé par rapport à la convention Lucene

```
sort=date_heure    -> le plus RÉCENT en premier
sort=-date_heure   -> le plus ANCIEN en premier
```

L'inverse de ce à quoi on s'attend (`-champ` = décroissant, d'habitude).
Vérifié avec 10 lignes de chaque côté, comportement stable et reproductible.
`src/ingest.py` utilise `sort=date_heure` (sans préfixe) pour récupérer les
dernières mesures.

## 2. Les mesures récentes (~24h) sont incomplètes tant que RTE ne les a pas consolidées

Un enregistrement fraîchement publié n'a que 6 champs (`heure`,
`prevision_j1`, `perimetre`, `date`, `date_heure`, `nature`) — les champs de
mesure réelle (`consommation`, `eolien`, `nucleaire`, etc.) sont absents,
pas juste à zéro. Vérifié le 2026-08-29 : le premier enregistrement complet
en remontant l'historique se trouve à **~24h derrière la mesure la plus
récente**. RTE publie d'abord une prévision (`prevision_j1`), puis consolide
la valeur réelle environ un jour plus tard.

**Conséquence pour l'ingestion** : ce n'est pas un problème à corriger, c'est
un comportement à absorber par le design déjà en place. L'upsert idempotent
sur `date_heure` (`ON CONFLICT ... DO UPDATE`) rattrape automatiquement ces
lignes : chaque poll suivant qui retombe sur une `date_heure` déjà en base la
complète dès que RTE a publié la valeur consolidée, sans duplication ni
intervention. Documenté ici pour que la fenêtre de repoll (`--n`) dans
`src/ingest.py` reste assez large pour repasser sur les mesures encore
incomplètes des dernières 24h, pas seulement les tout derniers points.

**Conséquence pour le narratif "temps réel" du projet** : à assumer
explicitement dans le README/dashboard plutôt que cacher — la courbe des
dernières ~24h affichera des trous ou des valeurs de prévision tant que RTE
n'a pas consolidé, ce qui est le comportement réel de la source, pas un bug
du pipeline.
