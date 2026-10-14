import {PGlite} from '@electric-sql/pglite';
import {postgis} from '@electric-sql/pglite-postgis';
import fs from 'node:fs';
const db=new PGlite({extensions:{postgis}});
try {
 for(const f of ['RutaAlerta_PostgreSQL_Completo.sql','06_Catalogo_indicadores.sql','03_Datos_demo.sql','05_Consultas_espaciales.sql']) {
  await db.exec(fs.readFileSync(new URL('../sql/'+f,import.meta.url),'utf8'));
  console.log('Correcto:',f);
 }
 const result=await db.exec(fs.readFileSync(new URL('../sql/04_Pruebas_integridad.sql',import.meta.url),'utf8'));
 const pruebas=result.flatMap(r=>r.rows??[]).filter(r=>r.prueba);
 if(pruebas.length!==36 || pruebas.some(p=>p.resultado!=='CORRECTO')) throw Error('Resultado de pruebas incompleto');
 console.table(pruebas);
 console.log('36 pruebas correctas. Entorno de verificación WASM; no prueba despliegue nativo.');
} catch(e) {console.error(e.message);process.exitCode=1;}
finally {await db.close();}
