"""Simulación integrada sobre la base temporal, sin avisos públicos ni fotos reales."""
import uuid
from datetime import datetime, timezone

from test_beta_colaborativa import foto_payload
from test_casos import _reporte
from test_identidad_mvp import activar


def test_recorrido_chillan(client, ciudadano, supervisor_org1, operador_org2):
    op, titular = supervisor_org1, ciudadano["headers"]
    _, _, colaborador, _ = activar(client)
    punto = {"latitud": -36.606, "longitud": -72.104}
    reporte = _reporte(zona="Chillán · ensayo local", **punto)
    cabecera={**titular,"Idempotency-Key":str(uuid.uuid4())}
    reporte["solicitar_colaboracion"]=True
    assert client.post("/casos", headers=cabecera,json={**reporte,"foto_base64":"A"*40}).status_code==422
    reporte["foto_base64"]=foto_payload()["contenido_base64"]
    r = client.post("/casos", headers=cabecera, json=reporte)
    assert r.status_code == 201
    cid = r.json()["id_caso"]
    assert client.post("/casos",headers=cabecera,json=reporte).json()["id_caso"]==cid
    ficha=client.get(f"/seguimiento/{cid}",headers=titular).json()
    assert ficha["estado_colaboracion"]=="Pendiente de publicación por el operador"
    assert len(ficha["evidencias"])==1
    evidencia=f"/evidencias/{ficha['evidencias'][0]['id_evidencia']}/foto"
    assert client.get(evidencia,headers=op).status_code==200
    assert client.get(evidencia,headers=colaborador).status_code==403
    mapa = "/gestion/mapa?id_organizacion=1"
    assert client.get(mapa, headers=colaborador).status_code == 403
    assert client.get(mapa, headers=operador_org2).status_code == 403
    def eventos():
        datos = client.get(mapa, headers=op)
        assert datos.status_code == 200
        return [e for e in datos.json()["eventos"] if e["id_caso"] == cid]
    ubicados = eventos()
    assert len(ubicados) == 1 and ubicados[0]["tipo"] == "reporte"
    assert abs(ubicados[0]["latitud"] - punto["latitud"]) < 1e-6
    assert abs(ubicados[0]["longitud"] - punto["longitud"]) < 1e-6
    base = f"/gestion/casos/{cid}"
    assert client.post(base+"/revision",headers=op,json={"estado":"en_revision","motivo":"Revisión supervisada del ejercicio"}).status_code == 200
    r=client.post(base+"/publicacion",headers=op,json={"zona":"Chillán · simulación","texto":"Vehículo ficticio para la prueba local de colaboración.","motivo":"Ejercicio con consentimiento del titular ficticio"})
    assert r.status_code == 201
    sid = r.json()["id_solicitud_colaboracion"]
    assert client.get(f"/seguimiento/{cid}",headers=titular).json()["estado_colaboracion"]=="Publicada en Colaborar"
    panorama=client.get("/territorio/panorama?lat=-36.606&lon=-72.104",headers=colaborador).json()
    ficha_publica=next(s for s in panorama["solicitudes"] if s["id_solicitud_colaboracion"]==sid)
    assert abs(ficha_publica["latitud_sector"]-(-36.60))<0.00001
    assert abs(ficha_publica["longitud_sector"]-(-72.10))<0.00001
    assert "evidencias" not in ficha_publica and "descripcion_privada" not in ficha_publica
    for lat,lon,grupo in [(-36.606,-72.104,"cercanos"),(-33.45,-70.66,"otras_zonas")]:
        resultado=client.get("/colaboracion",params={"lat":lat,"lon":lon,"radio_km":30,"zona":"Chillán"},headers=colaborador).json()
        assert any(s["id_solicitud_colaboracion"]==sid for s in resultado[grupo])
    url=f"/colaboracion/{sid}/avistamientos"
    h={**colaborador,"Idempotency-Key":str(uuid.uuid4())}
    datos={**punto,"observado_en":datetime.now(timezone.utc).isoformat(),"zona":"Chillán de ensayo",
           "descripcion":"Observación ficticia enviada para revisar la foto de prueba."}
    assert client.post(url,headers=h,json={**datos,"foto_base64":"A"*40}).status_code == 422
    datos["foto_base64"]=foto_payload()["contenido_base64"]
    r=client.post(url,headers=h,json=datos)
    assert r.status_code == 201
    aid=r.json()["id_avistamiento"]
    assert [e["tipo"] for e in eventos()] == ["reporte"]
    assert client.post(url,headers=h,json=datos).json()["id_avistamiento"]==aid
    def pendientes(actor):
        return [p for p in client.get("/gestion/aportes/pendientes",headers=actor).json() if p["id_caso"]==cid]
    assert len(pendientes(op))==1 and pendientes(op)[0]["con_foto"]
    assert pendientes(operador_org2)==[]
    aportes=client.get(base+"/aportes",headers=op).json()
    assert len(aportes)==1 and len(aportes[0]["fotos"])==1
    foto=f"/evidencias/{aportes[0]['fotos'][0]}/foto"
    assert client.get(foto,headers=op).content[:2] == bytes.fromhex("ffd8")
    assert client.get(foto,headers=titular).status_code==403
    assert client.get(foto,headers=operador_org2).status_code==403
    resumen="Se recibió un antecedente ficticio y el operador revisó la fotografía."
    assert client.post(f"/gestion/aportes/{aid}/revision",headers=op,json={"decision":"aceptado","motivo":"Aporte revisado en el ensayo","resumen":resumen}).status_code==200
    assert not pendientes(op)
    assert {e["tipo"] for e in eventos()} == {"reporte", "avistamiento"}
    seguimiento=client.get(f"/seguimiento/{cid}",headers=titular).json()
    assert seguimiento["aportes"][0]["resumen_para_afectado"]==resumen
    mensaje={"mensaje":"Actualización privada del ejercicio en Chillán.","clave_envio":str(uuid.uuid4())}
    assert client.post(base+"/mensaje",headers=operador_org2,json=mensaje).status_code==403
    for _ in range(2):
        assert client.post(base+"/mensaje",headers=op,json=mensaje).status_code==204
    notificaciones=client.get("/notificaciones",headers=titular).json()
    recibidas=[n for n in notificaciones if n["mensaje"]==mensaje["mensaje"]]
    assert len(recibidas)==1
    assert client.post(f"/notificaciones/{recibidas[0]['id_notificacion']}/leer",headers=titular).status_code==204
    decisiones=[n for n in client.get("/notificaciones",headers=colaborador).json() if n["titulo"]=="Avistamiento revisado"]
    assert len(decisiones)==1 and decisiones[0]["destino"]=="avistamientos" and decisiones[0]["id_caso"] is None

