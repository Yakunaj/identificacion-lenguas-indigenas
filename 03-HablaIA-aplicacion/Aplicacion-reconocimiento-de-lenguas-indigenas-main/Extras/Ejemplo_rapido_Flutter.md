# Flutter en Habla IA, un ejemplo rápido

## Qué es

Es una introducción corta a Flutter y a Dart, el lenguaje en el que está escrita la interfaz de la app, pensada para quien vaya a modificar el código por primera vez, con un ejemplo pequeño que imita la pantalla principal de Habla IA, la explicación de cada parte de su notación, cómo funcionan los widgets por dentro y cómo se comunica Flutter con el código de Kotlin.

## Qué hace

El ejemplo muestra una pantalla con un título, un texto con el idioma detectado y un botón que simula una clasificación, al presionarlo el botón se desactiva y dice Analizando mientras espera un segundo, como si el modelo estuviera trabajando, y después aparecen el idioma y su confianza, alternando entre español y maya en cada intento. Con eso se ven las mismas piezas que usa la app real, los widgets, el estado que cambia, las funciones que esperan un resultado y la forma en que Dart maneja los valores que todavía no existen. Al final hay un segundo ejemplo, con una parte en Dart y otra en Kotlin, que le pregunta datos al teléfono y recibe mensajes de Kotlin cada segundo, igual que la app recibe el audio del micrófono.

## Cómo se usa

Para probarlo se crea un proyecto aparte con `flutter create ejemplo`, se reemplaza todo el contenido de `ejemplo/lib/main.dart` por el código de la siguiente sección y se ejecuta `flutter run` dentro de la carpeta `ejemplo`, con un teléfono conectado o un emulador abierto. Mientras corre, al guardar un cambio y presionar `r` en la terminal la app se actualiza al instante sin perder lo que había en pantalla, lo que se llama recarga en caliente, y con `R` se reinicia desde cero. En este repositorio se usan además `flutter pub get` para descargar las dependencias que lista `pubspec.yaml`, `flutter analyze` para buscar errores sin ejecutar nada y `flutter test` para correr las pruebas.

## El código del ejemplo

### Qué hace

Es una app completa en un solo archivo, con `main` como punto de entrada, `EjemploApp` como la app que nunca cambia, `PantallaIdioma` como la pantalla que sí cambia y `_PantallaIdiomaState` como el lugar donde se guarda lo que cambia, que es el idioma, la confianza y si está analizando.

### Cómo se usa

Se copia entero en `lib/main.dart` del proyecto de prueba y se lee de arriba hacia abajo junto con la siguiente sección, que explica cada parte de la notación usando las mismas líneas.

```dart
import 'package:flutter/material.dart';

// Punto de entrada, runApp recibe el widget que ocupa toda la pantalla
void main() => runApp(const EjemploApp());

// Widget sin estado, solo arma la app y nunca cambia
class EjemploApp extends StatelessWidget {
  const EjemploApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: PantallaIdioma(titulo: 'Habla IA'),
    );
  }
}

// Widget con estado, lo que muestra cambia mientras la pantalla está abierta
class PantallaIdioma extends StatefulWidget {
  // Parámetro obligatorio, se pasa como titulo: 'Habla IA'
  final String titulo;

  const PantallaIdioma({super.key, required this.titulo});

  @override
  State<PantallaIdioma> createState() => _PantallaIdiomaState();
}

// El guion bajo hace que la clase solo se pueda usar dentro de este archivo
class _PantallaIdiomaState extends State<PantallaIdioma> {
  static const List<String> _idiomas = ['español', 'maya'];

  // El signo ? indica que puede no tener valor, es null hasta el primer análisis
  String? _idioma;
  double _confianza = 0;
  bool _analizando = false;
  int _intentos = 0;

  // Simula una clasificación que tarda un segundo, como la del modelo
  Future<void> _analizar() async {
    setState(() => _analizando = true);

    // await espera sin congelar la pantalla
    await Future.delayed(const Duration(seconds: 1));

    // Si el usuario salió de la pantalla mientras esperaba, ya no hay nada que actualizar
    if (!mounted) return;

    setState(() {
      _analizando = false;
      _idioma = _idiomas[_intentos % _idiomas.length];
      _confianza = 80 + _intentos * 2.5;
      _intentos++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ?? usa el texto de la derecha mientras _idioma sea null
            Text(_idioma ?? 'Sin resultado', style: const TextStyle(fontSize: 28)),

            // Un if dentro de la lista agrega el widget solo cuando se cumple
            if (_idioma != null) Text('${_confianza.toStringAsFixed(1)} % de confianza'),

            const SizedBox(height: 24),

            ElevatedButton(
              // Con null el botón queda desactivado mientras analiza
              onPressed: _analizando ? null : _analizar,
              child: Text(_analizando ? 'Analizando...' : 'Analizar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## La notación de Dart, cómo se lee el código

### Qué hace

Explica las partes del lenguaje que aparecen en el ejemplo y en todo el código de la app, cada una con lo que significa y un caso real de Habla IA donde se usa.

### Cómo se usa

Cada sección corresponde a algo que se ve en el ejemplo, así que conviene tener el código abierto al lado y buscar las líneas que se mencionan.

### Los widgets, `StatelessWidget` y `StatefulWidget`

#### Qué hace

En Flutter todo lo que se ve en pantalla es un widget, un texto, un botón, una columna o la pantalla completa, y se arman metiendo unos dentro de otros con `child` cuando llevan uno solo y `children` cuando llevan varios, como el `Scaffold` que contiene un `Center`, que contiene una `Column` con un texto y un botón. `StatelessWidget` sirve para lo que nunca cambia, como `EjemploApp`, y `StatefulWidget` para lo que cambia mientras se usa, como `PantallaIdioma`, que guarda sus datos en otra clase, `_PantallaIdiomaState`, porque el widget se vuelve a crear cada vez que se dibuja pero su estado se conserva. El método `build` devuelve el árbol de widgets y Flutter lo llama cada vez que necesita dibujar la pantalla.

#### Cómo se usa

Se crea una clase que extienda `StatelessWidget` o `StatefulWidget`, se escribe su `build` con `@override`, que indica que reemplaza el método de la clase de la que hereda, y desde el estado se leen los datos del widget con `widget.`, como en `widget.titulo`. El guion bajo al inicio de un nombre, como en `_PantallaIdiomaState` o `_analizar`, hace que solo se pueda usar dentro del mismo archivo. En la app, `principal_pagina.dart` es un `StatefulWidget` porque el idioma cambia mientras se graba, y `audios_pagina.dart` es un `StatelessWidget` porque solo contiene la lista.

### El estado y `setState`

#### Qué hace

Las variables del estado son los datos que se ven en pantalla, pero cambiarlas no basta para que la pantalla se actualice, hay que hacerlo dentro de `setState`, que avisa a Flutter que los datos cambiaron y que debe volver a llamar a `build`.

#### Cómo se usa

Para un solo cambio se escribe `setState(() => _analizando = true)` y para varios se usan llaves, como al final de `_analizar`. Después de esperar algo conviene revisar `mounted`, que dice si la pantalla sigue abierta, porque llamar a `setState` en una pantalla que ya se cerró da error, y por eso el ejemplo hace `if (!mounted) return;` igual que la pantalla principal de la app al recibir cada resultado del modelo.

### Los constructores, `required`, `final`, `const` y `super.key`

#### Qué hace

Los parámetros entre llaves son parámetros con nombre, que se pasan escribiendo su nombre, como `titulo: 'Habla IA'`, `required` los vuelve obligatorios y `this.titulo` guarda el valor directo en la variable de la clase. `final` indica que una variable recibe su valor una sola vez, `const` crea el valor al compilar para que Flutter lo reutilice sin volver a construirlo, y `super.key` pasa la llave del widget a la clase de la que hereda, algo que Flutter usa para saber qué widget es cuál cuando se redibuja.

#### Cómo se usa

El constructor del ejemplo es `const PantallaIdioma({super.key, required this.titulo})` y se llama con `PantallaIdioma(titulo: 'Habla IA')`, y conviene poner `const` delante de los widgets que nunca cambian, como `const SizedBox(height: 24)`, que además es lo que sugiere `flutter analyze`. En la app todas las clases de configuración de modelos, como `ConfiguracionModelo`, usan constructores `const` para poder escribir la lista de modelos fija en el código.

### Los valores vacíos, `?`, `??`, `?.`, `!` y `late`

#### Qué hace

Dart no deja usar un valor que podría ser `null` sin decirlo, el `?` después del tipo, como en `String? _idioma`, indica que puede no tener valor, `??` da una alternativa cuando lo que está a la izquierda es `null`, `?.` solo llama a algo si el valor existe, `!` afirma que el valor no es `null` y hace fallar la app si lo es, y `late` indica que una variable se va a llenar después, antes de usarla.

#### Cómo se usa

En el ejemplo `_idioma ?? 'Sin resultado'` muestra un texto mientras todavía no hay idioma, en la app `ClasificadorServicio` usa `_activo?.configuracion` para no fallar cuando aún no hay modelo cargado, y `late` aparece en las clases de entrada de los modelos para los valores que se calculan al leer el modelo. El `!` conviene usarlo lo menos posible, porque un error ahí cierra la app.

### Las funciones, `=>`, `async`, `await` y `Future`

#### Qué hace

`=>` es una forma corta de escribir una función que solo devuelve una cosa, como `main` o `createState` en el ejemplo. `Future` representa un valor que va a llegar más tarde, y una función marcada con `async` puede usar `await` para esperarlo sin congelar la pantalla, lo que permite que el botón muestre Analizando mientras pasa el segundo de espera.

#### Cómo se usa

Una función que espera algo se declara como `Future<void> _analizar() async` y dentro se escribe `await` antes de lo que hay que esperar, como `await Future.delayed(const Duration(seconds: 1))`. En la app casi todo lo lento funciona así, por ejemplo `await _clasificador.clasificar(segmento)` espera el resultado del modelo y `await GrabacionesDb.insertar(fila)` espera a que se guarde en la base de datos.

### El texto y las listas, `$`, `${}`, `if` dentro de `children` y la coma final

#### Qué hace

Dentro de un texto, `$variable` inserta el valor de una variable y `${...}` el resultado de una expresión, como `'${_confianza.toStringAsFixed(1)} % de confianza'`, que muestra la confianza con un decimal. Dentro de una lista de widgets se puede escribir `if` para agregar uno solo cuando se cumple una condición, y `...` para agregar varios de golpe, y la coma después del último parámetro hace que el formateador ponga cada parámetro en su propia línea.

#### Cómo se usa

En el ejemplo `if (_idioma != null) Text(...)` muestra la confianza solo cuando ya hay idioma, y en la pantalla principal de la app `if (graboSuficiente) ...[ ]` agrega el espacio y el texto de la confianza solo después de los primeros cinco segundos. Para acomodar el código se usa `dart format .` o la opción de formatear del editor, que respeta esas comas finales.

## Cómo funcionan los widgets por dentro

### Qué hace

Explica lo que pasa detrás de los widgets del ejemplo, cómo decide Flutter qué volver a dibujar, cómo acomoda cada cosa en la pantalla y cómo se pasan datos y avisos entre widgets, con los casos de la app donde se ve cada idea.

### Cómo se usa

Se lee después de probar el primer ejemplo, y cada sección indica en qué archivo de la app aparece lo que explica para poder verlo funcionando en el código real.

### El árbol de widgets y el redibujado

#### Qué hace

Un widget no es lo que se ve en pantalla sino la descripción de cómo debe verse, por eso no cambia una vez creado, y cuando algo cambia Flutter vuelve a llamar a `build`, compara la descripción nueva con la anterior y solo actualiza en pantalla lo que es distinto, lo que hace que redibujar sea barato aunque `build` se llame muchas veces. `build` se vuelve a ejecutar cuando se llama a `setState`, cuando el widget de arriba se redibuja y le pasa datos nuevos, o cuando cambia algo que el widget está escuchando.

#### Cómo se usa

Dentro de `build` solo se arma la descripción de la pantalla y nunca se hacen tareas lentas como leer archivos o llamar al modelo, que van en funciones aparte como `_analizar`, y los widgets que no cambian se marcan con `const` para que Flutter ni siquiera los compare. En la app, cada vez que llega un resultado del modelo `principal_pagina.dart` llama a `setState` y solo cambian en pantalla el texto del idioma y el de la confianza.

### El acomodo en pantalla, `Column`, `Row`, `Stack` y compañía

#### Qué hace

Cada widget le dice a sus hijos cuánto espacio tienen como máximo, cada hijo decide su tamaño dentro de ese límite y el padre los coloca, así que el acomodo se resuelve de arriba hacia abajo y de vuelta. `Column` pone sus hijos uno debajo de otro y `Row` uno al lado del otro, `Center` centra a su hijo, `Padding` le deja margen, `SizedBox` da un tamaño fijo o un espacio vacío, `Expanded` hace que un hijo de una `Column` o `Row` ocupe todo el espacio que sobra, y `Stack` encima varios widgets, que con `Positioned` se colocan en un lugar exacto.

#### Cómo se usa

Se eligen según cómo se quiera ver la pantalla y se meten unos dentro de otros, por ejemplo una `Column` con `mainAxisSize: MainAxisSize.min` ocupa solo lo que miden sus hijos, que es lo que permite centrarla con `Center` en el ejemplo. La pantalla principal de la app usa un `Stack` con dos `Positioned`, uno arriba para la onda de la voz y otro abajo para el idioma, y la lista de grabaciones usa un `Expanded` para que la lista ocupe todo el alto disponible.

### Pasar datos entre widgets, parámetros hacia abajo y avisos hacia arriba

#### Qué hace

Los datos bajan de un widget a sus hijos por los parámetros del constructor, y cuando un hijo necesita avisar algo hacia arriba, como que lo presionaron, el padre le pasa una función que el hijo llama en ese momento, de modo que el hijo no necesita saber qué pasa después y el padre sigue siendo el único dueño de los datos.

#### Cómo se usa

En la app el botón de grabar es un widget aparte, `ControlesGrabacion`, que recibe de la pantalla principal si se está grabando y la función que tiene que llamar al presionarlo.

```dart
ControlesGrabacion(
  grabando: grabando,
  onToggle: _gestionarGrabacion,
)
```

El botón usa `grabando` para cambiar su ícono y su color y llama a `onToggle` cuando lo presionan o cuando se cumple el minuto, y es la pantalla principal la que en `_gestionarGrabacion` decide si empieza o termina la grabación.

### Datos compartidos, `ChangeNotifier` y `ListenableBuilder`

#### Qué hace

Cuando un dato cambia muy seguido o lo usan varias partes de la app, en lugar de pasarlo de padre a hijo se guarda en una clase que extiende `ChangeNotifier`, que llama a `notifyListeners()` cada vez que cambia, y la parte de la pantalla que lo muestra se envuelve en un `ListenableBuilder`, que se redibuja sola al recibir el aviso sin redibujar el resto de la pantalla.

#### Cómo se usa

En la app `WaveformServicio` guarda los últimos niveles de volumen del micrófono y avisa cada vez que llega uno nuevo, unas veinte veces por segundo, y la pantalla principal solo redibuja la onda.

```dart
ListenableBuilder(
  listenable: _waveformServicio,
  builder: (context, _) => WaveformWidget(
    amplitudes: _waveformServicio.amplitudes,
    height: 150,
  ),
)
```

`ClasificadorServicio` también extiende `ChangeNotifier`, así que cualquier pantalla puede enterarse de que el usuario cambió de modelo escuchándolo de la misma forma.

## La comunicación con Kotlin

### Qué hace

Flutter no puede usar directamente el micrófono, los archivos del sistema ni otras partes de Android, así que para eso habla con código nativo en Kotlin a través de canales, que son como líneas de teléfono con un nombre, y cada lado manda mensajes por la línea con ese mismo nombre. Hay dos tipos, el canal de métodos, en el que Flutter pregunta y Kotlin responde una vez, y el canal de eventos, en el que Kotlin manda datos cuando quiere mientras Flutter esté escuchando. Los datos viajan convertidos automáticamente, un `String` de Dart llega como `String` a Kotlin, un `int` como `Int` o `Long`, un `double` como `Double`, un `bool` como `Boolean`, un `Map` como `Map`, una `List` como `List` y un `Uint8List` como `ByteArray`, y lo mismo al revés.

### Cómo se usa

Se elige un nombre para el canal, se crea con ese nombre exacto en Dart y en `MainActivity.kt`, y del lado de Kotlin se registra en `configureFlutterEngine`, que es lo primero que se ejecuta al abrir la app. El ejemplo de abajo tiene las dos partes completas y la última sección explica cómo lo hace Habla IA.

### El canal de métodos, `MethodChannel`

#### Qué hace

Sirve para pedirle algo a Kotlin y esperar la respuesta, Flutter llama a `invokeMethod` con el nombre del método y sus argumentos, Kotlin recibe la llamada en `setMethodCallHandler`, revisa `call.method` para saber qué le piden y contesta con `result.success` si todo salió bien, `result.error` si algo falló o `result.notImplemented` si no conoce ese método, y del lado de Flutter la respuesta llega como el resultado del `await` o como una excepción.

#### Cómo se usa

En Dart se crea el canal con `MethodChannel('com.ejemplo/metodos')` y se llama con `await _metodos.invokeMethod<int>('sumar', {'a': 2, 'b': 3})` dentro de un `try`, y en Kotlin cada método es un caso del `when (call.method)`, donde los argumentos se leen con `call.argument<Int>("a")` usando los mismos nombres del mapa que mandó Flutter. Kotlin tiene que responder siempre exactamente una vez, porque si no responde Flutter se queda esperando para siempre.

### El canal de eventos, `EventChannel`

#### Qué hace

Sirve para que Kotlin mande datos sin que Flutter los pida, Flutter empieza a escuchar con `receiveBroadcastStream().listen`, en ese momento Kotlin recibe `onListen` junto con un `EventSink`, por el que manda cada dato con `success` todas las veces que quiera, y cuando Flutter cancela la escucha Kotlin recibe `onCancel` para detener lo que estaba haciendo.

#### Cómo se usa

En Dart se guarda la suscripción que devuelve `listen` y se cancela en `dispose`, para que Kotlin deje de trabajar cuando la pantalla se cierra, y en Kotlin el `EventSink` solo se puede usar desde el hilo principal, por eso el ejemplo programa su tarea con un `Handler` del hilo principal. Si se mandan datos de varios tipos por el mismo canal conviene que cada uno sea un mapa con un campo `type`, como hace el ejemplo, para que Flutter sepa qué recibió.

### El ejemplo completo

#### Qué hace

Es una pantalla con un botón que le pregunta a Kotlin el modelo del teléfono y el resultado de una suma, y con un texto que muestra cuántos segundos lleva Kotlin mandando datos, que se actualiza solo cada segundo, de modo que usa los dos tipos de canal.

#### Cómo se usa

En el mismo proyecto de prueba del primer ejemplo, creado con `flutter create ejemplo`, se reemplaza `lib/main.dart` por el código de Dart y `android/app/src/main/kotlin/com/example/ejemplo/MainActivity.kt` por el de Kotlin, y se ejecuta `flutter run` en un teléfono o emulador Android, ya que los cambios en Kotlin necesitan detener la app y volver a correrla porque la recarga en caliente no los aplica.

El lado de Flutter, `lib/main.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MaterialApp(home: PantallaNativa()));

class PantallaNativa extends StatefulWidget {
  const PantallaNativa({super.key});

  @override
  State<PantallaNativa> createState() => _PantallaNativaState();
}

class _PantallaNativaState extends State<PantallaNativa> {
  // Los nombres de los canales tienen que ser idénticos a los de MainActivity.kt
  static const MethodChannel _metodos = MethodChannel('com.ejemplo/metodos');
  static const EventChannel _eventos = EventChannel('com.ejemplo/eventos');

  String _respuesta = 'Sin preguntar todavía';
  int _segundos = 0;
  StreamSubscription<dynamic>? _suscripcion;

  @override
  void initState() {
    super.initState();

    // Empieza a escuchar lo que mande Kotlin, cada dato llega como un mapa con su tipo
    _suscripcion = _eventos.receiveBroadcastStream().listen((dato) {
      if (dato is Map && dato['type'] == 'segundos') {
        setState(() => _segundos = dato['valor'] as int);
      }
    });
  }

  // Le pide dos cosas a Kotlin y espera cada respuesta
  Future<void> _preguntarAKotlin() async {
    try {
      final modelo = await _metodos.invokeMethod<String>('modeloTelefono');
      final suma = await _metodos.invokeMethod<int>('sumar', {'a': 2, 'b': 3});
      if (!mounted) return;
      setState(() => _respuesta = '$modelo, 2 + 3 = $suma');
    } catch (e) {
      // Llega aquí si Kotlin responde con un error o si el método no existe
      if (!mounted) return;
      setState(() => _respuesta = 'Error: $e');
    }
  }

  @override
  void dispose() {
    // Al cancelar, Kotlin recibe onCancel y deja de mandar datos
    _suscripcion?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter y Kotlin')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_respuesta, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _preguntarAKotlin,
              child: const Text('Preguntar a Kotlin'),
            ),
            const SizedBox(height: 32),
            Text('Kotlin lleva $_segundos segundos mandando datos'),
          ],
        ),
      ),
    );
  }
}
```

El lado de Kotlin, `MainActivity.kt`:

```kotlin
package com.example.ejemplo

import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // Permite programar tareas en el hilo principal, el único desde el que se puede hablar con Flutter
    private val manejador = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val mensajero = flutterEngine.dartExecutor.binaryMessenger

        // Canal de métodos, Flutter pregunta y Kotlin responde una sola vez a cada pregunta
        MethodChannel(mensajero, "com.ejemplo/metodos").setMethodCallHandler { call, result ->
            when (call.method) {
                "modeloTelefono" -> result.success("${Build.MANUFACTURER} ${Build.MODEL}")

                "sumar" -> {
                    // Los argumentos llegan en el mapa que mandó Flutter, con los mismos nombres
                    val a = call.argument<Int>("a") ?: 0
                    val b = call.argument<Int>("b") ?: 0
                    result.success(a + b)
                }

                // Si Flutter pide algo que no existe se le avisa para que no se quede esperando
                else -> result.notImplemented()
            }
        }

        // Canal de eventos, Kotlin manda datos cuando quiere mientras Flutter esté escuchando
        EventChannel(mensajero, "com.ejemplo/eventos").setStreamHandler(
            object : EventChannel.StreamHandler {
                private var tarea: Runnable? = null

                // Flutter empezó a escuchar, se manda un dato cada segundo
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    var segundos = 0
                    val nueva = object : Runnable {
                        override fun run() {
                            segundos++
                            events?.success(mapOf("type" to "segundos", "valor" to segundos))
                            manejador.postDelayed(this, 1000)
                        }
                    }
                    tarea = nueva
                    manejador.postDelayed(nueva, 1000)
                }

                // Flutter dejó de escuchar, se detiene la tarea para no gastar batería
                override fun onCancel(arguments: Any?) {
                    tarea?.let { manejador.removeCallbacks(it) }
                    tarea = null
                }
            }
        )
    }
}
```

### Cómo lo hace Habla IA

#### Qué hace

La app usa un canal de cada tipo, el de métodos se llama `com.hablaia/language` y por él Flutter pide `start` para empezar a grabar, `stop` para detener y `espectrograma` para que Kotlin calcule la imagen de un fragmento con los parámetros del modelo, y el de eventos se llama `com.hablaia/stream` y por él Kotlin manda mapas con `type` igual a `amplitude` para el volumen del micrófono, `segmento` con la ruta de cada fragmento nuevo de cinco segundos y `completo` cuando el audio completo está listo. Como grabar y calcular espectrogramas es lento, Kotlin hace ese trabajo en otros hilos y vuelve al hilo principal con `runOnUiThread` solo para responder o mandar el evento.

#### Cómo se usa

Del lado de Flutter los canales están en `lib/servicios/grabacion_servicio.dart` y en `lib/servicios/modelo/entradas_modelo.dart`, y los eventos se atienden en `_iniciarEscuchaStream` de `principal_pagina.dart`, mientras que del lado de Kotlin todo está en `android/app/src/main/kotlin/com/hablaia/MainActivity.kt`. Para agregar una función nueva se suma un caso al `when (call.method)` de Kotlin y su llamada con `invokeMethod` en Dart, y para mandar un dato nuevo a Flutter se usa `eventSink?.success` con un `type` nuevo y se agrega ese caso en `_iniciarEscuchaStream`.
