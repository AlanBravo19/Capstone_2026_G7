# RutaAlerta · Beta 0.13.0

El mapa móvil concentra los controles de GPS, perspectiva y ciudades junto a la cartografía. El planificador prioriza origen y destino. Modo trayecto dispone de navegación de regreso. En Colaborar se puede buscar a 30 km del GPS o fijar otra zona. Un colaborador puede adjuntar una foto opcional al avistamiento. Texto y foto se guardan en una sola operación.

En el escritorio, Avistamientos pendientes reúne los aportes de la organización. En la ficha se revisa la fotografía privada, se decide sobre el aporte y se puede enviar una actualización al titular. Los mensajes llegan a la bandeja interna. El ensayo de Chillán se reproduce en una base temporal con tests/test_recorrido_chillan.py del servidor.

## Historial

# RutaAlerta · Beta 0.12.0

En Android cualquier persona puede crear una cuenta ciudadana. Desde Inicio puede buscar vehículos con solicitud activa, informar como testigo o reportar el robo de un vehículo propio. Mapa, Colaborar y Cuenta están en la barra inferior.

El escritorio de operaciones admite cuentas personales previamente habilitadas. La administración asigna la organización y el rol de operador o supervisor por un canal interno. El servidor comprueba la cuenta activa y la membresía al ingresar y al confirmar el segundo factor, si está configurado. El dominio del correo no concede permisos. Las solicitudes de acceso se dirigen a la administración de la institución. La beta utiliza una organización de ensayo.

## Historial

# RutaAlerta · Beta 0.11.0

Alta ciudadana con modalidad de colaboración, aviso privado de pasajero o testigo sin vehículo ni patente, y revisión del aviso en el escritorio. La ficha institucional incorpora responsable, gestiones internas y renovación de publicaciones. Cámaras admite inventario y reproducción local de clips autorizados. La migración 07 amplía el esquema a 66 tablas. El documento alcance_mvp_0110.md en las evidencias del servidor detalla prioridades y pruebas de cierre.

## Historial

# RutaAlerta · Beta 0.10.0

## Registro ciudadano y vehículos

Desde Android o /ciudadania, selecciona Crear cuenta, indica tu nombre, correo y contraseña y confirma el código recibido. Configura una aplicación autenticadora y conserva los códigos de recuperación. El alta pública asigna el rol ciudadano. /operaciones comprueba la membresía institucional. Un acompañante puede colaborar sin registrar un vehículo.

El catálogo de altas admite automóvil, camioneta, furgón, motocicleta y camión. Bus no figura como tipo específico en el esquema. Otro y sin_dato siguen disponibles en los registros históricos. Los 65 objetos de tipo tabla se mantienen. El servidor verifica la combinación de tipo, marca y modelo contra una extracción de las nóminas livianos y pesados del SII 2026. En total hay 6.470 combinaciones distintas. La extracción usa los rótulos de carrocería definidos en scripts/importar_catalogo_sii.py. Omite categorías ambiguas, accesorios y carrocerías sin equivalencia en el MVP. Un modelo ausente no podrá darse de alta hasta actualizar el catálogo. Esta restricción no afecta los registros ya guardados.

La validación de PPU revisa estructura y normaliza separadores. Para cuatro ruedas contempla AA1234, BBBB12 y BBBBB1. Para motocicleta contempla AA123, BBB12 y BBBB1. La introducción de nuevas series depende de la determinación del Registro Civil prevista en el decreto. La app no verifica la emisión de la serie, la existencia de la placa o la propiedad.

Fuentes: [Nóminas SII](https://www.sii.cl/servicios_online/1049-2612.html) y [Decreto 53, artículos 2 y 2 bis](https://www.bcn.cl/leychile/navegar?idNorma=133287&idVersion=2026-01-16).

## Historial de versiones

## Beta 0.9 · Aplicación ciudadana y escritorio institucional

En Android, Inicio permite consultar solicitudes con «Vi un vehículo» y colaborar sin tener auto. Las cuatro secciones son Inicio, Colaborar, Mapa y Cuenta. El registro de un vehículo vinculado se utiliza al reportar su robo. El afectado selecciona qué organización recibirá ese reporte.

El escritorio está en https://rutaalerta-mvp-g7.vercel.app/operaciones. Se ingresa con invitación, credenciales y el segundo factor cuando está activo. La membresía vigente determina qué casos puede consultar el operador. El panel permite filtrar por estado y folio, leer el relato privado, revisar aportes y fotos, gestionar publicaciones consentidas, cerrar casos, revisar fuentes territoriales y consultar el inventario de cámaras. La web de acceso ciudadano anterior sigue en /ciudadania.

El panel usa la API de RutaAlerta y la base existente de 65 tablas. Su interfaz usa HTML, CSS y JavaScript. La aprobación de un antecedente, una publicación o una evidencia exige una decisión humana.


Documentación de la versión 0.8: [ESTADO_FUNCIONAL_080.md](ESTADO_FUNCIONAL_080.md). Correo real por Brevo, TOTP, desbloqueo biométrico Android, lugares privados, rutas con apertura Google Maps/Waze y avisos locales basados en fuentes revisadas. El esquema actual tiene 65 tablas. SMS no contratado; no se simula en operación.

El contenido siguiente documenta la versión anterior:

# RutaAlerta · Beta colaborativa 0.7.0

La documentación vigente de alcance, funcionamiento, límites y puesta en marcha está en [ESTADO_FUNCIONAL_070.md](ESTADO_FUNCIONAL_070.md).

API FastAPI conectada a PostgreSQL/PostGIS en Supabase, con app Flutter Android. Incluye TOTP real, casos privados, seguimiento, fotos privadas, confianza revocable, colaboración revisada, avistamientos, gestión y buzón interno. El correo y SMS no tienen proveedor real configurado; las cámaras, rutas e IA requieren integraciones adicionales detalladas en el estado funcional.

Migración nueva: `sql/05_Beta_Colaborativa.sql` (63 tablas en total, sin borrar datos previos). No recargar el esquema inicial sobre un proyecto existente.

Código preparado con asistencia de IA. Las pruebas reales y sus límites están en `evidencias/`. No atribuye aportes ni aprobación a los integrantes o docentes.
