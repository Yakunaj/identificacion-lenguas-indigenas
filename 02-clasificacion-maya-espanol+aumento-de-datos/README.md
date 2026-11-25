# 02 — Aumento de datos y modelos ligeros (maya-español)

Este proyecto continúa la línea base del proyecto 01 con el estudio de técnicas de aumento de datos (*data augmentation*) y modelos ligeros para la clasificación maya-español de espectrogramas. La metodología cubre desde la decisión de emplear arquitecturas convolucionales compactas, pasando por el balanceo de clases y la augmentación artificial de los espectrogramas, hasta el registro de los cuarenta y un experimentos y la evaluación de los modelos. El documento `documentos/Tesis_MODELOS_LIGEROS.pdf` narra el proceso completo y motiva la aplicación final en entornos médicos bilingües.

## Clasificación a partir de imágenes

Como en el proyecto 01, el entrenamiento se realiza con imágenes de espectrogramas extraídas de los audios, lo que evita la necesidad de anotaciones o transcripciones y aprovecha trabajos previos que validan esta propiedad [1]. Aquí, además, los espectrogramas ya vienen sin silencio (generados en el proyecto 01) y se aumentan artificialmente para contrarrestar el sesgo hacia el español y el sobreajuste detectados en los primeros experimentos.

El flujo es el siguiente:

1. Se parte de los espectrogramas sin silencio de las carpetas `datos/spectograms/mayan_without_silence/` y `datos/spectograms/spanish_no_silence/`, con 392 y 546 imágenes PNG respectivamente.
2. Se balancean las clases a un número fijo de imágenes por lengua: 1500 en el notebook de MobileNetV2, 1400 en el de EfficientNetB0 y 1350 en el de MobileNetV3-Small.
3. Las imágenes se cargan a 224 × 224 píxeles, se dividen en entrenamiento, validación y prueba (80/10/10, con semilla `1`) y se normalizan según el modelo base.
4. Se aplica *data augmentation* sobre los espectrogramas con `RandomFlip`, `RandomRotation`, `RandomZoom` y `RandomContrast`.
5. Una CNN ligera preentrenada en ImageNet extrae características (o se integra al modelo completo) y una cabeza densa realiza la clasificación binaria.
6. Se registran las métricas (accuracy, recall, precision y F1), la matriz de confusión y la curva de entrenamiento de cada experimento en una bitácora (CSV).

## Estructura

La organización concentra los espectrogramas en `datos/`, los notebooks en `codigo/`, la tesis en `documentos/`, los modelos entrenados en `modelos/` y la bitácora, gráficas y detalle de experimentos en `resultados/`. Obteniendo el siguiente árbol:

```text
02-clasificacion-maya-espanol+aumento-de-datos/
├── codigo/
│   ├── EfficientNet_Tesis_Entrenamiento_CNN.ipynb
│   ├── Entrenamiento_CNN.ipynb
│   └── movilnet3_Copia de Copia de Tesis_Entrenamiento_CNN.ipynb
├── datos/
│   └── spectograms/
│       ├── mayan_without_silence/
│       └── spanish_no_silence/
├── documentos/
│   └── Tesis_MODELOS_LIGEROS.pdf
├── modelos/
│   └── EXP1_model.keras … EXP40_model.keras
└── resultados/
    ├── graficas/
    │   └── EXP26_accuracy_plot.png … EXP39_accuracy_plot.png
    ├── log.csv
    └── EXP*_results.txt / EXP*_details.txt
```

### `datos/spectograms/`

Contiene los espectrogramas sin silencio empleados en todos los experimentos, separados por lengua: `mayan_without_silence/` (392 archivos PNG) y `spanish_no_silence/` (546 archivos PNG). Son el resultado de aplicar la macro de Audacity para eliminar silencios descrita en el proyecto 01, sobre los audios de los corpora indicados en la sección [Corpora](#corpora). El nombre de la carpeta conserva la grafía `spectograms` usada originalmente en los notebooks y en Google Drive.

### `codigo/`

Tres notebooks de Google Colab, prácticamente idénticos salvo por la arquitectura y los ajustes de cada modelo:

| Notebook | Modelo base | Augmentación en el modelo | Audios por lengua |
|---|---|---|---|
| [`Entrenamiento_CNN.ipynb`](codigo/Entrenamiento_CNN.ipynb) | MobileNetV2 | Capas `data_augmentation` activas | 1500 |
| [`EfficientNet_Tesis_Entrenamiento_CNN.ipynb`](codigo/EfficientNet_Tesis_Entrenamiento_CNN.ipynb) | EfficientNetB0 | Definida pero comentada | 1400 |
| [`movilnet3_Copia de Copia de Tesis_Entrenamiento_CNN.ipynb`](codigo/movilnet3_Copia%20de%20Copia%20de%20Tesis_Entrenamiento_CNN.ipynb) | MobileNetV3-Small | Definida pero comentada | 1350 |

> **Nota:** la bitácora registra estrategias de aumentación en casi todos los experimentos, pero solo el notebook de MobileNetV2 añade realmente las capas al modelo. En los otros dos las capas están comentadas y el entrenamiento se hace con las imágenes originales; el campo `Data_augmentation` se conserva en el CSV por el diccionario de registro. Esto explica que el mejor accuracy de la bitácora local no coincida con el reportado en la tesis.

### `documentos/`

Contiene [`Tesis_MODELOS_LIGEROS.pdf`](documentos/Tesis_MODELOS_LIGEROS.pdf), la tesis *Modelos ligeros de redes neuronales convolucionales para clasificación de espectrogramas de audio en entornos médicos bilingües (maya-español)*, presentada por Carlos Eduardo Tec Cahun y Jonathan David Chi Quiñones en la Universidad Intercultural Maya de Quintana Roo el 31 de agosto de 2025. El documento describe la alineación del corpus paralelo, la generación de espectrogramas, las dos fases experimentales y las conclusiones.

### `modelos/`

Contiene cuarenta archivos `.keras`, uno por experimento (`EXP1_model.keras` a `EXP40_model.keras`; el de `EXP2` se guardó como `EXP2_model_0.76.keras`). No hay modelo para `EXP0`, el experimento inicial de prueba con accuracy 0,5. Cada modelo se guarda al final del entrenamiento desde la celda correspondiente del notebook.

### `resultados/`

- **`log.csv`**: bitácora de experimentos (descrita abajo), con 41 filas `EXP0`–`EXP40`.
- **`graficas/`**: 13 gráficas de accuracy de entrenamiento y validación con el formato `[ID_Exp]_accuracy_plot.png` (`EXP26`–`EXP37` y `EXP39`). No todos los experimentos tienen gráfica.
- **`EXP*_results.txt` y `EXP*_details.txt`**: 31 archivos de texto con las métricas, la matriz de confusión, los parámetros y los datos de cada época. Los archivos `_results.txt` proceden del notebook de EfficientNetB0 y los `_details.txt` del de MobileNetV3-Small.

## Bitácora de experimentos

`resultados/log.csv` registra los detalles relevantes de cada experimento. Los campos son:

| Campo | Descripción |
|---|---|
| `ID_Exp` | Identificador único auto-incremental de cada experimento (`EXP0`–`EXP40`). |
| `Hash` | Hash MD5 generado a partir de lenguas, silencios, longitud, balance, audios usados, modelo, aumentación, parámetros y división. |
| `Languages` | Lista de lenguas incluidas, siempre `['maya', 'spanish']`. |
| `Audio_Folders_Used` | Carpetas de espectrogramas usadas, siempre `['spanish_no_silence', 'mayan_without_silence']`. |
| `Image_Amount` | Número de imágenes disponibles por lengua (`{'spanish': 2125, 'maya': 1725}`; `1726` en los dos primeros experimentos). |
| `hasSilence` | `"False"` en todos los experimentos, porque los silencios se eliminaron con Audacity. |
| `Audio_Length` | Duración del audio; se deja en blanco porque no se estandarizó. |
| `Balance` | `1` si se balancean las clases al número de audios elegido; `0` si no. Todos los experimentos usan `1`. |
| `Audios_usados` | Número fijo de imágenes por lengua tras balancear (1726, 1500, 1400, 1350 o 1300 según el experimento). |
| `Model` | Modelo utilizado: `MobileNetV2`, `MobileNetV3-Small` o `EfficientNetB0`. |
| `Data_augmentation` | Estrategias registradas: `RandomFlip` horizontal y vertical, `RandomRotation` (0.2 o 0.1), `RandomZoom` 0.2 y `RandomContrast` 0.2. `EXP39` no tiene valor. |
| `Parameters` | `batch_size`, `epochs` y `learning_rate` de cada corrida. |
| `Split_usado` | División 80 % entrenamiento, 10 % validación, 10 % prueba en todos los experimentos. |
| `Split_Seed` | Semilla de la división, siempre `1` (reproducible). |
| `Results` | Valores de accuracy, recall, precision y F1 del experimento. |
| `Notes` | Observación común: «tratando de reproducir los resultados del paper a partir de los espectogramas sin silencios». |

Todos los campos excepto `Notes` se registran automáticamente siguiendo el proceso de entrenamiento de los notebooks, que guardan la bitácora como `log.csv` en la raíz del directorio de trabajo de Google Drive; la copia incluida en el repositorio es `resultados/log.csv`.

## Corpora

Los espectrogramas proceden de los mismos audios de dominio público del proyecto 01, alineados como corpus paralelo maya-español. Las fuentes, licencias y el procesamiento aplicado se describen en la sección [Corpora](../01-clasificacion-maya-espanol/README.md#corpora) del proyecto 01:

- **Español mexicano**: CIEMPIESS-Balance.
- **Maya**: T'aantsil y Yucatec Maya DoReCo.

## Entrenamiento del modelo

Los tres notebooks siguen el mismo esqueleto, heredado del notebook de clasificación de audio de Jeff Prosise [5]. Se ejecutan en Google Colab, montan Google Drive y usan `directorio_de_trabajo = "/content/drive/MyDrive/spectograms"` como carpeta raíz; allí se leen las carpetas `mayan_without_silence/` y `spanish_no_silence/`, se guarda la bitácora `log.csv` y se escriben el resto de resultados en la subcarpeta `experimentos/`.

El procedimiento común es:

1. Contar los espectrogramas de cada lengua y fijar las variables de la bitácora (`languages`, `hasSilence = False`, `audio_length = ""`, `image_amount`).
2. Balancear las clases con `numero_audios_usados` y cargar las imágenes con `keras.preprocessing.image.load_img`, redimensionadas a 224 × 224.
3. Dividir en entrenamiento/validación/prueba con `train_test_split` de scikit-learn según `split_usado` y aplicar `to_categorical` a las etiquetas.
4. Preprocesar los píxeles con la función `preprocess_input` correspondiente al modelo base y usar `weights='imagenet', include_top=False`.
5. Construir la cabeza de clasificación, entrenar con `EarlyStopping(monitor='val_loss', patience=5, restore_best_weights=True)` y evaluar con matriz de confusión y métricas.
6. Calcular el hash del experimento, añadir la fila al CSV, guardar el modelo `.keras` y escribir los archivos de texto y la gráfica.

Las diferencias de arquitectura son:

```python
# Entrenamiento_CNN.ipynb — MobileNetV2
base_model = MobileNetV2(weights='imagenet', include_top=False, input_shape=(224, 224, 3))
base_model.trainable = False
# Input(224,224,3) → data_augmentation → Flatten → Dense(256, relu, l2(1e-4))
# → BatchNormalization → Dropout(0.7) → Dense(2, sigmoid)
# Adam(lr=1e-4), binary_crossentropy
```

```python
# EfficientNet_Tesis_Entrenamiento_CNN.ipynb — EfficientNetB0
base_model = EfficientNetB0(weights='imagenet', include_top=False, input_shape=(224, 224, 3))
base_model.trainable = False
fine_tune_learning_rate = parameters["learning_rate"] * 0.1  # 5e-05
# Flatten → Dense(256, relu, l2(1e-4)) → BatchNormalization
# → Dropout(0.7) → Dense(2, sigmoid)
# Adam(lr=5e-05), binary_crossentropy
```

```python
# movilnet3_Copia de Copia de Tesis_Entrenamiento_CNN.ipynb — MobileNetV3-Small
base_model = MobileNetV3Small(weights='imagenet', include_top=False, input_shape=(224, 224, 3))
base_model.trainable = False
# base_model → GlobalAveragePooling2D → Dense(256, relu, l2(1e-4))
# → BatchNormalization → Dropout(0.6) → Dense(len(languages), softmax)
# Adam(lr=1e-4), categorical_crossentropy
# entrenamiento end-to-end sobre x_train (no sobre características extraídas)
```

Los parámetros declarados en los notebooks son `batch_size = 20`, `epochs = 30` y `learning_rate = 1e-4`, aunque la bitácora documenta pruebas con valores de 16 a 64, 30 a 60 épocas y tasas de `1e-4` a `1e-6`.

## Resultados registrados

La bitácora contiene 41 experimentos (`EXP0`–`EXP40`) con tres arquitecturas ligeras. Mejor accuracy por modelo según `resultados/log.csv`:

| Modelo | Experimentos | Mejor accuracy | Experimento |
|---|---|---|---|
| EfficientNetB0 | EXP5–EXP6, EXP11–EXP12, EXP23–EXP37, EXP39 | 0,9036 | EXP6 (1400 audios, aug. 0.2, `batch_size=20`, 30 épocas, LR `1e-4`) |
| MobileNetV2 | EXP0–EXP1 | 0,7867 | EXP1 (1500 audios, aug. 0.2, `batch_size=20`, 30 épocas, LR `1e-4`) |
| MobileNetV3-Small | EXP2–EXP4, EXP7–EXP10, EXP13–EXP22, EXP38, EXP40 | 0,7846 | EXP9 (1300 audios, aug. 0.1, `batch_size=20`, 30 épocas, LR `1e-4`) |

La tesis, por su parte, organiza el trabajo en dos fases. En la primera los modelos presentaron sobreajuste y un sesgo marcado hacia el español; en la segunda se aplicó *data augmentation* para compensar la escasez de datos. Según el documento, MobileNetV2 alcanzó accuracy 0,91, recall 0,89, precision 0,93 y F1 0,915, eliminando el sesgo, mientras que MobileNetV3-Small y EfficientNetB0 quedaron en torno al 70 % y 69 % de exactitud. Estas cifras corresponden a los experimentos de la tesis y no coinciden con los mejores valores de la bitácora local, que documenta intentos por reproducir esos resultados a partir de los espectrogramas sin silencios.

`EXP7` tiene métricas en la bitácora pero no cuenta con gráfica ni archivo de texto; las gráficas disponibles cubren `EXP26`–`EXP37` y `EXP39`.

## Cómo reproducirlo

Requiere una cuenta de Google Colab con Google Drive, y las bibliotecas `tensorflow`, `keras`, `scikit-learn`, `matplotlib` y `seaborn`, además de los espectrogramas sin silencio en las carpetas de Drive. Se abre el notebook del modelo deseado y se ejecutan las celdas en orden: conexión al Drive, conteo y balanceo de espectrogramas, carga y división de imágenes, extracción de características, entrenamiento con *early stopping*, evaluación y guardado.

Los notebooks no usan rutas relativas al repositorio: todas las lecturas y escrituras apuntan a `/content/drive/MyDrive/spectograms/`. Para ejecutarlos con los datos de este repositorio hay que subir `datos/spectograms/mayan_without_silence/` y `datos/spectograms/spanish_no_silence/` a esa ubicación de Drive, o cambiar `directorio_de_trabajo` por la ruta local deseada. Las salidas se generan en `experimentos/` de Drive (modelo `[ID_Exp]_model.keras`, archivos `[ID_Exp]_results.txt` o `[ID_Exp]_details.txt` y gráfica `[ID_Exp]_accuracy_plot.png`), mientras que `log.csv` se guarda en la raíz del directorio de trabajo. En el repositorio estos archivos se han organizado en `modelos/` y `resultados/`.

## Relación con otros proyectos

- [`01 — Clasificación maya-español`](../01-clasificacion-maya-espanol/): línea base sobre la que trabajan la aumentación y los modelos ligeros de este proyecto.
- [`03 — Aplicación HablaIA`](../03-HablaIA-aplicacion/): aplicación móvil que necesita modelos ligeros como los evaluados aquí.
- [`04 — Clasificación maya-náhuatl-zapoteco`](../04-clasificacion-maya-nahuatl-zapoteco/): extiende la clasificación a múltiples lenguas.

## Referencias

1. Mukherjee, H., Ghosh, S., Sen, S., Sk Md, O., Santosh, K. C., Phadikar, S., & Roy, K. (2019). Deep learning for spoken language identification: Can we visualize speech signal patterns?. *Neural Computing and Applications*, 31, 8483–8501.
2. Howard, A. G. et al. (2017). MobileNets: Efficient Convolutional Neural Networks for Mobile Vision Applications. <https://arxiv.org/abs/1704.04861>.
3. Tan, M., & Le, Q. (2019). EfficientNet: Rethinking Model Scaling for Convolutional Neural Networks. <https://arxiv.org/abs/1905.11946>.
4. Sandler, M. et al. (2019). MobileNetV3: Searching for the Next Generation of Mobile Models. <https://arxiv.org/abs/1905.02244>.
5. Jeff Prosise (2021). Deep-Learning [Software]. GitHub. <https://github.com/jeffprosise/Deep-Learning/blob/master/Audio%20Classification%20(CNN).ipynb>.
6. Tec Cahun, C. E., & Chi Quiñones, J. D. (2025). *Modelos ligeros de redes neuronales convolucionales para clasificación de espectrogramas de audio en entornos médicos bilingües (maya-español)*. Universidad Intercultural Maya de Quintana Roo.

## Autoría y licencia

La tesis incluida fue elaborada por Carlos Eduardo Tec Cahun y Jonathan David Chi Quiñones en la Universidad Intercultural Maya de Quintana Roo. El código de los notebooks deriva del trabajo original `Language-Classification-CNN`; la autoría de los experimentos y los modelos dentro de este repositorio está pendiente de definir (`[P]`). La licencia del repositorio es provisional, según [`../LICENSE`](../LICENSE), y los corpus de terceros conservan sus licencias y avisos originales.
