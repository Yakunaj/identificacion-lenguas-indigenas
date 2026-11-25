package com.uuy

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// Servicio principal de la aplicación que maneja la comunicación entre Flutter y el código nativo de Android.
class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.uuy/language"
    private val EVENT_CHANNEL = "com.uuy/stream"

    private var grabar: GrabadorAudio? = null
    private var eventSink: EventChannel.EventSink? = null

    // Configura el motor de Flutter y establece los canales de comunicación para recibir eventos y llamadas desde Flutter.
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

        // Configura el canal para recibir llamadas desde Flutter y manejar la grabación de audio y la clasificación.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {


                    "start" -> {
                        if (grabar != null) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        try {
                            grabar =
                                GrabadorAudio(applicationContext) { bitmapBytes ->
                                    runOnUiThread {
                                        eventSink?.success(
                                            mapOf(
                                                "type" to "bitmap",
                                                "bytes" to bitmapBytes
                                            )
                                        )
                                    }
                                }
                            val sessionPath = grabar?.startRecording()
                            result.success(sessionPath)

                        } catch (e: Exception) {
                            result.error("ERR_START", e.message, null)
                        }
                    }

                    "stop" -> {
                        try {
                            val rutaCompleto = grabar?.stopRecording()
                            grabar = null
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("ERR_STOP", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // Detiene el servicio de grabación de audio cuando la actividad se destruye para liberar recursos.
    override fun onDestroy() {
        grabar?.stopRecording()
        super.onDestroy()
    }
}