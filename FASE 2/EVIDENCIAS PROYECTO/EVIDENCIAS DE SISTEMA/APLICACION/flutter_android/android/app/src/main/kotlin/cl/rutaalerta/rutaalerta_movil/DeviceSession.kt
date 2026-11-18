package cl.rutaalerta.rutaalerta_movil

import android.content.Context
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

class DeviceSession(context: Context) {
    private val prefs = context.getSharedPreferences("sesion_telefono", Context.MODE_PRIVATE)
    private val biometric = context.getSharedPreferences("vault_privado", Context.MODE_PRIVATE)
    private val alias = "rutaalerta.sesion.dispositivo"

    private fun key(create: Boolean): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        check(create)
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        return generator.generateKey()
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "clear" -> { check(prefs.edit().clear().commit()); result.success(null) }
                "save" -> {
                    val token = requireNotNull(call.argument<String>("token"))
                    require(token.isNotBlank())
                    if (!biometric.contains("blob")) {
                        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                        cipher.init(Cipher.ENCRYPT_MODE, key(true))
                        val bytes = cipher.doFinal(token.toByteArray(Charsets.UTF_8))
                        check(prefs.edit().putString("iv", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
                            .putString("blob", Base64.encodeToString(bytes, Base64.NO_WRAP)).commit())
                    }
                    result.success(null)
                }
                "read" -> {
                    val blob = prefs.getString("blob", null)
                    if (blob == null || biometric.contains("blob")) { result.success(null); return }
                    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                    cipher.init(Cipher.DECRYPT_MODE, key(false), GCMParameterSpec(128, Base64.decode(prefs.getString("iv", null), Base64.NO_WRAP)))
                    result.success(cipher.doFinal(Base64.decode(blob, Base64.NO_WRAP)).toString(Charsets.UTF_8))
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            result.error("device_session", "Android no pudo abrir o guardar la sesión en este teléfono.", null)
        }
    }
}
