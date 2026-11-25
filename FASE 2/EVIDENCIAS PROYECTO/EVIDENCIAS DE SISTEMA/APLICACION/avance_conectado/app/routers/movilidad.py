"""Destinos privados, rutas calculadas y antecedentes públicos sujetos a revisión."""
import math, uuid, json, os
from datetime import date, datetime, timezone, timedelta
from urllib.parse import urlsplit
import httpx
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field, field_validator
from ..db import obtener_conexion,fila_dict
from ..seguridad import usuario_actual,organizaciones_del_operador
from ..antifraude import limitar
from ..antifraude import DEMO
from ..config import config
from ..zonas_historicas import consultar_zonas, cruzar_rutas, PERIODO_DIAS
from .colaboracion import rows, listado

router=APIRouter(tags=['movilidad y antecedentes'])
class Punto(BaseModel):
 latitud:float=Field(ge=-90,le=90,allow_inf_nan=False)
 longitud:float=Field(ge=-180,le=180,allow_inf_nan=False)
class Lugar(Punto):
 nombre:str=Field(min_length=2,max_length=100)
 direccion:str=Field(default='',max_length=300)

@router.get('/lugares')
def lugares(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
 cur=conn.cursor();cur.execute('''SELECT tipo,nombre,direccion,ST_Y(ubicacion::geometry) AS latitud,ST_X(ubicacion::geometry) AS longitud FROM lugar_guardado WHERE id_usuario=%s AND activo ORDER BY tipo''',(usuario['id_usuario'],));return rows(cur)
@router.put('/lugares/{tipo}')
def guardar(tipo:str,datos:Lugar,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
 if tipo not in ('casa','trabajo','favorito'):raise HTTPException(422,'Tipo de lugar inválido')
 limitar(conn,f'lugar:{usuario["id_usuario"]}',20)
 conn.cursor().execute('''INSERT INTO lugar_guardado(id_usuario,tipo,nombre,direccion,ubicacion) VALUES(%s,%s,%s,%s,ST_SetSRID(ST_Point(%s,%s),4326)::geography)
 ON CONFLICT(id_usuario,tipo) DO UPDATE SET nombre=EXCLUDED.nombre,direccion=EXCLUDED.direccion,ubicacion=EXCLUDED.ubicacion,activo=true,actualizado_en=CURRENT_TIMESTAMP''',(usuario['id_usuario'],tipo,datos.nombre,datos.direccion,datos.longitud,datos.latitud))
 return {'mensaje':'Lugar privado guardado'}
@router.post('/lugares/{tipo}/retirar',status_code=204)
def retirar_lugar(tipo:str,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
 conn.cursor().execute("UPDATE lugar_guardado SET activo=false,ubicacion=NULL,direccion='',nombre='Lugar retirado',actualizado_en=CURRENT_TIMESTAMP WHERE id_usuario=%s AND tipo=%s",(usuario['id_usuario'],tipo))

class Ruta(BaseModel):
 origen:Punto
 destino:Punto
 consentimiento_proveedor:bool=False
 evitar_zonas:bool=True


def ambiente_historico():
 return 'prueba' if config.alertas_demo and DEMO else 'operacion'

@router.post('/rutas/calcular')
def ruta(datos:Ruta,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
 if not datos.consentimiento_proveedor:raise HTTPException(422,'Confirma el envío de origen y destino al proveedor de rutas')
 limitar(conn,f'ruta:{usuario["id_usuario"]}',10)
 # Host fijo: nunca aceptar una URL del cliente ni redirecciones a servicios internos.
 a,b=datos.origen,datos.destino
 coordinates=f'{a.longitud:.6f},{a.latitud:.6f};{b.longitud:.6f},{b.latitud:.6f}'
 try:
  with httpx.Client(timeout=12,follow_redirects=False,headers={'User-Agent':'RutaAlerta-Capstone/0.8'}) as client:
   with client.stream('GET',f'https://router.project-osrm.org/route/v1/driving/{coordinates}',params={'alternatives':'true','steps':'false','overview':'full','geometries':'geojson'}) as response:
    if response.status_code!=200:raise ValueError()
    chunks=[];size=0
    for chunk in response.iter_bytes():
     size+=len(chunk)
     if size>2000000:raise ValueError()
     chunks.append(chunk)
    data=json.loads(b''.join(chunks))
  if data.get('code')!='Ok':raise ValueError()
  found=[]
  for candidate in data['routes'][:3]:
   geometry=candidate['geometry'];pts=geometry['coordinates'];distance=float(candidate['distance']);duration=float(candidate['duration'])
   if geometry['type']!='LineString' or not 2<=len(pts)<=25000 or not math.isfinite(distance) or not math.isfinite(duration) or not 0<=distance<=5000000 or not 0<=duration<=1000000:raise ValueError()
   if any(len(p)!=2 or not all(isinstance(v,(int,float)) and math.isfinite(v) for v in p) or not -180<=p[0]<=180 or not -90<=p[1]<=90 for p in pts):raise ValueError()
   found.append({'distancia_m':distance,'duracion_s':duration,'geometria':geometry})
  if not found:raise ValueError()
 except (httpx.HTTPError,ValueError,TypeError,KeyError):
  raise HTTPException(503,'No se pudo calcular la ruta. Puedes abrir el destino en Google Maps o Waze. No se mostrará una línea recta como si fuera una ruta.') from None
 ambiente = ambiente_historico()
 alcance = {'type':'MultiLineString','coordinates':[r['geometria']['coordinates'] for r in found]}
 cur = conn.cursor()
 zonas = consultar_zonas(cur, alcance, ambiente, 2000)
 for alternativa, cruces in zip(found, cruzar_rutas(cur, found, zonas)):
  alternativa['cruces_zonas'] = cruces
 if datos.evitar_zonas:
  found.sort(key=lambda r: (r['cruces_zonas'], r['duracion_s']))
 nota = 'OSRM puede devolver una sola opción. La comparación usa antecedentes revisados de los últimos 365 días.'
 if zonas and all(r['cruces_zonas'] for r in found):
  nota = 'Todas las alternativas disponibles cruzan zonas históricas. ' + nota
 elif not zonas:
  nota = 'Sin zonas históricas concentradas cerca de las alternativas consultadas. ' + nota
 return {'rutas':found,'zonas':zonas,'simulacion':ambiente=='prueba',
         'proveedor':'OSRM · tiempos estimados sin tráfico en vivo','nota':nota}

class Ficha(BaseModel):
 id_organizacion:int
 url_fuente:str=Field(min_length=12,max_length=1500)
 nombre_fuente:str=Field(min_length=2,max_length=150)
 titulo:str=Field(min_length=8,max_length=250)
 resumen:str=Field(min_length=20,max_length=700)
 tipo:str=Field(pattern='^(portonazo|encerrona|robo_vehiculo|otro)$')
 fecha_publicacion:date
 fecha_hecho:date|None=None
 zona:str=Field(min_length=3,max_length=200)
 @field_validator('url_fuente')
 @classmethod
 def url(cls,v):
  p=urlsplit(v)
  if p.scheme!='https' or not p.hostname or p.username or p.password or p.fragment:raise ValueError('Usa enlace público HTTPS sin credenciales')
  return v

def ambito(cur,usuario,oid):
 if oid not in organizaciones_del_operador(cur,usuario['id_usuario']):raise HTTPException(403,'Fuera del ámbito institucional')

@router.post('/gestion/antecedentes',status_code=201)
def proponer(datos:Ficha,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
 cur=conn.cursor();ambito(cur,usuario,datos.id_organizacion)
 if datos.fecha_publicacion>datetime.now(timezone.utc).date() or datos.fecha_hecho and datos.fecha_hecho>datos.fecha_publicacion:raise HTTPException(422,'Revisa las fechas de la fuente')
 cur.execute('SELECT id_antecedente FROM antecedente_publico WHERE url_fuente=%s',(datos.url_fuente,))
 if cur.fetchone():raise HTTPException(409,'La fuente ya fue propuesta; revisa el antecedente existente')
 cur.execute('''INSERT INTO antecedente_publico(id_organizacion,url_fuente,nombre_fuente,titulo,resumen,tipo,fecha_publicacion,fecha_hecho,zona,entorno) VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id_antecedente''',(datos.id_organizacion,datos.url_fuente,datos.nombre_fuente,datos.titulo,datos.resumen,datos.tipo,datos.fecha_publicacion,datos.fecha_hecho,datos.zona,ambiente_historico()))
 return {'id_antecedente':cur.fetchone()[0],'estado':'pendiente','nota':'No genera avisos hasta una revisión humana y territorial explícita.'}
@router.get('/gestion/antecedentes')
def cola(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
 cur=conn.cursor();orgs=organizaciones_del_operador(cur,usuario['id_usuario'])
 if not orgs:raise HTTPException(403,'Sin ámbito institucional')
 cur.execute('''SELECT id_antecedente,url_fuente,nombre_fuente,titulo,resumen,tipo,fecha_publicacion,fecha_hecho,zona,estado,precision_m,radio_m,vence_en,ST_Y(centro::geometry) AS latitud,ST_X(centro::geometry) AS longitud FROM antecedente_publico WHERE id_organizacion=ANY(%s) ORDER BY creado_en DESC LIMIT 100''',(orgs,));return rows(cur)
class Revisar(BaseModel):
 latitud:float|None=Field(default=None,ge=-90,le=90,allow_inf_nan=False)
 longitud:float|None=Field(default=None,ge=-180,le=180,allow_inf_nan=False)
 decision:str=Field(pattern='^(validado|descartado)$')
 precision_m:int=Field(default=1000,ge=100,le=10000)
 radio_m:int=Field(default=1500,ge=100,le=15000)
 dias_vigencia:int=Field(default=30,ge=1,le=90)
 motivo:str=Field(min_length=15,max_length=1000)
@router.post('/gestion/antecedentes/{aid}/revision',status_code=204)
def revisar_fuente(aid:uuid.UUID,datos:Revisar,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
 cur=conn.cursor();cur.execute('SELECT id_organizacion FROM antecedente_publico WHERE id_antecedente=%s FOR UPDATE',(str(aid),));row=cur.fetchone()
 if not row:raise HTTPException(404,'Antecedente no disponible')
 ambito(cur,usuario,row[0])
 if datos.decision=='validado' and (datos.latitud is None or datos.longitud is None):raise HTTPException(422,'Confirma el sector antes de activar el aviso')
 if datos.radio_m<datos.precision_m:raise HTTPException(422,'El radio de aviso no puede ser menor que la incertidumbre de localización')
 cur.execute('''UPDATE antecedente_publico SET estado=%s,centro=CASE WHEN %s::float IS NOT NULL THEN ST_SetSRID(ST_Point(%s,%s),4326)::geography ELSE centro END,precision_m=%s,radio_m=%s,vence_en=CURRENT_TIMESTAMP+%s*interval '1 day',revisado_por=%s,revisado_en=CURRENT_TIMESTAMP,motivo_revision=%s WHERE id_antecedente=%s''',(datos.decision,datos.longitud,datos.longitud,datos.latitud,datos.precision_m,datos.radio_m,datos.dias_vigencia,usuario['id_usuario'],datos.motivo,str(aid)))
 cur.execute('''INSERT INTO evento_auditoria(id_usuario,accion,objeto_tipo,objeto_id,resultado,correlacion,resumen) VALUES(%s,'revision_territorial','antecedente_publico',%s,'exito',%s,%s)''',(usuario['id_usuario'],str(aid),str(uuid.uuid4()),'Decisión editorial y territorial registrada; no acredita denuncia oficial'))

@router.get('/territorio/avisos')
def avisos(lat:float=Query(...,ge=-90,le=90),lon:float=Query(...,ge=-180,le=180),radio_km:int=Query(30,ge=1,le=100),usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
 cur=conn.cursor()
 # El servidor recibe una búsqueda puntual por área, no un historial continuo de GPS.
 cur.execute('''SELECT id_antecedente,url_fuente,nombre_fuente,titulo,resumen,tipo,fecha_publicacion,fecha_hecho,zona,precision_m,radio_m,vence_en,ST_Y(centro::geometry) AS latitud,ST_X(centro::geometry) AS longitud FROM antecedente_publico
 WHERE estado='validado' AND entorno=%s AND vence_en>CURRENT_TIMESTAMP AND fecha_publicacion>=CURRENT_DATE-365
 AND ST_DWithin(centro,ST_SetSRID(ST_Point(%s,%s),4326)::geography,%s) ORDER BY fecha_publicacion DESC LIMIT 50''',(ambiente_historico(),lon,lat,radio_km*1000))
 return {'avisos':rows(cur),'cache_hasta':datetime.now(timezone.utc)+timedelta(hours=2),'nota':'Antecedentes de prensa revisados; no indican delitos en curso ni frecuencia estadística. Ubicaciones aproximadas.'}


@router.get('/territorio/panorama')
def panorama(lat:float=Query(...,ge=-90,le=90), lon:float=Query(...,ge=-180,le=180),
             usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    solicitudes=listado(lat,lon,30,'',usuario,conn)
    antecedentes=avisos(lat,lon,30,usuario,conn)
    ambiente = ambiente_historico()
    zonas = consultar_zonas(conn.cursor(), {'type':'Point','coordinates':[lon,lat]}, ambiente, 30000)
    return {'solicitudes':solicitudes['cercanos'], 'antecedentes':antecedentes['avisos'],
            'zonas':zonas, 'periodo_dias':PERIODO_DIAS, 'simulacion':ambiente=='prueba'}

@router.get('/territorio/zonas')
def zonas_mapa(lat:float=Query(...,ge=-90,le=90), lon:float=Query(...,ge=-180,le=180),
               usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    ambiente = ambiente_historico()
    zonas = consultar_zonas(conn.cursor(), {'type':'Point','coordinates':[lon,lat]}, ambiente, 30000)
    return {'zonas':zonas, 'periodo_dias':PERIODO_DIAS, 'simulacion':ambiente=='prueba'}

@router.get('/territorio/noticias')
def noticias(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
 cur=conn.cursor();cur.execute("""SELECT id_antecedente,url_fuente,nombre_fuente,titulo,resumen,tipo,fecha_publicacion,fecha_hecho,zona,estado FROM antecedente_publico WHERE entorno=%s AND estado<>'descartado' AND fecha_publicacion>=CURRENT_DATE-365 ORDER BY fecha_publicacion DESC LIMIT 100""", (ambiente_historico(),))
 return {'noticias':rows(cur),'nota':'Enlaces y resúmenes propios. Los pendientes todavía no generan avisos. Una noticia no es una estadística de frecuencia.'}

@router.post('/territorio/avisos/descargar')
def descargar_avisos(area:Punto,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
 # Búsqueda por cuerpo JSON y centro redondeado, sin coordenadas precisas en URL de acceso.
 return avisos(round(area.latitud,2),round(area.longitud,2),30,usuario,conn)
