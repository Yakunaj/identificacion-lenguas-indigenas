# 03 — Aplicación HablaIA

HablaIA es una aplicación móvil prototipo que graba fragmentos de voz y reconoce automáticamente si la persona habla español o maya. El modelo se ejecuta dentro del propio teléfono, sin conexión a internet, para apoyar la asignación rápida de intérpretes en contextos de emergencia (por ejemplo, atención médica o legal). Forma parte del proyecto *Ciencia, Humanidades, Tecnología e Innovación* (SECIHTI), clave `CBF-2025-G-368`, de la Universidad Autónoma de Yucatán.

## Qué hace

1. Al pulsar el botón de grabar, la app pide permiso de micrófono y captura la voz en fragmentos de cinco segundos.
2. Cada fragmento se convierte en un espectrograma Mel de 224 × 224 píxeles y se clasifica con un modelo TensorFlow Lite (`MobileNetV3Large`) incluido en la app.
3. La pantalla muestra el idioma detectado y su porcentaje de confianza mientras se sigue hablando.
4. Al detener, la grabación se guarda en una base de datos SQLite junto con el resultado, la duración y las coordenadas GPS si se concedió ese permiso.
5. En la pestaña de audios se pueden escuchar las grabaciones, volver a analizarlas o borrarlas.

## Estructura

```text
03-HablaIA-aplicacion/
├── Aplicacion-reconocimiento-de-lenguas-indigenas-main/
│   ├── android/                 módulo nativo de Android
│   ├── Entrenamiento/           scripts y guía para entrenar el modelo
│   ├── Extras/                  material de apoyo para el desarrollo
│   ├── lib/                     código Dart: paginas/, widgets/, servicios/, estructuras/, modelos/
│   ├── MODELOS.md               cómo agregar o configurar modelos
│   ├── README.md                documentación detallada del código
│   └── pubspec.yaml             dependencias de Flutter
├── documentos/
│   ├── Manual_Usuario_HablaIA.pdf
│   └── Manual_Tecnico_HablaIA.pdf
└── README.md
```

El código de la interfaz y la clasificación está en Dart/Flutter (`lib/`), y la grabación y el cálculo de espectrogramas se hacen en Kotlin/Android. En esta copia la carpeta `android/` está vacía: el módulo nativo necesario para compilar la app no se distribuye aquí.

## Manual de usuario

El paso a paso con capturas está en [`documentos/Manual_Usuario_HablaIA.pdf`](documentos/Manual_Usuario_HablaIA.pdf). En resumen:

- **Pantalla principal:** pulsa el botón circular del micrófono para empezar; la primera vez la app solicita el permiso. Mientras graba, el botón se vuelve rojo, se dibuja la onda de la voz y cada cinco segundos aparece el idioma detectado con su confianza. Pulsa de nuevo para detener; la grabación también se detiene sola al minuto. El botón ⚙ permite elegir el modelo.
- **Pantalla de audios:** muestra el historial de grabaciones. Desde cada una se puede reproducir, volver a analizarla (resultado general y por fragmento) o eliminarla.
- **Permisos:** el micrófono es obligatorio para grabar; la ubicación es opcional y, si se rechaza, las grabaciones se guardan igual pero sin coordenadas.

## Datos técnicos

| Aspecto | Valor |
|---|---|
| Framework | Flutter (Dart ^3.10.8), Kotlin para Android |
| Plataforma | Android 7.0 o superior (`minSdk 24`); solo Android |
| Modelo | `MobileNetV3Large_normal.tflite`, en `lib/modelos/` |
| Entrada | Espectrograma Mel de 224 × 224 × 3, 16 kHz, fragmentos de 5 s |
| Clases | español, maya |
| Permisos | `RECORD_AUDIO` y ubicación (opcional) |
| Almacenamiento | Grabaciones en SQLite (`uuy.db`); audio en la caché del dispositivo |
| Conectividad | Ninguna: toda la inferencia es local |

## Cómo ejecutarla desde el código

Necesitas Flutter con el SDK de Android, un dispositivo o emulador Android 7.0+ y al menos 80 MB libres.

```bash
cd Aplicacion-reconocimiento-de-lenguas-indigenas-main
flutter pub get
flutter run
flutter test
```

Recuerda que el módulo `android/` debe estar presente para que `flutter run` funcione; en esta copia no se incluye, así que hace falta conseguirlo por separado. Para entrenar un modelo nuevo, empieza por [`Entrenamiento/README.md`](Aplicacion-reconocimiento-de-lenguas-indigenas-main/Entrenamiento/README.md); para cambiar o agregar modelos, consulta [`MODELOS.md`](Aplicacion-reconocimiento-de-lenguas-indigenas-main/MODELOS.md). El detalle interno del código está en el [README de la app](Aplicacion-reconocimiento-de-lenguas-indigenas-main/README.md) y el detalle técnico en [`Manual_Tecnico_HablaIA.pdf`](documentos/Manual_Tecnico_HablaIA.pdf).

## Relación con otros proyectos

- [`01 — Clasificación maya-español`](../01-clasificacion-maya-espanol/): enfoque de espectrogramas + CNN del que parte el modelo de la app.
- [`02 — Aumento de datos y modelos ligeros`](../02-clasificacion-maya-espanol+aumento-de-datos/): línea de modelos compactos orientados a dispositivos móviles.
- [`04 — Clasificación maya-náhuatl-zapoteco`](../04-clasificacion-maya-nahuatl-zapoteco/): clasificación multilingüe.

## Autoría y licencia

Los manuales (versión 1.0, agosto de 2026) y el prototipo proceden del proyecto SECIHTI `CBF-2025-G-368` de la Universidad Autónoma de Yucatán. La autoría dentro de este repositorio está pendiente de definir (`[P]`). La licencia del repositorio es provisional, según [`../LICENSE`](../LICENSE).
