'use strict';
// Los puntos pertenecen únicamente a /mis-casos. No se consultan datos de otras cuentas.
window.RutaMapa=(()=>{
 const el=id=>document.getElementById(id);
 let mapa=null,capaCasos=null,seleccion=null,casos=[];
 const valido=(lat,lng)=>Number.isFinite(lat)&&Number.isFinite(lng)&&Math.abs(lat)<=90&&Math.abs(lng)<=180;
 function mensaje(texto,error=false){el('mapa-estado').textContent=texto;el('mapa-estado').classList.toggle('map-error',error);}
 function seleccionar(lat,lng,centrar=false){
  if(!valido(lat,lng))return;
  el('latitud').value=lat.toFixed(6);el('longitud').value=lng.toFixed(6);
  if(mapa){
   if(seleccion)seleccion.remove();
   seleccion=L.circleMarker([lat,lng],{radius:11,color:'#fff',weight:3,fillColor:'#087f80',fillOpacity:1,bubblingMouseEvents:false}).addTo(mapa);
   seleccion.bindTooltip('Lugar seleccionado para el nuevo reporte');
   if(centrar)mapa.setView([lat,lng],14);
  }
  mensaje(`Ubicación seleccionada: ${lat.toFixed(5)}, ${lng.toFixed(5)}. Se guardará al registrar el reporte.`);
 }
 function puntos(){
  if(!capaCasos)return;
  capaCasos.clearLayers();
  for(const c of casos){
   if(c.latitud==null||c.longitud==null)continue;
   const lat=Number(c.latitud),lng=Number(c.longitud);
   if(!valido(lat,lng))continue;
   const contenido=document.createElement('div');
   const titulo=document.createElement('strong');titulo.textContent=c.folio;
   const detalle=document.createElement('p');detalle.textContent=`${c.zona} · ${String(c.estado).replaceAll('_',' ')}`;
   contenido.append(titulo,detalle);
   L.circleMarker([lat,lng],{radius:8,color:'#fff',weight:2,fillColor:'#c67743',fillOpacity:.95,bubblingMouseEvents:false}).bindPopup(contenido).addTo(capaCasos);
  }
  el('mapa-total').textContent=`${capaCasos.getLayers().length} reportes ubicados`;
 }
 function abrir(){
  if(!window.L){el('mapa-intro').querySelector('h3').textContent='No se pudo cargar el mapa';el('mapa-intro').querySelector('p').textContent='Revisa tu conexión o utiliza los campos de latitud y longitud para continuar.';return;}
  el('mapa-intro').hidden=true;el('mapa-contenido').hidden=false;
  if(!mapa){
   mapa=L.map('mapa',{scrollWheelZoom:false,worldCopyJump:true}).setView([-36.827,-73.05],12);
   // La política por elemento envía sólo el origen, nunca la ruta ni los datos del caso.
   L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',{
    maxZoom:19,referrerPolicy:'origin',
    attribution:'&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
   }).on('tileerror',()=>mensaje('No se pudo cargar parte de la cartografía. Puedes seguir usando las coordenadas.',true)).addTo(mapa);
   capaCasos=L.layerGroup().addTo(mapa);
   mapa.on('click',e=>seleccionar(e.latlng.lat,e.latlng.wrap().lng));
   puntos();
   desdeCampos();
  }
  requestAnimationFrame(()=>mapa.invalidateSize());
 }
 function desdeCampos(){
  if(!el('latitud').value.trim()||!el('longitud').value.trim())return;
  seleccionar(Number(el('latitud').value),Number(el('longitud').value));
 }
 el('abrir-mapa').addEventListener('click',abrir);
 el('mapa-concepcion').addEventListener('click',()=>mapa?.setView([-36.827,-73.05],12));
 el('mapa-santiago').addEventListener('click',()=>mapa?.setView([-33.45,-70.66],12));
 el('mapa-mis-casos').addEventListener('click',()=>{
  if(!capaCasos||!capaCasos.getLayers().length){mensaje('Todavía no tienes reportes con ubicación guardada.');return;}
  const grupo=L.featureGroup(capaCasos.getLayers());mapa.fitBounds(grupo.getBounds(),{padding:[35,35],maxZoom:14});
 });
 el('latitud').addEventListener('change',desdeCampos);el('longitud').addEventListener('change',desdeCampos);
 function quitarSeleccion(){if(seleccion)seleccion.remove();seleccion=null;mensaje('Haz clic en el mapa para elegir el lugar del nuevo reporte.');}
 function limpiar(){
  casos=[];quitarSeleccion();if(mapa)mapa.remove();mapa=null;capaCasos=null;
  el('mapa-contenido').hidden=true;el('mapa-intro').hidden=false;
  el('latitud').value='';el('longitud').value='';el('mapa-total').textContent='0 puntos';
 }
 return {actualizar(datos){casos=datos;puntos();},limpiar,quitarSeleccion};
})();
