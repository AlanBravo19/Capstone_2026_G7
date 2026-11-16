import time
import uuid
from datetime import datetime, timezone

import pytest
from pydantic import ValidationError
from app.routers.avance import VehiculoEntrada
from app.routers.seguridad_cuenta import codigo_totp
from test_identidad_mvp import CLAVE
from test_beta_colaborativa import publicacion
from test_casos import _reporte

def vehiculo(tipo,placa):
    marca,modelo=('HONDA','125CC') if tipo=='motocicleta' else ('TOYOTA','YARIS')
    return dict(tipo_vehiculo=tipo, marca=marca, modelo=modelo, patente=placa,color='Azul',anio=2020)

@pytest.mark.parametrize('tipo,placa', [('motocicleta','BC-123'),('motocicleta','BCD 12'),('motocicleta','BCDF1'),('automovil','BC1234'),('automovil','BC.DF-41'),('automovil','BCDFG1')])
def test_formatos(tipo,placa):
    assert VehiculoEntrada(**vehiculo(tipo,placa)).patente.isalnum()

@pytest.mark.parametrize('tipo,placa', [('motocicleta','BCDF12'),('automovil','BCD12'),('automovil','AB12CD'),('bus','BC1234')])
def test_formato_incompatible(tipo,placa):
    with pytest.raises(ValidationError):VehiculoEntrada(**vehiculo(tipo,placa))

def test_modelo_no_corresponde_a_la_marca():
    datos=vehiculo('motocicleta','BC123')
    datos.update(marca='TOYOTA',modelo='YARIS')
    with pytest.raises(ValidationError):VehiculoEntrada(**datos)

def test_registro_verificacion_y_colaboracion_sin_auto(client,monkeypatch,supervisor_org1):
    from app import correo
    from app.routers import identidad
    captured={}
    monkeypatch.setattr(correo,'correo_real',lambda:True)
    monkeypatch.setattr(identidad,'correo_real',lambda:True)
    monkeypatch.setattr(identidad,'enviar_codigo',lambda destinatario,codigo,*args:captured.update({destinatario:codigo}))

    def alta():
        email=uuid.uuid4().hex+'@example.invalid'
        credentials={'correo':email,'clave':CLAVE}
        assert client.post('/cuentas',json={**credentials,'nombre_visible':'Persona de prueba'}).status_code==201
        login=client.post('/sesiones',json=credentials).json()
        h={'Authorization':'Bearer '+login['token']}
        assert client.post('/seguridad/totp/preparar',headers=h,json={'clave':CLAVE}).status_code==403
        r=client.post('/identidad/correo/solicitar',headers=h);assert r.status_code==202 and 'token_demo' not in r.json()
        assert client.post('/identidad/correo/confirmar',json={'token':captured[email]}).status_code==200
        s=client.post('/seguridad/totp/preparar',headers=h,json={'clave':CLAVE}).json()['secreto']
        r=client.post('/seguridad/totp/activar',headers=h,json={'codigo':codigo_totp(s,int(time.time())//30-1)})
        assert len(r.json()['codigos_recuperacion'])==8
        challenge=client.post('/sesiones',json=credentials).json()
        assert challenge['requiere_mfa'] and not challenge['token']
        login=client.post('/sesiones/mfa',json={'id_desafio':challenge['id_desafio'],'codigo':codigo_totp(s,int(time.time())//30)}).json()
        h={'Authorization':'Bearer '+login['token']}
        assert client.get('/identidad/mi-estado',headers=h).json()['puede_participar']
        assert client.get('/casos',headers=h).status_code==403
        return h

    driver=alta();witness=alta()
    moto=client.post('/vehiculos',headers=driver,json=vehiculo('motocicleta','bc.d-12'))
    assert moto.status_code==201
    saved=client.get('/vehiculos',headers=driver).json()[0]
    assert (saved['tipo_vehiculo'],saved['patente'])==('motocicleta','BCD12')
    cid=client.post('/casos',headers={**driver,'Idempotency-Key':str(uuid.uuid4())},json=_reporte(id_vehiculo=saved['id_vehiculo'])).json()['id_caso']
    sid=publicacion(client,cid,driver,supervisor_org1)
    assert client.get('/vehiculos',headers=witness).json()==[]
    observed=client.post(f'/colaboracion/{sid}/avistamientos',headers={**witness,'Idempotency-Key':str(uuid.uuid4())},json={'observado_en':datetime.now(timezone.utc).isoformat(),'zona':'Sector de ensayo','descripcion':'Observación de prueba en base desechable','latitud':-36.82,'longitud':-73.05})
    aid=observed.json()['id_avistamiento']
    assert client.post(f'/gestion/aportes/{aid}/revision',headers=supervisor_org1,json={'decision':'aceptado','motivo':'Revisión de prueba controlada','resumen':'Avistamiento de prueba revisado.'}).status_code==200
    assert client.get(f'/seguimiento/{cid}',headers=driver).json()['aportes'][0]['id_avistamiento']==aid

