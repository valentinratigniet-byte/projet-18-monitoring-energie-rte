-- =====================================================================
-- Projet 18 — Monitoring Eco2mix — schéma raw
-- Postgres local pour le développement (Docker, port 5435) ; même schéma
-- utilisable tel quel sur Supabase (Postgres géré) en production.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- eco2mix_national_tr : un point de mesure du mix énergétique français,
--   une ligne toutes les ~15 min (source : API ODRE, dataset
--   "eco2mix-national-tr", cf. src/ingest.py).
--   date_heure = clé de dédoublonnage (upsert idempotent, voir ingest.py) :
--   la même mesure peut être re-fetchée plusieurs fois sans dupliquer, et
--   une correction ultérieure de RTE écrase la version précédente.
-- ---------------------------------------------------------------------
CREATE TABLE eco2mix_national_tr (
    date_heure      TIMESTAMPTZ NOT NULL PRIMARY KEY,
    perimetre       TEXT        NOT NULL,
    nature          TEXT        NOT NULL,
    consommation    NUMERIC,
    eolien          NUMERIC,
    nucleaire       NUMERIC,
    hydraulique     NUMERIC,
    gaz             NUMERIC,
    bioenergies     NUMERIC,
    solaire         NUMERIC,
    charbon         NUMERIC,
    fioul           NUMERIC,
    taux_co2        NUMERIC,
    ech_physiques   NUMERIC,
    ingested_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- ingestion_log : un run de src/ingest.py = une ligne. Base de
--   l'alerting fraîcheur (dernier run_at récent = pipeline sain) et
--   réservée à l'admin en production (RLS, voir sql/02_rls.sql — les
--   rôles anon/authenticated n'existent qu'côté Supabase, pas en local).
-- ---------------------------------------------------------------------
CREATE TABLE ingestion_log (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    rows_fetched   INT         NOT NULL,
    status         TEXT        NOT NULL CHECK (status IN ('success', 'error')),
    error_message  TEXT
);

COMMIT;
