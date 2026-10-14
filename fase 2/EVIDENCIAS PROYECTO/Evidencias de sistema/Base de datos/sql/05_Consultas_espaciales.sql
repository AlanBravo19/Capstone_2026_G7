-- Ejemplos de sólo lectura. Sustituir parámetros en la API con valores enlazados.
SET search_path=rutaalerta,public;
-- Cámaras de la organización 1 dentro de 1 km de un punto de ensayo. Longitude primero.
SELECT id_camara,nombre,ST_Distance(ubicacion,ST_SetSRID(ST_Point(-73.05,-36.82),4326)::geography) AS distancia_m
FROM camara WHERE id_organizacion=1 AND entorno='prueba' AND estado='disponible'
AND ST_DWithin(ubicacion,ST_SetSRID(ST_Point(-73.05,-36.82),4326)::geography,1000)
ORDER BY distancia_m;
-- Corredores que cruzan cobertura conocida; se limita la organización y la sesión.
SELECT h.id_hipotesis_ruta,c.id_camara,c.nombre
FROM hipotesis_ruta h JOIN sesion_busqueda s USING(id_sesion_busqueda)
JOIN camara c ON c.id_organizacion=s.id_organizacion
AND ST_Intersects(h.geometria,c.cobertura)
WHERE s.id_sesion_busqueda=1 AND s.id_organizacion=1;
-- Agregación interna para mapa de calor. El agrupamiento ciudadano se realiza por sectores
-- y sólo se publica cuando el mínimo de registros y las reglas de privacidad se cumplen.
SELECT zona,count(*) AS hechos_validados
FROM hecho_territorial WHERE estado='validado' AND entorno='prueba'
AND ocurrido_en >= CURRENT_TIMESTAMP-interval '365 days' GROUP BY zona;
