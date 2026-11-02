#!/usr/bin/env bash
# 诸暨实时公交 APK 构建脚本
# 不依赖 Gradle / Android Studio：aapt2 + javac + d8 + zipalign + apksigner
#
# 前置：
#   JDK 17        -> export JAVA_HOME=/path/to/jdk-17
#   Android SDK   -> export ANDROID_HOME=/path/to/android-sdk
#                    （需 build-tools;34.0.0 与 platforms;android-34）
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"

# 本地开发时可选：如果仓库同级有 _tools 目录，自动沿用
if [ -z "$JAVA_HOME" ] && [ -d "$HERE/../_tools/jdk_tmp" ]; then
  JAVA_HOME="$(ls -d "$HERE"/../_tools/jdk_tmp/jdk-* | head -1)"
  export JAVA_HOME
fi
if [ -z "$ANDROID_HOME" ] && [ -d "$HERE/../_tools/sdk" ]; then
  export ANDROID_HOME="$HERE/../_tools/sdk"
fi

: "${JAVA_HOME:?请先设置 JAVA_HOME 指向 JDK 17}"
: "${ANDROID_HOME:?请先设置 ANDROID_HOME 指向 Android SDK}"
export PATH="$JAVA_HOME/bin:$PATH"

BT="$ANDROID_HOME/build-tools/34.0.0"
ANDROID_JAR="$ANDROID_HOME/platforms/android-34/android.jar"
bin() { if [ -f "$1.exe" ]; then echo "$1.exe"; else echo "$1"; fi; }
AAPT2="$(bin "$BT/aapt2")"
D8="$(bin "$BT/d8")"
ZIPALIGN="$(bin "$BT/zipalign")"
APKSIGNER="$(bin "$BT/apksigner")"
KEYTOOL="$(bin "$JAVA_HOME/bin/keytool")"

OUT="$HERE/build"
DIST="$(cd "$HERE/.." && pwd)/dist"
rm -rf "$OUT"
mkdir -p "$OUT/gen" "$OUT/classes" "$OUT/dex" "$DIST"

echo "==> 同步网页资源"
rm -rf "$HERE/assets"
mkdir -p "$HERE/assets/www"
if [ -f "$HERE/../web/index.html" ]; then
  cp "$HERE/../web/index.html" "$HERE/assets/www/index.html"
else
  cp "$HERE/../index.html" "$HERE/assets/www/index.html"
fi

echo "==> aapt2 compile"
"$AAPT2" compile --dir "$HERE/res" -o "$OUT/res.zip"

echo "==> aapt2 link"
"$AAPT2" link \
  -o "$OUT/app-unsigned.apk" \
  -I "$ANDROID_JAR" \
  --manifest "$HERE/AndroidManifest.xml" \
  -R "$OUT/res.zip" \
  -A "$HERE/assets" \
  --java "$OUT/gen" \
  --min-sdk-version 21 \
  --target-sdk-version 34 \
  --version-code 1 \
  --version-name 1.0 \
  --auto-add-overlay

echo "==> javac"
cd "$HERE"
find "build/gen" "src" -name "*.java" > "build/sources.txt"
javac -nowarn -source 8 -target 8 -encoding UTF-8 -bootclasspath "$ANDROID_JAR" \
  -d "build/classes" @"build/sources.txt"

echo "==> d8"
find "build/classes" -name "*.class" > "build/classes.txt"
"$D8" --release --lib "$ANDROID_JAR" --min-api 21 --output "build/dex" @"build/classes.txt"

echo "==> 打包 classes.dex"
python - "$OUT/app-unsigned.apk" "$OUT/dex/classes.dex" <<'PY'
import sys, zipfile, shutil
apk, dex = sys.argv[1], sys.argv[2]
tmp = apk + '.tmp'
shutil.move(apk, tmp)
with zipfile.ZipFile(tmp) as zin, zipfile.ZipFile(apk, 'w', zipfile.ZIP_DEFLATED) as zout:
    for it in zin.infolist():
        zout.writestr(it, zin.read(it.filename))
    zout.write(dex, 'classes.dex')
PY

echo "==> zipalign"
"$ZIPALIGN" -f -p 4 "$OUT/app-unsigned.apk" "$OUT/app-aligned.apk"

if [ ! -f "$HERE/release.keystore" ]; then
  echo "==> 生成签名证书（仅首次；请务必备份，覆盖安装必须用同一份）"
  "$KEYTOOL" -genkeypair -v -keystore "$HERE/release.keystore" \
    -alias zjbus -keyalg RSA -keysize 2048 -validity 10950 \
    -storepass zjbus2026 -keypass zjbus2026 \
    -dname "CN=Zhuji Bus Live, OU=App, O=Personal, L=Zhuji, ST=Zhejiang, C=CN" 2>&1 | tail -2
fi

echo "==> 签名"
"$APKSIGNER" sign --ks "$HERE/release.keystore" --ks-key-alias zjbus \
  --ks-pass pass:zjbus2026 --key-pass pass:zjbus2026 \
  --out "$DIST/诸暨实时公交.apk" "$OUT/app-aligned.apk"

echo "==> 校验"
"$APKSIGNER" verify --print-certs "$DIST/诸暨实时公交.apk" | head -6
ls -lh "$DIST/诸暨实时公交.apk"
echo "BUILD OK"
