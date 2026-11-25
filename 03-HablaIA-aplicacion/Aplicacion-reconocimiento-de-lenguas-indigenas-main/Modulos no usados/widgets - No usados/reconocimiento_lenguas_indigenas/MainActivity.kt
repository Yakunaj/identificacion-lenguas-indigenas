package com.Uuy

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// ❌ Quita estos 3 — mismo paquete, no necesitan import
// import com.Uuy.LanguageClassifier
// import com.Uuy.FileManager
// import com.Uuy.AudioRecorderService

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.Uuy/language"
    private val EVENT_CHANNEL  = "com.Uuy/stream"

    private var classifier: LanguageClassifier? = null
    private var recorderService: AudioRecorderService? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        classifier = LanguageClassifier(applicationContext)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sinks: EventChannel.EventSink?) {
                    eventSink = sinks
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            recorderService = AudioRecorderService(
                                applicationContext,
                                classifier!!
                            ) { idioma, confianza ->
                                runOnUiThread {
                                    eventSink?.success(
                                        mapOf("className" to idioma, "confidence" to confianza)
                                    )
                                }
                            }
                            val idGrabacion = recorderService?.startRecording()
                            result.success(idGrabacion)
                        } catch (e: Exception) {
                            result.error("ERR_START", e.message, null)
                        }
                    }
                    "stop" -> {
                        recorderService?.stopRecording()
                        recorderService = null
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        recorderService?.stopRecording()
        classifier?.close()
        super.onDestroy()
    }
}