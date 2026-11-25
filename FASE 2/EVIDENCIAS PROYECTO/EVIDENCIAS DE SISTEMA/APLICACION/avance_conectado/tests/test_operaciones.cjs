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
  for(const id of ['content','status','name','membership','account-help','account-content','desk','access','login','mfa','back','exit','refresh','title','page-description','updated'])nodes.set(id,node());
  const nav=node(),user=node();
  const window={location:{pathname:initial},addEventListener(name,fn){events[name]=fn;},history:{state:null,
    pushState(state,_,url){this.state=state;window.location.pathname=url;history.push(url);},
    replaceState(state,_,url){this.state=state;window.location.pathname=url;}}};
  const document={getElementById(id){
    if(nodes.has(id))return nodes.get(id);
    if(nodes.get('content').innerHTML.includes(`id="${id}"`)){nodes.set(id,node());return nodes.get(id);}
    return null;
  },querySelector(selector){return selector==='nav'?nav:user;},querySelectorAll(){return [];}};
  const details={id_caso:7,folio:'RA-7',estado:'en_revision',patente:'ABCD12',zona:'Chillán',denuncia_estado:'pendiente',historial:[],evidencias:[],relato_para_revision:'Relato privado',revision_alerta:3,simulacion_disponible:false};
  const fixtures={'/mi-perfil':{nombre_visible:'Operador',organizaciones:[1]},'/organizaciones':[{id_organizacion:1,nombre:'Institución',territorio_cobertura:'Chillán'}],
    '/gestion/mi-acceso':{organizaciones:[{id_organizacion:1,nombre:'Institución',rol:'operador',puede_asignar:false}],administrador_global:false,permisos:['Consultar estadísticas del ámbito institucional'],asignacion:'Ser responsable de un caso no cambia el rol ni amplía el ámbito institucional.'},
    '/casos':[], '/gestion/testigos':[], '/seguimiento/7':details,'/gestion/casos/7/aportes':[],
    '/gestion/casos/7/equipo':{responsable:'Ana',opciones:[],gestiones:[{accion:'nota',descripcion:'Antecedente privado del titular',creada_en:'2026-11-17T12:00:00Z'}],publicacion:null},
    '/gestion/aportes/pendientes':[],'/gestion/camaras':{camaras:[],nota:'Inventario autorizado'},'/sesiones/cerrar':null,...override};
  const context=vm.createContext({window,document,crypto:require('node:crypto').webcrypto,URL,URLSearchParams,Image:class{},FormData:class{constructor(form){return Object.entries(form.values||{});}},
    setTimeout(){return 1;},clearTimeout(){},MapaOperador:{cerrar(){}},
    async fetch(url,options){calls.push({url,...options});const f=fixtures[url];if(f===undefined)throw Error('Unexpected request: '+url);
      const value=typeof f==='function'?await f(options):f;
      return value?.status?{ok:false,...value,json:async()=>({detail:value.detail})}:{ok:true,status:value===null?204:200,json:async()=>value};}});
  vm.runInContext(source,context);
  return {run:code=>vm.runInContext(code,context),nodes,calls,events,window,history,fixtures};
}

test('routed sections, case deep links and invalid identifiers',()=>{
  const e=environment();
  for(const p of ['/operaciones','/operaciones/estadisticas','/operaciones/mapa','/operaciones/casos','/operaciones/avistamientos','/operaciones/testigos','/operaciones/fuentes','/operaciones/camaras','/operaciones/recursos'])assert.notEqual(e.run(`readRoute(${JSON.stringify(p)}).view`),'missing');
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
  assert.match(e.nodes.get('content').innerHTML,/Registrar consulta manual/);
  assert.match(e.nodes.get('content').innerHTML,/name="captura_encargo"/);
  assert.doesNotMatch(e.nodes.get('content').innerHTML,/Mantener imagen actual|load-error/);
  assert.doesNotMatch(e.nodes.get('content').innerHTML,/Asignar responsable/);
  assert.equal(e.calls.find(c=>c.url==='/seguimiento/7').headers.Authorization,'Bearer session');
});

test('an active alert only offers accepted, authorised report photos in the manual review',async()=>{
  const e=environment('/operaciones/casos/7');
  Object.assign(e.fixtures['/seguimiento/7'],{alerta:{visible:true},evidencias:[
    {id_evidencia:101,estado_revision:'aceptada',autorizada_publicacion_en:'2026-11-25T12:00:00Z'},
    {id_evidencia:102,estado_revision:'aceptada',autorizada_publicacion_en:null},
    {id_evidencia:103,estado_revision:'pendiente',autorizada_publicacion_en:'2026-11-25T12:00:00Z'}
  ]});
  await e.run("signin({token:'session'})");
  const html=e.nodes.get('content').innerHTML;
  assert.match(html,/Registrar consulta manual/);
  assert.match(html,/Mantener imagen actual/);
  assert.match(html,/Foto del titular #101/);
  assert.doesNotMatch(html,/Foto del titular #10[23]|load-error/);
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

// Fixtures are isolated test data, never inserted into the application or database.
function analyticsFixture(){return {
  filtros:{desde:'2026-01-01',hasta:'2026-12-31',anio:2026,id_organizacion:null,zona:null,entorno:'operacion',zona_horaria:'America/Santiago',radio_m:300},
  internos:{total:3,reportes_total:4,duplicados_excluidos:1,recuperacion:{denominador:3,documentados:1,abiertos:2,cerrados_sin_recuperacion:0,porcentaje_cohorte:33.33},
    mensual:[{periodo:'2026-01',total:2},{periodo:'2026-02',total:1}],marcas:[{valor:'<script>marca</script>',total:3}],modelos:[{marca:'Marca',modelo:'Modelo',total:3}],
    tipos_vehiculo:[{valor:'automovil',total:3}],zonas:[{valor:'Zona de prueba',total:3}],estados:[{valor:'en_revision',total:2},{valor:'cerrado',total:1}],desenlaces:[{valor:'recuperado',total:1}]},
  territorial:{total:7,mensual:[{periodo:'2026-01',total:7}],zonas:[],tipos:[]},
  camaras:{radio_m:300,inventario:{total:2,disponibles:1,fuera_servicio:0,desconocidas:1,con_cobertura:1,verificadas:1},zonas:[{zona:'Zona de prueba',reportes:3,con_ubicacion:2,cerca_de_camara:1,en_cobertura_declarada:1,sin_camara_cercana:1}]},
  limites:['Fuente de prueba <img src=x onerror=alert(1)>']
};}

test('statistics deep link requests aggregates without loading raw cases and exposes accessible separate sources',async()=>{
  const e=environment('/operaciones/estadisticas');e.fixtures[e.run('statisticsPath()')]=analyticsFixture();
  await e.run("signin({token:'session'})");
  const html=e.nodes.get('content').innerHTML;
  assert.equal(e.nodes.get('title').textContent,'Estadísticas');
  assert.ok(e.calls.some(c=>c.url.startsWith('/gestion/estadisticas?')&&c.headers.Authorization==='Bearer session'));
  assert.ok(!e.calls.some(c=>c.url==='/casos'));
  assert.match(html,/Casos sin duplicados<\/span><strong>3/);
  assert.match(html,/4 reportes recibidos · 1 duplicados excluidos/);
  assert.match(html,/7 hechos territoriales/);
  assert.match(html,/no se suman/);assert.match(html,/sin adscripción a una organización/);
  assert.match(html,/<svg[^>]*role="img"[^>]*aria-labelledby=/);
  assert.match(html,/Ver datos mensuales en tabla/);assert.match(html,/<caption>Evolución mensual de reportes<\/caption>/);
  assert.match(html,/<th scope="col">Registros/);assert.match(html,/<th scope="row">2026-01/);
  assert.match(html,/&lt;script&gt;marca&lt;\/script&gt;/);assert.doesNotMatch(html,/<script>|<img src=x/);
  assert.match(html,/no confirma visibilidad/);assert.match(html,/Fuente de prueba &lt;img/);
});

test('statistics filters encode sector, use either dates or year, and submit GET only',async()=>{
  const e=environment('/operaciones/estadisticas');e.fixtures[e.run('statisticsPath()')]=analyticsFixture();
  await e.run("signin({token:'session'})");
  const custom='/gestion/estadisticas?desde=2026-01-02&hasta=2026-02-03&id_organizacion=1&zona=Estaci%C3%B3n+%26+Centro&entorno=prueba&radio_m=500';
  e.fixtures[custom]=analyticsFixture();
  e.run(`content.onsubmit({preventDefault(){},target:{dataset:{statistics:'true'},values:{periodo:'fechas',desde:'2026-01-02',hasta:'2026-02-03',id_organizacion:'1',zona:'  Estación & Centro  ',entorno:'prueba',radio_m:'500'}}})`);
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(e.run('statisticsPath()'),custom);
  const call=e.calls.find(c=>c.url===custom);assert.equal(call.method,'GET');assert.equal(call.body,undefined);
  assert.equal(e.nodes.get('statistics-dates').hidden,false);assert.equal(e.nodes.get('statistics-year').disabled,true);
  assert.equal(e.nodes.get('statistics-from').required,true);
  const before=e.calls.length;
  e.run(`content.onsubmit({preventDefault(){},target:{dataset:{statistics:'true'},values:{periodo:'fechas',desde:'2026-02-03',hasta:'2026-01-01'}}})`);
  assert.equal(e.calls.length,before);assert.match(e.nodes.get('status').textContent,/rango válido/);
  e.run("statisticsFilters.periodo='anio';statisticsFilters.anio='2025'");
  assert.match(e.run('statisticsPath()'),/anio=2025/);assert.doesNotMatch(e.run('statisticsPath()'),/desde=|hasta=/);
});

test('empty statistics retain filters, zero source counts and monthly tables without inventing a graph or recovery rate',()=>{
  const e=environment();const data={filtros:{},internos:{total:0,reportes_total:0,duplicados_excluidos:0,recuperacion:{abiertos:0,documentados:0,porcentaje_cohorte:null},mensual:[{periodo:'2026-01',total:0}]},territorial:{total:0,mensual:[]},limites:[]};
  const html=e.run(`statisticsRoom(${JSON.stringify(data)})`);
  assert.match(html,/Casos sin duplicados<\/span><strong>0/);assert.match(html,/Recuperación de la cohorte<\/span><strong>—/);
  assert.match(html,/0 hechos territoriales/);assert.match(html,/No hay reportes internos/);
  assert.doesNotMatch(html,/<polyline/);assert.match(html,/<th scope="row">2026-01/);
  assert.match(html,/no ofrece indicadores de cámaras/);assert.match(html,/data-statistics="true"/);
});

test('a stale analytics response cannot replace a newer route or repopulate a closed session',async()=>{
  const e=environment('/operaciones/camaras');await e.run("signin({token:'session'})");
  let release;e.fixtures[e.run('statisticsPath()')]=()=>new Promise(resolve=>{release=resolve;});
  const pending=e.run("navigate('statistics')");await e.run("navigate('cameras')");release(analyticsFixture());await pending;
  assert.equal(e.window.location.pathname,'/operaciones/camaras');assert.doesNotMatch(e.nodes.get('content').innerHTML,/statistics-internal/);
  const afterLogout=e.run("navigate('statistics')");e.run('reset()');release(analyticsFixture());await afterLogout;
  assert.equal(e.nodes.get('content').innerHTML,'');assert.equal(e.nodes.get('account-content').innerHTML,'');assert.equal(e.run('accountAccess'),null);
});

test('statistics errors retain filter controls and retry; expiration removes private identity and content',async()=>{
  const e=environment('/operaciones/estadisticas');const endpoint=e.run('statisticsPath()');
  e.fixtures[endpoint]={status:503,detail:'Estadísticas no disponibles'};await e.run("signin({token:'session'})");
  assert.match(e.nodes.get('content').innerHTML,/data-retry/);assert.match(e.nodes.get('content').innerHTML,/statistics-filters/);
  e.fixtures[endpoint]={status:401,detail:'Sesión vencida'};await e.run('load()');
  assert.equal(e.nodes.get('content').innerHTML,'');assert.equal(e.nodes.get('membership').innerHTML,'');assert.equal(e.nodes.get('account-help').open,false);
});

test('account help displays roles per organization, escapes data and distinguishes assignments from privileges',async()=>{
  const access={organizaciones:[{id_organizacion:1,nombre:'Institución <b>uno</b>',rol:'operador',puede_asignar:false},{id_organizacion:2,nombre:'Institución dos',rol:'supervisor',puede_asignar:true}],administrador_global:true,permisos:['Consultar <casos>'],asignacion:'Ser responsable de un caso no cambia el rol ni amplía el ámbito institucional.'};
  const e=environment('/operaciones/camaras',{'/gestion/mi-acceso':access});await e.run("signin({token:'session'})");
  const html=e.nodes.get('account-content').innerHTML;
  assert.match(html,/Operador · Sin permiso para asignar/);assert.match(html,/Supervisor · Puede asignar/);
  assert.match(html,/administrador global/);assert.match(html,/no cambia el rol/);
  assert.match(e.nodes.get('membership').innerHTML,/Institución &lt;b&gt;uno&lt;\/b&gt; · Operador/);
  assert.doesNotMatch(html,/<b>uno<\/b>|Consultar <casos>/);
  assert.equal(e.calls.find(c=>c.url==='/gestion/mi-acceso').headers.Authorization,'Bearer session');
});

test('institutional membership access failure blocks the desk before case data loads',async()=>{
  const e=environment('/operaciones/casos/7',{'/gestion/mi-acceso':{status:403,detail:'Sin membresía institucional vigente'}});
  await assert.rejects(e.run("signin({token:'session'})"),/Sin membresía institucional/);
  assert.equal(e.nodes.get('desk').hidden,true);assert.equal(e.nodes.get('account-content').innerHTML,'');assert.equal(e.run('token'),'');
  assert.ok(!e.calls.some(c=>c.url==='/seguimiento/7'));
});

test('assigned role and stale membership warning do not grant assignment controls',()=>{
  const e=environment();const c={id_caso:7,estado:'en_revision'};
  const team={responsable:'Persona asignada',responsable_rol:'operador',responsable_vigente:false,puede_asignar:false,opciones:[{id_membresia:2,nombre_visible:'Supervisor'}],gestiones:[]};
  const html=e.run(`equipoCaso(${JSON.stringify(c)},${JSON.stringify(team)})`);
  assert.match(html,/Persona asignada/);assert.match(html,/class="badge">Operador/);assert.match(html,/ya no está vigente/);
  assert.match(html,/no modifica el rol/);assert.doesNotMatch(html,/Asignar responsable/);
  team.puede_asignar=true;team.responsable_vigente=true;
  const supervisor=e.run(`equipoCaso(${JSON.stringify(c)},${JSON.stringify(team)})`);
  assert.match(supervisor,/Asignar responsable/);assert.doesNotMatch(supervisor,/ya no está vigente/);
});
