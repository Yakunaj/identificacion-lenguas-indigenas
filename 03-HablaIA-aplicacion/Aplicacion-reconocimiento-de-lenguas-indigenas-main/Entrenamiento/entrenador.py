import os
import random
import shutil
import tensorflow as tf
from tensorflow.keras import layers, models
from tensorflow.keras.applications import MobileNetV3Large
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint, ReduceLROnPlateau

# Configuración
CARPETA_DATASET = "espectrogramas"
CARPETA_SPLIT   = "dataset_split"
MODELO_SALIDA   = "modelo_maya_español.keras"
TFLITE_SALIDA   = "modelo_maya_español.tflite"

IMG_SIZE        = 224
BATCH_SIZE      = 32
MAX_POR_CLASE   = 2086
EPOCHS_FASE1    = 20
EPOCHS_FASE2    = 20
SEED            = 42

# 1. Split balanceado 80/10/10
def crear_split(carpeta_origen, carpeta_destino, max_por_clase, seed=42):
    random.seed(seed)
    if os.path.exists(carpeta_destino):
        shutil.rmtree(carpeta_destino)

    clases = sorted([d for d in os.listdir(carpeta_origen) if os.path.isdir(os.path.join(carpeta_origen, d))])
    print(f"\nClases encontradas: {clases}")

    for split in ["train", "val", "test"]:
        for clase in clases:
            os.makedirs(os.path.join(carpeta_destino, split, clase), exist_ok=True)

    for clase in clases:
        imagenes = [f for f in os.listdir(os.path.join(carpeta_origen, clase))
                    if f.lower().endswith(".png")]
        random.shuffle(imagenes)
        imagenes = imagenes[:max_por_clase]

        n       = len(imagenes)
        n_train = int(n * 0.80)
        n_val   = int(n * 0.10)

        splits = {
            "train": imagenes[:n_train],
            "val":   imagenes[n_train:n_train + n_val],
            "test":  imagenes[n_train + n_val:]
        }

        for split, archivos in splits.items():
            for archivo in archivos:
                shutil.copy2(
                    os.path.join(carpeta_origen, clase, archivo),
                    os.path.join(carpeta_destino, split, clase, archivo)
                )
        print(f"  {clase}: train={len(splits['train'])}  "
              f"val={len(splits['val'])}  test={len(splits['test'])}")

    return clases

# 2. Pipelines de datos
def crear_dataset(carpeta, batch_size, shuffle=True):
    ds = tf.keras.utils.image_dataset_from_directory(
        carpeta,
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=batch_size,
        shuffle=shuffle,
        seed=SEED,
        label_mode="binary"         # 2 clases → etiqueta 0 o 1
    )
    # Normalización simple [0, 1] — no usar preprocess_input de ImageNet
    # porque nuestras imágenes son espectrogramas, no fotos naturales
    ds = ds.map(lambda x, y: (x / 255.0, y), num_parallel_calls=tf.data.AUTOTUNE)
    return ds.prefetch(tf.data.AUTOTUNE)

# 3. Modelo
def construir_modelo():
    base = MobileNetV3Large(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights="imagenet",
        include_preprocessing=False  # desactivamos el preprocesamiento interno
    )
    base.trainable = False

    entradas = layers.Input(shape=(IMG_SIZE, IMG_SIZE, 3))
    x = base(entradas, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.BatchNormalization()(x)  # estabiliza cuando la entrada no sigue dist. ImageNet
    x = layers.Dropout(0.3)(x)
    salidas = layers.Dense(1, activation="sigmoid")(x)  # sigmoid para clasificación binaria

    return models.Model(entradas, salidas), base

# 4. Callbacks
def callbacks(checkpoint_path, patience=5):
    return [
        EarlyStopping(
            monitor="val_loss",
            patience=patience,
            restore_best_weights=True,
            verbose=1
        ),
        ModelCheckpoint(
            filepath=checkpoint_path,
            monitor="val_loss",
            save_best_only=True,
            verbose=1
        ),
        ReduceLROnPlateau(
            monitor="val_loss",
            factor=0.5,
            patience=3,
            min_lr=1e-7,
            verbose=1
        )
    ]

# 5. Exportar TFLite float16
def exportar_tflite(modelo, ruta_salida):
    converter = tf.lite.TFLiteConverter.from_keras_model(modelo)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    tflite_model = converter.convert()
    with open(ruta_salida, "wb") as f:
        f.write(tflite_model)
    size_mb = os.path.getsize(ruta_salida) / (1024 * 1024)
    print(f"\nTFLite guardado: {ruta_salida}  ({size_mb:.1f} MB)")

# FLUJO PRINCIPAL
if __name__ == "__main__":

    print("=" * 60)
    print("PASO 1: Split balanceado 80/10/10")
    print("=" * 60)
    clases = crear_split(CARPETA_DATASET, CARPETA_SPLIT, MAX_POR_CLASE, SEED)
    print(f"\nClases: {clases}")

    print("\n" + "=" * 60)
    print("PASO 2: Cargando datasets")
    print("=" * 60)
    ds_train = crear_dataset(os.path.join(CARPETA_SPLIT, "train"), BATCH_SIZE, shuffle=True)
    ds_val   = crear_dataset(os.path.join(CARPETA_SPLIT, "val"),   BATCH_SIZE, shuffle=False)
    ds_test  = crear_dataset(os.path.join(CARPETA_SPLIT, "test"),  BATCH_SIZE, shuffle=False)

    print("\n" + "=" * 60)
    print("PASO 3: Construyendo modelo")
    print("=" * 60)
    modelo, base = construir_modelo()
    modelo.summary()

    # FASE 1: base congelada
    print("\n" + "=" * 60)
    print("FASE 1: Transfer learning — base congelada")
    print("=" * 60)
    modelo.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss="binary_crossentropy",
        metrics=["accuracy"]
    )
    modelo.fit(
        ds_train,
        validation_data=ds_val,
        epochs=EPOCHS_FASE1,
        callbacks=callbacks("checkpoint_fase1.keras", patience=5)
    )

    # FASE 2: fine-tuning últimas 30 capas
    print("\n" + "=" * 60)
    print("FASE 2: Fine-tuning — últimas 30 capas descongeladas")
    print("=" * 60)
    base.trainable = True
    for capa in base.layers[:-30]:
        capa.trainable = False

    capas_entrenables = sum(1 for c in base.layers if c.trainable)
    print(f"Capas entrenables en la base: {capas_entrenables} / {len(base.layers)}")

    modelo.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-5),
        loss="binary_crossentropy",
        metrics=["accuracy"]
    )
    modelo.fit(
        ds_train,
        validation_data=ds_val,
        epochs=EPOCHS_FASE2,
        callbacks=callbacks("checkpoint_fase2.keras", patience=5)
    )

    # Evaluación final
    print("\n" + "=" * 60)
    print("EVALUACIÓN FINAL en test set")
    print("=" * 60)
    loss, acc = modelo.evaluate(ds_test, verbose=1)
    print(f"\nTest loss    : {loss:.4f}")
    print(f"Test accuracy: {acc * 100:.2f}%")

    # Guardar
    modelo.save(MODELO_SALIDA)
    print(f"\nModelo Keras guardado: {MODELO_SALIDA}")

    print("\n" + "=" * 60)
    print("EXPORTANDO A TFLITE")
    print("=" * 60)
    exportar_tflite(modelo, TFLITE_SALIDA)

    print("\n" + "=" * 60)
    print("¡Proceso completado!")
    print(f"  Modelo Keras : {MODELO_SALIDA}")
    print(f"  Modelo TFLite: {TFLITE_SALIDA}")
    print(f"  Clases (orden alfabético): {clases}")
    print("=" * 60)