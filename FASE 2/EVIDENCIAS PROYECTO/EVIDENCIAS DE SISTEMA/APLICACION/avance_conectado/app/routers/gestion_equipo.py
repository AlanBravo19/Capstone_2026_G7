from typing import Literal
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from ..db import obtener_conexion
from ..seguridad import usuario_actual, organizaciones_del_operador
from .colaboracion import caso_autorizado, bitacora, rows
from ..alertas import VIGENTE, entorno
from ..config import config
from ..antifraude import DEMO

router=APIRouter(tags=['gestión institucional'])

@router.get('/gestion/mi-acceso')
def mi_acceso(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    cur.execute("""SELECT m.id_organizacion,o.nombre,m.rol,
        (m.rol='supervisor') AS puede_asignar
        FROM membresia m JOIN organizacion o USING(id_organizacion)
        WHERE m.id_usuario=%s AND m.estado='activa' AND m.fin IS NULL
        AND m.inicio<=CURRENT_TIMESTAMP AND o.estado='activa'
        ORDER BY o.nombre,m.id_membresia""",(usuario['id_usuario'],))
    organizaciones=rows(cur)
    if not organizaciones:raise HTTPException(403,'Sin membresía institucional vigente')
    cur.execute("""SELECT 1 FROM usuario_rol ur JOIN rol r USING(id_rol)
        WHERE ur.id_usuario=%s AND ur.revocado_en IS NULL AND r.codigo='administrador'""",
        (usuario['id_usuario'],))
    admin=cur.fetchone() is not None
    permisos=['Consultar y gestionar casos de tus organizaciones',
              'Revisar aportes, publicar solicitudes y enviar novedades',
              'Consultar estadísticas del ámbito institucional',
              'Mantener recursos de apoyo del equipo']
    if any(o['puede_asignar'] for o in organizaciones):
        permisos.append('Asignar responsables en las organizaciones donde eres supervisor')
        permisos.append('Revisar padrones privados y resolver vínculos vehiculares de esas organizaciones')
    if admin:permisos.append('Administrar restricciones de cuentas')
    return {'organizaciones':organizaciones,'administrador_global':admin,'permisos':permisos,
            'demo_alertas':config.alertas_demo and DEMO,
            'asignacion':'Ser responsable de un caso no cambia el rol ni amplía el ámbito institucional.'}

@router.get('/gestion/mapa')
def mapa_operativo(id_organizacion: int, usuario=Depends(usuario_actual), conn=Depends(obtener_conexion)):
    cur = conn.cursor()
    if id_organizacion not in organizaciones_del_operador(cur, usuario['id_usuario']):
        raise HTTPException(403, 'Organización fuera de tu ámbito')
    cur.execute(f"""
        WITH abiertos AS (
            SELECT c.id_caso, c.folio, c.estado, c.zona, c.ubicacion, c.fecha_hecho,
                   EXISTS (SELECT 1 FROM solicitud_colaboracion s
                           WHERE s.id_caso=c.id_caso AND {VIGENTE}) AS alerta_activa
            FROM caso c WHERE c.id_organizacion=%s AND c.entorno=%s AND c.estado<>'cerrado'
        ), eventos AS (
            SELECT 'reporte' AS tipo, id_caso AS id_evento, id_caso, folio, estado,
                   zona, ubicacion, fecha_hecho AS fecha, alerta_activa FROM abiertos
            UNION ALL
            SELECT 'avistamiento', a.id_avistamiento, c.id_caso, c.folio, c.estado,
                   a.zona, a.ubicacion, a.observado_en, false
            FROM avistamiento a JOIN abiertos c USING(id_caso)
            WHERE a.estado_revision='aceptado'
        )
        SELECT tipo, id_evento, id_caso, folio, estado, zona, fecha, alerta_activa,
               ST_Y(ubicacion::geometry) AS latitud, ST_X(ubicacion::geometry) AS longitud
        FROM eventos ORDER BY fecha DESC, tipo, id_evento DESC LIMIT 301
    """, (id_organizacion, entorno()))
    items = rows(cur)
    return {'eventos': items[:300], 'hay_mas': len(items) > 300,
            'simulacion': DEMO and config.alertas_demo}

def supervisor(cur,uid,oid):
    cur.execute("""SELECT 1 FROM membresia WHERE id_usuario=%s AND id_organizacion=%s AND rol='supervisor'
                   AND estado='activa' AND fin IS NULL AND inicio<=CURRENT_TIMESTAMP""",(uid,oid))
    return cur.fetchone() is not None

@router.get('/gestion/casos/{cid}/equipo')
def equipo(cid:int,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();c=caso_autorizado(cur,cid,usuario,operador=True);oid=c['id_organizacion']
    cur.execute("""SELECT u.nombre_visible,m.rol,
                   (m.estado='activa' AND m.fin IS NULL AND m.inicio<=CURRENT_TIMESTAMP AND u.estado='activo')
                   FROM asignacion_caso a JOIN membresia m USING(id_membresia)
                   JOIN usuario u USING(id_usuario) WHERE a.id_caso=%s AND a.fin IS NULL""",(cid,))
    actual=cur.fetchone();opciones=[]
    if supervisor(cur,usuario['id_usuario'],oid):
        cur.execute("""SELECT m.id_membresia,u.nombre_visible FROM membresia m JOIN usuario u USING(id_usuario)
                       WHERE m.id_organizacion=%s AND m.estado='activa' AND m.fin IS NULL AND m.inicio<=CURRENT_TIMESTAMP
                       AND u.estado='activo' ORDER BY u.nombre_visible""",(oid,))
        opciones=rows(cur)
    cur.execute("""SELECT accion,descripcion,creada_en FROM gestion_caso WHERE id_caso=%s AND visibilidad='interna'
                   ORDER BY id_gestion_caso DESC LIMIT 100""",(cid,))
    gestiones=rows(cur)
    cur.execute(f"""SELECT s.id_solicitud_colaboracion,s.vence_en,s.id_foto_vehiculo,s.modo_alerta
        FROM solicitud_colaboracion s JOIN caso c USING(id_caso) WHERE c.id_caso=%s AND {VIGENTE}""",(cid,))
    publica=rows(cur)
    return {'responsable':actual[0] if actual else None,
            'responsable_rol':actual[1] if actual else None,
            'responsable_vigente':actual[2] if actual else False,
            'puede_asignar':supervisor(cur,usuario['id_usuario'],oid),
            'opciones':opciones,'gestiones':gestiones,'publicacion':publica[0] if publica else None}

class Renovacion(BaseModel):
    revision:int|None=Field(default=None,ge=0)
    motivo:str=Field(min_length=10,max_length=500)
    horas:int=Field(ge=1,le=72)
    id_solicitud_colaboracion:int

@router.post('/gestion/casos/{cid}/renovacion',status_code=204)
def renovar(cid:int,d:Renovacion,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();c=caso_autorizado(cur,cid,usuario,operador=True)
    cur.execute('SELECT revision_alerta FROM caso WHERE id_caso=%s',(cid,))
    if d.revision is not None and cur.fetchone()[0]!=d.revision:
        raise HTTPException(409,'El expediente cambió. Recarga antes de renovar.')
    if c['estado'] not in ('en_revision','en_gestion') or not c['colaboracion_consentida_en']:
        raise HTTPException(409,'La renovación requiere un caso en gestión o revisión con consentimiento.')
    cur.execute("""UPDATE solicitud_colaboracion SET vence_en=CURRENT_TIMESTAMP+(%s*interval '1 hour')
                   WHERE id_caso=%s AND id_solicitud_colaboracion=%s AND estado='publicada' AND vence_en>CURRENT_TIMESTAMP
                   AND suspendida_en IS NULL AND modo_alerta<>'provisional' AND id_vinculo_verificado IS NULL
                   AND vence_en<CURRENT_TIMESTAMP+(%s*interval '1 hour') RETURNING vence_en""",(d.horas,cid,d.id_solicitud_colaboracion,d.horas))
    if not cur.fetchone():raise HTTPException(409,'Selecciona una publicación vigente y un plazo que amplíe su duración.')
    cur.execute('UPDATE caso SET revision_alerta=revision_alerta+1 WHERE id_caso=%s',(cid,))
    bitacora(cur,cid,usuario['id_usuario'],'renovacion',d.motivo,'interna')

class Asignacion(BaseModel):
    id_membresia:int
    motivo:str=Field(min_length=10,max_length=500)

@router.post('/gestion/casos/{cid}/asignacion',status_code=204)
def asignar(cid:int,d:Asignacion,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();c=caso_autorizado(cur,cid,usuario,operador=True);uid=usuario['id_usuario'];oid=c['id_organizacion']
    if not supervisor(cur,uid,oid):raise HTTPException(403,'Se requiere supervisión de esta organización')
    if c['estado']=='cerrado':raise HTTPException(409,'Caso cerrado')
    cur.execute("""SELECT u.nombre_visible FROM membresia m JOIN usuario u USING(id_usuario) WHERE m.id_membresia=%s AND
                   m.id_organizacion=%s AND m.estado='activa' AND m.fin IS NULL AND m.inicio<=CURRENT_TIMESTAMP AND u.estado='activo' FOR SHARE""",(d.id_membresia,oid))
    member=cur.fetchone()
    if not member:raise HTTPException(422,'Elige un integrante vigente de la organización')
    cur.execute('SELECT id_membresia FROM asignacion_caso WHERE id_caso=%s AND fin IS NULL',(cid,))
    previo=cur.fetchone()
    if previo and previo[0]==d.id_membresia:return
    cur.execute('UPDATE asignacion_caso SET fin=CURRENT_TIMESTAMP WHERE id_caso=%s AND fin IS NULL',(cid,))
    cur.execute('INSERT INTO asignacion_caso(id_caso,id_organizacion,id_membresia,asignado_por,motivo) VALUES(%s,%s,%s,%s,%s)',(cid,oid,d.id_membresia,uid,d.motivo))
    bitacora(cur,cid,uid,'asignacion',f'{member[0]} · {d.motivo}','interna')

class Gestion(BaseModel):
    accion:Literal['nota','derivacion']
    descripcion:str=Field(min_length=10,max_length=500)

@router.post('/gestion/casos/{cid}/gestiones',status_code=204)
def gestionar(cid:int,d:Gestion,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();c=caso_autorizado(cur,cid,usuario,operador=True)
    if c['estado']=='cerrado':raise HTTPException(409,'Caso cerrado')
    bitacora(cur,cid,usuario['id_usuario'],d.accion,d.descripcion,'interna')

