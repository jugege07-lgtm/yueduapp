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

echo "==> 下载模型: $MODEL_URL"
curl -L -o model.tar.bz2 "$MODEL_URL"

echo "==> 解压..."
tar xf model.tar.bz2
rm -f model.tar.bz2

# 生成 manifest.txt（列出所有解压出的文件，供 App 拷贝到私有目录）
find . -type f -not -name manifest.txt | sed 's|^\./||' | sort > manifest.txt

echo "==> 完成。解压出的文件清单："
cat manifest.txt

echo ""
echo "【下一步】打开 lib/services/tts_model_config.dart，"
echo "把里面的路径（model/tokens/lexicon/dataDir/dictDir）"
echo "改成上面清单里的实际文件名（参考官方 example/lib/model.dart）。"
