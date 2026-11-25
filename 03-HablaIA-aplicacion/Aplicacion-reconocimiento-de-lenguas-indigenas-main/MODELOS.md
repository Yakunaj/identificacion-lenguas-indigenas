# Modelos de clasificación de Habla IA

## Qué es

Es la explicación de cómo la app usa los modelos que reconocen el idioma, de dónde saca la lista de modelos disponibles y de qué forma se describe cada uno, para que se puedan agregar modelos nuevos aunque reciban otro tipo de entrada, distingan más idiomas o entreguen su resultado de otra manera, sin tener que cambiar el código de la app.

## Qué hace

Mientras se graba, la app guarda cada cinco segundos un fragmento de audio en WAV y se lo pasa al modelo activo, que según su configuración lo convierte en la entrada que espera, ya sea la imagen de un espectrograma o el audio tal cual, lo ejecuta con TFLite y convierte su salida en una probabilidad para cada idioma, de la que sale el idioma con mayor probabilidad y su confianza. Como todo parte del WAV, al volver a analizar una grabación guardada se usa el modelo que esté activo en ese momento aunque la grabación se haya hecho con otro. El usuario elige el modelo con el botón ⚙ de la pantalla principal, que se desactiva mientras graba, y la app recuerda la elección para la próxima vez.

## Cómo se usa

Para agregar un modelo se copia su `.tflite` a `lib/modelos/`, que ya está declarada en `pubspec.yaml`, y se agrega su `ConfiguracionModelo` a la lista `modelosDisponibles` de `lib/estructuras/modelos_disponibles_estructura.dart`, después se corre `flutter test`, que revisa que el archivo exista, que ningún `id` se repita, que haya un solo modelo predeterminado y que la salida esté bien declarada. Las clases de la configuración están en `lib/estructuras/modelo_configuracion_estructura.dart` y las siguientes secciones explican cada una.

## La configuración del modelo, `ConfiguracionModelo`

### Qué hace

Reúne todo lo que la app necesita saber de un modelo, su identificador, que se guarda como la preferencia del usuario y no se debe repetir, el nombre que aparece al elegirlo, la versión, que se guarda junto a cada resultado como `id@version`, la ruta del archivo `.tflite`, si es el modelo que se usa cuando el usuario todavía no ha elegido ninguno, y la descripción de su entrada y de su salida.

### Cómo se usa

Se escribe una entrada nueva dentro de la lista `modelosDisponibles` con estos datos, poniendo en `archivo` la ruta completa del asset y en `entrada` y `salida` los constructores que se explican abajo, y solo un modelo de la lista debe llevar `predeterminado: true`.

```dart
ConfiguracionModelo(
  id: 'mi_modelo',
  nombre: 'Texto que ve el usuario',
  version: '1.0',
  archivo: 'lib/modelos/mi_modelo.tflite',
  predeterminado: false,
  entrada: ConfiguracionEntrada.espectrograma(),
  salida: ConfiguracionSalida.binaria(etiquetas: ['español', 'maya']),
),
```

## La entrada de espectrograma, `ConfiguracionEntrada.espectrograma`

### Qué hace

Convierte el fragmento de audio en la imagen de un espectrograma Mel, que genera el código nativo de Kotlin con los parámetros del modelo, y la pasa al modelo como una imagen de forma `[1, alto, ancho, canales]` o `[1, canales, alto, ancho]`. El ancho, el alto y los canales se leen del propio modelo, con un canal la imagen va en gris y con tres en color. Los parámetros que no se indiquen toman los valores del modelo MobileNetV3 original, que son 16 000 Hz, una FFT de 2048 con saltos de 512, 128 bandas Mel entre 0 y 8000 Hz, un piso de −80 dB y la paleta inferno, y `nFft` siempre tiene que ser potencia de 2.

### Cómo se usa

Se indica cómo se escalan los pixeles con `normalizacion`, que puede ser `Normalizacion.ceroUno` para dividirlos entre 255, que es la opción por defecto, `Normalizacion.menosUnoUno` para llevarlos entre −1 y 1, o `Normalizacion.ninguna` para dejarlos entre 0 y 255, y si el modelo se entrenó con otro espectrograma se cambian solo los valores distintos dentro de `ParametrosEspectrograma`, con `MapaColor.gris` si se entrenó en escala de grises.

```dart
entrada: ConfiguracionEntrada.espectrograma(
  normalizacion: Normalizacion.ceroUno,
  espectrograma: ParametrosEspectrograma(
    nMels: 64,
    mapaColor: MapaColor.gris,
  ),
),
```

## La entrada de audio crudo, `ConfiguracionEntrada.audio`

### Qué hace

Pasa al modelo el sonido tal cual, sin convertirlo en imagen, en un tensor de forma `[1, muestras]`, `[muestras]` o `[1, muestras, 1]`. Primero cambia la frecuencia de muestreo del fragmento de cinco segundos a la que pide el modelo, después lo parte en ventanas del tamaño de su entrada, rellenando con ceros la última, o descartándola si mide menos de la mitad y ya hay otras ventanas, clasifica cada ventana y promedia las probabilidades de todas.

### Cómo se usa

Se indica la frecuencia que espera el modelo en `sampleRate` y el tamaño de cada ventana en `muestras`, que se puede omitir si el modelo tiene un tamaño fijo pero hace falta cuando su entrada es dinámica, y en `normalizacion` se usa `Normalizacion.menosUnoUno` para valores entre −1 y 1, que es la opción por defecto, `Normalizacion.ceroUno` para valores entre 0 y 1, o `Normalizacion.ninguna` para pasar los enteros de 16 bits.

```dart
entrada: ConfiguracionEntrada.audio(
  sampleRate: 16000,
  muestras: 16000,
  normalizacion: Normalizacion.menosUnoUno,
),
```

## La salida del modelo, `ConfiguracionSalida`

### Qué hace

Convierte lo que entrega el modelo en una probabilidad para cada idioma. La salida binaria sirve para modelos de dos idiomas que terminan en una sola neurona sigmoide, cuyo valor es la probabilidad del segundo idioma de la lista, aunque también acepta dos valores si el modelo termina en softmax, y la salida multiclase sirve para cualquier número de idiomas, con un valor para cada uno. Si el modelo entrega valores sin la sigmoide o la softmax final, con `logits: true` la app los aplica por su cuenta. Funciona con modelos en `float32` y también con modelos cuantizados en `uint8` o `int8`.

### Cómo se usa

Se elige `ConfiguracionSalida.binaria` o `ConfiguracionSalida.multiclase` y se ponen las etiquetas en el mismo orden que se usó al entrenar, que con `image_dataset_from_directory` de Keras es el orden alfabético de las carpetas, porque el `.tflite` no guarda los nombres de los idiomas y con el orden equivocado la app funcionaría sin errores pero con los idiomas intercambiados. Si la configuración no coincide con el modelo, por ejemplo con tres etiquetas para un modelo de dos salidas, la app muestra un aviso claro al seleccionarlo.

```dart
salida: ConfiguracionSalida.multiclase(
  etiquetas: ['español', 'maya', 'náhuatl'],
  logits: false,
),
```

## Un tipo de entrada nuevo

### Qué hace

Permite que la app acepte modelos con una entrada distinta a las dos que ya existen, por ejemplo coeficientes MFCC, sin cambiar el resto del proceso, porque la app solo le pide a cada tipo de entrada que convierta el fragmento de audio en los datos que necesita el modelo.

### Cómo se usa

Se agrega el valor nuevo al enum `TipoEntrada` junto con su constructor en `ConfiguracionEntrada`, por ejemplo `ConfiguracionEntrada.mfcc`, se crea una clase que extienda `EntradaModelo` en `lib/servicios/modelo/entradas_modelo.dart` con la conversión dentro de su método `preparar`, y se registra en el `switch` de `EntradaModelo.crear`, donde Dart avisa al compilar si falta algún tipo.
