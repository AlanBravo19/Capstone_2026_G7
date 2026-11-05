"use strict";
window.RutaMapa=(()=>{
 const el=id=>document.getElementById(id);
 let mapa=null,seleccion=null,casos=[],marcas=[],vista3d=true;
 const valido=(lat,lng)=>Number.isFinite(lat)&&Number.isFinite(lng)&&Math.abs(lat)<=90&&Math.abs(lng)<=180;
 function mensaje(t,error=false){el('mapa-estado').textContent=t;el('mapa-estado').classList.toggle('map-error',error);}
 function seleccionar(lat,lng){
  if(!valido(lat,lng))return;
  el('latitud').value=lat.toFixed(6);el('longitud').value=lng.toFixed(6);
  if(mapa){if(!seleccion)seleccion=new maplibregl.Marker({color:'#087f80'});seleccion.setLngLat([lng,lat]).addTo(mapa);}
  mensaje(`Lugar seleccionado: ${lat.toFixed(5)}, ${lng.toFixed(5)}. Se guardará al registrar el reporte.`);
 }
 function puntos(){
  if(!mapa)return;
  marcas.forEach(m=>m.remove());marcas=[];
  for(const c of casos){
   if(c.latitud==null||c.longitud==null)continue;
   const lat=Number(c.latitud),lng=Number(c.longitud);if(!valido(lat,lng))continue;
   const contenido=document.createElement('div');const titulo=document.createElement('strong');titulo.textContent=c.folio;
   const detalle=document.createElement('p');detalle.textContent=`${c.zona} · ${String(c.estado).replaceAll('_',' ')}`;contenido.append(titulo,detalle);
   const m=new maplibregl.Marker({color:'#bf7545',scale:.8}).setLngLat([lng,lat]).setPopup(new maplibregl.Popup({offset:25}).setDOMContent(contenido)).addTo(mapa);
   m.getElement().addEventListener('click',e=>e.stopPropagation());marcas.push(m);
  }
  el('mapa-total').textContent=`${marcas.length} reportes ubicados`;
 }
 function abrir(){
  if(!window.maplibregl||!maplibregl.supported()){mensaje('Este dispositivo no pudo iniciar el mapa 3D. Puedes escribir las coordenadas manualmente.',true);el('mapa-contenido').hidden=false;return;}
  el('mapa-intro').hidden=true;el('mapa-contenido').hidden=false;
  if(!mapa){
   mapa=new maplibregl.Map({container:'mapa',style:'https://tiles.openfreemap.org/styles/liberty',center:[-73.05,-36.827],zoom:16,pitch:55,bearing:-20,attributionControl:true});
   mapa.addControl(new maplibregl.NavigationControl({visualizePitch:true}),'top-right');mapa.addControl(new maplibregl.FullscreenControl(),'top-right');
   mapa.on('click',e=>seleccionar(e.lngLat.lat,e.lngLat.wrap().lng));
   mapa.on('error',()=>mensaje('No se pudo cargar parte de la cartografía 3D. Puedes continuar con coordenadas manuales.',true));
   mapa.on('load',()=>{puntos();desdeCampos();mensaje('Mapa 3D: gira e inclina la vista. Los edificios dependen de la cobertura cartográfica y sus alturas pueden ser aproximadas.');});
   puntos();desdeCampos();
  }
  requestAnimationFrame(()=>mapa.resize());
 }
 function desdeCampos(){if(el('latitud').value.trim()&&el('longitud').value.trim())seleccionar(Number(el('latitud').value),Number(el('longitud').value));}
 function ir(center){mapa?.flyTo({center,zoom:16,pitch:vista3d?55:0,bearing:vista3d?-20:0});}
 el('abrir-mapa').addEventListener('click',abrir);
 el('mapa-concepcion').addEventListener('click',()=>ir([-73.05,-36.827]));
 el('mapa-santiago').addEventListener('click',()=>ir([-70.66,-33.45]));
 el('mapa-vista').addEventListener('click',()=>{vista3d=!vista3d;el('mapa-vista').textContent=vista3d?'Ver en 2D':'Ver en 3D';mapa?.easeTo({pitch:vista3d?55:0,bearing:vista3d?-20:0});});
 el('mapa-mis-casos').addEventListener('click',()=>{if(!marcas.length){mensaje('Todavía no tienes reportes ubicados.');return;}const bounds=new maplibregl.LngLatBounds();marcas.forEach(m=>bounds.extend(m.getLngLat()));mapa.fitBounds(bounds,{padding:60,maxZoom:16,pitch:vista3d?55:0});});
 el('latitud').addEventListener('change',desdeCampos);el('longitud').addEventListener('change',desdeCampos);
 function quitarSeleccion(){seleccion?.remove();seleccion=null;mensaje('Toca el lugar del incidente para preparar tu reporte.');}
 function limpiar(){casos=[];marcas.forEach(m=>m.remove());marcas=[];quitarSeleccion();mapa?.remove();mapa=null;vista3d=true;el('mapa-vista').textContent='Ver en 2D';el('mapa-contenido').hidden=true;el('mapa-intro').hidden=false;el('latitud').value='';el('longitud').value='';el('mapa-total').textContent='0 puntos';}
 return {actualizar(datos){casos=datos;puntos();},limpiar,quitarSeleccion};
})();
