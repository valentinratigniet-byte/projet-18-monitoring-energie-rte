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

## 3. Les premières lignes de l'API sont des créneaux sans mesure (panne du 02/10 au 19/10/2026)

Le 19/10/2026, l'API publiait des créneaux jusqu'au **20/10 21:45**, tous sans
`consommation` : les créneaux du lendemain, en prévision. La dernière vraie
mesure datait du 19/10 18:30. Le workflow n8n demandait les **8 premières
lignes** : il ne récupérait que des créneaux vides, et le tableau de bord est
resté figé sur la dernière mesure reçue, le 02/10 05:30 (le moment exact de
la rupture n'est pas connu sans le journal `ingestion_log`).

**L'alerte n'a rien vu** : le contrôle de fraîcheur portait sur `ingested_at`,
la date d'écriture, que chaque upsert de lignes vides remettait à jour.

**Corrigé** :
- l'API est interrogée avec `q=consommation>0` (16 lignes) : elle ne renvoie
  que des mesures réelles, quel que soit l'horizon des prévisions ;
- la fraîcheur dbt porte sur `date_heure` des lignes où `consommation` est
  renseignée (alerte à 2 h, échec à 6 h) : ce qu'on veut savoir, c'est si des
  mesures arrivent, pas si on écrit ;
- le trou a été comblé par le workflow manuel `rattrapage.yml` (2 000 mesures).

Leçon : une alerte doit surveiller le résultat attendu (des mesures récentes),
pas l'activité du pipeline (des écritures récentes).
