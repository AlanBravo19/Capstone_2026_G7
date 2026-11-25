"""Sectores aproximados derivados de antecedentes revisados."""
import json

from .db import fila_dict

RADIO_M = 800
MINIMO = 2
PERIODO_DIAS = 365

_ZONAS = """
    WITH alcance AS (
        SELECT ST_SetSRID(ST_GeomFromGeoJSON(%s),4326)::geography AS geometria
    ), antecedentes AS (
        SELECT ST_SnapToGrid(a.centro::geometry,0.01) AS celda, a.zona
        FROM antecedente_publico a CROSS JOIN alcance p
        WHERE a.entorno=%s AND a.estado='validado' AND a.centro IS NOT NULL
          AND vence_en>CURRENT_TIMESTAMP
          AND a.precision_m<=%s
          AND coalesce(fecha_hecho,fecha_publicacion)>=CURRENT_DATE-%s
          AND ST_DWithin(a.centro,p.geometria,%s)
    ), sectores AS (
        SELECT celda,count(*) AS antecedentes,min(zona) AS sector
        FROM antecedentes GROUP BY celda HAVING count(*)>=%s
    )
    SELECT ST_Y(celda) AS latitud,ST_X(celda) AS longitud,%s AS radio_m,
           antecedentes,sector,ST_AsGeoJSON(ST_Buffer(celda::geography,%s)::geometry,6)::jsonb AS geometria
    FROM sectores ORDER BY antecedentes DESC,ST_Y(celda),ST_X(celda)
"""


def consultar_zonas(cur, alcance, ambiente, radio_m):
    cur.execute(_ZONAS, (json.dumps(alcance), ambiente, RADIO_M, PERIODO_DIAS, radio_m, MINIMO, RADIO_M, RADIO_M))
    return [fila_dict(cur, row) for row in cur.fetchall()]


def cruzar_rutas(cur, rutas, zonas):
    if not zonas:
        return [0] * len(rutas)
    datos_ruta = json.dumps([ruta['geometria'] for ruta in rutas])
    areas = json.dumps([zona['geometria'] for zona in zonas])
    cur.execute('''WITH zonas AS (SELECT ST_SetSRID(ST_GeomFromGeoJSON(z.value),4326) AS geom
        FROM jsonb_array_elements(%s::jsonb) z),
        rutas AS (SELECT r.ordinality,ST_SetSRID(ST_GeomFromGeoJSON(r.value),4326) AS geom
        FROM jsonb_array_elements(%s::jsonb) WITH ORDINALITY r)
        SELECT (SELECT count(*) FROM zonas z WHERE ST_Intersects(z.geom,r.geom))
        FROM rutas r ORDER BY r.ordinality''', (areas, datos_ruta))
    return [row[0] for row in cur.fetchall()]
