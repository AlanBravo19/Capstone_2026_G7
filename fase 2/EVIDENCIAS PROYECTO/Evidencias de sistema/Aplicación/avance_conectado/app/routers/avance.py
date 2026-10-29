"""Tramo conectado: vehículos propios y casos. No publica reportes sin revisión."""
import re
from pydantic import BaseModel, Field, field_validator
from fastapi import APIRouter,Depends,HTTPException
from ..db import obtener_conexion,fila_dict,ErrorBD,es_unico
from ..seguridad import usuario_actual
from ..antifraude import participante,limitar,administrador

router=APIRouter(tags=['avance conectado'])

class VehiculoEntrada(BaseModel):
    marca:str=Field(min_length=2,max_length=80)
    modelo:str=Field(min_length=1,max_length=100)
    patente:str=Field(min_length=4,max_length=16)
    color:str=Field(min_length=2,max_length=50)
    anio:int=Field(ge=1900,le=2100)
    @field_validator('patente')
    @classmethod
    def placa(cls,v):
        v=re.sub(r'[\s-]','',v).upper()
        if not re.fullmatch(r'[A-Z0-9]{4,16}',v):raise ValueError('Patente alfanumérica de 4 a 16 caracteres')
        return v

@router.post('/vehiculos',status_code=201)
def nuevo_vehiculo(datos:VehiculoEntrada,usuario=Depends(participante),conn=Depends(obtener_conexion)):
    limitar(conn,f'vehiculo:{usuario["id_usuario"]}',10)
    cur=conn.cursor()
    # Revalidar y bloquear tras confirmar los contadores de uso.
    cur.execute('SELECT estado FROM usuario WHERE id_usuario=%s FOR UPDATE',(usuario['id_usuario'],))
    if cur.fetchone()[0]!='activo':raise HTTPException(403,'Cuenta restringida')
    cur.execute('INSERT INTO marca(nombre) VALUES(%s) ON CONFLICT(nombre) DO UPDATE SET nombre=EXCLUDED.nombre RETURNING id_marca',(datos.marca.strip().upper(),))
    mid=cur.fetchone()[0]
    cur.execute('INSERT INTO modelo(id_marca,nombre) VALUES(%s,%s) ON CONFLICT(id_marca,nombre) DO UPDATE SET nombre=EXCLUDED.nombre RETURNING id_modelo',(mid,datos.modelo.strip().upper()))
    modelo=cur.fetchone()[0]
    try:
        cur.execute('''INSERT INTO vehiculo(id_modelo,patente,color,anio,tipo_vehiculo)
            VALUES(%s,%s,%s,%s,'automovil') RETURNING id_vehiculo''',(modelo,datos.patente,datos.color,datos.anio))
    except ErrorBD as e:
        if es_unico(e):
            raise HTTPException(409,'El vehículo ya está registrado. El vínculo con un vehículo existente requiere revisión asistida.')
        raise
    vid=cur.fetchone()[0]
    cur.execute("INSERT INTO vinculo_vehiculo(id_usuario,id_vehiculo,tipo) VALUES(%s,%s,'propietario')",(usuario['id_usuario'],vid))
    return {'id_vehiculo':vid,'estado_vinculo':'pendiente','mensaje':'Vínculo declarado; no acredita propiedad.'}

@router.get('/vehiculos')
def mis_vehiculos(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    cur.execute('''SELECT v.id_vehiculo,v.patente,v.color,v.anio,ma.nombre AS marca,mo.nombre AS modelo,vv.estado AS estado_vinculo
       FROM vinculo_vehiculo vv JOIN vehiculo v USING(id_vehiculo) JOIN modelo mo USING(id_modelo)
       JOIN marca ma USING(id_marca) WHERE vv.id_usuario=%s AND vv.estado IN ('pendiente','autorizado') ORDER BY v.id_vehiculo DESC''',(usuario['id_usuario'],))
    return [fila_dict(cur,r) for r in cur.fetchall()]

@router.get('/mis-casos')
def mis_casos(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    cur.execute('''SELECT c.id_caso,c.folio,c.estado,c.zona,c.fecha_hecho,c.creado_en,c.denuncia_estado,v.patente
       FROM caso c JOIN vehiculo v USING(id_vehiculo) WHERE c.id_usuario_reportante=%s ORDER BY c.creado_en DESC LIMIT 100''',(usuario['id_usuario'],))
    return [fila_dict(cur,r) for r in cur.fetchall()]

@router.get('/mi-perfil')
def perfil(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    cur.execute('''SELECT r.codigo FROM usuario_rol ur JOIN rol r USING(id_rol)
        WHERE ur.id_usuario=%s AND ur.revocado_en IS NULL''',(usuario['id_usuario'],))
    return {**usuario,'roles':[r[0] for r in cur.fetchall()]}

class RevisionCaso(BaseModel):
    estado:str=Field(pattern='^(en_revision|en_gestion)$')
    motivo:str=Field(min_length=10,max_length=500)

@router.post('/gestion/casos/{id_caso}/revision')
def revision_caso(id_caso:int,datos:RevisionCaso,usuario=Depends(administrador),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    # Exige además pertenencia institucional al caso, incluso siendo administrador global.
    cur.execute('''SELECT c.estado FROM caso c WHERE c.id_caso=%s AND EXISTS (
      SELECT 1 FROM membresia m JOIN organizacion o USING(id_organizacion)
      WHERE m.id_organizacion=c.id_organizacion AND m.id_usuario=%s AND m.estado='activa'
      AND m.fin IS NULL AND m.inicio<=CURRENT_TIMESTAMP AND o.estado='activa') FOR UPDATE OF c''',(id_caso,usuario['id_usuario']))
    fila=cur.fetchone()
    if fila is None:raise HTTPException(403,'Caso fuera del ámbito autorizado')
    if fila[0]=='cerrado':raise HTTPException(409,'Caso cerrado')
    cur.execute('UPDATE caso SET estado=%s,actualizado_en=CURRENT_TIMESTAMP WHERE id_caso=%s',(datos.estado,id_caso))
    cur.execute("INSERT INTO gestion_caso(id_caso,id_usuario,accion,descripcion) VALUES(%s,%s,'nota',%s)",(id_caso,usuario['id_usuario'],datos.motivo))
    return {'id_caso':id_caso,'estado':datos.estado,'publicado':False}
