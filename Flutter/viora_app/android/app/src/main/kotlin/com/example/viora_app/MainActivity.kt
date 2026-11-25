package com.example.viora_app

import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.Ringtone
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteOrder
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.log10

class MainActivity : FlutterActivity() {
    private var ringtone: Ringtone? = null
    private var toneGenerator: ToneGenerator? = null
    private val waveformExecutor = Executors.newFixedThreadPool(2)
    private val mainHandler = Handler(Looper.getMainLooper())

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "viora/audio_waveform")
            .setMethodCallHandler { call, result ->
                if (call.method == "extractWaveform") {
                    val path = call.argument<String>("path")
                    val barCount = call.argument<Int>("barCount") ?: 20
                    if (path.isNullOrEmpty()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    waveformExecutor.execute {
                        val amps = try {
                            extractAudioWaveform(path, barCount)
                        } catch (_: Throwable) {
                            null
                        }
                        mainHandler.post {
                            result.success(amps)
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun extractAudioWaveform(path: String, barCount: Int): List<Double>? {
        val file = File(path)
        if (!file.exists() || file.length() == 0L) return null

        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            extractor.setDataSource(path)
            var audioTrackIndex = -1
            var format: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val f = extractor.getTrackFormat(i)
                val mime = f.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    format = f
                    break
                }
            }
            if (audioTrackIndex == -1 || format == null) return null

            extractor.selectTrack(audioTrackIndex)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: return null
            val sampleRate = if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            } else 44100
            var channelCount = if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            } else 1
            if (channelCount < 1) channelCount = 1

            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            var windowSamples = (sampleRate * channelCount * 90) / 1000
            val windowPeaks = ArrayList<Int>()
            var currentWindowPeak = 0
            var currentWindowSamples = 0

            val bufferInfo = MediaCodec.BufferInfo()
            var sawInputEOS = false
            var sawOutputEOS = false
            var iterations = 0

            while (!sawOutputEOS && iterations < 50000) {
                iterations++
                if (!sawInputEOS) {
                    val inIndex = codec.dequeueInputBuffer(10000)
                    if (inIndex >= 0) {
                        val inputBuf = codec.getInputBuffer(inIndex)
                        if (inputBuf != null) {
                            val sampleSize = extractor.readSampleData(inputBuf, 0)
                            if (sampleSize < 0) {
                                codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                sawInputEOS = true
                            } else {
                                codec.queueInputBuffer(inIndex, 0, sampleSize, extractor.sampleTime, 0)
                                extractor.advance()
                            }
                        }
                    }
                }

                val outIndex = codec.dequeueOutputBuffer(bufferInfo, 10000)
                if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val outFmt = codec.outputFormat
                    val sr = if (outFmt.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                        outFmt.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    } else sampleRate
                    val ch = if (outFmt.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                        outFmt.getInteger(MediaFormat.KEY_CHANNEL_COUNT).coerceAtLeast(1)
                    } else channelCount
                    windowSamples = ((sr * ch * 90) / 1000).coerceAtLeast(1)
                } else if (outIndex >= 0) {
                    if (bufferInfo.size > 0) {
                        val outBuf = codec.getOutputBuffer(outIndex)
                        if (outBuf != null) {
                            outBuf.position(bufferInfo.offset)
                            outBuf.limit(bufferInfo.offset + bufferInfo.size)
                            val shortBuf = outBuf.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
                            while (shortBuf.hasRemaining()) {
                                val sample = abs(shortBuf.get().toInt())
                                if (sample > currentWindowPeak) {
                                    currentWindowPeak = sample
                                }
                                currentWindowSamples++
                                if (currentWindowSamples >= windowSamples) {
                                    windowPeaks.add(currentWindowPeak)
                                    currentWindowPeak = 0
                                    currentWindowSamples = 0
                                }
                            }
                        }
                    }
                    codec.releaseOutputBuffer(outIndex, false)
                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        sawOutputEOS = true
                    }
                }
            }

            if (currentWindowSamples > 0) {
                windowPeaks.add(currentWindowPeak)
            }
            if (windowPeaks.isEmpty()) return List(barCount) { 0.0 }

            val dbs = windowPeaks.map { peak ->
                if (peak > 0) 20.0 * log10(peak / 32768.0) else -160.0
            }
            val quietSamples = dbs.filter { it > -80.0 && it < -21.5 }.sorted()
            val noiseFloor = if (quietSamples.isNotEmpty()) {
                quietSamples[(quietSamples.size * 0.4).toInt().coerceIn(0, quietSamples.lastIndex)]
            } else {
                -46.0
            }
            val gateDb = (noiseFloor + 4.5).coerceIn(-47.0, -19.5)
            val span = (-2.0 - gateDb).coerceIn(12.0, 44.0)

            val norms = dbs.map { db ->
                if (db > gateDb) {
                    val ratio = ((db - gateDb) / span).coerceIn(0.0, 1.0)
                    (0.14 + 0.86 * ratio).coerceIn(0.0, 1.0)
                } else {
                    0.0
                }
            }

            return if (norms.size < barCount) {
                List(barCount) { i ->
                    val idx = (i * norms.size) / barCount
                    norms[idx.coerceIn(0, norms.lastIndex)]
                }
            } else {
                List(barCount) { i ->
                    val start = (i * norms.size) / barCount
                    val end = (((i + 1) * norms.size) / barCount).coerceIn(start + 1, norms.size)
                    var peak = 0.0
                    for (j in start until end) {
                        if (norms[j] > peak) peak = norms[j]
                    }
                    peak
                }
            }
        } finally {
            try { codec?.stop() } catch (_: Throwable) {}
            try { codec?.release() } catch (_: Throwable) {}
            try { extractor.release() } catch (_: Throwable) {}
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
        waveformExecutor.shutdownNow()
        super.onDestroy()
    }
}
