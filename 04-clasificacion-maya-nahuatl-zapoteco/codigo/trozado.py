import os
import re
import sys

import librosa
import numpy as np
import soundfile as sf

import configuraciones as cfg

FRAME_LENGTH = 2048
HOP_LENGTH = 512

SPEAKER_GROUPED_LANGUAGES = {'espanol'}
SPEAKER_PATTERN = re.compile(r'(?:^|_)([FM])_(\d+)')


def clean_stem(filename):
    stem = os.path.splitext(os.path.basename(filename))[0]
    stem = re.sub(r'\s*\(checado\)$', '', stem, flags=re.IGNORECASE)
    stem = re.sub(r'[\\/:*?"<>|]+', '_', stem)
    return stem


def speaker_id(filename):
    match = SPEAKER_PATTERN.search(clean_stem(filename))
    return f'{match.group(1)}_{match.group(2)}' if match else None


def output_group(lang_name, filename):
    if lang_name.lower() in SPEAKER_GROUPED_LANGUAGES:
        return speaker_id(filename) or clean_stem(filename)
    return clean_stem(filename)


def process_audio(input_path, output_dir, clip_length, sr, top_db, min_vad_ratio):
    os.makedirs(output_dir, exist_ok=True)

    y, _ = librosa.load(input_path, sr=sr, mono=True)
    if len(y) == 0:
        return 0, 1

    intervals = librosa.effects.split(y, top_db=top_db, frame_length=FRAME_LENGTH, hop_length=HOP_LENGTH)
    voice_mask = np.zeros(len(y), dtype=bool)
    for start, end in intervals:
        voice_mask[start:end] = True

    frames = librosa.feature.rms(y=y, frame_length=FRAME_LENGTH, hop_length=HOP_LENGTH)[0]
    frame_times = np.arange(len(frames)) * (HOP_LENGTH / sr)
    rms_floor = max(cfg.RMS_THRESHOLD, float(np.quantile(frames, 0.05)))

    clip_samples = int(round(clip_length * sr))
    stem = clean_stem(input_path)
    saved = 0
    discarded = 0
    for i, start in enumerate(range(0, len(y) - clip_samples + 1, clip_samples)):
        end = start + clip_samples
        start_sec = start / sr
        end_sec = end / sr
        window_frames = (frame_times >= start_sec) & (frame_times < end_sec)
        vad_ratio = float(np.mean(voice_mask[start:end]))
        window_rms = float(np.mean(frames[window_frames]))
        if vad_ratio < min_vad_ratio and window_rms < rms_floor:
            discarded += 1
            continue
        clip_path = os.path.join(output_dir, f'{stem}_5s_{i + 1:04d}.wav')
        if os.path.isfile(clip_path):
            saved += 1
            continue
        sf.write(clip_path, y[start:end], sr, subtype='PCM_16')
        saved += 1
    return saved, discarded


def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

    audio_root = cfg.AUDIOS_RAW_DIR
    output_root = cfg.CLIPS_OUTPUT_DIR

    if not os.path.isdir(audio_root):
        raise FileNotFoundError(f'No existe la carpeta de audios: {audio_root}')

    totals = {'saved': 0, 'discarded': 0, 'files': 0}
    for lang_name in sorted(os.listdir(audio_root)):
        lang_dir = os.path.join(audio_root, lang_name)
        if not os.path.isdir(lang_dir):
            continue
        for filename in sorted(os.listdir(lang_dir)):
            input_path = os.path.join(lang_dir, filename)
            if not os.path.isfile(input_path) or not filename.lower().endswith('.wav'):
                continue
            output_dir = os.path.join(output_root, lang_name, output_group(lang_name, filename))
            try:
                saved, discarded = process_audio(
                    input_path,
                    output_dir,
                    cfg.AUDIO_LENGTH,
                    cfg.CLIP_SR,
                    cfg.VAD_TOP_DB,
                    cfg.MIN_VAD_RATIO,
                )
                totals['files'] += 1
                totals['saved'] += saved
                totals['discarded'] += discarded
                print(f'{lang_name}/{filename}: {saved} recortes guardados, {discarded} descartados')
            except Exception as e:
                print(f'{lang_name}/{filename}: error -> {e}')

    print(
        '\nResumen:'
        f'\n  Audios procesados:  {totals["files"]}'
        f'\n  Recortes guardados: {totals["saved"]}'
        f'\n  Recortes descartados: {totals["discarded"]}'
        f'\n  Salida: {output_root}'
    )


if __name__ == '__main__':
    main()