-- =====================================================================
-- Projet 18 — Accès public aux marts (frontend GitHub Pages)
--
-- Les 3 marts dbt sont déjà des vues "public-safe" par construction : pas
-- de colonne d'ingestion/métadonnée, seulement des mesures agrégées (même
-- discipline que sql/02_rls.sql pour la table brute). Contrairement à une
-- table, une vue Postgres n'hérite pas automatiquement d'un GRANT — il
-- faut l'accorder explicitement à la vue elle-même, même si son SELECT
-- interne lit une table où anon/authenticated n'ont qu'un accès restreint
-- (la vue s'exécute avec les droits de son propriétaire, pas du rôle
-- appelant — comportement standard Postgres, pas une faille).
-- =====================================================================

GRANT USAGE ON SCHEMA public TO anon, authenticated;

GRANT SELECT ON mart_mix_energetique TO anon, authenticated;
GRANT SELECT ON mart_pics_quotidiens TO anon, authenticated;
GRANT SELECT ON mart_comparaison_j7 TO anon, authenticated;
