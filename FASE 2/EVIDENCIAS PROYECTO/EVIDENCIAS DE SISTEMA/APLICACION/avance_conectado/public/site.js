'use strict';
RutaMapa.configurarZonas((lat,lon)=>api(`/territorio/zonas?lat=${lat}&lon=${lon}`));
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
 limpiarFotosColaboracion();limpiarFotoReporte();
 $('form-vehiculo').reset();mostrarRevisionAlta();
 $('form-solicitar-vinculo').reset();$('form-solicitar-vinculo').hidden=true;
 if($('aporte-web')){cerrarAporte();}
 $('clave-totp').textContent='';$('codigos-recuperacion').textContent='';$('activar-totp').hidden=true;
 $('preparar-totp').reset();$('activar-totp').reset();
}
formulario('preparar-totp',async e=>{
 const r=await api('/seguridad/totp/preparar',{method:'POST',body:{clave:e.target.elements.clave.value}});
 e.target.reset();$('clave-totp').textContent=r.secreto;$('activar-totp').hidden=false;
});
formulario('activar-totp',async e=>{
 const r=await api('/seguridad/totp/activar',{method:'POST',body:{codigo:e.target.elements.codigo.value.trim(),continuar_sesion:true}});
 limpiarAlta();token=r.token||'';$('codigos-recuperacion').textContent=r.codigos_recuperacion.join('\n');
 $('resguardo').showModal();
});
$('resguardo').oncancel=e=>e.preventDefault();
$('volver-ingreso').onclick=async()=>{limpiarAlta();$('resguardo').close();if(!token){location.reload();return;}try{await cargar();}catch(e){aviso(e.message,true);}};
function aviso(texto,error=false){$('mensaje').textContent=texto;$('mensaje').className=error?'error':'';$('mensaje').hidden=false;clearTimeout(mensajeTimer);mensajeTimer=setTimeout(()=>$('mensaje').hidden=true,11000)}
async function api(ruta,{method='GET',body,headers={},binary=false,signal}={}){
 const sesion=token,h={...headers};if(sesion)h.Authorization='Bearer '+sesion;
 if(body!==undefined)h['Content-Type']='application/json';
 const r=await fetch(ruta,{method,headers:h,body:body===undefined?undefined:JSON.stringify(body),cache:'no-store',signal});
 if(r.ok&&binary)return r.blob();
 const datos=r.status===204?null:await r.json().catch(()=>null);
 if(!r.ok){let d=datos?.detail;if(Array.isArray(d))d=d.map(x=>x.msg).join('. ');if(r.status===401&&sesion&&sesion===token){limpiarAlta();RutaMapa.limpiar();token='';$('panel').hidden=true;$('acceso').hidden=false;$('salir').hidden=true}throw new Error(d||'No se pudo completar la operación. Intenta nuevamente.');}
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
 try{await cargar();$('acceso').hidden=true;$('panel').hidden=false;$('salir').hidden=false;if(nueva){$('form-correo').scrollIntoView();$('pedir-correo').click();}else aviso('Sesión iniciada. Bienvenido a RutaAlerta.')}catch(e){limpiarAlta();token='';RutaMapa.limpiar();throw e}
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
 $('lista-vehiculos').innerHTML=vehiculos.length?vehiculos.map(v=>`<article class="item"><b>${esc(v.patente)} · ${esc(v.marca)} ${esc(v.modelo)}</b><p>${esc(v.color)} · ${esc(v.anio)}</p><span class="pill">${v.estado_vinculo==='autorizado'?'Vínculo aprobado':'Vínculo pendiente'}</span>${v.estado_vinculo==='pendiente'?(v.padron_recibido_en?'<p>Padrón enviado al supervisor.</p>':'<p><button type="button" data-revision-vinculo="'+Number(v.id_vehiculo)+'">Adjuntar padrón</button></p>'):v.vence_revision_en?`<p>Revisión válida hasta ${esc(v.vence_revision_en.split('T')[0])}.</p>`:''}</article>`).join(''):'<p class="empty">Todavía no has registrado vehículos.</p>';
 $('vehiculo-caso').innerHTML='<option value="">Selecciona tu vehículo</option>'+vehiculos.map(v=>`<option value="${Number(v.id_vehiculo)}">${esc(v.patente)} · ${esc(v.modelo)}</option>`).join('');
 $('vehiculo-caso').onchange=()=>{
   const v=vehiculos.find(item=>Number(item.id_vehiculo)===Number($('vehiculo-caso').value));
   const org=$('org-caso');
   if(v?.estado_vinculo==='autorizado'&&Date.parse(v.vence_revision_en)>Date.now()&&Array.from(org.options).some(o=>Number(o.value)===Number(v.id_organizacion_revision)))org.value=String(v.id_organizacion_revision);
 };
 $('lista-casos').innerHTML=casos.length?casos.map(tarjetaCasoPersonal).join(''):'<p class="empty">Tus reportes aparecerán aquí después de registrarlos.</p>';
 const admin=perfil.roles.includes('administrador');$('administracion').hidden=!admin;
 for(const boton of $('lista-vehiculos').querySelectorAll('button[data-revision-vinculo]')){
   boton.onclick=async()=>{
     const form=$('form-solicitar-vinculo');
     form.reset();
     form.elements.vehiculo.value=boton.dataset.revisionVinculo;
     const select=form.elements.organizacion;
     select.replaceChildren(...Array.from($('org-caso').options,op=>new Option(op.text,op.value)));
     const revision=vehiculos.find(v=>Number(v.id_vehiculo)===Number(boton.dataset.revisionVinculo));
     select.disabled=revision.id_organizacion_revision!=null;
     if(select.disabled)select.value=String(revision.id_organizacion_revision);
     form.hidden=false;select.focus();
   };
 }
 await solicitudesCiudadanas(estado.puede_participar);

}
function tarjetaCasoPersonal(c){
 const id=Number(c.id_caso);
 const retirar=c.colaboracion_consentida_en?`<button type="button" data-accion-caso="retirar_consentimiento" data-caso="${id}">Retirar consentimiento</button>`:'';
 const recuperar=`<button type="button" data-accion-caso="informar_recuperacion" data-caso="${id}">Informar recuperación</button>`;
 return `<article class="item"><b>${esc(c.folio)} · ${esc(c.patente)}</b><p>${esc(c.zona)} · ${esc(new Date(c.fecha_hecho).toLocaleString('es-CL'))}</p><span class="pill">${esc(c.estado.replaceAll('_',' '))}</span><p>Antecedentes de denuncia: ${esc(c.denuncia_estado.replaceAll('_',' '))}.</p>${c.estado!=='cerrado'?`<div class="row">${retirar}${recuperar}</div>`:''}</article>`;
}
$('lista-casos').onclick=async event=>{
 const button=event.target.closest('button[data-accion-caso]');
 if(!button)return;
 const accion=button.dataset.accionCaso;
 const cid=Number(button.dataset.caso);
 const pregunta=accion==='informar_recuperacion'?'¿Informar que recuperaste el vehículo? La organización revisará el aviso y se suspenderá la difusión.':'¿Retirar la autorización para difundir esta alerta?';
 if(!confirm(pregunta))return;
 button.disabled=true;
 try{
   await api('/mis-casos/'+cid+'/alerta',{method:'POST',body:{accion}});
   await cargar();
   aviso('Información guardada en el expediente.');
 }catch(error){aviso(error.message,true);}
 finally{button.disabled=false;}
};
accion('pedir-correo',async()=>{const r=await api('/identidad/correo/solicitar',{method:'POST'});correoCanal=r.canal||'prueba';if(r.token_demo){$('token-correo').value=r.token_demo;$('correo-demo').textContent='Código beta preparado. No se envió un correo.';$('correo-demo').hidden=false}else {$('correo-demo').textContent=r.mensaje;$('correo-demo').hidden=false;aviso(r.mensaje)}});
formulario('form-correo',async()=>{await api('/identidad/correo/confirmar',{method:'POST',body:{token:$('token-correo').value}});$('token-correo').value='';$('correo-demo').hidden=true;await cargar();aviso(correoCanal==='correo'?'Correo confirmado con el código recibido.':'Paso de correo completado en la beta.')});
accion('pedir-sms',async()=>{const r=await api('/identidad/telefono/solicitar',{method:'POST',body:{telefono:$('telefono').value}});desafio=r.id_desafio;$('codigo-sms').value=r.codigo_demo||'';$('sms-demo').textContent='Código beta: '+r.codigo_demo+'. No se envió un SMS.';$('sms-demo').hidden=false});
formulario('form-telefono',async()=>{if(!desafio)throw new Error('Primero solicita un código.');await api('/identidad/telefono/confirmar',{method:'POST',body:{id_desafio:desafio,codigo:$('codigo-sms').value}});desafio=null;$('codigo-sms').value='';$('sms-demo').hidden=true;await cargar();aviso('Pasos beta completados. Ya puedes registrar vehículos y reportes.')});
function mostrarRevisionAlta(){
 const activar=$('verificar-vehiculo').checked;
 $('revision-alta').hidden=!activar;
 for(const campo of [vehiculo.organizacion_revision,vehiculo.padron]){campo.disabled=!activar;campo.required=activar;}
 if(!activar)vehiculo.padron.value='';
 $('form-vehiculo').querySelector('.primary').textContent=activar?'Guardar y enviar a revisión':'Guardar vehículo';
}
$('verificar-vehiculo').onchange=mostrarRevisionAlta;
formulario('form-vehiculo',async e=>{
 const {organizacion_revision, padron, ...datos}=Object.fromEntries(new FormData(e.target));
 datos.anio=Number(datos.anio);datos.patente=datos.patente.toUpperCase().replace(/[ .-]/g,'');
 const formato=catalogoVehicular.formatos[datos.tipo_vehiculo==='motocicleta'?'motocicleta':'cuatro_ruedas'];
 if(!new RegExp('^'+formato+'$').test(datos.patente)){
   vehiculo.patente.setCustomValidity('Revisa la patente para este tipo de vehículo.');vehiculo.patente.reportValidity();return;
 }
 if($('verificar-vehiculo').checked)datos.revision={id_organizacion:Number(organizacion_revision),padron_base64:await imagenPrivada(vehiculo.padron)};
 const resultado=await api('/vehiculos',{method:'POST',body:datos});
 e.target.reset();mostrarRevisionAlta();opcionesVehiculo();await cargar();aviso(resultado.mensaje);
});
formulario('form-solicitar-vinculo',async e=>{
 const form=e.target;
 await api('/vehiculos/'+Number(form.elements.vehiculo.value)+'/revision-vinculo',
   {method:'POST',body:{id_organizacion:Number(form.elements.organizacion.value),padron_base64:await imagenPrivada(form.elements.padron)}});
 form.reset();form.hidden=true;
 await cargar();
 aviso('Padrón enviado al supervisor.');
});
formulario('form-caso',async e=>{const d={id_vehiculo:Number($('vehiculo-caso').value),id_organizacion:Number($('org-caso').value),fecha_hecho:new Date($('fecha-caso').value).toISOString(),zona:$('zona-caso').value,descripcion:$('descripcion').value,latitud:Number($('latitud').value),longitud:Number($('longitud').value)};
 // Un fallo de red conserva la clave para no duplicar el mismo envío.
 d.solicitar_colaboracion=$('autoriza-caso').checked;
 d.confirmar_sustraccion=$('confirma-sustraccion').checked;
 d.autorizar_foto_publica=$('autoriza-foto-caso').checked;
 if(d.autorizar_foto_publica&&(!d.solicitar_colaboracion||!$('foto-caso').files.length))throw Error('Para autorizar la foto, adjunta una imagen del vehículo y solicita colaboración ciudadana.');
 const foto=await imagenPrivada($('foto-caso'));if(foto)d.foto_base64=foto;
 const firma=JSON.stringify(d);if(!envioCaso||envioCaso.firma!==firma)envioCaso={firma,clave:crypto.randomUUID()};
 const r=await api('/casos',{method:'POST',body:d,headers:{'Idempotency-Key':envioCaso.clave}});
 envioCaso=null;e.target.reset();limpiarFotoReporte();RutaMapa.quitarSeleccion();
 try{await cargar();}finally{aviso('Reporte '+r.folio+' recibido. '+(r.siguiente_paso||'Abre el seguimiento para revisar el estado.'));}
});
formulario('form-sancion',async e=>{await api('/moderacion/usuarios/'+Number($('usuario-sancion').value)+'/sanciones',{method:'POST',body:{accion:'suspension',motivo:$('motivo-sancion').value}});e.target.reset();aviso('Cuenta suspendida y sesiones revocadas. Acción registrada.')});
$('bandeja').addEventListener('click',async e=>{const b=e.target.closest('.revisar');if(!b)return;const id=Number(b.dataset.id);b.disabled=true;try{await api('/gestion/casos/'+id+'/revision',{method:'POST',body:{estado:'en_revision',motivo:$('revision-'+id).value}});await cargar();aviso('Estado actualizado. El reporte continúa privado.')}catch(err){aviso(err.message,true)}finally{b.disabled=false}});

formulario('form-recuperacion',async()=>{
 const r=await api('/cuentas/recuperacion',{method:'POST',body:{correo:$('correo-recuperacion').value}});
 $('aviso-recuperacion').textContent=r.mensaje;
 if(r.token_prueba){$('token-recuperacion').value=r.token_prueba;$('aviso-recuperacion').textContent='Recuperación beta: código mostrado aquí. No se envió un correo.';}
});
formulario('form-nueva-clave',async()=>{
 await api('/cuentas/recuperacion/confirmar',{method:'POST',body:{token:$('token-recuperacion').value,nueva_clave:$('nueva-clave').value}});
 limpiarAlta();token='';perfil=null;$('token-recuperacion').value='';$('nueva-clave').value='';
 aviso('Contraseña actualizada. Inicia sesión con tu nueva contraseña.');
});

let intentoTestigo;
async function cargarTestigos(){
 const [orgs,mios]=await Promise.all([api('/organizaciones'),api('/mis-avisos-testigo')]);
 for(const select of [$('org-caso'),$('form-testigo').elements.id_organizacion,vehiculo.organizacion_revision]){
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
let solicitudElegida=null, intentoAporte=null, participacion=false, consultaSolicitudes=0;
let cargaFotos=null,fotoReporteUrl=null,ultimaLista='';
const fotosColaboracion=new Map(),solicitudesVisibles=new Map();
function limpiarFotoReporte(){
 if(fotoReporteUrl)URL.revokeObjectURL(fotoReporteUrl);fotoReporteUrl=null;
 $('foto-caso').value='';$('foto-caso-vista').replaceChildren();$('foto-caso-vista').hidden=true;
 $('autoriza-foto-caso').checked=false;$('autoriza-foto-caso').disabled=true;
}
function actualizarConsentimientoFoto(){
 if(fotoReporteUrl)URL.revokeObjectURL(fotoReporteUrl);fotoReporteUrl=null;
 const file=$('foto-caso').files[0],vista=$('foto-caso-vista'),consentimiento=$('autoriza-foto-caso');
 vista.replaceChildren();vista.hidden=!file;
 if(file){fotoReporteUrl=URL.createObjectURL(file);const img=document.createElement('img');img.src=fotoReporteUrl;img.alt='Foto seleccionada para este reporte';vista.append(img);}
 consentimiento.disabled=!file||!$('autoriza-caso').checked;
 if(consentimiento.disabled)consentimiento.checked=false;
}
$('foto-caso').onchange=()=>{$('autoriza-foto-caso').checked=false;actualizarConsentimientoFoto();};
$('autoriza-caso').onchange=actualizarConsentimientoFoto;
function limpiarFotosColaboracion(){
 ultimaLista='';consultaSolicitudes++;cargaFotos?.abort();cargaFotos=null;
 fotosColaboracion.forEach(url=>URL.revokeObjectURL(url));fotosColaboracion.clear();solicitudesVisibles.clear();
 $('solicitudes-ciudadanas').replaceChildren();$('foto-vehiculo-aporte').replaceChildren();
}
function imagenColaboracion(s){
 const url=fotosColaboracion.get(Number(s.id_solicitud_colaboracion));
 if(url)return `<figure class="vehicle-visual"><img src="${esc(url)}" alt="Foto del titular · ${esc(s.patente)}"><figcaption>Foto del titular</figcaption></figure>`;
 const model=[s.marca,s.modelo].filter(Boolean).join(' ');
 const bmw=/^BMW\s+320(?:\s?i)?$/i.test(model) && (!s.anio || (s.anio>=2012 && s.anio<=2018));
 const ref=bmw?`<details><summary>Ver BMW 320i F30 de ejemplo</summary><img src="/bmw_320i_f30.jpg" loading="lazy" alt="Referencia de catálogo BMW 320i F30"><small><a href="https://commons.wikimedia.org/wiki/File:BMW_320i_(F30)_front.JPG">Tokumeigakarinoaoshima</a> · <a href="https://creativecommons.org/licenses/by-sa/4.0/">CC BY-SA 4.0</a></small></details>`:'';
 return `<div class="vehicle-visual"><strong>${esc(model)}</strong><p>${s.foto_disponible?'Foto del titular solicitada':'Sin foto pública del titular'}</p>${s.foto_disponible?'':ref}</div>`;
}
function mostrarImagenColaboracion(container,s){
 if(!container)return;
 container.innerHTML=imagenColaboracion(s);
 const img=container.querySelector('img'),sid=Number(s.id_solicitud_colaboracion),url=fotosColaboracion.get(sid);
 if(img&&url)img.onerror=()=>{
   if(fotosColaboracion.get(sid)!==url)return;
   fotosColaboracion.delete(sid);URL.revokeObjectURL(url);
   mostrarImagenColaboracion($('foto-solicitud-'+sid),s);
   if(solicitudElegida===sid)mostrarImagenColaboracion($('foto-vehiculo-aporte'),s);
 };
}
function cerrarAporte(){
 solicitudElegida=null;intentoAporte=null;
 $('aporte-web').reset();$('aporte-web').hidden=true;$('foto-vehiculo-aporte').replaceChildren();
}
function estadoAlerta(s){
 const nombre={provisional:'Alerta ciudadana provisional',encargo_comprobado:'Encargo comprobado',revisada:'Publicación revisada'}[s.modo_alerta]||'Solicitud activa';
 const edad=Math.max(0,Math.floor((Date.now()-Date.parse(s.reportada_en))/60000));
 const subtitulo={
   encontrado:'Resultado registrado por el operador.',
   sin_resultado:'La consulta no encontró un encargo en ese momento.',
   no_disponible:'La fuente no estaba disponible durante la consulta.'
 }[s.encargo_resultado]||'Encargo policial pendiente de comprobación.';
 return `<p class="alert-card-state ${s.modo_alerta==='provisional'?'provisional':''}"><strong>${s.simulada?'SIMULACIÓN · ':''}${esc(nombre)}</strong><br>${esc(subtitulo)}${Number.isFinite(edad)?' · Reportado hace '+edad+' min':''}</p>`;
}
async function imagenPrivada(input){
 const file=input.files[0];if(!file)return null;
 if(file.size>2097152)throw Error('La imagen supera 2 MB.');
 return new Promise((resolve,reject)=>{const reader=new FileReader();reader.onerror=()=>reject(Error('No se pudo leer la imagen.'));reader.onload=()=>resolve(String(reader.result).split(',')[1]);reader.readAsDataURL(file);});
}
async function solicitudesCiudadanas(permitido){
 participacion=permitido;const actual=token,turno=++consultaSolicitudes;
 if(!actual){cerrarAporte();return;}
 const d=await api('/colaboracion');
 if(actual!==token||turno!==consultaSolicitudes)return;
 $('alertas-actualizacion').textContent=(d.demo_alertas?'DEMOSTRACIÓN AISLADA · ':'')+'Actualizado '+new Date().toLocaleTimeString('es-CL');
 const items=[...d.cercanos,...d.otras_zonas];
 const signature=JSON.stringify([permitido,items]);
 if(ultimaLista===signature)return;
 cargaFotos?.abort();
 const controller=new AbortController();cargaFotos=controller;
 fotosColaboracion.forEach(url=>URL.revokeObjectURL(url));
 fotosColaboracion.clear();solicitudesVisibles.clear();ultimaLista=signature;
 for(const s of items)solicitudesVisibles.set(Number(s.id_solicitud_colaboracion),s);
 $('solicitudes-ciudadanas').innerHTML=items.length?items.map(s=>`<article class="item collaboration-card"><div id="foto-solicitud-${Number(s.id_solicitud_colaboracion)}">${imagenColaboracion(s)}</div><div>${estadoAlerta(s)}<b>${esc(s.patente)} · ${esc(s.marca)} ${esc(s.modelo)}</b><p>${esc(nombresTipo[s.tipo_vehiculo]||'Vehículo')} · ${esc(s.color)} · ${esc(s.zona_publicable)}</p><p>${esc(s.texto_aprobado)}</p><button type="button" data-solicitud="${Number(s.id_solicitud_colaboracion)}" data-patente="${esc(s.patente)}" ${permitido&&!s.es_mi_caso?'':'disabled'}>${s.es_mi_caso?'Tu caso · usa el seguimiento':'Aportar información y foto'}</button></div></article>`).join(''):'<p class="empty">Sin solicitudes vigentes. Aquí aparecen las alertas activas con autorización del titular.</p>';
 if(!permitido&&items.length)$('solicitudes-ciudadanas').insertAdjacentHTML('beforeend','<p>Verifica tu cuenta para enviar avistamientos.</p>');
 const elegida=solicitudesVisibles.get(solicitudElegida);
 if(solicitudElegida&&(!elegida||!permitido||elegida.es_mi_caso))cerrarAporte();
 else if(elegida)mostrarImagenColaboracion($('foto-vehiculo-aporte'),elegida);
 await Promise.all(items.map(async s=>{
   const sid=Number(s.id_solicitud_colaboracion),ruta='/colaboracion/'+sid+'/foto-vehiculo';
   if(!s.foto_disponible||s.foto_url!==ruta)return;
   try{
     const blob=await api(ruta,{binary:true,signal:controller.signal});
     if(actual!==token||controller.signal.aborted)return;
     if(!['image/jpeg','image/png','image/webp'].includes(blob.type))return;
     fotosColaboracion.set(sid,URL.createObjectURL(blob));
     mostrarImagenColaboracion($('foto-solicitud-'+sid),s);
     if(solicitudElegida===sid)mostrarImagenColaboracion($('foto-vehiculo-aporte'),s);
    }catch(err){
     if(actual!==token||controller.signal.aborted)return;
     ultimaLista=''; // Reintentar la descarga en la próxima consulta.
     const message='No se pudo cargar la foto del titular.';
     const card=$('foto-solicitud-'+sid);if(card)card.textContent=message;
     if(solicitudElegida===sid)$('foto-vehiculo-aporte').textContent=message;
   }
 }));
}
accion('actualizar-solicitudes',()=>solicitudesCiudadanas(participacion));
let actualizandoAlertas=false;
setInterval(async()=>{
 if(!token||document.hidden||solicitudElegida||actualizandoAlertas)return;
 actualizandoAlertas=true;
 try{await solicitudesCiudadanas(participacion);}
 catch(error){if(token)$('alertas-actualizacion').textContent='Conexión interrumpida · reintentando';}
 finally{actualizandoAlertas=false;}
},5000);
$('solicitudes-ciudadanas').onclick=e=>{
 const b=e.target.closest('button[data-solicitud]');if(!b)return;
 const s=solicitudesVisibles.get(Number(b.dataset.solicitud));if(!s||!participacion||s.es_mi_caso)return;
 cerrarAporte();solicitudElegida=Number(s.id_solicitud_colaboracion);$('vehiculo-observado').textContent='Avistamiento · '+s.patente;
 mostrarImagenColaboracion($('foto-vehiculo-aporte'),s);
 $('aporte-web').hidden=false;$('aporte-web').elements.zona.focus();
};
accion('gps-aporte',async()=>{
 const sesion=token,sid=solicitudElegida;
 const p=await new Promise((res,rej)=>navigator.geolocation.getCurrentPosition(res,rej,{enableHighAccuracy:true,timeout:15000,maximumAge:0}));
 if(sesion!==token||sid!==solicitudElegida)return;
 const f=$('aporte-web').elements;f.lat.value=p.coords.latitude;f.lon.value=p.coords.longitude;
});
formulario('aporte-web',async e=>{
 const f=e.target.elements;
 const sid=solicitudElegida;if(!sid)return;
 const d={zona:f.zona.value,observado_en:new Date(f.fecha.value).toISOString(),descripcion:f.descripcion.value,latitud:Number(f.lat.value),longitud:Number(f.lon.value)};
 const foto=await imagenPrivada(f.foto);if(foto)d.foto_base64=foto;
 const firma=sid+JSON.stringify(d);if(intentoAporte?.firma!==firma)intentoAporte={firma,clave:crypto.randomUUID()};
 await api('/colaboracion/'+sid+'/avistamientos',{method:'POST',body:d,headers:{'Idempotency-Key':intentoAporte.clave}});
 cerrarAporte();aviso('Avistamiento recibido para revisión.');
});
