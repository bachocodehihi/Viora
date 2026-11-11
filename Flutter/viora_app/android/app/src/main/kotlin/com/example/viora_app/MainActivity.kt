package com.example.viora_app

import android.media.AudioAttributes
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ringtone: Ringtone? = null
    private var toneGenerator: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "viora/call_sound")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRingtone" -> {
                        startRingtone()
                        result.success(true)
                    }
                    "stopRingtone" -> {
                        stopRingtone()
                        result.success(true)
                    }
                    "playRingbackPulse" -> {
                        playRingbackPulse()
                        result.success(true)
                    }
                    "stopRingback" -> {
                        stopRingback()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startRingtone() {
        try {
            stopRingtone()
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                ?: return
            val rt = RingtoneManager.getRingtone(applicationContext, uri) ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                rt.isLooping = true
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                rt.audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            }
            rt.play()
            ringtone = rt
        } catch (_: Throwable) {
        }
    }

    private fun stopRingtone() {
        try {
            ringtone?.stop()
        } catch (_: Throwable) {
        }
        ringtone = null
    }

    private fun playRingbackPulse() {
        try {
            if (toneGenerator == null) {
                toneGenerator = ToneGenerator(AudioManager.STREAM_VOICE_CALL, 40)
            }
            toneGenerator?.startTone(ToneGenerator.TONE_SUP_RINGTONE, 900)
        } catch (_: Throwable) {
        }
    }

    private fun stopRingback() {
        try {
            toneGenerator?.stopTone()
            toneGenerator?.release()
        } catch (_: Throwable) {
        }
        toneGenerator = null
    }

    override fun onDestroy() {
        stopRingtone()
        stopRingback()
        super.onDestroy()
    }
}
