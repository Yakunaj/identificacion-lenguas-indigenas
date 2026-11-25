import os
from pydub import AudioSegment

CARPETA_ENTRADA = "entrenamien/español"
CARPETA_SALIDA  = "entrenamiento/español"

os.makedirs(CARPETA_SALIDA, exist_ok=True)

for archivo in os.listdir(CARPETA_ENTRADA):
    if archivo.lower().endswith('.wav'):
        audio = AudioSegment.from_wav(os.path.join(CARPETA_ENTRADA, archivo))
        audio = audio.set_frame_rate(16000).set_channels(1)
        audio.export(os.path.join(CARPETA_SALIDA, archivo), format="wav")
        print(f"✔ {archivo}")