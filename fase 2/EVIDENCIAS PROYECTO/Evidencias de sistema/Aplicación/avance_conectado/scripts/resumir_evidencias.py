"""Resumen derivado de resultados observados, sin inventar una ejecución única."""
from pathlib import Path
from datetime import datetime,timezone
import json,re,importlib.metadata

base=Path(__file__).resolve().parents[1]
e=base/'evidencias'
parcial=(e/'pytest_supabase.txt').read_text(encoding='utf-8',errors='replace')
restantes=(e/'pytest_supabase_restantes.txt').read_text(encoding='utf-8',errors='replace')
a=set(re.findall(r'(tests/[^\s]+::test_[^\s]+) PASSED',parcial))
b=set(re.findall(r'(tests/[^\s]+::test_[^\s]+) PASSED',restantes))
http=json.loads((e/'prueba_http_vercel.json').read_text(encoding='utf-8'))
assert len(a)==18 and len(b)==7 and len(a|b)==25
assert '7 passed' in restantes and len(http['resultados'])==15 and all(x['correcto'] for x in http['resultados'])
res={'fecha_resumen_utc':datetime.now(timezone.utc).isoformat(),'sitio':http['url'],
     'ejecucion_unica_de_suite_completa':False,'primer_lote_parcial_aprobados':len(a),
     'segundo_lote_completo_aprobados':len(b),'escenarios_distintos_cubiertos':len(a|b),
     'escenarios':sorted(a|b),'verificaciones_http_publicas_aprobadas':15,
     'psycopg':importlib.metadata.version('psycopg'),
     'limitacion':'Primera ejecución parcial detenida por tiempo máximo. Siete casos restantes verificados en lote separado. Correo/SMS simulados; no se acredita una identidad civil ni un sistema final.'}
(e/'resumen_verificacion.json').write_text(json.dumps(res,ensure_ascii=False,indent=2),encoding='utf-8')
print('Verificado: 18 + 7 escenarios distintos; 15 operaciones HTTP. No se declara una suite única completa.')
