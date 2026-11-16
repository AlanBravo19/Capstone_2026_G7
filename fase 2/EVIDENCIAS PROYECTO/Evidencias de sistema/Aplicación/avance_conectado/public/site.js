'use strict';
const $=id=>document.getElementById(id);
let token='',perfil=null,registro=false,desafio=null,envioCaso=null,correoCanal='prueba';
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let mensajeTimer;
let catalogoVehicular;
const vehiculo=$('form-vehiculo').elements;
const nombresTipo={automovil:'Automóvil',motocicleta:'Motocicleta',camioneta:'Camioneta',furgon:'Furgón',camion:'Camión'};
function opciones(select, values, labels={}){
 select.replaceChildren(new Option('Selecciona…',''),...values.map(v=>new Option(labels[v]||v,v)));
}
function opcionesModelo(){
 opciones(vehiculo.modelo,catalogoVehicular.catalogo[vehiculo.tipo_vehiculo.value]?.[vehiculo.marca.value]||[]);
}
function opcionesVehiculo(){
 const tipo=vehiculo.tipo_vehiculo.value;
 opciones(vehiculo.marca,Object.keys(catalogoVehicular.catalogo[tipo]||{}));opcionesModelo();
 vehiculo.patente.placeholder=tipo==='motocicleta'?'Ejemplo: BCD12':'Ejemplo: BCDF12';
 vehiculo.patente.setCustomValidity('');
}
async function prepararCatalogo(){
 if(catalogoVehicular)return;
 catalogoVehicular=await api('/catalogo/vehiculos');
 opciones(vehiculo.tipo_vehiculo,Object.keys(nombresTipo),nombresTipo);opcionesVehiculo();
 vehiculo.tipo_vehiculo.onchange=opcionesVehiculo;vehiculo.marca.onchange=opcionesModelo;
 vehiculo.patente.oninput=()=>vehiculo.patente.setCustomValidity('');
 vehiculo.anio.max=new Date().getFullYear()+1;
}
function limpiarAlta(){
 $('clave-totp').textContent='';$('codigos-recuperacion').textContent='';$('activar-totp').hidden=true;
 $('preparar-totp').reset();$('activar-totp').reset();
}
formulario('preparar-totp',async e=>{
 const r=await api('/seguridad/totp/preparar',{method:'POST',body:{clave:e.target.elements.clave.value}});
 e.target.reset();$('clave-totp').textContent=r.secreto;$('activar-totp').hidden=false;
});
formulario('activar-totp',async e=>{
 const r=await api('/seguridad/totp/activar',{method:'POST',body:{codigo:e.target.elements.codigo.value.trim()}});
 limpiarAlta();token='';$('codigos-recuperacion').textContent=r.codigos_recuperacion.join('\n');
 $('resguardo').showModal();
});
$('resguardo').oncancel=e=>e.preventDefault();
$('volver-ingreso').onclick=()=>{limpiarAlta();location.reload();};
function aviso(texto,error=false){$('mensaje').textContent=texto;$('mensaje').className=error?'error':'';$('mensaje').hidden=false;clearTimeout(mensajeTimer);mensajeTimer=setTimeout(()=>$('mensaje').hidden=true,11000)}
async function api(ruta,{method='GET',body,headers={}}={}){
 const h={...headers};if(token)h.Authorization='Bearer '+token;
 if(body!==undefined)h['Content-Type']='application/json';
 const r=await fetch(ruta,{method,headers:h,body:body===undefined?undefined:JSON.stringify(body)});
 const datos=r.status===204?null:await r.json().catch(()=>null);
 if(!r.ok){let d=datos?.detail;if(Array.isArray(d))d=d.map(x=>x.msg).join('. ');if(r.status===401&&token){limpiarAlta();RutaMapa.limpiar();token='';$('panel').hidden=true;$('acceso').hidden=false;$('salir').hidden=true}throw new Error(d||'No se pudo completar la operación. Intenta nuevamente.');}
 return datos;
}
function formulario(id,fn){$(id).addEventListener('submit',async e=>{e.preventDefault();const b=e.submitter;if(b)b.disabled=true;try{await fn(e)}catch(err){aviso(err.message,true)}finally{if(b)b.disabled=false}})}
function accion(id,fn){$(id).addEventListener('click',async()=>{const b=$(id);b.disabled=true;try{await fn()}catch(e){aviso(e.message,true)}finally{b.disabled=false}})}
function modo(r){registro=r;$('modalidad-wrap').hidden=!r;$('nombre-wrap').hidden=!r;$('nombre').required=r;$('titulo-acceso').textContent=r?'Comienza tu registro':'Bienvenido a RutaAlerta';$('submit-acceso').textContent=r?'Crear cuenta e ingresar':'Ingresar';$('modo-ingreso').className=r?'':'active';$('modo-registro').className=r?'active':'';$('clave').autocomplete=r?'new-password':'current-password'}
$('modo-ingreso').onclick=()=>modo(false);$('modo-registro').onclick=()=>modo(true);
formulario('form-acceso',async()=>{const correo=$('correo').value,clave=$('clave').value;
 const nueva=registro;if(nueva){await api('/cuentas',{method:'POST',body:{correo,clave,nombre_visible:$('nombre').value,modalidad_ciudadana:$('modalidad').value}});modo(false);}
 let login=await api('/sesiones',{method:'POST',body:{correo,clave}});
 if(login.requiere_mfa){const codigo=window.prompt('Ingresa el código del autenticador o un código de recuperación:');if(!codigo)throw new Error('Ingreso cancelado.');login=await api('/sesiones/mfa',{method:'POST',body:{id_desafio:login.id_desafio,codigo:codigo.trim()}});}
 token=login.token;$('clave').value='';
 try{await cargar();$('acceso').hidden=true;$('panel').hidden=false;$('salir').hidden=false;if(nueva){$('form-correo').scrollIntoView();$('pedir-correo').click();}else aviso('Sesión iniciada. Bienvenido a RutaAlerta.')}catch(e){token='';RutaMapa.limpiar();throw e}
});
accion('salir',async()=>{try{await api('/sesiones/cerrar',{method:'POST'})}finally{limpiarAlta();token='';perfil=null;$('panel').hidden=true;$('acceso').hidden=false;$('salir').hidden=true;$('administracion').hidden=true;RutaMapa.limpiar()}});
accion('actualizar',cargar);
async function cargar(){
 perfil=await api('/mi-perfil');await cargarTestigos();const estado=await api('/identidad/mi-estado');await prepararCatalogo();const vehiculos=await api('/vehiculos');const casos=await api('/mis-casos');
 $('alta-totp').hidden=estado.transporte_correo!=='smtp'||!estado.correo_verificado||estado.mfa_activo;
 if(estado.transporte_correo==='smtp'){
  $('pedir-correo').textContent='Enviar código por correo';
  $('nota-verificacion').textContent=estado.canales_demo?'El código de correo se envía a tu buzón. El paso de teléfono sigue siendo de prueba y no acredita su titularidad.':'El código llega a tu correo. Para participar, completa el paso de Autenticador aquí.';
 }
 RutaMapa.actualizar(casos);
 $('saludo').textContent='Hola, '+perfil.nombre_visible;$('estado-cuenta').textContent=estado.estado;$('total-vehiculos').textContent=vehiculos.length;$('total-casos').textContent=casos.length;
 if(estado.transporte_correo==='smtp'){$('pedir-sms').hidden=true;$('form-telefono').hidden=true;}
 $('estado-contactos').textContent=`Correo: ${estado.correo_verificado?'confirmado':'pendiente'} · Autenticador: ${estado.mfa_activo?'activo':'pendiente'} · ${estado.puede_participar?'Puedes registrar vehículos y reportes.':'Completa los dos pasos para participar.'}`;
 $('lista-vehiculos').innerHTML=vehiculos.length?vehiculos.map(v=>`<article class="item"><b>${esc(v.patente)} · ${esc(v.marca)} ${esc(v.modelo)}</b><p>${esc(v.color)} · ${esc(v.anio)}</p><span class="pill">Vínculo ${esc(v.estado_vinculo)}</span></article>`).join(''):'<p class="empty">Todavía no has registrado vehículos.</p>';
 $('vehiculo-caso').innerHTML='<option value="">Selecciona tu vehículo</option>'+vehiculos.map(v=>`<option value="${Number(v.id_vehiculo)}">${esc(v.patente)} · ${esc(v.modelo)}</option>`).join('');
 $('lista-casos').innerHTML=casos.length?casos.map(c=>`<article class="item"><b>${esc(c.folio)} · ${esc(c.patente)}</b><p>${esc(c.zona)} · ${esc(new Date(c.fecha_hecho).toLocaleString('es-CL'))}</p><span class="pill">${esc(c.estado.replaceAll('_',' '))}</span><p>Antecedentes de denuncia: ${esc(c.denuncia_estado.replaceAll('_',' '))}. Sin publicación automática.</p></article>`).join(''):'<p class="empty">Tus reportes aparecerán aquí después de registrarlos.</p>';
 const admin=perfil.roles.includes('administrador');$('administracion').hidden=!admin;

}
accion('pedir-correo',async()=>{const r=await api('/identidad/correo/solicitar',{method:'POST'});correoCanal=r.canal||'prueba';if(r.token_demo){$('token-correo').value=r.token_demo;$('correo-demo').textContent='Código beta preparado. No se envió un correo.';$('correo-demo').hidden=false}else {$('correo-demo').textContent=r.mensaje;$('correo-demo').hidden=false;aviso(r.mensaje)}});
formulario('form-correo',async()=>{await api('/identidad/correo/confirmar',{method:'POST',body:{token:$('token-correo').value}});$('token-correo').value='';$('correo-demo').hidden=true;await cargar();aviso(correoCanal==='correo'?'Correo confirmado con el código recibido.':'Paso de correo completado en la beta.')});
accion('pedir-sms',async()=>{const r=await api('/identidad/telefono/solicitar',{method:'POST',body:{telefono:$('telefono').value}});desafio=r.id_desafio;$('codigo-sms').value=r.codigo_demo||'';$('sms-demo').textContent='Código beta: '+r.codigo_demo+'. No se envió un SMS.';$('sms-demo').hidden=false});
formulario('form-telefono',async()=>{if(!desafio)throw new Error('Primero solicita un código.');await api('/identidad/telefono/confirmar',{method:'POST',body:{id_desafio:desafio,codigo:$('codigo-sms').value}});desafio=null;$('codigo-sms').value='';$('sms-demo').hidden=true;await cargar();aviso('Pasos beta completados. Ya puedes registrar vehículos y reportes.')});
formulario('form-vehiculo',async e=>{const d=Object.fromEntries(new FormData(e.target));d.anio=Number(d.anio);d.patente=d.patente.toUpperCase().replace(/[ .-]/g,'');const formato=catalogoVehicular.formatos[d.tipo_vehiculo==='motocicleta'?'motocicleta':'cuatro_ruedas'];if(!new RegExp('^'+formato+'$').test(d.patente)){vehiculo.patente.setCustomValidity('Revisa la patente para este tipo de vehículo.');vehiculo.patente.reportValidity();return;}await api('/vehiculos',{method:'POST',body:d});e.target.reset();opcionesVehiculo();await cargar();aviso('Vehículo guardado. Vínculo pendiente de revisión.')});
formulario('form-caso',async e=>{const d={id_vehiculo:Number($('vehiculo-caso').value),id_organizacion:Number($('org-caso').value),fecha_hecho:new Date($('fecha-caso').value).toISOString(),zona:$('zona-caso').value,descripcion:$('descripcion').value,latitud:Number($('latitud').value),longitud:Number($('longitud').value)};
 // Un fallo de red conserva la clave para no duplicar el mismo envío.
 const firma=JSON.stringify(d);if(!envioCaso||envioCaso.firma!==firma)envioCaso={firma,clave:crypto.randomUUID()};
 const r=await api('/casos',{method:'POST',body:d,headers:{'Idempotency-Key':envioCaso.clave}});envioCaso=null;e.target.reset();RutaMapa.quitarSeleccion();await cargar();aviso('Reporte guardado: '+r.folio+'. Está pendiente de revisión.')});
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

let intentoTestigo;
async function cargarTestigos(){
 const [orgs,mios]=await Promise.all([api('/organizaciones'),api('/mis-avisos-testigo')]);
 for(const select of [$('org-caso'),$('form-testigo').elements.id_organizacion]){
   const previo=select.value;
   select.replaceChildren(new Option('Selecciona…',''),...orgs.map(o=>new Option(o.nombre,String(o.id_organizacion))));
   select.value=previo;
 }
 $('form-modalidad').elements.modalidad_ciudadana.value=perfil.modalidad_ciudadana;
 $('mis-avisos').textContent=mios.length?'':'Aún no has enviado avisos.';
 for(const a of mios){const row=document.createElement('p');row.textContent=a.zona+' · '+a.estado+' · Comprobante '+a.id_aviso;$('mis-avisos').append(row);}
}
formulario('form-modalidad',async e=>{
 const modalidad=e.target.elements.modalidad_ciudadana.value;
 await api('/mi-perfil/modalidad',{method:'PUT',body:{modalidad_ciudadana:modalidad}});perfil.modalidad_ciudadana=modalidad;aviso('Preferencia guardada.');
});
formulario('form-testigo',async e=>{
 const data=Object.fromEntries(new FormData(e.target));data.observado_en=new Date(data.observado_en).toISOString();
 data.id_organizacion=Number(data.id_organizacion);data.patente_observada=data.patente_observada.trim()||null;
 const firma=JSON.stringify(data);
 if(intentoTestigo?.firma!==firma)intentoTestigo={firma,clave:crypto.randomUUID()};
 const r=await api('/avisos-testigo',{method:'POST',body:data,headers:{'Idempotency-Key':intentoTestigo.clave}});
 intentoTestigo=null;e.target.reset();aviso('Aviso recibido. Comprobante '+r.id_aviso);await cargarTestigos();
});
