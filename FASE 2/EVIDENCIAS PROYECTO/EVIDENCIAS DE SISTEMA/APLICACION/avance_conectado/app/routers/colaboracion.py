"""Colaboración revisada, seguimiento, fotos privadas y avisos internos persistentes."""
import hashlib, uuid
from datetime import datetime, timezone
from typing import Literal
from fastapi import APIRouter, Depends, HTTPException, Query, Response, Header
from pydantic import BaseModel, Field, model_validator
from ..db import obtener_conexion, fila_dict
from ..seguridad import usuario_actual, organizaciones_del_operador
from ..antifraude import DEMO, participante, limitar
from ..alertas import VIGENTE, entorno, vinculo_vigente
from ..config import config
from ..imagenes import limpiar_imagen

router=APIRouter(tags=['colaboración y seguimiento'])
def rows(cur):return [fila_dict(cur,r) for r in cur.fetchall()]
def caso_autorizado(cur,cid,usuario,operador=False,propietario=False):
    cur.execute('SELECT id_caso,id_usuario_reportante,id_organizacion,estado,folio,colaboracion_consentida_en FROM caso WHERE id_caso=%s FOR UPDATE',(cid,));c=fila_dict(cur,cur.fetchone())
    if not c:raise HTTPException(404,'Caso no disponible')
    own=c['id_usuario_reportante']==usuario['id_usuario']
    org=c['id_organizacion'] in organizaciones_del_operador(cur,usuario['id_usuario'])
    if (operador and not org) or (propietario and not own) or (not operador and not propietario and not (own or org)):
        raise HTTPException(403,'Caso fuera del ámbito autorizado')
    return c

def bloquear_participante(cur,uid):
    from ..correo import correo_real
    if correo_real():
        cur.execute("SELECT 1 FROM usuario u WHERE u.id_usuario=%s AND u.estado='activo' AND u.correo_verificado_en IS NOT NULL AND u.canal_correo_verificado IN ('smtp','brevo') AND (EXISTS(SELECT 1 FROM autenticador_totp a WHERE a.id_usuario=u.id_usuario AND a.activo) OR EXISTS(SELECT 1 FROM contacto_telefono t WHERE t.id_usuario=u.id_usuario AND t.canal_verificado='sms')) FOR UPDATE OF u",(uid,))
    else:
        cur.execute("SELECT 1 FROM usuario u JOIN contacto_telefono t USING(id_usuario) WHERE u.id_usuario=%s AND u.estado='activo' AND u.correo_verificado_en IS NOT NULL FOR UPDATE OF u",(uid,))
    if not cur.fetchone():raise HTTPException(403,'Cuenta restringida: revisa correo y autenticador')

def aviso(cur,uid,cid,titulo,texto,clave):
    tipo='general' if cid is None else 'caso'
    cur.execute('''INSERT INTO notificacion(id_usuario,id_caso,tipo,titulo,mensaje,clave_deduplicacion) VALUES(%s,%s,%s,%s,%s,%s) ON CONFLICT(id_usuario,clave_deduplicacion) DO NOTHING''',(uid,cid,tipo,titulo,texto,clave))
def bitacora(cur,cid,uid,accion,texto,visible='afectado',anterior=None,nuevo=None):
    cur.execute('''INSERT INTO gestion_caso(id_caso,id_usuario,accion,descripcion,visibilidad,estado_anterior,estado_nuevo) VALUES(%s,%s,%s,%s,%s,%s,%s)''',(cid,uid,accion,texto,visible,anterior,nuevo))

@router.get('/organizaciones')
def organizaciones(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();cur.execute("SELECT id_organizacion,nombre,tipo,territorio_cobertura FROM organizacion WHERE estado='activa' ORDER BY nombre");return rows(cur)

@router.get('/seguimiento/compartidos')
def compartidos(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();cur.execute('''SELECT c.id_caso,c.folio,c.estado,c.zona FROM acceso_confianza a JOIN caso c USING(id_caso) WHERE a.id_usuario_destinatario=%s AND a.revocado_en IS NULL AND a.vence_en>CURRENT_TIMESTAMP ORDER BY a.autorizado_en DESC''',(usuario['id_usuario'],));return rows(cur)

@router.get('/seguimiento/{cid}')
def seguimiento(cid:int,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    uid=usuario['id_usuario'];cur=conn.cursor()
    cur.execute('SELECT id_usuario_reportante,id_organizacion FROM caso WHERE id_caso=%s',(cid,));r=cur.fetchone()
    if not r:raise HTTPException(404,'Caso no disponible')
    own=r[0]==uid;org=r[1] in organizaciones_del_operador(cur,uid)
    cur.execute('SELECT 1 FROM acceso_confianza WHERE id_caso=%s AND id_usuario_destinatario=%s AND revocado_en IS NULL AND vence_en>CURRENT_TIMESTAMP',(cid,uid));trusted=cur.fetchone() is not None
    if not (own or org or trusted):raise HTTPException(403,'Sin permiso para este seguimiento')
    cur.execute('''SELECT c.id_caso,c.folio,c.estado,c.zona,c.denuncia_estado,c.motivo_cierre,c.fecha_hecho,c.creado_en,c.colaboracion_consentida_en,v.patente FROM caso c JOIN vehiculo v USING(id_vehiculo) WHERE c.id_caso=%s''',(cid,));c=fila_dict(cur,cur.fetchone())
    cur.execute("SELECT accion,descripcion,creada_en,estado_nuevo FROM gestion_caso WHERE id_caso=%s AND visibilidad='afectado' ORDER BY creada_en,id_gestion_caso",(cid,));timeline=rows(cur)
    c['es_propietario']=own;c['es_operador']=org;c['historial']=timeline
    if own or org:
        from .alertas import resumen_alerta
        estado_alerta=resumen_alerta(cur,cid)
        ultima=estado_alerta['alerta']
        if c['estado']=='cerrado': paso='Caso cerrado'
        elif ultima and ultima['visible']:
            paso={'provisional':'Alerta ciudadana provisional activa',
                  'encargo_comprobado':'Activa con encargo comprobado',
                  'revisada':'Publicada en Colaborar'}[ultima['modo_alerta']]
        elif ultima and ultima['suspendida_en']: paso='Alerta suspendida'
        elif ultima and ultima['estado']=='publicada' and ultima['vence_en']>datetime.now(timezone.utc):
            paso='Alerta suspendida por pérdida de condiciones'
        elif ultima: paso='Publicación retirada o vencida'
        elif c['colaboracion_consentida_en']: paso='Pendiente de publicación por el operador'
        else: paso='Pendiente de autorización del titular'
        c['estado_colaboracion']=paso
        c['alerta']=ultima
        if org:
            c.update(estado_alerta)
        elif estado_alerta['consultas_encargo']:
            consulta=estado_alerta['consultas_encargo'][0]
            c['encargo']={k:consulta[k] for k in ('resultado','consultada_en','simulada')}
    if org:
        cur.execute('SELECT descripcion_privada FROM caso WHERE id_caso=%s',(cid,))
        c['relato_para_revision']=cur.fetchone()[0]
    if own or org:
        cur.execute('''SELECT a.id_avistamiento,a.zona,a.observado_en,a.estado_revision,a.resumen_para_afectado FROM avistamiento a WHERE a.id_caso=%s AND a.estado_revision='aceptado' AND a.resumen_para_afectado IS NOT NULL ORDER BY observado_en DESC''',(cid,));c['aportes']=rows(cur)
        cur.execute('''SELECT e.id_evidencia,e.estado_revision,e.mime,e.tamano_bytes,e.autorizada_publicacion_en
            FROM evidencia e WHERE e.id_caso=%s AND e.id_avistamiento IS NULL
            AND NOT EXISTS(SELECT 1 FROM consulta_encargo q WHERE q.id_evidencia=e.id_evidencia)
            ORDER BY creada_en DESC''',(cid,));c['evidencias']=rows(cur)
    return c

@router.post('/mis-casos/{cid}/colaboracion')
def consentir(cid:int,usuario=Depends(participante),conn=Depends(obtener_conexion)):
    cur=conn.cursor();c=caso_autorizado(cur,cid,usuario,propietario=True)
    if c['estado']=='cerrado':raise HTTPException(409,'Caso cerrado')
    cur.execute("SELECT 1 FROM gestion_caso WHERE id_caso=%s AND accion='informar_recuperacion'",(cid,))
    if cur.fetchone():raise HTTPException(409,'La recuperación informada debe ser revisada por la organización.')
    cur.execute('UPDATE caso SET colaboracion_consentida_en=CURRENT_TIMESTAMP WHERE id_caso=%s',(cid,))
    bitacora(cur,cid,usuario['id_usuario'],'solicitar_colaboracion','El afectado autorizó solicitar colaboración. Publicación pendiente de revisión humana.')
    return {'mensaje':'Solicitud de colaboración pendiente de revisión; todavía no está publicada.'}

class Publicacion(BaseModel):
    revision:int|None=Field(default=None,ge=0)
    id_foto_vehiculo:int|None=Field(default=None,gt=0)
    zona:str=Field(min_length=3,max_length=200)
    texto:str=Field(min_length=15,max_length=1500)
    motivo:str=Field(min_length=10,max_length=500)
    horas:int=Field(default=24,ge=1,le=72)

@router.post('/gestion/casos/{cid}/publicacion',status_code=201)
def publicar(cid:int,datos:Publicacion,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();c=caso_autorizado(cur,cid,usuario,operador=True)
    if c['estado'] not in ('en_revision','en_gestion') or not c['colaboracion_consentida_en']:
        raise HTTPException(409,'Se requiere revisión del caso y consentimiento del afectado')
    cur.execute("SELECT id_vehiculo,revision_alerta,sustraccion_declarada_en,entorno FROM caso WHERE id_caso=%s",(cid,))
    vid,rev,declarado,ambiente=cur.fetchone()
    if (declarado is not None or datos.revision is not None) and datos.revision!=rev:
        raise HTTPException(409,'Otro operador actualizó el expediente. Recarga antes de publicar.')
    vinculo=None
    if declarado is not None:
        cur.execute('SELECT id_vehiculo FROM vehiculo WHERE id_vehiculo=%s FOR UPDATE',(vid,))
        vinculo=vinculo_vigente(cur,c['id_usuario_reportante'],vid,c['id_organizacion'])
        if not vinculo:raise HTTPException(409,'Revisa y aprueba primero el vínculo con el vehículo.')
        cur.execute(f"""SELECT 1 FROM solicitud_colaboracion s JOIN caso c USING(id_caso)
            WHERE c.id_vehiculo=%s AND c.entorno=%s AND c.id_caso<>%s AND {VIGENTE}""",(vid,ambiente,cid))
        if cur.fetchone():raise HTTPException(409,'Ya existe otra alerta activa para este vehículo.')
        cur.execute("""SELECT resultado,consultada_en>CURRENT_TIMESTAMP-interval '24 hours'
            FROM consulta_encargo WHERE id_caso=%s ORDER BY id_consulta_encargo DESC LIMIT 1""",(cid,))
        consulta=cur.fetchone()
        if not consulta or consulta!=('encontrado',True):
            raise HTTPException(409,'Registra una consulta reciente con encargo encontrado antes de publicar.')
    if datos.id_foto_vehiculo is not None:
        cur.execute(f'''SELECT 1 FROM evidencia e JOIN archivo_evidencia f USING(id_evidencia)
            JOIN caso c ON c.id_caso=e.id_caso
            WHERE e.id_evidencia=%s AND c.id_caso=%s AND {FOTO_PUBLICABLE}''',(datos.id_foto_vehiculo,cid))
        if not cur.fetchone():raise HTTPException(422,'Foto no elegible: requiere foto del reportante, aceptada y con consentimiento explícito')
    cur.execute("UPDATE solicitud_colaboracion SET estado='vencida' WHERE id_caso=%s AND estado='publicada' AND vence_en<=CURRENT_TIMESTAMP",(cid,))
    cur.execute("SELECT 1 FROM solicitud_colaboracion WHERE id_caso=%s AND estado='publicada' AND suspendida_en IS NULL",(cid,))
    if cur.fetchone():raise HTTPException(409,'Ya existe una publicación vigente')
    cur.execute("""UPDATE solicitud_colaboracion SET estado='retirada',retirada_en=CURRENT_TIMESTAMP,
        motivo_retiro='Reemplazada por decisión institucional posterior'
        WHERE id_caso=%s AND estado='publicada' AND suspendida_en IS NOT NULL""",(cid,))
    # Centro territorial redondeado (~2 km), nunca la coordenada privada del afectado.
    cur.execute('''INSERT INTO solicitud_colaboracion(id_caso,autorizada_por,zona_publicable,texto_aprobado,motivo_autorizacion,inicio,vence_en,centro_publico,id_foto_vehiculo,modo_alerta,id_vinculo_verificado)
      SELECT id_caso,%s,%s,%s,%s,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP+(%s*interval '1 hour'),ST_SnapToGrid(ubicacion::geometry,0.02)::geography,%s,%s,%s FROM caso WHERE id_caso=%s RETURNING id_solicitud_colaboracion''',(usuario['id_usuario'],datos.zona,datos.texto,datos.motivo,datos.horas,datos.id_foto_vehiculo,'encargo_comprobado' if vinculo else 'revisada',vinculo,cid));sid=cur.fetchone()[0]
    cur.execute("UPDATE caso SET revision_alerta=revision_alerta+1 WHERE id_caso=%s",(cid,))
    bitacora(cur,cid,usuario['id_usuario'],'publicacion','Se publicó una solicitud de colaboración con datos mínimos revisados.')
    aviso(cur,c['id_usuario_reportante'],cid,'Colaboración publicada','Tu solicitud ya está disponible para colaboradores.',f'publicacion:{sid}')
    return {'id_solicitud_colaboracion':sid}

class Motivo(BaseModel):
    motivo:str=Field(min_length=10,max_length=500)
    revision:int|None=Field(default=None,ge=0)
@router.post('/gestion/casos/{cid}/retirar',status_code=204)
def retirar(cid:int,datos:Motivo,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();caso_autorizado(cur,cid,usuario,operador=True)
    cur.execute('SELECT revision_alerta FROM caso WHERE id_caso=%s',(cid,))
    if datos.revision is not None and cur.fetchone()[0]!=datos.revision:
        raise HTTPException(409,'El expediente cambió. Recarga antes de retirar.')
    cur.execute("UPDATE solicitud_colaboracion SET estado='retirada',retirada_en=CURRENT_TIMESTAMP,motivo_retiro=%s WHERE id_caso=%s AND estado='publicada'",(datos.motivo,cid))
    bitacora(cur,cid,usuario['id_usuario'],'retirar_publicacion',datos.motivo,'interna')
    cur.execute("UPDATE caso SET revision_alerta=revision_alerta+1 WHERE id_caso=%s",(cid,))

# Shared by selection, listing and download so revocation/review changes apply immediately.
FOTO_PUBLICABLE="""e.id_caso=c.id_caso AND e.id_usuario_autor=c.id_usuario_reportante
    AND e.id_avistamiento IS NULL AND e.tipo='foto' AND e.mime='image/jpeg'
    AND e.estado_revision='aceptada' AND e.estado_carga='recibido' AND e.recibida_en IS NOT NULL
    AND e.autorizada_publicacion_en IS NOT NULL AND octet_length(f.contenido)>0"""
SOLICITUD_VIGENTE=VIGENTE

def colaboraciones_publicas(cur,uid,lat=None,lon=None,zona='',sid=None):
    cur.execute(f'''SELECT s.id_solicitud_colaboracion,s.zona_publicable,s.texto_aprobado,s.vence_en,v.patente,v.color,v.tipo_vehiculo,ma.nombre AS marca,m.nombre AS modelo,
        c.id_usuario_reportante=%s AS es_mi_caso,
        s.modo_alerta,c.creado_en AS reportada_en,
        (SELECT resultado FROM consulta_encargo q WHERE q.id_caso=c.id_caso
            ORDER BY q.id_consulta_encargo DESC LIMIT 1) AS encargo_resultado,
        (SELECT simulada FROM consulta_encargo q WHERE q.id_caso=c.id_caso
            ORDER BY q.id_consulta_encargo DESC LIMIT 1) IS TRUE AS simulada,
        ST_Y(s.centro_publico::geometry) AS latitud_sector, ST_X(s.centro_publico::geometry) AS longitud_sector,
        CASE WHEN %s::float IS NOT NULL THEN ST_Distance(s.centro_publico,ST_SetSRID(ST_Point(%s,%s),4326)::geography)/1000 END AS distancia_km,
        EXISTS(SELECT 1 FROM evidencia e JOIN archivo_evidencia f USING(id_evidencia)
               WHERE e.id_evidencia=s.id_foto_vehiculo AND {FOTO_PUBLICABLE}) AS foto_disponible
        FROM solicitud_colaboracion s JOIN caso c USING(id_caso) JOIN vehiculo v USING(id_vehiculo) JOIN modelo m USING(id_modelo) JOIN marca ma USING(id_marca)
        WHERE {SOLICITUD_VIGENTE} AND c.entorno=%s AND s.zona_publicable ILIKE %s
        AND (%s::bigint IS NULL OR s.id_solicitud_colaboracion=%s)
        ORDER BY distancia_km ASC NULLS LAST,s.inicio DESC LIMIT 100''',(uid,lat,lon,lat,entorno(),'%'+zona+'%',sid,sid))
    found=rows(cur)
    for fila in found:
        fila['foto_url']=f"/colaboracion/{fila['id_solicitud_colaboracion']}/foto-vehiculo" if fila['foto_disponible'] else None
    return found

@router.get('/colaboracion/{sid}/foto-vehiculo')
def foto_vehiculo_publica(sid:int,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    cur.execute(f'''SELECT f.contenido FROM solicitud_colaboracion s JOIN caso c USING(id_caso)
        JOIN evidencia e ON e.id_evidencia=s.id_foto_vehiculo
        JOIN archivo_evidencia f USING(id_evidencia)
        WHERE s.id_solicitud_colaboracion=%s AND c.entorno=%s AND {SOLICITUD_VIGENTE} AND {FOTO_PUBLICABLE}''',(sid,entorno()))
    row=cur.fetchone()
    if not row:raise HTTPException(404,'Foto no disponible',headers={'Cache-Control':'no-store'})
    return Response(bytes(row[0]),media_type='image/jpeg',headers={'Cache-Control':'no-store','Content-Disposition':'inline; filename="vehiculo.jpg"'})

@router.get('/colaboracion/{sid}')
def detalle_colaboracion(sid:int,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    found=colaboraciones_publicas(conn.cursor(),usuario['id_usuario'],sid=sid)
    if not found:raise HTTPException(404,'Publicación no disponible')
    return found[0]

@router.get('/colaboracion')
def listado(lat:float|None=Query(None,ge=-90,le=90),lon:float|None=Query(None,ge=-180,le=180),radio_km:int=Query(30,ge=1,le=300),zona:str=Query('',max_length=200),usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    if (lat is None)!=(lon is None):raise HTTPException(422,'Envía latitud y longitud juntas')
    cur=conn.cursor()
    found=colaboraciones_publicas(cur,usuario['id_usuario'],lat,lon,zona)
    resultado={'cercanos':[], 'otras_zonas':[], 'demo_alertas':config.alertas_demo and DEMO,
               'nota':'Distancias aproximadas al sector de publicación, no ubicación actual del vehículo.'}
    for fila in found:
        km=fila['distancia_km']
        grupo='cercanos' if km is not None and km<=radio_km else 'otras_zonas'
        fila['distancia_km']=round(km) if km is not None else None
        resultado[grupo].append(fila)
    return resultado

class AvistamientoEntrada(BaseModel):
    foto_base64:str|None=Field(default=None,min_length=16,max_length=2800000)
    observado_en:datetime
    zona:str=Field(min_length=3,max_length=200)
    descripcion:str=Field(min_length=10,max_length=3000)
    latitud:float=Field(ge=-90,le=90)
    longitud:float=Field(ge=-180,le=180)

@router.post('/colaboracion/{sid}/avistamientos',status_code=201)
def aportar(sid:int,datos:AvistamientoEntrada,response:Response,idempotency_key:uuid.UUID=Header(...),usuario=Depends(participante),conn=Depends(obtener_conexion)):
    uid=usuario['id_usuario'];limitar(conn,f'aporte:{uid}',10);cur=conn.cursor();bloquear_participante(cur,uid)
    cur.execute('SELECT id_avistamiento,id_solicitud_colaboracion FROM avistamiento WHERE id_usuario_autor=%s AND clave_envio=%s',(uid,str(idempotency_key)));prev=cur.fetchone()
    if prev:
        if prev[1]!=sid:raise HTTPException(409,'Clave de envío utilizada en otra solicitud')
        response.status_code=200;return {'id_avistamiento':prev[0],'estado':'pendiente','reintento':True}
    fecha=datos.observado_en
    if fecha.tzinfo is None or fecha>datetime.now(timezone.utc):raise HTTPException(422,'La fecha debe incluir zona horaria y no ser futura')
    # Bloquear caso antes que solicitud, igual que cierre/publicación.
    cur.execute('SELECT id_caso FROM solicitud_colaboracion WHERE id_solicitud_colaboracion=%s',(sid,));row=cur.fetchone()
    if not row:raise HTTPException(404,'Publicación no disponible')
    cid=row[0];cur.execute('SELECT estado,id_usuario_reportante FROM caso WHERE id_caso=%s FOR UPDATE',(cid,))
    caso=cur.fetchone()
    if caso[1]==uid:raise HTTPException(403,'Actualiza tus antecedentes desde el seguimiento de tu caso.')
    if caso[0]=='cerrado':raise HTTPException(409,'Caso cerrado')
    cur.execute(f"""SELECT 1 FROM solicitud_colaboracion s JOIN caso c USING(id_caso)
        WHERE s.id_solicitud_colaboracion=%s AND c.entorno=%s AND {VIGENTE}""",(sid,entorno()))
    if not cur.fetchone():raise HTTPException(409,'La publicación ya no está vigente')
    cur.execute('''INSERT INTO avistamiento(id_solicitud_colaboracion,id_caso,id_usuario_autor,observado_en,zona,descripcion,ubicacion,clave_envio) VALUES(%s,%s,%s,%s,%s,%s,ST_SetSRID(ST_Point(%s,%s),4326)::geography,%s) RETURNING id_avistamiento''',(sid,cid,uid,fecha,datos.zona,datos.descripcion,datos.longitud,datos.latitud,str(idempotency_key)))
    aid=cur.fetchone()[0]
    if datos.foto_base64 is not None:
        guardar_foto(cur,cid,uid,uuid.uuid4(),datos.foto_base64,aid)
    return {'id_avistamiento':aid,'estado':'pendiente','mensaje':'Aporte recibido para revisión humana. No sigas ni confrontes a nadie.'}

@router.get('/mis-avistamientos')
def mis_aportes(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();cur.execute('''SELECT id_avistamiento,zona,observado_en,estado_revision,motivo_revision FROM avistamiento WHERE id_usuario_autor=%s ORDER BY recibido_en DESC LIMIT 100''',(usuario['id_usuario'],));return rows(cur)

@router.get('/gestion/casos/{cid}/aportes')
def aportes(cid:int,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();caso_autorizado(cur,cid,usuario,operador=True)
    cur.execute('''SELECT a.id_avistamiento,a.zona,a.descripcion,a.observado_en,a.estado_revision,
        ST_Y(a.ubicacion::geometry) AS latitud, ST_X(a.ubicacion::geometry) AS longitud,
        ARRAY(SELECT e.id_evidencia FROM evidencia e WHERE e.id_avistamiento=a.id_avistamiento ORDER BY e.id_evidencia) AS fotos
        FROM avistamiento a WHERE a.id_caso=%s ORDER BY a.recibido_en DESC''',(cid,));return rows(cur)

class Revision(Motivo):
    decision:Literal['aceptado','rechazado','requiere_aclaracion']
    resumen:str=Field(default='',max_length=500)

@router.get('/gestion/aportes/pendientes')
def pendientes(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    orgs=organizaciones_del_operador(cur,usuario['id_usuario'])
    if not orgs:raise HTTPException(403,'Se requiere acceso institucional')
    cur.execute("""SELECT c.id_caso,c.folio,a.zona,a.recibido_en,
            EXISTS(SELECT 1 FROM evidencia e WHERE e.id_avistamiento=a.id_avistamiento) AS con_foto
        FROM avistamiento a JOIN caso c USING(id_caso)
        WHERE c.id_organizacion=ANY(%s) AND c.estado<>'cerrado' AND a.estado_revision='pendiente'
        ORDER BY a.recibido_en, a.id_avistamiento LIMIT 100""",(orgs,))
    return rows(cur)
@router.post('/gestion/aportes/{aid}/revision')
def revisar(aid:int,datos:Revision,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();cur.execute('SELECT id_caso,id_usuario_autor FROM avistamiento WHERE id_avistamiento=%s',(aid,));row=cur.fetchone()
    if not row:raise HTTPException(404,'Aporte no disponible')
    cid,autor=row;c=caso_autorizado(cur,cid,usuario,operador=True)
    if c['estado']=='cerrado':raise HTTPException(409,'Caso cerrado')
    if autor==usuario['id_usuario']:raise HTTPException(403,'No puedes revisar tu propio aporte')
    cur.execute('SELECT revisar_avistamiento(%s,%s,%s,%s)',(aid,usuario['id_usuario'],datos.decision,datos.motivo))
    resumen=datos.resumen.strip() if datos.decision=='aceptado' else None
    cur.execute('UPDATE avistamiento SET resumen_para_afectado=%s WHERE id_avistamiento=%s',(resumen or None,aid))
    aviso(cur,autor,None,'Avistamiento revisado',
          'Consulta la decisión en Cuenta → Mis avistamientos.',f'revision:{aid}:{datos.decision}')
    if resumen:
        bitacora(cur,cid,usuario['id_usuario'],'aporte_revisado',resumen)
        aviso(cur,c['id_usuario_reportante'],cid,'Nuevo antecedente revisado','Hay un antecedente disponible en el seguimiento de tu caso.',f'aporte:{aid}:{uuid.uuid4()}')
    return {'estado_revision':datos.decision}

class Foto(BaseModel):
    autorizar_foto_publica:bool=False
    contenido_base64:str=Field(min_length=16,max_length=2800000)
    clave_envio:uuid.UUID

class MensajeCaso(BaseModel):
    mensaje:str=Field(min_length=10,max_length=500)
    clave_envio:uuid.UUID

@router.post('/gestion/casos/{cid}/mensaje',status_code=204)
def comunicar(cid:int,datos:MensajeCaso,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    caso=caso_autorizado(cur,cid,usuario,operador=True)
    if caso['estado']=='cerrado':raise HTTPException(409,'Caso cerrado')
    clave=f"mensaje:{cid}:{usuario['id_usuario']}:{datos.clave_envio}"
    texto=datos.mensaje.strip()
    if len(texto)<10:raise HTTPException(422,'Escribe una actualización de al menos diez caracteres')
    cur.execute('SELECT mensaje FROM notificacion WHERE id_usuario=%s AND clave_deduplicacion=%s',
                (caso['id_usuario_reportante'],clave))
    anterior=cur.fetchone()
    if anterior:
        if anterior[0]!=texto:raise HTTPException(409,'Esta actualización ya fue enviada con otro texto')
        return
    aviso(cur,caso['id_usuario_reportante'],cid,'Novedad del caso '+caso['folio'],texto,clave)
    bitacora(cur,cid,usuario['id_usuario'],'mensaje_al_afectado',texto,'interna')

@router.post('/casos/{cid}/fotos',status_code=201)
def foto(cid:int,datos:Foto,response:Response,usuario=Depends(participante),conn=Depends(obtener_conexion)):
    uid=usuario['id_usuario'];limitar(conn,f'foto:{uid}',10);cur=conn.cursor();bloquear_participante(cur,uid);c=caso_autorizado(cur,cid,usuario,propietario=True)
    if c['estado']=='cerrado':raise HTTPException(409,'Caso cerrado')
    cur.execute('SELECT id_evidencia,id_caso FROM evidencia WHERE id_usuario_autor=%s AND clave_envio=%s',(uid,str(datos.clave_envio)));prev=cur.fetchone()
    if prev:
        if prev[1]!=cid:raise HTTPException(409,'Clave utilizada en otro caso')
        response.status_code=200;return {'id_evidencia':prev[0]}
    cur.execute('SELECT count(*) FROM archivo_evidencia f JOIN evidencia e USING(id_evidencia) WHERE e.id_caso=%s AND e.id_avistamiento IS NULL',(cid,))
    if cur.fetchone()[0]>=5:raise HTTPException(409,'Máximo cinco fotos por caso en esta beta')
    eid=guardar_foto(cur,cid,uid,datos.clave_envio,datos.contenido_base64,autorizar_foto_publica=datos.autorizar_foto_publica)
    return {'id_evidencia':eid,'estado_revision':'pendiente','mensaje':'Foto privada recibida para revisión.'}

class AntecedenteTitular(BaseModel):
    descripcion:str=Field(min_length=10,max_length=3000)
    clave_envio:uuid.UUID
    latitud:float|None=Field(default=None,ge=-90,le=90)
    longitud:float|None=Field(default=None,ge=-180,le=180)
    foto_base64:str|None=Field(default=None,min_length=16,max_length=2800000)

@router.post('/mis-casos/{cid}/antecedentes',status_code=201)
def antecedente_titular(cid:int,datos:AntecedenteTitular,response:Response,usuario=Depends(participante),conn=Depends(obtener_conexion)):
    uid=usuario['id_usuario'];cur=conn.cursor()
    bloquear_participante(cur,uid)
    caso=caso_autorizado(cur,cid,usuario,propietario=True)
    if (datos.latitud is None)!=(datos.longitud is None):
        raise HTTPException(422,'Selecciona un punto completo en el mapa')
    marcador=f'Antecedente del titular [{datos.clave_envio}]'
    cur.execute("SELECT descripcion FROM gestion_caso WHERE id_caso=%s AND id_usuario=%s AND accion='nota' AND descripcion LIKE %s",
                (cid,uid,marcador+'%'))
    if cur.fetchone():
        response.status_code=200
        return {'mensaje':'Antecedente recibido','reintento':True}
    if caso['estado']=='cerrado':raise HTTPException(409,'Caso cerrado')
    texto=marcador+'\n'+datos.descripcion.strip()
    if datos.latitud is not None:
        texto+=f'\nUbicación aportada: {datos.latitud}, {datos.longitud}'
    if datos.foto_base64:
        cur.execute('SELECT count(*) FROM evidencia WHERE id_caso=%s AND id_avistamiento IS NULL',(cid,))
        if cur.fetchone()[0]>=5:raise HTTPException(409,'Máximo cinco fotos por caso')
        guardar_foto(cur,cid,uid,datos.clave_envio,datos.foto_base64)
    bitacora(cur,cid,uid,'nota',texto,'interna')
    return {'mensaje':'Antecedente privado recibido para revisión del operador'}

def guardar_foto(cur,cid,uid,clave,contenido,aid=None,autorizar_foto_publica=False):
    try:
        clean=limpiar_imagen(contenido)
    except ValueError:
        raise HTTPException(422,'Foto inválida. Usa JPEG, PNG o WebP de hasta 2 MB y 16 megapíxeles.') from None
    key=f'privado/{uid}/{uuid.uuid4()}.jpg'
    cur.execute('''INSERT INTO evidencia(id_caso,id_avistamiento,id_usuario_autor,tipo,origen,clave_objeto,mime,tamano_bytes,sha256,estado_carga,clave_envio,recibida_en)
      VALUES(%s,%s,%s,'foto','archivo_adjuntado',%s,'image/jpeg',%s,%s,'recibido',%s,CURRENT_TIMESTAMP) RETURNING id_evidencia''',(cid,aid,uid,key,len(clean),hashlib.sha256(clean).digest(),str(clave)));eid=cur.fetchone()[0]
    cur.execute('INSERT INTO archivo_evidencia(id_evidencia,contenido) VALUES(%s,%s)',(eid,clean))
    if autorizar_foto_publica and aid is None:
        cur.execute('UPDATE evidencia SET autorizada_publicacion_en=CURRENT_TIMESTAMP WHERE id_evidencia=%s',(eid,))
    return eid

class ConsentimientoFoto(BaseModel):
    autorizada:bool

@router.post('/mis-casos/{cid}/fotos/{eid}/publicacion',status_code=204)
def consentir_foto(cid:int,eid:int,datos:ConsentimientoFoto,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();caso_autorizado(cur,cid,usuario,propietario=True)
    cur.execute('''UPDATE evidencia SET autorizada_publicacion_en=CASE WHEN %s THEN CURRENT_TIMESTAMP ELSE NULL END
        WHERE id_evidencia=%s AND id_caso=%s AND id_usuario_autor=%s AND id_avistamiento IS NULL AND tipo='foto'
        RETURNING id_evidencia''',(datos.autorizada,eid,cid,usuario['id_usuario']))
    if not cur.fetchone():raise HTTPException(404,'Foto no disponible')

@router.get('/evidencias/{eid}/foto')
def descargar(eid:int,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();cur.execute('''SELECT id_caso,id_avistamiento,EXISTS(
        SELECT 1 FROM consulta_encargo q WHERE q.id_evidencia=e.id_evidencia)
        FROM evidencia e WHERE e.id_evidencia=%s''',(eid,));row=cur.fetchone()
    if not row:raise HTTPException(404,'Foto no disponible')
    caso_autorizado(cur,row[0],usuario,operador=row[1] is not None or row[2])
    cur.execute('SELECT contenido FROM archivo_evidencia WHERE id_evidencia=%s',(eid,));row=cur.fetchone()
    if not row:raise HTTPException(404,'Foto no disponible')
    return Response(bytes(row[0]),media_type='image/jpeg',headers={'Cache-Control':'no-store','Content-Disposition':'inline; filename="evidencia.jpg"'})

class RevisionFoto(Motivo):decision:Literal['aceptada','rechazada']
@router.post('/gestion/evidencias/{eid}/revision',status_code=204)
def revisar_foto(eid:int,datos:RevisionFoto,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();cur.execute('SELECT id_caso,id_usuario_autor FROM evidencia WHERE id_evidencia=%s',(eid,));row=cur.fetchone()
    if not row:raise HTTPException(404,'Evidencia no disponible')
    c=caso_autorizado(cur,row[0],usuario,operador=True)
    if c['estado']=='cerrado':raise HTTPException(409,'Caso cerrado')
    if row[1]==usuario['id_usuario']:raise HTTPException(403,'No puedes evaluar tu propia evidencia')
    cur.execute('''UPDATE evidencia SET estado_revision=%s,revisada_por=%s,revisada_en=CURRENT_TIMESTAMP,motivo_revision=%s WHERE id_evidencia=%s''',(datos.decision,usuario['id_usuario'],datos.motivo,eid))
    bitacora(cur,row[0],usuario['id_usuario'],'revision_evidencia',datos.motivo,'interna')

class Cierre(Motivo):
    motivo_cierre:Literal['recuperado','duplicado','informacion_insuficiente','otro']
    id_evidencia:int|None=None
    id_caso_principal:int|None=None
@router.post('/gestion/casos/{cid}/cerrar',status_code=204)
def cerrar_caso(cid:int,datos:Cierre,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();c=caso_autorizado(cur,cid,usuario,operador=True)
    cur.execute('SELECT revision_alerta FROM caso WHERE id_caso=%s',(cid,))
    if datos.revision is not None and cur.fetchone()[0]!=datos.revision:
        raise HTTPException(409,'El expediente cambió. Recarga antes de cerrar.')
    if c['estado']=='cerrado':raise HTTPException(409,'Caso ya cerrado')
    if datos.motivo_cierre=='recuperado':
        cur.execute("SELECT 1 FROM evidencia WHERE id_evidencia=%s AND id_caso=%s AND estado_revision='aceptada'",(datos.id_evidencia,cid))
        if not cur.fetchone():raise HTTPException(422,'La recuperación requiere evidencia aceptada del mismo caso')
    if datos.motivo_cierre=='duplicado':
        cur.execute('SELECT 1 FROM caso WHERE id_caso=%s AND id_organizacion=%s AND id_caso<>%s AND id_caso_principal IS NULL',(datos.id_caso_principal,c['id_organizacion'],cid))
        if not cur.fetchone():raise HTTPException(422,'Selecciona un caso principal válido del mismo ámbito')
    cur.execute('''UPDATE caso SET estado='cerrado',motivo_cierre=%s,cerrado_en=CURRENT_TIMESTAMP,recuperado_en=CASE WHEN %s='recuperado' THEN CURRENT_TIMESTAMP ELSE NULL END,id_evidencia_recuperacion=%s,id_caso_principal=%s WHERE id_caso=%s''',(datos.motivo_cierre,datos.motivo_cierre,datos.id_evidencia if datos.motivo_cierre=='recuperado' else None,datos.id_caso_principal if datos.motivo_cierre=='duplicado' else None,cid))
    cur.execute("UPDATE solicitud_colaboracion SET estado='retirada',retirada_en=CURRENT_TIMESTAMP,motivo_retiro='Cierre del caso' WHERE id_caso=%s AND estado='publicada'",(cid,))
    bitacora(cur,cid,usuario['id_usuario'],'cierre',datos.motivo,'afectado',c['estado'],'cerrado')
    aviso(cur,c['id_usuario_reportante'],cid,'Caso cerrado','Consulta el motivo en el seguimiento.',f'cierre:{cid}')

class Confianza(BaseModel):
    correo:str=Field(min_length=5,max_length=254)
    dias:int=Field(default=7,ge=1,le=30)
@router.post('/mis-casos/{cid}/confianza',status_code=201)
def confiar(cid:int,datos:Confianza,usuario=Depends(participante),conn=Depends(obtener_conexion)):
    uid=usuario['id_usuario'];limitar(conn,f'confianza:{uid}',10);cur=conn.cursor();bloquear_participante(cur,uid);caso_autorizado(cur,cid,usuario,propietario=True)
    cur.execute("SELECT id_usuario FROM usuario WHERE correo_normalizado=lower(trim(%s)) AND estado='activo' AND id_usuario<>%s",(datos.correo,uid));row=cur.fetchone()
    if not row:raise HTTPException(422,'No fue posible asociar ese contacto. Debe tener una cuenta activa distinta de la tuya.')
    dest=row[0]
    cur.execute('SELECT count(*) FROM acceso_confianza WHERE id_caso=%s AND revocado_en IS NULL AND vence_en>CURRENT_TIMESTAMP',(cid,))
    if cur.fetchone()[0]>=5:raise HTTPException(409,'Máximo cinco accesos activos')
    cur.execute('''INSERT INTO acceso_confianza(id_caso,otorgado_por,id_usuario_destinatario,vence_en) VALUES(%s,%s,%s,CURRENT_TIMESTAMP+%s*interval '1 day') RETURNING id_acceso_confianza''',(cid,uid,dest,datos.dias));return {'id_acceso_confianza':cur.fetchone()[0]}

@router.get('/mis-casos/{cid}/confianza')
def contactos(cid:int,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();caso_autorizado(cur,cid,usuario,propietario=True);cur.execute('''SELECT a.id_acceso_confianza,u.nombre_visible,a.vence_en,a.revocado_en FROM acceso_confianza a JOIN usuario u ON u.id_usuario=a.id_usuario_destinatario WHERE a.id_caso=%s ORDER BY a.autorizado_en DESC''',(cid,));return rows(cur)

@router.post('/mis-casos/{cid}/confianza/{aid}/revocar',status_code=204)
def revocar(cid:int,aid:int,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();caso_autorizado(cur,cid,usuario,propietario=True);cur.execute('UPDATE acceso_confianza SET revocado_en=CURRENT_TIMESTAMP WHERE id_acceso_confianza=%s AND id_caso=%s AND revocado_en IS NULL',(aid,cid))

@router.get('/notificaciones')
def notificaciones(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();cur.execute('''SELECT id_notificacion,id_caso,titulo,mensaje,creada_en,leida_en,CASE WHEN clave_deduplicacion LIKE 'revision:%%' THEN 'avistamientos' ELSE 'caso' END AS destino FROM notificacion WHERE id_usuario=%s ORDER BY creada_en DESC LIMIT 100''',(usuario['id_usuario'],));return rows(cur)
@router.post('/notificaciones/{nid}/leer',status_code=204)
def leer(nid:int,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    conn.cursor().execute('UPDATE notificacion SET leida_en=COALESCE(leida_en,CURRENT_TIMESTAMP) WHERE id_notificacion=%s AND id_usuario=%s',(nid,usuario['id_usuario']))

@router.get('/gestion/metricas')
def metricas(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();orgs=organizaciones_del_operador(cur,usuario['id_usuario'])
    if not orgs:raise HTTPException(403,'Sin ámbito institucional')
    cur.execute('SELECT estado,count(*) AS cantidad FROM caso WHERE id_organizacion=ANY(%s) GROUP BY estado',(orgs,));return rows(cur)

@router.get('/territorio/antecedentes')
def antecedentes(zona:str=Query('',max_length=200),usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    # No mezclar datos de prueba ni registros no validados con antecedentes reales.
    cur.execute('''SELECT h.id_hecho_territorial,h.tipo,h.ocurrido_en,h.zona,h.nivel_agregacion,
      array_agg(DISTINCT f.nombre) AS fuentes
      FROM hecho_territorial h JOIN registro_fuente r USING(id_hecho_territorial)
      JOIN fuente_datos f USING(id_fuente_datos) JOIN lote_importacion l USING(id_lote_importacion)
      WHERE h.estado='validado' AND h.entorno='operacion' AND r.estado_revision='aceptado'
      AND f.estado='autorizada' AND l.estado='completado' AND h.zona ILIKE %s
      GROUP BY h.id_hecho_territorial ORDER BY h.ocurrido_en DESC LIMIT 100''',('%'+zona+'%',))
    return {'registros':rows(cur),'nota':'Antecedentes documentados, no predicciones. Si no hay fuentes autorizadas y registros validados, no se muestran datos.'}

@router.get('/gestion/camaras')
def camaras(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();orgs=organizaciones_del_operador(cur,usuario['id_usuario'])
    if not orgs:raise HTTPException(403,'Sin ámbito institucional')
    cur.execute('''SELECT id_camara,nombre,estado,referencia_autorizacion,entorno,verificada_en FROM camara WHERE id_organizacion=ANY(%s) ORDER BY nombre''',(orgs,))
    return {'camaras':rows(cur),'nota':'Inventario autorizado. No hay transmisión, reconocimiento visual ni conexión automática a cámaras.'}

@router.get('/gestion/casos/{cid}/resumen')
def resumen_verificable(cid:int,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();c=caso_autorizado(cur,cid,usuario,operador=True)
    facts=[{'texto':f"Caso {c['folio']} en estado {c['estado']}",'fuente':f'caso:{cid}'}]
    cur.execute("SELECT id_avistamiento,zona,observado_en FROM avistamiento WHERE id_caso=%s AND estado_revision='aceptado' ORDER BY observado_en LIMIT 20",(cid,))
    for a in rows(cur):facts.append({'texto':f"Avistamiento revisado en {a['zona']}, observado {a['observado_en']}",'fuente':f"avistamiento:{a['id_avistamiento']}"})
    cur.execute("SELECT id_evidencia FROM evidencia WHERE id_caso=%s AND estado_revision='aceptada' ORDER BY creada_en LIMIT 20",(cid,))
    for e in rows(cur):facts.append({'texto':'Existe una evidencia aceptada por revisión humana.','fuente':f"evidencia:{e['id_evidencia']}"})
    return {'metodo':'Resumen estructurado determinista; no usa un modelo de inteligencia artificial.','hechos':facts,'limites':'No infiere rutas, sospechosos ni ubicaciones actuales. La aceptación de un aporte no prueba por sí sola que sea verdadero.'}

class Denuncia(BaseModel):
    estado:Literal['no_informada','pendiente','declarada']
    referencia:str=Field(default='',max_length=120)
@router.post('/mis-casos/{cid}/denuncia',status_code=204)
def declarar_denuncia(cid:int,datos:Denuncia,usuario=Depends(participante),conn=Depends(obtener_conexion)):
    cur=conn.cursor();c=caso_autorizado(cur,cid,usuario,propietario=True)
    if c['estado']=='cerrado':raise HTTPException(409,'Caso cerrado')
    if datos.estado=='declarada' and not datos.referencia.strip():raise HTTPException(422,'Indica la referencia de la denuncia declarada')
    cur.execute('SELECT denuncia_estado FROM caso WHERE id_caso=%s',(cid,))
    if cur.fetchone()[0]=='verificada':raise HTTPException(409,'El antecedente ya fue verificado; solicita revisión institucional')
    cur.execute('UPDATE caso SET denuncia_estado=%s,referencia_denuncia=%s WHERE id_caso=%s',(datos.estado,datos.referencia.strip() or None,cid))
    bitacora(cur,cid,usuario['id_usuario'],'denuncia_declarada','El afectado actualizó los antecedentes declarados de denuncia. No constituye validación policial automática.')

class Prioridad(Motivo):prioridad:Literal['baja','normal','alta']
@router.post('/gestion/casos/{cid}/prioridad',status_code=204)
def prioridad(cid:int,datos:Prioridad,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();caso_autorizado(cur,cid,usuario,operador=True)
    cur.execute('UPDATE caso SET prioridad=%s WHERE id_caso=%s',(datos.prioridad,cid))
    bitacora(cur,cid,usuario['id_usuario'],'prioridad',datos.motivo,'interna')
