# Prototipo navegable de RutaAlerta

Prototipo de alta fidelidad, sólo de interfaz, con datos ficticios. Muestra cómo funcionaría la plataforma de punta a punta. **No es la aplicación final**: no está conectado a la API ni a la base de datos de `../backend`.

| Archivo | Qué es |
|---|---|
| `RutaAlerta_Prototipo.html` | El prototipo completo en un solo archivo |
| `RutaAlerta_Demo_Prototipo.mp4` | Video narrado de 3 minutos con el recorrido completo, grabado del prototipo real |

## Cómo abrirlo

1. Descargar `RutaAlerta_Prototipo.html` y abrirlo con Chrome o Edge (doble clic).
2. Necesita internet: carga React y htm desde cdnjs y jsDelivr, y las fuentes desde Google Fonts.
3. Lo que se hace queda guardado sólo en ese navegador. En **Guía de la demo → Reiniciar datos de la demo** se vuelve al estado inicial.

## Cuentas de demostración

Todas usan la contraseña `demo1234`. También se puede entrar con un clic desde la pantalla de ingreso.

| Cuenta | Persona | Rol |
|---|---|---|
| `ana.rojas@demo.invalid` | Ana Rojas | Persona afectada |
| `pedro.soto@demo.invalid` | Pedro Soto | Ciudadano colaborador |
| `operador1@demo.invalid` | Carla Muñoz | Operadora |
| `supervisor1@demo.invalid` | Diego Fuentes | Supervisor |
| `admin@demo.invalid` | Valentina Araya | Administradora |
| `operador2@demo.invalid` | Ignacio Lagos | Operador de otra organización |

Las cuentas comparten los datos: lo que Ana reporta aparece en la bandeja de la operadora y lo que la operadora decide le llega a Ana como aviso. La **Guía de la demo** recorre un caso completo cambiando de cuenta.

## Qué incluye

**App de la persona afectada y del colaborador**
- Ingreso, registro y recuperación de clave con código de un solo uso (HU01).
- Mis vehículos con vínculo pendiente de revisión (HU02).
- Reporte en tres pasos con folio, reintento sin duplicar y evidencia con huella SHA-256 (HU03, HU04).
- Mi caso con estado, siguiente paso, novedades y contacto de confianza revocable (HU06, HU07).
- Solicitudes vigentes e informe de avistamientos (HU05, HU11).
- Avisos y privacidad con consentimientos (HU12).

**Panel institucional**
- Bandeja por organización y prueba de acceso ajeno con error 403 (HU13, CP44).
- Detalle del caso: asignación, estados, bitácora, solicitud de colaboración y cierre con respaldo (HU15, HU16, HU17).
- Revisión de avistamientos con motivo obligatorio e historial (HU14).
- Indicadores M01, M05, M08, M09 y M11 calculados con los datos de la demo (HU18).
- Administración: roles, canales de apoyo, fuentes históricas y auditoría de sólo lectura (HU19 a HU23).

**Ampliación propuesta OE5 y OE6 (no comprometida)**
- Búsqueda asistida: corredores posibles, cámaras recomendadas con decisión y motivo, video simulado, candidatos ordenados por IA y copiloto con hechos, hipótesis, limitaciones y referencias (HU26 a HU31).

**Alcance por acordar con los docentes**
- Trayecto con avisos territoriales cerca de puntos con reportes históricos (HU10, HU25).
- Antecedentes por sector y comparación de rutas (HU08, HU09).
- Validación de lotes de fuentes históricas antes de generar avisos (HU20, HU21).

## Qué es simulado

- Personas, folios, patentes, organizaciones, fuentes y lugares son ficticios.
- La ubicación del trayecto, las cámaras, el video y las detecciones de IA son simulados.
- El copiloto usa Claude sólo cuando el prototipo se abre como artifact publicado en claude.ai. Abierto desde este archivo responde un asistente local de demostración, y la pantalla lo indica.
- No envía correos ni notificaciones reales, y el mapa es esquemático.
- El prototipo no reemplaza la denuncia, no predice delitos, no declara rutas seguras y no sigue vehículos con el GPS del teléfono de la víctima.

## Autoría

Preparado con asistencia de IA (Claude) a partir del diseño del equipo: libro v4.1, documentos 01 a 10 y C1 a C3. El equipo debe revisarlo, probarlo y poder explicarlo. La narración del video usa una voz sintética (Microsoft Lorenzo, español de Chile).
