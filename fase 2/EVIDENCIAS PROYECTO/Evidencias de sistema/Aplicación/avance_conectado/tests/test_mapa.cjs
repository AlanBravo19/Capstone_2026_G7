const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
function entorno(conL=true){
 const elementos=new Map();
 const elemento=()=>({value:'',textContent:'',hidden:false,listeners:{},classList:{toggle(){}},
  addEventListener(n,fn){this.listeners[n]=fn},querySelector(){return this},append(...x){this.hijos=x}});
 const document={getElementById(id){if(!elementos.has(id))elementos.set(id,elemento());return elementos.get(id)},createElement:elemento};
 let mapas=0,tiles=0,capas=[];
 const mapa={eventos:{},setView(){return this},on(n,f){this.eventos[n]=f;return this},invalidateSize(){},remove(){this.eliminado=true},fitBounds(){}};
 const L={map(){mapas++;return mapa},tileLayer(url,opts){tiles++;assert.equal(opts.referrerPolicy,'origin');return {on(){return this},addTo(){return this}}},
  layerGroup(){const grupo={layers:[],addTo(){return this},clearLayers(){this.layers=[]},getLayers(){return this.layers}};capas.push(grupo);return grupo},
  circleMarker(coords){return {coords,addTo(capa){if(capa.layers)capa.layers.push(this);return this},bindTooltip(){return this},bindPopup(x){this.popup=x;return this},remove(){}}},
  featureGroup(){return {getBounds(){return {}}}}};
 const ctx={window:{},document,requestAnimationFrame:f=>f(),Number,String};
 if(conL){ctx.L=L;ctx.window.L=L;}
 vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../public/mapa.js'),'utf8'),ctx);
 return {api:ctx.window.RutaMapa,el:document.getElementById.bind(document),mapa,capas,cuentas:()=>({mapas,tiles})};
}
test('no solicita cartografía hasta abrir el mapa',()=>{
 const e=entorno();assert.equal(e.cuentas().tiles,0);
 e.el('abrir-mapa').listeners.click();assert.equal(e.cuentas().tiles,1);
});
test('clic selecciona coordenadas sin guardar un caso',()=>{
 const e=entorno();e.el('abrir-mapa').listeners.click();
 e.mapa.eventos.click({latlng:{lat:-36.82,wrap:()=>({lng:-73.05})}});
 assert.equal(e.el('latitud').value,'-36.820000');assert.equal(e.el('longitud').value,'-73.050000');
 assert.match(e.el('mapa-estado').textContent,/al registrar/);
});
test('filtra puntos inválidos y conserva texto sin interpretarlo como HTML',()=>{
 const e=entorno();e.api.actualizar([{latitud:-36.82,longitud:-73.05,folio:'<script>x</script>',zona:'Sector de ensayo',estado:'reportado'},
  {latitud:null,longitud:null},{latitud:999,longitud:0}]);e.el('abrir-mapa').listeners.click();
 assert.equal(e.capas[0].layers.length,1);
 assert.equal(e.capas[0].layers[0].popup.hijos[0].textContent,'<script>x</script>');
});
test('cerrar sesión elimina puntos, mapa y coordenadas',()=>{
 const e=entorno();e.el('abrir-mapa').listeners.click();e.el('latitud').value='-36';
 e.api.limpiar();assert.equal(e.mapa.eliminado,true);assert.equal(e.el('latitud').value,'');
 assert.equal(e.el('mapa-contenido').hidden,true);assert.equal(e.el('mapa-intro').hidden,false);
});
test('sin Leaflet ofrece continuar con coordenadas',()=>{
 const e=entorno(false);e.el('abrir-mapa').listeners.click();
 assert.match(e.el('mapa-intro').textContent,/latitud y longitud/);assert.equal(e.cuentas().tiles,0);
});
