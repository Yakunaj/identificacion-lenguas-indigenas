# 01 — Clasificación maya-español

Este proyecto contiene la metodología empleada para entrenar un modelo de clasificación de imágenes con el objetivo de clasificar lenguas: español mexicano y maya, con experimentos adicionales que incluyen náhuatl. La metodología cubre desde la decisión de emplear clasificación de imágenes, pasando por la obtención de los audios y el código para su manejo, hasta el entrenamiento del modelo.

## Clasificación a partir de imágenes

El entrenamiento se realiza con las imágenes de espectrogramas extraídas de los audios. Se usan espectrogramas porque trabajar con ellos no requiere anotaciones ni transcripciones, y existen trabajos previos que aprovechan esta propiedad [1].

El flujo es el siguiente:

1. Los archivos WAV se transforman en imágenes de espectrograma (mel-espectrograma) con `librosa`. El notebook también incluye una variante con etiquetas de tiempo y frecuencia para visualización, aunque el entrenamiento usa las imágenes sin etiquetas.
2. Las imágenes se cargan a 224 × 224 píxeles, se dividen en entrenamiento y prueba (80/20, estratificado) y se normalizan según el modelo base.
3. Una CNN preentrenada extrae características y una cabeza densa realiza la clasificación binaria.
4. Se registran las métricas (accuracy, recall, precision y F1) y la matriz de confusión de cada experimento en una bitácora (CSV).

## Estructura

La organización actual concentra los espectogramas y audios en `datos/`, el código y notebooks en `codigo/`, los resultados y bitácora en `resultados/`, los modelos en `modelos/` y la documentación de terceros en `documentos/`. Obteniendo el siguiente arbol:


```text
01-clasificacion-maya-espanol/
├── codigo/
│   ├── Audio Classification (CNN).ipynb
│   └── helpers/
├── datos/
│   ├── audios/{mayan, nahuatl, spanish}/
│   └── spectrograms/{mayan, nahuatl, spanish}/
├── documentos/
│   └── Puebla-Nahuatl-Manifest/
├── modelos/
└── resultados/
    ├── graficas/{spanish_mayan, mayan_nahuatl, spanish_nahuatl}/
    ├── log.csv
    └── metadatos/
```

### `datos/audios/`

Contiene los archivos de audio utilizados en los distintos experimentos, separados por lengua.

- **`mayan/original/`**: audios originales, sin otro procesamiento que el trozado (*clipping*).
- **`mayan/audios_maasab_with_silence/`**: audios del corpus Maasab.
- **`mayan/audios_maasab_no_silence_audacity/`**: audios del corpus Maasab después de aplicar la macro de Audacity `trim_silence_audacity.txt` para eliminar el silencio.
- **`mayan/mayan_one_second/`**: todos los clips de un segundo obtenidos de los audios originales.
- **`mayan/mayan_one_second_without_maasab_corpus/`**: clips de un segundo de los audios originales, excluyendo los procedentes del corpus Maasab.
- **`mayan/mayan_without_maasab_corpus/`**: audios mayas sin los archivos del corpus Maasab.
- **`nahuatl/nahuatl_ten_seconds/`**: clips de diez segundos de los audios seleccionados.
- **`nahuatl/nahuatl_one_second/`**: clips de un segundo obtenidos de los clips de diez segundos.
- **`nahuatl/chosen_one_speaker_audios.txt`**: información sobre los audios seleccionados del corpus original tras separar a los hablantes en canales diferentes, trozarlos y guardarlos en `nahuatl_ten_seconds/`.
- **`spanish/original/`**: audios originales, sin ningún procesamiento.
- **`spanish/spanish_no_silence/`**: audios tras aplicar la macro `trim_silence_audacity.txt` para eliminar el silencio.
- **`spanish/spanish_no_silence_without_maasab/`**: audios sin silencio, excluyendo los procedentes del corpus Maasab.

> **Nota:** por las restricciones de tamaño de archivo de GitHub no se pudieron incluir en el repositorio los audios náhuatl anteriores al trozado. El enlace al corpus original y el procesamiento aplicado se describen en la sección [Corpora](#corpora).

### `datos/spectrograms/`

Contiene los espectrogramas utilizados en los distintos experimentos, separados por lengua. Cada grupo de audios tiene, en general, su carpeta equivalente de espectrogramas:

- **`mayan/`**: `original/`, `mayan_without_silence/`, `mayan_without_maasab_corpus/`, `mayan_one_second/` y `mayan_one_second_without_maasab_corpus/`.
- **`nahuatl/`**: `nahuatl_ten_seconds/` y `nahuatl_one_second/`.
- **`spanish/`**: `original/`, `spanish_no_silence/` y `spanish_no_silence_without_maasab_corpus/`.

Algunos nombres de carpetas de espectrogramas no coinciden exactamente con los de audios (por ejemplo, `spanish_no_silence_without_maasab` frente a `spanish_no_silence_without_maasab_corpus`); las rutas reales son las que se indican aquí y las que aparecen en la bitácora de experimentos.

### `codigo/helpers/`

Scripts y macros que ayudan a modificar los audios:

- **`remove_silence.py`**: elimina el silencio de los audios mediante la biblioteca `librosa`.
- **`split_audios.py`**: divide los audios en clips de una longitud determinada.
- **`trim_silence_audacity.txt`**: macro importable en el software *Audacity* para eliminar el silencio de los audios.

> **Nota:** se recomienda usar `trim_silence_audacity.txt` en lugar de `remove_silence.py` para eliminar silencios, ya que fue más eficaz durante los experimentos. Estas herramientas se ejecutan por separado, como paso previo manual; el notebook no las importa.

### `resultados/`

- **`graficas/`**: contiene la matriz de confusión y la gráfica de entrenamiento de la mayor parte de los experimentos, agrupadas en carpetas por par de lenguas (`spanish_mayan`, `mayan_nahuatl` y `spanish_nahuatl`). Los archivos se identifican como `[ID_Exp]_plot` y `[ID_Exp]_matrix`, donde `[ID_Exp]` es el identificador único del experimento según la bitácora.
- **`log.csv`**: bitácora de experimentos (descrita abajo).
- **`metadatos/`**: carpeta reservada para metadatos procesados.

### `documentos/`

Contiene los artículos de referencia, el documento de licencia del corpus Puebla-Náhuatl y toda la documentación oficial del corpus en `Puebla-Nahuatl-Manifest/`.

### `modelos/`

Este proyecto no distribuye modelos entrenados: el notebook entrena el clasificador durante su ejecución y guarda el resultado como `modelos/model.keras`.

## Bitácora de experimentos

`resultados/log.csv` registra los detalles relevantes de cada experimento. Los campos son:

| Campo | Descripción |
|---|---|
| `ID_Exp` | Identificador único auto-incremental de cada experimento. |
| `Hash` | Hash único generado a partir de los distintos parámetros del experimento. |
| `Languages` | Lista de lenguas incluidas en el experimento. |
| `Model` | Modelo utilizado en el entrenamiento. |
| `Audio_Length` | Duración de cada audio; se deja en blanco si no se estandarizó. |
| `Image_Amount` | Número de imágenes por lengua incluidas en el experimento. |
| `Parameters` | Distintos parámetros ajustables (frecuencia de audio, tasa de aprendizaje, tamaño de lote, etc.). |
| `Split_Seed` | Semilla usada al dividir las imágenes en entrenamiento y prueba. |
| `hasSilence` | `"True"` si los audios no se procesaron para eliminar el silencio; `"False"` si se eliminó. |
| `Results` | Valores de accuracy, recall, precision y F1 del experimento. |
| `Audio_Folders_Used` | Lista de rutas a las carpetas de audio usadas en el experimento. |
| `Notes` | Observaciones adicionales. |

Todos los campos excepto `Notes` se registran automáticamente siguiendo el proceso de entrenamiento descrito en `codigo/Audio Classification (CNN).ipynb`.

## Corpora

Los audios de dominio público se pueden encontrar en las siguientes fuentes.

### Español mexicano

- **Ciempiess-Balance**: <https://mega.nz/folder/k0QTyA6C#iRwTHwEqjYdlOlAVbMSFKw> [2].
  El CIEMPIESS BALANCE es un corpus de radio diseñado para crear modelos acústicos para el reconocimiento automático de voz; se compone de grabaciones de conversaciones espontáneas en español mexicano entre un moderador de radio y sus invitados. Está formado por 8555 archivos de audio con transcripción: 2447 (28,6 %) de hablantes hombres y 6108 (71,39 %) de hablantes mujeres. Se seleccionaron al azar 1317 archivos de los 8555 originales, procurando mantener el equilibrio entre sexos, lo que dio 778 archivos de hablantes mujeres y 539 de hablantes hombres.

### Maya

- **T'aantsil**: <https://taantsil.com.mx/> [3]. Es un corpus de audio en lengua maya yucateca, creado con el objetivo de apoyar el desarrollo de tecnologías del habla para lenguas indígenas. Forma parte de un esfuerzo más amplio por documentar y preservar las lenguas nativas mediante recursos digitales.
- **Yucatec Maya DoReCo**: <https://sharedocs.huma-num.fr/wl/?id=OEm80dNUe88cfpejRnhmFE5IIFeGdCp9> [4]. El conjunto de datos fue compilado por Stavros Skopeteas en 2015 y procesado posteriormente para DoReCo por Alejandra Camelo Cruz, Ludger Paschen y Matthew Stave entre 2019 y 2022. Los archivos en los que se basa forman parte de una colección más amplia de datos en maya yucateco de Stavros Skopeteas, archivada en TLA (<https://hdl.handle.net/1839/00-0000-0000-0021-E91B-F>). El conjunto consta de 10 archivos de audio, de entre 6 y 13 minutos de duración; al dividirlos se obtuvieron 792 clips utilizados en el entrenamiento.

### Náhuatl

- **Puebla-Náhuatl**: <https://www.openslr.org/92> [6]. La documentación de este corpus se encuentra en `documentos/Puebla-Nahuatl-Manifest/`. Debido a las restricciones de tamaño de GitHub, los audios originales anteriores al trozado no se incluyeron en el repositorio: el enlace anterior apunta al corpus original y a continuación se describe el procesamiento realizado.

  Los audios de entrenamiento se tomaron todos de la subcarpeta `Medicina_79` del corpus original, con un total de 79 audios. La mayoría tiene dos hablantes, cada uno grabado en un canal distinto, por lo que los audios se separaron en dos (uno por canal) con Audacity. Su duración oscilaba entre un minuto y más de una hora, así que, usando `documentos/Puebla-Nahuatl-Manifest/Metadata/Metadata_Cuetzalan-954-Recordings.xml`, se seleccionaron algunos audios según género y duración para trozarlos en clips de 10 segundos. Esto produjo un total de 1747 clips; consultando `datos/audios/nahuatl/chosen_one_speaker_audios.txt` se puede saber qué audios se eligieron para trozarse.

## Entrenamiento del modelo

El archivo `codigo/Audio Classification (CNN).ipynb` contiene todo el código necesario para realizar el entrenamiento una vez recopilados los datos de audio. Su contenido es una adaptación y una serie de funciones adicionales basadas en el notebook de <https://github.com/jeffprosise/Deep-Learning/blob/master/Audio%20Classification%20(CNN).ipynb> [5].

Aunque el notebook describe el procedimiento para un solo modelo, es posible emplear otros modelos en el entrenamiento. El modelo base actual se identifica con este fragmento de código:

```python
from tensorflow.keras.applications import ResNet152V2
from tensorflow.keras.applications.resnet import preprocess_input

base_model = ResNet152V2(weights='imagenet', include_top=False, input_shape=(224, 224, 3))
```

Para entrenar con otros modelos base, hay que sustituir `ResNet152V2` por cualquiera de los modelos oficiales de Keras listados en <https://keras.io/api/applications/> [7], y reemplazar `tensorflow.keras.applications.resnet` por el módulo correspondiente según el modelo elegido, de acuerdo con la lista oficial de aplicaciones de Keras en <https://www.tensorflow.org/api_docs/python/tf/keras/applications> [8].

## Resultados registrados

Dieciséis experimentos (`EXP0`–`EXP15`) con MobileNetV2, ResNet50, ResNet152, ResNet152V2, MobileNetV3Small/Large y EfficientNetB7. Mejor accuracy por par de lenguas según `resultados/log.csv`:

| Par de lenguas | Experimentos | Mejor accuracy | Modelo |
|---|---|---|---|
| español–maya | EXP0–EXP2 | 0,906 | ResNet152 (EXP2) |
| maya–náhuatl | EXP3–EXP11 | 0,996 | EfficientNetB7 (EXP8) |
| náhuatl–español | EXP12–EXP15 | 0,999 | MobileNetV3Large (EXP12) |

`EXP7` tiene métricas en la bitácora, pero no cuenta con gráficas.

## Cómo reproducirlo

Requiere Python con `tensorflow`, `keras`, `librosa`, `scikit-learn` y `seaborn`, además de los audios fuente con licencia autorizada. Se definen en el notebook las rutas de los audios por lengua y se ejecutan las celdas en orden: generación de espectrogramas, carga de imágenes, entrenamiento (Adam con tasa de aprendizaje `1e-4`, 10 épocas y *early stopping* con paciencia 3) y evaluación.

El notebook usa las rutas de la estructura actual, relativas a su ubicación en `codigo/`: `../datos/audios/...` para los WAV, `../datos/spectrograms/...` para los espectrogramas, `../resultados/log.csv` para la bitácora y `../modelos/model.keras` para el modelo guardado. Para el ejemplo de náhuatl se emplea `../datos/audios/nahuatl/nahuatl_ten_seconds/`, porque la carpeta original anterior al trozado no está incluida. Las gráficas se guardan en `resultados/graficas/<par_de_lenguas>/` con los nombres `[ID_Exp]_plot.png` y `[ID_Exp]_matrix.png`.

## Relación con otros proyectos

- [`02 — Aumento de datos y modelos ligeros`](../02-clasificacion-maya-espanol+aumento-de-datos/): continúa esta línea base con aumento de datos y modelos ligeros.
- [`03 — Aplicación HablaIA`](../03-HablaIA-aplicacion/): aplicación móvil que clasifica la lengua en el dispositivo.
- [`04 — Clasificación maya-náhuatl-zapoteco`](../04-clasificacion-maya-nahuatl-zapoteco/): extiende la clasificación a múltiples lenguas.

## Referencias

1. Mukherjee, H., Ghosh, S., Sen, S., Sk Md, O., Santosh, K. C., Phadikar, S., & Roy, K. (2019). Deep learning for spoken language identification: Can we visualize speech signal patterns?. *Neural Computing and Applications*, 31, 8483–8501.
2. Ciempiess-unam. Recuperado de <https://ciempiess.org/downloads>.
3. T'aantsil. Recuperado de <https://taantsil.com.mx/>.
4. Skopeteas, Stavros, Amedee Colli Colli, Daniela Schellenbach, Carolin Brokmann, Florian Fischer and Maya Gálvez Wimmelmann. 2024. Yucatec Maya DoReCo dataset. In Seifart, Frank, Ludger Paschen and Matthew Stave (eds.). *Language Documentation Reference Corpus (DoReCo) 2.0*. Lyon: Laboratoire Dynamique Du Langage (UMR5596, CNRS & Université Lyon 2). <https://doi.org/10.34847/nkl.9cbb3619>.
5. Jeff Prosise (2021). Deep-Learning [Software]. GitHub. <https://github.com/jeffprosise/Deep-Learning/blob/master/Audio%20Classification%20(CNN).ipynb>.
6. Highland Puebla Nahuatl speech translation corpus for endangered language documentation. Shi, Jiatong and Amith, Jonathan D and Chang, Xuankai and Dalmia, Siddharth and Yan, Brian and Watanabe, Shinji. *Proceedings of the First Workshop on Natural Language Processing for Indigenous Languages of the Americas*. 53–63, 2021.
7. Keras. Recuperado de <https://keras.io/api/applications/>.
8. Tensorflow. Recuperado de <https://www.tensorflow.org/api_docs/python/tf/keras/applications>.

## Autoría y licencia

La metodología, los experimentos y el código proceden del trabajo original `Language-Classification-CNN`. La autoría dentro de este repositorio está pendiente de definir (`[P]`). La licencia del repositorio es provisional, según [`../LICENSE`](../LICENSE), y los corpus de terceros conservan sus licencias y avisos originales, en particular la documentación incluida en `documentos/Puebla-Nahuatl-Manifest/`.
