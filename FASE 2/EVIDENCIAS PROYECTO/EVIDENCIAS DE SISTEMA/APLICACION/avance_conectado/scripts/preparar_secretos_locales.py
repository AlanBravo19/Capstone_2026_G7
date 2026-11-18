"""Genera sólo secretos de la demo; nunca muestra contraseñas ni los sube al repositorio."""
from pathlib import Path
import secrets
dest=Path(__file__).resolve().parents[1]/'.env.local'
if dest.exists():raise SystemExit('El archivo ya existe. No se sobrescribe.')
dest.write_text('''# Completa solo DB_PASSWORD con la contraseña que elegiste al crear Supabase.
# Este archivo es privado, está ignorado por Git y no debe compartirse.
DB_HOST=aws-0-us-east-1.pooler.supabase.com
DB_PORT=5432
DB_NAME=postgres
DB_USER=postgres.fmqlijkowxxplltkjoey
DB_PASSWORD=
DB_SSL=1
ENTORNO=prueba
CANALES_DEMO=1
OTP_SECRET='''+secrets.token_urlsafe(48)+'\nDEMO_ACCESS_KEY='+secrets.token_urlsafe(32)+'\n',encoding='utf-8')
print('Archivo privado creado. Completa DB_PASSWORD sin enviarlo al chat.')
