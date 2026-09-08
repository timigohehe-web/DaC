#!/usr/bin/env bash
set -e

REPO="timigohehe-web/DaC"
TOKEN="$GITHUB_TOKEN_TIMIGOHEHE"
API="https://api.github.com/repos/$REPO"
HEADERS=(-H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json")

echo "[1/4] 等待 Actions run 出现..."
RUN_ID=""
for i in $(seq 1 12); do
  LATEST=$(curl -s "${HEADERS[@]}" "$API/actions/runs?per_page=1&branch=main" \
    | jq -r '.workflow_runs[0] | "\(.id) \(.status) \(.conclusion) \(.created_at)"')
  RUN_ID=$(echo "$LATEST" | awk '{print $1}')
  STATUS=$(echo "$LATEST" | awk '{print $2}')
  echo "  run=$RUN_ID status=$STATUS"
  if [ -n "$RUN_ID" ] && [ "$RUN_ID" != "null" ]; then
    break
  fi
  sleep 5
done

echo "[2/4] 等待 run $RUN_ID 完成..."
for i in $(seq 1 60); do
  RESULT=$(curl -s "${HEADERS[@]}" "$API/actions/runs/$RUN_ID" \
    | jq -r '"\(.status) \(.conclusion)"')
  STATUS=$(echo "$RESULT" | awk '{print $1}')
  CONCLUSION=$(echo "$RESULT" | awk '{print $2}')
  echo "  [$i] status=$STATUS conclusion=$CONCLUSION"
  if [ "$STATUS" = "completed" ]; then
    break
  fi
  sleep 10
done

if [ "$CONCLUSION" != "success" ]; then
  echo "❌ 构建失败！conclusion=$CONCLUSION"
  echo "查看日志: https://github.com/$REPO/actions/runs/$RUN_ID"
  exit 1
fi

echo "[3/4] 构建成功 ✅ 下载 Artifacts..."
ARTIFACTS_URL=$(curl -s "${HEADERS[@]}" "$API/actions/runs/$RUN_ID/artifacts" \
  | jq -r '.artifacts[0].archive_download_url')

if [ "$ARTIFACTS_URL" = "null" ] || [ -z "$ARTIFACTS_URL" ]; then
  echo "❌ 没有找到 artifact"
  exit 1
fi

TMPZIP="/tmp/dac-pdfs-$RUN_ID.zip"
curl -s -L "${HEADERS[@]}" "$ARTIFACTS_URL" -o "$TMPZIP"
echo "  下载完成: $TMPZIP ($(du -h "$TMPZIP" | cut -f1))"

echo "[4/4] 解压 PDF 到对应目录..."
TMPDIR="/tmp/dac-pdfs-$RUN_ID"
mkdir -p "$TMPDIR"
cd "$TMPDIR"
python3 -c "
import zipfile, os, shutil
with zipfile.ZipFile('$TMPZIP', 'r') as z:
    z.extractall('.')
    for f in z.namelist():
        print(f'  extracted: {f}')
"

cd /workspace/DaC
for pdf in "$TMPDIR"/*.pdf; do
  [ -f "$pdf" ] || continue
  BASENAME=$(basename "$pdf" .pdf)
  TEX_PATH=$(find latex/ -name "${BASENAME}.tex" -type f | head -1)
  if [ -n "$TEX_PATH" ]; then
    TARGET_DIR=$(dirname "$TEX_PATH")/pdf
    mkdir -p "$TARGET_DIR"
    cp "$pdf" "$TARGET_DIR/"
    echo "  ✅ $BASENAME.pdf → $TARGET_DIR/"
    OBSIDIAN_DIR="/mnt/obsidian/考研学习/数学一/学习记录/概率统计/习题"
    if [ -d "$OBSIDIAN_DIR" ]; then
      cp "$pdf" "$OBSIDIAN_DIR/"
      echo "  ✅ 同步至 Obsidian: $OBSIDIAN_DIR/$BASENAME.pdf"
    fi
  else
    mkdir -p output/
    cp "$pdf" output/
    echo "  ⚠️ $BASENAME.pdf → output/ (未找到对应 .tex)"
  fi
done

rm -rf "$TMPZIP" "$TMPDIR"
echo "🎉 全部完成！"
