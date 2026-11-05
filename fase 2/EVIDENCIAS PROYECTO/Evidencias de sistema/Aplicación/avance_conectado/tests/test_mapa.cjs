const {test}=require('node:test');const assert=require('node:assert/strict');const vm=require('node:vm');const fs=require('node:fs');const path=require('node:path');
function entorno(supported=true){
 const els=new Map();const doc={getElementById(id){if(!els.has(id))els.set(id,{value:'',hidden:false,textContent:'',events:{},classList:{toggle(){}},addEventListener(n,f){this.events[n]=f;}});return els.get(id)},createElement(){return {textContent:'',append(...items){this.children=items}}}};
 let config;const maps=[];
 class MockMap{constructor(c){config=c;this.events={};maps.push(this)}on(n,f){this.events[n]=f;return this}addControl(){}resize(){}remove(){this.removed=true}flyTo(c){this.camera=c}easeTo(c){this.camera=c}fitBounds(){}}
 class Marker{constructor(){this.element={addEventListener(){}}}setLngLat(c){this.coords=c;return this}addTo(){return this}remove(){this.removed=true}setPopup(p){this.popup=p;return this}getElement(){return this.element}getLngLat(){return this.coords}}
 class Popup{setDOMContent(c){this.content=c;return this}}
 const lib={Map:MockMap,Marker,Popup,supported:()=>supported,NavigationControl:class{},FullscreenControl:class{},LngLatBounds:class{extend(){}}};
 const ctx={window:{maplibregl:lib},maplibregl:lib,document:doc,requestAnimationFrame:f=>f()};vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../public/mapa.js'),'utf8'),ctx);
 return {api:ctx.window.RutaMapa,el:doc.getElementById.bind(doc),maps,config:()=>config};
}
test('no carga cartografía antes de pulsar abrir',()=>{const e=entorno();assert.equal(e.maps.length,0);});
test('abre estilo vectorial con perspectiva y conserva selección',()=>{const e=entorno();e.el('abrir-mapa').events.click();assert.equal(e.config().pitch,55);assert.match(e.config().style,/openfreemap/);e.maps[0].events.click({lngLat:{lat:-36.82,wrap:()=>({lng:-73.05})}});assert.equal(e.el('latitud').value,'-36.820000');});
test('alterna 2D y 3D',()=>{const e=entorno();e.el('abrir-mapa').events.click();e.el('mapa-vista').events.click();assert.equal(e.maps[0].camera.pitch,0);e.el('mapa-vista').events.click();assert.equal(e.maps[0].camera.pitch,55);});
test('filtra ubicaciones inválidas',()=>{const e=entorno();e.api.actualizar([{latitud:-36,longitud:-73,folio:'ENSAYO',estado:'reportado',zona:'Sector ficticio'},{latitud:999,longitud:0}]);e.el('abrir-mapa').events.click();assert.equal(e.el('mapa-total').textContent,'1 reportes ubicados');});
test('limpia mapa y coordenadas al cerrar sesión',()=>{const e=entorno();e.el('abrir-mapa').events.click();e.el('latitud').value='-36';e.api.limpiar();assert.equal(e.maps[0].removed,true);assert.equal(e.el('latitud').value,'');});
test('sin soporte gráfico permite coordenadas manuales',()=>{const e=entorno(false);e.el('abrir-mapa').events.click();assert.equal(e.maps.length,0);assert.match(e.el('mapa-estado').textContent,/manualmente/);});
