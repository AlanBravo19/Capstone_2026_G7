"""Avisos privados independientes de la propiedad del vehículo y del consentimiento para difundir."""
from datetime import datetime, timezone
from typing import Literal
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, Response
from pydantic import BaseModel, Field, field_validator
from ..antifraude import participante, limitar
from ..db import obtener_conexion, fila_dict
from ..seguridad import usuario_actual, organizaciones_del_operador
from .colaboracion import rows, bitacora, bloquear_participante, caso_autorizado
from .avance import PLACAS
import re

router=APIRouter(tags=['avisos de testigos'])

class Aviso(BaseModel):
    perspectiva:Literal['pasajero','testigo']
    id_organizacion:int
    observado_en:datetime
    zona:str=Field(min_length=3,max_length=200)
    descripcion:str=Field(min_length=10,max_length=3000)
    patente_observada:str|None=Field(default=None,max_length=16)

    @field_validator('zona','descripcion', mode='before')
    @classmethod
    def recortar(cls,v):
        return v.strip() if isinstance(v,str) else v

    @field_validator('patente_observada')
    @classmethod
    def normalizar(cls,v):
        if not v or not v.strip():return None
        placa=re.sub(r'[ .-]','',v.upper())
        if not any(re.fullmatch(patron,placa) for patron in PLACAS.values()):
            raise ValueError('Indica la patente completa o deja el campo vacío.')
        return placa

    @field_validator('observado_en')
    @classmethod
    def fecha(cls,v):
        if v.tzinfo is None or v>datetime.now(timezone.utc):
            raise ValueError('La hora de observación debe incluir zona horaria y no puede ser futura.')
        return v

@router.post('/avisos-testigo',status_code=201)
def crear(datos:Aviso,response:Response,idempotency_key:UUID=Header(...),usuario=Depends(participante),conn=Depends(obtener_conexion)):
    uid=usuario['id_usuario'];cur=conn.cursor()
    cur.execute('SELECT id_aviso FROM aviso_testigo WHERE id_usuario=%s AND clave_envio=%s',(uid,idempotency_key))
    anterior=cur.fetchone()
    if not anterior:limitar(conn,f'aviso-testigo:{uid}',10)
    bloquear_participante(cur,uid)
    cur.execute('SELECT id_aviso,id_organizacion,perspectiva,observado_en,zona,descripcion,patente_observada FROM aviso_testigo WHERE id_usuario=%s AND clave_envio=%s',(uid,idempotency_key))
    previo=cur.fetchone()
    contenido=(datos.id_organizacion,datos.perspectiva,datos.observado_en,datos.zona,datos.descripcion,datos.patente_observada)
    if previo:
        if tuple(previo[1:])!=contenido:raise HTTPException(409,'La clave ya corresponde a otro aviso')
        response.status_code=200
        return {'id_aviso':previo[0]}
    cur.execute("SELECT 1 FROM organizacion WHERE id_organizacion=%s AND estado='activa'",(datos.id_organizacion,))
    if not cur.fetchone():raise HTTPException(422,'Selecciona una organización activa')
    aid=uuid4()
    cur.execute('''INSERT INTO aviso_testigo(id_aviso,id_usuario,clave_envio,id_organizacion,perspectiva,observado_en,zona,descripcion,patente_observada)
                   VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s)''',(aid,uid,idempotency_key,*contenido))
    return {'id_aviso':aid}

@router.get('/mis-avisos-testigo')
def propios(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    cur.execute('SELECT id_aviso,perspectiva,observado_en,zona,estado FROM aviso_testigo WHERE id_usuario=%s ORDER BY recibido_en DESC LIMIT 100',(usuario['id_usuario'],))
    return rows(cur)

@router.get('/gestion/testigos')
def bandeja(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();orgs=organizaciones_del_operador(cur,usuario['id_usuario'])
    if not orgs:raise HTTPException(403,'Se requiere acceso institucional')
    cur.execute('''SELECT a.id_aviso,a.id_organizacion,a.perspectiva,a.observado_en,a.zona,a.descripcion,a.patente_observada,
                          a.estado,a.motivo_revision,c.folio FROM aviso_testigo a LEFT JOIN caso c USING(id_caso)
                   WHERE a.id_organizacion=ANY(%s) ORDER BY (a.estado='pendiente') DESC,a.recibido_en DESC LIMIT 200''',(orgs,))
    return rows(cur)

class Revision(BaseModel):
    decision:Literal['asociado','revisado','descartado']
    motivo:str=Field(min_length=10,max_length=500)
    id_caso:int|None=None

@router.post('/gestion/testigos/{aid}/revision',status_code=204)
def revisar(aid:UUID,d:Revision,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    uid=usuario['id_usuario'];cur=conn.cursor();orgs=organizaciones_del_operador(cur,uid)
    cur.execute('SELECT id_usuario,id_organizacion,estado FROM aviso_testigo WHERE id_aviso=%s AND id_organizacion=ANY(%s) FOR UPDATE',(aid,orgs))
    row=cur.fetchone()
    if not row or row[0]==uid:raise HTTPException(403,'No puedes revisar este aviso')
    if row[2]!='pendiente':raise HTTPException(409,'El aviso ya fue revisado')
    if len(d.motivo.strip())<10:raise HTTPException(422,'Explica el fundamento de la decisión')
    if d.decision=='asociado':
        if not d.id_caso:raise HTTPException(422,'Selecciona el caso relacionado')
        caso=caso_autorizado(cur,d.id_caso,usuario,operador=True)
        if caso['id_organizacion']!=row[1] or caso['estado']=='cerrado':raise HTTPException(409,'Selecciona un caso abierto de la organización receptora')
        bitacora(cur,d.id_caso,uid,'aviso_testigo',f'Aviso {aid}: {d.motivo.strip()}','interna')
    elif d.id_caso is not None:raise HTTPException(422,'La decisión seleccionada no requiere caso')
    cur.execute('UPDATE aviso_testigo SET estado=%s,id_caso=%s,motivo_revision=%s,revisado_en=CURRENT_TIMESTAMP,revisado_por=%s WHERE id_aviso=%s',(d.decision,d.id_caso,d.motivo.strip(),uid,aid))

