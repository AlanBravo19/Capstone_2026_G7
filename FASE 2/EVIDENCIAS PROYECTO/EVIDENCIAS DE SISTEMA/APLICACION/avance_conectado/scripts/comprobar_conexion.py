"""Una conexión, sin imprimir secretos ni datos de usuarios."""
from config_local import cargar
import pg8000.dbapi
import ssl
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from app.tls import contexto_tls
v=cargar()
try:
    conn=pg8000.dbapi.connect(host=v['DB_HOST'],port=int(v['DB_PORT']),database=v['DB_NAME'],user=v['DB_USER'],password=v['DB_PASSWORD'],ssl_context=contexto_tls(),timeout=12)
    cur=conn.cursor();cur.execute("SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name='rutaalerta')")
    print('CONEXIÓN CORRECTA. Esquema RutaAlerta existente:',cur.fetchone()[0]);conn.close()
except Exception as e:
    estado=e.args[0].get('C') if e.args and isinstance(e.args[0],dict) else None
    if estado=='28P01':print('CONTRASEÑA RECHAZADA por Supabase. No se modificó nada.')
    elif isinstance(e,ssl.SSLCertVerificationError):print('CERTIFICADO NO VERIFICADO:',e.verify_message)
    else:print('NO SE PUDO CONECTAR. Tipo:',type(e).__name__,'SQLSTATE:',estado or 'no disponible')
    raise SystemExit(1)
