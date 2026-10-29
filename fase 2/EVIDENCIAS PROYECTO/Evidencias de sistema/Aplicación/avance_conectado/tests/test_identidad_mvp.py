"""Pruebas nuevas de este avance; no se reasignan los CP del plan anterior."""
import uuid
import pytest
from app.antifraude import limitar
from app.db import conectar
from test_casos import _reporte

CLAVE='Clave-de-ensayo-2026'

def cuenta(client):
    mail=f'mvp-{uuid.uuid4().hex[:12]}@example.invalid'
    r=client.post('/cuentas',json={'nombre_visible':'Ensayo ficticio','correo':mail,'clave':CLAVE})
    assert r.status_code==201,r.text
    uid=r.json()['id_usuario']
    r=client.post('/sesiones',json={'correo':mail,'clave':CLAVE})
    assert r.status_code==201,r.text
    return uid,mail,{'Authorization':'Bearer '+r.json()['token']}

def correo(client,h):
    r=client.post('/identidad/correo/solicitar',headers=h)
    assert r.status_code==202,r.text
    token=r.json()['token_demo']
    assert client.post('/identidad/correo/confirmar',json={'token':token}).status_code==200
    return token

def desafio(client,h,numero):
    r=client.post('/identidad/telefono/solicitar',headers=h,json={'telefono':numero})
    assert r.status_code==202,r.text
    return {'id_desafio':r.json()['id_desafio'],'codigo':r.json()['codigo_demo']}

def numero():return '+569'+str(uuid.uuid4().int%100000000).zfill(8)

def activar(client):
    uid,mail,h=cuenta(client);correo(client,h);tel=numero()
    assert client.post('/identidad/telefono/confirmar',headers=h,json=desafio(client,h,tel)).status_code==200
    return uid,mail,h,tel

def test_flujo_contactos_y_caso(client,db):
    uid,mail,h=cuenta(client)
    assert not client.get('/identidad/mi-estado',headers=h).json()['puede_participar']
    db("INSERT INTO vinculo_vehiculo(id_usuario,id_vehiculo,tipo) VALUES(%s,1,'propietario')",(uid,))
    head={**h,'Idempotency-Key':str(uuid.uuid4())}
    assert client.post('/casos',headers=head,json=_reporte()).status_code==403
    token=correo(client,h)
    assert client.post('/identidad/correo/confirmar',json={'token':token}).status_code==400
    challenge=desafio(client,h,numero())
    assert client.post('/identidad/telefono/confirmar',headers=h,json=challenge).status_code==200
    assert client.post('/identidad/telefono/confirmar',headers=h,json=challenge).status_code==400
    assert client.get('/identidad/mi-estado',headers=h).json()['puede_participar']
    assert client.post('/casos',headers=head,json=_reporte()).status_code==201

def test_telefono_duplicado_no_habilita_otra_cuenta(client):
    _,_,_,tel=activar(client)
    _,_,h=cuenta(client);correo(client,h)
    r=client.post('/identidad/telefono/confirmar',headers=h,json=desafio(client,h,tel))
    assert r.status_code==409
    assert not client.get('/identidad/mi-estado',headers=h).json()['puede_participar']

def test_numero_no_se_reserva_antes_de_verificar(client):
    _,_,h1=cuenta(client);correo(client,h1)
    _,_,h2=cuenta(client);correo(client,h2)
    tel=numero();desafio(client,h1,tel)
    assert client.post('/identidad/telefono/confirmar',headers=h2,json=desafio(client,h2,tel)).status_code==200

def test_codigo_fallido_persiste_y_agota(client,db):
    uid,_,h=cuenta(client);correo(client,h);ch=desafio(client,h,numero())
    malo={**ch,'codigo':'000000' if ch['codigo']!='000000' else '111111'}
    for _ in range(5):assert client.post('/identidad/telefono/confirmar',headers=h,json=malo).status_code==400
    assert db('SELECT intentos FROM desafio_telefono WHERE id_desafio=%s::uuid',(ch['id_desafio'],),filas=True)[0][0]==5
    assert client.post('/identidad/telefono/confirmar',headers=h,json=ch).status_code==400

def test_codigo_vencido(client,db):
    _,_,h=cuenta(client);correo(client,h);ch=desafio(client,h,numero())
    db("UPDATE desafio_telefono SET creado_en=CURRENT_TIMESTAMP-interval '10 minutes',vence_en=CURRENT_TIMESTAMP-interval '1 minute' WHERE id_desafio=%s::uuid",(ch['id_desafio'],))
    assert client.post('/identidad/telefono/confirmar',headers=h,json=ch).status_code==400

def test_codigo_no_transferible_entre_usuarios(client):
    _,_,h1=cuenta(client);correo(client,h1);ch=desafio(client,h1,numero())
    _,_,h2=cuenta(client)
    assert client.post('/identidad/telefono/confirmar',headers=h2,json=ch).status_code==400

def test_no_escalar_a_administrador(client):
    uid,_,h=cuenta(client)
    assert client.post(f'/moderacion/usuarios/{uid}/sanciones',headers=h,json={'accion':'bloqueo','motivo':'Ensayo de permisos restringidos'}).status_code==403

def test_baneo_revoca_sesiones_impide_reingreso_y_reuso_telefono(client,supervisor_org1,db):
    uid,mail,h,tel=activar(client)
    rec=client.post('/cuentas/recuperacion',json={'correo':mail}).json()['token_prueba']
    r=client.post(f'/moderacion/usuarios/{uid}/sanciones',headers=supervisor_org1,json={'accion':'bloqueo','motivo':'Abuso ficticio documentado en prueba'})
    assert r.status_code==201,r.text
    assert client.get('/identidad/mi-estado',headers=h).status_code==401
    assert client.post('/sesiones',json={'correo':mail,'clave':CLAVE}).status_code==401
    assert client.post('/cuentas/recuperacion/confirmar',json={'token':rec,'nueva_clave':'Otra-clave-2026'}).status_code==400
    assert client.post('/cuentas/recuperacion',json={'correo':mail}).json()['token_prueba'] is None
    assert client.post('/cuentas',json={'nombre_visible':'Nueva cuenta','correo':mail.upper(),'clave':CLAVE}).status_code==409
    _,_,h2=cuenta(client);correo(client,h2)
    assert client.post('/identidad/telefono/confirmar',headers=h2,json=desafio(client,h2,tel)).status_code==409
    assert db('SELECT count(*) FROM moderacion_usuario WHERE id_usuario_afectado=%s',(uid,),filas=True)[0][0]==1

def test_nueva_identidad_contacto_no_se_puede_identificar_infablemente(client,supervisor_org1):
    uid,_,_,_=activar(client)
    assert client.post(f'/moderacion/usuarios/{uid}/sanciones',headers=supervisor_org1,json={'accion':'suspension','motivo':'Suspensión de ensayo documentada'}).status_code==201
    # Límite explícito: otro correo y otro teléfono pueden participar, incluso en igual IP.
    _,_,h,_=activar(client)
    assert client.get('/identidad/mi-estado',headers=h).json()['puede_participar']

def test_limite_login_persiste_y_responde_retry_after(client):
    mail='inexistente-'+uuid.uuid4().hex+'@example.invalid'
    for _ in range(10):assert client.post('/sesiones',json={'correo':mail,'clave':'Incorrecta'}).status_code==401
    r=client.post('/sesiones',json={'correo':mail,'clave':'Incorrecta'})
    assert r.status_code==429 and int(r.headers['Retry-After'])>0

def test_cerrar_sesion(client):
    _,_,h=cuenta(client)
    assert client.post('/sesiones/cerrar',headers=h).status_code==204
    assert client.get('/identidad/mi-estado',headers=h).status_code==401

def test_telefono_formato_y_correo_previo(client):
    _,_,h=cuenta(client)
    assert client.post('/identidad/telefono/solicitar',headers=h,json={'telefono':'123'}).status_code==422
    assert client.post('/identidad/telefono/solicitar',headers=h,json={'telefono':numero()}).status_code==403
