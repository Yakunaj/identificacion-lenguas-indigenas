"""Creación del dataset balanceado de espectrogramas y de la partición train/validation/test.

Los clips de 5s están organizados en datos/Audios v4/Audios recortados/{lengua}/{fuente}/*.wav.
El flujo es:

  1. Escanea los clips y aplica las exclusiones de configuraciones.EXCLUDED_SOURCES.
  2. Calcula un límite de clips por fuente (mediana o media de todas las fuentes) y,
     con el capeo por fuente, un límite de clips por lengua (el menor total capeado).
  3. Con la semilla, aleatoriza los clips que se toman de cada fuente y de cada lengua.
  4. Particiona 0.6/0.2/0.2 asegurando que las fuentes de test son disjuntas de las de
     train/validation (elegidas aleatoriamente según la semilla) y que train/validation
     quedan completamente aleatorizadas entre sí.
  5. Genera los espectrogramas PNG y los guarda en
     datos/splits/CNN1/{train,validation,test}/{lengua}.

Uso:
    python graficacion.py
    python graficacion.py --dry-run
    python graficacion.py --regenerar
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import sys

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import librosa
import librosa.display
from PIL import Image

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE_DIR)

from configuraciones import (
    CLEAN_CSV_PATH, CLIPS_OUTPUT_DIR, EXCLUDED_SOURCES, IMG_SIZE, LANGUAGES,
    SPLIT_BASE_DIR, SPLIT_RATIOS, SPLIT_SEED, SOURCE_LIMIT_MODE, SR,
    TEST_DIR, TRAIN_DIR, USE_CLEAN_FILTER, VAL_DIR,
)


# ============ GENERACIÓN DE ESPECTROGRAMAS ============
def create_spectrogram(audio_file, image_file, sr=SR):
    fig = plt.figure()
    ax = fig.add_subplot(1, 1, 1)
    fig.subplots_adjust(left=0, right=1, bottom=0, top=1)

    y, _ = librosa.load(audio_file, sr=sr)
    ms = librosa.feature.melspectrogram(y=y, sr=sr)
    log_ms = librosa.power_to_db(ms, ref=np.max)
    librosa.display.specshow(log_ms, sr=sr)

    fig.savefig(image_file)
    plt.close(fig)


def load_exclude_files():
    """Utiliza la calidad de audio_quality.csv para filtrar archivos sospechosos de ruido."""
    if not USE_CLEAN_FILTER:
        return set()
    if os.path.exists(CLEAN_CSV_PATH):
        import pandas as pd
        df_q = pd.read_csv(CLEAN_CSV_PATH)
        exclude = set(df_q[df_q['suspect_noise'] == True]['file'])
        print(f"Loaded {CLEAN_CSV_PATH}: excluding {len(exclude)} noise-suspect files")
        return exclude
    print(f"Warning: {CLEAN_CSV_PATH} not found. Se necesita el reporte de calidad de audio.")
    return set()


def resize_pil(path, target_size=IMG_SIZE):
    """Carga un PNG y lo redimensiona igual que la libreta (interpolación NEAREST)."""
    img = Image.open(path).convert('RGB')
    return img.resize(target_size, Image.NEAREST)


def generate_spectrogram_resized(audio_file, image_file):
    """Genera el espectrograma y lo guarda redimensionado (224x224)."""
    tmp = os.path.join(os.path.dirname(image_file), f'.__tmp_{os.path.basename(image_file)}')
    create_spectrogram(audio_file, tmp)
    img = resize_pil(tmp, IMG_SIZE)
    img.save(image_file)
    os.remove(tmp)


def sanitize_name(text):
    return re.sub(r'[^A-Za-z0-9._-]+', '_', text).strip('_') or 'src'


# ============ ESCANEO Y LÍMITES ============
def scan_clips():
    """lang -> {fuente: [rutas de clips wav]} (fuentes excluidas omitidas)."""
    lang_lookup = {l.lower(): l for l in LANGUAGES}
    registry = {}
    for folder in sorted(os.listdir(CLIPS_OUTPUT_DIR)):
        key = folder.lower()
        if key not in lang_lookup or not os.path.isdir(os.path.join(CLIPS_OUTPUT_DIR, folder)):
            continue
        lang = lang_lookup[key]
        lang_dir = os.path.join(CLIPS_OUTPUT_DIR, folder)
        excluded = set(EXCLUDED_SOURCES.get(lang, ()))
        sources = {}
        for src in sorted(os.listdir(lang_dir)):
            src_dir = os.path.join(lang_dir, src)
            if not os.path.isdir(src_dir):
                continue
            if src in excluded:
                print(f'  [excluida] {lang}/{src}')
                continue
            clips = sorted(
                os.path.join(src_dir, f) for f in os.listdir(src_dir)
                if f.lower().endswith('.wav')
            )
            if clips:
                sources[src] = clips
        registry[lang] = sources
    return registry


def compute_limits(registry):
    """Límite por fuente y límite por lengua (menor total capeado)."""
    source_counts = {}
    raw_totals = {}
    all_counts = []
    for lang, sources in registry.items():
        src_counts = {s: len(clips) for s, clips in sources.items()}
        source_counts[lang] = src_counts
        raw_totals[lang] = sum(src_counts.values())
        all_counts.extend(src_counts.values())

    all_counts = sorted(all_counts)
    n = len(all_counts)
    if isinstance(SOURCE_LIMIT_MODE, str) and SOURCE_LIMIT_MODE.lower() == 'median':
        limit_source = int(round((all_counts[(n - 1) // 2] + all_counts[n // 2]) / 2))
    elif isinstance(SOURCE_LIMIT_MODE, str) and SOURCE_LIMIT_MODE.lower() == 'mean':
        limit_source = int(round(sum(all_counts) / n))
    else:
        limit_source = int(SOURCE_LIMIT_MODE)

    capped_totals = {
        lang: sum(min(c, limit_source) for c in src_counts.values())
        for lang, src_counts in source_counts.items()
    }
    limit_lang = min(capped_totals.values())
    return limit_source, limit_lang, raw_totals, capped_totals, source_counts


# ============ MUESTREO Y PARTICIONADO ============
def sample_selected_clips(registry, limit_source, limit_lang, seed):
    """Selecciona hasta limit_lang clips por lengua aleatorizados con la semilla."""
    rng = np.random.default_rng(seed)
    selected = {}
    for lang, sources in registry.items():
        pool = []
        for src in sorted(sources):
            clips = np.array(sources[src], dtype=object)
            if len(clips) > limit_source:
                clips = rng.choice(clips, size=limit_source, replace=False)
            pool.extend((src, c) for c in clips.tolist())
        rng.shuffle(pool)
        if len(pool) > limit_lang:
            pool = rng.choice(np.array(pool, dtype=object), size=limit_lang, replace=False).tolist()
        selected[lang] = pool
    return selected


def _lang_salt(lang):
    return int(hashlib.md5(lang.encode('utf-8')).hexdigest()[:8], 16)


def partition_by_source(selected, limit_lang, ratios, seed):
    """Particiona 0.6/0.2/0.2 con fuentes de test disjuntas de train/validation.

    Por lengua se barajan las fuentes (según la semilla) y se acumulan hasta llegar
    ~20% del total para designar las fuentes de test; el resto se baraja y se reparte
    75/25 (60% y 20% del global) entre train y validation.
    """
    total_w = sum(ratios.values())
    target_test = int(round(ratios['test'] / total_w * limit_lang))
    splits = {}
    test_sources = {}
    for lang, clips in selected.items():
        by_src = {}
        for src, path in clips:
            by_src.setdefault(src, []).append((src, path))
        sources = list(by_src.keys())
        rng = np.random.default_rng(seed + _lang_salt(lang))
        rng.shuffle(sources)

        acc = 0
        n_test_src = 0
        for s in sources:
            n_test_src += 1
            acc += len(by_src[s])
            if acc >= target_test:
                break

        test_srcs = sources[:n_test_src]
        test_clips = [c for s in test_srcs for c in by_src[s]]
        rest = [c for s in sources[n_test_src:] for c in by_src[s]]
        rng.shuffle(rest)

        train_frac = ratios['train'] / (ratios['train'] + ratios['val'])
        n_train = int(round(train_frac * len(rest)))
        splits[lang] = {
            'train': rest[:n_train],
            'val': rest[n_train:],
            'test': test_clips,
        }
        test_sources[lang] = test_srcs
    return splits, test_sources


def split_counts(splits):
    counts = {}
    for lang, parts in splits.items():
        counts[lang] = {k: len(v) for k, v in parts.items()}
    total = {k: sum(c[k] for c in counts.values()) for k in ('train', 'val', 'test')}
    return counts, total


# ============ ESCRITURA DE SPLITS ============
def clean_legacy_dirs():
    for root in (TRAIN_DIR, VAL_DIR, TEST_DIR):
        if not os.path.isdir(root):
            continue
        for entry in os.listdir(root):
            p = os.path.join(root, entry)
            if os.path.isdir(p) and entry not in LANGUAGES:
                shutil.rmtree(p, ignore_errors=True)
                print(f'  eliminada carpeta obsoleta: {p}')


def write_splits(splits, exclude_files, force):
    expected = set()
    generated = {'train': 0, 'val': 0, 'test': 0}
    skipped_existing = {'train': 0, 'val': 0, 'test': 0}
    skipped_filter = {'train': 0, 'val': 0, 'test': 0}
    split_roots = {'train': TRAIN_DIR, 'val': VAL_DIR, 'test': TEST_DIR}

    for lang in LANGUAGES:
        for split_name, root in split_roots.items():
            class_dir = os.path.join(root, lang)
            os.makedirs(class_dir, exist_ok=True)
            for src, path in splits[lang][split_name]:
                out = os.path.join(
                    class_dir,
                    f'{sanitize_name(src)}_{os.path.basename(path)[:-4]}.png',
                )
                expected.add(out)
                if os.path.exists(out) and not force:
                    skipped_existing[split_name] += 1
                    continue
                if os.path.basename(path) in exclude_files:
                    skipped_filter[split_name] += 1
                    continue
                generate_spectrogram_resized(path, out)
                generated[split_name] += 1

    remove_stale_pngs(expected)
    return generated, skipped_existing, skipped_filter


def remove_stale_pngs(expected):
    for root in (TRAIN_DIR, VAL_DIR, TEST_DIR):
        for cur, _dirs, files in os.walk(root):
            for f in files:
                if f.lower().endswith('.png'):
                    p = os.path.join(cur, f)
                    if p not in expected:
                        os.remove(p)
                        print(f'  eliminado png no seleccionado: {p}')


# ============ ORQUESTACIÓN ============
def build_splits(dry_run=False, force=False):
    print('=== 1. Escaneo de clips (Audios recortados) ===')
    registry = scan_clips()
    for lang, sources in registry.items():
        total = sum(len(c) for c in sources.values())
        print(f'  {lang}: {len(sources)} fuentes, {total} clips')

    print('\n=== 2. Límites de balanceo ===')
    limit_source, limit_lang, raw_totals, capped_totals, source_counts = compute_limits(registry)
    all_counts = sorted(c for m in source_counts.values() for c in m.values())
    print(f'  Fuentes globales: {len(all_counts)}')
    print(f'  Mediana clips/fuente: {int(np.median(all_counts))} | Promedio: {np.mean(all_counts):.2f}')
    print(f'  Límite por fuente ({SOURCE_LIMIT_MODE}): {limit_source}')
    for lang in LANGUAGES:
        print(f'    {lang}: raw={raw_totals[lang]}, capeado={capped_totals[lang]}')
    print(f'  Límite por lengua: {limit_lang}')

    print('\n=== 3. Muestreo con semilla ===')
    selected = sample_selected_clips(registry, limit_source, limit_lang, SPLIT_SEED)
    for lang in LANGUAGES:
        print(f'  {lang}: {len(selected[lang])} clips seleccionados')

    print('\n=== 4. Partición 0.6 / 0.2 / 0.2 (test por fuentes) ===')
    splits, test_sources = partition_by_source(selected, limit_lang, SPLIT_RATIOS, SPLIT_SEED)
    counts, totals = split_counts(splits)
    for lang in LANGUAGES:
        c = counts[lang]
        n = sum(c.values())
        print(
            f'  {lang}: train={c["train"]} ({c["train"]/n:.1%}) | '
            f'val={c["val"]} ({c["val"]/n:.1%}) | '
            f'test={c["test"]} ({c["test"]/n:.1%})'
        )
        print(f'    fuentes de test ({len(test_sources[lang])}): {test_sources[lang]}')
    n_global = sum(totals.values())
    print(
        f'  GLOBAL: train={totals["train"]} ({totals["train"]/n_global:.1%}) | '
        f'val={totals["val"]} ({totals["val"]/n_global:.1%}) | '
        f'test={totals["test"]} ({totals["test"]/n_global:.1%})'
    )

    os.makedirs(SPLIT_BASE_DIR, exist_ok=True)
    metadata = {
        'languages': LANGUAGES,
        'split_seed': SPLIT_SEED,
        'source_limit_mode': SOURCE_LIMIT_MODE,
        'source_limit': limit_source,
        'language_limit': limit_lang,
        'language_clips_raw': raw_totals,
        'language_clips_capped': capped_totals,
        'split_ratios': SPLIT_RATIOS,
        'splits': {lang: {k: list(map(lambda x: x[1], v)) for k, v in parts.items()}
                   for lang, parts in splits.items()},
        'test_sources': test_sources,
        'excluded_sources': EXCLUDED_SOURCES,
        'counts': counts,
        'totals': totals,
    }
    metadata_path = os.path.join(SPLIT_BASE_DIR, 'metadata.json')
    with open(metadata_path, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2, ensure_ascii=False)
    print(f'\nMetadata guardada en: {metadata_path}')

    if dry_run:
        print('\n[dry-run] No se generaron espectrogramas.')
        return

    print('\n=== 5. Generación de espectrogramas en CNN1 ===')
    clean_legacy_dirs()
    exclude_files = load_exclude_files()
    generated, skipped_existing, skipped_filter = write_splits(splits, exclude_files, force)
    print(f'  Espectrogramas generados: {generated}')
    if sum(skipped_existing.values()):
        print(f'  Ya existentes (omitidos): {skipped_existing}')
    if sum(skipped_filter.values()):
        print(f'  Omitidos por filtro de ruido: {skipped_filter}')
    print(f'  Train: {totals["train"]} | Validation: {totals["val"]} | Test: {totals["test"]}')
    print('Splits guardados en datos/splits/CNN1/train, /validation y /test.')


def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass
    parser = argparse.ArgumentParser(description='Crea espectrogramas y splits balanceados del dataset.')
    parser.add_argument('--dry-run', action='store_true',
                        help='Calcula límites y particiones sin generar espectrogramas.')
    parser.add_argument('--regenerar', action='store_true',
                        help='Regenera los espectrogramas aunque ya existan.')
    args = parser.parse_args()
    build_splits(dry_run=args.dry_run, force=args.regenerar)


if __name__ == '__main__':
    main()