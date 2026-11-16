'use strict';
const el=id=>document.getElementById(id);
const content=el('content');
const h=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const names={cases:'Bandeja de casos',sources:'Fuentes territoriales',cameras:'Cámaras autorizadas'};
const states={reportado:'Reportado',en_revision:'En revisión',en_gestion:'En gestión',cerrado:'Cerrado'};
const date=value=>value?new Date(value).toLocaleString('es-CL',{dateStyle:'short',timeStyle:'short'}):'—';
const badge=value=>`<span class="badge">${h(states[value]||String(value).replaceAll('_',' '))}</span>`;
const empty=message=>`<p class="empty">${h(message)}</p>`;
const motives='<label>Motivo de la decisión<textarea name="motivo" minlength="10" maxlength="500" required></textarea></label>';
const selector=(name,label,values)=>`<label>${label}<select name="${name}">${Object.entries(values).map(([k,v])=>`<option value="${h(k)}">${h(v)}</option>`).join('')}</select></label>`;
const action=(title,path,fields,submit=title)=>`<details class="record"><summary>${h(title)}</summary><form data-path="${h(path)}">${fields}<button class="primary">${h(submit)}</button></form></details>`;
let token='', invite='', challenge='', view='cases', selected=null, generation=0, records=[], orgs=[], query='', filter='';
let photos=[], noticeTimer;
function notify(message){el('status').textContent=message;clearTimeout(noticeTimer);noticeTimer=setTimeout(()=>el('status').textContent='',9500);}
function clearPhotos(){photos.forEach(URL.revokeObjectURL);photos=[];}
function reset(){
  generation++;token=invite=challenge='';orgs=[];records=[];selected=null;query=filter='';clearPhotos();
  content.replaceChildren();el('name').textContent='';el('desk').hidden=true;document.querySelector('.user').hidden=true;
  el('access').hidden=false;el('mfa').hidden=true;el('login').hidden=false;el('login').reset();el('mfa').reset();
}
async function api(path,body,binary=false){
  const session=token;const headers={'X-Demo-Access':invite};
  if(session)headers.Authorization='Bearer '+session;
  if(body!==undefined)headers['Content-Type']='application/json';
  const response=await fetch(path,{method:body===undefined?'GET':'POST',headers,body:body===undefined?undefined:JSON.stringify(body),cache:'no-store'});
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
    const profile=await api('/mi-perfil');
    if(!profile.organizaciones?.length)throw Error('Tu cuenta tiene acceso ciudadano. Para operar se requiere una membresía institucional vigente.');
    const available=await api('/organizaciones');orgs=available.filter(o=>profile.organizaciones.includes(o.id_organizacion));
    el('name').textContent=profile.nombre_visible;el('access').hidden=true;el('desk').hidden=false;document.querySelector('.user').hidden=false;
    view='cases';selected=null;await load();
  }catch(err){try{if(token)await api('/sesiones/cerrar',{});}finally{reset();}throw err;}
}
async function handle(button,work){button.disabled=true;try{await work();}catch(err){notify(err.message);}finally{button.disabled=false;}}
for(const id of ['login','mfa'])el(id).onsubmit=e=>{
  e.preventDefault();const f=e.currentTarget.elements;
  handle(e.submitter,async()=>{
    if(id==='login'){invite=f.invite.value.trim();const result=await api('/sesiones',{correo:f.correo.value.trim(),clave:f.clave.value});f.clave.value='';await signin(result);}
    else{const result=await api('/sesiones/mfa',{id_desafio:challenge,codigo:f.codigo.value.trim()});f.codigo.value='';await signin(result);}
  });
};
el('back').onclick=reset;
el('exit').onclick=()=>handle(el('exit'),async()=>{try{await api('/sesiones/cerrar',{});}finally{reset();}});
document.querySelector('nav').onclick=e=>{const b=e.target.closest('[data-view]');if(b){view=b.dataset.view;selected=null;load();}};
el('refresh').onclick=()=>load();

function caseRows(){
  const visible=records.filter(c=>(!filter||c.estado===filter)&&c.folio.toLowerCase().includes(query.toLowerCase().trim()));
  const rows=visible.map(c=>`<tr><td><strong>${h(c.folio)}</strong></td><td>${badge(c.estado)}</td><td>${h(c.prioridad)}</td><td>${h(c.aportes_pendientes)}</td><td>${h(date(c.creado_en))}</td><td><button data-case="${Number(c.id_caso)}">Abrir ficha</button></td></tr>`).join('');
  return rows?`<div class="table-wrap"><table><thead><tr><th>Folio</th><th>Estado</th><th>Prioridad</th><th>Aportes pendientes</th><th>Ingreso</th><th></th></tr></thead><tbody>${rows}</tbody></table></div>`:empty(records.length?'Ningún caso coincide con la búsqueda.':'Tu organización aún no ha recibido reportes.');
}
function queue(data){
  records=data;
  const stats=[['Casos abiertos',data.filter(c=>c.estado!=='cerrado').length],['Por revisar',data.filter(c=>c.estado==='reportado').length],['Aportes pendientes',data.reduce((n,c)=>n+c.aportes_pendientes,0)]];
  return `<div class="stats">${stats.map(([label,n])=>`<div class="stat"><span>${label}</span><strong>${n}</strong></div>`).join('')}</div>
    <section class="card"><h2>Reportes recibidos</h2><div class="filters"><label>Buscar folio<input id="search" type="search" value="${h(query)}"></label>${selector('estado','Filtrar por estado',{'':'Todos los estados',...states})}</div><div id="results">${caseRows()}</div></section>`;
}
function detail(c,contributions){
  const base=`/gestion/casos/${Number(c.id_caso)}`;const open=c.estado!=='cerrado';
  const header=`<button class="back" data-list>← Volver a la bandeja</button><section class="card"><div class="row"><h2>${h(c.folio)}</h2>${badge(c.estado)}</div><p>${h(c.patente)} · ${h(c.zona)} · ${h(date(c.fecha_hecho))}</p><p>Denuncia declarada: ${h(c.denuncia_estado)} · Colaboración ${c.colaboracion_consentida_en?'autorizada por el afectado':'pendiente de consentimiento'}.</p>`;
  const statement='<h3>Relato recibido</h3><p>'+h(c.relato_para_revision || 'Sin relato disponible.')+'</p>';
  const management=open?action('Cambiar estado',base+'/revision',selector('estado','Nuevo estado',{en_revision:'En revisión',en_gestion:'En gestión'})+motives,'Guardar cambio')+
    action('Asignar prioridad',base+'/prioridad',selector('prioridad','Prioridad',{normal:'Normal',alta:'Alta',baja:'Baja'})+motives,'Guardar prioridad')+
    (c.colaboracion_consentida_en&&c.estado!=='reportado'?action('Publicar solicitud de colaboración',base+'/publicacion','<label>Sector público<input name="zona" required minlength="3" maxlength="200"></label><label>Texto para la ciudadanía<textarea name="texto" required minlength="15" maxlength="1500"></textarea></label>'+motives):'')+
    action('Retirar solicitud de colaboración',base+'/retirar',motives)+action('Cerrar caso',base+'/cerrar',selector('motivo_cierre','Resultado',{recuperado:'Recuperado',duplicado:'Duplicado',informacion_insuficiente:'Información insuficiente',otro:'Otro'})+'<label>ID de evidencia aceptada (si fue recuperado)<input type="number" min="1" name="id_evidencia"></label><label>ID del caso principal (si fue duplicado)<input type="number" min="1" name="id_caso_principal"></label>'+motives):'';
  const sightings=contributions.map(a=>`<div class="record"><strong>${h(a.zona)}</strong> ${badge(a.estado_revision)}<p>${h(a.descripcion)}</p><p class="muted">${h(date(a.observado_en))}</p>${open?action('Evaluar aporte',`/gestion/aportes/${Number(a.id_avistamiento)}/revision`,selector('decision','Decisión',{aceptado:'Aceptar',requiere_aclaracion:'Pedir aclaración',rechazado:'Rechazar'})+motives+'<label>Resumen que podrá ver el afectado si se acepta<textarea name="resumen" maxlength="500"></textarea></label>'):''}</div>`).join('');
  const evidence=(c.evidencias||[]).map(e=>`<div class="record"><button data-photo="${Number(e.id_evidencia)}">Ver foto #${Number(e.id_evidencia)}</button> ${badge(e.estado_revision)}${open?action('Revisar evidencia',`/gestion/evidencias/${Number(e.id_evidencia)}/revision`,selector('decision','Decisión',{aceptada:'Aceptar',rechazada:'Rechazar'})+motives):''}</div>`).join('');
  return header+statement+management+`</section><section class="card"><h2>Avistamientos</h2>${sightings||empty('Todavía no hay aportes para este caso.')}</section><section class="card"><h2>Evidencias privadas</h2>${evidence||empty('Sin fotos adjuntas.')}</section><section class="card"><h2>Historial compartido con el afectado</h2>${c.historial.map(x=>`<div class="record"><strong>${h(date(x.creada_en))}</strong><p>${h(x.descripcion)}</p></div>`).join('')||empty('Todavía no hay novedades en el seguimiento.')}</section>`;
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
async function load(){
  const epoch=++generation;clearPhotos();el('title').textContent=selected?'Ficha del caso':names[view];el('status').textContent='';
  for(const b of document.querySelectorAll('nav button')){if(b.dataset.view===view)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');}
  content.setAttribute('aria-busy','true');content.textContent='Cargando…';
  try{
    let render;
    if(view==='cases'&&selected){const result=await Promise.all([api('/seguimiento/'+selected),api(`/gestion/casos/${selected}/aportes`)]);render=()=>detail(...result);}
    else if(view==='cases'){const items=await api('/casos');render=()=>queue(items);}
    else if(view==='sources'){const items=await api('/gestion/antecedentes');render=()=>sources(items);}
    else{const {camaras,nota}=await api('/gestion/camaras');render=()=>`<section class="card"><p>${h(nota)}</p>${camaras.map(c=>`<div class="record"><strong>${h(c.nombre)}</strong> ${badge(c.estado)}<p>${h(c.referencia_autorizacion)}</p></div>`).join('')||empty('Sin cámaras registradas en tu organización.')}</section>`;}
    if(epoch!==generation)return;
    content.innerHTML=render();
    if(el('results')){const select=content.querySelector('[name="estado"]');select.value=filter;select.onchange=()=>{filter=select.value;el('results').innerHTML=caseRows();};el('search').oninput=e=>{query=e.target.value;el('results').innerHTML=caseRows();};}
  }catch(err){if(epoch===generation)content.textContent=err.message;else if(!token)notify(err.message);}
  finally{if(epoch===generation)content.setAttribute('aria-busy','false');}
}
content.onclick=e=>{
  const b=e.target.closest('button');if(!b)return;
  if(b.hasAttribute('data-list')){selected=null;load();}
  if(b.dataset.case){selected=Number(b.dataset.case);load();}
  if(b.dataset.photo)handle(b,async()=>{const epoch=generation;const file=await api(`/evidencias/${Number(b.dataset.photo)}/foto`,undefined,true);if(generation!==epoch)return;const url=URL.createObjectURL(file);photos.push(url);const img=new Image();img.className='photo';img.alt='Evidencia privada del caso';img.src=url;b.replaceWith(img);});
};
content.onsubmit=e=>{
  e.preventDefault();const form=e.target;const epoch=generation;
  handle(e.submitter,async()=>{const data=Object.fromEntries(new FormData(form));
    for(const input of form.querySelectorAll('input[type="number"]')){if(input.value==='')delete data[input.name];else data[input.name]=input.valueAsNumber;}
    if(data.id_organizacion)data.id_organizacion=Number(data.id_organizacion);
    await api(form.dataset.path,data);if(generation!==epoch)return;await load();if(token)notify('Cambio guardado.');
  });
};
