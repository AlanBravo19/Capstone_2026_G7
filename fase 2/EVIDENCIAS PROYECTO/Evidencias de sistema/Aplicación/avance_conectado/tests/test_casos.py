"""HU03 y HU13: CP42, CP43 y CP44."""
import uuid
from datetime import datetime, timedelta, timezone


def _reporte(org=1, **extra):
    datos = {"id_vehiculo": 1, "id_organizacion": org, "zona": "Sector sintético A",
             "fecha_hecho": (datetime.now(timezone.utc) - timedelta(minutes=30)).isoformat(),
             "descripcion": "Ejercicio de prueba sin incidente real", "latitud": -36.82, "longitud": -73.05,
             "precision_m": 15, "tipo_incidente": "encerrona"}
    datos.update(extra)
    return datos


def test_cp42_reporte_devuelve_folio_persistido(client, ciudadano, db):
    clave = str(uuid.uuid4())
    r = client.post("/casos", json=_reporte(), headers={**ciudadano["headers"], "Idempotency-Key": clave})
    assert r.status_code == 201, r.text
    cuerpo = r.json()
    assert cuerpo["folio"].startswith("RA-") and cuerpo["estado"] == "reportado"
    folio, lat, precision = db("""SELECT folio, round(ST_Y(ubicacion::geometry)::numeric, 2), precision_m
                                    FROM caso WHERE id_caso = %s""", (cuerpo["id_caso"],), filas=True)[0]
    assert folio == cuerpo["folio"] and float(lat) == -36.82 and float(precision) == 15
    eventos = db("SELECT count(*) FROM evento_salida WHERE clave_evento = %s",
                 (f"caso_reportado:{cuerpo['id_caso']}",), filas=True)[0][0]
    assert eventos == 1


def test_cp43_reintento_con_misma_clave_no_duplica(client, ciudadano, db):
    h = {**ciudadano["headers"], "Idempotency-Key": str(uuid.uuid4())}
    primero = client.post("/casos", json=_reporte(), headers=h)
    segundo = client.post("/casos", json=_reporte(), headers=h)
    assert primero.status_code == 201 and segundo.status_code == 200
    assert segundo.json()["folio"] == primero.json()["folio"] and segundo.json()["reintento"] is True
    assert db("SELECT count(*) FROM caso WHERE clave_envio = %s::uuid", (h["Idempotency-Key"],), filas=True)[0][0] == 1


def test_reporte_rechaza_vehiculo_no_vinculado_y_fecha_futura(client, ciudadano):
    h = {**ciudadano["headers"], "Idempotency-Key": str(uuid.uuid4())}
    assert client.post("/casos", json=_reporte(id_vehiculo=2), headers=h).status_code == 403
    futura = (datetime.now(timezone.utc) + timedelta(days=1)).isoformat()
    h2 = {**ciudadano["headers"], "Idempotency-Key": str(uuid.uuid4())}
    assert client.post("/casos", json=_reporte(fecha_hecho=futura), headers=h2).status_code == 422


def test_cp44_bandeja_y_detalle_restringidos_a_la_organizacion(client, ciudadano, supervisor_org1, operador_org2):
    r = client.post("/casos", json=_reporte(org=1), headers={**ciudadano["headers"], "Idempotency-Key": str(uuid.uuid4())})
    id_caso = r.json()["id_caso"]
    bandeja1 = client.get("/casos", headers=supervisor_org1)
    assert bandeja1.status_code == 200
    assert id_caso in [c["id_caso"] for c in bandeja1.json()]
    assert all(c["id_organizacion"] == 1 for c in bandeja1.json())
    assert client.get(f"/casos/{id_caso}", headers=supervisor_org1).status_code == 200
    # Operador de otra organización: no ve el caso en su bandeja y recibe 403 en el detalle.
    bandeja2 = client.get("/casos", headers=operador_org2)
    assert id_caso not in [c["id_caso"] for c in bandeja2.json()]
    assert client.get(f"/casos/{id_caso}", headers=operador_org2).status_code == 403
