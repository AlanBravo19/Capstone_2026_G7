import {PGlite} from '@electric-sql/pglite';
import {postgis} from '@electric-sql/pglite-postgis';
import fs from 'node:fs'; import path from 'node:path'; import os from 'node:os';
const sqlDir = process.argv[2], outDir = process.argv[3], mode = process.argv[4] || 'completo';
const log = []; const t0 = Date.now();
const db = new PGlite({extensions:{postgis}});
const q = async s => (await db.query(s)).rows;
const res = {fecha_ejecucion: new Date().toISOString(), modo: mode, host: {os: `${os.type()} ${os.release()} ${os.arch()}`, cpu: os.cpus()[0]?.model, node: process.version}, pasos: [], pruebas: []};
try {
  const files = mode === 'modular'
    ? ['01_Esquema_PostgreSQL_PostGIS.sql','02_Vistas_y_operaciones.sql','06_Catalogo_indicadores.sql','03_Datos_demo.sql']
    : ['RutaAlerta_PostgreSQL_Completo.sql','06_Catalogo_indicadores.sql','03_Datos_demo.sql'];
  for (const f of files) { const s=Date.now(); await db.exec(fs.readFileSync(path.join(sqlDir,f),'utf8')); res.pasos.push({archivo:f, estado:'Correcto', ms:Date.now()-s}); }
  const v = await q(`select version() v, postgis_full_version() p`); res.motor = v[0];
  res.conteos = (await q(`select
   (select count(*) from information_schema.tables where table_schema='rutaalerta' and table_type='BASE TABLE')::int tablas,
   (select count(*) from information_schema.columns c join information_schema.tables t on t.table_schema=c.table_schema and t.table_name=c.table_name where c.table_schema='rutaalerta' and t.table_type='BASE TABLE')::int columnas,
   (select count(*) from pg_constraint where contype='f' and connamespace='rutaalerta'::regnamespace)::int claves_foraneas,
   (select count(*) from pg_constraint where contype='p' and connamespace='rutaalerta'::regnamespace)::int claves_primarias,
   (select count(*) from pg_constraint where contype='c' and connamespace='rutaalerta'::regnamespace)::int checks,
   (select count(*) from pg_constraint where contype='u' and connamespace='rutaalerta'::regnamespace)::int unicas,
   (select count(*) from pg_indexes where schemaname='rutaalerta')::int indices,
   (select count(*) from information_schema.views where table_schema='rutaalerta')::int vistas,
   (select count(*) from pg_proc where pronamespace='rutaalerta'::regnamespace)::int funciones,
   (select count(*) from pg_trigger tg join pg_class c on c.oid=tg.tgrelid where c.relnamespace='rutaalerta'::regnamespace and not tg.tgisinternal)::int triggers,
   (select count(*) from rutaalerta.version_indicador)::int indicadores_catalogo`))[0];
  res.tablas = (await q(`select table_name from information_schema.tables where table_schema='rutaalerta' and table_type='BASE TABLE' order by 1`)).map(r=>r.table_name);
  res.filas_demo = (await q(`select relname tabla, n_live_tup::int filas from pg_stat_user_tables where schemaname='rutaalerta' order by relname`));
  const s=Date.now();
  const r = await db.exec(fs.readFileSync(path.join(sqlDir,'04_Pruebas_integridad.sql'),'utf8'));
  res.pruebas = r.flatMap(x=>x.rows??[]).filter(x=>x.prueba);
  res.pasos.push({archivo:'04_Pruebas_integridad.sql', estado:'Ejecutado', ms:Date.now()-s});
  const e = await db.exec(fs.readFileSync(path.join(sqlDir,'05_Consultas_espaciales.sql'),'utf8'));
  res.consultas_espaciales = e.map(x=>x.rows).filter(x=>x && x.length);
  res.pasos.push({archivo:'05_Consultas_espaciales.sql', estado:'Correcto'});
  res.vistas = {};
  for (const vname of ['v_bandeja_institucional','v_solicitudes_publicables','v_seguimiento_limitado','v_revisiones_oportunas','v_casos_por_marca'])
    res.vistas[vname] = await q(`select * from rutaalerta.${vname} limit 5`);
  res.resumen = {total: res.pruebas.length, correctas: res.pruebas.filter(p=>p.resultado==='CORRECTO').length};
} catch (err) { res.error = String(err.message||err); process.exitCode = 1; }
finally { await db.close(); res.duracion_total_ms = Date.now()-t0;
  fs.writeFileSync(path.join(outDir, `resultado_${mode}.json`), JSON.stringify(res,(k,v)=>typeof v==='bigint'?Number(v):v,2));
  console.log(JSON.stringify({modo:mode, error:res.error, conteos:res.conteos, resumen:res.resumen, pasos:res.pasos, ms:res.duracion_total_ms}, null, 1)); }
