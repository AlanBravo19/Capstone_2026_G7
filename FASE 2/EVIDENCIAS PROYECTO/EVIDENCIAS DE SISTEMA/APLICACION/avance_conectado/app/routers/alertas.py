"""Revisión anticipada y ciclo de alertas ciudadanas."""
from datetime import datetime, timezone
from typing import Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, ConfigDict, Field

from ..alertas import VIGENTE, avisar_equipo, entorno, vinculo_vigente
from ..antifraude import DEMO, administrador, limitar, participante
from ..config import config
from ..db import fila_dict, obtener_conexion
from ..seguridad import organizaciones_del_operador, usuario_actual
from ..revision_vehicular import SolicitarRevision, auditar_vinculo, guardar_solicitud, preparar_padron
from .. import prelectura_padron
from .colaboracion import FOTO_PUBLICABLE, aviso, bitacora, caso_autorizado, guardar_foto, rows
from .gestion_equipo import supervisor

router = APIRouter(tags=['alertas de vehículos'])

class Entrada(BaseModel):
    model_config = ConfigDict(extra='forbid',str_strip_whitespace=True)

class DecisionVinculo(Entrada):
    decision: Literal['autorizado','rechazado','revocado']
    estado_esperado: Literal['pendiente','autorizado']
    motivo: Literal['padron_y_coincidencia', 'padron_y_autorizacion',
                     'documentacion_insuficiente','datos_inconsistentes','cambio_o_retiro','uso_indebido']
    referencia: str | None = Field(default=None,pattern=r'^[A-Za-z][A-Za-z0-9_-]{3,79}$')
    confirmar_padron: bool = False

@router.post('/vehiculos/{vid}/revision-vinculo',status_code=204)
def solicitar_revision(vid:int,datos:SolicitarRevision,usuario=Depends(participante),conn=Depends(obtener_conexion)):
    uid = usuario['id_usuario']
    cur=conn.cursor()
    imagen, prelectura = None, None
    if datos.padron_base64 is not None:
        cur.execute("""SELECT a.patente,d.contenido IS NOT NULL,v.id_organizacion_revision
            FROM vinculo_vehiculo v JOIN vehiculo a USING(id_vehiculo)
            LEFT JOIN documento_vinculo_vehiculo d USING(id_vinculo_vehiculo)
            WHERE v.id_usuario=%s AND a.id_vehiculo=%s AND v.estado='pendiente' AND v.fin IS NULL""", (uid, vid))
        actual = cur.fetchone()
        if not actual:
            raise HTTPException(409, 'Se requiere un vínculo pendiente de tu cuenta.')
        patente, recibido, organizacion = actual
        puede_cotejar = not recibido and organizacion in (None, datos.id_organizacion)
        if puede_cotejar and datos.autorizar_prelectura and prelectura_padron.operativa():
            limitar(conn, f'padron:{uid}', 8)
        imagen, prelectura = preparar_padron(datos, patente, cotejar=puede_cotejar)
        cur.execute('SELECT estado FROM usuario WHERE id_usuario=%s FOR UPDATE', (uid,))
        if cur.fetchone() != ('activo',):
            raise HTTPException(403, 'Cuenta restringida.')
    cur.execute("SELECT id_vehiculo FROM vehiculo WHERE id_vehiculo=%s FOR UPDATE",(vid,))
    cur.execute("""SELECT id_vinculo_vehiculo,id_organizacion_revision FROM vinculo_vehiculo
        WHERE id_usuario=%s AND id_vehiculo=%s AND estado='pendiente' AND fin IS NULL FOR UPDATE""",
        (uid,vid))
    fila=cur.fetchone()
    if not fila:raise HTTPException(409,'Se requiere un vínculo pendiente de tu cuenta.')
    guardar_solicitud(cur, uid, fila[0], fila[1], datos, imagen, prelectura)

@router.get('/gestion/vinculos')
def vinculos(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    orgs=organizaciones_del_operador(cur,usuario['id_usuario'])
    if not orgs:raise HTTPException(403,'Se requiere membresía vigente.')
    cur.execute("""SELECT vv.id_vinculo_vehiculo,v.patente,vv.id_organizacion_revision,
        vv.tipo,vv.estado,vv.inicio,vv.revisado_en,vv.vence_revision_en,vv.motivo_revision,
        o.nombre AS organizacion,d.tipo_documento,d.recibido_en AS padron_recibido_en,
        (SELECT e.resumen FROM evento_auditoria e WHERE e.objeto_tipo='vinculo_vehiculo'
         AND e.objeto_id=vv.id_vinculo_vehiculo::text AND e.accion='prelectura_padron'
         AND e.creado_en>=d.recibido_en ORDER BY e.creado_en DESC LIMIT 1) AS padron_prelectura,
        (vv.estado='pendiente' AND vv.fin IS NULL AND d.contenido IS NOT NULL) AS padron_disponible,
        uu.nombre_visible AS solicitante,rv.nombre_visible AS revisor,
        EXISTS(SELECT 1 FROM membresia m WHERE m.id_usuario=%s AND m.id_organizacion=vv.id_organizacion_revision
            AND m.estado='activa' AND m.fin IS NULL AND m.inicio<=CURRENT_TIMESTAMP AND m.rol='supervisor')
            AND vv.id_usuario<>%s AS puede_revisar
        FROM vinculo_vehiculo vv JOIN vehiculo v USING(id_vehiculo)
        JOIN usuario uu ON uu.id_usuario=vv.id_usuario
        JOIN organizacion o ON o.id_organizacion=vv.id_organizacion_revision
        LEFT JOIN documento_vinculo_vehiculo d USING(id_vinculo_vehiculo)
        LEFT JOIN usuario rv ON rv.id_usuario=vv.revisado_por
        WHERE vv.id_organizacion_revision=ANY(%s)
        ORDER BY (vv.estado='pendiente') DESC,vv.inicio DESC LIMIT 100""",(usuario['id_usuario'],usuario['id_usuario'],orgs))
    prelectura_activa = prelectura_padron.disponible()
    return [{**fila, 'prelectura_disponible': prelectura_activa and fila['puede_revisar'] and fila['padron_disponible']
             and fila['patente'] == prelectura_padron.PATENTE_ENSAYO} for fila in rows(cur)]

def padron_en_revision(cur, id_vinculo, uid):
    cur.execute('''SELECT v.id_organizacion_revision,auto.patente FROM vinculo_vehiculo v
        JOIN vehiculo auto USING(id_vehiculo)
        WHERE v.id_vinculo_vehiculo=%s AND v.id_usuario<>%s AND v.estado='pendiente'
        AND v.fin IS NULL FOR SHARE OF v''', (id_vinculo, uid))
    fila = cur.fetchone()
    if not fila or fila[0] not in organizaciones_del_operador(cur, uid) or not supervisor(cur, uid, fila[0]):
        raise HTTPException(404, 'Padrón no disponible para esta cuenta.')
    cur.execute('SELECT contenido FROM documento_vinculo_vehiculo WHERE id_vinculo_vehiculo=%s', (id_vinculo,))
    documento = cur.fetchone()
    if not documento or documento[0] is None:
        raise HTTPException(404, 'Esta solicitud no tiene un padrón adjunto disponible.')
    return bytes(documento[0]), fila[1]


@router.get('/gestion/vinculos/{id_vinculo}/padron')
def ver_padron(id_vinculo:int,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    uid = usuario['id_usuario']
    cur = conn.cursor()
    documento, _ = padron_en_revision(cur, id_vinculo, uid)
    auditar_vinculo(cur, uid, id_vinculo, 'consultar_padron', 'Padrón consultado por supervisión.')
    return Response(documento, media_type='image/jpeg', headers={
        'Cache-Control': 'private, no-store', 'X-Content-Type-Options': 'nosniff',
        'Content-Disposition': 'inline; filename="padron.jpg"',
    })


class Prelectura(Entrada):
    archivo_ficticio: Literal[True]


@router.post('/gestion/vinculos/{id_vinculo}/prelectura')
def preleer_padron(id_vinculo:int, datos:Prelectura, usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    if not prelectura_padron.disponible():
        raise HTTPException(404, 'La prelectura está disponible únicamente en un ensayo configurado.')
    uid = usuario['id_usuario']
    cur = conn.cursor()
    documento, patente = padron_en_revision(cur, id_vinculo, uid)
    conn.commit()  # Liberar la fila antes de esperar a un proveedor de ensayo.
    resultado = prelectura_padron.analizar(documento, patente)
    auditar_vinculo(cur, uid, id_vinculo, 'prelectura_padron_ensayo', resultado['resultado'])
    return resultado

@router.post('/gestion/vinculos/{id_vinculo}/decision',status_code=204)
def decidir_vinculo(id_vinculo:int,datos:DecisionVinculo,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    uid=usuario['id_usuario']
    cur=conn.cursor()
    cur.execute('SELECT id_vehiculo FROM vinculo_vehiculo WHERE id_vinculo_vehiculo=%s',(id_vinculo,))
    fila=cur.fetchone()
    if not fila:raise HTTPException(404,'Solicitud no disponible.')
    cur.execute("SELECT id_vehiculo FROM vehiculo WHERE id_vehiculo=%s FOR UPDATE",(fila[0],))
    cur.execute("""SELECT * FROM vinculo_vehiculo WHERE id_vinculo_vehiculo=%s FOR UPDATE""",(id_vinculo,))
    v=fila_dict(cur,cur.fetchone())
    org=v['id_organizacion_revision']
    if not org or v['id_usuario']==uid or org not in organizaciones_del_operador(cur,uid) or not supervisor(cur,uid,org):
        raise HTTPException(403,'Se requiere supervisión de la organización y un revisor distinto del solicitante.')
    if v['estado']!=datos.estado_esperado or v['fin'] is not None:
        raise HTTPException(409,'El vínculo cambió. Actualiza la lista antes de decidir.')
    referencia = datos.referencia
    if datos.decision=='autorizado':
        cur.execute('SELECT tipo_documento FROM documento_vinculo_vehiculo WHERE id_vinculo_vehiculo=%s AND contenido IS NOT NULL', (id_vinculo,))
        documento = cur.fetchone()
        if documento:
            if not datos.confirmar_padron:
                raise HTTPException(422, 'Confirma la revisión del documento, la identidad del titular y la patente.')
            cur.execute("""SELECT 1 FROM evento_auditoria WHERE id_usuario=%s AND objeto_tipo='vinculo_vehiculo'
                AND objeto_id=%s AND accion='consultar_padron' ORDER BY creado_en DESC LIMIT 1""", (uid, str(id_vinculo)))
            if not cur.fetchone():
                raise HTTPException(422, 'Abre el documento privado antes de aprobar este vínculo.')
            referencia = f'{documento[0].upper()}-{id_vinculo}'
        motivo_correcto='padron_y_autorizacion' if v['tipo']=='conductor_autorizado' else 'padron_y_coincidencia'
        if v['estado']!='pendiente' or datos.motivo!=motivo_correcto or not referencia:
            raise HTTPException(422,'Registra la revisión documental adecuada y una referencia interna protegida.')
        cur.execute("""SELECT 1 FROM vinculo_vehiculo WHERE id_vehiculo=%s AND id_vinculo_vehiculo<>%s
            AND fin IS NULL AND estado IN ('pendiente','autorizado') AND tipo='propietario'
            AND %s='propietario'""",(v['id_vehiculo'],id_vinculo,v['tipo']))
        if cur.fetchone():raise HTTPException(409,'Hay otro vínculo de propietario sin resolver.')
    elif datos.decision=='rechazado' and (v['estado']!='pendiente' or datos.motivo not in ('documentacion_insuficiente','datos_inconsistentes','uso_indebido')):
        raise HTTPException(422,'Selecciona un motivo de rechazo para un vínculo pendiente.')
    elif datos.decision=='revocado' and (v['estado']!='autorizado' or datos.motivo not in ('cambio_o_retiro','uso_indebido','datos_inconsistentes')):
        raise HTTPException(422,'Selecciona un motivo de revocación para un vínculo aprobado.')
    cur.execute("""UPDATE vinculo_vehiculo SET estado=%s,revisado_por=%s,revisado_en=CURRENT_TIMESTAMP,
        motivo_revision=%s,referencia_revision=COALESCE(%s,referencia_revision),
        vence_revision_en=CASE WHEN %s='autorizado' THEN CURRENT_TIMESTAMP+interval '365 days' END,
        fin=CASE WHEN %s<>'autorizado' THEN CURRENT_TIMESTAMP END WHERE id_vinculo_vehiculo=%s""",
        (datos.decision,uid,datos.motivo,referencia,datos.decision,datos.decision,id_vinculo))
    cur.execute('UPDATE documento_vinculo_vehiculo SET contenido=NULL WHERE id_vinculo_vehiculo=%s', (id_vinculo,))
    auditar_vinculo(cur,uid,id_vinculo,'decision_vinculo',f'{datos.decision}: {datos.motivo}')
    aviso(cur,v['id_usuario'],None,'Revisión de tu vínculo',f'Resultado: {datos.decision.replace("_"," ")}. Consulta Mis vehículos.',f'vinculo:{id_vinculo}:{datos.decision}')

class DecisionCaso(Entrada):
    revision: int = Field(ge=0)
    motivo: str = Field(min_length=10,max_length=500)

class Encargo(DecisionCaso):
    resultado: Literal['encontrado','sin_resultado','no_disponible']
    referencia: str | None = Field(default=None,pattern=r'^[A-Za-z][A-Za-z0-9_-]{3,79}$')
    foto: int | None = Field(default=None,gt=0)
    evidencia_base64: str | None = Field(default=None,min_length=16,max_length=2800000)
    simulada: bool = False

def caso_versionado(cur,cid,usuario,revision):
    c=caso_autorizado(cur,cid,usuario,operador=True)
    cur.execute('SELECT id_vehiculo,revision_alerta,entorno FROM caso WHERE id_caso=%s',(cid,))
    c.update(fila_dict(cur,cur.fetchone()))
    if c['revision_alerta']!=revision:
        raise HTTPException(409,'Otro operador actualizó el expediente. Recarga antes de continuar.')
    if c['estado']=='cerrado':raise HTTPException(409,'Caso cerrado.')
    return c

def subir_revision(cur,cid):
    cur.execute('UPDATE caso SET revision_alerta=revision_alerta+1 WHERE id_caso=%s',(cid,))

def resumen_alerta(cur,cid):
    cur.execute("""SELECT revision_alerta,sustraccion_declarada_en FROM caso WHERE id_caso=%s""",(cid,))
    info=fila_dict(cur,cur.fetchone())
    cur.execute(f"""SELECT s.id_solicitud_colaboracion,s.estado,s.modo_alerta,s.suspendida_en,
        s.vence_en,({VIGENTE}) AS visible FROM solicitud_colaboracion s JOIN caso c USING(id_caso)
        WHERE c.id_caso=%s ORDER BY s.id_solicitud_colaboracion DESC LIMIT 1""",(cid,))
    info['alerta']=fila_dict(cur,cur.fetchone())
    cur.execute("""SELECT q.resultado,q.fuente,q.consultada_en,q.referencia,q.observacion,q.simulada,q.id_evidencia,
        u.nombre_visible AS operador FROM consulta_encargo q JOIN usuario u ON u.id_usuario=q.id_operador
        WHERE q.id_caso=%s ORDER BY q.id_consulta_encargo DESC LIMIT 25""",(cid,))
    info['consultas_encargo']=rows(cur)
    info['simulacion_disponible']=config.alertas_demo and DEMO
    return info

@router.post('/gestion/casos/{cid}/encargo',status_code=204)
def registrar_encargo(cid:int,datos:Encargo,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    c=caso_versionado(cur,cid,usuario,datos.revision)
    if config.alertas_demo and DEMO and not datos.simulada:
        raise HTTPException(422,'En esta demostración los resultados deben marcarse como simulados.')
    if datos.simulada:
        if not (config.alertas_demo and DEMO and c['entorno']=='prueba' and
                supervisor(cur,usuario['id_usuario'],c['id_organizacion'])):
            raise HTTPException(403,'Simulación disponible solo en la demostración aislada.')
        administrador(usuario,conn)
    if datos.resultado=='encontrado' and not datos.referencia:
        raise HTTPException(422,'Ingresa una referencia interna para respaldar la consulta positiva.')
    if datos.foto is not None and datos.resultado!='encontrado':
        raise HTTPException(422,'Para cambiar la foto usa una publicación revisada con encargo encontrado.')
    if datos.foto is not None:
        cur.execute(f"""SELECT 1 FROM evidencia e JOIN archivo_evidencia f USING(id_evidencia)
            JOIN caso c ON c.id_caso=e.id_caso WHERE e.id_evidencia=%s AND c.id_caso=%s AND {FOTO_PUBLICABLE}""",
            (datos.foto,cid))
        if not cur.fetchone():raise HTTPException(422,'Foto fuera del caso o sin aceptación y consentimiento.')
    fuente='Simulador RutaAlerta' if datos.simulada else 'Auto Seguro'
    evidencia=None
    if datos.evidencia_base64:
        evidencia=guardar_foto(cur,cid,usuario['id_usuario'],uuid4(),datos.evidencia_base64)
    cur.execute("""INSERT INTO consulta_encargo(id_caso,id_operador,resultado,fuente,referencia,observacion,simulada,id_evidencia)
        VALUES(%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id_consulta_encargo""",
        (cid,usuario['id_usuario'],datos.resultado,fuente,datos.referencia,datos.motivo,datos.simulada,evidencia))
    consulta=cur.fetchone()[0]
    if datos.resultado=='encontrado':
        cur.execute(f"""UPDATE solicitud_colaboracion s SET modo_alerta='encargo_comprobado',
            id_foto_vehiculo=COALESCE(%s,s.id_foto_vehiculo)
            FROM caso c WHERE c.id_caso=%s AND s.id_caso=c.id_caso AND {VIGENTE}""",(datos.foto,cid))
    else:
        cur.execute("""UPDATE solicitud_colaboracion SET modo_alerta=CASE
            WHEN id_vinculo_verificado IS NULL THEN 'revisada' ELSE 'provisional' END
            WHERE id_caso=%s AND estado='publicada' AND modo_alerta='encargo_comprobado'""",(cid,))
    subir_revision(cur,cid)
    bitacora(cur,cid,usuario['id_usuario'],'consulta_encargo',f'{fuente} · {datos.resultado} · {datos.motivo}','interna')
    textos={'encontrado':'Encargo encontrado en la consulta registrada.',
        'sin_resultado':'La consulta no encontró un encargo en ese momento.',
        'no_disponible':'La consulta quedó pendiente por indisponibilidad de la fuente.'}
    aviso(cur,c['id_usuario_reportante'],cid,'Actualización de la consulta',
          ('Simulación · ' if datos.simulada else '')+textos[datos.resultado],f'encargo:{consulta}')

def suspender(cur,cid):
    cur.execute("""UPDATE solicitud_colaboracion SET suspendida_en=CURRENT_TIMESTAMP
        WHERE id_caso=%s AND estado='publicada' AND suspendida_en IS NULL
        AND vence_en>CURRENT_TIMESTAMP RETURNING id_solicitud_colaboracion""",(cid,))
    return cur.fetchone()

@router.post('/gestion/casos/{cid}/suspender-alerta',status_code=204)
def suspender_alerta(cid:int,datos:DecisionCaso,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    c=caso_versionado(cur,cid,usuario,datos.revision)
    s=suspender(cur,cid)
    if not s:raise HTTPException(409,'Actualmente no hay una alerta activa para suspender.')
    subir_revision(cur,cid)
    bitacora(cur,cid,usuario['id_usuario'],'suspension_alerta',datos.motivo,'interna')
    aviso(cur,c['id_usuario_reportante'],cid,'Difusión suspendida','El expediente continúa disponible para revisión.',f'suspension:{s[0]}')

class InformeTitular(Entrada):
    accion: Literal['retirar_consentimiento','informar_recuperacion']

@router.post('/mis-casos/{cid}/alerta',status_code=204)
def actualizar_alerta_titular(cid:int,datos:InformeTitular,usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    c=caso_autorizado(cur,cid,usuario,propietario=True)
    if c['estado']=='cerrado':raise HTTPException(409,'Caso cerrado.')
    if c['colaboracion_consentida_en'] is None and datos.accion=='retirar_consentimiento':
        return
    if datos.accion=='informar_recuperacion':
        cur.execute("""SELECT 1 FROM gestion_caso WHERE id_caso=%s AND accion='informar_recuperacion'""",(cid,))
        if cur.fetchone():return
    suspender(cur,cid)
    cur.execute('UPDATE caso SET colaboracion_consentida_en=NULL WHERE id_caso=%s',(cid,))
    subir_revision(cur,cid)
    texto=('Recuperación informada por el titular. Pendiente de revisión institucional.'
           if datos.accion=='informar_recuperacion' else 'El titular retiró el consentimiento de colaboración.')
    bitacora(cur,cid,usuario['id_usuario'],datos.accion,texto)
    avisar_equipo(cur,c['id_organizacion'],cid,'Revisar expediente',texto,f'{datos.accion}:{cid}')

@router.post('/gestion/alertas/vencimiento')
def vencer_alertas(usuario=Depends(usuario_actual),conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    orgs=organizaciones_del_operador(cur,usuario['id_usuario'])
    if not orgs:raise HTTPException(403,'Se requiere membresía institucional.')
    return {'procesadas':procesar_vencimientos(cur,orgs)}

def procesar_vencimientos(cur,orgs=None):
    """Una transacción por lote, incluida la auditoría y los avisos internos."""
    cur.execute("""SELECT c.id_caso,s.id_solicitud_colaboracion,c.id_organizacion,c.id_usuario_reportante
        FROM caso c JOIN solicitud_colaboracion s USING(id_caso)
        WHERE (%s::bigint[] IS NULL OR c.id_organizacion=ANY(%s))
        AND s.estado='publicada' AND s.vence_en<=CURRENT_TIMESTAMP
        ORDER BY s.vence_en LIMIT 50 FOR UPDATE OF c SKIP LOCKED""",(orgs,orgs))
    lote=rows(cur)
    for item in lote:
        cid,sid=item['id_caso'],item['id_solicitud_colaboracion']
        cur.execute("UPDATE solicitud_colaboracion SET estado='vencida' WHERE id_solicitud_colaboracion=%s AND estado='publicada' RETURNING 1",(sid,))
        if not cur.fetchone():continue
        subir_revision(cur,cid)
        cur.execute("""INSERT INTO evento_auditoria(accion,objeto_tipo,objeto_id,resultado,correlacion,resumen)
            VALUES('vencimiento_alerta','caso',%s,'exito',%s,'Vencimiento detectado por el servicio.')""",
            (str(cid),uuid4()))
        aviso(cur,item['id_usuario_reportante'],cid,'Alerta vencida','La difusión terminó. El expediente sigue disponible.',f'vencimiento:{sid}')
        avisar_equipo(cur,item['id_organizacion'],cid,'Alerta vencida','Revisa el caso antes de publicar nuevamente.',f'vencimiento:{sid}')
    return len(lote)
