"""Configuración leída desde variables de entorno (ver .env.example)."""
import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Config:
    db_host: str = os.getenv("DB_HOST", "127.0.0.1")
    db_port: int = int(os.getenv("DB_PORT", "5432"))
    db_name: str = os.getenv("DB_NAME", "rutaalerta_demo")
    db_user: str = os.getenv("DB_USER", "postgres")
    db_password: str = os.getenv("DB_PASSWORD", "")
    sesion_horas: int = int(os.getenv("SESION_HORAS", "12"))
    recuperacion_minutos: int = int(os.getenv("RECUPERACION_MINUTOS", "30"))
    # Sólo en entorno de prueba se devuelve el token de recuperación en la respuesta;
    # en operación debe enviarse por correo y nunca exponerse.
    entorno: str = os.getenv("ENTORNO", "prueba")


config = Config()
