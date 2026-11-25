# 04 — Clasificación maya-náhuatl-zapoteco

Este proyecto reúne la metodología, los experimentos y los prototipos para la identificación automática de las lenguas maya, náhuatl y zapoteco. Es una continuación del proyecto [`01 — Clasificación maya-español`](../01-clasificacion-maya-espanol/) y del [`02 — Aumento de datos y modelos ligeros`](../02-clasificacion-maya-espanol+aumento-de-datos/), con dos cambios principales: se trabaja con tres lenguas indígenas y se incorpora una fase de ajuste fino (*fine-tuning*) sobre un modelo preentrenado.

Los audios y los espectrogramas **no están incluidos** en este repositorio: se alojan en Google Drive y sus enlaces se registran en [`datos/Datos remotos.md`](datos/Datos%20remotos.md). Lo que sí se conserva aquí es el código, las bitácoras de experimentos, las gráficas, los modelos entrenados y el prototipo de aplicación móvil.

## Clasificación a partir de imágenes

Al igual que en los proyectos anteriores, la clasificación se hace sobre imágenes de espectrogramas en lugar de sobre audio crudo. Esto evita depender de transcripciones o anotaciones fonéticas. El flujo es el siguiente:

1. Los audios se recortan enventanas de 5 segundos a 16 kHz, con filtrado de ventanas casi silenciosas, y se agrupan por lengua y fuente de grabación.
2. Cada clip se convierte en un mel-espectrograma y se redimensiona a 224 × 224 píxeles, sin etiquetas de tiempo ni de frecuencia.
3. El dataset se balancea limitando el número de clips por fuente (mediana global) y se divide en entrenamiento, validación y prueba en proporción 0,6 / 0,2 / 0,2. Las fuentes de prueba se mantienen disjuntas de las de entrenamiento y validación.
4. Se entrena MobileNetV2 en dos fases: 20 épocas con la base congelada y 10 épocas descongelando las últimas 10 capas. Se usa SpecAugment, *label smoothing* 0,1, Adam, calentamiento de 3 épocas, `ReduceLROnPlateau` y *early stopping* con paciencia 8.
5. Se registran accuracy, recall, precision y F1, además de la matriz de confusión, en la bitácora de experimentos.

La libreta [`codigo/Clasificación.ipynb`](codigo/Clasificación.ipynb) contiene la implementación histórica en TensorFlow/Keras (MobileNetV2 y una CNN simple). La versión reproducible actual es la tubería formada por `codigo/trozado.py`, `codigo/graficacion.py` y `codigo/entrenamiento/entrenamiento.py`, esta última en PyTorch.

> **Nota:** los scripts y la libreta están preparados para cuatro clases (`espanol`, `maya`, `nahuatl`, `zapoteco`), porque la configuración actual incluye español como clase de control. Las bitácoras, en cambio, documentan tanto experimentos de tres lenguas como de cuatro.

## Estructura

La organización sigue el mismo criterio que los proyectos 01 y 02: el código en `codigo/`, los datos en `datos/`, los resultados en `resultados/`, los modelos en `modelos/` y la documentación en `documentos/`. El prototipo de aplicación se conserva en `prototipos/`.

```text
04-clasificacion-maya-nahuatl-zapoteco/
├── codigo/
│   ├── Clasificación.ipynb
│   ├── configuraciones.py
│   ├── graficacion.py
│   ├── trozado.py
│   ├── inferencia.py
│   ├── entrenamiento/
│   │   ├── entrenamiento.py
│   │   └── requirements-entrenamiento.txt
│   └── helpers/
│       ├── remove_silence.py
│       └── split_audios.py
├── datos/
│   ├── Datos remotos.md
│   └── splits/CNN1/{train,validation,test}/{lengua}/   # se genera
├── documentos/
│   ├── Manual_Tecnico_HablaIA.pdf
│   └── Manual_Usuario_HablaIA.pdf
├── modelos/
│   ├── EXP9.keras
│   ├── EXP10.keras
│   ├── MobileNetV2.pth
│   └── MobileNetV2(AudiosV3).pth
├── prototipos/
│   └── HablaIA/
└── resultados/
    ├── log.csv
    ├── logs/log.csv
    ├── audio_quality.csv
    ├── curvas_fase1.png
    ├── curvas_fase2.png
    ├── matriz_confusion.png
    ├── matriz_confusion_test.png
    ├── confusion_matrix.png
    ├── confusion_matrix CNN.png
    ├── graficas final.png
    └── graficas cnn final.png
```

### `datos/`

No contiene audios ni espectrogramas propios. [`datos/Datos remotos.md`](datos/Datos%20remotos.md) apunta a las dos carpetas de Google Drive con los audios y los espectrogramas de entrenamiento. La estructura que esperan los scripts es:

- `datos/Audios v4/audios/{lengua}/*.wav`: grabaciones originales, entrada de `trozado.py`.
- `datos/Audios v4/Audios recortados/{lengua}/{fuente}/*.wav`: clips de 5 segundos, entrada de `graficacion.py`.
- `datos/spectrograms/{lengua}/`: espectrogramas de la libreta histórica (ruta obsoleta para la tubería actual).
- `datos/splits/CNN1/{train,validation,test}/{lengua}/*.png`: espectrogramas particionados, generados por `graficacion.py`. Junto con `metadata.json`, se crean al ejecutar el script; no están incluidos en el repositorio.

La libreta histórica guarda sus propias particiones en `datos/splits/CNN1_legado/`, con carpetas numeradas por etiqueta, para no mezclarlas con las particiones nominales de `graficacion.py`.

### `resultados/`

Aquí están todos los artefactos generados, incluidas las cuatro imágenes que antes se encontraban en la carpeta `Datos/`:

- **`log.csv`**: bitácora de la fase reciente, con los experimentos `EXP0`–`EXP2`.
- **`logs/log.csv`**: bitácora histórica, con `EXP0`–`EXP10`, correspondiente a las primeras pruebas con ResNet152V2, MobileNetV2 y una CNN simple.
- **`audio_quality.csv`**: reporte de calidad de 6.275 audios con las columnas `language`, `file`, `vad_ratio`, `rms` y `suspect_noise`. Es una salida generada, no el corpus original; se usa de forma opcional para descartar archivos con ruido.
- **`curvas_fase1.png`, `curvas_fase2.png` y `matriz_confusion_test.png`**: salidas del entrenamiento en PyTorch.
- **`matriz_confusion.png`, `confusion_matrix.png`, `confusion_matrix CNN.png`, `graficas final.png` y `graficas cnn final.png`**: gráficas obtenidas en distintas rondas de experimentos.

> **Nota:** las columnas `Audio_Folders_Used` de las bitácoras conservan rutas de la máquina original (`A:\main\uni\Repositorio Tesis\...\Audios v3`, `Audios v4`, `Audios_Usar3s`, `Audios_Usar5s v2`, etc.). Son un registro histórico, no rutas válidas dentro de este repositorio.

### `modelos/`

Contiene los pesos entrenados: `EXP9.keras` y `EXP10.keras` proceden de la libreta de Keras, mientras que `MobileNetV2.pth` y `MobileNetV2(AudiosV3).pth` proceden del entrenamiento en PyTorch, el segundo entrenado con la versión anterior del corpus. El modelo que usa la aplicación móvil, `MobileNetV3Large_normal.tflite`, se conserva dentro de `prototipos/HablaIA/lib/modelos/`.

### `codigo/`

- **`configuraciones.py`**: semillas (`SEED = 18062026`, `SPLIT_SEED = 4`), balanceo (`SOURCE_LIMIT_MODE = 'median'`), partición 0,6 / 0,2 / 0,2, parámetros de audio y rutas del proyecto. Es el único lugar que hay que editar si se cambia la ubicación de los datos.
- **`trozado.py`**: divide los audios originales en clips de 5 segundos y los organiza por lengua y fuente.
- **`graficacion.py`**: aplica exclusiones, balancea por fuente, reparte las muestras con la semilla y genera los espectrogramas en `datos/splits/CNN1/`. Admite `--dry-run` y `--regenerar`.
- **`entrenamiento/entrenamiento.py`**: entrena MobileNetV2 en PyTorch con las dos fases descritas arriba y escribe en `resultados/` y `modelos/`.
- **`entrenamiento/requirements-entrenamiento.txt`**: versiones fijadas del entorno de entrenamiento.
- **`helpers/remove_silence.py` y `helpers/split_audios.py`**: utilidades manuales para recortar silencios y dividir audios; hay que editar sus carpetas de entrada y salida antes de usarlas. La libreta no las importa.
- **`inferencia.py`**: archivo vacío reservado como espacio de trabajo para inferencia.
- **`Clasificación.ipynb`**: libreta original de Keras; sus rutas ya son relativas a `codigo/` y apuntan a `../datos/`, `../resultados/` y `../modelos/`.

### `documentos/` y `prototipos/`

`documentos/` contiene el manual técnico y el manual de usuario de HablaIA. `prototipos/HablaIA/` es una copia antigua de la aplicación Flutter, con el código nativo de Android y el modelo `.tflite`. La versión mantenida de la aplicación está en el proyecto [`03 — Aplicación HablaIA`](../03-HablaIA-aplicacion/).

## Bitácora de experimentos

Ambas bitácoras registran los mismos campos, aunque en distinto orden:

| Campo | Descripción |
|---|---|
| `ID_Exp` | Identificador único del experimento. |
| `Hash` | Hash MD5 derivado de lenguas, modelo, duración, imágenes, parámetros, semilla y silencio. |
| `Languages` | Lenguas incluidas. |
| `Model` | Modelo utilizado (`ResNet152V2`, `MobileNetV2` o `CNN simple`). |
| `Audio_Length` | Duración de los clips en segundos. |
| `Image_Amount` | Número de imágenes por lengua. |
| `Parameters` | Tamaño de lote, frecuencia de muestreo y tasa de aprendizaje. |
| `Results` | Accuracy, recall, precision y F1. |
| `Split_Seed` | Semilla del particionado. |
| `hasSilence` | Indica si se conservó el silencio en los audios. |
| `Audio_Folders_Used` | Carpetas de audio utilizadas, con sus rutas históricas. |
| `Notes` | Observaciones adicionales. |

### Resultados registrados

En `resultados/logs/log.csv` (bitácora histórica, tres lenguas, `ResNet152V2` salvo las últimas filas):

| Experimento | Modelo | Clips por lengua | Accuracy | Observación |
|---|---|---|---|---|
| `EXP0` | ResNet152V2 | 1.317 | 0,867 | Primer acercamiento con maya, náhuatl y español. |
| `EXP2`–`EXP4` | ResNet152V2 | 1.165 | 0,970 – 1,000 | Clips de 3 segundos; `EXP4` alcanzó 1,000. |
| `EXP5` | ResNet152V2 | 189 | 0,974 | Clips de 6 segundos, dataset mucho más pequeño. |
| `EXP7`–`EXP8` | MobileNetV2 | 1.731 | 0,688 – 0,724 | Clips de 5 segundos con 1731 imágenes por lengua. |
| `EXP9` | MobileNetV2 | 1.428 | 0,870 | Resultado sesgado a maya. |
| `EXP10` | CNN simple | 1.428 | 0,990 | Resultado sesgado a náhuatl. |

En `resultados/log.csv` (fase reciente, MobileNetV2, semilla 4):

| Experimento | Lenguas | Imágenes por lengua | Accuracy |
|---|---|---|---|
| `EXP0` | maya, náhuatl, zapoteco | 750 | 0,9447 |
| `EXP1` | maya, náhuatl, zapoteco | 750 | 0,7296 |
| `EXP2` | español, maya, náhuatl, zapoteco | 968 | 0,7229 |

Los valores con accuracy perfecto o muy alto deben interpretarse con cautela: las fuentes y los hablantes no siempre estaban separados entre particiones, y las propias bitácoras señalan sesgo hacia una clase en `EXP9` y `EXP10`. La liberación actual de `graficacion.py` corrige ese punto manteniendo las fuentes de prueba disjuntas.

## Cómo reproducirlo

Requiere Python con `librosa`, `soundfile`, `numpy`, `matplotlib`, `Pillow` y `pandas` para la preparación de datos. Para el entrenamiento se necesita además el entorno aislado con `torch==2.4.1`, `torchvision==0.19.1` y `torch-directml`, diseñado para GPU AMD en Windows.

1. Descargar las carpetas de [audios](https://drive.google.com/drive/folders/1TQwCDDDMf2kuVycOb_rD0mIOlI_0xtux?usp=sharing) y [espectrogramas](https://drive.google.com/drive/folders/1RncuOhLhO8K3MuJ6cTW3n1RTG9bSAB3l?usp=sharing) y colocarlas siguiendo la estructura descrita en [`datos/`](#datos).
2. Si se parte de los audios originales, ejecutar desde la raíz del proyecto `python codigo/trozado.py`.
3. Verificar el particionado con `python codigo/graficacion.py --dry-run` y generar los espectrogramas con `python codigo/graficacion.py`. Para regenerar los PNG existentes, añadir `--regenerar`.
4. Crear el entorno de entrenamiento una sola vez (Python 3.11; `torch-directml` no soporta versiones posteriores a 3.12):

   ```powershell
   python -m venv codigo\entrenamiento\.venv
   codigo\entrenamiento\.venv\Scripts\python.exe -m pip install -r codigo\entrenamiento\requirements-entrenamiento.txt
   ```

   > No mezclar este entorno con otros del proyecto: `torch-directml` fija versiones concretas de `torch` y `torchvision`.

5. Entrenar y evaluar:

   ```powershell
   codigo\entrenamiento\.venv\Scripts\python.exe codigo\entrenamiento\entrenamiento.py
   ```

   El dispositivo se detecta solo: `torch-directml` (GPU AMD en Windows), después CUDA/ROCm y finalmente CPU. Las curvas y la matriz de confusión se guardan en `resultados/`, el modelo en `modelos/MobileNetV2.pth` y la nueva fila de la bitácora en `resultados/log.csv`.

La libreta [`codigo/Clasificación.ipynb`](codigo/Clasificación.ipynb) puede ejecutarse por separado desde `codigo/` con TensorFlow/Keras. Genera espectrogramas en `../datos/spectrograms/`, guarda el modelo en `../modelos/CNN1.keras`, las particiones históricas en `../datos/splits/CNN1_legado/` y registra los experimentos en `../resultados/log.csv`.

## Relación con otros proyectos

- [`01 — Clasificación maya-español`](../01-clasificacion-maya-espanol/): línea base de clasificación binaria con espectrogramas.
- [`02 — Aumento de datos y modelos ligeros`](../02-clasificacion-maya-espanol+aumento-de-datos/): experimentos con aumentos y modelos ligeros.
- [`03 — Aplicación HablaIA`](../03-HablaIA-aplicacion/): aplicación móvil que clasifica la lengua en el dispositivo.

## Autoría y licencia

La metodología, los experimentos y el código proceden del trabajo original desarrollado para la tesis de identificación automática de las lenguas indígenas maya, náhuatl y zapoteco. La autoría dentro de este repositorio está pendiente de definir (`[P]`). La licencia del repositorio es provisional, según [`../LICENSE`](../LICENSE), y los corpus de terceros conservan sus licencias y avisos originales.
