package com.Uuy;

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String METHOD_CHANNEL = "com.Uuy/language";
    private static final String EVENT_CHANNEL = "com.Uuy/stream";

    private LanguageClassifier classifier;
    private AudioRecorderService recorderService;
    private EventChannel.EventSink eventSink;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        classifier = new LanguageClassifier(getApplicationContext());

        new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), EVENT_CHANNEL)
            .setStreamHandler(new EventChannel.StreamHandler() {
                @Override
                public void onListen(Object arguments, EventChannel.EventSink sinks) {
                    eventSink = sinks;
                }

                @Override
                public void onCancel(Object arguments) {
                    eventSink = null;
                }
            });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), METHOD_CHANNEL)
            .setMethodCallHandler((call, result) -> {
                switch (call.method) {
                    case "start":
                        try {
                            recorderService = new AudioRecorderService(getApplicationContext(), classifier, (idioma, confianza) -> {
                                runOnUiThread(() -> {
                                    java.util.Map<String, Object> mapaResultados = new java.util.HashMap<>();
                                    mapaResultados.put("className", idioma);
                                    mapaResultados.put("confidence", confianza);
                                    if (eventSink != null) eventSink.success(mapaResultados);
                                });
                            });

                            String idGrabacion = recorderService.startRecording();
                            result.success(idGrabacion);
                        } catch (Exception e) {
                            result.error("ERR_START", e.getMessage(), null);
                        }
                        break;
                    case "stop":
                        if (recorderService != null) {
                            recorderService.stopRecording();
                            recorderService = null;
                        }
                        result.success(true);
                        break;
                    default:
                        result.notImplemented();
                        break;
                }
            });
    }

    @Override
    protected void onDestroy() {
        if (recorderService != null) recorderService.stopRecording();
        if (classifier != null) classifier.close();
        super.onDestroy();
    }
}
