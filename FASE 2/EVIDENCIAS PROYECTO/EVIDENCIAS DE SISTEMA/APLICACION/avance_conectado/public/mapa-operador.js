'use strict';

const MapaOperador = (() => {
  const centros = [
    ['las condes', -33.41, -70.57], ['santiago', -33.45, -70.66],
    ['chillan', -36.606, -72.104], ['concepcion', -36.827, -73.05],
  ];
  const normal = value => String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  const etiqueta = tipo => tipo === 'reporte' ? 'Reporte' : 'Avistamiento aceptado';
  let map, grupo;

  function cerrar() {
    if (map) map.remove();
    map = grupo = null;
  }

  function plantilla(orgs, actual) {
    return `<section class="geo-board" aria-label="Eventos de casos abiertos">
      <div class="geo-toolbar"><label>Organización<select id="geo-org">${orgs.map(o => `<option value="${Number(o.id_organizacion)}" ${o.id_organizacion===actual.id_organizacion?'selected':''}>${h(o.nombre)}</option>`).join('')}</select></label>
      <label>Tipo de evento<select id="geo-tipo"><option value="">Todos los eventos</option><option value="reporte">Reportes</option><option value="avistamiento">Avistamientos aceptados</option></select></label>
      <label>Buscar sector o folio<input type="search" id="geo-filtro" placeholder="Ej. Chillán"></label></div>
      <div class="geo-layout"><div class="geo-stage"><div id="geo-canvas" aria-label="Mapa de casos abiertos"></div>
      <button class="geo-fit" id="geo-fit">Centrar vista</button>
      <div class="geo-legend"><span><i></i>Reporte</span><span><i></i>Avistamiento aceptado</span></div></div>
      <section class="geo-feed"><div class="geo-feed-head"><small>Cobertura declarada</small><strong>${h(actual.territorio_cobertura)}</strong></div>
      <h2>Eventos <span id="geo-total"></span></h2><p class="geo-message" id="geo-message" role="status"></p><div id="geo-items"></div></section></div></section>`;
  }

  function montar(actual, data) {
    const canvas = el('geo-canvas'), lista = el('geo-items');
    const referencia = centros.find(([nombre]) => normal(actual.territorio_cobertura).includes(nombre));
    const tienePunto = e => Number.isFinite(e.latitud) && Number.isFinite(e.longitud);
    let visibles = [], tileError = false;
    function explicar() {
      const mensajes = [];
      if (!map || tileError) mensajes.push('Cartografía no disponible. Puedes abrir las fichas desde la lista.');
      if (data.hay_mas) mensajes.push('Se muestran los 300 eventos más recientes.');
      if (!visibles.length) mensajes.push(data.eventos.length ? 'Ningún evento coincide con los filtros.' : 'Sin eventos de casos abiertos en esta organización.');
      const sinPunto = visibles.filter(e => !tienePunto(e)).length;
      if (sinPunto) mensajes.push(`Sin coordenadas: ${sinPunto}.`);
      el('geo-message').textContent = mensajes.join(' ');
    }
    function encuadrar() {
      if (!map) return;
      const puntos = visibles.filter(tienePunto).map(e => [e.latitud,e.longitud]);
      if (puntos.length) map.fitBounds(puntos, {padding:[42,42], maxZoom:14,animate:false});
      else if (referencia) map.setView(referencia.slice(1), 12);
      else map.setView([-35.8,-71.4],5);
    }
    if (window.L) {
      map = L.map(canvas,{scrollWheelZoom:false});
      const capa = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom:19, referrerPolicy:'strict-origin-when-cross-origin',
        attribution:'&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      });
      capa.on('tileerror', () => { if(map){tileError=true;explicar();} });
      capa.on('tileload', () => { if(map && tileError){tileError=false;explicar();} });
      capa.addTo(map); grupo=L.layerGroup().addTo(map);
    } else el('geo-fit').disabled=true;

    function actualizar() {
      const tipo=el('geo-tipo').value, texto=normal(el('geo-filtro').value.trim());
      visibles=data.eventos.filter(e => (!tipo || e.tipo===tipo) && normal(e.zona+' '+e.folio).includes(texto));
      el('geo-total').textContent=String(visibles.length);
      lista.innerHTML=visibles.map(e => `<article class="geo-event ${e.tipo==='reporte'?'report':'sighting'}">
        <small>${etiqueta(e.tipo)}</small><strong>${h(e.zona)}</strong><span>${h(date(e.fecha))}</span>
        <button data-case="${Number(e.id_caso)}">Abrir ${h(e.folio)} →</button></article>`).join('');
      if (map) {
        grupo.clearLayers();
        const lugares=new Map();
        for(const evento of visibles.filter(tienePunto)){
          const llave=evento.latitud+','+evento.longitud;
          if(!lugares.has(llave))lugares.set(llave,[]);
          lugares.get(llave).push(evento);
        }
        for (const eventos of lugares.values()) {
          const primero=eventos[0],varios=eventos.length>1;
          const marker=L.circleMarker([primero.latitud,primero.longitud],{
            color:'#fff',weight:2,radius:varios?13:9,fillColor:varios?'#2c4764':primero.tipo==='reporte'?'#155bbd':'#0a786c',fillOpacity:1,
          }).addTo(grupo);
          if(varios) marker.bindTooltip(String(eventos.length),{permanent:true,direction:'center',className:'geo-count',opacity:1});
          const popup=document.createElement('div');
          for(const e of eventos){
            const title=document.createElement('strong');title.textContent=etiqueta(e.tipo);
            const caption=document.createElement('p');caption.textContent=e.zona+' · '+date(e.fecha);
            const button=document.createElement('button');button.textContent='Abrir '+e.folio;
            button.onclick=()=>abrirCaso(e.id_caso);
            const fila=document.createElement('section');fila.append(title,caption,button);popup.append(fila);
          }
          marker.bindPopup(popup,{maxHeight:220});
        }
      }
      encuadrar(); explicar();
    }
    el('geo-fit').onclick=encuadrar;
    el('geo-tipo').onchange=actualizar; el('geo-filtro').oninput=actualizar;
    actualizar();
  }
  return {plantilla,montar,cerrar};
})();
