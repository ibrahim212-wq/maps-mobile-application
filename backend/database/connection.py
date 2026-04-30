import os
from contextlib import contextmanager

import psycopg2
from dotenv import load_dotenv

load_dotenv()


def _db_config() -> dict:
    return {
        "host": os.getenv("DB_HOST", "localhost"),
        "port": int(os.getenv("DB_PORT", "5432")),
        "user": os.getenv("DB_USER", "postgres"),
        "password": os.getenv("DB_PASSWORD", ""),
        "dbname": os.getenv("DB_NAME", "postgres"),
    }


@contextmanager
def get_connection():
    conn = psycopg2.connect(**_db_config())
    try:
        yield conn
    finally:
        conn.close()


def check_db_connection() -> bool:
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                cur.fetchone()
        return True
    except Exception:
        return False
