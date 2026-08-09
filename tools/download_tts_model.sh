#!/usr/bin/env bash
# 下载并解压离线 TTS 语音模型到 assets/tts-model/
# 模型会随 APK 打包，实现“AI 离线听书”（完全不联网）。
#
# 想换其他模型（中文/英文/方言），去官方发布页挑选：
#   https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models
# 把下面 MODEL_URL 换成你选的 .tar.bz2 地址即可（命名形如 vits-...-medium.tar.bz2）。
set -e

# ⚠️ 默认示例：中文普通话 VITS 模型（如链接失效，请到上面的发布页另选一个并替换）
# 当前：梵尘 fanchen-C（多说话人，含萝莉/少女情感声线，最接近甜美少女音）
MODEL_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-zh-hf-fanchen-C.tar.bz2"

# 切到脚本所在目录（项目根）
cd "$(dirname "$0")/.."

DEST="assets/tts-model"
mkdir -p "$DEST"
cd "$DEST"

# 清理旧模型（避免换模型后残留文件）
rm -rf *.onnx *.fst *.far tokens.txt lexicon.txt dict espeak-ng-data manifest.txt README.txt

echo "==> 下载模型: $MODEL_URL"
# 带重试：网络抖动时自动重试，避免 CI 因偶发断线而失败
curl -L --retry 5 --retry-delay 10 --connect-timeout 30 --max-time 1800 \
     -o model.tar.bz2 "$MODEL_URL"

echo "==> 解压..."
tar xf model.tar.bz2
rm -f model.tar.bz2

# 官方 tar 通常把所有文件放到一个子目录里（如 vits-zh-hf-fanchen-C/）。
# 为了简化 App 端拷贝逻辑并确保 Flutter assets 能正确打包，
# 把子目录里的文件全部上提到 assets/tts-model/ 根目录。
SUBDIR=$(find . -maxdepth 1 -type d -not -path '.' | head -1)
if [ -n "$SUBDIR" ]; then
  echo "==> 检测到模型子目录 $SUBDIR，将文件上提到根目录..."
  # 先移文件，再移目录，最后删空子目录
  find "$SUBDIR" -maxdepth 1 -type f -exec mv -t . {} +
  find "$SUBDIR" -maxdepth 1 -type d -not -path "$SUBDIR" -exec mv -t . {} +
  rm -rf "$SUBDIR"
fi

# 重新写入 README.txt（说明用途）
printf '此目录用于存放离线 TTS 语音模型文件（由 tools/download_tts_model.sh 下载）。\n运行下载脚本后，这里会出现模型文件和一个 manifest.txt（供 App 拷贝到应用私有目录）。\n' > README.txt

# 生成 manifest.txt（列出所有需要拷贝的模型文件，供 App 拷贝到私有目录）
find . -type f -not -name manifest.txt | sed 's|^\./||' | sort > manifest.txt

echo "==> 完成。解压出的文件清单："
cat manifest.txt
