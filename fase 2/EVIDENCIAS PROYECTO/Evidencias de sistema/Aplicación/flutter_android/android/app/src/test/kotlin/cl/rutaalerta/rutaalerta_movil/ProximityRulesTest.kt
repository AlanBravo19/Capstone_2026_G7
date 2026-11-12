package cl.rutaalerta.rutaalerta_movil
import org.junit.Assert.*
import org.junit.Test

class ProximityRulesTest {
 private val now=10000000L
 private val n=TerritorialNotice("ficticio",-36.82,-73.05,1500.0,now+3600000L,"Sector ficticio","Fuente ficticia","https://example.invalid","2026-11-12")
 @Test fun nearbyRecentFix(){assertTrue(ProximityRules.eligible(n,-36.82,-73.05,20.0,now-1000,now,now+7200000L,0,0))}
 @Test fun staleFixNeverAlerts(){assertFalse(ProximityRules.eligible(n,-36.82,-73.05,20.0,now-31000,now,now+7200000L,0,0))}
 @Test fun poorAccuracyNeverAlerts(){assertFalse(ProximityRules.eligible(n,-36.82,-73.05,1000.0,now,now,now+7200000L,0,0))}
 @Test fun expiredCacheNeverAlerts(){assertFalse(ProximityRules.eligible(n,-36.82,-73.05,20.0,now,now,now-1,0,0))}
 @Test fun expiredNoticeNeverAlerts(){assertFalse(ProximityRules.eligible(n.copy(expires=now-1),-36.82,-73.05,20.0,now,now,now+7200000L,0,0))}
 @Test fun farAwayDoesNotAlert(){assertFalse(ProximityRules.eligible(n,-33.44,-70.66,20.0,now,now,now+7200000L,0,0))}
 @Test fun cooldownPerNoticeAndGlobal(){assertFalse(ProximityRules.eligible(n,-36.82,-73.05,20.0,now,now,now+7200000L,now-1000,0));assertFalse(ProximityRules.eligible(n,-36.82,-73.05,20.0,now,now,now+7200000L,0,now-1000))}
 @Test fun invalidFixDoesNotAlert(){assertFalse(ProximityRules.eligible(n,Double.NaN,-73.05,20.0,now,now,now+7200000L,0,0))}
}
