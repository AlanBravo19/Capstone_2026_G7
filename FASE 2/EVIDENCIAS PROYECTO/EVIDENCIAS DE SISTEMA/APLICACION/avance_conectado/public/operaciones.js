'use strict';
const el=id=>document.getElementById(id);
const content=el('content');
const h=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const names={dashboard:'Resumen operativo',statistics:'Estadísticas',map:'Mapa operativo',pending:'Avistamientos pendientes',cases:'Bandeja de casos',witness:'Avisos de testigos',sources:'Fuentes territoriales',cameras:'Cámaras autorizadas',resources:'Recursos de apoyo'};
const routes={dashboard:'/operaciones',statistics:'/operaciones/estadisticas',map:'/operaciones/mapa',cases:'/operaciones/casos',pending:'/operaciones/avistamientos',witness:'/operaciones/testigos',sources:'/operaciones/fuentes',cameras:'/operaciones/camaras',resources:'/operaciones/recursos'};
const descriptions={dashboard:'Pendientes y prioridades de tus organizaciones.',statistics:'Tendencias y distribución de registros reales, con su fuente y alcance.',map:'Reportes y avistamientos aceptados de casos abiertos.',cases:'Consulta, filtra y gestiona los reportes recibidos.',pending:'Aportes ciudadanos que requieren una decisión.',witness:'Revisa los avisos recibidos y su posible relación con un caso.',sources:'Registra y valida antecedentes territoriales documentados.',cameras:'Consulta el inventario y revisa videos autorizados.',resources:'Mantén los contactos y orientaciones de apoyo a la ciudadanía.'};
const states={reportado:'Reportado',en_revision:'En revisión',en_gestion:'En gestión',cerrado:'Cerrado'};
const date=value=>value?new Date(value).toLocaleString('es-CL',{dateStyle:'short',timeStyle:'short'}):'—';
const badge=value=>`<span class="badge badge-${h(String(value).replace(/[^a-z_]/g,''))}">${h(states[value]||String(value).replaceAll('_',' '))}</span>`;
const empty=message=>`<p class="empty">${h(message)}</p>`;
const motives='<label>Motivo de la decisión<textarea name="motivo" minlength="10" maxlength="500" required></textarea></label>';
const selector=(name,label,values)=>`<label>${label}<select name="${name}">${Object.entries(values).map(([k,v])=>`<option value="${h(k)}">${h(v)}</option>`).join('')}</select></label>`;
const action=(title,path,fields,submit=title)=>`<details class="record"><summary>${h(title)}</summary><form data-path="${h(path)}">${fields}<button class="primary">${h(submit)}</button></form></details>`;
let token='', challenge='', view='cases', selected=null, generation=0, records=[], orgs=[], query='', filter='', priority='';
let photos=[], noticeTimer;
let mapOrg=null,originView='cases',resourceOffset=0;
let accountAccess=null;
const defaultStatisticsFilters=()=>({periodo:'anio',anio:new Intl.DateTimeFormat('en',{timeZone:'America/Santiago',year:'numeric'}).format(new Date()),desde:'',hasta:'',id_organizacion:'',zona:'',entorno:'operacion',radio_m:'300'});
let statisticsFilters=defaultStatisticsFilters();
const roleName=role=>({operador:'Operador',supervisor:'Supervisor'}[role]||String(role||'Rol no informado').replaceAll('_',' '));
function showAccount(access){
  accountAccess=access;
  el('membership').innerHTML=access.organizaciones.map(o=>`<span class="membership-badge">${h(o.nombre)} · ${h(roleName(o.rol))}</span>`).join('');
  el('account-content').innerHTML=`<h2>Tu acceso institucional</h2><ul class="membership-list">${access.organizaciones.map(o=>`<li><strong>${h(o.nombre)}</strong><span>${h(roleName(o.rol))} · ${o.puede_asignar?'Puede asignar responsables':'Sin permiso para asignar responsables'}</span></li>`).join('')}</ul>${access.administrador_global?'<p>Tu cuenta también tiene el rol de administrador global. El acceso a casos depende de tu membresía en cada organización.</p>':''}<h3>Permisos de esta cuenta</h3><ul>${(access.permisos||[]).map(p=>`<li>${h(p)}</li>`).join('')}</ul><p class="consent-note">${h(access.asignacion||'Ser responsable de un caso no cambia el rol ni amplía el ámbito institucional.')}</p><p>Solo un supervisor puede asignar responsables en su organización. Para cambiar tu rol, contacta a quien administra el acceso institucional.</p>`;
}
function readRoute(path=window.location.pathname){
  path=path.replace(/\/+$/,'')||'/';
  if(path==='/')return {view:'dashboard',selected:null};
  const match=path.match(/^\/operaciones\/casos\/([1-9]\d*)$/);
  if(match&&Number.isSafeInteger(Number(match[1])))return {view:'cases',selected:Number(match[1])};
  const found=Object.keys(routes).find(key=>routes[key]===path);
  return {view:found||'missing',selected:null};
}
function routePath(next,id=null){return id?routes.cases+'/'+id:routes[next];}
function navigate(next,id=null,replace=false){
  if(!routes[next])return;
  const path=routePath(next,id);
  const from=id?(selected?originView:view):'cases';
  if(window.location.pathname!==path){
    window.history[replace?'replaceState':'pushState']({originView:routes[from]?from:'cases'},'',path);
  }
  originView=routes[from]?from:'cases';view=next;selected=id;
  return token?load(true):undefined;
}
window.addEventListener('popstate',()=>{
  ({view,selected}=readRoute());originView=window.history.state?.originView||'cases';
  if(!routes[originView])originView='cases';
  if(token)load(true);
});
function notify(message){el('status').textContent=message;clearTimeout(noticeTimer);noticeTimer=setTimeout(()=>el('status').textContent='',9500);}
function clearPhotos(){photos.forEach(URL.revokeObjectURL);photos=[];}
function reset(){
  MapaOperador.cerrar();mapOrg=null;originView='cases';resourceOffset=0;
  generation++;token=challenge='';orgs=[];records=[];selected=null;query=filter=priority='';dashboard.bind=null;clearPhotos();
  accountAccess=null;statisticsFilters=defaultStatisticsFilters();el('membership').replaceChildren();el('account-content').replaceChildren();el('account-help').open=false;
  content.replaceChildren();content.setAttribute('aria-busy','false');el('name').textContent='';el('desk').hidden=true;document.querySelector('.user').hidden=true;
  el('access').hidden=false;el('mfa').hidden=true;el('login').hidden=false;el('login').reset();el('mfa').reset();
}
async function api(path,body,binary=false,method=body===undefined?'GET':'POST'){
  const session=token;const headers={};
  if(session)headers.Authorization='Bearer '+session;
  if(body!==undefined)headers['Content-Type']='application/json';
  const response=await fetch(path,{method,headers,body:body===undefined?undefined:JSON.stringify(body),cache:'no-store'});
  if(!response.ok){
    if(response.status===401&&session&&session===token)reset();
    const problem=await response.json().catch(()=>({}));
    throw Error(Array.isArray(problem.detail)?problem.detail.map(e=>e.msg).join('. '):problem.detail||'Hubo un problema al consultar el servicio.');
  }
  if(response.status===204)return null;
  return binary?response.blob():response.json();
}
async function signin(result){
  if(result.requiere_mfa){challenge=result.id_desafio;el('login').hidden=true;el('mfa').hidden=false;el('mfa').elements.codigo.focus();return;}
  token=result.token;
  try{
    const [profile,access]=await Promise.all([api('/mi-perfil'),api('/gestion/mi-acceso')]);
    if(!profile.organizaciones?.length)throw Error('Tu cuenta tiene acceso ciudadano. Para operar se requiere una membresía institucional vigente.');
    const available=await api('/organizaciones');orgs=available.filter(o=>profile.organizaciones.includes(o.id_organizacion));
    showAccount(access);
    el('name').textContent=profile.nombre_visible;el('access').hidden=true;el('desk').hidden=false;document.querySelector('.user').hidden=false;
    ({view,selected}=readRoute());originView=window.history.state?.originView||'cases';
    if(!routes[originView])originView='cases';
    if(window.location.pathname==='/')window.history.replaceState({},'',routes.dashboard);
    mapOrg=orgs[0]?.id_organizacion;await load();
  }catch(err){try{if(token)await api('/sesiones/cerrar',{});}finally{reset();}throw err;}
}
async function handle(button,work){button.disabled=true;try{await work();}catch(err){notify(err.message);}finally{button.disabled=false;}}
for(const id of ['login','mfa'])el(id).onsubmit=e=>{
  e.preventDefault();const f=e.currentTarget.elements;
  handle(e.submitter,async()=>{
    if(id==='login'){const result=await api('/institucional/sesiones',{correo:f.correo.value.trim(),clave:f.clave.value});f.clave.value='';await signin(result);}
    else{const result=await api('/institucional/sesiones/mfa',{id_desafio:challenge,codigo:f.codigo.value.trim()});f.codigo.value='';await signin(result);}
  });
};
el('back').onclick=reset;
el('exit').onclick=()=>handle(el('exit'),async()=>{try{await api('/sesiones/cerrar',{});}finally{reset();}});
document.querySelector('nav').onclick=e=>{const b=e.target.closest('[data-view]');if(b){e.preventDefault();navigate(b.dataset.view);}};
function abrirCaso(cid){const id=Number(cid);if(Number.isSafeInteger(id)&&id>0)return navigate('cases',id);}
el('refresh').onclick=()=>load();

function dashboard(data,witnesses){
  const open=data.filter(c=>c.estado!=='cerrado');
  const reported=open.filter(c=>c.estado==='reportado');
  const pending=open.reduce((n,c)=>n+Number(c.aportes_pendientes||0),0);
  const high=open.filter(c=>c.prioridad==='alta');
  const waiting=witnesses.filter(a=>a.estado==='pendiente').length;
  const stats=[['Casos abiertos',open.length,'cases','En revisión y seguimiento','open'],['Sin primera revisión',reported.length,'cases','Reportes en estado reportado','reported'],['Aportes pendientes',pending,'pending','Avistamientos por evaluar',''],['Prioridad alta',high.length,'cases','Casos abiertos de atención prioritaria','high']];
  const attention=[...open].sort((a,b)=>(b.prioridad==='alta')-(a.prioridad==='alta')||Number(b.aportes_pendientes||0)-Number(a.aportes_pendientes||0)||new Date(a.creado_en)-new Date(b.creado_en)).slice(0,6);
  const attentionRows=items=>items.map(c=>`<tr><td><button class="text-button" data-case="${Number(c.id_caso)}">${h(c.folio)}</button><span class="cell-note">${h(orgs.find(o=>o.id_organizacion===c.id_organizacion)?.nombre||'Organización autorizada')}</span></td><td>${badge(c.estado)}</td><td>${badge(c.prioridad)}</td><td>${Number(c.aportes_pendientes||0)}</td></tr>`).join('');
  const attentionTable=items=>items.length?`<div class="table-wrap"><table><caption class="sr-only">Casos abiertos que requieren atención</caption><thead><tr><th>Folio / organización</th><th>Estado</th><th>Prioridad</th><th>Aportes</th></tr></thead><tbody>${attentionRows(items)}</tbody></table></div>`:empty('No hay casos abiertos que coincidan con la búsqueda.');
  dashboard.bind=()=>{el('geo-filtro').oninput=e=>{const q=e.target.value.trim().toLowerCase();el('attention-results').innerHTML=attentionTable(q?open.filter(c=>c.folio.toLowerCase().includes(q)):attention);};};
  return `<section class="overview-banner"><div><small>Tu mesa de trabajo</small><h2>Actividad de tu organización</h2><p>${h(orgs.map(o=>o.nombre).join(' · '))}</p></div><button data-go="map">Abrir mapa operativo →</button></section>
    <div class="stats dashboard-stats">${stats.map(([label,n,target,caption,scope])=>`<button class="stat" data-go="${target}" data-scope="${scope}"><span>${label}</span><strong>${n}</strong><span class="stat-caption">${caption}</span></button>`).join('')}</div>
    <div class="dashboard-grid"><section class="card"><div class="row"><h2>Casos que requieren atención</h2><button data-go="cases">Ver bandeja →</button></div><p class="muted">Hasta seis casos: primero prioridad alta, luego aportes pendientes y mayor antigüedad.</p><label class="dashboard-search">Buscar un caso abierto por folio<input id="geo-filtro" type="search" placeholder="Ej. RA-20261117"></label><div id="attention-results">${attentionTable(attention)}</div></section>
    <section class="card"><h2>Pendientes de revisión</h2><button class="task-link" data-go="pending"><span>Avistamientos por evaluar</span><strong>${pending} →</strong></button><button class="task-link" data-go="witness"><span>Avisos de testigos</span><strong>${waiting}${witnesses.length===200?'+':''} →</strong></button><p class="muted">Los avisos se calculan sobre los últimos 200 registros disponibles.</p><h3>Distribución de casos</h3><ul class="state-summary">${Object.entries(states).map(([state,label])=>{const n=data.filter(c=>c.estado===state).length;return `<li><span>${label}</span><strong>${n}</strong><meter min="0" max="${Math.max(data.length,1)}" value="${n}" aria-label="${label}">${n}</meter></li>`;}).join('')}</ul><p class="muted">${data.length} casos en tus organizaciones autorizadas.</p></section></div>`;
}

function caseRows(){
  const visible=records.filter(c=>(!filter||(filter==='open'?c.estado!=='cerrado':c.estado===filter))&&(!priority||c.prioridad===priority)&&c.folio.toLowerCase().includes(query.toLowerCase().trim()));
  const rows=visible.map(c=>`<tr><td><strong>${h(c.folio)}</strong></td><td>${badge(c.estado)}</td><td>${badge(c.prioridad)}</td><td>${h(c.aportes_pendientes)}</td><td>${h(date(c.creado_en))}</td><td><button data-case="${Number(c.id_caso)}" aria-label="Abrir ficha ${h(c.folio)}">Abrir ficha →</button></td></tr>`).join('');
  return rows?`<div class="table-wrap"><table><thead><tr><th>Folio</th><th>Estado</th><th>Prioridad</th><th>Aportes pendientes</th><th>Ingreso</th><th></th></tr></thead><tbody>${rows}</tbody></table></div>`:empty(records.length?'Ningún caso coincide con la búsqueda.':'Tu organización aún no ha recibido reportes.');
}
function queue(data){
  records=data;
  const stats=[['Casos abiertos',data.filter(c=>c.estado!=='cerrado').length],['Por revisar',data.filter(c=>c.estado==='reportado').length],['Aportes pendientes',data.reduce((n,c)=>n+c.aportes_pendientes,0)]];
  return `<div class="stats">${stats.map(([label,n])=>`<div class="stat"><span>${label}</span><strong>${n}</strong></div>`).join('')}</div>
    <section class="card"><h2>Reportes recibidos</h2><div class="filters"><label>Buscar folio<input id="search" type="search" value="${h(query)}"></label>${selector('estado','Filtrar por estado',{'':'Todos los estados',open:'Solo abiertos',...states})}${selector('prioridad','Prioridad',{'':'Todas',alta:'Alta',normal:'Normal',baja:'Baja'})}</div><div id="results">${caseRows()}</div></section>`;
}
function publicPhotoField(c,current=null){
  // Seguimiento only exposes initial-report evidence from this case.
  const eligible=(c.evidencias||[]).filter(e=>e.estado_revision==='aceptada'&&e.autorizada_publicacion_en!=null);
  return '<label>Foto pública del vehículo<select name="id_foto_vehiculo"><option value="">Sin foto real · imagen de referencia</option>'+eligible.map(e=>`<option value="${Number(e.id_evidencia)}"${Number(current)===Number(e.id_evidencia)?' selected':''}>Foto del titular #${Number(e.id_evidencia)}</option>`).join('')+'</select></label><p class="consent-note">Requiere autorización explícita del titular y una foto del reporte aceptada por el operador. Las fotos de avistamientos permanecen privadas.</p>';
}
function detail(c,contributions,equipo){
  const base=`/gestion/casos/${Number(c.id_caso)}`;const open=c.estado!=='cerrado';
  const header=`<button class="back" data-list>← Volver a la bandeja</button><section class="card case-summary"><div class="row"><h2>${h(c.folio)}</h2>${badge(c.estado)}</div><dl class="case-facts"><div><dt>Patente</dt><dd>${h(c.patente)}</dd></div><div><dt>Sector</dt><dd>${h(c.zona)}</dd></div><div><dt>Fecha del hecho</dt><dd>${h(date(c.fecha_hecho))}</dd></div><div><dt>Denuncia declarada</dt><dd>${h(c.denuncia_estado.replaceAll('_',' '))}</dd></div></dl><p class="consent-note">${h(c.estado_colaboracion||(c.colaboracion_consentida_en?'Colaboración autorizada por el afectado':'Pendiente de consentimiento del afectado'))}</p>`;
  const statement='<h3>Relato recibido</h3><p>'+h(c.relato_para_revision || 'Sin relato disponible.')+'</p>';
  const management=open?action('Cambiar estado',base+'/revision',selector('estado','Nuevo estado',{en_revision:'En revisión',en_gestion:'En gestión'})+motives,'Guardar cambio')+
    action('Asignar prioridad',base+'/prioridad',selector('prioridad','Prioridad',{normal:'Normal',alta:'Alta',baja:'Baja'})+motives,'Guardar prioridad')+
    (c.colaboracion_consentida_en&&c.estado!=='reportado'&&!equipo.publicacion?action('Publicar solicitud de colaboración',base+'/publicacion','<label>Sector público<input name="zona" required minlength="3" maxlength="200"></label><label>Texto para la ciudadanía<textarea name="texto" required minlength="15" maxlength="1500"></textarea></label>'+publicPhotoField(c)+motives):'')+
    (equipo.publicacion?'<p>Solicitud vigente hasta '+h(date(equipo.publicacion.vence_en))+'</p>'+action('Renovar solicitud',base+'/renovacion','<input type="hidden" name="id_solicitud_colaboracion" value="'+Number(equipo.publicacion.id_solicitud_colaboracion)+'">'+numberField('horas','Nuevo plazo contado desde ahora (horas)',1,72)+motives)+action('Retirar solicitud de colaboración',base+'/retirar',motives):'')+
    action('Notificar al afectado',base+'/mensaje','<input type="hidden" name="clave_envio" value="'+crypto.randomUUID()+'"><label>Mensaje para su bandeja privada<textarea name="mensaje" required minlength="10" maxlength="500"></textarea></label>','Enviar notificación')+
    action('Cerrar caso',base+'/cerrar',selector('motivo_cierre','Resultado',{recuperado:'Recuperado',duplicado:'Duplicado',informacion_insuficiente:'Información insuficiente',otro:'Otro'})+'<label>ID de evidencia aceptada (si fue recuperado)<input type="number" min="1" name="id_evidencia"></label><label>ID del caso principal (si fue duplicado)<input type="number" min="1" name="id_caso_principal"></label>'+motives):'';
  const sightings=contributions.map(a=>`<div class="record"><strong>${h(a.zona)}</strong> ${badge(a.estado_revision)}<p>${h(a.descripcion)}</p><p class="muted">${h(date(a.observado_en))}</p>${(a.fotos||[]).map(id=>`<button data-photo="${Number(id)}">Ver foto del avistamiento #${Number(id)}</button>`).join('')}${open?action('Evaluar aporte',`/gestion/aportes/${Number(a.id_avistamiento)}/revision`,selector('decision','Decisión',{aceptado:'Aceptar',requiere_aclaracion:'Pedir aclaración',rechazado:'Rechazar'})+motives+'<label>Resumen que podrá ver el afectado si se acepta<textarea name="resumen" maxlength="500"></textarea></label>'):''}</div>`).join('');
  const evidence=(c.evidencias||[]).map(e=>`<div class="record"><button data-photo="${Number(e.id_evidencia)}">Ver foto #${Number(e.id_evidencia)}</button> ${badge(e.estado_revision)}<p class="consent-note">${e.autorizada_publicacion_en!=null?'Foto pública autorizada por el titular · '+h(date(e.autorizada_publicacion_en)):'Sin autorización del titular para publicar esta foto'}</p>${open?action('Revisar evidencia',`/gestion/evidencias/${Number(e.id_evidencia)}/revision`,selector('decision','Decisión',{aceptada:'Aceptar',rechazada:'Rechazar'})+motives):''}</div>`).join('');
  return header+statement+management+"</section>"+equipoCaso(c,equipo)+`<section class="card"><h2>Avistamientos</h2>${sightings||empty('Todavía no hay aportes para este caso.')}</section><section class="card"><h2>Evidencias privadas</h2>${evidence||empty('Sin fotos adjuntas.')}</section><section class="card"><h2>Historial compartido con el afectado</h2>${c.historial.map(x=>`<div class="record"><strong>${h(date(x.creada_en))}</strong><p>${h(x.descripcion)}</p></div>`).join('')||empty('Todavía no hay novedades en el seguimiento.')}</section>`;
}
function numberField(key,label,min,max,step='1'){return `<label>${label}<input type="number" required name="${key}" min="${min}" max="${max}" step="${step}"></label>`;}
function sources(items){
  const entry=action('Registrar una fuente','/gestion/antecedentes',selector('id_organizacion','Organización',Object.fromEntries(orgs.map(o=>[o.id_organizacion,o.nombre])))+
    '<label>Medio o institución<input name="nombre_fuente" minlength="2" required></label><label>Enlace original HTTPS<input type="url" pattern="https://.+" name="url_fuente" required></label><label>Título<input name="titulo" minlength="8" required></label><label>Resumen propio<textarea name="resumen" minlength="20" maxlength="700" required></textarea></label><label>Sector o comuna<input name="zona" minlength="3" required></label><label>Fecha de publicación<input name="fecha_publicacion" type="date" required></label>'+selector('tipo','Tipo',{portonazo:'Portonazo',encerrona:'Encerrona',robo_vehiculo:'Robo vehicular',otro:'Otro'}));
  return `<section class="card">${entry}</section>`+items.map(s=>{
    const path=`/gestion/antecedentes/${encodeURIComponent(s.id_antecedente)}/revision`;
    const reason='<label>Fundamento de la revisión<textarea name="motivo" minlength="15" maxlength="1000" required></textarea></label>';
    return `<article class="card">${badge(s.estado)}<h2>${h(s.titulo)}</h2><p>${h(s.resumen)}</p><p>${h(s.zona)} · ${h(s.fecha_publicacion)} · ${h(s.nombre_fuente)}</p>${/^https:\/\//i.test(s.url_fuente)?`<a href="${h(s.url_fuente)}" target="_blank" rel="noopener noreferrer">Leer fuente original ↗</a>`:''}
    ${action('Validar sector y activar aviso',path,'<input type="hidden" name="decision" value="validado"><div class="form-grid">'+numberField('latitud','Latitud del sector',-90,90,'any')+numberField('longitud','Longitud del sector',-180,180,'any')+numberField('precision_m','Incertidumbre en metros',100,10000)+numberField('radio_m','Radio del aviso en metros',100,15000)+numberField('dias_vigencia','Vigencia en días',1,90)+'</div>'+reason)}
    ${action('Descartar fuente',path,'<input type="hidden" name="decision" value="descartado">'+reason)}</article>`;
  }).join('')+(items.length?'':empty('Aún no hay fuentes registradas.'));
}

function statisticsPath(){
  const f=statisticsFilters,params=new URLSearchParams();
  if(f.periodo==='fechas'){params.set('desde',f.desde);params.set('hasta',f.hasta);}
  else params.set('anio',f.anio);
  for(const key of ['id_organizacion','zona','entorno','radio_m'])if(f[key])params.set(key,String(f[key]).trim());
  return '/gestion/estadisticas?'+params;
}
function statisticsForm(){
  const f=statisticsFilters;
  const options=(values,current)=>Object.entries(values).map(([value,label])=>`<option value="${h(value)}"${String(current)===String(value)?' selected':''}>${h(label)}</option>`).join('');
  return `<section class="card statistics-filter-card" aria-labelledby="statistics-filter-title"><h2 id="statistics-filter-title">Explorar un período</h2><form id="statistics-filters" data-statistics="true"><div class="statistics-filters">
    <label>Período<select id="statistics-period" name="periodo">${options({anio:'Año completo',fechas:'Rango de fechas'},f.periodo)}</select></label>
    <label id="statistics-year-field">Año<input id="statistics-year" name="anio" type="number" step="1" min="1900" max="2100" value="${h(f.anio)}" required></label>
    <div id="statistics-dates" class="statistics-dates" hidden><label>Desde<input id="statistics-from" name="desde" type="date" value="${h(f.desde)}"></label><label>Hasta (inclusive)<input id="statistics-to" name="hasta" type="date" value="${h(f.hasta)}"></label></div>
    <label>Organización<select name="id_organizacion">${options({'':'Todas mis organizaciones',...Object.fromEntries(orgs.map(o=>[o.id_organizacion,o.nombre]))},f.id_organizacion)}</select></label>
    <label>Sector o zona exacta<input name="zona" type="search" maxlength="200" placeholder="Todos los sectores" value="${h(f.zona)}" aria-describedby="statistics-sector-help"></label>
    <label>Entorno de los registros<select name="entorno">${options({operacion:'Operación',prueba:'Prueba'},f.entorno)}</select></label>
    <label>Proximidad a cámaras<select name="radio_m">${options({100:'100 m',300:'300 m',500:'500 m',1000:'1.000 m',2000:'2.000 m'},f.radio_m)}</select></label>
    </div><p id="statistics-sector-help" class="muted">El sector coincide por nombre completo, sin distinguir mayúsculas ni tildes. Rango personalizado: máximo 366 días.</p><div class="statistics-filter-actions"><button class="primary">Aplicar filtros</button><button type="button" data-statistics-reset>Restablecer</button><a href="#statistics-methodology">Cómo se calculan</a></div></form></section>`;
}
function bindStatisticsFilters(){
  const period=el('statistics-period');if(!period)return;
  period.value=statisticsFilters.periodo;
  const toggle=()=>{
    const custom=period.value==='fechas';
    el('statistics-year-field').hidden=custom;el('statistics-year').disabled=custom;el('statistics-year').required=!custom;
    el('statistics-dates').hidden=!custom;
    for(const id of ['statistics-from','statistics-to']){el(id).disabled=!custom;el(id).required=custom;}
  };
  period.onchange=toggle;toggle();
}
const statisticNumber=value=>Number.isFinite(Number(value))&&value!==null&&value!==undefined?Number(value).toLocaleString('es-CL'):'—';
const statisticRows=items=>(Array.isArray(items)?items:[]).filter(row=>Number.isFinite(Number(row.total))&&Number(row.total)>=0);
const statisticLabel=value=>({sin_dato:'Sin dato',sin_desenlace:'Sin desenlace registrado',sin_cierre:'Sin cierre registrado',recuperado:'Recuperado',duplicado:'Duplicado',informacion_insuficiente:'Información insuficiente',otro:'Otro',...states}[value]||String(value||'Sin dato').replaceAll('_',' '));
function statisticsTable(rows,label,heading='Categoría',bars=false){
  const max=Math.max(1,...rows.map(row=>Number(row.total)));
  return `<div class="table-wrap"><table class="statistics-table"><caption>${h(label)}</caption><thead><tr><th scope="col">${h(heading)}</th>${bars?'<th scope="col" class="statistics-bar-heading">Comparación</th>':''}<th scope="col">Registros</th></tr></thead><tbody>${rows.map(row=>`<tr><th scope="row">${h(row.label)}</th>${bars?`<td><meter aria-hidden="true" min="0" max="${max}" value="${Number(row.total)}">${Number(row.total)}</meter></td>`:''}<td class="statistics-count">${statisticNumber(row.total)}</td></tr>`).join('')}</tbody></table></div>`;
}
function statisticsBreakdown(title,items,label=row=>statisticLabel(row.valor),heading='Categoría'){
  const rows=statisticRows(items).map(row=>({label:label(row),total:Number(row.total)})).sort((a,b)=>b.total-a.total||a.label.localeCompare(b.label,'es'));
  return `<section class="card statistics-breakdown"><h3>${h(title)}</h3>${rows.some(row=>row.total>0)?statisticsTable(rows.slice(0,8),title,heading,true)+(rows.length>8?`<details class="statistics-data"><summary>Ver las ${rows.length} categorías en tabla</summary>${statisticsTable(rows,title+' · todas las categorías',heading)}</details>`:''):empty('Sin registros para esta distribución.')}</section>`;
}
function statisticsTrend(id,title,items,kind){
  const rows=statisticRows(items).map(row=>({label:String(row.periodo),total:Number(row.total)}));
  const max=Math.max(1,...rows.map(row=>row.total)),width=660,left=56,baseline=154,height=120;
  const x=i=>left+(rows.length===1?width/2:i*width/(rows.length-1));
  const y=n=>baseline-n/max*height;
  const points=rows.map((row,i)=>`${x(i).toFixed(2)},${y(row.total).toFixed(2)}`).join(' ');
  const labels=rows.map((row,i)=>i===0||i===rows.length-1||i%Math.max(1,Math.ceil(rows.length/6))===0?`<text x="${x(i).toFixed(2)}" y="182" text-anchor="middle">${h(row.label)}</text>`:'').join('');
  const graph=rows.some(row=>row.total>0)?`<figure class="statistics-trend"><svg viewBox="0 0 760 200" role="img" aria-labelledby="${id}-chart-title ${id}-chart-desc"><title id="${id}-chart-title">${h(title)}</title><desc id="${id}-chart-desc">${h(kind)} por mes. Cifras exactas disponibles en la tabla de datos.</desc><path class="chart-grid" d="M${left} 34H716 M${left} ${baseline}H716"/><text x="44" y="38" text-anchor="end">${statisticNumber(max)}</text><text x="44" y="158" text-anchor="end">0</text><polyline class="chart-line" points="${points}"/>${rows.map((row,i)=>`<circle class="chart-point" cx="${x(i).toFixed(2)}" cy="${y(row.total).toFixed(2)}" r="3.5"/>`).join('')}${labels}</svg><figcaption>${h(kind)} por mes · número de registros</figcaption></figure>`:empty('No hay '+kind.toLowerCase()+' en el período y ámbito seleccionados.');
  return `<section class="card statistics-monthly"><h3>${h(title)}</h3>${graph}${rows.length?`<details class="statistics-data"><summary>Ver datos mensuales en tabla</summary>${statisticsTable(rows,title,'Mes')}</details>`:''}</section>`;
}
function statisticsMetric(label,value,caption){return `<div class="stat"><span>${h(label)}</span><strong>${h(value)}</strong><span class="stat-caption">${h(caption)}</span></div>`;}
function statisticsCameras(cameras){
  if(!cameras)return `<section class="card"><h2>Proximidad a cámaras</h2>${empty('El servicio no ofrece indicadores de cámaras para esta consulta.')}</section>`;
  const inventory=cameras.inventario||{},zones=Array.isArray(cameras.zonas)?cameras.zonas:[];
  return `<section class="card statistics-cameras"><div class="row"><div><small>Inventario institucional autorizado</small><h2>Proximidad y cobertura declarada</h2></div><span class="badge">Radio: ${statisticNumber(cameras.radio_m)} m</span></div><p class="muted">El inventario describe su estado actual. La proximidad usa las ubicaciones de los reportes y las cámaras disponibles; no confirma visibilidad, grabaciones ni cobertura efectiva.</p><dl class="camera-inventory">${[['Cámaras inventariadas','total'],['Disponibles','disponibles'],['Fuera de servicio','fuera_servicio'],['Estado desconocido','desconocidas'],['Con cobertura declarada','con_cobertura'],['Verificadas','verificadas']].map(([label,key])=>`<div><dt>${label}</dt><dd>${statisticNumber(inventory[key])}</dd></div>`).join('')}</dl>${zones.length?`<div class="table-wrap"><table><caption>Reportes internos del período y su proximidad a cámaras autorizadas</caption><thead><tr>${['Zona','Reportes','Con ubicación','Con cámara cercana','En cobertura declarada','Sin cámara cercana'].map(label=>`<th scope="col">${label}</th>`).join('')}</tr></thead><tbody>${zones.map(z=>`<tr><th scope="row">${h(z.zona||'Sin zona')}</th>${['reportes','con_ubicacion','cerca_de_camara','en_cobertura_declarada','sin_camara_cercana'].map(key=>`<td>${statisticNumber(z[key])}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`:empty('No hay reportes con los que calcular la proximidad en este ámbito.')}<p class="muted">Los indicadores de proximidad y cobertura pueden coincidir; no se suman. Los reportes sin ubicación no permiten evaluar distancia. Estos datos no determinan dónde instalar cámaras.</p></section>`;
}
function statisticsRoom(data){
  const internal=data.internos||{},territorial=data.territorial||{},recovery=internal.recuperacion||{},f=data.filtros||{};
  const orgLabel=f.id_organizacion?orgs.find(o=>Number(o.id_organizacion)===Number(f.id_organizacion))?.nombre||'Organización seleccionada':'Todas tus organizaciones autorizadas';
  const days=['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
  const temporal=(prefix,d)=>`<details class="card statistics-temporal"><summary>Distribución diaria y por horario · ${h(prefix)}</summary><p class="muted">Recuentos del período; los horarios sin información no se imputan.</p><div class="statistics-grid">${statisticsBreakdown('Día de la semana',d.dias_semana,row=>days[row.dia]||'Sin dato','Día')}${statisticsBreakdown('Hora del hecho',d.horas,row=>String(row.hora).padStart(2,'0')+':00','Hora')}</div>${statisticRows(d.diaria).length?statisticsTable(statisticRows(d.diaria).map(row=>({label:row.periodo,total:row.total})),'Recuento por día · '+prefix,'Fecha'):empty('No hay desglose diario disponible.')}</details>`;
  return statisticsForm()+`<section class="statistics-scope" aria-label="Ámbito de los resultados"><strong>${h(f.desde||'—')} — ${h(f.hasta||'—')}</strong><span>${h(orgLabel)}${f.zona?' · '+h(f.zona):' · Todos los sectores'}</span><span class="badge">${f.entorno==='prueba'?'Entorno de prueba':'Entorno de operación'}</span><span>${h(f.zona_horaria||'America/Santiago')}</span></section>
    <section class="statistics-source" aria-labelledby="statistics-internal-title"><div class="statistics-section-head"><small>Fuente 01 · registros internos</small><h2 id="statistics-internal-title">Reportes de tus organizaciones</h2><p>Casos del período seleccionado. Su estado y desenlace reflejan la situación registrada al consultar.</p><p>${statisticNumber(internal.reportes_total)} reportes recibidos · ${statisticNumber(internal.duplicados_excluidos)} duplicados excluidos de los gráficos y de la recuperación.</p></div><div class="stats statistics-metrics">${statisticsMetric('Casos sin duplicados',statisticNumber(internal.total),'Cohorte del período')}${statisticsMetric('Casos abiertos',statisticNumber(recovery.abiertos),'En seguimiento a la fecha de consulta')}${statisticsMetric('Recuperaciones documentadas',statisticNumber(recovery.documentados),'Según el desenlace registrado')}${statisticsMetric('Recuperación de la cohorte',recovery.porcentaje_cohorte==null?'—':statisticNumber(recovery.porcentaje_cohorte)+' %','Recuperaciones / casos sin duplicados')}</div>
    ${statisticsTrend('statistics-internal','Evolución mensual de reportes',internal.mensual,'Reportes internos')}<div class="statistics-grid">${statisticsBreakdown('Marcas de vehículos',internal.marcas)}${statisticsBreakdown('Modelos de vehículos',internal.modelos,row=>[row.marca,row.modelo].filter(Boolean).join(' · ')||'Sin dato','Marca / modelo')}${statisticsBreakdown('Tipos de vehículo',internal.tipos_vehiculo)}${statisticsBreakdown('Reportes por zona',internal.zonas)}${statisticsBreakdown('Estado actual de los casos',internal.estados)}${statisticsBreakdown('Desenlace registrado',internal.desenlaces)}${statisticsBreakdown('Tipos de incidente',internal.tipos_incidente)}</div>${temporal('reportes internos',internal)}</section>
    ${statisticsBreakdown('Revisión actual de aportes de estos casos',internal.aportes)}
    ${statisticsCameras(data.camaras)}
    <section class="statistics-source statistics-external" aria-labelledby="statistics-external-title"><div class="statistics-section-head"><small>Fuente 02 · historial externo validado</small><h2 id="statistics-external-title">Hechos territoriales revisados</h2><p>Historial compartido, sin adscripción a una organización. El filtro de organización limita los reportes internos y el inventario de cámaras; no atribuye este historial a tu institución.</p><p>Se cuentan hechos validados con respaldo autorizado, no la cantidad de noticias. Pueden referirse a un reporte interno: ambas fuentes se consultan por separado y no se suman.</p><strong class="territorial-total">${statisticNumber(territorial.total)} hechos territoriales</strong></div>${statisticsTrend('statistics-external','Evolución mensual del historial territorial',territorial.mensual,'Hechos territoriales validados')}<div class="statistics-grid">${statisticsBreakdown('Hechos territoriales por zona',territorial.zonas)}${statisticsBreakdown('Tipos de hecho territorial',territorial.tipos)}</div>${temporal('historial territorial',territorial)}</section>
    <section id="statistics-methodology" class="card statistics-methodology" tabindex="-1"><h2>Fuentes, método y límites</h2><p>Los gráficos muestran recuentos del servicio de estadísticas para los filtros indicados. No son tasas de delincuencia ni estimaciones de riesgo. La ausencia de registros no demuestra ausencia de hechos.</p><p>Las tablas de clasificación muestran primero las ocho categorías de mayor recuento y permiten consultar todas las categorías devueltas. La serie mensual incluye los meses sin registros dentro del período.</p><ul>${(data.limites||[]).map(limit=>`<li>${h(limit)}</li>`).join('')}</ul><p>Origen: registros institucionales de RutaAlerta, historial territorial revisado e inventario autorizado de cámaras. Los datos de operación y prueba se consultan en entornos separados.</p></section>`;
}
async function load(focus=false){
  MapaOperador.cerrar();
  const epoch=++generation;clearPhotos();el('title').textContent=selected?'Ficha del caso':names[view]||'Página no encontrada';el('status').textContent='';
  el('page-description').textContent=selected?'Expediente privado, revisión y seguimiento institucional.':descriptions[view]||'Selecciona una sección del centro de operaciones.';
  el('updated').textContent='';document.title=(selected?'Ficha #'+selected:names[view]||'Página no encontrada')+' · RutaAlerta';
  for(const b of document.querySelectorAll('nav [data-view]')){if(b.dataset.view===view)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');}
  if(focus)el('title').focus();
  content.setAttribute('aria-busy','true');content.textContent='Cargando…';
  try{
    let render, montar;
    if(view==='dashboard'){
      const result=await Promise.all([api('/casos'),api('/gestion/testigos')]);render=()=>dashboard(...result);
    }
    else if(view==='statistics'){const data=await api(statisticsPath());render=()=>statisticsRoom(data);}
    else if(view==='map'){
      const actual=orgs.find(o=>o.id_organizacion===mapOrg);
      if(!actual){render=()=>empty('No hay una organización disponible para esta cuenta.');}
      else{
        const data=await api('/gestion/mapa?id_organizacion='+Number(mapOrg));
        render=()=>MapaOperador.plantilla(orgs,actual);
        montar=()=>{el('geo-org').onchange=e=>{mapOrg=Number(e.target.value);load();};MapaOperador.montar(actual,data);};
      }
    }
    else if(view==='cases'&&selected){const result=await Promise.all([api('/seguimiento/'+selected),api(`/gestion/casos/${selected}/aportes`),api('/gestion/casos/'+selected+'/equipo')]);render=()=>detail(...result);}
    else if(view==='cases'){const items=await api('/casos');render=()=>queue(items);}
    else if(view==='pending'){
      const items=await api('/gestion/aportes/pendientes');
      render=()=>items.length?items.map(a=>`<article class="card"><div class="row"><h2>${h(a.folio)}</h2>${badge(a.con_foto?'Con foto':'Sin foto')}</div><p>${h(a.zona)} · ${h(date(a.recibido_en))}</p><button data-case="${Number(a.id_caso)}">Revisar en la ficha</button></article>`).join(''):empty('No hay avistamientos pendientes de revisión.');
    }
    else if(view==='sources'){const items=await api('/gestion/antecedentes');render=()=>sources(items);}
    else if(view==='witness'){const [items,cases]=await Promise.all([api('/gestion/testigos'),api('/casos')]);render=()=>witnessQueue(items,cases);}
    else if(view==='cameras'){const inventory=await api('/gestion/camaras');render=()=>cameraRoom(inventory);}
    else if(view==='resources'){const result=await Promise.all([api('/gestion/recursos-apoyo?limite=50&offset='+resourceOffset),api('/gestion/recursos-apoyo/responsables')]);render=()=>resourceRoom(...result);}
    else render=()=>`<section class="card"><h2>Esta página no existe</h2><p>Vuelve al resumen para continuar con tus casos.</p><button data-view="dashboard">Ir al resumen</button></section>`;
    if(epoch!==generation)return;
    content.innerHTML=render();
    if(view==='dashboard')dashboard.bind();
    if(view==='statistics')bindStatisticsFilters();
    el('updated').textContent='Actualizado a las '+new Date().toLocaleTimeString('es-CL',{hour:'2-digit',minute:'2-digit'});
    if(montar)montar();
    if(selected && originView!=='cases'){const back=content.querySelector('[data-list]');if(back)back.textContent='← '+names[originView];}
    if(el('clip'))bindClip();
    if(el('results')){const priorities=content.querySelector('[name=prioridad]');priorities.value=priority;priorities.onchange=()=>{priority=priorities.value;el('results').innerHTML=caseRows();};const select=content.querySelector('[name="estado"]');select.value=filter;select.onchange=()=>{filter=select.value;el('results').innerHTML=caseRows();};el('search').oninput=e=>{query=e.target.value;el('results').innerHTML=caseRows();};}
  }catch(err){if(epoch===generation){content.innerHTML=(view==='statistics'?statisticsForm():'')+`<section class="card load-error" role="alert"><h2>No se pudo cargar esta vista</h2><p>${h(err.message)}</p><button data-retry>Reintentar</button>${selected?'<button data-list>Volver a la bandeja</button>':''}</section>`;if(view==='statistics')bindStatisticsFilters();}else if(!token)notify(err.message);}
  finally{if(epoch===generation)content.setAttribute('aria-busy','false');}
}
content.onclick=e=>{
  const b=e.target.closest('button');if(!b)return;
  if(b.hasAttribute('data-retry'))load();
  if(b.hasAttribute('data-statistics-reset')){statisticsFilters=defaultStatisticsFilters();load(true);}
  if(b.hasAttribute('data-list'))navigate(originView);
  if(b.dataset.view)navigate(b.dataset.view);
  if(b.dataset.go){
    if(b.dataset.scope){query='';filter=b.dataset.scope==='reported'?'reportado':'open';priority=b.dataset.scope==='high'?'alta':'';}
    navigate(b.dataset.go);
  }
  if(b.dataset.case)abrirCaso(b.dataset.case);
  if(b.dataset.photo)handle(b,async()=>{const epoch=generation;const file=await api(`/evidencias/${Number(b.dataset.photo)}/foto`,undefined,true);if(generation!==epoch)return;const url=URL.createObjectURL(file);photos.push(url);const img=new Image();img.className='photo';img.alt='Evidencia privada del caso';img.src=url;b.replaceWith(img);});
  if(b.hasAttribute('data-resource-page')){resourceOffset=Number(b.dataset.resourcePage);load(true);}
};
content.onsubmit=e=>{
  e.preventDefault();const form=e.target;const epoch=generation;
  if(form.dataset.statistics){
    const fields=Object.fromEntries(new FormData(form));
    if(fields.periodo==='fechas'&&(!fields.desde||!fields.hasta||fields.desde>fields.hasta)){notify('Selecciona un rango válido: la fecha de inicio debe ser anterior o igual al término.');return;}
    statisticsFilters={...statisticsFilters,...fields,zona:(fields.zona||'').trim()};load(true);return;
  }
  handle(e.submitter,async()=>{const data=Object.fromEntries(new FormData(form));
    for(const input of form.querySelectorAll('input[type="number"]')){if(input.value==='')delete data[input.name];else data[input.name]=input.valueAsNumber;}
    for(const field of ['id_organizacion','id_membresia','id_caso'])if(data[field])data[field]=Number(data[field]);
    if(Object.hasOwn(data,'id_foto_vehiculo')){
      if(data.id_foto_vehiculo==='')delete data.id_foto_vehiculo;
      else {data.id_foto_vehiculo=Number(data.id_foto_vehiculo);if(!Number.isSafeInteger(data.id_foto_vehiculo)||data.id_foto_vehiculo<1)throw Error('Selecciona una foto válida.');}
    }
    if(form.dataset.resource==='edit'){
      for(const key of ['verificado_en','vence_en'])data[key]=new Date(data[key]).toISOString();
      if(new Date(data.vence_en)<=new Date(data.verificado_en))throw Error('El vencimiento debe ser posterior a la verificación.');
      data.activo=data.activo==='true';data.url_oficial=data.url_oficial.trim()||null;
      if(data.mantenido_por)data.mantenido_por=Number(data.mantenido_por);else delete data.mantenido_por;
    }
    await api(form.dataset.path,form.dataset.method==='DELETE'?undefined:data,false,form.dataset.method||'POST');if(generation!==epoch)return;await load();if(token)notify('Cambio guardado.');
  });
};

function equipoCaso(c,equipo) {
  const base=`/gestion/casos/${Number(c.id_caso)}`;
  const members=Object.fromEntries(equipo.opciones.map(m=>[m.id_membresia,m.nombre_visible]));
  const assign=c.estado!=='cerrado'&&equipo.puede_asignar!==false&&equipo.opciones.length?action('Asignar responsable',base+'/asignacion',selector('id_membresia','Integrante de la organización',members)+motives):'';
  const note=c.estado!=='cerrado'?action('Registrar gestión interna',base+'/gestiones',selector('accion','Tipo de gestión',{nota:'Nota interna',derivacion:'Derivación realizada'})+'<label>Describe la gestión realizada<textarea name="descripcion" required minlength="10" maxlength="500"></textarea></label>'):'';
  return `<section class="card"><h2>Equipo y gestiones internas</h2><p>Responsable: ${h(equipo.responsable||'Sin asignar')}${equipo.responsable&&equipo.responsable_rol?` <span class="badge">${h(roleName(equipo.responsable_rol))}</span>`:''}</p>${equipo.responsable&&equipo.responsable_vigente===false?'<p class="membership-warning" role="status">La membresía de la persona asignada ya no está vigente. Un supervisor debe revisar la asignación.</p>':''}<p class="muted assignment-help">La asignación de un caso no modifica el rol ni otorga permisos de supervisor.</p>${assign}${note}${equipo.gestiones.map(g=>`<div class="record">${badge(g.accion)} <strong>${h(date(g.creada_en))}</strong><p>${h(g.descripcion)}</p></div>`).join('')}</section>`;
}
function witnessQueue(items,cases){
  if(!items.length)return empty('Aún no hay avisos de pasajeros o testigos en tu organización.');
  return items.map(a=>{
    const options=Object.fromEntries(cases.filter(c=>c.id_organizacion===a.id_organizacion&&c.estado!=='cerrado').map(c=>[c.id_caso,c.folio]));
    const path='/gestion/testigos/'+encodeURIComponent(a.id_aviso)+'/revision';
    let actions='';
    if(a.estado==='pendiente'){
      actions=action('Revisar sin asociar a un caso',path,selector('decision','Decisión',{revisado:'Dejar revisado',descartado:'Descartar'})+motives);
      if(Object.keys(options).length)actions+=action('Asociar a un caso abierto',path,'<input type="hidden" name="decision" value="asociado">'+selector('id_caso','Caso de la organización',options)+motives);
    }
    return `<article class="card"><div class="row"><h2>${a.perspectiva==='pasajero'?'Aviso de pasajero':'Aviso de testigo'}</h2>${badge(a.estado)}</div>
      <p><strong>${h(a.zona)}</strong> · ${h(date(a.observado_en))}</p><p>${h(a.descripcion)}</p><p>Patente observada: ${h(a.patente_observada||'Desconocida')}</p><p class="muted">Comprobante: ${h(a.id_aviso)}</p>
      ${a.motivo_revision?`<p>Decisión: ${h(a.motivo_revision)} ${a.folio?'· '+h(a.folio):''}</p>`:''}${actions}</article>`;
  }).join('');
}
function cameraRoom(inventory){
  const list=inventory.camaras.map(c=>`<div class="record"><strong>${h(c.nombre)}</strong> ${badge(c.estado)} ${badge(c.entorno)}
    <p>Referencia de autorización: ${h(c.referencia_autorizacion)}</p><p>Última verificación: ${h(date(c.verificada_en))}</p></div>`).join('');
  return `<section class="card"><h2>Inventario de mi organización</h2><p>${h(inventory.nota)}</p>${list||empty('Sin cámaras registradas en tu organización.')}</section>
    <section class="card"><h2>Revisar un clip local</h2><p>Selecciona un video autorizado o un clip de práctica. Se reproduce sólo en este navegador. No se incorpora al expediente.</p>
    <button id="ver-practica" type="button">Ver ejemplo ilustrado</button>
    <label>Archivo de video<input type="file" id="clip" accept="video/mp4,video/webm"></label>
    <video id="preview" hidden controls playsinline preload="metadata" style="background:#122236;width:100%;max-height:450px;margin-top:16px"></video><p id="video-status" role="status"></p></section>`;
}
function resourceRoom(items,responsibles){
  const categories={denuncia:'Denuncia',orientacion:'Orientación',apoyo_victima:'Apoyo a víctimas',otro:'Otro'};
  const localDate=value=>{if(!value)return '';const d=new Date(value);return new Date(d.getTime()-d.getTimezoneOffset()*60000).toISOString().slice(0,19);};
  function form(r={}){
    const path='/gestion/recursos-apoyo'+(r.id_recurso_apoyo?'/'+Number(r.id_recurso_apoyo):'');
    const choose=(name,label,values,value)=>selector(name,label,values).replace(`value="${h(value)}"`,`value="${h(value)}" selected`);
    const members=Object.fromEntries(responsibles.map(m=>[m.id_usuario,m.nombre_visible]));
    if(r.mantenido_por&&!members[r.mantenido_por])members[r.mantenido_por]=r.responsable||'Responsable actual';
    return `<details class="record"><summary>${r.id_recurso_apoyo?'Editar recurso':'Registrar recurso de apoyo'}</summary><form data-path="${path}" data-method="${r.id_recurso_apoyo?'PUT':'POST'}" data-resource="edit"><div class="form-grid">
      ${choose('categoria','Categoría',categories,r.categoria||'orientacion')}
      <label>Territorio o comuna<input name="territorio" required maxlength="200" value="${h(r.territorio||'')}"></label>
      <label>Título<input name="titulo" required maxlength="150" value="${h(r.titulo||'')}"></label>
      <label>Canal de atención<input name="canal" required maxlength="300" value="${h(r.canal||'')}"></label>
      <label>Verificado el (hora local)<input name="verificado_en" type="datetime-local" step="1" required value="${localDate(r.verificado_en)}"></label>
      <label>Vigente hasta (hora local)<input name="vence_en" type="datetime-local" step="1" required value="${localDate(r.vence_en)}"></label>
      ${choose('mantenido_por','Responsable',{'':r.id_recurso_apoyo?'Conservar responsable actual':'Mi cuenta',...members},r.mantenido_por||'')}
      ${choose('activo','Disponibilidad',{true:'Activo',false:'Inactivo'},String(r.activo??true))}</div>
      <label>Descripción<textarea name="descripcion" required maxlength="10000">${h(r.descripcion||'')}</textarea></label>
      <label>Enlace oficial (opcional)<input name="url_oficial" type="url" pattern="https?://.+" maxlength="1000" value="${h(r.url_oficial||'')}"></label>
      <p class="muted">Confirma los datos y su vigencia antes de guardar. Los recursos activos, verificados y vigentes quedan disponibles para la ciudadanía.</p><button class="primary">Guardar recurso</button></form></details>`;
  }
  return `<section class="card resource-tools"><h2>Directorio de apoyo</h2><p>Recursos mantenidos por integrantes de tus organizaciones. Incluye registros inactivos y vencidos. Hasta 50 recursos por página.</p>${form()}</section><div class="resource-grid">${items.map(r=>`<article class="card"><div class="row">${badge(categories[r.categoria]||r.categoria)}${badge(!r.activo?'Inactivo':r.vigente?'Vigente':'Vencido o sin verificar')}</div><h2>${h(r.titulo)}</h2><p>${h(r.descripcion)}</p><p><strong>${h(r.territorio)}</strong> · ${h(r.canal)}</p>${/^https?:\/\//i.test(r.url_oficial||'')?`<a href="${h(r.url_oficial)}" target="_blank" rel="noopener noreferrer">Abrir enlace oficial ↗</a>`:''}<p class="resource-meta">Responsable: ${h(r.responsable)}<br>Verificado: ${h(date(r.verificado_en))}<br>Vence: ${h(date(r.vence_en))}</p>${r.puede_editar?form(r)+(r.activo?`<details class="record"><summary>Desactivar recurso</summary><form data-path="/gestion/recursos-apoyo/${Number(r.id_recurso_apoyo)}" data-method="DELETE"><p>Dejará de estar disponible para la ciudadanía. Puedes reactivarlo al editarlo.</p><button>Desactivar recurso</button></form></details>`:''):''}</article>`).join('')}</div>${items.length?'':empty(resourceOffset?'No hay más recursos. Vuelve a la página anterior.':'No hay recursos de apoyo registrados en tu ámbito institucional.')}<div class="resource-pagination"><button data-resource-page="${Math.max(0,resourceOffset-50)}" ${resourceOffset?'':'disabled'}>Anterior</button><span>Página ${resourceOffset/50+1}</span><button data-resource-page="${resourceOffset+50}" ${items.length===50&&resourceOffset<10000?'':'disabled'}>Siguiente</button></div>`;
}
function bindClip(){
  const input=el('clip'),player=el('preview');let url=null;
  el('ver-practica').onclick=()=>{
    input.value='';input.onchange();
    player.hidden=false;player.src='/clip-practica.mp4';
    el('video-status').textContent='Ejemplo sintético de siete segundos.';
    player.play().catch(()=>{el('video-status').textContent='Pulsa reproducir para ver el ejemplo sintético.';});
  };
  input.onchange=()=>{
    player.pause();player.removeAttribute('src');player.load();player.hidden=true;el('video-status').textContent='';
    if(url){URL.revokeObjectURL(url);photos=photos.filter(item=>item!==url);url=null;}
    const file=input.files[0];if(!file)return;
    if(!['video/mp4','video/webm'].includes(file.type)){el('video-status').textContent='Selecciona un archivo MP4 o WebM.';return;}
    url=URL.createObjectURL(file);photos.push(url);
    player.onerror=()=>{el('video-status').textContent='El navegador no puede reproducir este archivo.';};
    player.src=url;player.hidden=false;
  };
}
