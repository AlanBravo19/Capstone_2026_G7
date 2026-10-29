"""Restaura sólo la credencial ficticia guardada tras pruebas que la cambian."""
from config_local import BASE,cargar
import re
import sys
v=cargar()
sys.path.insert(0,str(BASE))
from app.db import conectar
from app.seguridad import cifrar_clave
texto=(BASE/'ACCESO_DEMO_PRIVADO.txt').read_text(encoding='utf-8')
clave=re.search(r'^Contraseña: (.+)$',texto,flags=re.M).group(1)
c=conectar()
try:
    c.cursor().execute("UPDATE usuario SET password_hash=%s WHERE correo_normalizado='operador@example.invalid'",(cifrar_clave(clave),))
    c.commit()
    print('Credencial del operador ficticio restaurada; no se modificaron cuentas reales.')
finally:c.close()
