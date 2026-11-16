from typing import Literal
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from ..db import obtener_conexion
from ..seguridad import usuario_actual
from .colaboracion import caso_autorizado, bitacora, rows

router=APIRouter(tags=['gestión institucional'])

def supervisor(cur,uid,oid):
    cur.execute("""SELECT 1 FROM membresia WHERE id_usuario=%s AND id_organizacion=%s AND rol='supervisor'
                   AND estado='activa' AND fin IS NULL AND inicio<=CURRENT_TIMESTAMP""",(uid,oid))
    return cur.fetchone() is not None

@router.get('/gestion/casos/{cid}/equipo')
def equipo(cid:int,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();c=caso_autorizado(cur,cid,usuario,operador=True);oid=c['id_organizacion']
    cur.execute("""SELECT u.nombre_visible FROM asignacion_caso a JOIN membresia m USING(id_membresia)
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
    cur.execute("""SELECT id_solicitud_colaboracion,vence_en FROM solicitud_colaboracion WHERE id_caso=%s
                   AND estado='publicada' AND vence_en>CURRENT_TIMESTAMP""",(cid,))
    publica=rows(cur)
    return {'responsable':actual[0] if actual else None,'opciones':opciones,'gestiones':gestiones,'publicacion':publica[0] if publica else None}

class Renovacion(BaseModel):
    motivo:str=Field(min_length=10,max_length=500)
    horas:int=Field(ge=1,le=72)
    id_solicitud_colaboracion:int

@router.post('/gestion/casos/{cid}/renovacion',status_code=204)
def renovar(cid:int,d:Renovacion,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();c=caso_autorizado(cur,cid,usuario,operador=True)
    if c['estado'] not in ('en_revision','en_gestion') or not c['colaboracion_consentida_en']:
        raise HTTPException(409,'La renovación requiere un caso en gestión o revisión con consentimiento.')
    cur.execute("""UPDATE solicitud_colaboracion SET vence_en=CURRENT_TIMESTAMP+(%s*interval '1 hour')
                   WHERE id_caso=%s AND id_solicitud_colaboracion=%s AND estado='publicada' AND vence_en>CURRENT_TIMESTAMP
                   AND vence_en<CURRENT_TIMESTAMP+(%s*interval '1 hour') RETURNING vence_en""",(d.horas,cid,d.id_solicitud_colaboracion,d.horas))
    if not cur.fetchone():raise HTTPException(409,'Selecciona una publicación vigente y un plazo que amplíe su duración.')
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

