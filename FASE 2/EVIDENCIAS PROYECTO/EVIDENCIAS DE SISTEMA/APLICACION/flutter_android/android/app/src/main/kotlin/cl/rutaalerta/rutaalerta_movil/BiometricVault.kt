package cl.rutaalerta.rutaalerta_movil

import android.app.Activity
import android.content.Intent
import android.provider.Settings
import android.hardware.biometrics.BiometricPrompt
import android.hardware.biometrics.BiometricManager
import android.hardware.fingerprint.FingerprintManager
import android.os.Build
import android.os.CancellationSignal
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import org.json.JSONObject

/** El sensor y las plantillas pertenecen a Android; sólo se cifra una sesión ya autenticada. */
class BiometricVault(private val activity: Activity) {
    private val alias = "rutaalerta_biometria_v1"
    private val prefs = activity.getSharedPreferences("vault_privado", Activity.MODE_PRIVATE)
    private var cancellation: CancellationSignal? = null
    private var pending: MethodChannel.Result? = null
    private val aad = "RutaAlertaVaultV1".toByteArray(Charsets.UTF_8)
    private fun store() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    private fun impediment(): String? {
        if (Build.VERSION.SDK_INT < 28) return "Este teléfono necesita Android 9 o posterior para esta función."
        return try {
            if (Build.VERSION.SDK_INT >= 29) {
                val manager = activity.getSystemService(BiometricManager::class.java)
                val status = if (Build.VERSION.SDK_INT >= 30) manager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) else manager.canAuthenticate()
                when(status) {
                    BiometricManager.BIOMETRIC_SUCCESS -> null
                    BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "Registra una huella en los ajustes de seguridad del teléfono y vuelve aquí."
                    BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> "Android no encuentra un sensor compatible con este acceso."
                    BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "El sensor no está disponible en este momento. Inténtalo de nuevo."
                    else -> "Android no permite usar biometría fuerte en este momento (código $status)."
                }
            } else activity.getSystemService(FingerprintManager::class.java).let {
                when {
                    it?.isHardwareDetected != true -> "Android no encuentra un lector de huellas."
                    !it.hasEnrolledFingerprints() -> "Registra una huella en los ajustes de seguridad del teléfono y vuelve aquí."
                    else -> null
                }
            }
        } catch (_: Exception) { "No se pudo consultar el lector. Revisa los ajustes de seguridad de Android." }
    }
    private val savedAlias get() = prefs.getString("alias",alias) ?: alias
    fun clear() { cancel(); prefs.edit().clear().apply(); try { store().apply { deleteEntry(alias);deleteEntry(alias+"_b") } } catch (_: Exception) {} }
    fun cancel() { cancellation?.cancel() }
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when(call.method) {
            "status" -> {
                val reason=impediment()
                result.success(mapOf("available" to (reason==null), "reason" to reason, "saved" to (prefs.contains("blob") && try { store().containsAlias(savedAlias) } catch (_: Exception) { false })))
            }
            "settings" -> try {activity.startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS));result.success(null)}
                catch (_:Exception){result.error("settings","Abre Ajustes → Seguridad en Android.",null)}
            "clear" -> { clear(); result.success(null) }
            "save", "unlock" -> authenticate(call, result)
            else -> result.notImplemented()
        }
    }
    @Suppress("DEPRECATION")
    private fun authenticate(call: MethodCall, result: MethodChannel.Result) {
        val reason=impediment()
        if (Build.VERSION.SDK_INT < 28 || reason!=null) { result.error("unavailable", reason, null); return }
        if (pending != null) { result.error("busy", "Ya hay una verificación biométrica en curso.", null); return }
        val saving=call.method=="save"
        val payload=call.argument<String>("payload")
        val prior=savedAlias
        val keyAlias=if(saving && prior==alias) alias+"_b" else if(saving) alias else prior
        if(saving && (payload==null || payload.length>12000)) { result.error("invalid", "Sesión no válida para guardar.", null); return }
        pending=result
        fun finish(value:Any?,code:String?=null,message:String?=null) {
            if(pending !== result) return
            pending=null;cancellation=null
            if(code==null)result.success(value) else result.error(code,message,null)
        }
        try {
            val ks=store()
            if(saving) {
                if(ks.containsAlias(keyAlias)) ks.deleteEntry(keyAlias)
                val builder=KeyGenParameterSpec.Builder(keyAlias,KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setUserAuthenticationRequired(true).setInvalidatedByBiometricEnrollment(true)
                if(Build.VERSION.SDK_INT>=30) builder.setUserAuthenticationParameters(0,KeyProperties.AUTH_BIOMETRIC_STRONG)
                else builder.setUserAuthenticationValidityDurationSeconds(-1)
                KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore").apply { init(builder.build());generateKey() }
            }
            val key=ks.getKey(keyAlias,null) as? SecretKey ?: throw java.security.UnrecoverableKeyException()
            val cipher=Cipher.getInstance("AES/GCM/NoPadding")
            if(saving) cipher.init(Cipher.ENCRYPT_MODE,key)
            else cipher.init(Cipher.DECRYPT_MODE,key,GCMParameterSpec(128,Base64.decode(prefs.getString("iv",null),Base64.NO_WRAP)))
            cancellation=CancellationSignal()
            val builder=BiometricPrompt.Builder(activity).setTitle(if(saving) "Activar acceso biométrico" else "Ingresar a RutaAlerta")
                .setSubtitle("Confirma con la biometría de este teléfono")
                .setNegativeButton("Usar contraseña",activity.mainExecutor) { _,_ -> finish(null,"cancelled","Verificación cancelada. Usa tu contraseña.") }
            if(Build.VERSION.SDK_INT>=30) builder.setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            builder.build().authenticate(BiometricPrompt.CryptoObject(cipher),cancellation!!,activity.mainExecutor,object:BiometricPrompt.AuthenticationCallback(){
                override fun onAuthenticationSucceeded(auth:BiometricPrompt.AuthenticationResult) {
                    if(pending !== result || cancellation?.isCanceled != false) return
                    try {
                        val c=auth.cryptoObject?.cipher ?: throw IllegalStateException()
                        c.updateAAD(aad)
                        if(saving) {
                            val blob=c.doFinal(payload!!.toByteArray(Charsets.UTF_8))
                            prefs.edit().putString("alias",keyAlias).putString("blob",Base64.encodeToString(blob,Base64.NO_WRAP)).putString("iv",Base64.encodeToString(c.iv,Base64.NO_WRAP)).apply()
                            try { ks.deleteEntry(prior) } catch (_:Exception) {}
                            finish(true)
                        }else {
                            val data=c.doFinal(Base64.decode(prefs.getString("blob",null),Base64.NO_WRAP)).toString(Charsets.UTF_8)
                            JSONObject(data) // Validar estructura sin registrar el contenido.
                            finish(data)
                        }
                    }catch(_:Exception){if(!saving)clear();finish(null,"crypto",if(saving) "El teléfono reconoció la biometría, pero no pudo guardar la sesión cifrada. Reintenta la activación." else "No se pudo abrir la sesión cifrada. Ingresa con contraseña y vuelve a activar la huella.")}
                }
                override fun onAuthenticationError(code:Int,message:CharSequence){
                    finish(null,"android_$code",when(code){
                        BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT -> "Demasiados intentos. Espera y vuelve a probar la huella."
                        BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT_PERMANENT -> "Android bloqueó el lector. Desbloquea el teléfono con su PIN y vuelve a intentarlo."
                        BiometricPrompt.BIOMETRIC_ERROR_USER_CANCELED, BiometricPrompt.BIOMETRIC_ERROR_CANCELED -> "Verificación cancelada. Puedes volver a intentarlo."
                        else -> "$message (Android $code)"
                    })
                }
                override fun onAuthenticationFailed(){ /* Android mantiene su diálogo para un nuevo intento. */ }
            })
        } catch(_:android.security.keystore.KeyPermanentlyInvalidatedException) {
            if(!saving)clear();finish(null,"invalidated","Android invalidó la clave de este teléfono. Ingresa con contraseña y activa la huella otra vez.")
        } catch(_:java.security.UnrecoverableKeyException) {
            if(!saving)clear();finish(null,"missing","No se encontró la clave guardada. Ingresa con contraseña y activa la huella otra vez.")
        } catch(e:Exception) {
            finish(null,"crypto_setup","Android no pudo preparar la clave biométrica (${e.javaClass.simpleName}). Desbloquea el teléfono y vuelve a intentarlo.")
        }
    }
}
