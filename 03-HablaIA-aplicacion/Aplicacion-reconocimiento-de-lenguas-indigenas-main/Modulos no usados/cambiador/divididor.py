import os
import random
import shutil
from pathlib import Path
from sklearn.model_selection import train_test_split

# ==========================================
# CONFIGURACIÓN
# ==========================================
SOURCE_DIR   = "dataset-sinCambio"
OUTPUT_DIR   = "dataset-Entrenamiento"
TRAIN_SPLIT  = 0.70
VAL_SPLIT    = 0.15
TEST_SPLIT   = 0.15
SEED         = 42
VALID_EXTENSIONS = [".png", ".jpg", ".jpeg"]

# "oversample" | "undersample" | None
BALANCE_STRATEGY = "undersample"

# ==========================================
# VERIFICAR SPLITS
# ==========================================
assert TRAIN_SPLIT + VAL_SPLIT + TEST_SPLIT == 1.0, "Los splits deben sumar 1.0"
random.seed(SEED)

# ==========================================
# CREAR DIRECTORIOS
# ==========================================
splits = ["train", "val", "test"]
for split in splits:
    os.makedirs(os.path.join(OUTPUT_DIR, split), exist_ok=True)

# ==========================================
# OBTENER CLASES
# ==========================================
classes = sorted([
    d for d in os.listdir(SOURCE_DIR)
    if os.path.isdir(os.path.join(SOURCE_DIR, d))
])
print("\nClases detectadas:")
for cls in classes:
    print(f"  - {cls}")

# ==========================================
# SPLIT POR CLASE (primera pasada)
# ==========================================
split_data_all = {}   # { cls: { "train": [...], "val": [...], "test": [...] } }

for cls in classes:
    class_dir = os.path.join(SOURCE_DIR, cls)
    images = [
        os.path.join(class_dir, img)
        for img in os.listdir(class_dir)
        if Path(img).suffix.lower() in VALID_EXTENSIONS
    ]
    random.shuffle(images)

    train_images, temp_images = train_test_split(
        images,
        test_size=(1 - TRAIN_SPLIT),
        random_state=SEED
    )
    val_ratio_adjusted = VAL_SPLIT / (VAL_SPLIT + TEST_SPLIT)
    val_images, test_images = train_test_split(
        temp_images,
        test_size=(1 - val_ratio_adjusted),
        random_state=SEED
    )

    split_data_all[cls] = {
        "train": train_images,
        "val":   val_images,
        "test":  test_images
    }

# ==========================================
# BALANCEO DEL SPLIT TRAIN
# ==========================================
def balance_split(split_data_by_class, strategy, seed=42):
    """
    Balancea las imágenes de train por clase.

    Parameters
    ----------
    split_data_by_class : dict  { cls: [img_paths] }
    strategy            : str   "oversample" | "undersample"
    seed                : int

    Returns
    -------
    dict  { cls: [img_paths_balanceados] }
    """
    random.seed(seed)
    counts = {cls: len(imgs) for cls, imgs in split_data_by_class.items()}
    target = max(counts.values()) if strategy == "oversample" else min(counts.values())

    print(f"\n{'='*60}")
    print(f"BALANCEO ({strategy.upper()})  →  target por clase: {target}")
    print(f"{'='*60}")
    for cls, n in counts.items():
        print(f"  {cls}: {n} → {target}")

    balanced = {}
    for cls, imgs in split_data_by_class.items():
        n = len(imgs)
        if strategy == "oversample" and n < target:
            # Copia todas las originales + muestrea con reemplazo el resto
            extra = random.choices(imgs, k=(target - n))
            balanced[cls] = imgs + extra
        elif strategy == "undersample" and n > target:
            balanced[cls] = random.sample(imgs, target)
        else:
            balanced[cls] = imgs[:]   # ya está en el target (o no necesita ajuste)
    return balanced

if BALANCE_STRATEGY:
    train_by_class = {cls: split_data_all[cls]["train"] for cls in classes}
    balanced_train = balance_split(train_by_class, BALANCE_STRATEGY, seed=SEED)
    for cls in classes:
        split_data_all[cls]["train"] = balanced_train[cls]

# ==========================================
# COPIAR ARCHIVOS
# ==========================================
print()
for cls in classes:
    print("="*50)
    print(f"Copiando clase: {cls}")
    print("="*50)

    for split_name in splits:
        split_images    = split_data_all[cls][split_name]
        split_class_dir = os.path.join(OUTPUT_DIR, split_name, cls)
        os.makedirs(split_class_dir, exist_ok=True)

        seen_names = {}   # maneja duplicados en oversample
        for img_path in split_images:
            filename  = os.path.basename(img_path)
            stem, ext = os.path.splitext(filename)

            # Evitar colisiones de nombre al duplicar en oversample
            if filename in seen_names:
                seen_names[filename] += 1
                filename = f"{stem}_dup{seen_names[filename]}{ext}"
            else:
                seen_names[filename] = 0

            shutil.copy2(img_path, os.path.join(split_class_dir, filename))

        count = len(split_images)
        print(f"  {split_name:6s}: {count} imágenes")

# ==========================================
# RESUMEN FINAL
# ==========================================
print("\n" + "="*60)
print("SPLIT COMPLETADO")
print("="*60)
for split_name in splits:
    print(f"\n{split_name.upper()}")
    total = 0
    for cls in classes:
        cls_path = os.path.join(OUTPUT_DIR, split_name, cls)
        count    = len(os.listdir(cls_path))
        total   += count
        print(f"  {cls}: {count}")
    print(f"  TOTAL: {total}")

print("\nDataset listo para TensorFlow.")