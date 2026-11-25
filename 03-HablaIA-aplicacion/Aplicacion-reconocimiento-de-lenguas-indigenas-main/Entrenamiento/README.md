# Entrenamiento del modelo de Habla IA

## Qué es

Es la carpeta donde se entrena el modelo que usa la app Habla IA para saber si una persona habla español o maya, y reúne los scripts que preparan el audio, el programa que lo convierte en imágenes, el script que entrena la red, los notebooks que la evalúan y los modelos que han salido de cada corrida.

## Qué hace

Convierte grabaciones de voz en un modelo listo para el teléfono, primero limpia los audios y los corta en clips de cinco segundos, luego los deja a 16 kHz en mono, después dibuja el espectrograma de cada clip como una imagen de 224 por 224, entrena con esas imágenes una red MobileNetV3Large y la exporta a TensorFlow Lite, el formato que lee la app. Los espectrogramas se hacen en Kotlin con el mismo código que usa la app, así el modelo ve en el teléfono exactamente el mismo tipo de imagen con el que aprendió, y todo lo demás se hace en Python.

## Cómo se usa

Lo más sencillo es abrir `Guia_pipeline_entrenamiento.ipynb`, que lleva todo el proceso paso a paso desde una sola configuración, aunque cada script también se puede correr por su cuenta en este orden, `PreparadorAudios.py`, `hacer16000.py`, el programa de Kotlin en `untitled/`, `entrenador.py` y al final `Untitled1_corregido.ipynb`. Hace falta Python 3.10, 3.11 o 3.12 con TensorFlow, NumPy, SciPy, Pillow, pydub, scikit-learn, pandas, openpyxl y matplotlib, y para la parte de Kotlin el JDK 23 con IntelliJ IDEA. Los audios no están en la carpeta, hay que ponerlos con una subcarpeta por idioma, como `audios_originales/español` y `audios_originales/maya`, porque el nombre de cada subcarpeta se vuelve la etiqueta y el orden alfabético decide su número, `español` el 0 y `maya` el 1.

## Audios uniformes, la regla para obtener buenos resultados

### Qué hace

Para que el modelo funcione bien, la frecuencia y la duración de los audios de entrenamiento tienen que ser lo más uniformes posible y además iguales a las que usan el modelo y la aplicación, porque el modelo solo aprende a reconocer audios parecidos a los que vio al entrenar, y si en el teléfono recibe fragmentos más largos, más cortos o con otra frecuencia, el espectrograma cambia de forma y el modelo se equivoca aunque el idioma sea el mismo. Si se entrena con clips de cinco segundos todos deben durar cinco segundos, y si se entrena con audio a 16 000 Hz el audio que llega al modelo cuando se usa la app también debe estar a 16 000 Hz, igual que debe coincidir el número de canales, que aquí es uno.

### Cómo se usa

En este proceso `PreparadorAudios.py` deja todos los clips en exactamente cinco segundos, rellenando con ceros los que quedan más cortos, y `hacer16000.py` los deja todos a 16 000 Hz en mono, así que hay que correr los dos sobre todos los audios sin saltarse ninguno. En la app, `GrabadorAudio.kt` corta la grabación en fragmentos de cinco segundos con `SEGMENT_SEC`, y graba directamente a 16 000 Hz con `FRECUENCIA_PREFERIDA`, así que el audio llega al modelo con la misma frecuencia con la que se entrenó, y solo en los teléfonos que no aceptan esa frecuencia graba a 44 100 Hz y el audio se convierte a 16 000 Hz antes de generar el espectrograma, según el `sampleRate` de la configuración del modelo en `modelos_disponibles_estructura.dart`. Si se entrena un modelo nuevo con otra duración o con otra frecuencia, hay que cambiar esos mismos valores en la app para que coincidan, `SEGMENT_SEC` para la duración, y `FRECUENCIA_PREFERIDA` junto con el `sampleRate` de la configuración del modelo para la frecuencia.

## Parte 1 · Python, preparar, entrenar y evaluar

### Qué hace

Se encarga de todo menos de los espectrogramas, deja los audios listos, reparte las imágenes para entrenar, entrena y exporta el modelo, mide sus resultados y guarda el historial de pruebas.

### Cómo se usa

Cada script tiene sus rutas escritas dentro, se ajustan y se ejecuta con `python <script>.py`, o se corre todo desde la guía, que ya tiene las rutas unificadas porque en los scripts no coinciden entre sí.

### `PreparadorAudios.py`, limpiar y cortar el audio

#### Qué hace

Quita los silencios de cada audio tomando como silencio lo que esté 20 dB por debajo de su volumen promedio, de modo que funciona igual con grabaciones fuertes que bajitas, une lo que queda y lo corta en clips de cinco segundos, completando el último con silencio si le falta, y los guarda como `<nombre>_clip_<n>.wav`.

#### Cómo se usa

Trabaja un idioma por vez, se cambian `CARPETA_ENTRADA` y `CARPETA_SALIDA` al final del archivo, por ejemplo a `audios/mayan/original` y `entrenamien/maya`, se corre `python PreparadorAudios.py` y se repite para el otro idioma, y en Python 3.13 o más nuevo pydub necesita además `pip install audioop-lts`.

### `hacer16000.py`, dejar el audio a 16 kHz mono

#### Qué hace

Pasa cada clip a 16 000 Hz y a un solo canal, que es como lo espera el generador de espectrogramas, y lo guarda con el mismo nombre en otra carpeta.

#### Cómo se usa

También va un idioma por vez, se cambian `CARPETA_ENTRADA` y `CARPETA_SALIDA`, por ejemplo a `entrenamien/español` y `entrenamiento/español`, y se corre `python hacer16000.py`.

### `entrenador.py`, entrenar y exportar el modelo

#### Qué hace

Reparte los espectrogramas en 80 % para entrenar, 10 % para validar y 10 % para probar, con un máximo de 2086 por idioma para que queden parejos, y entrena una MobileNetV3Large que ya viene preentrenada, primero solo la parte nueva que decide el idioma y después también sus últimas 30 capas con un aprendizaje más lento, deteniéndose sola cuando deja de mejorar. Al terminar lo prueba con las imágenes que apartó, guarda el modelo en `.keras` y lo exporta a `.tflite` en float16, y como tiene una sola salida, su valor es la probabilidad de que el audio sea maya.

#### Cómo se usa

Se corre `python entrenador.py` en esta carpeta, lee las imágenes de `espectrogramas/` y crea `dataset_split/`, que borra y vuelve a crear en cada corrida, junto con `modelo_maya_español.keras` y `modelo_maya_español.tflite`, que conviene renombrar sin la ñ porque así los busca la evaluación.

### `Untitled1_corregido.ipynb`, evaluar el modelo

#### Qué hace

Pasa las imágenes de prueba por el `.tflite`, igual que lo haría el teléfono, y calcula accuracy, precision, recall y F1, la matriz de confusión y el reporte por idioma, que guarda en `model_comparison.xlsx`, y además trae una función para saber qué idioma ve el modelo en un solo espectrograma.

#### Cómo se usa

Se abre con un kernel que tenga TensorFlow después de entrenar, con el modelo nombrado `modelo_maya_espanol.tflite` en esta carpeta, y se ejecutan sus celdas en orden.

### `Guia_pipeline_entrenamiento.ipynb`, la guía paso a paso

#### Qué hace

Explica cada script y lo ejecuta desde el notebook, procesa todos los idiomas de una vez, incluye una versión en Python del generador de espectrogramas por si no se tiene Kotlin, anota cada entrenamiento en `log.csv` y al final genera el código que hay que pegar en la app para declarar el modelo nuevo.

#### Cómo se usa

Se abre desde esta carpeta, se ajustan las rutas de la sección de configuración y se ejecutan las secciones de arriba hacia abajo.

### `log.csv` y `model_comparison.xlsx`, el historial de resultados

#### Qué hacen

`log.csv` guarda una línea por entrenamiento con los idiomas, el modelo base, los parámetros, la semilla, si los audios tenían silencio, los resultados y un código que identifica la combinación de parámetros, y `model_comparison.xlsx` guarda las métricas, la matriz de confusión y el reporte de la última evaluación.

#### Cómo se usan

`log.csv` se llena automáticamente al usar la guía y sirve para revisar qué se ha probado antes de entrenar otra vez, y `model_comparison.xlsx` se reemplaza en cada evaluación, así que hay que copiarlo si se quiere guardar uno anterior.

## Parte 2 · Kotlin, los espectrogramas

### Qué hace

Es el proyecto de la carpeta `untitled/`, que convierte cada clip en la imagen de su espectrograma con el mismo cálculo, los mismos valores y los mismos colores que usa la app en `GeneradorEspectrograma.kt`, porque si las imágenes del entrenamiento y las del teléfono no salieran iguales el modelo se equivocaría más.

### Cómo se usa

Se abre `untitled/` en IntelliJ IDEA con el JDK 23 y se ejecuta la función `main()` de `Main.kt`, sin cambiar nada si los clips están en `entrenamiento/`.

### `Main.kt`, recorrer las carpetas

#### Qué hace

Busca los WAV de cada subcarpeta de idioma y guarda su espectrograma como PNG en una subcarpeta con el mismo nombre, y al terminar dice cuántos archivos procesó y cuántos fallaron.

#### Cómo se usa

`CARPETA_ENTRADA` apunta a `entrenamiento/`, donde deja los clips `hacer16000.py`, y `CARPETA_SALIDA` a `espectrogramas/`, donde los busca `entrenador.py`, las dos relativas a `untitled/`, que es desde donde IntelliJ ejecuta el proyecto, así que funcionan en cualquier computadora sin cambiarlas, y al empezar el programa muestra la ruta completa de cada una para confirmar que son las correctas.

### `MelSpectogramGenerator.kt`, dibujar el espectrograma

#### Qué hace

Lee el audio, lo lleva a 16 kHz, lo divide en ventanas de 2048 muestras que avanzan de 512 en 512, mide cuánta energía hay en 128 bandas de frecuencia entre 0 y 8000 Hz, la pasa a decibeles respecto al punto más fuerte del clip con un mínimo de −80 dB y la pinta en 224 por 224 con la paleta inferno, con los graves abajo y el tiempo de izquierda a derecha.

#### Cómo se usa

Lo llama `Main.kt`, así que no hace falta tocarlo, y si alguna vez se cambian sus valores hay que cambiarlos igual en la app, porque el modelo solo reconoce bien imágenes hechas de la misma forma.

## Los modelos entrenados

### Qué son

Son los modelos que salieron de este mismo proceso, `modelo_maya_espanolno.keras` con su versión `modelo_maya_espanolNo.tflite` son del 9 de junio de 2026, y `modelo_maya_espanol.keras`, `modelo_maya_espanol1.keras` y `modelo_maya_espanol2.keras` son del 19 de julio de 2026, que solo están en `.keras` porque su `.tflite` no se guardó en la carpeta.

### Cómo se usan

Los `.keras` se pueden cargar en Python para evaluarlos o seguir entrenándolos, y como pesan mucho no se suben al repositorio, así que solo existen en la computadora donde se entrenaron, mientras que el `.tflite` se puede llevar a la app copiándolo a `lib/modelos/` y declarándolo como explica su `MODELOS.md`.
