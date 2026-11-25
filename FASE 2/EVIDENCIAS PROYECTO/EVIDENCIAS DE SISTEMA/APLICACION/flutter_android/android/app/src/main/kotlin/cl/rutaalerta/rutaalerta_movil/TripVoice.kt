package cl.rutaalerta.rutaalerta_movil

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener

/** Reproduce instrucciones breves con una voz instalada en el teléfono. */
internal class TripVoice(context: Context, private val onState: (String) -> Unit) {
    private val main = Handler(Looper.getMainLooper())
    private val audio = context.getSystemService(AudioManager::class.java)
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        .build()
    private val focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        .setAudioAttributes(attributes)
        .setWillPauseWhenDucked(true)
        .setOnAudioFocusChangeListener({ change ->
            if (change < 0) cancelSpeech()
        }, main)
        .build()
    private var engine: TextToSpeech? = null
    private var ready = false
    private var pending: Pair<String, Long>? = null
    private var current: String? = null
    private var sequence = 0

    init {
        onState("loading")
        engine = TextToSpeech(context) { status -> main.post { configure(status) } }
    }

    private fun configure(status: Int) {
        val tts = engine ?: return
        val available = status == TextToSpeech.SUCCESS && runCatching {
            val voice = tts.voices.orEmpty().filter {
                it.locale.language == "es" && !it.isNetworkConnectionRequired &&
                    "notInstalled" !in it.features.orEmpty()
            }.minByOrNull { if (it.locale.country == "CL") 0 else 1 }
            voice != null && tts.setVoice(voice) == TextToSpeech.SUCCESS
        }.getOrDefault(false)
        if (!available) {
            onState("unavailable")
            close()
            return
        }
        tts.setAudioAttributes(attributes)
        tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String) = Unit
            override fun onDone(utteranceId: String) = finish(utteranceId)
            @Deprecated("Compatibilidad con el motor de voz")
            override fun onError(utteranceId: String) = finish(utteranceId)
        })
        ready = true
        onState("ready")
        val queued = pending
        pending = null
        if (queued != null && SystemClock.elapsedRealtime() < queued.second) say(queued.first)
    }

    fun say(message: String): Boolean {
        val tts = engine ?: return false
        if (!ready) {
            pending = message to (SystemClock.elapsedRealtime() + 10000L)
            return false
        }
        if (current != null ||
            audio.requestAudioFocus(focus) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) return false
        val id = "rutaalerta-${++sequence}"
        current = id
        val queued = runCatching { tts.speak(message, TextToSpeech.QUEUE_FLUSH, null, id) }
            .getOrDefault(TextToSpeech.ERROR) == TextToSpeech.SUCCESS
        if (!queued) {
            cancelSpeech()
        } else {
            main.postDelayed({ if (current == id) cancelSpeech() }, 15000L)
        }
        return queued
    }

    private fun finish(id: String) {
        main.post {
            if (current == id) {
                current = null
                audio.abandonAudioFocusRequest(focus)
            }
        }
    }

    private fun cancelSpeech() {
        if (current == null) return
        current = null
        engine?.stop()
        audio.abandonAudioFocusRequest(focus)
    }

    fun close() {
        pending = null
        cancelSpeech()
        engine?.shutdown()
        engine = null
        main.removeCallbacksAndMessages(null)
    }
}
