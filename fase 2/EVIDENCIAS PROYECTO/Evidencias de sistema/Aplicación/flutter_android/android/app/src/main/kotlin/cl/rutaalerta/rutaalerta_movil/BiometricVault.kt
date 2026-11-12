package cl.rutaalerta.rutaalerta_movil

import android.app.Activity
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
    private fun available(): Boolean {
        if (Build.VERSION.SDK_INT < 28) return false
        return try {
            if (Build.VERSION.SDK_INT >= 30) activity.getSystemService(BiometricManager::class.java).canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS
            else if (Build.VERSION.SDK_INT >= 29) activity.getSystemService(BiometricManager::class.java).canAuthenticate() == BiometricManager.BIOMETRIC_SUCCESS
            else activity.getSystemService(FingerprintManager::class.java).let { it?.isHardwareDetected == true && it.hasEnrolledFingerprints() }
        } catch (_: Exception) { false }
    }
    fun clear() { prefs.edit().clear().apply(); try { store().deleteEntry(alias) } catch (_: Exception) {} }
    fun cancel() { cancellation?.cancel() }
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when(call.method) {
            "status" -> result.success(mapOf("available" to available(), "saved" to (prefs.contains("blob") && try { store().containsAlias(alias) } catch (_: Exception) { false })))
            "clear" -> { clear(); result.success(null) }
            "save", "unlock" -> authenticate(call, result)
            else -> result.notImplemented()
        }
    }
    @Suppress("DEPRECATION")
    private fun authenticate(call: MethodCall, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 28 || !available()) { result.error("unavailable", "Configura una huella o biometría fuerte en Android. En este dispositivo puedes usar tu contraseña.", null); return }
        if (pending != null) { result.error("busy", "Ya hay una verificación biométrica en curso.", null); return }
        val saving=call.method=="save"
        val payload=call.argument<String>("payload")
        if(saving && (payload==null || payload.length>12000)) { result.error("invalid", "Sesión no válida para guardar.", null); return }
        try {
            val ks=store()
            if(saving) {
                prefs.edit().clear().apply()
                if(ks.containsAlias(alias)) ks.deleteEntry(alias)
                val builder=KeyGenParameterSpec.Builder(alias,KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setUserAuthenticationRequired(true).setInvalidatedByBiometricEnrollment(true)
                if(Build.VERSION.SDK_INT>=30) builder.setUserAuthenticationParameters(0,KeyProperties.AUTH_BIOMETRIC_STRONG)
                else builder.setUserAuthenticationValidityDurationSeconds(-1)
                KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore").apply { init(builder.build());generateKey() }
            }
            val key=ks.getKey(alias,null) as? SecretKey ?: throw IllegalStateException()
            val cipher=Cipher.getInstance("AES/GCM/NoPadding")
            if(saving) cipher.init(Cipher.ENCRYPT_MODE,key)
            else cipher.init(Cipher.DECRYPT_MODE,key,GCMParameterSpec(128,Base64.decode(prefs.getString("iv",null),Base64.NO_WRAP)))
            cipher.updateAAD(aad)
            pending=result;cancellation=CancellationSignal()
            val builder=BiometricPrompt.Builder(activity).setTitle(if(saving) "Activar acceso biométrico" else "Ingresar a RutaAlerta")
                .setSubtitle("Confirma con la biometría de este teléfono")
                .setNegativeButton("Usar contraseña",activity.mainExecutor) { _,_ -> finish(null,"cancelled","Verificación cancelada. Usa tu contraseña.") }
            if(Build.VERSION.SDK_INT>=30) builder.setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            builder.build().authenticate(BiometricPrompt.CryptoObject(cipher),cancellation!!,activity.mainExecutor,object:BiometricPrompt.AuthenticationCallback(){
                override fun onAuthenticationSucceeded(auth:BiometricPrompt.AuthenticationResult) {
                    try {
                        val c=auth.cryptoObject?.cipher ?: throw IllegalStateException()
                        if(saving) {
                            val blob=c.doFinal(payload!!.toByteArray(Charsets.UTF_8))
                            prefs.edit().putString("blob",Base64.encodeToString(blob,Base64.NO_WRAP)).putString("iv",Base64.encodeToString(c.iv,Base64.NO_WRAP)).apply()
                            finish(true)
                        }else {
                            val data=c.doFinal(Base64.decode(prefs.getString("blob",null),Base64.NO_WRAP)).toString(Charsets.UTF_8)
                            JSONObject(data) // Validar estructura sin registrar el contenido.
                            finish(data)
                        }
                    }catch(_:Exception){clear();finish(null,"invalidated","El acceso guardado ya no es válido. Ingresa con contraseña y vuelve a activarlo.")}
                }
                override fun onAuthenticationError(code:Int,message:CharSequence){finish(null,"cancelled","No se completó la verificación. Puedes usar tu contraseña.")}
                override fun onAuthenticationFailed(){ /* Android mantiene su diálogo para un nuevo intento. */ }
            })
        } catch(_:Exception) {clear();finish(null,"invalidated","Ingresa con contraseña y vuelve a configurar la biometría.",result)}
    }
    private fun finish(value:Any?,code:String?=null,message:String?=null,fallback:MethodChannel.Result?=null) {
        val r=pending ?: fallback;pending=null;cancellation=null
        if(code==null)r?.success(value) else r?.error(code,message,null)
    }
}
