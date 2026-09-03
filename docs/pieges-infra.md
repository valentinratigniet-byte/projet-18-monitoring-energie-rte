# Pièges infra rencontrés (VPS/Coolify/n8n/Supabase) — 2026-09-03

Trois problèmes réels, chacun avec sa cause exacte identifiée avant
correction (pas de solution appliquée à l'aveugle).

## 1. HTTPS Coolify : le formulaire "Domains" ne persiste pas toujours

Passer un service (n8n, Metabase) de `http://` à `https://` via l'onglet
"Domains" de Coolify a échoué silencieusement à plusieurs reprises — la
valeur restait `http://` en base (`service_applications.fqdn`, vérifié
directement dans `coolify-db`). Cause exacte non identifiée côté UI.

**Contournement** : correction directe du `fqdn` en base + régénération
manuelle des labels Traefik (routeur `https-...`, `tls.certresolver=letsencrypt`)
dans `docker-compose.yml` du service, puis `docker compose up -d --force-recreate`.

**Piège n°2 associé** : même après ça, Traefik continuait à servir son
certificat par défaut alors que Let's Encrypt avait bien émis le vrai
certificat (vérifié dans `acme.json`, présent). Le process Traefik en cours
n'avait pas rechargé le store. Un `docker restart coolify-proxy` (après
avoir confirmé le certificat présent dans `acme.json`, pas avant) résout.

## 2. Connexion Supabase directe : IPv6 injoignable depuis le VPS

La connexion directe (`db.<projet>.supabase.co:5432`) résout vers une
adresse IPv6. Fonctionne depuis un poste qui a l'IPv6 (testé en local), mais
le réseau Docker du VPS n'a pas de sortie IPv6 → `ENETUNREACH` depuis le
conteneur n8n.

**Solution** : utiliser le **connection pooler** Supabase
(`aws-0-<region>.pooler.supabase.com:5432`, utilisateur au format
`postgres.<projet-ref>`) — il répond en IPv4. C'est la recommandation
officielle de Supabase pour tout environnement sans IPv6 sortant, pas un
contournement bricolé.

## 3. Node Postgres n8n : certificat auto-signé rejeté même en mode `require`

Avec `ssl: require` (ou `allow`), le driver `pg` utilisé par le nœud
Postgres de n8n valide quand même la chaîne de certificat par défaut —
contrairement à `libpq`/`psycopg2` où `require` signifie "chiffré, sans
vérification". Résultat : `self-signed certificate in certificate chain`
même avec une vraie connexion Supabase valide.

Le champ attendu par l'API publique de n8n pour désactiver cette
vérification (`allowUnauthorizedCerts`) a été rejeté par le schéma de
validation à `true` (accepté à `false` seulement — comportement non
élucidé, plusieurs combinaisons testées côté API sans succès). **Résolu
via l'interface n8n** : éditer le credential Postgres directement dans
l'UI (nœud → crédential → icône crayon) et activer l'option SSL
équivalente ("Ignore SSL Issues"/"Reject Unauthorized") — l'UI a accès
au bon schéma pour la version de n8n installée, l'API publique semble en
retard ou différente sur ce point précis pour ce champ.

**Leçon générale** : quand l'API publique d'un outil se comporte de façon
non documentée sur un champ précis, basculer sur l'UI plutôt que de
multiplier les tentatives à l'aveugle — l'UI est toujours la source de
vérité la plus à jour du schéma réel.
