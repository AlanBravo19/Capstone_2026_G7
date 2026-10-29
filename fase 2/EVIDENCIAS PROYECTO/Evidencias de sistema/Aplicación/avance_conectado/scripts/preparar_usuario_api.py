"""Usuario limitado y credenciales ficticias del operador. No imprime secretos."""
from config_local import BASE,cargar
import pg8000.dbapi
import secrets
import sys
sys.path.insert(0,str(BASE))
from app.tls import contexto_tls
from app.seguridad import cifrar_clave
from app.db import conectar

v=cargar()
dest=BASE/'.env.runtime.local'
if dest.exists():raise SystemExit('La configuración de ejecución ya existe; no se rotan credenciales automáticamente.')
conn=conectar()
try:
    cur=conn.cursor()
    cur.execute("SELECT 1 FROM pg_roles WHERE rolname='ra_api'")
    if cur.fetchone():raise SystemExit('El rol ra_api ya existe: revisar antes de cambiar sus permisos.')
    password=secrets.token_urlsafe(40)
    # token_urlsafe no contiene comillas; el nombre del rol es constante, no entrada del usuario.
    cur.execute("CREATE ROLE ra_api LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD '"+password+"'")
    cur.execute('GRANT CONNECT ON DATABASE postgres TO ra_api')
    cur.execute('GRANT USAGE ON SCHEMA rutaalerta, extensions TO ra_api')
    cur.execute('GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA rutaalerta TO ra_api')
    cur.execute('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA rutaalerta TO ra_api')
    cur.execute('GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA rutaalerta TO ra_api')
    cur.execute('REVOKE ALL ON SCHEMA rutaalerta FROM anon, authenticated')
    cur.execute('REVOKE ALL ON ALL TABLES IN SCHEMA rutaalerta FROM anon, authenticated')
    cur.execute('REVOKE ALL ON ALL SEQUENCES IN SCHEMA rutaalerta FROM anon, authenticated')
    admin=secrets.token_urlsafe(22)
    cur.execute("UPDATE rutaalerta.usuario SET password_hash=%s WHERE correo_normalizado='operador@example.invalid'",(cifrar_clave(admin),))
    conn.commit()
    ref='fmqlijkowxxplltkjoey'
    runtime={**v,'DB_USER':'ra_api.'+ref,'DB_PASSWORD':password}
    dest.write_text('\n'.join(k+'='+val for k,val in runtime.items())+'\n',encoding='utf-8')
    (BASE/'ACCESO_DEMO_PRIVADO.txt').write_text('ACCESO DE ENSAYO - NO SUBIR A GITHUB\n\nClave de acceso a la demostración: '+v['DEMO_ACCESS_KEY']+'\n\nOperador ficticio de demostración:\nCorreo: operador@example.invalid\nContraseña: '+admin+'\n\nNo son credenciales de Carabineros ni de una municipalidad. No usar datos reales.\n',encoding='utf-8')
    print('Usuario limitado y acceso privado de ensayo preparados. Secretos guardados solo en archivos excluidos de Git.')
finally:conn.close()
