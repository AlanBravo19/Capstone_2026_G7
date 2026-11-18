"""Conserva salida auténtica, código de retorno y reporte JUnit de la ejecución."""
from pathlib import Path
import subprocess
import sys
import json
import platform
from datetime import datetime, timezone
import importlib.metadata

base=Path(__file__).resolve().parents[1]
e=base/'evidencias';e.mkdir(exist_ok=True)
comando=[sys.executable,'-m','pytest','-v','--tb=short','-p','no:cacheprovider',f'--junitxml={e / "pytest_mvp.xml"}']
r=subprocess.run(comando,cwd=base,capture_output=True)
(e/'pytest_mvp.txt').write_bytes(r.stdout+b'\n'+r.stderr)
print(r.stdout.decode(errors='replace'))
info={'fecha_utc':datetime.now(timezone.utc).isoformat(),'python':platform.python_version(),'sistema':platform.platform(),
      'motor':'PGlite 0.5.8 + PostGIS 0.2.8 + socket 0.2.13 (memoria, secuencial)',
      'paquetes':{n:importlib.metadata.version(n) for n in ['fastapi','pg8000','pytest','httpx','uvicorn']},
      'codigo_salida':r.returncode,'comando':'python -m pytest -v --tb=short -p no:cacheprovider --junitxml=../evidencias/pytest_mvp.xml',
      'limites':'No prueba concurrencia multiproceso, PostgreSQL nativo, envío real, MFA ni interfaz Flutter/React.'}
(e/'entorno_pruebas.json').write_text(json.dumps(info,ensure_ascii=False,indent=2),encoding='utf-8')
if r.returncode:raise SystemExit(r.returncode)
raise SystemExit(subprocess.call([sys.executable,str(base/'scripts/demostrar.py')],cwd=base))
