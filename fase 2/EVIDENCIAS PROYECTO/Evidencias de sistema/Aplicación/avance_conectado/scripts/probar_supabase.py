"""Pruebas reales contra el proyecto nuevo dedicado a demostración."""
from config_local import BASE,cargar
from pathlib import Path
from datetime import datetime,timezone
import subprocess
import sys
import os
import json
import importlib.metadata

v=cargar()
if v['DB_USER']!='postgres.fmqlijkowxxplltkjoey':raise SystemExit('Este ensayo requiere la cuenta de preparación de la base dedicada.')
out=BASE/'evidencias';out.mkdir(exist_ok=True)
args=[sys.executable,'-m','pytest','-x','-v','--tb=short','-p','no:cacheprovider','--junitxml='+str(out/'pytest_supabase.xml')]
with (out/'pytest_supabase.txt').open('wb') as log:
    r=subprocess.run(args,cwd=BASE,stdout=log,stderr=subprocess.STDOUT,timeout=480)
(out/'entorno_supabase.json').write_text(json.dumps({'fecha_utc':datetime.now(timezone.utc).isoformat(),'python':sys.version.split()[0],'motor':'PostgreSQL/PostGIS alojado en Supabase','proyecto':'fmqlijkowxxplltkjoey','TLS':'CA y hostname verificados','salida':r.returncode,'paquetes':{x:importlib.metadata.version(x) for x in ['fastapi','pg8000','pytest','httpx']},'nota':'Contactos simulados. Datos ficticios. No acredita usuarios reales, SMS, MFA ni carga concurrente.'},ensure_ascii=False,indent=2),encoding='utf-8')
print((out/'pytest_supabase.txt').read_text(encoding='utf-8',errors='replace')[-3500:])
raise SystemExit(r.returncode)
