"""Constantes y configuración compartida para graficacion.py y entrenamiento.py.

Centraliza los valores que en la libreta original (Clasificación.ipynb) se
definían al inicio. No importa PyTorch ni TensorFlow para mantener el script
de creación del dataset ligero.
"""

import hashlib
import os

CODIGO_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(CODIGO_DIR)
DATOS_DIR = os.path.join(PROJECT_ROOT, 'datos')
RESULTADOS_DIR = os.path.join(PROJECT_ROOT, 'resultados')
MODELOS_DIR = os.path.join(PROJECT_ROOT, 'modelos')

# ============ SEMILLAS ============
SEED = 18062026
SPLIT_SEED = 4

# ============ LÍMITES DE BALANCEO Y PARTICIONADO ============
# Modo para calcular el límite de clips por fuente sobre todas las fuentes:
# 'median' (robusto a outliers) o 'mean'. También puede ser un int fijo.
SOURCE_LIMIT_MODE = 'median'
# Proporciones de la partición train / validation / test.
SPLIT_RATIOS = {'train': 0.6, 'val': 0.2, 'test': 0.2}

# Fuentes mal ubicadas que deben ignorarse al construir el dataset.
# (grabaciones de Nahuatl que por error de organización quedaron en Zapoteco).
EXCLUDED_SOURCES = {
    'zapoteco': [
        'NAWA001R002I001', 'NAWA001R004I001', 'NAWA001R013I001',
        'NAWA001R014I001(chacado)', 'NAWA001R017I001', 'NGU001R011I001',
        'NHP001R006I001', 'NHP001R006I002', 'NHP001R006I003',
        'NHP001R006I004', 'NHW001R036I001', 'NLV001R085I001',
        'NLV001R086I001',
    ],
}

# ============ LENGUAS ============
LANGUAGES = ['maya', 'nahuatl', 'zapoteco', 'espanol']
LANGUAGES.sort(key=str.lower)
NUM_CLASSES = len(LANGUAGES)
USED_MODEL = 'MobileNetV2'

# ============ CONFIGURACIÓN DEL AUDIO ============
AUDIO_LENGTH = 5  # segundos
SR = 16000  # sample rate
VAD_THRESHOLD = 0.15
RMS_THRESHOLD = 0.005

# ============ IMÁGENES / ENTRENAMIENTO ============
IMG_SIZE = (224, 224)
BATCH_SIZE = 32
MAX_IMAGES_PER_CLASS = 968
INITIAL_LR = 1e-3
FINE_TUNE_LR = 1e-5
MIN_LR = 1e-7
EPOCHS_PHASE1 = 20
EPOCHS_PHASE2 = 10
WARMUP_EPOCHS = 3
EARLY_STOP_PATIENCE = 8
REDUCE_LR_PATIENCE = 4
REDUCE_LR_FACTOR = 0.5
LABEL_SMOOTHING = 0.1
HEAD_L2 = 5e-4  # regularización l2 del Dense(128) de la cabeza (5e-4)

# ============ FILTRO DE CALIDAD ============
USE_CLEAN_FILTER = False
CLEAN_CSV_PATH = os.path.join(RESULTADOS_DIR, 'audio_quality.csv')

# ============ RUTAS DE AUDIO Y ESPECTROGRAMAS ============
AUDIO_ROOT = os.path.join(DATOS_DIR, 'Audios v4')
FIRST_FOLDER = os.path.join(AUDIO_ROOT, 'Maya')
SECOND_FOLDER = os.path.join(AUDIO_ROOT, 'Nahuatl')
THIRD_FOLDER = os.path.join(AUDIO_ROOT, 'Zapoteco')
FORTH_FOLDER = os.path.join(AUDIO_ROOT, 'Espanol')
FOLDER_PATH_LIST = [FIRST_FOLDER, SECOND_FOLDER, THIRD_FOLDER, FORTH_FOLDER]

SPECTROGRAM_DIRS = [
    os.path.join(DATOS_DIR, 'spectrograms', 'Maya'),
    os.path.join(DATOS_DIR, 'spectrograms', 'Nahuatl'),
    os.path.join(DATOS_DIR, 'spectrograms', 'Zapoteco'),
    os.path.join(DATOS_DIR, 'spectrograms', 'Espanol'),
]  # obsoletos tras la reescritura de graficacion.py (los espectrogramas van directo a datos/splits/CNN1).

# ============ RECORTADO DE AUDIOS (trozado.py) ============
AUDIOS_RAW_DIR = os.path.join(AUDIO_ROOT, 'audios')
CLIPS_OUTPUT_DIR = os.path.join(AUDIO_ROOT, 'Audios recortados')
CLIP_SR = SR  # 16000 Hz mono
VAD_TOP_DB = 44  # muy permisivo; igual que helpers/remove_silence.py
MIN_VAD_RATIO = 0.05  # descarta solo ventanas casi silenciosas
KEEP_PARTIAL_TAIL = False  # el sobrante < AUDIO_LENGTH se descarta

WAV_SOURCE_DIRS = list(zip(FOLDER_PATH_LIST, SPECTROGRAM_DIRS))

# ============ RUTAS DE SALIDA ============
CSV_LOG_PATH = os.path.join(RESULTADOS_DIR, 'log.csv')
SPLIT_BASE_DIR = os.path.join(DATOS_DIR, 'splits', 'CNN1')
TRAIN_DIR = os.path.join(SPLIT_BASE_DIR, 'train')
VAL_DIR = os.path.join(SPLIT_BASE_DIR, 'validation')
TEST_DIR = os.path.join(SPLIT_BASE_DIR, 'test')
MODEL_OUTPUT = os.path.join(MODELOS_DIR, 'MobileNetV2.pth')
PLOT_PHASE1_PATH = os.path.join(RESULTADOS_DIR, 'curvas_fase1.png')
PLOT_PHASE2_PATH = os.path.join(RESULTADOS_DIR, 'curvas_fase2.png')

# ============ LOG DEL EXPERIMENTO ============
LOG_COLUMNS = [
    'ID_Exp', 'Hash', 'Languages', 'Model', 'Audio_Length',
    'Image_Amount', 'Parameters', 'Results', 'Split_Seed',
    'hasSilence', 'Audio_Folders_Used', 'Notes'
]

HAS_SILENCE = False


def compute_parameters():
    return {
        'batch_size': BATCH_SIZE,
        'frequency': SR,
        'learning_rate': INITIAL_LR
    }


def compute_experiment_hash(languages=None):
    """Reproduce el hash MD5 de la libreta original (usa MAX_IMAGES_PER_CLASS)."""
    langs = languages if languages is not None else LANGUAGES
    image_amount = {lang: MAX_IMAGES_PER_CLASS for lang in langs}
    raw = (
        f"{langs},{USED_MODEL},{AUDIO_LENGTH},{image_amount}."
        f"{compute_parameters()},{SPLIT_SEED},{HAS_SILENCE}"
    ).encode()
    return hashlib.md5(raw).hexdigest()