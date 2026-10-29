"""Inicializa sólo un proyecto sin esquema RutaAlerta. Nunca borra ni reinicializa."""
from config_local import BASE,cargar
import pg8000.dbapi
import secrets
import sys
from pathlib import Path
sys.path.insert(0,str(BASE))
from app.tls import contexto_tls

v=cargar()
conn=pg8000.dbapi.connect(host=v['DB_HOST'],port=int(v['DB_PORT']),database=v['DB_NAME'],user=v['DB_USER'],password=v['DB_PASSWORD'],ssl_context=contexto_tls(),timeout=30)
conn.autocommit=True
try:
    cur=conn.cursor()
    cur.execute("SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name='rutaalerta')")
    if cur.fetchone()[0]:raise SystemExit('Esquema existente: se detiene para no sobrescribir. Requiere revisar migraciones.')
    for nombre in ['01_Esquema_Completo_Supabase.sql','02_Catalogo_indicadores.sql','03_Datos_demo.sql','04_Identidad_MVP.sql']:
        cur.execute((BASE/'sql'/nombre).read_text(encoding='utf-8'))
        print('Cargado:',nombre)
    cur.execute("SELECT count(*) FROM information_schema.tables WHERE table_schema='rutaalerta' AND table_type='BASE TABLE'")
    tablas=cur.fetchone()[0]
    if tablas!=59:raise RuntimeError('El conteo no coincide con la migración')
    print('Esquema cargado:',tablas,'tablas físicas. Datos ficticios únicamente.')
finally:conn.close()
