import tensorflow as tf
import numpy as np

tf.keras.mixed_precision.set_global_policy('float32')

# ── 1. Cargar original solo para extraer pesos ────────────────
modelo_original = tf.keras.models.load_model("MobileNetV3Large.keras")

# ── 2. Reconstruir arquitectura 100% limpia desde cero ────────
#    MobileNetV3Large de Keras ya incluye rescaling interno en float32
#    cuando se construye así (sin cargar desde el modelo entrenado)

base = tf.keras.applications.MobileNetV3Large(
    input_shape=(224, 224, 3),
    include_top=False,
    weights=None,          # sin pesos de internet, los ponemos nosotros
    include_preprocessing=False  # ← excluye el Rescaling/Cast interno
)

inputs  = tf.keras.Input(shape=(224, 224, 3), name="input_spectrogram")

# Rescaling manual en float32 puro (equivalente a lo que hacía la Lambda)
x = tf.keras.layers.Rescaling(scale=1./127.5, offset=-1.0)(inputs)

x = base(x, training=False)
x = tf.keras.layers.GlobalAveragePooling2D(name="gap")(x)
x = tf.keras.layers.Dropout(0.3)(x)
x = tf.keras.layers.Dense(256, activation='relu', name="dense_256")(x)
x = tf.keras.layers.Dropout(0.3)(x)
outputs = tf.keras.layers.Dense(
    2, activation='softmax', dtype='float32', name="output"
)(x)

modelo_limpio = tf.keras.Model(inputs=inputs, outputs=outputs)

# ── 3. Traspasar pesos del original al limpio ─────────────────
print(f"Pesos original : {len(modelo_original.get_weights())}")
print(f"Pesos limpio   : {len(modelo_limpio.get_weights())}")

# Verificar que las formas coinciden antes de asignar
pesos_orig  = modelo_original.get_weights()
pesos_nuevo = modelo_limpio.get_weights()

formas_orig  = [w.shape for w in pesos_orig]
formas_nuevo = [w.shape for w in pesos_nuevo]

if formas_orig == formas_nuevo:
    modelo_limpio.set_weights(pesos_orig)
    print("✅ Pesos transferidos correctamente")
else:
    # Mostrar dónde difieren para diagnosticar
    print("⚠️  Diferencia en formas de pesos:")
    for i, (a, b) in enumerate(zip(formas_orig, formas_nuevo)):
        if a != b:
            print(f"  [{i}]  original={a}  limpio={b}")
    raise ValueError("Las arquitecturas no coinciden exactamente")

# ── 4. Verificar que no queda ningún float16 ──────────────────
print("\nCapas del modelo limpio:")
for layer in modelo_limpio.layers:
    flag = "⚠️" if 'float16' in str(layer.dtype) else "✅"
    print(f"  {flag} {layer.name:<30s} dtype={layer.dtype}")

# ── 5. Convertir ──────────────────────────────────────────────
converter = tf.lite.TFLiteConverter.from_keras_model(modelo_limpio)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()

with open("modelo_movil.tflite", "wb") as f:
    f.write(tflite_model)

print(f"\n✅ Guardado  ({len(tflite_model)/1024/1024:.2f} MB)")

# ── 6. Test rápido ────────────────────────────────────────────
interp = tf.lite.Interpreter(model_content=tflite_model)
interp.allocate_tensors()
inp = interp.get_input_details()[0]
out = interp.get_output_details()[0]
dummy = np.zeros(inp['shape'], dtype=np.float32)
interp.set_tensor(inp['index'], dummy)
interp.invoke()
print(f"🧪 Prueba OK → salida: {interp.get_tensor(out['index'])}")
print("🎉 Sin FlexOps, listo para Flutter")