"""Recursos informativos y catálogo territorial, sin cambios de esquema.

Fuente de las 346 comunas: Unidad de Interoperabilidad, MINSAL, EIS 0.2.0.
https://build.fhir.org/ig/Minsal-CL/eis/CodeSystem-eis-comunas-cs.json
Descargado: 2026-11-17 14:20 UTC. Snapshot de nombres/códigos, no de límites.
La fuente publica algunos códigos con cuatro dígitos: se normalizan a cinco.
Para actualizar, contrastar 346 conceptos/códigos únicos con la fuente oficial.

El esquema no vincula recurso_apoyo a una organización. El ámbito de edición
es la membresía vigente compartida con mantenido_por (responsable persistido).
Se conserva ese responsable al editar salvo reasignación explícita dentro del
mismo ámbito; no se deduce jurisdicción de una dirección, sector o coordenada.
"""
import unicodedata
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Path, Query
from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, HttpUrl, field_validator, model_validator

from ..db import fila_dict, obtener_conexion
from ..seguridad import usuario_actual

router = APIRouter(tags=['recursos y catálogo territorial'])

COMUNAS = {
    '01101': 'Iquique',
    '01107': 'Alto Hospicio',
    '01401': 'Pozo Almonte',
    '01402': 'Camiña',
    '01403': 'Colchane',
    '01404': 'Huara',
    '01405': 'Pica',
    '02101': 'Antofagasta',
    '02102': 'Mejillones',
    '02103': 'Sierra Gorda',
    '02104': 'Taltal',
    '02201': 'Calama',
    '02202': 'Ollagüe',
    '02203': 'San Pedro de Atacama',
    '02301': 'Tocopilla',
    '02302': 'María Elena',
    '03101': 'Copiapó',
    '03102': 'Caldera',
    '03103': 'Tierra Amarilla',
    '03201': 'Chañaral',
    '03202': 'Diego de Almagro',
    '03301': 'Vallenar',
    '03302': 'Alto del Carmen',
    '03303': 'Freirina',
    '03304': 'Huasco',
    '04101': 'La Serena',
    '04102': 'Coquimbo',
    '04103': 'Andacollo',
    '04104': 'La Higuera',
    '04105': 'Paiguano',
    '04106': 'Vicuña',
    '04201': 'Illapel',
    '04202': 'Canela',
    '04203': 'Los Vilos',
    '04204': 'Salamanca',
    '04301': 'Ovalle',
    '04302': 'Combarbalá',
    '04303': 'Monte Patria',
    '04304': 'Punitaqui',
    '04305': 'Río Hurtado',
    '05101': 'Valparaíso',
    '05102': 'Casablanca',
    '05103': 'Concón',
    '05104': 'Juan Fernández',
    '05105': 'Puchuncaví',
    '05107': 'Quintero',
    '05109': 'Viña del Mar',
    '05201': 'Isla de Pascua',
    '05301': 'Los Andes',
    '05302': 'Calle Larga',
    '05303': 'Rinconada',
    '05304': 'San Esteban',
    '05401': 'La Ligua',
    '05402': 'Cabildo',
    '05403': 'Papudo',
    '05404': 'Petorca',
    '05405': 'Zapallar',
    '05501': 'Quillota',
    '05502': 'Calera',
    '05503': 'Hijuelas',
    '05504': 'La Cruz',
    '05506': 'Nogales',
    '05601': 'San Antonio',
    '05602': 'Algarrobo',
    '05603': 'Cartagena',
    '05604': 'El Quisco',
    '05605': 'El Tabo',
    '05606': 'Santo Domingo',
    '05701': 'San Felipe',
    '05702': 'Catemu',
    '05703': 'Llaillay',
    '05704': 'Panquehue',
    '05705': 'Putaendo',
    '05706': 'Santa María',
    '05801': 'Quilpué',
    '05802': 'Limache',
    '05803': 'Olmué',
    '05804': 'Villa Alemana',
    '06101': 'Rancagua',
    '06102': 'Codegua',
    '06103': 'Coinco',
    '06104': 'Coltauco',
    '06105': 'Doñihue',
    '06106': 'Graneros',
    '06107': 'Las Cabras',
    '06108': 'Machalí',
    '06109': 'Malloa',
    '06110': 'Mostazal',
    '06111': 'Olivar',
    '06112': 'Peumo',
    '06113': 'Pichidegua',
    '06114': 'Quinta de Tilcoco',
    '06115': 'Rengo',
    '06116': 'Requínoa',
    '06117': 'San Vicente',
    '06201': 'Pichilemu',
    '06202': 'La Estrella',
    '06203': 'Litueche',
    '06204': 'Marchihue',
    '06205': 'Navidad',
    '06206': 'Paredones',
    '06301': 'San Fernando',
    '06302': 'Chépica',
    '06303': 'Chimbarongo',
    '06304': 'Lolol',
    '06305': 'Nancagua',
    '06306': 'Palmilla',
    '06307': 'Peralillo',
    '06308': 'Placilla',
    '06309': 'Pumanque',
    '06310': 'Santa Cruz',
    '07101': 'Talca',
    '07102': 'Constitución',
    '07103': 'Curepto',
    '07104': 'Empedrado',
    '07105': 'Maule',
    '07106': 'Pelarco',
    '07107': 'Pencahue',
    '07108': 'Río Claro',
    '07109': 'San Clemente',
    '07110': 'San Rafael',
    '07201': 'Cauquenes',
    '07202': 'Chanco',
    '07203': 'Pelluhue',
    '07301': 'Curicó',
    '07302': 'Hualañé',
    '07303': 'Licantén',
    '07304': 'Molina',
    '07305': 'Rauco',
    '07306': 'Romeral',
    '07307': 'Sagrada Familia',
    '07308': 'Teno',
    '07309': 'Vichuquén',
    '07401': 'Linares',
    '07402': 'Colbún',
    '07403': 'Longaví',
    '07404': 'Parral',
    '07405': 'Retiro',
    '07406': 'San Javier',
    '07407': 'Villa Alegre',
    '07408': 'Yerbas Buenas',
    '08101': 'Concepción',
    '08102': 'Coronel',
    '08103': 'Chiguayante',
    '08104': 'Florida',
    '08105': 'Hualqui',
    '08106': 'Lota',
    '08107': 'Penco',
    '08108': 'San Pedro de la Paz',
    '08109': 'Santa Juana',
    '08110': 'Talcahuano',
    '08111': 'Tomé',
    '08112': 'Hualpén',
    '08201': 'Lebu',
    '08202': 'Arauco',
    '08203': 'Cañete',
    '08204': 'Contulmo',
    '08205': 'Curanilahue',
    '08206': 'Los Alamos',
    '08207': 'Tirúa',
    '08301': 'Los Angeles',
    '08302': 'Antuco',
    '08303': 'Cabrero',
    '08304': 'Laja',
    '08305': 'Mulchén',
    '08306': 'Nacimiento',
    '08307': 'Negrete',
    '08308': 'Quilaco',
    '08309': 'Quilleco',
    '08310': 'San Rosendo',
    '08311': 'Santa Bárbara',
    '08312': 'Tucapel',
    '08313': 'Yumbel',
    '08314': 'Alto Biobío',
    '09101': 'Temuco',
    '09102': 'Carahue',
    '09103': 'Cunco',
    '09104': 'Curarrehue',
    '09105': 'Freire',
    '09106': 'Galvarino',
    '09107': 'Gorbea',
    '09108': 'Lautaro',
    '09109': 'Loncoche',
    '09110': 'Melipeuco',
    '09111': 'Nueva Imperial',
    '09112': 'Padre Las Casas',
    '09113': 'Perquenco',
    '09114': 'Pitrufquén',
    '09115': 'Pucón',
    '09116': 'Saavedra',
    '09117': 'Teodoro Schmidt',
    '09118': 'Toltén',
    '09119': 'Vilcún',
    '09120': 'Villarrica',
    '09121': 'Cholchol',
    '09201': 'Angol',
    '09202': 'Collipulli',
    '09203': 'Curacautín',
    '09204': 'Ercilla',
    '09205': 'Lonquimay',
    '09206': 'Los Sauces',
    '09207': 'Lumaco',
    '09208': 'Purén',
    '09209': 'Renaico',
    '09210': 'Traiguén',
    '09211': 'Victoria',
    '10101': 'Puerto Montt',
    '10102': 'Calbuco',
    '10103': 'Cochamó',
    '10104': 'Fresia',
    '10105': 'Frutillar',
    '10106': 'Los Muermos',
    '10107': 'Llanquihue',
    '10108': 'Maullín',
    '10109': 'Puerto Varas',
    '10201': 'Castro',
    '10202': 'Ancud',
    '10203': 'Chonchi',
    '10204': 'Curaco de Vélez',
    '10205': 'Dalcahue',
    '10206': 'Puqueldón',
    '10207': 'Queilén',
    '10208': 'Quellón',
    '10209': 'Quemchi',
    '10210': 'Quinchao',
    '10301': 'Osorno',
    '10302': 'Puerto Octay',
    '10303': 'Purranque',
    '10304': 'Puyehue',
    '10305': 'Río Negro',
    '10306': 'San Juan de la Costa',
    '10307': 'San Pablo',
    '10401': 'Chaitén',
    '10402': 'Futaleufú',
    '10403': 'Hualaihué',
    '10404': 'Palena',
    '11101': 'Coyhaique',
    '11102': 'Lago Verde',
    '11201': 'Aysén',
    '11202': 'Cisnes',
    '11203': 'Guaitecas',
    '11301': 'Cochrane',
    '11302': 'O\'Higgins',
    '11303': 'Tortel',
    '11401': 'Chile Chico',
    '11402': 'Río Ibáñez',
    '12101': 'Punta Arenas',
    '12102': 'Laguna Blanca',
    '12103': 'Río Verde',
    '12104': 'San Gregorio',
    '12201': 'Cabo de Hornos',
    '12202': 'Antártica',
    '12301': 'Porvenir',
    '12302': 'Primavera',
    '12303': 'Timaukel',
    '12401': 'Natales',
    '12402': 'Torres del Paine',
    '13101': 'Santiago',
    '13102': 'Cerrillos',
    '13103': 'Cerro Navia',
    '13104': 'Conchalí',
    '13105': 'El Bosque',
    '13106': 'Estación Central',
    '13107': 'Huechuraba',
    '13108': 'Independencia',
    '13109': 'La Cisterna',
    '13110': 'La Florida',
    '13111': 'La Granja',
    '13112': 'La Pintana',
    '13113': 'La Reina',
    '13114': 'Las Condes',
    '13115': 'Lo Barnechea',
    '13116': 'Lo Espejo',
    '13117': 'Lo Prado',
    '13118': 'Macul',
    '13119': 'Maipú',
    '13120': 'Ñuñoa',
    '13121': 'Pedro Aguirre Cerda',
    '13122': 'Peñalolén',
    '13123': 'Providencia',
    '13124': 'Pudahuel',
    '13125': 'Quilicura',
    '13126': 'Quinta Normal',
    '13127': 'Recoleta',
    '13128': 'Renca',
    '13129': 'San Joaquín',
    '13130': 'San Miguel',
    '13131': 'San Ramón',
    '13132': 'Vitacura',
    '13201': 'Puente Alto',
    '13202': 'Pirque',
    '13203': 'San José de Maipo',
    '13301': 'Colina',
    '13302': 'Lampa',
    '13303': 'Tiltil',
    '13401': 'San Bernardo',
    '13402': 'Buin',
    '13403': 'Calera de Tango',
    '13404': 'Paine',
    '13501': 'Melipilla',
    '13502': 'Alhué',
    '13503': 'Curacaví',
    '13504': 'María Pinto',
    '13505': 'San Pedro',
    '13601': 'Talagante',
    '13602': 'El Monte',
    '13603': 'Isla de Maipo',
    '13604': 'Padre Hurtado',
    '13605': 'Peñaflor',
    '14101': 'Valdivia',
    '14102': 'Corral',
    '14103': 'Lanco',
    '14104': 'Los Lagos',
    '14105': 'Máfil',
    '14106': 'Mariquina',
    '14107': 'Paillaco',
    '14108': 'Panguipulli',
    '14201': 'La Unión',
    '14202': 'Futrono',
    '14203': 'Lago Ranco',
    '14204': 'Río Bueno',
    '15101': 'Arica',
    '15102': 'Camarones',
    '15201': 'Putre',
    '15202': 'General Lagos',
    '16101': 'Chillán',
    '16102': 'Bulnes',
    '16103': 'Chillán Viejo',
    '16104': 'El Carmen',
    '16105': 'Pemuco',
    '16106': 'Pinto',
    '16107': 'Quillón',
    '16108': 'San Ignacio',
    '16109': 'Yungay',
    '16201': 'Quirihue',
    '16202': 'Cobquecura',
    '16203': 'Coelemu',
    '16204': 'Ninhue',
    '16205': 'Portezuelo',
    '16206': 'Ranquil',
    '16207': 'Treguaco',
    '16301': 'San Carlos',
    '16302': 'Coihueco',
    '16303': 'Ñiquén',
    '16304': 'San Fabián',
    '16305': 'San Nicolás',
}

FUENTE_COMUNAS = 'https://build.fhir.org/ig/Minsal-CL/eis/CodeSystem-eis-comunas-cs.json'
Categoria = Literal['denuncia', 'orientacion', 'apoyo_victima', 'otro']


def normalizar(texto: str) -> str:
    return ' '.join(''.join(c for c in unicodedata.normalize('NFD', texto)
                           if unicodedata.category(c) != 'Mn').casefold().split())


class TerritorioEntrada(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra='forbid')
    codigo_comuna: str | None = None
    comuna: str | None = Field(default=None, min_length=1, max_length=200)
    sector: str | None = Field(default=None, min_length=1, max_length=200)
    latitud: float | None = Field(default=None, ge=-90, le=90, allow_inf_nan=False)
    longitud: float | None = Field(default=None, ge=-180, le=180, allow_inf_nan=False)

    @field_validator('codigo_comuna')
    @classmethod
    def codigo_oficial(cls, valor):
        if valor is None:
            return None
        if not valor.isascii() or not valor.isdigit() or len(valor) not in (4, 5):
            raise ValueError('Selecciona un código de comuna del catálogo oficial')
        valor = valor.zfill(5)
        if valor not in COMUNAS:
            raise ValueError('Código de comuna no catalogado')
        return valor

    @model_validator(mode='after')
    def validar_territorio(self):
        if (self.latitud is None) != (self.longitud is None):
            raise ValueError('Latitud y longitud deben informarse juntas')
        if self.comuna is not None:
            codigo = next((c for c, n in COMUNAS.items() if normalizar(n) == normalizar(self.comuna)), None)
            if codigo is None or (self.codigo_comuna and self.codigo_comuna != codigo):
                raise ValueError('Comuna no catalogada o incompatible con el código seleccionado')
            self.codigo_comuna = codigo
        if self.codigo_comuna:
            self.comuna = COMUNAS[self.codigo_comuna]
        return self


@router.get('/catalogo/comunas')
def catalogo_comunas(q: str = Query(default='', max_length=200), usuario=Depends(usuario_actual)):
    consulta = normalizar(q)
    return [{'codigo_comuna': c, 'nombre': n} for c, n in sorted(COMUNAS.items())
            if consulta in normalizar(n) or consulta in c]


@router.post('/territorio/validacion')
def validar_territorio(datos: TerritorioEntrada, usuario=Depends(usuario_actual)):
    """Valida identidad de comuna y formato de coordenadas; nunca pertenencia espacial."""
    return {**datos.model_dump(),
            'zona': ' · '.join(p for p in (datos.comuna, datos.sector) if p),
            'comuna_validada': datos.codigo_comuna is not None,
            'sector_validado': False, 'limites_geograficos_verificados': False,
            'relacion_comuna_sector_disponible': False}


@router.get('/catalogo/territorios')
def catalogo_territorios(q: str = Query(default='', max_length=200),
                        tipo: Literal['comuna', 'sector', 'cobertura'] | None = None,
                        limite: int = Query(default=50, ge=1, le=500),
                        usuario=Depends(usuario_actual), conn=Depends(obtener_conexion)):
    consulta = normalizar(q)
    items = []
    if tipo in (None, 'comuna'):
        items.extend({'tipo': 'comuna', 'nombre': n, 'codigo_comuna': c, 'fuente': 'MINSAL EIS 0.2.0'}
                     for c, n in COMUNAS.items() if consulta in normalizar(n) or consulta in c)
    if tipo != 'comuna':
        cur = conn.cursor()
        # Sólo nombres agregados ya validados; nunca zonas de casos privados o avisos pendientes.
        cur.execute("""SELECT 'cobertura' AS tipo, territorio_cobertura AS nombre, 'organizacion' AS fuente
                       FROM organizacion WHERE estado='activa'
                       UNION SELECT 'sector', zona, 'hecho_territorial'
                       FROM hecho_territorial WHERE estado='validado' AND nivel_agregacion='sector'""")
        for fila in cur.fetchall():
            if (tipo is None or fila[0] == tipo) and consulta in normalizar(fila[1]):
                items.append({'tipo': fila[0], 'nombre': fila[1], 'codigo_comuna': None, 'fuente': fila[2]})
    items.sort(key=lambda i: (i['tipo'], normalizar(i['nombre']), i['nombre']))
    return {'items': items[:limite], 'hay_mas': len(items) > limite,
            'fuente_comunas': FUENTE_COMUNAS, 'catalogo_comunas_total': len(COMUNAS),
            'limites_geograficos_verificados': False, 'relacion_comuna_sector_disponible': False}


class RecursoEntrada(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra='forbid')
    categoria: Categoria
    territorio: str | None = Field(default=None, min_length=1, max_length=200)
    codigo_comuna: str | None = None
    titulo: str = Field(min_length=1, max_length=150)
    descripcion: str = Field(min_length=1, max_length=10000)
    canal: str = Field(min_length=1, max_length=300)
    url_oficial: HttpUrl | None = Field(default=None, max_length=1000)
    mantenido_por: int | None = Field(default=None, gt=0)
    verificado_en: AwareDatetime
    vence_en: AwareDatetime
    activo: bool = True

    @model_validator(mode='after')
    def validar_recurso(self):
        if self.codigo_comuna is not None:
            territorio = TerritorioEntrada(codigo_comuna=self.codigo_comuna)
            self.codigo_comuna = territorio.codigo_comuna
            self.territorio = territorio.comuna
        if self.territorio is None:
            raise ValueError('Indica un territorio o selecciona una comuna del catálogo')
        if self.vence_en <= self.verificado_en:
            raise ValueError('El vencimiento debe ser posterior a la verificación')
        return self


def _filas(cur):
    return [fila_dict(cur, fila) for fila in cur.fetchall()]


def _membresias(cur, uid):
    # Bloqueos compartidos mantienen la autorización vigente durante la escritura.
    cur.execute("""SELECT m.id_organizacion FROM membresia m
                   JOIN organizacion o USING(id_organizacion) JOIN usuario u USING(id_usuario)
                   WHERE m.id_usuario=%s AND m.estado='activa' AND m.fin IS NULL
                   AND m.inicio<=CURRENT_TIMESTAMP AND o.estado='activa' AND u.estado='activo'
                   AND m.rol IN ('operador','supervisor') FOR SHARE OF m,o,u""", (uid,))
    return {fila[0] for fila in cur.fetchall()}


def _ambito(cur, uid):
    orgs = _membresias(cur, uid)
    if not orgs:
        raise HTTPException(403, 'Se requiere membresía institucional vigente')
    return orgs


_CAMPOS = """r.*, u.nombre_visible AS responsable,
             (r.activo AND r.verificado_en<=CURRENT_TIMESTAMP AND r.vence_en>CURRENT_TIMESTAMP) AS vigente"""
_AMBITO_RESPONSABLE = """EXISTS (SELECT 1 FROM membresia m JOIN organizacion o USING(id_organizacion)
    WHERE m.id_usuario=r.mantenido_por AND m.id_organizacion=ANY(%s)
    AND m.estado='activa' AND m.fin IS NULL AND m.inicio<=CURRENT_TIMESTAMP
    AND o.estado='activa' AND u.estado='activo')"""


def _leer(cur, rid):
    cur.execute(f'SELECT {_CAMPOS} FROM recurso_apoyo r JOIN usuario u ON u.id_usuario=r.mantenido_por WHERE r.id_recurso_apoyo=%s', (rid,))
    return fila_dict(cur, cur.fetchone())


def _autorizado(cur, rid, uid):
    orgs = _ambito(cur, uid)
    cur.execute('SELECT mantenido_por FROM recurso_apoyo WHERE id_recurso_apoyo=%s FOR UPDATE', (rid,))
    fila = cur.fetchone()
    if fila is None:
        raise HTTPException(403, 'Recurso fuera del ámbito autorizado')
    compartidas = orgs & _membresias(cur, fila[0])
    if not compartidas:
        raise HTTPException(403, 'Recurso fuera del ámbito autorizado')
    return fila[0], compartidas


def _listar(cur, territorio, categoria, limite, offset, orgs=None):
    condiciones = []
    params = []
    if orgs is None:
        condiciones.append('r.activo AND r.verificado_en<=CURRENT_TIMESTAMP AND r.vence_en>CURRENT_TIMESTAMP')
    else:
        condiciones.append(_AMBITO_RESPONSABLE)
        params.append(sorted(orgs))
    if territorio:
        # Coincidencia exacta normalizada; un filtro nunca se interpola en SQL.
        condiciones.append("lower(translate(regexp_replace(btrim(r.territorio), '\\s+', ' ', 'g'), 'ÁÉÍÓÚÜÑáéíóúüñ', 'AEIOUUNaeiouun'))=%s")
        params.append(normalizar(territorio))
    if categoria:
        condiciones.append('r.categoria=%s')
        params.append(categoria)
    cur.execute(f"SELECT {_CAMPOS} FROM recurso_apoyo r JOIN usuario u ON u.id_usuario=r.mantenido_por WHERE "
                + ' AND '.join(condiciones) + ' ORDER BY r.territorio,r.titulo,r.id_recurso_apoyo LIMIT %s OFFSET %s',
                (*params, limite, offset))
    items = _filas(cur)
    if orgs is not None:
        for item in items:
            item['puede_editar'] = True
    return items


@router.get('/recursos-apoyo')
def recursos(territorio: str | None = Query(default=None, max_length=200), categoria: Categoria | None = None,
             limite: int = Query(default=50, ge=1, le=200), offset: int = Query(default=0, ge=0, le=10000),
             usuario=Depends(usuario_actual), conn=Depends(obtener_conexion)):
    return _listar(conn.cursor(), territorio, categoria, limite, offset)


@router.get('/recursos-apoyo/{rid}')
def recurso(rid: int = Path(gt=0), usuario=Depends(usuario_actual), conn=Depends(obtener_conexion)):
    item = _leer(conn.cursor(), rid)
    if not item or not item['vigente']:
        raise HTTPException(404, 'Recurso vigente no disponible')
    return item


@router.get('/gestion/recursos-apoyo/responsables')
def responsables(usuario=Depends(usuario_actual), conn=Depends(obtener_conexion)):
    cur = conn.cursor()
    orgs = _ambito(cur, usuario['id_usuario'])
    cur.execute("""SELECT DISTINCT u.id_usuario,u.nombre_visible FROM membresia m JOIN usuario u USING(id_usuario)
                   WHERE m.id_organizacion=ANY(%s) AND m.estado='activa' AND m.fin IS NULL
                   AND m.inicio<=CURRENT_TIMESTAMP AND u.estado='activo' ORDER BY u.nombre_visible,u.id_usuario""", (sorted(orgs),))
    return _filas(cur)


@router.get('/gestion/recursos-apoyo')
def gestion_recursos(territorio: str | None = Query(default=None, max_length=200), categoria: Categoria | None = None,
                     limite: int = Query(default=50, ge=1, le=200), offset: int = Query(default=0, ge=0, le=10000),
                     usuario=Depends(usuario_actual), conn=Depends(obtener_conexion)):
    cur = conn.cursor()
    return _listar(cur, territorio, categoria, limite, offset, _ambito(cur, usuario['id_usuario']))


@router.post('/gestion/recursos-apoyo', status_code=201)
def crear_recurso(datos: RecursoEntrada, usuario=Depends(usuario_actual), conn=Depends(obtener_conexion)):
    cur = conn.cursor()
    orgs = _ambito(cur, usuario['id_usuario'])
    responsable = datos.mantenido_por or usuario['id_usuario']
    if not orgs & _membresias(cur, responsable):
        raise HTTPException(403, 'El responsable debe pertenecer al mismo ámbito vigente')
    cur.execute("""INSERT INTO recurso_apoyo(categoria,territorio,titulo,descripcion,canal,url_oficial,
                   mantenido_por,verificado_en,vence_en,activo) VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                   RETURNING id_recurso_apoyo""", _valores(datos, responsable))
    item = _leer(cur, cur.fetchone()[0])
    return {**item, 'puede_editar': True}


def _valores(datos, responsable):
    return (datos.categoria, datos.territorio, datos.titulo, datos.descripcion, datos.canal,
            str(datos.url_oficial) if datos.url_oficial else None, responsable,
            datos.verificado_en, datos.vence_en, datos.activo)


@router.put('/gestion/recursos-apoyo/{rid}')
def actualizar_recurso(datos: RecursoEntrada, rid: int = Path(gt=0), usuario=Depends(usuario_actual), conn=Depends(obtener_conexion)):
    cur = conn.cursor()
    anterior, orgs = _autorizado(cur, rid, usuario['id_usuario'])
    responsable = datos.mantenido_por or anterior
    if not orgs & _membresias(cur, responsable):
        raise HTTPException(403, 'La reasignación debe conservar el ámbito institucional del recurso')
    cur.execute("""UPDATE recurso_apoyo SET categoria=%s,territorio=%s,titulo=%s,descripcion=%s,canal=%s,
                   url_oficial=%s,mantenido_por=%s,verificado_en=%s,vence_en=%s,activo=%s
                   WHERE id_recurso_apoyo=%s""", (*_valores(datos, responsable), rid))
    return {**_leer(cur, rid), 'puede_editar': True}


@router.delete('/gestion/recursos-apoyo/{rid}', status_code=204)
def desactivar_recurso(rid: int = Path(gt=0), usuario=Depends(usuario_actual), conn=Depends(obtener_conexion)):
    cur = conn.cursor()
    _autorizado(cur, rid, usuario['id_usuario'])
    cur.execute('UPDATE recurso_apoyo SET activo=FALSE WHERE id_recurso_apoyo=%s', (rid,))


