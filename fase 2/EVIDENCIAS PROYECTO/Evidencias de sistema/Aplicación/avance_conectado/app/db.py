"""Conexión a PostgreSQL/PostGIS. Cada solicitud usa su propia transacción."""
import psycopg
from pathlib import Path
import time

from .config import config


ErrorBD=psycopg.DatabaseError

def es_unico(e):
    return getattr(e,'sqlstate',None)=='23505'


def conectar():
    for intento in range(2):
        conn=None
        try:
            conn = psycopg.connect(
                host=config.db_host, port=config.db_port, dbname=config.db_name,
                user=config.db_user, password=config.db_password or None, connect_timeout=10,
                sslmode='verify-full' if config.db_ssl else 'disable',
                sslrootcert=str(Path(__file__).resolve().parents[1]/'certs/prod-ca-2021.crt') if config.db_ssl else None,
                prepare_threshold=None,
                options='-c statement_timeout=15000 -c lock_timeout=5000',
            )
            cur = conn.cursor()
            cur.execute("SET search_path TO rutaalerta, public, extensions")
            cur.close()
            conn.commit()
            return conn
        except psycopg.OperationalError:
            if conn is not None:conn.close()
            if intento:raise
            # Sólo se reintenta la inicialización, antes de ejecutar operaciones de negocio.
            time.sleep(.25)


def obtener_conexion():
    """Dependencia de FastAPI: confirma si la solicitud termina bien y revierte si falla."""
    conn = conectar()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def fila_dict(cur, fila):
    if fila is None:
        return None
    return {d[0]: v for d, v in zip(cur.description, fila)}
