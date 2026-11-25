from dataclasses import replace
from datetime import datetime, timezone
from uuid import uuid4

import pytest

from app import alertas
from app.routers import alertas as gestion
from test_casos import _reporte
from test_beta_colaborativa import foto_payload
from test_identidad_mvp import activar


@pytest.fixture
def piloto(client, db, supervisor_org1, monkeypatch):
    monkeypatch.setattr(alertas,'config',replace(alertas.config,alertas_automaticas=True))
    _, _, titular, _ = activar(client)
    _, _, colaborador, _ = activar(client)
    patente = uuid4().hex[:4].translate(str.maketrans('0123456789','GHIJKLMNOP')).upper()+'19'
    r = client.post('/vehiculos',headers=titular,json={
        'marca':'TOYOTA','modelo':'YARIS','patente':patente,'color':'Azul','anio':2020,
    })
    assert r.status_code==201,r.text
    vid=r.json()['id_vehiculo']
    assert client.post(f'/vehiculos/{vid}/revision-vinculo',headers=titular,json={'id_organizacion':1}).status_code==204
    v=next(v for v in client.get('/gestion/vinculos',headers=supervisor_org1).json() if v['patente']==patente)
    db("UPDATE organizacion SET alertas_provisionales_habilitadas=TRUE WHERE id_organizacion=1")
    return titular,colaborador,supervisor_org1,vid,v['id_vinculo_vehiculo']


def decision(client,piloto,estado='autorizado'):
    _,_,op,_,vinculo=piloto
    cuerpo={'decision':estado,'estado_esperado':'pendiente' if estado=='autorizado' else 'autorizado',
            'motivo':'padron_y_coincidencia' if estado=='autorizado' else 'uso_indebido','referencia':'VIN-ENSAYO-01'}
    return client.post(f'/gestion/vinculos/{vinculo}/decision',headers=op,json=cuerpo)


def reportar(client,piloto,consentimiento=True,clave=None):
    titular,_,_,vid,_=piloto
    return client.post('/casos',headers={**titular,'Idempotency-Key':clave or str(uuid4())},
        json=_reporte(id_vehiculo=vid,confirmar_sustraccion=True,solicitar_colaboracion=consentimiento,zona='Chillán · Ensayo'))


def datos_alerta(client,piloto,cid):
    return client.get(f'/seguimiento/{cid}',headers=piloto[2]).json()


@pytest.mark.parametrize('control',['vinculo_pendiente','revocado','sin_consentimiento','organizacion','interruptor','bloqueo'])
def test_causas_de_no_publicacion(client,db,piloto,monkeypatch,control):
    if control!='vinculo_pendiente':
        assert decision(client,piloto).status_code==204
    if control=='revocado':
        assert decision(client,piloto,'revocado').status_code==204
    if control=='organizacion':
        db('UPDATE organizacion SET alertas_provisionales_habilitadas=FALSE WHERE id_organizacion=1')
    if control=='interruptor':
        monkeypatch.setattr(alertas,'config',replace(alertas.config,alertas_automaticas=False))
    if control=='bloqueo':
        db("UPDATE usuario SET estado='suspendido' WHERE id_usuario=(SELECT id_usuario FROM vinculo_vehiculo WHERE id_vinculo_vehiculo=%s)",(piloto[4],))
    r=reportar(client,piloto,control!='sin_consentimiento')
    if control in ('revocado','bloqueo'):
        assert r.status_code in (401,403),r.text
        return
    assert r.status_code==201,r.text
    assert r.json()['publicacion']==('privada' if control=='sin_consentimiento' else 'pendiente')
    assert datos_alerta(client,piloto,r.json()['id_caso'])['alerta'] is None


def test_provisional_reintento_avistamiento_y_suspension(client,db,piloto,operador_org2):
    titular,colaborador,op,_,vinculo=piloto
    intento=client.post(f'/gestion/vinculos/{vinculo}/decision',headers=titular,
        json={'decision':'autorizado','estado_esperado':'pendiente','motivo':'padron_y_coincidencia','referencia':'ABC-12'})
    assert intento.status_code==403
    assert decision(client,piloto).status_code==204
    clave=str(uuid4())
    reporte=reportar(client,piloto,clave=clave)
    assert reporte.status_code==201,reporte.text
    assert reporte.json()['publicacion']=='provisional'
    cid=reporte.json()['id_caso']
    assert reportar(client,piloto,clave=clave).json()['id_caso']==cid
    assert reportar(client,piloto).status_code==409
    ficha=datos_alerta(client,piloto,cid)
    sid,rev=ficha['alerta']['id_solicitud_colaboracion'],ficha['revision_alerta']
    path=f'/colaboracion/{sid}'
    publica=client.get(path,headers=colaborador).json()
    assert publica['modo_alerta']=='provisional' and publica['zona_publicable']=='Chillán'
    assert not {'referencia_revision','descripcion_privada','id_usuario_reportante'} & publica.keys()
    datos={'observado_en':datetime.now(timezone.utc).isoformat(),'zona':'Lugar de prueba',
           'descripcion':'Avistamiento ficticio del ejercicio','latitud':-36.61,'longitud':-72.10}
    assert client.post(path+'/avistamientos',headers={**colaborador,'Idempotency-Key':str(uuid4())},json=datos).status_code==201
    cuerpo={'revision':rev,'motivo':'Revisión de posible abuso en el ensayo'}
    url=f'/gestion/casos/{cid}/suspender-alerta'
    assert client.post(url,headers=operador_org2,json=cuerpo).status_code==403
    assert client.post(url,headers=op,json=cuerpo).status_code==204
    assert client.post(url,headers=op,json=cuerpo).status_code==409
    assert client.get(path,headers=colaborador).status_code==404
    assert client.post(path+'/avistamientos',headers={**colaborador,'Idempotency-Key':str(uuid4())},json=datos).status_code==409
    assert db("SELECT count(*) FROM gestion_caso WHERE id_caso=%s AND accion='suspension_alerta'",(cid,),filas=True)==[(1,)]


@pytest.mark.parametrize('resultado',['sin_resultado','no_disponible','encontrado'])
def test_consulta_manual_separada_y_vencimiento(client,db,piloto,monkeypatch,resultado):
    assert decision(client,piloto).status_code==204
    titular,colaborador,op,_,_=piloto
    r=reportar(client,piloto)
    assert r.status_code==201,r.text
    cid=r.json()['id_caso']
    ficha=datos_alerta(client,piloto,cid)
    sid=ficha['alerta']['id_solicitud_colaboracion']
    ruta=f'/gestion/casos/{cid}/encargo'
    entrada={'revision':ficha['revision_alerta'],'resultado':resultado,'motivo':'Resultado del ensayo local','referencia':'AS-ENSAYO'}
    assert client.post(ruta,headers=titular,json={**entrada,'simulada':True}).status_code==403
    monkeypatch.setattr(gestion,'config',replace(gestion.config,alertas_demo=False))
    assert client.post(ruta,headers=op,json={**entrada,'simulada':True}).status_code==403
    assert client.post(ruta,headers=op,json=entrada).status_code==204
    assert client.post(ruta,headers=op,json=entrada).status_code==409
    ficha=datos_alerta(client,piloto,cid)
    assert ficha['denuncia_estado']=='no_informada' and ficha['consultas_encargo'][0]['resultado']==resultado
    assert ficha['alerta']['modo_alerta']==('encargo_comprobado' if resultado=='encontrado' else 'provisional')
    db("""UPDATE solicitud_colaboracion SET inicio=CURRENT_TIMESTAMP-interval '2 hours',
        vence_en=CURRENT_TIMESTAMP-interval '1 minute' WHERE id_solicitud_colaboracion=%s""",(sid,))
    assert client.get(f'/colaboracion/{sid}',headers=colaborador).status_code==404
    assert client.post('/gestion/alertas/vencimiento',headers=op).json()['procesadas']>=1
    assert any(n['titulo']=='Alerta vencida' and n['id_caso']==cid for n in client.get('/notificaciones',headers=titular).json())


@pytest.mark.parametrize('accion',['retirar_consentimiento','informar_recuperacion'])
def test_titular_detiene_difusion_preservando_caso(client,piloto,accion):
    assert decision(client,piloto).status_code==204
    titular,colaborador,_,_,_=piloto
    cid=reportar(client,piloto).json()['id_caso']
    sid=datos_alerta(client,piloto,cid)['alerta']['id_solicitud_colaboracion']
    url=f'/mis-casos/{cid}/alerta'
    assert client.post(url,headers=colaborador,json={'accion':accion}).status_code==403
    assert client.post(url,headers=titular,json={'accion':accion}).status_code==204
    assert client.get(f'/colaboracion/{sid}',headers=colaborador).status_code==404
    ficha=client.get(f'/seguimiento/{cid}',headers=titular).json()
    assert ficha['estado']!='cerrado' and ficha['alerta']['suspendida_en']


def test_captura_encargo_privada_y_auditoria(client,piloto,operador_org2,db):
    assert decision(client,piloto).status_code==204
    titular,colaborador,op,_,_=piloto
    cid=reportar(client,piloto).json()['id_caso']
    ficha=datos_alerta(client,piloto,cid)
    entrada={'revision':ficha['revision_alerta'],'resultado':'sin_resultado',
        'motivo':'Consulta documentada del ensayo','evidencia_base64':foto_payload()['contenido_base64']}
    assert client.post(f'/gestion/casos/{cid}/encargo',headers=op,json=entrada).status_code==204
    ficha=datos_alerta(client,piloto,cid)
    eid=ficha['consultas_encargo'][0]['id_evidencia']
    assert eid and not ficha['evidencias']
    for bloqueado in (titular,colaborador,operador_org2):
        assert client.get(f'/evidencias/{eid}/foto',headers=bloqueado).status_code==403
    assert client.get(f'/evidencias/{eid}/foto',headers=op).headers['content-type']=='image/jpeg'
    sid=ficha['alerta']['id_solicitud_colaboracion']
    assert client.get(f'/colaboracion/{sid}/foto-vehiculo',headers=colaborador).status_code==404


def test_revocacion_del_vinculo_apaga_una_alerta_activa(client,piloto):
    assert decision(client,piloto).status_code==204
    _,colaborador,_,_,_=piloto
    cid=reportar(client,piloto).json()['id_caso']
    sid=datos_alerta(client,piloto,cid)['alerta']['id_solicitud_colaboracion']
    assert decision(client,piloto,'revocado').status_code==204
    assert client.get(f'/colaboracion/{sid}',headers=colaborador).status_code==404
