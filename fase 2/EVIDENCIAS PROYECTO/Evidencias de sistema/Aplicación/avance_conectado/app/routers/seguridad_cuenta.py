"""TOTP RFC6238 con secreto cifrado, recuperación y prevención de repetición."""
import base64, hashlib, hmac, secrets, struct, time, uuid
from datetime import datetime, timedelta, timezone
from urllib.parse import quote
from cryptography.fernet import Fernet
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from ..antifraude import SECRET, limitar, limitar_ip
from ..db import obtener_conexion, fila_dict
from ..seguridad import usuario_actual, verificar_clave, cifrar_clave, emitir_token, huella
from ..config import config

router=APIRouter(tags=['seguridad de cuenta'])
def caja():
    # Derivación con separación de dominio; OTP_SECRET estable sólo en servidor.
    return Fernet(base64.urlsafe_b64encode(hmac.new(SECRET,b'rutaalerta:totp:encryption:v1',hashlib.sha256).digest()))

def codigo_totp(secret,paso,digitos=6):
    digest=hmac.new(base64.b32decode(secret),struct.pack('>Q',paso),hashlib.sha1).digest()
    offset=digest[-1]&15
    return str((struct.unpack('>I',digest[offset:offset+4])[0]&0x7fffffff)%(10**digitos)).zfill(digitos)

def validar_factor(cur,uid,codigo):
    cur.execute('SELECT secreto_cifrado,ultimo_paso FROM autenticador_totp WHERE id_usuario=%s AND activo FOR UPDATE',(uid,))
    row=cur.fetchone()
    if not row:return False
    if len(codigo)==6 and codigo.isascii() and codigo.isdigit():
        secret=caja().decrypt(row[0].encode()).decode()
        now=int(time.time())//30
        for step in [now,now-1,now+1]:
            if step>row[1] and hmac.compare_digest(codigo_totp(secret,step),codigo):
                cur.execute('UPDATE autenticador_totp SET ultimo_paso=%s WHERE id_usuario=%s',(step,uid))
                return True
    else:
        cur.execute('UPDATE recuperacion_mfa SET consumido_en=CURRENT_TIMESTAMP WHERE id_usuario=%s AND codigo_hash=%s AND consumido_en IS NULL RETURNING id_usuario',(uid,huella(codigo.strip().upper())))
        if cur.fetchone():return True
    return False

def clave_actual(cur,uid,clave):
    cur.execute('SELECT password_hash,estado FROM usuario WHERE id_usuario=%s FOR UPDATE',(uid,))
    row=cur.fetchone()
    if not row or row[1] in ('suspendido','anonimizado') or not verificar_clave(clave,row[0]):
        raise HTTPException(403,'No fue posible confirmar la contraseña actual')

class Clave(BaseModel):
    clave:str=Field(min_length=1,max_length=128)
class Factor(BaseModel):
    codigo:str=Field(min_length=6,max_length=80)
class Desafio(Factor):
    id_desafio:uuid.UUID
class Desactivar(Clave,Factor):pass
class CambiarClave(Clave):
    nueva_clave:str=Field(min_length=12,max_length=128)
    codigo:str=Field(default='',max_length=80)

@router.get('/seguridad/estado')
def estado(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();cur.execute('SELECT activo FROM autenticador_totp WHERE id_usuario=%s',(usuario['id_usuario'],));row=cur.fetchone()
    return {'mfa_activo':bool(row and row[0]),'metodo':'TOTP','correo_sms':'Depende del proveedor configurado; TOTP no envía mensajes.'}

@router.post('/seguridad/totp/preparar')
def preparar(datos:Clave,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    uid=usuario['id_usuario'];limitar(conn,f'totp-alta:{uid}',5)
    cur=conn.cursor();clave_actual(cur,uid,datos.clave)
    cur.execute('SELECT activo FROM autenticador_totp WHERE id_usuario=%s',(uid,));row=cur.fetchone()
    if row and row[0]:raise HTTPException(409,'Ya hay un autenticador activo')
    secret=base64.b32encode(secrets.token_bytes(20)).decode()
    cur.execute('''INSERT INTO autenticador_totp(id_usuario,secreto_cifrado) VALUES(%s,%s)
      ON CONFLICT(id_usuario) DO UPDATE SET secreto_cifrado=EXCLUDED.secreto_cifrado,vence_alta_en=CURRENT_TIMESTAMP+interval '10 minutes',ultimo_paso=-1''',(uid,caja().encrypt(secret.encode()).decode()))
    return {'secreto':secret,'uri':f'otpauth://totp/{quote("RutaAlerta:"+str(uid))}?secret={secret}&issuer=RutaAlerta&digits=6&period=30','mensaje':'Guarda la clave en tu aplicación autenticadora y confirma un código. No compartas esta clave.'}

@router.post('/seguridad/totp/activar')
def activar(datos:Factor,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    uid=usuario['id_usuario'];limitar(conn,f'totp-confirmar:{uid}',5)
    cur=conn.cursor();cur.execute('SELECT estado FROM usuario WHERE id_usuario=%s FOR UPDATE',(uid,))
    if cur.fetchone()[0] in ('suspendido','anonimizado'):raise HTTPException(403,'Cuenta restringida')
    cur.execute('SELECT secreto_cifrado FROM autenticador_totp WHERE id_usuario=%s AND NOT activo AND vence_alta_en>CURRENT_TIMESTAMP FOR UPDATE',(uid,));row=cur.fetchone()
    if not row:raise HTTPException(400,'Solicita una configuración nueva')
    secret=caja().decrypt(row[0].encode()).decode();now=int(time.time())//30
    matches=[p for p in [now,now-1,now+1] if hmac.compare_digest(codigo_totp(secret,p),datos.codigo)]
    if not matches:raise HTTPException(400,'Código incorrecto o vencido')
    cur.execute('UPDATE autenticador_totp SET activo=true,ultimo_paso=%s WHERE id_usuario=%s',(matches[0],uid))
    codes=[secrets.token_hex(8).upper() for _ in range(8)]
    cur.execute('UPDATE recuperacion_mfa SET consumido_en=CURRENT_TIMESTAMP WHERE id_usuario=%s AND consumido_en IS NULL',(uid,))
    for code in codes:cur.execute('INSERT INTO recuperacion_mfa(id_usuario,codigo_hash) VALUES(%s,%s)',(uid,huella(code)))
    cur.execute("UPDATE token_acceso SET revocado_en=CURRENT_TIMESTAMP WHERE id_usuario=%s AND proposito='sesion' AND revocado_en IS NULL",(uid,))
    return {'codigos_recuperacion':codes,'mensaje':'Segundo factor activado. Guarda estos códigos una sola vez y vuelve a ingresar. Cada código permite un acceso.'}

@router.post('/sesiones/mfa',status_code=201)
def completar(datos:Desafio,request:Request,conn=Depends(obtener_conexion)):
    limitar_ip(conn,request,'mfa',30)
    cur=conn.cursor();cur.execute('SELECT id_usuario FROM desafio_mfa WHERE id_desafio=%s',(str(datos.id_desafio),));row=cur.fetchone()
    if not row:raise HTTPException(400,'Desafío inválido o vencido')
    uid=row[0];cur.execute('SELECT estado FROM usuario WHERE id_usuario=%s FOR UPDATE',(uid,))
    if cur.fetchone()[0] in ('suspendido','anonimizado'):raise HTTPException(403,'Cuenta restringida')
    cur.execute('''UPDATE desafio_mfa SET intentos=intentos+1 WHERE id_desafio=%s AND consumido_en IS NULL AND vence_en>CURRENT_TIMESTAMP AND intentos<5 RETURNING intentos''',(str(datos.id_desafio),))
    if not cur.fetchone():raise HTTPException(400,'Desafío inválido, vencido o agotado')
    if not validar_factor(cur,uid,datos.codigo):
        conn.commit();raise HTTPException(400,'Código incorrecto, utilizado o vencido')
    cur.execute('UPDATE desafio_mfa SET consumido_en=CURRENT_TIMESTAMP WHERE id_desafio=%s',(str(datos.id_desafio),))
    token,vence=emitir_token(cur,uid,'sesion',config.sesion_horas*60)
    return {'token':token,'vence_en':vence,'requiere_mfa':False}

@router.post('/seguridad/totp/desactivar',status_code=204)
def desactivar(datos:Desactivar,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    uid=usuario['id_usuario'];limitar(conn,f'totp-baja:{uid}',5);cur=conn.cursor();clave_actual(cur,uid,datos.clave)
    if not validar_factor(cur,uid,datos.codigo):raise HTTPException(400,'Código incorrecto, utilizado o vencido')
    cur.execute('UPDATE autenticador_totp SET activo=false WHERE id_usuario=%s',(uid,));cur.execute('UPDATE recuperacion_mfa SET consumido_en=CURRENT_TIMESTAMP WHERE id_usuario=%s AND consumido_en IS NULL',(uid,))
    cur.execute('UPDATE desafio_mfa SET consumido_en=CURRENT_TIMESTAMP WHERE id_usuario=%s',(uid,))
    cur.execute("UPDATE token_acceso SET revocado_en=CURRENT_TIMESTAMP WHERE id_usuario=%s AND proposito='sesion'",(uid,))

@router.post('/seguridad/clave',status_code=204)
def cambiar_clave(datos:CambiarClave,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    uid=usuario['id_usuario'];limitar(conn,f'clave:{uid}',5);cur=conn.cursor();clave_actual(cur,uid,datos.clave)
    cur.execute('SELECT 1 FROM autenticador_totp WHERE id_usuario=%s AND activo',(uid,))
    if cur.fetchone() and not validar_factor(cur,uid,datos.codigo):raise HTTPException(400,'Confirma el segundo factor')
    cur.execute('UPDATE usuario SET password_hash=%s WHERE id_usuario=%s',(cifrar_clave(datos.nueva_clave),uid))
    cur.execute('UPDATE token_acceso SET revocado_en=CURRENT_TIMESTAMP WHERE id_usuario=%s AND revocado_en IS NULL',(uid,))
    cur.execute('UPDATE desafio_mfa SET consumido_en=CURRENT_TIMESTAMP WHERE id_usuario=%s',(uid,))

@router.get('/seguridad/sesiones')
def sesiones(request:Request,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    current=huella(request.headers['authorization'].split(' ',1)[1].strip());cur=conn.cursor()
    cur.execute("SELECT id_token_acceso,creado_en,vence_en,(token_hash=%s) AS actual FROM token_acceso WHERE id_usuario=%s AND proposito='sesion' AND revocado_en IS NULL AND vence_en>CURRENT_TIMESTAMP ORDER BY creado_en DESC",(current,usuario['id_usuario']))
    return [fila_dict(cur,r) for r in cur.fetchall()]

@router.post('/seguridad/sesiones/cerrar-otras',status_code=204)
def cerrar_otras(request:Request,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    current=huella(request.headers['authorization'].split(' ',1)[1].strip())
    conn.cursor().execute("UPDATE token_acceso SET revocado_en=CURRENT_TIMESTAMP WHERE id_usuario=%s AND proposito='sesion' AND token_hash<>%s AND revocado_en IS NULL",(usuario['id_usuario'],current))
