#!/bin/bash
# Script de limpieza para "Aplicacion-reconocimiento-de-lenguas-indigenas" (Uuy)
# Ejecutar desde la RAÍZ de tu repo local (donde está el .git)
#
# Uso:
#   chmod +x limpiar_repo.sh
#   ./limpiar_repo.sh

set -e

echo "== 1. Modelos TFLite duplicados sin usar (solo 'MobileNetV3Large_normal.tflite' está en pubspec.yaml) =="
git rm -f "lib/modelos/MobileNetV3Large_normal1.tflite" 2>/dev/null || echo "  (ya no existe o no estaba trackeado)"
git rm -f "lib/modelos/MobileNetV3Large_normal2.tflite" 2>/dev/null || echo "  (ya no existe o no estaba trackeado)"

echo "== 2. Carpeta de código muerto confirmado (sin referencias en lib/ ni android/app/src) =="
git rm -rf "widgets - No usados" 2>/dev/null || echo "  (ya no existe o no estaba trackeada)"

echo "== 3. Config de IDE que no debería versionarse (ya estaba tracked antes del .gitignore) =="
git rm -rf --cached .idea 2>/dev/null || echo "  (raíz .idea no trackeada)"
git rm -rf --cached android/.idea 2>/dev/null || echo "  (android/.idea no trackeada)"
git rm -rf --cached .vscode 2>/dev/null || echo "  (.vscode no trackeada)"
rm -rf .idea android/.idea .vscode

echo "== 4. .iml duplicados con nombres viejos del proyecto (raíz + android/) =="
git rm -f "reconocimiento_lenguas_indigenas.iml" 2>/dev/null || true
git rm -f "flutter_permisos.iml" 2>/dev/null || true
git rm -f "android/android.iml" 2>/dev/null || true
git rm -f "android/flutter_permisos_android.iml" 2>/dev/null || true
git rm -f "android/reconocimiento_lenguas_indigenas_android.iml" 2>/dev/null || true

echo "== 5. package.json vacío (proyecto Flutter puro, no necesita npm) =="
git rm -f package.json 2>/dev/null || echo "  (no existe o no estaba trackeado)"

echo "== 6. .flutter-plugins-dependencies: archivo autogenerado que se coló por un .gitignore roto =="
git rm -f --cached .flutter-plugins-dependencies 2>/dev/null || echo "  (no trackeado)"
rm -f .flutter-plugins-dependencies

echo "== 7. Reubicar script de preprocesamiento fuera de la raíz =="
if [ -f "piezas funcionales/Main.kt" ]; then
  mkdir -p scripts
  git mv "piezas funcionales/Main.kt" "scripts/generar_espectrogramas.kt"
  rmdir "piezas funcionales" 2>/dev/null || true
else
  echo "  (ya no existe en esa ruta)"
fi

echo "== 8. Reemplazar .gitignore (el actual tenía comentarios en línea que rompían los patrones) =="
cat > .gitignore << 'EOF'
# Flutter/Dart
.dart_tool/
.packages
.pub/
build/
.flutter-plugins
.flutter-plugins-dependencies
*.hprof
*.log

# Android
android/.gradle/
android/app/build/
android/build/
android/captures/
.gradle/
local.properties

# Keystore files
*.jks
*.keystore

# IDE
.idea/
.vscode/
*.iml

# iOS
ios/Pods/

# Node
node_modules/

# Environment files
.env
.env.*
EOF
git add .gitignore

echo ""
echo "== Listo. Revisa el estado antes de comitear: =="
git status

echo ""
echo "Si todo se ve bien:"
echo "  git commit -m 'chore: limpiar repo (modelos duplicados, código muerto, config de IDE, .gitignore)'"
echo ""
echo "NOTA: esto reduce el árbol de trabajo, pero los archivos grandes ya comiteados"
echo "siguen ocupando espacio en el HISTORIAL de git. Si además quieres reducir el"
echo "tamaño del repo clonado (.git), avísame y te paso el comando de 'git filter-repo'"
echo "para purgarlos también del historial (requiere force-push, hazlo con cuidado)."
