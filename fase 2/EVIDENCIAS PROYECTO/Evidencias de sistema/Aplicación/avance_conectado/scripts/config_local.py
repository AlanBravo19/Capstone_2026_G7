"""Carga un archivo privado de variables como datos, nunca como código."""
from pathlib import Path
import os

BASE=Path(__file__).resolve().parents[1]
def cargar():
    p=BASE/'.env.local'
    if not p.exists():raise SystemExit('Falta .env.local privado')
    valores={}
    for linea in p.read_text(encoding='utf-8-sig').splitlines():
        if not linea.strip() or linea.lstrip().startswith('#') or '=' not in linea:continue
        k,v=linea.split('=',1);valores[k.strip()]=v.strip()
    if not valores.get('DB_PASSWORD'):raise SystemExit('DB_PASSWORD aún está vacío')
    os.environ.update(valores)
    return valores
