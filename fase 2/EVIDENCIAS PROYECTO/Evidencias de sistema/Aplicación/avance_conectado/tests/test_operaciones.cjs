const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const source=fs.readFileSync(path.join(__dirname,'../public/operaciones.js'),'utf8');

function environment(initial='/operaciones',override={}){
  const nodes=new Map(),events={},calls=[],history=[];
  const node=()=>({hidden:false,value:'',textContent:'',innerHTML:'',dataset:{},attrs:{},
    setAttribute(k,v){this.attrs[k]=v;},removeAttribute(k){delete this.attrs[k];},
    focus(){this.focused=true;},reset(){},replaceChildren(){this.innerHTML='';},
    querySelector(selector){if(selector==='[data-list]')return this.innerHTML.includes('data-list')?back:null;return null;}});
  const back=node();
  for(const id of ['content','status','name','desk','access','login','mfa','back','exit','refresh','title','page-description','updated'])nodes.set(id,node());
  const nav=node(),user=node();
  const window={location:{pathname:initial},addEventListener(name,fn){events[name]=fn;},history:{state:null,
    pushState(state,_,url){this.state=state;window.location.pathname=url;history.push(url);},
    replaceState(state,_,url){this.state=state;window.location.pathname=url;}}};
  const document={getElementById(id){
    if(nodes.has(id))return nodes.get(id);
    if(nodes.get('content').innerHTML.includes(`id="${id}"`)){nodes.set(id,node());return nodes.get(id);}
    return null;
  },querySelector(selector){return selector==='nav'?nav:user;},querySelectorAll(){return [];}};
  const details={id_caso:7,folio:'RA-7',estado:'en_revision',patente:'ABCD12',zona:'Chillán',denuncia_estado:'pendiente',historial:[],evidencias:[],relato_para_revision:'Relato privado'};
  const fixtures={'/mi-perfil':{nombre_visible:'Operador',organizaciones:[1]},'/organizaciones':[{id_organizacion:1,nombre:'Institución',territorio_cobertura:'Chillán'}],
    '/casos':[], '/gestion/testigos':[], '/seguimiento/7':details,'/gestion/casos/7/aportes':[],
    '/gestion/casos/7/equipo':{responsable:'Ana',opciones:[],gestiones:[{accion:'nota',descripcion:'Antecedente privado del titular',creada_en:'2026-11-17T12:00:00Z'}],publicacion:null},
    '/gestion/aportes/pendientes':[],'/gestion/camaras':{camaras:[],nota:'Inventario autorizado'},'/sesiones/cerrar':null,...override};
  const context=vm.createContext({window,document,crypto:require('node:crypto').webcrypto,URL,Image:class{},FormData:class{constructor(form){return Object.entries(form.values||{});}},
    setTimeout(){return 1;},clearTimeout(){},MapaOperador:{cerrar(){}},
    async fetch(url,options){calls.push({url,...options});const f=fixtures[url];if(f===undefined)throw Error('Unexpected request: '+url);
      const value=typeof f==='function'?await f(options):f;
      return value?.status?{ok:false,...value,json:async()=>({detail:value.detail})}:{ok:true,status:value===null?204:200,json:async()=>value};}});
  vm.runInContext(source,context);
  return {run:code=>vm.runInContext(code,context),nodes,calls,events,window,history,fixtures};
}

test('routed sections, case deep links and invalid identifiers',()=>{
  const e=environment();
  for(const p of ['/operaciones','/operaciones/mapa','/operaciones/casos','/operaciones/avistamientos','/operaciones/testigos','/operaciones/fuentes','/operaciones/camaras','/operaciones/recursos'])assert.notEqual(e.run(`readRoute(${JSON.stringify(p)}).view`),'missing');
  assert.equal(e.run("readRoute('/operaciones/casos/7/').selected"),7);
  for(const p of ['/operaciones/casos/0','/operaciones/casos/-1','/operaciones/casos/7x','/operaciones/casos/9007199254740992','/operaciones/desconocida'])assert.equal(e.run(`readRoute(${JSON.stringify(p)}).view`),'missing');
});

test('dashboard counts actual open cases, orders attention, and escapes received data',()=>{
  const e=environment();
  const data=[{id_caso:1,folio:'RA-1',estado:'reportado',prioridad:'normal',aportes_pendientes:2,creado_en:'2026-11-01'},
    {id_caso:2,folio:'<script>bad</script>',estado:'en_gestion',prioridad:'alta',aportes_pendientes:1,creado_en:'2026-11-02'},
    {id_caso:3,folio:'CLOSED',estado:'cerrado',prioridad:'alta',aportes_pendientes:9,creado_en:'2026-11-03'}];
  const html=e.run(`dashboard(${JSON.stringify(data)},[{estado:'pendiente'}])`);
  assert.match(html,/Casos abiertos<\/span><strong>2/);
  assert.match(html,/Sin primera revisión<\/span><strong>1/);
  assert.match(html,/Aportes pendientes<\/span><strong>3/);
  assert.match(html,/Prioridad alta<\/span><strong>1/);
  assert.ok(html.indexOf('data-case="2"')<html.indexOf('data-case="1"'));
  assert.doesNotMatch(html,/<script>|data-case="3"/);
  assert.match(html,/&lt;script&gt;bad&lt;\/script&gt;/);
});

test('institutional login retains requested case and displays internal owner notes',async()=>{
  const e=environment('/operaciones/casos/7');await e.run("signin({token:'session'})");
  assert.equal(e.window.location.pathname,'/operaciones/casos/7');
  assert.match(e.nodes.get('content').innerHTML,/Relato privado|Antecedente privado del titular/);
  assert.match(e.nodes.get('content').innerHTML,/Antecedente privado del titular/);
  assert.doesNotMatch(e.nodes.get('content').innerHTML,/Asignar responsable/);
  assert.equal(e.calls.find(c=>c.url==='/seguimiento/7').headers.Authorization,'Bearer session');
});

test('navigation pushes a case URL and popstate restores the originating view',async()=>{
  const e=environment('/operaciones/avistamientos');await e.run("signin({token:'session'})");
  await e.run('abrirCaso(7)');assert.equal(e.history.at(-1),'/operaciones/casos/7');
  assert.equal(e.window.history.state.originView,'pending');
  e.window.location.pathname='/operaciones/avistamientos';e.window.history.state={};e.events.popstate();
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(e.run('view'),'pending');assert.equal(e.run('selected'),null);
  assert.match(e.nodes.get('content').innerHTML,/No hay avistamientos/);
});

test('citizen profile is denied before institutional data loads',async()=>{
  const e=environment('/operaciones/casos/7',{'/mi-perfil':{organizaciones:[]}});
  await assert.rejects(e.run("signin({token:'citizen'})"),/membresía institucional/);
  assert.equal(e.nodes.get('desk').hidden,true);
  assert.equal(e.run('token'),'');assert.ok(!e.calls.some(c=>c.url==='/seguimiento/7'));
});

test('a stale queue response cannot replace a newer routed view',async()=>{
  let release;const e=environment('/operaciones/camaras');await e.run("signin({token:'session'})");
  e.fixtures['/gestion/aportes/pendientes']=()=>new Promise(resolve=>{release=resolve;});
  const pending=e.run("navigate('pending')");await e.run("navigate('cameras')");
  release([{folio:'STALE',id_caso:7,zona:'Sector',recibido_en:'2026-11-17'}]);await pending;
  assert.equal(e.window.location.pathname,'/operaciones/camaras');
  assert.match(e.nodes.get('content').innerHTML,/Revisar un clip local/);assert.doesNotMatch(e.nodes.get('content').innerHTML,/STALE/);
});

test('load errors offer retry and session expiration clears private content',async()=>{
  const e=environment('/operaciones/camaras',{'/gestion/camaras':{status:503,detail:'Servicio temporalmente no disponible'}});
  await e.run("signin({token:'session'})");assert.match(e.nodes.get('content').innerHTML,/data-retry/);
  e.fixtures['/gestion/camaras']={status:401,detail:'Sesión vencida'};await e.run('load()');
  assert.equal(e.run('token'),'');assert.equal(e.nodes.get('content').innerHTML,'');assert.equal(e.nodes.get('desk').hidden,true);
});

test('resource editor honors server edit capability and excludes unsafe links',()=>{
  const e=environment();const r={id_recurso_apoyo:4,categoria:'orientacion',titulo:'Apoyo',descripcion:'Orientación oficial',territorio:'Chillán',canal:'Atención presencial',url_oficial:'javascript:alert(1)',responsable:'Ana',activo:true,vigente:true,puede_editar:false};
  let html=e.run(`resourceRoom([${JSON.stringify(r)}],[])`);
  assert.doesNotMatch(html,/javascript:|data-method="PUT"|data-method="DELETE"/);
  r.puede_editar=true;html=e.run(`resourceRoom([${JSON.stringify(r)}],[])`);
  assert.match(html,/data-method="PUT"/);assert.match(html,/data-method="DELETE"/);
});

test('resource edit submits PUT with typed availability, responsible and ISO dates',async()=>{
  const e=environment('/operaciones/recursos',{'/gestion/recursos-apoyo?limite=50&offset=0':[],
    '/gestion/recursos-apoyo/responsables':[],'/gestion/recursos-apoyo/4':null});
  await e.run("signin({token:'session'})");
  e.run(`content.onsubmit({preventDefault(){},submitter:{disabled:false},target:{
    dataset:{path:'/gestion/recursos-apoyo/4',method:'PUT',resource:'edit'},querySelectorAll(){return [];},
    values:{categoria:'orientacion',territorio:'Chillán',titulo:'Apoyo',descripcion:'Orientación oficial',canal:'Atención presencial',
      url_oficial:'',mantenido_por:'6',activo:'false',verificado_en:'2026-11-01T10:00:00',vence_en:'2026-12-01T10:00:00'}}})`);
  await new Promise(resolve=>setImmediate(resolve));
  const request=e.calls.find(c=>c.url==='/gestion/recursos-apoyo/4');
  assert.equal(request.method,'PUT');assert.equal(request.headers.Authorization,'Bearer session');
  const body=JSON.parse(request.body);assert.equal(body.activo,false);assert.equal(body.mantenido_por,6);
  assert.equal(body.url_oficial,null);assert.match(body.verificado_en,/Z$/);assert.match(body.vence_en,/Z$/);
  assert.equal(e.nodes.get('status').textContent,'Cambio guardado.');
});

test('deactivation submits DELETE without a JSON body and retains the resources route',async()=>{
  const e=environment('/operaciones/recursos',{'/gestion/recursos-apoyo?limite=50&offset=0':[],
    '/gestion/recursos-apoyo/responsables':[],'/gestion/recursos-apoyo/4':null});
  await e.run("signin({token:'session'})");
  e.run(`content.onsubmit({preventDefault(){},submitter:{disabled:false},target:{
    dataset:{path:'/gestion/recursos-apoyo/4',method:'DELETE'},querySelectorAll(){return [];},values:{}}})`);
  await new Promise(resolve=>setImmediate(resolve));
  const request=e.calls.find(c=>c.url==='/gestion/recursos-apoyo/4');
  assert.equal(request.method,'DELETE');assert.equal(request.body,undefined);
  assert.equal(e.window.location.pathname,'/operaciones/recursos');
});
