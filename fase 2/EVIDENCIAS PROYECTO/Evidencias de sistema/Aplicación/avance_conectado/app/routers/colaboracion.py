"""Colaboración revisada, seguimiento, fotos privadas y avisos internos persistentes."""
import base64, binascii, hashlib, io, uuid
from datetime import datetime, timezone
from typing import Literal
from PIL import Image, UnidentifiedImageError, ImageOps
from fastapi import APIRouter, Depends, HTTPException, Query, Response, Header
from pydantic import BaseModel, Field, model_validator
from ..db import obtener_conexion, fila_dict
from ..seguridad import usuario_actual, organizaciones_del_operador
from ..antifraude import participante, limitar

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
    cur.execute('''INSERT INTO notificacion(id_usuario,id_caso,tipo,titulo,mensaje,clave_deduplicacion) VALUES(%s,%s,'caso',%s,%s,%s) ON CONFLICT(id_usuario,clave_deduplicacion) DO NOTHING''',(uid,cid,titulo,texto,clave))
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
    if org:
        cur.execute('SELECT descripcion_privada FROM caso WHERE id_caso=%s',(cid,))
        c['relato_para_revision']=cur.fetchone()[0]
    if own or org:
        cur.execute('''SELECT a.id_avistamiento,a.zona,a.observado_en,a.estado_revision,a.resumen_para_afectado FROM avistamiento a WHERE a.id_caso=%s AND a.estado_revision='aceptado' AND a.resumen_para_afectado IS NOT NULL ORDER BY observado_en DESC''',(cid,));c['aportes']=rows(cur)
        cur.execute('SELECT id_evidencia,estado_revision,mime,tamano_bytes FROM evidencia WHERE id_caso=%s AND id_avistamiento IS NULL ORDER BY creada_en DESC',(cid,));c['evidencias']=rows(cur)
    return c

@router.post('/mis-casos/{cid}/colaboracion')
def consentir(cid:int,usuario=Depends(participante),conn=Depends(obtener_conexion)):
    cur=conn.cursor();c=caso_autorizado(cur,cid,usuario,propietario=True)
    if c['estado']=='cerrado':raise HTTPException(409,'Caso cerrado')
    cur.execute('UPDATE caso SET colaboracion_consentida_en=CURRENT_TIMESTAMP WHERE id_caso=%s',(cid,))
    bitacora(cur,cid,usuario['id_usuario'],'solicitar_colaboracion','El afectado autorizó solicitar colaboración. Publicación pendiente de revisión humana.')
    return {'mensaje':'Solicitud de colaboración pendiente de revisión; todavía no está publicada.'}

class Publicacion(BaseModel):
    zona:str=Field(min_length=3,max_length=200)
    texto:str=Field(min_length=15,max_length=1500)
    motivo:str=Field(min_length=10,max_length=500)
    horas:int=Field(default=24,ge=1,le=72)

@router.post('/gestion/casos/{cid}/publicacion',status_code=201)
def publicar(cid:int,datos:Publicacion,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();c=caso_autorizado(cur,cid,usuario,operador=True)
    if c['estado'] not in ('en_revision','en_gestion') or not c['colaboracion_consentida_en']:
        raise HTTPException(409,'Se requiere revisión del caso y consentimiento del afectado')
    cur.execute("UPDATE solicitud_colaboracion SET estado='vencida' WHERE id_caso=%s AND estado='publicada' AND vence_en<=CURRENT_TIMESTAMP",(cid,))
    cur.execute("SELECT 1 FROM solicitud_colaboracion WHERE id_caso=%s AND estado='publicada'",(cid,))
    if cur.fetchone():raise HTTPException(409,'Ya existe una publicación vigente')
    # Centro territorial redondeado (~2 km), nunca la coordenada privada del afectado.
    cur.execute('''INSERT INTO solicitud_colaboracion(id_caso,autorizada_por,zona_publicable,texto_aprobado,motivo_autorizacion,inicio,vence_en,centro_publico)
      SELECT id_caso,%s,%s,%s,%s,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP+(%s*interval '1 hour'),ST_SnapToGrid(ubicacion::geometry,0.02)::geography FROM caso WHERE id_caso=%s RETURNING id_solicitud_colaboracion''',(usuario['id_usuario'],datos.zona,datos.texto,datos.motivo,datos.horas,cid));sid=cur.fetchone()[0]
    bitacora(cur,cid,usuario['id_usuario'],'publicacion','Se publicó una solicitud de colaboración con datos mínimos revisados.')
    aviso(cur,c['id_usuario_reportante'],cid,'Colaboración publicada','Tu solicitud ya está disponible para colaboradores.',f'publicacion:{sid}')
    return {'id_solicitud_colaboracion':sid}

class Motivo(BaseModel):motivo:str=Field(min_length=10,max_length=500)
@router.post('/gestion/casos/{cid}/retirar',status_code=204)
def retirar(cid:int,datos:Motivo,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();caso_autorizado(cur,cid,usuario,operador=True)
    cur.execute("UPDATE solicitud_colaboracion SET estado='retirada',retirada_en=CURRENT_TIMESTAMP,motivo_retiro=%s WHERE id_caso=%s AND estado='publicada'",(datos.motivo,cid))
    bitacora(cur,cid,usuario['id_usuario'],'retirar_publicacion','La publicación de colaboración fue retirada.')

@router.get('/colaboracion')
def listado(lat:float|None=Query(None,ge=-90,le=90),lon:float|None=Query(None,ge=-180,le=180),radio_km:int=Query(30,ge=1,le=300),zona:str=Query('',max_length=200),usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    if (lat is None)!=(lon is None):raise HTTPException(422,'Envía latitud y longitud juntas')
    cur=conn.cursor()
    cur.execute('''SELECT s.id_solicitud_colaboracion,s.zona_publicable,s.texto_aprobado,s.vence_en,v.patente,v.color,ma.nombre AS marca,m.nombre AS modelo,
        CASE WHEN %s::float IS NOT NULL THEN round((ST_Distance(s.centro_publico,ST_SetSRID(ST_Point(%s,%s),4326)::geography)/1000)::numeric,0) END AS distancia_km
        FROM solicitud_colaboracion s JOIN caso c USING(id_caso) JOIN vehiculo v USING(id_vehiculo) JOIN modelo m USING(id_modelo) JOIN marca ma USING(id_marca)
        WHERE s.estado='publicada' AND s.inicio<=CURRENT_TIMESTAMP AND s.vence_en>CURRENT_TIMESTAMP AND c.estado<>'cerrado' AND s.zona_publicable ILIKE %s
        ORDER BY distancia_km ASC NULLS LAST,s.inicio DESC LIMIT 100''',(lat,lon,lat,'%'+zona+'%'))
    found=rows(cur)
    return {'cercanos':[r for r in found if r['distancia_km'] is not None and r['distancia_km']<=radio_km],
      'otras_zonas':[r for r in found if r['distancia_km'] is None or r['distancia_km']>radio_km],
      'nota':'Distancias aproximadas al sector de publicación, no ubicación actual del vehículo.'}

class AvistamientoEntrada(BaseModel):
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
    cid=row[0];cur.execute('SELECT estado FROM caso WHERE id_caso=%s FOR UPDATE',(cid,))
    if cur.fetchone()[0]=='cerrado':raise HTTPException(409,'Caso cerrado')
    cur.execute("SELECT 1 FROM solicitud_colaboracion WHERE id_solicitud_colaboracion=%s AND estado='publicada' AND inicio<=CURRENT_TIMESTAMP AND vence_en>CURRENT_TIMESTAMP",(sid,))
    if not cur.fetchone():raise HTTPException(409,'La publicación ya no está vigente')
    cur.execute('''INSERT INTO avistamiento(id_solicitud_colaboracion,id_caso,id_usuario_autor,observado_en,zona,descripcion,ubicacion,clave_envio) VALUES(%s,%s,%s,%s,%s,%s,ST_SetSRID(ST_Point(%s,%s),4326)::geography,%s) RETURNING id_avistamiento''',(sid,cid,uid,fecha,datos.zona,datos.descripcion,datos.longitud,datos.latitud,str(idempotency_key)))
    return {'id_avistamiento':cur.fetchone()[0],'estado':'pendiente','mensaje':'Aporte recibido para revisión humana. No sigas ni confrontes a nadie.'}

@router.get('/mis-avistamientos')
def mis_aportes(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();cur.execute('''SELECT id_avistamiento,zona,observado_en,estado_revision,motivo_revision FROM avistamiento WHERE id_usuario_autor=%s ORDER BY recibido_en DESC LIMIT 100''',(usuario['id_usuario'],));return rows(cur)

@router.get('/gestion/casos/{cid}/aportes')
def aportes(cid:int,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();caso_autorizado(cur,cid,usuario,operador=True)
    cur.execute('''SELECT id_avistamiento,zona,descripcion,observado_en,estado_revision,ST_Y(ubicacion::geometry) AS latitud,ST_X(ubicacion::geometry) AS longitud FROM avistamiento WHERE id_caso=%s ORDER BY recibido_en''',(cid,));return rows(cur)

class Revision(Motivo):
    decision:Literal['aceptado','rechazado','requiere_aclaracion']
    resumen:str=Field(default='',max_length=500)
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
    if resumen:
        bitacora(cur,cid,usuario['id_usuario'],'aporte_revisado',resumen)
        aviso(cur,c['id_usuario_reportante'],cid,'Nuevo antecedente revisado','Hay un antecedente disponible en el seguimiento de tu caso.',f'aporte:{aid}:{uuid.uuid4()}')
    return {'estado_revision':datos.decision}

class Foto(BaseModel):
    contenido_base64:str=Field(min_length=16,max_length=2800000)
    clave_envio:uuid.UUID
@router.post('/casos/{cid}/fotos',status_code=201)
def foto(cid:int,datos:Foto,response:Response,usuario=Depends(participante),conn=Depends(obtener_conexion)):
    uid=usuario['id_usuario'];limitar(conn,f'foto:{uid}',10);cur=conn.cursor();bloquear_participante(cur,uid);c=caso_autorizado(cur,cid,usuario,propietario=True)
    if c['estado']=='cerrado':raise HTTPException(409,'Caso cerrado')
    cur.execute('SELECT id_evidencia,id_caso FROM evidencia WHERE id_usuario_autor=%s AND clave_envio=%s',(uid,str(datos.clave_envio)));prev=cur.fetchone()
    if prev:
        if prev[1]!=cid:raise HTTPException(409,'Clave utilizada en otro caso')
        response.status_code=200;return {'id_evidencia':prev[0]}
    cur.execute('SELECT count(*) FROM archivo_evidencia f JOIN evidencia e USING(id_evidencia) WHERE e.id_caso=%s',(cid,))
    if cur.fetchone()[0]>=5:raise HTTPException(409,'Máximo cinco fotos por caso en esta beta')
    try:
        raw=base64.b64decode(datos.contenido_base64,validate=True)
        if len(raw)>2097152:raise ValueError()
        with Image.open(io.BytesIO(raw)) as im:
            if im.format not in ('JPEG','PNG','WEBP') or im.width*im.height>16000000:raise ValueError()
            im=ImageOps.exif_transpose(im).convert('RGB');im.thumbnail((2000,2000));out=io.BytesIO();im.save(out,format='JPEG',quality=88);clean=out.getvalue()
        if not 0<len(clean)<=2097152:raise ValueError()
    except (ValueError,binascii.Error,UnidentifiedImageError,OSError,Image.DecompressionBombError):
        raise HTTPException(422,'Foto inválida. Usa JPEG, PNG o WebP de hasta 2 MB y 16 megapíxeles.') from None
    key=f'privado/{uid}/{uuid.uuid4()}.jpg'
    cur.execute('''INSERT INTO evidencia(id_caso,id_usuario_autor,tipo,origen,clave_objeto,mime,tamano_bytes,sha256,estado_carga,clave_envio,recibida_en)
      VALUES(%s,%s,'foto','archivo_adjuntado',%s,'image/jpeg',%s,%s,'recibido',%s,CURRENT_TIMESTAMP) RETURNING id_evidencia''',(cid,uid,key,len(clean),hashlib.sha256(clean).digest(),str(datos.clave_envio)));eid=cur.fetchone()[0]
    cur.execute('INSERT INTO archivo_evidencia(id_evidencia,contenido) VALUES(%s,%s)',(eid,clean))
    return {'id_evidencia':eid,'estado_revision':'pendiente','mensaje':'Foto privada recibida; se eliminan metadatos de ubicación. No acredita por sí sola la veracidad del reporte.'}

@router.get('/evidencias/{eid}/foto')
def descargar(eid:int,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor();cur.execute('SELECT id_caso FROM evidencia WHERE id_evidencia=%s',(eid,));row=cur.fetchone()
    if not row:raise HTTPException(404,'Foto no disponible')
    caso_autorizado(cur,row[0],usuario)
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
    cur=conn.cursor();cur.execute('''SELECT id_notificacion,id_caso,titulo,mensaje,creada_en,leida_en FROM notificacion WHERE id_usuario=%s ORDER BY creada_en DESC LIMIT 100''',(usuario['id_usuario'],));return rows(cur)
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
