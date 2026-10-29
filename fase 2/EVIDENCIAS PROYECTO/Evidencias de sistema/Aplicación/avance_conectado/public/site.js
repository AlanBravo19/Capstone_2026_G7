'use strict';
const $=id=>document.getElementById(id);
let token='',perfil=null,registro=false,desafio=null,envioCaso=null,correoCanal='prueba';
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let mensajeTimer;
function aviso(texto,error=false){$('mensaje').textContent=texto;$('mensaje').className=error?'error':'';$('mensaje').hidden=false;clearTimeout(mensajeTimer);mensajeTimer=setTimeout(()=>$('mensaje').hidden=true,11000)}
async function api(ruta,{method='GET',body,headers={}}={}){
 const h={...headers};if(token)h.Authorization='Bearer '+token;
 if($('demo-key').value)h['X-Demo-Access']=$('demo-key').value;
 if(body!==undefined)h['Content-Type']='application/json';
 const r=await fetch(ruta,{method,headers:h,body:body===undefined?undefined:JSON.stringify(body)});
 const datos=r.status===204?null:await r.json().catch(()=>null);
 if(!r.ok){let d=datos?.detail;if(Array.isArray(d))d=d.map(x=>x.msg).join('. ');if(r.status===401&&token){token='';$('panel').hidden=true;$('acceso').hidden=false;$('salir').hidden=true}throw new Error(d||'No se pudo completar la operación. Intenta nuevamente.');}
 return datos;
}
function formulario(id,fn){$(id).addEventListener('submit',async e=>{e.preventDefault();const b=e.submitter;if(b)b.disabled=true;try{await fn(e)}catch(err){aviso(err.message,true)}finally{if(b)b.disabled=false}})}
function accion(id,fn){$(id).addEventListener('click',async()=>{const b=$(id);b.disabled=true;try{await fn()}catch(e){aviso(e.message,true)}finally{b.disabled=false}})}
function modo(r){registro=r;$('nombre-wrap').hidden=!r;$('nombre').required=r;$('titulo-acceso').textContent=r?'Comienza tu registro':'Bienvenido a RutaAlerta';$('submit-acceso').textContent=r?'Crear cuenta e ingresar':'Ingresar';$('modo-ingreso').className=r?'':'active';$('modo-registro').className=r?'active':'';$('clave').autocomplete=r?'new-password':'current-password'}
$('modo-ingreso').onclick=()=>modo(false);$('modo-registro').onclick=()=>modo(true);
formulario('form-acceso',async()=>{const correo=$('correo').value,clave=$('clave').value;
 if(registro)await api('/cuentas',{method:'POST',body:{correo,clave,nombre_visible:$('nombre').value}});
 token=(await api('/sesiones',{method:'POST',body:{correo,clave}})).token;$('clave').value='';
 try{await cargar();$('acceso').hidden=true;$('panel').hidden=false;$('salir').hidden=false;aviso('Sesión iniciada. Bienvenido a RutaAlerta.')}catch(e){token='';throw e}
});
accion('salir',async()=>{try{await api('/sesiones/cerrar',{method:'POST'})}finally{token='';perfil=null;$('panel').hidden=true;$('acceso').hidden=false;$('salir').hidden=true;$('administracion').hidden=true}});
accion('actualizar',cargar);
async function cargar(){
 perfil=await api('/mi-perfil');const estado=await api('/identidad/mi-estado');const vehiculos=await api('/vehiculos');const casos=await api('/mis-casos');
 if(estado.transporte_correo==='smtp'){
  $('pedir-correo').textContent='Enviar código por correo';
  $('nota-verificacion').textContent=estado.canales_demo?'El código de correo se envía a tu buzón. El paso de teléfono sigue siendo de prueba y no acredita su titularidad.':'El código de correo se envía a tu buzón. La verificación por SMS aún no está disponible; la participación permanece restringida.';
 }
 $('saludo').textContent='Hola, '+perfil.nombre_visible;$('estado-cuenta').textContent=estado.estado;$('total-vehiculos').textContent=vehiculos.length;$('total-casos').textContent=casos.length;
 $('estado-contactos').textContent=`Correo: ${estado.correo_verificado?'paso beta completado':'pendiente'} · Teléfono: ${estado.telefono_verificado?'paso beta completado':'pendiente'} · ${estado.puede_participar?'Puedes registrar vehículos y reportes.':'Completa los dos pasos para participar.'}`;
 $('lista-vehiculos').innerHTML=vehiculos.length?vehiculos.map(v=>`<article class="item"><b>${esc(v.patente)} · ${esc(v.marca)} ${esc(v.modelo)}</b><p>${esc(v.color)} · ${esc(v.anio)}</p><span class="pill">Vínculo ${esc(v.estado_vinculo)}</span></article>`).join(''):'<p class="empty">Todavía no has registrado vehículos.</p>';
 $('vehiculo-caso').innerHTML='<option value="">Selecciona tu vehículo</option>'+vehiculos.map(v=>`<option value="${Number(v.id_vehiculo)}">${esc(v.patente)} · ${esc(v.modelo)}</option>`).join('');
 $('lista-casos').innerHTML=casos.length?casos.map(c=>`<article class="item"><b>${esc(c.folio)} · ${esc(c.patente)}</b><p>${esc(c.zona)} · ${esc(new Date(c.fecha_hecho).toLocaleString('es-CL'))}</p><span class="pill">${esc(c.estado.replaceAll('_',' '))}</span><p>Antecedentes de denuncia: ${esc(c.denuncia_estado.replaceAll('_',' '))}. Sin publicación automática.</p></article>`).join(''):'<p class="empty">Tus reportes aparecerán aquí después de registrarlos.</p>';
 const admin=perfil.roles.includes('administrador');$('administracion').hidden=!admin;
 if(admin){const bandeja=await api('/casos');$('bandeja').innerHTML=bandeja.length?bandeja.map(c=>`<article class="item"><b>${esc(c.folio)}</b><p>${esc(c.estado)} · prioridad ${esc(c.prioridad)}</p><label>Motivo de revisión<input id="revision-${Number(c.id_caso)}" minlength="10" placeholder="Explica el cambio de estado"></label><button class="secondary revisar" data-id="${Number(c.id_caso)}">Marcar en revisión</button></article>`).join(''):'<p class="empty">No hay casos en tu bandeja.</p>';}
}
accion('pedir-correo',async()=>{const r=await api('/identidad/correo/solicitar',{method:'POST'});correoCanal=r.canal||'prueba';if(r.token_demo){$('token-correo').value=r.token_demo;$('correo-demo').textContent='Código beta preparado. No se envió un correo.';$('correo-demo').hidden=false}else {$('correo-demo').textContent=r.mensaje;$('correo-demo').hidden=false;aviso(r.mensaje)}});
formulario('form-correo',async()=>{await api('/identidad/correo/confirmar',{method:'POST',body:{token:$('token-correo').value}});$('token-correo').value='';$('correo-demo').hidden=true;await cargar();aviso(correoCanal==='correo'?'Correo confirmado con el código recibido.':'Paso de correo completado en la beta.')});
accion('pedir-sms',async()=>{const r=await api('/identidad/telefono/solicitar',{method:'POST',body:{telefono:$('telefono').value}});desafio=r.id_desafio;$('codigo-sms').value=r.codigo_demo||'';$('sms-demo').textContent='Código beta: '+r.codigo_demo+'. No se envió un SMS.';$('sms-demo').hidden=false});
formulario('form-telefono',async()=>{if(!desafio)throw new Error('Primero solicita un código.');await api('/identidad/telefono/confirmar',{method:'POST',body:{id_desafio:desafio,codigo:$('codigo-sms').value}});desafio=null;$('codigo-sms').value='';$('sms-demo').hidden=true;await cargar();aviso('Pasos beta completados. Ya puedes registrar vehículos y reportes.')});
formulario('form-vehiculo',async e=>{const d=Object.fromEntries(new FormData(e.target));d.anio=Number(d.anio);await api('/vehiculos',{method:'POST',body:d});e.target.reset();await cargar();aviso('Vehículo guardado. Vínculo pendiente de revisión.')});
formulario('form-caso',async e=>{const d={id_vehiculo:Number($('vehiculo-caso').value),id_organizacion:1,fecha_hecho:new Date($('fecha-caso').value).toISOString(),zona:$('zona-caso').value,descripcion:$('descripcion').value,latitud:Number($('latitud').value),longitud:Number($('longitud').value)};
 // Un fallo de red conserva la clave para no duplicar el mismo envío.
 const firma=JSON.stringify(d);if(!envioCaso||envioCaso.firma!==firma)envioCaso={firma,clave:crypto.randomUUID()};
 const r=await api('/casos',{method:'POST',body:d,headers:{'Idempotency-Key':envioCaso.clave}});envioCaso=null;e.target.reset();await cargar();aviso('Reporte guardado: '+r.folio+'. Está pendiente de revisión.')});
formulario('form-sancion',async e=>{await api('/moderacion/usuarios/'+Number($('usuario-sancion').value)+'/sanciones',{method:'POST',body:{accion:'suspension',motivo:$('motivo-sancion').value}});e.target.reset();aviso('Cuenta suspendida y sesiones revocadas. Acción registrada.')});
$('bandeja').addEventListener('click',async e=>{const b=e.target.closest('.revisar');if(!b)return;const id=Number(b.dataset.id);b.disabled=true;try{await api('/gestion/casos/'+id+'/revision',{method:'POST',body:{estado:'en_revision',motivo:$('revision-'+id).value}});await cargar();aviso('Estado actualizado. El reporte continúa privado.')}catch(err){aviso(err.message,true)}finally{b.disabled=false}});

formulario('form-recuperacion',async()=>{
 const r=await api('/cuentas/recuperacion',{method:'POST',body:{correo:$('correo-recuperacion').value}});
 $('aviso-recuperacion').textContent=r.mensaje;
 if(r.token_prueba){$('token-recuperacion').value=r.token_prueba;$('aviso-recuperacion').textContent='Recuperación beta: código mostrado aquí. No se envió un correo.';}
});
formulario('form-nueva-clave',async()=>{
 await api('/cuentas/recuperacion/confirmar',{method:'POST',body:{token:$('token-recuperacion').value,nueva_clave:$('nueva-clave').value}});
 token='';perfil=null;$('token-recuperacion').value='';$('nueva-clave').value='';
 aviso('Contraseña actualizada. Inicia sesión con tu nueva contraseña.');
});
