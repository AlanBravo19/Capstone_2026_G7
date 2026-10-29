"""Incremento de identidad. Códigos devueltos sólo en demo explícita, no SMS reales."""
import re
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Literal
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field, field_validator
from ..antifraude import DEMO, administrador, limitar, limitar_ip, resumen, participante
from ..correo import correo_real, enviar_codigo, CorreoNoDisponible
from ..db import obtener_conexion, ErrorBD, es_unico
from ..seguridad import usuario_actual, emitir_token, huella

router=APIRouter(tags=['identidad MVP'])

class TokenEntrada(BaseModel):
    token: str = Field(min_length=20,max_length=200)

class TelefonoEntrada(BaseModel):
    telefono: str
    @field_validator('telefono')
    @classmethod
    def normalizar(cls,v):
        v=re.sub(r'[\s()-]', '', v)
        if not re.fullmatch(r'\+[1-9]\d{7,14}',v, flags=re.ASCII):
            raise ValueError('Usa formato internacional, por ejemplo +56912345678')
        return v

class CodigoEntrada(BaseModel):
    id_desafio: uuid.UUID
    codigo: str=Field(pattern=r'^[0-9]{6}$')

class SancionEntrada(BaseModel):
    accion: Literal['suspension','bloqueo']
    motivo: str=Field(min_length=10,max_length=1000)

@router.post('/identidad/correo/solicitar',status_code=202)
def solicitar_correo(request: Request, usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    limitar_ip(conn,request,'correo',30)
    limitar(conn,f'correo:{usuario["id_usuario"]}',3)
    cur=conn.cursor()
    cur.execute('SELECT correo_verificado_en FROM usuario WHERE id_usuario=%s FOR UPDATE',(usuario['id_usuario'],))
    correo=cur.fetchone()[0]
    cur.execute('SELECT estado FROM usuario WHERE id_usuario=%s',(usuario['id_usuario'],))
    if cur.fetchone()[0] in ('suspendido','anonimizado'):raise HTTPException(403,'Cuenta restringida')
    if correo is not None:
        return {'mensaje':'El correo ya está verificado.'}
    cur.execute("UPDATE token_acceso SET revocado_en=CURRENT_TIMESTAMP WHERE id_usuario=%s AND proposito='verificar_correo' AND revocado_en IS NULL",(usuario['id_usuario'],))
    token,_=emitir_token(cur,usuario['id_usuario'],'verificar_correo',15)
    if correo_real():
        cur.execute('SELECT correo FROM usuario WHERE id_usuario=%s', (usuario['id_usuario'],))
        try:
            enviar_codigo(cur.fetchone()[0], token, 'verificar_correo', 15)
        except CorreoNoDisponible:
            raise HTTPException(503, 'No fue posible enviar el correo. Intenta más tarde.') from None
        return {'mensaje':'Revisa tu correo e ingresa el código recibido.', 'canal':'correo'}
    if not DEMO:
        raise HTTPException(503, 'El servicio de correo todavía no está disponible.')
    return {'mensaje':'Entrega simulada. No se envió un correo.', 'token_demo':token, 'canal':'prueba'}

@router.post('/identidad/correo/confirmar')
def confirmar_correo(datos:TokenEntrada,request:Request,conn=Depends(obtener_conexion)):
    limitar_ip(conn,request,'confirmar_correo',30)
    cur=conn.cursor()
    # Bloquear primero la cuenta, como el proceso de sanción, para evitar carreras.
    cur.execute("SELECT id_usuario FROM token_acceso WHERE token_hash=%s AND proposito='verificar_correo'",(huella(datos.token),))
    fila=cur.fetchone()
    if fila is None:raise HTTPException(400,'Token inválido o vencido')
    cur.execute('SELECT estado FROM usuario WHERE id_usuario=%s FOR UPDATE',(fila[0],))
    if cur.fetchone()[0] in ('suspendido','anonimizado'):raise HTTPException(403,'Cuenta restringida')
    cur.execute("""UPDATE token_acceso SET consumido_en=CURRENT_TIMESTAMP
        WHERE token_hash=%s AND proposito='verificar_correo' AND consumido_en IS NULL
        AND revocado_en IS NULL AND vence_en>CURRENT_TIMESTAMP RETURNING id_usuario""",(huella(datos.token),))
    if cur.fetchone() is None:raise HTTPException(400,'Token inválido, vencido o ya utilizado')
    cur.execute('UPDATE usuario SET correo_verificado_en=CURRENT_TIMESTAMP,actualizado_en=CURRENT_TIMESTAMP WHERE id_usuario=%s',(fila[0],))
    return {'mensaje':'Correo verificado. Esto no acredita identidad civil.'}

@router.post('/identidad/telefono/solicitar',status_code=202)
def solicitar_telefono(datos:TelefonoEntrada,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    if not DEMO:
        raise HTTPException(503, 'La verificación SMS real todavía no está disponible.')
    limitar(conn,f'sms:{usuario["id_usuario"]}',3)
    limitar(conn,'sms-numero:'+datos.telefono,5)
    cur=conn.cursor()
    cur.execute('SELECT correo_verificado_en,estado FROM usuario WHERE id_usuario=%s FOR UPDATE',(usuario['id_usuario'],))
    correo,estado=cur.fetchone()
    if estado in ('suspendido','anonimizado'):raise HTTPException(403,'Cuenta restringida')
    if correo is None:raise HTTPException(403,'Primero verifica el correo')
    cur.execute('SELECT 1 FROM contacto_telefono WHERE id_usuario=%s',(usuario['id_usuario'],))
    if cur.fetchone():raise HTTPException(409,'Ya existe un teléfono. El cambio asistido aún no está implementado.')
    # No reservar números antes de probar su control: evita apropiación por registro.
    cur.execute('UPDATE desafio_telefono SET consumido_en=CURRENT_TIMESTAMP WHERE id_usuario=%s AND consumido_en IS NULL',(usuario['id_usuario'],))
    idd=str(uuid.uuid4());codigo=f'{secrets.randbelow(1000000):06d}'
    cur.execute('''INSERT INTO desafio_telefono(id_desafio,id_usuario,telefono,codigo_hmac,vence_en)
        VALUES(%s::uuid,%s,%s,%s,%s)''',(idd,usuario['id_usuario'],datos.telefono,resumen(idd+':'+codigo),datetime.now(timezone.utc)+timedelta(minutes=5)))
    return {'id_desafio':idd,'mensaje':'DEMO: código simulado. No se envió un SMS.', 'codigo_demo':codigo if DEMO else None}

@router.post('/identidad/telefono/confirmar')
def confirmar_telefono(datos:CodigoEntrada,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    limitar(conn,f'confirmar_sms:{usuario["id_usuario"]}',10)
    cur=conn.cursor()
    cur.execute('SELECT estado FROM usuario WHERE id_usuario=%s FOR UPDATE',(usuario['id_usuario'],))
    if cur.fetchone()[0] in ('suspendido','anonimizado'):raise HTTPException(403,'Cuenta restringida')
    cur.execute('''SELECT telefono,codigo_hmac,intentos FROM desafio_telefono
        WHERE id_desafio=%s::uuid AND id_usuario=%s AND consumido_en IS NULL
        AND vence_en>CURRENT_TIMESTAMP FOR UPDATE''',(str(datos.id_desafio),usuario['id_usuario']))
    fila=cur.fetchone()
    if fila is None or fila[2]>=5:raise HTTPException(400,'Código inválido, vencido o agotado')
    if not secrets.compare_digest(bytes(fila[1]),resumen(str(datos.id_desafio)+':'+datos.codigo)):
        cur.execute('UPDATE desafio_telefono SET intentos=intentos+1 WHERE id_desafio=%s::uuid',(str(datos.id_desafio),))
        conn.commit() # El fallo debe persistir aunque se responda HTTP 400.
        raise HTTPException(400,'Código inválido, vencido o agotado')
    try:
        cur.execute('INSERT INTO contacto_telefono(id_usuario,telefono) VALUES(%s,%s)',(usuario['id_usuario'],fila[0]))
    except ErrorBD as e:
        if es_unico(e):
            raise HTTPException(409,'No se puede asociar este contacto. Solicita revisión o recuperación de cuenta.')
        raise
    cur.execute('UPDATE desafio_telefono SET consumido_en=CURRENT_TIMESTAMP WHERE id_desafio=%s::uuid',(str(datos.id_desafio),))
    cur.execute("UPDATE usuario SET estado='activo',actualizado_en=CURRENT_TIMESTAMP WHERE id_usuario=%s",(usuario['id_usuario'],))
    return {'mensaje':'Teléfono verificado; participación habilitada. No certifica identidad civil.'}

@router.get('/identidad/mi-estado')
def mi_estado(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    cur.execute('''SELECT u.estado,u.correo_verificado_en IS NOT NULL,t.id_usuario IS NOT NULL
        FROM usuario u LEFT JOIN contacto_telefono t USING(id_usuario) WHERE u.id_usuario=%s''',(usuario['id_usuario'],))
    estado,correo,telefono=cur.fetchone()
    return {'estado':estado,'correo_verificado':correo,'telefono_verificado':telefono,
            'puede_participar':estado=='activo' and correo and telefono,'canales_demo':DEMO, 'transporte_correo':'smtp' if correo_real() else 'prueba'}

@router.post('/sesiones/cerrar',status_code=204)
def cerrar(request:Request,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    conn.cursor().execute('UPDATE token_acceso SET revocado_en=CURRENT_TIMESTAMP WHERE token_hash=%s',
        (huella(request.headers['authorization'].split(' ',1)[1].strip()),))

@router.post('/moderacion/usuarios/{id_usuario}/sanciones',status_code=201)
def sancionar(id_usuario:int,datos:SancionEntrada,admin=Depends(administrador),conn=Depends(obtener_conexion)):
    if id_usuario==admin['id_usuario']:raise HTTPException(400,'No puedes sancionarte a ti mismo')
    cur=conn.cursor()
    cur.execute('SELECT estado FROM usuario WHERE id_usuario=%s FOR UPDATE',(id_usuario,))
    fila=cur.fetchone()
    if fila is None:raise HTTPException(404,'Cuenta no encontrada')
    if fila[0]=='anonimizado':raise HTTPException(409,'Cuenta anonimizada: requiere revisión específica')
    cur.execute('''INSERT INTO moderacion_usuario(id_usuario_afectado,id_usuario_revisor,accion,motivo)
        VALUES(%s,%s,%s,%s) RETURNING id_moderacion_usuario''',(id_usuario,admin['id_usuario'],datos.accion,datos.motivo))
    mid=cur.fetchone()[0]
    cur.execute("UPDATE usuario SET estado='suspendido',actualizado_en=CURRENT_TIMESTAMP WHERE id_usuario=%s",(id_usuario,))
    cur.execute('UPDATE token_acceso SET revocado_en=CURRENT_TIMESTAMP WHERE id_usuario=%s AND revocado_en IS NULL',(id_usuario,))
    cur.execute('UPDATE desafio_telefono SET consumido_en=CURRENT_TIMESTAMP WHERE id_usuario=%s AND consumido_en IS NULL',(id_usuario,))
    return {'id_moderacion':mid,'estado':'suspendido','sesiones_revocadas':True}
