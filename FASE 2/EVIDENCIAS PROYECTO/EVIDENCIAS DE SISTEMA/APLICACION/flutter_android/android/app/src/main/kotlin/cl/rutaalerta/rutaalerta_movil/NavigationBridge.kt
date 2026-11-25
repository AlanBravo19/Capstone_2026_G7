package cl.rutaalerta.rutaalerta_movil

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class NavigationBridge(private val activity:Activity) {
 private var locationListener:LocationListener?=null
 private var locationResult:MethodChannel.Result?=null
 private val handler=Handler(Looper.getMainLooper())
 fun close(){finishLocation(null,"cancelled")}
 fun handle(call:MethodCall,result:MethodChannel.Result){
  when(call.method){
   "openAuthenticator" -> {
    val uri=Uri.parse(call.argument<String>("uri") ?: "")
    if(uri.scheme!="otpauth" || uri.host!="totp" || uri.getQueryParameter("issuer")!="RutaAlerta"){
     result.error("setup","Solicita una nueva configuración del autenticador.",null);return
    }
    val intent=Intent(Intent.ACTION_VIEW,uri)
    if(intent.resolveActivity(activity.packageManager)==null){
     result.error("no_authenticator","No encontramos un autenticador que abra este enlace. Usa la opción de clave manual en tu aplicación autenticadora.",null);return
    }
    try{activity.startActivity(Intent.createChooser(intent,"Elige tu aplicación autenticadora"));result.success(null)}
    catch(_:Exception){result.error("authenticator","No se pudo abrir el autenticador. Usa la opción de clave manual.",null)}
   }
   "openNavigation" -> {
    val lat=call.argument<Number>("lat")?.toDouble();val lon=call.argument<Number>("lon")?.toDouble()
    val provider=call.argument<String>("provider")
    if(!valid(lat,lon) || provider !in listOf("google","waze")){result.error("invalid","Destino inválido.",null);return}
    val uri=if(provider=="google") {
     val b=Uri.parse("https://www.google.com/maps/dir/").buildUpon().appendQueryParameter("api","1").appendQueryParameter("destination","$lat,$lon").appendQueryParameter("travelmode","driving").appendQueryParameter("dir_action","navigate")
     val a=call.argument<Number>("originLat")?.toDouble();val o=call.argument<Number>("originLon")?.toDouble()
     if(valid(a,o))b.appendQueryParameter("origin","$a,$o")
     b.build()
    }else Uri.parse("https://waze.com/ul").buildUpon().appendQueryParameter("ll","$lat,$lon").appendQueryParameter("navigate","yes").build()
    try { activity.startActivity(Intent(Intent.ACTION_VIEW,uri));result.success(null) }catch(_:Exception){result.error("browser","No se pudo abrir la aplicación de navegación.",null)}
   }
   "openSource" -> {
    val uri=Uri.parse(call.argument<String>("url") ?: "")
    if(uri.scheme!="https" || uri.host.isNullOrEmpty() || uri.userInfo!=null){result.error("invalid","Enlace no válido.",null);return}
    try{activity.startActivity(Intent(Intent.ACTION_VIEW,uri));result.success(null)}catch(_:Exception){result.error("browser","No hay navegador disponible.",null)}
   }
   "geocode" -> {
    val query=call.argument<String>("query")?.trim() ?: ""
    if(query.length !in 5..300 || !Geocoder.isPresent()){result.error("geocoder","No se pudo buscar la dirección. Selecciona el lugar en el mapa.",null);return}
    Thread {
     try {
      @Suppress("DEPRECATION") val found=Geocoder(activity,Locale("es","CL")).getFromLocationName(query,5) ?: emptyList()
      val values=found.map {mapOf("lat" to it.latitude,"lon" to it.longitude,"address" to (it.getAddressLine(0) ?: query))}
      activity.runOnUiThread{result.success(values)}
     }catch(_:Exception){activity.runOnUiThread{result.error("geocoder","La búsqueda no está disponible. Selecciona el punto en el mapa.",null)}}
    }.start()
   }
   "reverseGeocode" -> {
    val lat=call.argument<Number>("lat")?.toDouble()
    val lon=call.argument<Number>("lon")?.toDouble()
    if(!valid(lat,lon) || !Geocoder.isPresent()){result.success(emptyList<String>());return}
    Thread {
     val names=try {
      @Suppress("DEPRECATION") val found=Geocoder(activity,Locale("es","CL")).getFromLocation(lat!!,lon!!,1)?.firstOrNull()
      listOfNotNull(found?.subLocality,found?.locality,found?.subAdminArea).distinct()
     }catch(_:Exception){emptyList()}
     activity.runOnUiThread{result.success(names)}
    }.start()
   }
   "location" -> {
    if(locationResult!=null){result.error("busy","Hay una búsqueda de ubicación en curso.",null);return}
    val fine=activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED
    val coarse=activity.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)==PackageManager.PERMISSION_GRANTED
    if(!fine&&!coarse){result.error("permission","Autoriza la ubicación del teléfono.",null);return}
    val manager=activity.getSystemService(LocationManager::class.java)
    try {
     val providers=listOf(LocationManager.GPS_PROVIDER,LocationManager.NETWORK_PROVIDER).filter{manager.isProviderEnabled(it) && (fine || it!=LocationManager.GPS_PROVIDER)}
     val recent=providers.mapNotNull{manager.getLastKnownLocation(it)}.filter{fresh(it)}.minByOrNull{it.accuracy}
     if(recent!=null){result.success(map(recent));return}
     if(providers.isEmpty()){result.error("location","Activa el GPS del teléfono.",null);return}
     locationResult=result
     locationListener=object:LocationListener{
      override fun onLocationChanged(location:Location){if(fresh(location))finishLocation(location)}
      override fun onProviderEnabled(provider:String){}
      override fun onProviderDisabled(provider:String){}
      @Deprecated("Compatibilidad") override fun onStatusChanged(provider:String?,status:Int,extras:Bundle?){}
     }
     for(provider in providers)manager.requestLocationUpdates(provider,1000L,0f,locationListener!!,Looper.getMainLooper())
     handler.postDelayed({if(locationResult!=null)finishLocation(null,"timeout")},20000)
    }catch(_:Exception){if(locationResult==null)result.error("location","No se pudo obtener una ubicación actual.",null)else finishLocation(null,"location")}
   }
   else -> result.notImplemented()
  }
 }
 private fun valid(a:Double?,b:Double?)=a!=null&&b!=null&&a.isFinite()&&b.isFinite()&&a in -90.0..90.0&&b in -180.0..180.0
 private fun fresh(loc:Location):Boolean {val age=System.currentTimeMillis()-loc.time;return age in 0L..30000L}
 private fun map(loc:Location)=mapOf("lat" to loc.latitude,"lon" to loc.longitude,"accuracy" to loc.accuracy.toDouble(),"timestamp" to loc.time)
 private fun finishLocation(loc:Location?,code:String?=null){
  val result=locationResult;locationResult=null
  locationListener?.let{try{activity.getSystemService(LocationManager::class.java).removeUpdates(it)}catch(_:Exception){}};locationListener=null
  if(result!=null){if(loc!=null)result.success(map(loc))else result.error(code ?: "location","No se obtuvo una posición reciente. Intenta al aire libre.",null)}
 }
}
