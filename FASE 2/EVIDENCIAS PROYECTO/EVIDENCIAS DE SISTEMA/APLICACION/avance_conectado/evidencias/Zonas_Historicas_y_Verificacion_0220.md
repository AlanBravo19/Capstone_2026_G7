# RutaAlerta 0.22 · Zonas históricas, rutas y verificación vehicular

## Padrón y revisión

1. En **Mis vehículos**, el titular adjunta una imagen legible del padrón en JPEG, PNG o WebP, hasta 2 MB, y selecciona la organización revisora.
2. El padrón queda en **Operaciones → Verificar vínculos**. El servidor envía una novedad interna a los supervisores de esa organización. El aviso no contiene la patente ni un enlace público al archivo.
3. El supervisor con membresía vigente revisa el padrón y coteja la identidad por el canal institucional. El operador gestiona el reporte del robo y sus avistamientos. La imagen queda fuera de colaboración y se retira del registro activo al resolver el vínculo.
4. La prelectura usa Qwen 3.8 27B mediante GroqCloud. Extrae la patente del padrón ficticio y devuelve coincidencia, diferencia o lectura inconclusa. El servidor comprueba que la imagen corresponda exactamente a la generada para el ensayo. El resultado ayuda al cotejo y el vínculo queda pendiente de decisión del supervisor. La autenticidad y titularidad requieren una comprobación documental autorizada. [Imágenes y visión en GroqCloud](https://console.groq.com/docs/vision) · [Tratamiento de datos en GroqCloud](https://console.groq.com/docs/your-data)

## Alta y confirmación de antecedentes históricos

1. En **Operaciones → Fuentes territoriales**, registra el enlace HTTPS original, el medio o institución, un resumen propio, el tipo de hecho, la fecha y el sector aproximado. El antecedente comienza pendiente.
2. Compara fuente, fecha y lugar. Cuando varias publicaciones describen el mismo incidente, conserva una ficha validada y descarta las otras. Al validar, registra centro aproximado, incertidumbre, radio del aviso, vigencia y fundamento.
3. La capa roja usa fichas validadas, vigentes, con fecha del hecho o publicación dentro de 365 días y precisión declarada de hasta 800 m. `ST_DWithin` filtra el área consultada en metros. PostGIS agrupa los centros en una cuadrícula de `0,01°`, exige al menos dos fichas por celda y genera un área de radio de 800 m con `ST_Buffer`. El color aumenta con el número de fichas. Una fuente imprecisa puede seguir en el historial sin que genere una mancha roja.
4. Toca una zona en el mapa de Android para ver el sector, el número de antecedentes y el radio. Las fichas mantienen su fuente y fecha. La capa representa una concentración de antecedentes revisados. Los recuentos se refieren a las fichas disponibles y carecen de denominador poblacional. [PostGIS y consultas por radio](https://postgis.net/docs/ST_DWithin.html)

## Ruta de Casa a Trabajo y ubicación del reporte

- En **Mis lugares y rutas**, guarda Casa y Trabajo o busca una dirección puntual. También puedes elegir un punto sobre el mapa o usar el GPS como origen. **De Casa a Trabajo** completa ambos extremos cuando están guardados.
- OSRM devuelve hasta tres alternativas. PostGIS calcula cuántas zonas históricas intersecta cada trazado. Con la preferencia activada, el planificador pone primero la opción con menos cruces y, en empate, la más rápida. Si todas cruzan zonas, el resultado lo indica. Cada ruta muestra las manchas rojas y el trazado celeste. La opción que abra Google Maps o Waze tendrá el recorrido que calcule esa aplicación. [Alternativas en OSRM](https://project-osrm.org/docs/v26.6.1/http)
- En el formulario de robo, selecciona primero el punto del hecho. **Usar mi ubicación actual** corresponde a donde está el teléfono. Si estás en otro lugar, selecciona la ubicación sobre el mapa. Android puede sugerir una comuna a partir del punto y el catálogo. Confírmala o búscala por nombre, sin necesidad de tildes, o por código. La calle o referencia es opcional. La app valida el código del catálogo y conserva la coordenada como ubicación del hecho.
- La previsualización en Inicio se puede tocar para ampliar. Los créditos cartográficos siguen disponibles en un control discreto. [Atribución de OpenFreeMap](https://openfreemap.org/#attribution)

## Mostrar a profesores

Desde `RutaAlerta_Conectado/`, ejecuta `python scripts/demostrar_alertas.py` con las dependencias de `requirements.txt` y de `scripts/package.json` instaladas. La API arranca en localhost con una base en memoria. La terminal muestra los accesos temporales para titular, colaborador y supervisor. El script deja listo un padrón ficticio pendiente en `ZQXT92`. El `ZQXT91` ya pasó la revisión y se puede usar en el reporte de ensayo.

El escenario contiene seis fichas ficticias que forman dos manchas cerca de Concepción. El mapa las marca como **ENSAYO**. También prepara Casa y Trabajo de ensayo. Las zonas se cargan por el mismo flujo de alta y validación de fuentes que usa el panel. Para comprobar el recorrido por API y terminar, ejecuta `python scripts/demostrar_alertas.py --validar`.

En Windows, `.\Conectar_Groq.ps1 -Accion Configurar` guarda la clave cifrada para el usuario local. `.\Conectar_Groq.ps1 -Accion Validar` consulta la API con el padrón ficticio `ZQXT92` y comprueba que el vínculo siga pendiente. `.\Conectar_Groq.ps1 -Accion Demostrar` inicia el escenario para usar ese mismo padrón desde el panel. Estas acciones requieren las dependencias Python y Node del ensayo. Crea la clave en la [consola de GroqCloud](https://console.groq.com/keys).

La API 0.22 utiliza el esquema de 68 tablas con las migraciones 09 y 10 ya aplicadas. El mapa del portal sigue la API desplegada y la APK usa el `API_BASE` de su compilación. Para demostrar la APK contra una instancia distinta, compílala con `--dart-define=API_BASE=https://DIRECCION-DE-ENSAYO`. El ensayo local HTTP está pensado para el navegador. La base de producción y los padrones de usuarios quedan separados del escenario ficticio.

## Comprobaciones del 25 de noviembre de 2026

- **API y PostGIS local:** 176 pruebas pasaron. Se comprobó el aviso al supervisor, la separación de ensayos, el cómputo de cruces y el orden de dos rutas controladas.
- **Prelectura de IA:** pasaron las tres pruebas de padrón. En la prueba automatizada con respuesta simulada, el sistema rechazó una imagen fuera del ensayo antes de consultar al proveedor. En una llamada real desde la API local, GroqCloud con Qwen 3.8 27B leyó el padrón ficticio `ZQXT92`, RutaAlerta devolvió `coincide` y el vínculo siguió pendiente de revisión.
- **Flutter:** análisis sin incidencias. Pasaron 44 pruebas y quedó omitida la prueba remota. Se comprobó la búsqueda de comuna en el formulario y quedó pendiente probar la sugerencia geográfica en un teléfono físico. La APK `0.22.0+21` se compiló y pasó la verificación de firma.
- **Portal:** 26 pruebas JavaScript pasaron. En Edge se comprobó el alta con padrón, la revisión privada, la alerta provisional y la visualización de dos zonas ficticias en el mapa 3D. La captura está en `output/RutaAlerta_Zonas_Historicas_0220.png`.
