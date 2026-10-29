"""Verificación completa del certificado y hostname de Supabase."""
import ssl
from pathlib import Path

def contexto_tls():
    contexto=ssl.create_default_context()
    contexto.load_verify_locations(cafile=str(Path(__file__).resolve().parents[1]/'certs/prod-ca-2021.crt'))
    return contexto
