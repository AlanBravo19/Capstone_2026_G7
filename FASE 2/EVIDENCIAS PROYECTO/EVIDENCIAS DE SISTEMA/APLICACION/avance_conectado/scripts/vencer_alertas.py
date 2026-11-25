"""Procesa vencimientos desde un entorno ya configurado con el rol de servicio."""
from pathlib import Path
import os
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from app.db import conectar
from app.routers.alertas import procesar_vencimientos

if __name__=='__main__':
    if not {'DB_HOST','DB_PORT','DB_NAME','DB_USER','ENTORNO'} <= os.environ.keys():
        raise SystemExit('Configura el destino y el rol de servicio antes de ejecutar el trabajo.')
    with conectar() as conn:
        cantidad=procesar_vencimientos(conn.cursor())
    print(f'Vencimientos procesados: {cantidad}')
