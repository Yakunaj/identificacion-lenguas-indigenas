"""Entrenamiento del clasificador de lenguas (Maya/Nahuatl/Zapoteco/Español) con MobileNetV2.

Migración a PyTorch de la sección "Construcción del modelo: MobileNetV2"
de Clasificacion.ipynb. Únicamente MobileNetV2, en dos fases:

  Fase 1 (20 épocas): base Imagenet congelada + cabeza nueva, lr = INITIAL_LR.
  Fase 2 (10 épocas): descongela las últimas 10 capas de la base, lr = FINE_TUNE_LR.

Se replican los callbacks de la libreta:
  - Warmup de 3 épocas (lr = base_lr * min(1, (epoch+1)/3))
  - ReduceLROnPlateau (factor 0.5, patience 4, min_lr 1e-7)
  - EarlyStopping (patience 8) restaurando los mejores pesos

Requiere los splits generados por graficacion.py
(datos/splits/CNN1/train, datos/splits/CNN1/validation y datos/splits/CNN1/test).

Dispositivo detectado automáticamente:
  torch-directml (GPU AMD en Windows) -> CUDA/ROCm -> CPU.

Este script vive en un ambiente virtual aislado (codigo/entrenamiento/.venv)
para poder fijar las versiones de torch-directml/torch/torchvision sin
contaminar el resto del proyecto.

Ejecución:
    & codigo\\entrenamiento\\.venv\\Scripts\\python.exe codigo\\entrenamiento\\entrenamiento.py
"""

import json
import os
import random
import sys

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from torchvision import datasets, models, transforms

from sklearn.metrics import (
    accuracy_score, recall_score, precision_score, f1_score,
    classification_report, confusion_matrix,
)

CODIGO_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CODIGO_DIR)

from configuraciones import (
    BATCH_SIZE, CSV_LOG_PATH, EPOCHS_PHASE1, EPOCHS_PHASE2, FINE_TUNE_LR,
    FOLDER_PATH_LIST, HAS_SILENCE, HEAD_L2, IMG_SIZE, INITIAL_LR, LABEL_SMOOTHING,
    LANGUAGES, LOG_COLUMNS, MIN_LR, MODEL_OUTPUT, NUM_CLASSES, PLOT_PHASE1_PATH,
    PLOT_PHASE2_PATH, REDUCE_LR_FACTOR, REDUCE_LR_PATIENCE, RESULTADOS_DIR,
    SEED, SPLIT_SEED, TEST_DIR, TRAIN_DIR, USED_MODEL, VAL_DIR, WARMUP_EPOCHS,
    AUDIO_LENGTH,
    compute_experiment_hash, compute_parameters,
    EARLY_STOP_PATIENCE,
)


# ============ SEMILLAS ============
random.seed(SEED)
np.random.seed(SEED)
torch.manual_seed(SEED)
os.environ['PYTHONHASHSEED'] = str(SEED)


# ============ DISPOSITIVO ============
def get_device():
    """Prefiere torch-directml (AMD/Windows), luego CUDA (incluye ROCm), y CPU."""
    try:
        import torch_directml
        dml = torch_directml.device()
        print(f"Usando dispositivo: {dml} (DirectML)")
        return dml
    except ImportError:
        pass
    if torch.cuda.is_available():
        device = torch.device('cuda')
        print(f"Usando dispositivo: {device} ({torch.cuda.get_device_name(0)})")
        return device
    print("Usando dispositivo: CPU (sin aceleración por GPU)")
    return torch.device('cpu')


device = get_device()


# ============ SPEC AUGMENT (igual que la libreta) ============
def spec_augment(image, freq_mask_param=8, time_mask_param=8):
    """Enmascara frecuencias y tiempos de un espectrograma (tensor C,H,W en [0,1])."""
    img = image
    _, f, t = img.shape
    f_mask = random.randrange(freq_mask_param)
    f_start = random.randrange(max(f - f_mask, 1))
    if f_mask > 0:
        img[:, f_start:f_start + f_mask, :] = 0.0
    t_mask = random.randrange(time_mask_param)
    t_start = random.randrange(max(t - t_mask, 1))
    if t_mask > 0:
        img[:, :, t_start:t_start + t_mask] = 0.0
    return img


def collate_augment(batch):
    images, labels = zip(*batch)
    images = torch.stack(images)
    for i in range(len(images)):
        images[i] = spec_augment(images[i])
    return images, torch.tensor(labels)


# ============ DATASET ============
def build_loaders():
    if not all(os.path.isdir(path) for path in (TRAIN_DIR, VAL_DIR, TEST_DIR)):
        raise FileNotFoundError(
            f"No se encontraron los splits en {TRAIN_DIR} / {VAL_DIR} / {TEST_DIR}. "
            "Ejecuta primero: python codigo/graficacion.py"
        )
    transform = transforms.Compose([
        transforms.Resize(IMG_SIZE),
        transforms.ToTensor(),
    ])
    train_ds = datasets.ImageFolder(TRAIN_DIR, transform=transform)
    val_ds = datasets.ImageFolder(VAL_DIR, transform=transform)
    test_ds = datasets.ImageFolder(TEST_DIR, transform=transform)

    expected_class_to_idx = {
        language: index for index, language in enumerate(LANGUAGES)
    }
    if any(
        dataset.class_to_idx != expected_class_to_idx
        for dataset in (train_ds, val_ds, test_ds)
    ):
        raise ValueError(
            "Las clases de train, validation y test deben coincidir con LANGUAGES."
        )

    print(
        f"Train samples: {len(train_ds)} | Val samples: {len(val_ds)} | "
        f"Test samples: {len(test_ds)}"
    )
    print(f"Clases (orden de carpeta): {train_ds.classes} -> {train_ds.class_to_idx}")

    train_loader = DataLoader(
        train_ds, batch_size=BATCH_SIZE, shuffle=True,
        num_workers=2, collate_fn=collate_augment,
    )
    val_loader = DataLoader(
        val_ds, batch_size=BATCH_SIZE, shuffle=False, num_workers=2,
    )
    test_loader = DataLoader(
        test_ds, batch_size=BATCH_SIZE, shuffle=False, num_workers=2,
    )
    return train_loader, val_loader, test_loader


def read_image_amount():
    """Lee el tope de clips por lengua guardado por graficacion.py; si falta, lo estima."""
    metadata_path = os.path.abspath(os.path.join(TRAIN_DIR, '..', 'metadata.json'))
    if os.path.exists(metadata_path):
        with open(metadata_path, encoding='utf-8') as f:
            meta = json.load(f)
        if 'language_limit' in meta:
            return {lang: meta['language_limit'] for lang in LANGUAGES}
    counts = {lang: 0 for lang in LANGUAGES}
    for root, _dirs, files in os.walk(TRAIN_DIR):
        label = os.path.basename(root)
        if label in counts:
            counts[label] += len([f for f in files if f.lower().endswith('.png')])
    return counts


# ============ MODELO (solo MobileNetV2) ============
class MobileNetV2Classifier(nn.Module):
    """MobileNetV2 (Imagenet) + cabeza idéntica a la libreta:
    GlobalAvgPool -> Dense(128, relu, l2=5e-4) -> BatchNorm -> Dropout(0.6) -> Dense(num_classes)."""

    def __init__(self, num_classes):
        super().__init__()
        base = models.mobilenet_v2(weights=models.MobileNet_V2_Weights.IMAGENET1K_V1)
        self.features = base.features
        self.avgpool = nn.AdaptiveAvgPool2d(1)
        self.head = nn.Sequential(
            nn.Linear(1280, 128),
            nn.BatchNorm1d(128),
            nn.ReLU(),
            nn.Dropout(0.6),
            nn.Linear(128, num_classes),
        )

    def forward(self, x):
        x = self.features(x)
        x = self.avgpool(x)
        x = torch.flatten(x, 1)
        return self.head(x)


def build_model():
    model = MobileNetV2Classifier(NUM_CLASSES).to(device)
    for p in model.parameters():
        p.requires_grad = False
    for p in model.head.parameters():
        p.requires_grad = True
    return model


def build_optimizer(model, lr):
    """Adam. weight_decay 5e-4 solo sobre el peso del Dense(128) (equivale al l2 de la libreta)."""
    l2_weight = model.head[0].weight
    no_wd = [p for p in model.parameters() if p.requires_grad and p is not l2_weight]
    return torch.optim.Adam([
        {'params': [l2_weight], 'weight_decay': HEAD_L2},
        {'params': no_wd, 'weight_decay': 0.0},
    ], lr=lr)


# ============ ENTRENAMIENTO ============
def train_one_epoch(model, loader, optimizer, criterion):
    model.train()
    running_loss = 0.0
    correct = 0
    total = 0
    for xb, yb in loader:
        xb, yb = xb.to(device), yb.to(device)
        optimizer.zero_grad()
        out = model(xb)
        loss = criterion(out, yb)
        loss.backward()
        optimizer.step()
        running_loss += loss.item() * len(yb)
        correct += (out.argmax(dim=1) == yb).sum().item()
        total += len(yb)
    return running_loss / total, correct / total


@torch.no_grad()
def evaluate(model, loader, criterion):
    model.eval()
    running_loss = 0.0
    y_true, y_pred = [], []
    for xb, yb in loader:
        xb, yb = xb.to(device), yb.to(device)
        out = model(xb)
        loss = criterion(out, yb)
        running_loss += loss.item() * len(yb)
        y_pred.extend(out.argmax(dim=1).cpu().tolist())
        y_true.extend(yb.cpu().tolist())
    y_true = np.array(y_true)
    y_pred = np.array(y_pred)
    return {
        'loss': running_loss / len(y_true),
        'acc': accuracy_score(y_true, y_pred),
        'recall': recall_score(y_true, y_pred, average='macro', zero_division=0),
        'precision': precision_score(y_true, y_pred, average='macro', zero_division=0),
        'f1': f1_score(y_true, y_pred, average='macro', zero_division=0),
        'y_true': y_true,
        'y_pred': y_pred,
    }


def run_phase(model, train_loader, val_loader, base_lr, epochs, phase_name):
    criterion = nn.CrossEntropyLoss(label_smoothing=LABEL_SMOOTHING)
    optimizer = build_optimizer(model, base_lr)
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
        optimizer, mode='min', factor=REDUCE_LR_FACTOR,
        patience=REDUCE_LR_PATIENCE, min_lr=MIN_LR,
    )

    best_val_loss = float('inf')
    best_state = None
    wait = 0
    history = {'loss': [], 'acc': [], 'val_loss': [], 'val_acc': []}

    for epoch in range(epochs):
        if epoch < WARMUP_EPOCHS:
            factor = (epoch + 1) / WARMUP_EPOCHS
            for g in optimizer.param_groups:
                g['lr'] = base_lr * factor

        train_loss, train_acc = train_one_epoch(model, train_loader, optimizer, criterion)
        val_metrics = evaluate(model, val_loader, criterion)

        if epoch >= WARMUP_EPOCHS:
            scheduler.step(val_metrics['loss'])

        history['loss'].append(train_loss)
        history['acc'].append(train_acc)
        history['val_loss'].append(val_metrics['loss'])
        history['val_acc'].append(val_metrics['acc'])

        print(
            f"Epoch {epoch + 1}/{epochs} - loss: {train_loss:.4f} "
            f"- acc: {train_acc:.4f} - val_loss: {val_metrics['loss']:.4f} "
            f"- val_acc: {val_metrics['acc']:.4f}"
        )

        if val_metrics['loss'] < best_val_loss:
            best_val_loss = val_metrics['loss']
            best_state = {k: v.detach().cpu().clone() for k, v in model.state_dict().items()}
            wait = 0
        else:
            wait += 1
            if wait >= EARLY_STOP_PATIENCE:
                print(f"Early stopping ({phase_name}): sin mejora en val_loss durante {EARLY_STOP_PATIENCE} épocas.")
                break

    if best_state is not None:
        model.load_state_dict(best_state)
        print(f"{phase_name}: restaurados los mejores pesos (val_loss={best_val_loss:.4f}).")

    save_curves(history, phase_name)
    return history, best_val_loss


def save_curves(history, phase_name):
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))
    ax1.plot(history['acc'], label='Train Accuracy')
    ax1.plot(history['val_acc'], label='Val Accuracy')
    ax1.set_title(f'{phase_name}: Accuracy')
    ax1.set_xlabel('Epoch')
    ax1.set_ylabel('Accuracy')
    ax1.legend()
    ax2.plot(history['loss'], label='Train Loss')
    ax2.plot(history['val_loss'], label='Val Loss')
    ax2.set_title(f'{phase_name}: Loss')
    ax2.set_xlabel('Epoch')
    ax2.set_ylabel('Loss')
    ax2.legend()
    plt.tight_layout()
    out_path = PLOT_PHASE1_PATH if phase_name == 'Fase 1' else PLOT_PHASE2_PATH
    plt.savefig(out_path, dpi=150)
    plt.close(fig)
    print(f"Curvas guardadas en: {out_path}")


def save_confusion_matrix(y_true, y_pred, plot_path):
    cm = confusion_matrix(y_true, y_pred, labels=range(NUM_CLASSES))
    fig, ax = plt.subplots(figsize=(7, 6))
    im = ax.imshow(cm, interpolation='nearest', cmap=plt.cm.Blues)
    ax.set_title('Matriz de confusión (test)')
    ax.set_xlabel('Predicción')
    ax.set_ylabel('Real')
    ax.set_xticks(range(NUM_CLASSES))
    ax.set_yticks(range(NUM_CLASSES))
    ax.set_xticklabels(LANGUAGES)
    ax.set_yticklabels(LANGUAGES)
    thresh = cm.max() / 2
    for i in range(NUM_CLASSES):
        for j in range(NUM_CLASSES):
            ax.text(j, i, f'{cm[i, j]}', ha='center', va='center',
                    color='white' if cm[i, j] > thresh else 'black')
    fig.colorbar(im, ax=ax)
    fig.tight_layout()
    fig.savefig(plot_path, dpi=150)
    plt.close(fig)
    print(f"Matriz de confusión guardada en: {plot_path}")


# ============ SALIDAS ============
def save_model(model, test_metrics):
    payload = {
        'model_state_dict': {k: v.cpu() for k, v in model.state_dict().items()},
        'class_names': LANGUAGES,
        'image_size': IMG_SIZE,
        'model': USED_MODEL,
        'results': {
            'accuracy': test_metrics['acc'],
            'recall': test_metrics['recall'],
            'precision': test_metrics['precision'],
            'f1': test_metrics['f1'],
            'test_loss': test_metrics['loss'],
        },
    }
    torch.save(payload, MODEL_OUTPUT)
    print(f"Model saved to {MODEL_OUTPUT}")


def log_experiment(test_metrics, image_amount):
    results_str = (
        f"Accuracy: {test_metrics['acc']:.4f} "
        f"Recall: {test_metrics['recall']:.4f} "
        f"Precision: {test_metrics['precision']:.4f} "
        f"F1: {test_metrics['f1']:.4f}"
    )
    new_exp = {
        'ID_Exp': f"EXP{len(pd.read_csv(CSV_LOG_PATH)) if os.path.exists(CSV_LOG_PATH) and os.path.getsize(CSV_LOG_PATH) > 0 else 0}",
        'Hash': compute_experiment_hash(),
        'Languages': LANGUAGES,
        'Model': USED_MODEL,
        'Audio_Length': AUDIO_LENGTH,
        'Image_Amount': image_amount,
        'Parameters': compute_parameters(),
        'Results': results_str,
        'Split_Seed': SPLIT_SEED,
        'hasSilence': HAS_SILENCE,
        'Audio_Folders_Used': FOLDER_PATH_LIST,
        'Notes': '',
    }
    if os.path.exists(CSV_LOG_PATH) and os.path.getsize(CSV_LOG_PATH) > 0:
        df_log = pd.read_csv(CSV_LOG_PATH)
    else:
        df_log = pd.DataFrame(columns=LOG_COLUMNS)
    df_log = pd.concat([df_log, pd.DataFrame([new_exp])], ignore_index=True)
    df_log.to_csv(CSV_LOG_PATH, index=False)
    print(f"Experiment logged to {CSV_LOG_PATH}")
    print(df_log.tail())


def main():
    print("Cargando splits...")
    image_amount = read_image_amount()
    train_loader, val_loader, test_loader = build_loaders()

    print("Construyendo MobileNetV2...")
    model = build_model()
    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    total = sum(p.numel() for p in model.parameters())
    print(f"Trainable params: {trainable:,} / {total:,} total")

    history1, _ = run_phase(model, train_loader, val_loader, INITIAL_LR,
                            EPOCHS_PHASE1, 'Fase 1')

    print("Descongelando las últimas 10 capas de la base para fine-tuning...")
    for p in model.features.parameters():
        p.requires_grad = False
    for p in list(model.features.parameters())[-10:]:
        p.requires_grad = True

    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    total = sum(p.numel() for p in model.parameters())
    print(f"Trainable params: {trainable:,} / {total:,} total")

    history2, _ = run_phase(model, train_loader, val_loader, FINE_TUNE_LR,
                            EPOCHS_PHASE2, 'Fase 2')

    print("Evaluación final sobre test...")
    criterion = nn.CrossEntropyLoss()
    test_metrics = evaluate(model, test_loader, criterion)
    print(
        f"Accuracy: {test_metrics['acc']:.4f} | Recall: {test_metrics['recall']:.4f} "
        f"| Precision: {test_metrics['precision']:.4f} | F1: {test_metrics['f1']:.4f}"
    )
    labels = range(NUM_CLASSES)
    print(classification_report(
        test_metrics['y_true'], test_metrics['y_pred'], labels=labels,
        target_names=LANGUAGES, digits=4, zero_division=0,
    ))
    print("Confusion matrix (test):")
    print(confusion_matrix(
        test_metrics['y_true'], test_metrics['y_pred'], labels=labels,
    ))

    save_confusion_matrix(
        test_metrics['y_true'], test_metrics['y_pred'],
        os.path.join(RESULTADOS_DIR, 'matriz_confusion_test.png'),
    )

    save_model(model, test_metrics)
    log_experiment(test_metrics, image_amount)


if __name__ == '__main__':
    main()