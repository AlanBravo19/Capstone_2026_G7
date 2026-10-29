// Servidor PostgreSQL de prueba en memoria (PGlite + PostGIS) para ejecutar las pruebas sin instalar PostgreSQL.
// Uso: node servidor_prueba_pglite.mjs <carpeta_sql> [puerto]
// Carga el script completo, el catálogo de indicadores y los datos ficticios. No usar con datos reales.
import { PGlite } from '@electric-sql/pglite';
import { postgis } from '@electric-sql/pglite-postgis';
import { PGLiteSocketServer } from '@electric-sql/pglite-socket';
import fs from 'node:fs';
import path from 'node:path';

const [sqlDir, puerto = '54329'] = process.argv.slice(2);
const db = new PGlite({ extensions: { postgis } });
for (const f of ['01_Esquema_Completo_Supabase.sql', '02_Catalogo_indicadores.sql', '03_Datos_demo.sql', '04_Identidad_MVP.sql']) {
  await db.exec(fs.readFileSync(path.join(sqlDir, f), 'utf8'));
  console.log('cargado', f);
}
// Las conexiones comparten un único motor PGlite: usar sólo para pruebas secuenciales.
const server = new PGLiteSocketServer({ db, port: Number(puerto), host: '127.0.0.1', maxConnections: 20, idleTimeout: 5000 });
await server.start();
console.log(`LISTO: PostgreSQL de prueba en 127.0.0.1:${puerto} (usuario postgres, base postgres)`);
