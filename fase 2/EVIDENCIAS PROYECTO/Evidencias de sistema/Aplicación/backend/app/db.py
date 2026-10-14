"""Conexión a PostgreSQL/PostGIS. Cada solicitud usa su propia transacción."""
import pg8000.dbapi

from .config import config


def conectar():
    conn = pg8000.dbapi.connect(
        host=config.db_host, port=config.db_port, database=config.db_name,
        user=config.db_user, password=config.db_password or None,
    )
    cur = conn.cursor()
    cur.execute("SET search_path TO rutaalerta, public")
    cur.close()
    conn.commit()
    return conn


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
