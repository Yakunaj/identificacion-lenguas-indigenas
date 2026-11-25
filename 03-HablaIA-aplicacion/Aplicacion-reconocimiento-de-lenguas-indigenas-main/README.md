# Habla IA

## Qué es

Es una aplicación para Android que escucha a una persona hablar y reconoce en qué idioma lo hace, pensada para distinguir el español de lenguas indígenas como el maya, que graba desde el micrófono, analiza el audio con un modelo de inteligencia artificial que corre dentro del propio teléfono, sin conexión a internet, y guarda cada grabación con su resultado y el lugar donde se hizo.

## Qué hace

Al presionar el botón de grabar la app empieza a escuchar, dibuja la onda de la voz en pantalla y, cada cinco segundos, toma el último fragmento, lo convierte en la entrada que espera el modelo activo y muestra el idioma detectado con su porcentaje de confianza, que se va actualizando mientras la persona sigue hablando. La grabación se detiene al volver a presionar el botón o sola al cumplir un minuto, y en ese momento la app une los fragmentos en un solo audio y guarda en una base de datos SQLite el idioma que ganó en más fragmentos, la confianza, el modelo usado, la duración y las coordenadas GPS si el usuario dio permiso. En la pestaña de audios se pueden escuchar las grabaciones, borrarlas o volver a analizarlas, lo que muestra el resultado general y el de cada fragmento por separado, cada uno con su propio audio.

La app está hecha en dos partes que trabajan juntas, la interfaz y la lógica de clasificación están en Flutter, mientras que la grabación del micrófono, el manejo de archivos de audio y el cálculo de los espectrogramas están en Kotlin, el código nativo de Android, porque necesitan acceso directo al hardware y mucho cálculo numérico, y las dos partes se comunican por canales de Flutter que se describen en cada sección.

## Cómo se usa

Para compilarla hace falta Flutter con su SDK de Android y un teléfono Android 7.0 o más nuevo, que corresponde al `minSdk 24`, se descargan las dependencias con `flutter pub get`, se conecta el teléfono con la depuración USB activa y se ejecuta `flutter run`, y las pruebas automáticas se corren con `flutter test`. La primera vez que se presiona el botón de grabar la app pide el permiso del micrófono, sin el cual no puede grabar, y el de ubicación, que es opcional porque si se niega las grabaciones se guardan igual pero sin coordenadas. Solo funciona en Android, ya que la parte nativa no existe para iOS.

## Parte 1 · Flutter, la interfaz y la clasificación

### Qué hace

Es todo lo que está en `lib/`, se encarga de las pantallas, de pedir los permisos, de recibir los fragmentos de audio que manda Kotlin, de convertirlos en la entrada del modelo y ejecutarlo con TensorFlow Lite, de interpretar el resultado y de guardarlo en la base de datos con la ubicación. Está organizado en `paginas` para las pantallas, `widgets` para los componentes visuales, `servicios` para la lógica y `estructuras` para las clases de datos.

### Cómo se usa

Se modifica como cualquier proyecto de Flutter y los cambios se ven con la recarga en caliente de `flutter run`, salvo los que tocan a Kotlin, que necesitan volver a compilar. Las siguientes secciones explican cada pieza.

### Las pantallas, `paginas/` y `widgets/`

#### Qué hace

`barra_navegacion_widget.dart` arma la barra inferior con dos pestañas, Principal y Audios. `principal_pagina.dart` es la pantalla de grabación, muestra la onda de la voz con `waveform_construccion_widget.dart`, el idioma detectado con su confianza y el botón de `boton_grabacion_widget.dart`, que cambia de micrófono a detener y tiene alrededor un anillo que se llena durante el minuto máximo de grabación, y en la esquina tiene el botón ⚙ para elegir el modelo. `audios_pagina.dart` muestra la lista de grabaciones de `lista_audios_widget.dart`, con el tamaño de cada una, un botón para reproducirla y un menú para analizarla o eliminarla, y al analizar abre `resultados_pagina.dart`, con el resultado general arriba y el de cada fragmento debajo. Los colores, blanco, dorado y azul, están en `tema_color_estructura.dart` y siguen el modo claro u oscuro del teléfono.

#### Cómo se usa

Cada pantalla es un widget independiente, así que para cambiar cómo se ve una parte se edita su archivo, y para agregar una pestaña nueva se añade su página a la lista `_paginas` y su botón a `destinations` en `barra_navegacion_widget.dart`.

### La comunicación con Kotlin, `grabacion_servicio.dart`

#### Qué hace

Habla con la parte nativa por dos canales, el canal de métodos `com.hablaia/language`, por el que Flutter pide empezar a grabar con `start`, detener con `stop` o generar el espectrograma de un fragmento con `espectrograma`, y el canal de eventos `com.hablaia/stream`, por el que Kotlin avisa del volumen del micrófono para dibujar la onda, de cada fragmento nuevo de cinco segundos con la ruta de su WAV y del audio completo al terminar.

#### Cómo se usa

La pantalla principal llama a `iniciar` y `detener` y escucha `results`, donde cada evento es un mapa con un campo `type`, que vale `amplitude`, `segmento` o `completo`, así que para recibir un dato nuevo desde Kotlin basta con mandar otro `type` desde `MainActivity.kt` y atenderlo en `_iniciarEscuchaStream` de `principal_pagina.dart`.

### La clasificación, `modelo_servicio.dart` y `servicios/modelo/`

#### Qué hace

`ClasificadorServicio` es un servicio único que comparten las dos pantallas, carga el modelo elegido, recuerda la elección con `shared_preferences` y clasifica cada fragmento en orden para no cerrar un modelo mientras se está usando. Para cada fragmento prepara la entrada con `entradas_modelo.dart`, que puede ser la imagen de un espectrograma pedida a Kotlin o el audio tal cual, la pasa al modelo y convierte la salida en una probabilidad por idioma con `salidas_modelo.dart`, mientras que `tensores.dart` se ocupa de los modelos cuantizados. La lista de modelos disponibles está en `estructuras/modelos_disponibles_estructura.dart`.

#### Cómo se usa

Para agregar un modelo se copia su `.tflite` a `lib/modelos/` y se declara en `modelos_disponibles_estructura.dart`, y el detalle de cómo describir su entrada y su salida está en `MODELOS.md`.

### La base de datos y la ubicación, `sqlite_servicio.dart` y `ubicacion_servicio.dart`

#### Qué hace

`GrabacionesDb` guarda una fila por grabación en la tabla `grabaciones` del archivo `uuy.db`, con el número de grabación, el idioma, la confianza, la versión del modelo, la probabilidad del idioma ganador en cada fragmento, la fecha, la duración, la frecuencia de muestreo, la latitud, la longitud, la precisión del GPS y la carpeta donde está el audio, porque el audio en sí se queda en disco y la base solo guarda su ruta. Permite listar las grabaciones, buscarlas por zona con `enArea` y borrarlas, y al borrar una grabación de la lista también se borra su fila. `UbicacionServicio` pide el permiso de ubicación y lee el GPS mientras se graba, esperando hasta 15 segundos y usando la última posición conocida si no hay señal, y nunca impide grabar. `SesionGrabacion` junta los resultados de los fragmentos y los resume en la fila que se guarda.

#### Cómo se usa

La pantalla principal se encarga de todo al detener la grabación, así que solo hace falta tocar estos archivos para cambiar qué se guarda, y si se agrega una columna hay que subir `version` en `GrabacionesDb` y escribir la migración en `onUpgrade` para no perder los datos de quienes ya tienen la app instalada. Las pruebas de la base de datos están en `test/sqlite_test.dart` y las de los modelos en `test/modelos_test.dart`.

## Parte 2 · Kotlin, la grabación y el procesamiento de audio

### Qué hace

Es el código nativo de Android que está en `android/app/src/main/kotlin/com/hablaia/`, se encarga de grabar el micrófono, de cortar el audio en fragmentos y guardarlos como WAV, de unirlos al terminar y de calcular los espectrogramas que piden los modelos, tareas que aquí se hacen más rápido y con acceso directo al hardware del teléfono.

### Cómo se usa

No se llama directamente sino a través de los canales que abre `MainActivity.kt`, y cualquier cambio en estos archivos necesita detener la app y volver a ejecutar `flutter run`, porque la recarga en caliente no aplica al código nativo. Las siguientes secciones explican cada archivo.

### La conexión con Flutter, `MainActivity.kt`

#### Qué hace

Abre los dos canales que usa Flutter, atiende `start` creando un `GrabadorAudio` y devolviendo la carpeta de la grabación, atiende `stop` deteniéndolo en otro hilo para no congelar la pantalla y avisando con el evento `completo` cuando el audio completo está listo, y atiende `espectrograma` leyendo el WAV indicado y generando la imagen con los parámetros que manda Flutter en un hilo aparte, para devolver los pixeles en color. También reenvía a Flutter los eventos de volumen y de fragmento nuevo que produce el grabador.

#### Cómo se usa

Para agregar una función nueva que Flutter pueda pedir se añade un caso al `when (call.method)` del canal de métodos, y para mandar un dato nuevo a Flutter se usa `eventSink?.success` con un mapa que incluya su `type`, siempre dentro de `runOnUiThread` porque los canales solo funcionan en el hilo principal.

### La grabación, `GrabadorAudio.kt`

#### Qué hace

Graba el micrófono con `AudioRecord` a 16 000 Hz, la misma frecuencia con la que se entrenó el modelo, en mono y 16 bits, y si el teléfono no acepta esa frecuencia usa 44 100 Hz, la única que Android garantiza en todos los equipos, en cuyo caso el audio se convierte a 16 000 Hz antes de llegar al modelo. Además calcula el volumen cada 50 milisegundos para dibujar la onda y junta las muestras en bloques de cinco segundos, y cuando completa uno lo normaliza para que su punto más fuerte llegue al máximo, lo guarda como WAV y avisa a Flutter con su número y su ruta, todo en un hilo aparte para no interrumpir la grabación. Al detener espera a que termine el último bloque y pide que se unan todos los fragmentos en un solo archivo, y si al detener quedan menos de cinco segundos sin completar ese pedazo no se guarda.

#### Cómo se usa

La duración de los fragmentos está en `SEGMENT_SEC` y la frecuencia de muestreo en `FRECUENCIA_PREFERIDA`, con `FRECUENCIA_RESPALDO` para los teléfonos que no la aceptan, y en el registro de Android aparece `Grabando a 16000 Hz` o `Grabando a 44100 Hz` para saber cuál se usó, y si se cambian hay que revisar que los modelos sigan recibiendo lo que esperan, porque los actuales se entrenaron con fragmentos de cinco segundos.

### Los archivos, `ManejadorArchivos.kt`

#### Qué hace

Crea una carpeta por grabación con el nombre `Grabacion_<fecha en milisegundos>` dentro de la caché de la app, guarda en `fragmentos/bloque_N.wav` cada fragmento con su cabecera WAV, al terminar los une en `grabacion_completa.wav` y además sabe leer un WAV de 16 bits en mono o estéreo, que es lo que usa el cálculo de espectrogramas.

#### Cómo se usa

Lo usan `GrabadorAudio` para guardar y unir y `MainActivity` para leer, y como las grabaciones están en la caché el sistema puede borrarlas si el teléfono se queda sin espacio, así que para conservarlas siempre habría que cambiar `context.cacheDir` por `context.filesDir` en `iniciarNuevaSesion` y, para que la lista las siga encontrando, `getTemporaryDirectory` por `getApplicationSupportDirectory` en `lista_audios_widget.dart`, que apunta a esa misma carpeta.

### Los espectrogramas, `GeneradorEspectrograma.kt`

#### Qué hace

Convierte un fragmento de audio en la imagen de un espectrograma Mel, primero lo lleva a la frecuencia que pide el modelo, lo divide en ventanas, calcula la FFT de cada una, agrupa las frecuencias en bandas Mel, pasa la energía a decibeles tomando como referencia el punto más fuerte del fragmento y la pinta con la paleta inferno o en gris, con los graves abajo y el tiempo de izquierda a derecha. Todos esos valores llegan en `ParametrosEspectrograma`, y los que no se indican toman los del modelo original, que son 16 000 Hz, una FFT de 2048 con saltos de 512, 128 bandas entre 0 y 8000 Hz, un piso de −80 dB y una imagen de 224 por 224, los mismos que usa el generador con el que se entrenó el modelo.

#### Cómo se usa

No hace falta llamarlo a mano porque Flutter lo pide por el canal con los parámetros de cada modelo, y si un modelo nuevo se entrenó con otro espectrograma basta con indicar sus valores en su configuración de Flutter, sin tocar este archivo, que solo se modificaría para agregar otro tipo de cálculo o de paleta.

## Otras carpetas del repositorio

### Qué son

`Entrenamiento` tiene todo lo necesario para entrenar el modelo que usa la app, los scripts que preparan el audio, el generador de espectrogramas en Kotlin, el script de entrenamiento, los notebooks de evaluación y una guía que lleva el proceso paso a paso, y `Modulos no usados` guarda versiones anteriores de la app, pantallas, servicios y scripts que ya no se usan pero se conservan como referencia.

### Cómo se usan

Para entrenar un modelo nuevo se empieza por el `README.md` de `Entrenamiento`, que explica el orden de los scripts, y el `.tflite` que resulte se copia a `lib/modelos/` como indica `MODELOS.md`. Los modelos en formato `.keras` y los archivos `.zip` no se suben al repositorio por su tamaño, así que solo existen en la computadora donde se entrenaron, y ninguna de las dos carpetas forma parte de la app, por eso el análisis de Flutter las ignora.

## Extras, los apoyos para el desarrollo posterior

### Qué hace

En la carpeta `Extras` están los archivos y los enlaces necesarios para apoyarse en el desarrollo posterior de la aplicación, el material de consulta que no forma parte del código pero que ayuda a entender el proyecto y a seguir ampliándolo.

### Cómo se usa

Antes de hacer cambios grandes en la app conviene revisar esa carpeta, y cada archivo o enlace nuevo que sirva para el desarrollo se agrega ahí, con los enlaces anotados en su `README.md` junto a una frase que explique para qué sirve cada uno.
