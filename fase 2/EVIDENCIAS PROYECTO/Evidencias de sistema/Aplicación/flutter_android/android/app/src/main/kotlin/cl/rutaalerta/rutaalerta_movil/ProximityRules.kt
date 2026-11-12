package cl.rutaalerta.rutaalerta_movil
import kotlin.math.*

data class TerritorialNotice(val id:String,val lat:Double,val lon:Double,val radius:Double,val expires:Long,val zone:String,val source:String,val url:String,val published:String)
/** Reglas geométricas, no estima probabilidad ni certifica seguridad. */
object ProximityRules {
 fun distance(a:Double,b:Double,c:Double,d:Double):Double {
  val r=PI/180;val p=(c-a)*r;val q=(d-b)*r
  val h=sin(p/2).pow(2)+cos(a*r)*cos(c*r)*sin(q/2).pow(2)
  return 6371000*2*atan2(sqrt(h.coerceIn(0.0,1.0)),sqrt((1-h).coerceIn(0.0,1.0)))
 }
 fun eligible(n:TerritorialNotice,lat:Double,lon:Double,accuracy:Double,fixTime:Long,now:Long,cacheUntil:Long,last:Long,lastAny:Long):Boolean {
  if(!listOf(lat,lon,accuracy,n.lat,n.lon,n.radius).all{it.isFinite()})return false
  if(lat !in -90.0..90.0 || lon !in -180.0..180.0 || accuracy !in 0.0..250.0 || accuracy>n.radius/2)return false
  if(now-fixTime !in 0L..30000L || now>=cacheUntil || now>=n.expires)return false
  if(last>0 && now-last<1800000 || lastAny>0 && now-lastAny<120000)return false
  return distance(lat,lon,n.lat,n.lon)<=n.radius
 }
}
