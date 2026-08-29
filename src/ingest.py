"""
Ingestion Eco2mix — poll l'API ODRE (dataset `eco2mix-national-tr`, gratuite,
sans clé) et upsert les dernières mesures dans `eco2mix_national_tr`.

Piège vérifié le 2026-08-29 sur cette API opendatasoft v1 (curl direct, pas
supposé depuis la doc) : le sens du tri est INVERSÉ par rapport à la
convention Lucene habituelle —
  sort=date_heure   -> le plus RÉCENT en premier (ce qu'on veut ici)
  sort=-date_heure  -> le plus ANCIEN en premier
À revérifier si ODRE migre vers son API v2 (syntaxe différente).

Idempotent par construction (upsert sur la clé `date_heure`) : rejouer une
même fenêtre de 15 min plusieurs fois (retry n8n, chevauchement de
planning) ne crée jamais de doublon, et une correction ultérieure de RTE
écrase la version précédente — le risque identifié dans le cadrage
(issue #1) est traité dès cette première version, pas différé.

Usage : python src/ingest.py [--n 8]
"""
import argparse
import os

import psycopg2
import requests

API_URL = "https://odre.opendatasoft.com/api/records/1.0/search/"
DATASET = "eco2mix-national-tr"
DSN = os.environ.get("DATABASE_URL", "postgresql://portfolio:portfolio@127.0.0.1:5435/eco2mix")

COLUMNS = ["date_heure", "perimetre", "nature", "consommation", "eolien", "nucleaire",
           "hydraulique", "gaz", "bioenergies", "solaire", "charbon", "fioul",
           "taux_co2", "ech_physiques"]


def fetch_latest(n: int = 8) -> list:
    resp = requests.get(API_URL, params={"dataset": DATASET, "rows": n, "sort": "date_heure"}, timeout=15)
    resp.raise_for_status()
    return [r["fields"] for r in resp.json()["records"]]


def upsert(cur, rows: list) -> int:
    if not rows:
        return 0
    cols_sql = ", ".join(COLUMNS)
    placeholders = ", ".join(f"%({c})s" for c in COLUMNS)
    updates = ", ".join(f"{c} = EXCLUDED.{c}" for c in COLUMNS if c != "date_heure")
    sql = f"""
        INSERT INTO eco2mix_national_tr ({cols_sql})
        VALUES ({placeholders})
        ON CONFLICT (date_heure) DO UPDATE SET {updates}, ingested_at = now()
    """
    for row in rows:
        cur.execute(sql, {c: row.get(c) for c in COLUMNS})
    return len(rows)


def run(n: int = 8) -> int:
    rows = fetch_latest(n)
    conn = psycopg2.connect(DSN)
    cur = conn.cursor()
    count = upsert(cur, rows)
    conn.commit()
    cur.close(); conn.close()
    return count


def row_count() -> int:
    conn = psycopg2.connect(DSN); cur = conn.cursor()
    cur.execute("SELECT count(*) FROM eco2mix_national_tr")
    n = cur.fetchone()[0]
    cur.close(); conn.close()
    return n


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, default=8, help="nombre de dernières mesures à récupérer")
    args = parser.parse_args()

    fetched = run(args.n)
    total = row_count()
    print(f"{fetched} mesures récupérées, {total} lignes en base.")

    # Self-check idempotence : rejouer la même ingestion ne doit rien changer
    # (le risque exact identifié dans le cadrage, issue #1).
    run(args.n)
    total_after = row_count()
    assert total == total_after, (
        f"Idempotence cassée : {total} lignes avant ré-ingestion, {total_after} après"
    )
    print(f"Idempotence vérifiée : {total_after} lignes stables après ré-ingestion.")
