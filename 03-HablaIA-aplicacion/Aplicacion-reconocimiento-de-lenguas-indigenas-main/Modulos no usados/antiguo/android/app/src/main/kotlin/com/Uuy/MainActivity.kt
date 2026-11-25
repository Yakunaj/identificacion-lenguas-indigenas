package com.Uuy

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.Uuy/language"
    private val EVENT_CHANNEL  = "com.Uuy/stream"

    private var recorderService: AudioRecorderService? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)



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
                         if (recorderService != null) {
                                result.success(null)
                                return@setMethodCallHandler
                            }
                        try {
                            recorderService = AudioRecorderService(applicationContext) { bitmapBytes ->
                                runOnUiThread {
                                    eventSink?.success(mapOf(
                                        "type"  to "bitmap",
                                        "bytes" to bitmapBytes
                                    ))
                                }
                            }
                            val sessionPath = recorderService?.startRecording()
                            result.success(sessionPath)
                            
                        } catch (e: Exception) {
                            result.error("ERR_START", e.message, null)
                        }
                    }

                    "stop" -> {
                        try {
                            val rutaCompleto = recorderService?.stopRecording()
                            recorderService = null
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("ERR_STOP", e.message, null)
                        }
                    }

                    "classify" -> {
                        try {
                            val bytes = call.argument<ByteArray>("bytes")
                                ?: return@setMethodCallHandler result.error(
                                    "ERR_CLASSIFY", "No se recibieron bytes", null
                                )
                        } catch (e: Exception) {
                            result.error("ERR_CLASSIFY", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            } // ← cierra setMethodCallHandler
    }         // ← cierra configureFlutterEngine

    override fun onDestroy() {
        recorderService?.stopRecording()
        super.onDestroy()
    }
}