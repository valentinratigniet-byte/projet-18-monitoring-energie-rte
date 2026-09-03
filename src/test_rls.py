"""
Preuve que la RLS marche vraiment (pas juste déclarée) : on se place dans
la peau des rôles anon/authenticated (`SET ROLE`, valide seulement sur
Supabase — ces rôles n'existent pas sur le Postgres local de dev) et on
vérifie ce qu'ils voient réellement.

Usage : DATABASE_URL=<connexion Supabase, superuser> python src/test_rls.py
"""
import os

import psycopg2

DSN = os.environ["DATABASE_URL"]


def check(role: str, query: str, expect_ok: bool) -> bool:
    conn = psycopg2.connect(DSN, connect_timeout=15)
    cur = conn.cursor()
    cur.execute(f"SET ROLE {role};")
    try:
        cur.execute(query)
        cur.fetchall()
        ok = True
    except Exception:
        ok = False
    finally:
        cur.close(); conn.close()
    passed = ok == expect_ok
    print(f"[{'PASS' if passed else 'FAIL'}] rôle={role:14s} attendu={'OK' if expect_ok else 'REFUS'} -> "
          f"{'OK' if ok else 'REFUS'}  ({query})")
    return passed


CASES = [
    ("anon", "SELECT date_heure, consommation, eolien FROM eco2mix_national_tr LIMIT 3;", True),
    ("anon", "SELECT ingested_at FROM eco2mix_national_tr LIMIT 1;", False),
    ("anon", "SELECT * FROM eco2mix_national_tr LIMIT 1;", False),
    ("anon", "SELECT * FROM ingestion_log LIMIT 1;", False),
    ("authenticated", "SELECT date_heure, consommation FROM eco2mix_national_tr LIMIT 3;", True),
    ("authenticated", "SELECT * FROM ingestion_log LIMIT 1;", False),
]

if __name__ == "__main__":
    results = [check(role, query, expected) for role, query, expected in CASES]
    assert all(results), "Au moins un cas RLS ne se comporte pas comme attendu"
    print(f"\n{len(results)}/{len(results)} cas RLS conformes.")
