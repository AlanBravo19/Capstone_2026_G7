"""Tramo conectado: vehículos propios y casos. No publica reportes sin revisión."""
import re
import json
from pathlib import Path
from typing import Literal
from datetime import date
from pydantic import BaseModel, Field, field_validator, model_validator
from fastapi import APIRouter,Depends,HTTPException
from ..db import obtener_conexion,fila_dict,ErrorBD,es_unico
from ..seguridad import usuario_actual
from ..antifraude import participante,limitar,administrador

router=APIRouter(tags=['avance conectado'])

CATALOGO = json.loads((Path(__file__).resolve().parents[1] / 'catalogo_sii_2026.json').read_text(encoding='utf-8'))
PLACAS = {'motocicleta': r'(?:[A-Z]{2}[0-9]{3}|[A-Z]{3}[0-9]{2}|[A-Z]{4}[0-9])',
          'cuatro_ruedas': r'(?:[A-Z]{2}[0-9]{4}|[A-Z]{4}[0-9]{2}|[A-Z]{5}[0-9])'}

@router.get('/catalogo/vehiculos')
def catalogo_vehiculos():
    return {'edicion':2026,'catalogo':CATALOGO,'formatos':PLACAS}

class VehiculoEntrada(BaseModel):
    tipo_vehiculo:Literal['automovil','camioneta','furgon','motocicleta','camion']='automovil'
    marca:str=Field(min_length=2,max_length=80)
    modelo:str=Field(min_length=1,max_length=100)
    patente:str=Field(min_length=4,max_length=16)
    color:str=Field(min_length=2,max_length=50)
    anio:int=Field(ge=1900,le=2100)
    @field_validator('marca','modelo','color',mode='before')
    @classmethod
    def limpiar_texto(cls,v):
        return ' '.join(v.split()) if isinstance(v,str) else v

    @model_validator(mode='after')
    def validar_registro(self):
        self.marca=self.marca.upper()
        self.modelo=self.modelo.upper()
        if self.modelo not in CATALOGO[self.tipo_vehiculo].get(self.marca, ()):
            raise ValueError('Selecciona una marca y un modelo del catálogo para ese tipo de vehículo.')
        self.patente=re.sub(r'[ .-]','',self.patente).upper()
        patron=PLACAS['motocicleta' if self.tipo_vehiculo=='motocicleta' else 'cuatro_ruedas']
        if not re.fullmatch(patron,self.patente):
            raise ValueError('La patente no corresponde al formato del tipo de vehículo seleccionado.')
        if self.anio>date.today().year+1:
            raise ValueError('Revisa el año de fabricación.')
        return self

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
    cur.execute('''INSERT INTO vehiculo(id_modelo,patente,color,anio,tipo_vehiculo)
        VALUES(%s,%s,%s,%s,%s) ON CONFLICT(pais,patente_normalizada) DO NOTHING''',
        (modelo,datos.patente,datos.color,datos.anio,datos.tipo_vehiculo))
    # La fila única serializa registros concurrentes y retiros de la misma patente.
    cur.execute("SELECT id_vehiculo FROM vehiculo WHERE pais='CL' AND patente_normalizada=%s FOR UPDATE",(datos.patente,))
    vid=cur.fetchone()[0]
    cur.execute("""SELECT 1 FROM vinculo_vehiculo WHERE id_vehiculo=%s
        AND estado IN ('pendiente','autorizado') AND fin IS NULL""",(vid,))
    if cur.fetchone():
        raise HTTPException(409,'La patente ya está vinculada a una cuenta. Su titular debe retirarla o solicitar revisión al operador.')
    cur.execute("SELECT 1 FROM caso WHERE id_vehiculo=%s AND estado<>'cerrado'",(vid,))
    if cur.fetchone():
        raise HTTPException(409,'El vehículo tiene un caso abierto. Solicita revisión al operador.')
    cur.execute('UPDATE vehiculo SET id_modelo=%s,color=%s,anio=%s,tipo_vehiculo=%s WHERE id_vehiculo=%s',
                (modelo,datos.color,datos.anio,datos.tipo_vehiculo,vid))
    cur.execute("INSERT INTO vinculo_vehiculo(id_usuario,id_vehiculo,tipo) VALUES(%s,%s,'propietario')",(usuario['id_usuario'],vid))
    return {'id_vehiculo':vid,'estado_vinculo':'pendiente','mensaje':'Vínculo declarado; no acredita propiedad.'}

@router.delete('/vehiculos/{vid}/vinculo',status_code=204)
def retirar_vehiculo(vid:int,usuario=Depends(participante),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    cur.execute('SELECT id_vehiculo FROM vehiculo WHERE id_vehiculo=%s FOR UPDATE',(vid,))
    if not cur.fetchone():raise HTTPException(404,'Vehículo no disponible')
    cur.execute("""SELECT id_vinculo_vehiculo FROM vinculo_vehiculo
        WHERE id_vehiculo=%s AND id_usuario=%s AND tipo='propietario'
        AND estado IN ('pendiente','autorizado') AND fin IS NULL""",(vid,usuario['id_usuario']))
    vinculos=[r[0] for r in cur.fetchall()]
    if not vinculos:raise HTTPException(403,'El vehículo no está vinculado a tu cuenta como propietario')
    cur.execute("SELECT 1 FROM caso WHERE id_vehiculo=%s AND estado<>'cerrado'",(vid,))
    if cur.fetchone():raise HTTPException(409,'Cierra el caso con el operador antes de retirar el vehículo.')
    cur.execute("""UPDATE vinculo_vehiculo SET estado='revocado',fin=CURRENT_TIMESTAMP,
        revisado_por=%s,revisado_en=CURRENT_TIMESTAMP,motivo_revision='Retiro voluntario por el titular'
        WHERE id_vehiculo=%s AND estado IN ('pendiente','autorizado') AND fin IS NULL""",
        (usuario['id_usuario'],vid))

@router.get('/vehiculos')
def mis_vehiculos(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    cur.execute('''SELECT v.id_vehiculo,v.tipo_vehiculo,v.patente,v.color,v.anio,ma.nombre AS marca,mo.nombre AS modelo,vv.estado AS estado_vinculo
       FROM vinculo_vehiculo vv JOIN vehiculo v USING(id_vehiculo) JOIN modelo mo USING(id_modelo)
       JOIN marca ma USING(id_marca) WHERE vv.id_usuario=%s AND vv.estado IN ('pendiente','autorizado') ORDER BY v.id_vehiculo DESC''',(usuario['id_usuario'],))
    return [fila_dict(cur,r) for r in cur.fetchall()]

@router.get('/mis-casos')
def mis_casos(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    cur.execute('''SELECT c.id_caso,c.folio,c.estado,c.zona,c.fecha_hecho,c.creado_en,c.denuncia_estado,v.patente,
       ST_Y(c.ubicacion::geometry) AS latitud, ST_X(c.ubicacion::geometry) AS longitud
       FROM caso c JOIN vehiculo v USING(id_vehiculo) WHERE c.id_usuario_reportante=%s ORDER BY c.creado_en DESC LIMIT 100''',(usuario['id_usuario'],))
    return [fila_dict(cur,r) for r in cur.fetchall()]

@router.get('/mi-perfil')
def perfil(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    cur.execute('''SELECT r.codigo FROM usuario_rol ur JOIN rol r USING(id_rol)
        WHERE ur.id_usuario=%s AND ur.revocado_en IS NULL''',(usuario['id_usuario'],))
    roles=[r[0] for r in cur.fetchall()]
    from ..seguridad import organizaciones_del_operador
    cur.execute("""SELECT COALESCE(modalidad_ciudadana, CASE WHEN EXISTS(SELECT 1 FROM vinculo_vehiculo v
        WHERE v.id_usuario=u.id_usuario AND v.estado IN ('autorizado','pendiente')) THEN 'con_vehiculo' ELSE 'colaborador' END)
        FROM usuario u WHERE id_usuario=%s""",(usuario['id_usuario'],))
    return {**usuario,'roles':roles,'modalidad_ciudadana':cur.fetchone()[0],'organizaciones':organizaciones_del_operador(cur,usuario['id_usuario'])}

class Modalidad(BaseModel):
    modalidad_ciudadana:Literal['colaborador','con_vehiculo']

@router.put('/mi-perfil/modalidad',status_code=204)
def cambiar_modalidad(d:Modalidad,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    conn.cursor().execute('UPDATE usuario SET modalidad_ciudadana=%s WHERE id_usuario=%s',(d.modalidad_ciudadana,usuario['id_usuario']))

class RevisionCaso(BaseModel):
    estado:str=Field(pattern='^(en_revision|en_gestion)$')
    motivo:str=Field(min_length=10,max_length=500)

@router.post('/gestion/casos/{id_caso}/revision')
def revision_caso(id_caso:int,datos:RevisionCaso,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
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
    from .colaboracion import bitacora,aviso
    bitacora(cur,id_caso,usuario['id_usuario'],'cambio_estado',datos.motivo,'afectado',fila[0],datos.estado)
    cur.execute('SELECT id_usuario_reportante FROM caso WHERE id_caso=%s',(id_caso,))
    aviso(cur,cur.fetchone()[0],id_caso,'Estado actualizado','Hay una actualización en el seguimiento.',f'estado:{id_caso}:{__import__("uuid").uuid4()}')
    return {'id_caso':id_caso,'estado':datos.estado,'publicado':False}
