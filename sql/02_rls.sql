-- =====================================================================
-- Projet 18 — Gouvernance : RLS appliquée en base, pas juste documentée
-- (contrairement au Projet 11, où le lignage/gouvernance était uniquement
-- de la doc — ici les rôles sont réels et testés).
--
-- Spécifique à Supabase (utilise les rôles managés `anon`/`authenticated`,
-- qui n'existent pas sur le Postgres local de dev) — à appliquer sur le
-- projet Supabase uniquement, après sql/01_schema.sql.
--
-- Rôle `public` (anon + authenticated Supabase) : lecture des mesures
--   nationales agrégées uniquement — jamais les métadonnées d'ingestion.
-- Rôle admin (service_role / superuser, utilisé par le pipeline backend) :
--   accès complet, y compris les logs d'ingestion.
-- =====================================================================

ALTER TABLE eco2mix_national_tr ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingestion_log ENABLE ROW LEVEL SECURITY;

-- --- eco2mix_national_tr : lecture publique des mesures, pas du reste ---

-- RLS = filtre de LIGNES : toutes les lignes sont "France" agrégée, donc
-- la politique autorise tout (pas de filtre régional aujourd'hui — prêt à
-- restreindre si une source régionale est ajoutée plus tard, cf. réservoir
-- d'extensions de l'issue #1).
CREATE POLICY public_read_measures ON eco2mix_national_tr
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- RLS ne filtre pas les COLONNES : `ingested_at` (métadonnée opérationnelle,
-- pas une mesure) est retirée explicitement par un grant colonne par
-- colonne — défense en profondeur, pas seulement la policy ci-dessus.
REVOKE SELECT ON eco2mix_national_tr FROM anon, authenticated;
GRANT SELECT (
    date_heure, perimetre, nature, consommation, eolien, nucleaire,
    hydraulique, gaz, bioenergies, solaire, charbon, fioul,
    taux_co2, ech_physiques
) ON eco2mix_national_tr TO anon, authenticated;

-- --- ingestion_log : aucun accès public, admin uniquement ---
-- Aucune policy pour anon/authenticated => refus par défaut (RLS activée).
-- Révocation explicite du grant table par défaut de Supabase, pour ne pas
-- dépendre uniquement du comportement "deny by default" de la policy.
REVOKE ALL ON ingestion_log FROM anon, authenticated;
