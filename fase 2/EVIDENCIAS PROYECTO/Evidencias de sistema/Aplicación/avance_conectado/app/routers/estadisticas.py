"""Agregados históricos de plataforma; fuentes separadas, sin datos personales."""
from datetime import date, datetime, time, timedelta
from typing import Literal
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, HTTPException, Query

from ..db import fila_dict, obtener_conexion
from ..seguridad import usuario_actual
from .recursos_territorio import normalizar

router = APIRouter(tags=['estadísticas institucionales'])
TZ = ZoneInfo('America/Santiago')
LIMITES = [
    'Conteos de registros de plataforma, no incidencia poblacional ni tasa delictiva.',
    'Reportes internos e historial territorial son series separadas y no sumables: pueden referirse al mismo hecho.',
    'El historial territorial revisado es compartido y no tiene adscripción organizacional en el esquema.',
    'Las marcas, modelos y recuperaciones corresponden sólo a casos de RutaAlerta.',
    'Se excluyen casos vinculados a un principal o cerrados como duplicados de los desgloses internos.',
    'Los desenlaces son el estado actual de la cohorte por fecha del hecho, no su estado al terminar el período.',
    'Inventario actual de cámaras autorizadas; no reconstruye disponibilidad histórica ni se filtra por zona o fecha.',
    'Proximidad no acredita cobertura. Cobertura declarada exige coincidencia con un polígono registrado; no prueba visibilidad, grabación ni funcionamiento en la fecha del hecho.',
    'Coordenadas y precisiones registradas pueden ser incompletas o aproximadas; no se verifican límites de comunas o sectores.',
    'Estos indicadores apoyan revisión humana; no recomiendan automáticamente instalar cámaras.',
    'Operación y prueba se consultan por separado. Los reportes antiguos de la beta conservaron entorno prueba; selecciona Prueba para consultarlos.',
]


def _periodo(anio, desde, hasta):
    if (desde is None) != (hasta is None):
        raise HTTPException(422, 'Indica desde y hasta juntos')
    if desde is None:
        anio = anio or datetime.now(TZ).year
        desde, hasta = date(anio, 1, 1), date(anio, 12, 31)
    if desde.year < 1900 or hasta.year > 2100 or hasta < desde or (hasta-desde).days > 365:
        raise HTTPException(422, 'El período debe ser ordenado, entre 1900 y 2100 y de hasta 366 días')
    # Fin exclusivo calculado en fecha local: incluye días de 23/25 horas por DST.
    return desde, hasta, datetime.combine(desde, time.min, TZ), datetime.combine(hasta+timedelta(days=1), time.min, TZ)


def _grupos(cur, cte, params, dimensiones):
    """Todo el conjunto se agrega en SQL. Sin LIMIT ni truncamiento de totales."""
    valores = ','.join(f"('{nombre}',to_jsonb({expr}))" for nombre, expr in dimensiones.items())
    cur.execute(cte + f""" SELECT g.dimension,g.valor,count(*) AS total FROM base
        CROSS JOIN LATERAL (VALUES {valores}) AS g(dimension,valor)
        GROUP BY g.dimension,g.valor ORDER BY g.dimension,g.valor""", params)
    result = {nombre: [] for nombre in dimensiones}
    for dimension, valor, total in cur.fetchall():
        item = dict(valor) if isinstance(valor, dict) else {'valor': valor}
        result[dimension].append({**item, 'total': total})
    return result


def _series(datos, desde, hasta):
    for nombre, formato in [('mensual', '%Y-%m'), ('diaria', '%Y-%m-%d')]:
        valores = {r['valor']: r['total'] for r in datos[nombre]}
        claves = sorted({(desde+timedelta(days=n)).strftime(formato) for n in range((hasta-desde).days+1)})
        datos[nombre] = [{'periodo': k, 'total': valores.get(k, 0)} for k in claves]
    for nombre, campo, n in [('dias_semana', 'dia', 7), ('horas', 'hora', 24)]:
        valores = {int(r['valor']): r['total'] for r in datos[nombre]}
        datos[nombre] = [{campo: i, 'total': valores.get(i, 0)} for i in range(n)]
    for nombre in datos.keys() - {'mensual', 'diaria', 'dias_semana', 'horas'}:
        datos[nombre].sort(key=lambda r: (-r['total'], str(r)))
    return datos


TIEMPO = {
    'mensual': "to_char(fecha_local,'YYYY-MM')",
    'diaria': "to_char(fecha_local,'YYYY-MM-DD')",
    'dias_semana': '(extract(isodow FROM fecha_local)::int-1)',
    'horas': 'extract(hour FROM fecha_local)::int',
    'zonas': 'zona',
}
# Coincidencia exacta, sin interpolar entradas del usuario ni tratar % como comodín.
ZONA = "lower(translate(regexp_replace(btrim({alias}.zona), '\\s+', ' ', 'g'), 'ÁÉÍÓÚÜÑáéíóúüñ', 'AEIOUUNaeiouun'))"


@router.get('/gestion/estadisticas')
def estadisticas(
    anio: int | None = Query(None, ge=1900, le=2100),
    desde: date | None = None, hasta: date | None = None,
    id_organizacion: int | None = Query(None, gt=0),
    zona: str | None = Query(None, min_length=1, max_length=200),
    entorno: Literal['operacion', 'prueba'] = 'operacion',
    radio_m: int = Query(300, ge=50, le=2000),
    usuario=Depends(usuario_actual), conn=Depends(obtener_conexion),
):
    """Fechas locales inclusivas; sin fechas explícitas, año calendario chileno.

    Ausencia de organización selecciona todas las membresías vigentes del usuario.
    El rol administrador global no concede acceso institucional.
    """
    cur = conn.cursor()
    cur.execute("""SELECT m.id_organizacion FROM membresia m
        JOIN organizacion o USING(id_organizacion) JOIN usuario u USING(id_usuario)
        WHERE m.id_usuario=%s AND m.estado='activa' AND m.fin IS NULL
        AND m.inicio<=CURRENT_TIMESTAMP AND m.rol IN ('operador','supervisor')
        AND o.estado='activa' AND u.estado='activo' FOR SHARE OF m,o,u""", (usuario['id_usuario'],))
    autorizadas = sorted({r[0] for r in cur.fetchall()})
    if not autorizadas or (id_organizacion is not None and id_organizacion not in autorizadas):
        raise HTTPException(403, 'Se requiere membresía institucional vigente en el ámbito solicitado')
    orgs = [id_organizacion] if id_organizacion is not None else autorizadas
    desde, hasta, inicio, fin = _periodo(anio, desde, hasta)
    filtro_zona = normalizar(zona) if zona is not None else None
    if filtro_zona == '':
        raise HTTPException(422, 'La zona no puede estar vacía')
    params = (orgs, entorno, inicio, fin, filtro_zona, filtro_zona)
    condiciones = f"""c.id_organizacion=ANY(%s) AND c.entorno=%s
        AND c.fecha_hecho>=%s AND c.fecha_hecho<%s
        AND (%s::text IS NULL OR {ZONA.format(alias='c')}=%s)"""
    cte = f"""WITH reportes AS MATERIALIZED (SELECT c.* FROM caso c WHERE {condiciones}),
        base AS MATERIALIZED (SELECT c.*, c.fecha_hecho AT TIME ZONE 'America/Santiago' AS fecha_local,
        ma.nombre AS marca,mo.nombre AS modelo,v.tipo_vehiculo,
        (c.estado='cerrado' AND c.motivo_cierre='recuperado' AND c.recuperado_en IS NOT NULL
         AND EXISTS(SELECT 1 FROM evidencia e WHERE e.id_evidencia=c.id_evidencia_recuperacion
                    AND e.id_caso=c.id_caso AND e.estado_revision='aceptada')) AS documentado
        FROM reportes c JOIN vehiculo v USING(id_vehiculo) JOIN modelo mo USING(id_modelo)
        JOIN marca ma USING(id_marca) WHERE c.id_caso_principal IS NULL
        AND c.motivo_cierre IS DISTINCT FROM 'duplicado') """
    cur.execute(cte + """SELECT count(*) AS total,(SELECT count(*) FROM reportes) AS reportes_total,
        count(*) FILTER(WHERE documentado) AS documentados,
        count(*) FILTER(WHERE estado<>'cerrado') AS abiertos,
        count(*) FILTER(WHERE estado='cerrado' AND NOT documentado) AS cerrados_sin_recuperacion
        FROM base""", params)
    resumen = fila_dict(cur, cur.fetchone())
    total = resumen['total']
    internos = _series(_grupos(cur, cte, params, {
        **TIEMPO, 'estados': 'estado', 'desenlaces': "coalesce(motivo_cierre,'sin_cierre')",
        'marcas': 'marca', 'modelos': "jsonb_build_object('marca',marca,'modelo',modelo)",
        'tipos_vehiculo': 'tipo_vehiculo', 'tipos_incidente': 'tipo_incidente',
    }), desde, hasta)
    internos.update(total=total, reportes_total=resumen['reportes_total'],
        duplicados_excluidos=resumen['reportes_total']-total,
        recuperacion={k: resumen[k] for k in ['documentados', 'abiertos', 'cerrados_sin_recuperacion']})
    internos['recuperacion'].update(denominador=total,
        porcentaje_cohorte=round(100*resumen['documentados']/total, 2) if total else None)
    cur.execute(cte + """SELECT a.estado_revision AS valor,count(*) AS total
        FROM avistamiento a JOIN base b USING(id_caso)
        GROUP BY a.estado_revision ORDER BY a.estado_revision""",params)
    internos['aportes']=[fila_dict(cur,r) for r in cur.fetchall()]

    # EXISTS impide multiplicar hechos por noticias, lotes o registros de origen.
    hcte = f"""WITH base AS MATERIALIZED (SELECT h.tipo,h.zona,
        h.ocurrido_en AT TIME ZONE 'America/Santiago' AS fecha_local
        FROM hecho_territorial h WHERE h.estado='validado' AND h.entorno=%s
        AND h.ocurrido_en>=%s AND h.ocurrido_en<%s
        AND (%s::text IS NULL OR {ZONA.format(alias='h')}=%s)
        AND EXISTS(SELECT 1 FROM registro_fuente r JOIN fuente_datos f USING(id_fuente_datos)
            JOIN lote_importacion l ON l.id_lote_importacion=r.id_lote_importacion
                AND l.id_fuente_datos=r.id_fuente_datos
            WHERE r.id_hecho_territorial=h.id_hecho_territorial AND r.estado_revision='aceptado'
            AND f.estado='autorizada' AND l.estado='completado')) """
    hp = (entorno, inicio, fin, filtro_zona, filtro_zona)
    territorial = _series(_grupos(cur, hcte, hp, {**TIEMPO, 'tipos': 'tipo'}), desde, hasta)
    territorial.update(total=sum(r['total'] for r in territorial['tipos']),
        ambito='historial_revisado_compartido_sin_adscripcion_organizacional')

    cur.execute("""SELECT count(*) AS total,
        count(*) FILTER(WHERE estado='disponible') AS disponibles,
        count(*) FILTER(WHERE estado='fuera_servicio') AS fuera_servicio,
        count(*) FILTER(WHERE estado='desconocido') AS desconocidas,
        count(*) FILTER(WHERE cobertura IS NOT NULL) AS con_cobertura,
        count(*) FILTER(WHERE verificada_en IS NOT NULL) AS verificadas
        FROM camara WHERE id_organizacion=ANY(%s) AND entorno=%s
        AND btrim(referencia_autorizacion)<>''""", (orgs, entorno))
    inventario = fila_dict(cur, cur.fetchone())
    cur.execute(cte + """, puntos AS (
        SELECT b.zona,b.ubicacion,
        EXISTS(SELECT 1 FROM camara k WHERE k.id_organizacion=ANY(%s) AND k.entorno=%s
            AND btrim(k.referencia_autorizacion)<>'' AND k.estado='disponible'
            AND ST_DWithin(k.ubicacion,b.ubicacion,%s)) AS cerca,
        EXISTS(SELECT 1 FROM camara k WHERE k.id_organizacion=ANY(%s) AND k.entorno=%s
            AND btrim(k.referencia_autorizacion)<>'' AND k.estado='disponible'
            AND k.cobertura IS NOT NULL AND ST_Covers(k.cobertura,b.ubicacion::geometry)) AS cubierta
        FROM base b)
        SELECT zona,count(*) AS reportes,count(ubicacion) AS con_ubicacion,
            count(*) FILTER(WHERE cerca) AS cerca_de_camara,
            count(*) FILTER(WHERE cubierta) AS en_cobertura_declarada,
            count(*) FILTER(WHERE ubicacion IS NOT NULL AND NOT cerca) AS sin_camara_cercana
        FROM puntos GROUP BY zona ORDER BY count(*) DESC,zona""", (*params, orgs, entorno, radio_m, orgs, entorno))
    zonas = [fila_dict(cur, r) for r in cur.fetchall()]
    return {
        'filtros': {'desde': desde, 'hasta': hasta, 'anio': desde.year if desde.year==hasta.year else None,
            'id_organizacion': id_organizacion, 'organizaciones': orgs, 'zona': zona,
            'entorno': entorno, 'zona_horaria': 'America/Santiago', 'radio_m': radio_m},
        'internos': internos, 'territorial': territorial,
        'camaras': {'inventario': inventario, 'zonas': zonas, 'radio_m': radio_m},
        'limites': LIMITES,
    }
