# -*- coding: utf-8 -*-
"""
Created on Mon Jun  8 12:23:42 2026

@author: Equipo 1
"""

import os
from pydub import AudioSegment
from pydub.silence import split_on_silence

def procesar_audio_completo(ruta_input, ruta_output_folder, clip_length_ms=5000):
    audio = AudioSegment.from_wav(ruta_input)
    filename = os.path.splitext(os.path.basename(ruta_input))[0]

    # Umbral dinámico: 20dB por debajo del nivel promedio del audio
    # Esto se adapta a audios grabados a distintos volúmenes
    umbral_dinamico = audio.dBFS - 20

    print(f"Procesando: {filename}  |  nivel promedio: {audio.dBFS:.1f} dBFS  |  umbral: {umbral_dinamico:.1f} dBFS")

    chunks = split_on_silence(
        audio,
        min_silence_len=300,
        silence_thresh=umbral_dinamico,
        keep_silence=100
    )

    if not chunks:
        audio_limpio = audio
    else:
        audio_limpio = sum(chunks)
        
    # 3. Cortar en bloques exactos de 5 segundos
    total_duration = len(audio_limpio)
    start_time = 0
    clip_index = 1
    
    while start_time < total_duration:
        end_time = start_time + clip_length_ms
        clip = audio_limpio[start_time:end_time]
        
        # Si es el último fragmento y mide menos de 5 segundos, aplicamos Zero Padding
        if len(clip) < clip_length_ms:
            silencio_faltante = clip_length_ms - len(clip)
            clip = clip + AudioSegment.silent(duration=silencio_faltante)
            
        # Guardar el clip final estandarizado
        nombre_salida = f"{filename}_clip_{clip_index}.wav"
        ruta_salida = os.path.join(ruta_output_folder, nombre_salida)
        clip.export(ruta_salida, format="wav")
        
        start_time += clip_length_ms
        clip_index += 1

# --- CONFIGURACIÓN DE RUTAS EN TU PC ---
CARPETA_ENTRADA = "audios/mayan/original"
CARPETA_SALIDA = "entrenamien/maya"

if not os.path.exists(CARPETA_SALIDA):
    os.makedirs(CARPETA_SALIDA)

# Procesar todos los archivos .wav
for archivo in os.listdir(CARPETA_ENTRADA):
    if archivo.lower().endswith('.wav'):
        ruta_completa_entrada = os.path.join(CARPETA_ENTRADA, archivo)
        procesar_audio_completo(ruta_completa_entrada, CARPETA_SALIDA)

print("¡Proceso de limpieza y corte completado con éxito!")