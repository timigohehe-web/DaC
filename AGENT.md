# AGENT.md — DaC 仓库 Agent 操作手册

> 本文件是写给 Agent（江峰）自己看的操作指南，不是给人类用户看的 README。
> 天赢扔 .tex 文件过来 → 你按这个流程操作。

---

## 一、仓库信息

| 项目 | 值 |
|------|-----|
| 仓库 | `timigohehe-web/DaC` |
| 地址 | `https://github.com/timigohehe-web/DaC` |
| 本地路径 | `/workspace/DaC` |
| 远程 | `origin` → `https://timigohehe-web:$GITHUB_TOKEN_TIMIGOHEHE@github.com/timigohehe-web/DaC.git` |
| 分支 | `main` |
| 可见性 | Public（Actions 免费无限） |

## 二、目录约定

```
DaC/
├── .github/workflows/
│   └── latex-build.yml          # LaTeX 自动编译
├── latex/
│   └── <分类>/<子分类>/<项目名>/
│       ├── image/               # 图片资源
│       ├── pdf/                 # ← 编译好的 PDF 下载到这里（本地用，不提交）
│       └── *.tex                # 源文件
├── typst/                       # 预留
├── AGENT.md                     # 本文件
├── README.md
└── .gitignore
```

- **pdf/ 目录仅本地存在**，已在 `.gitignore` 中排除，不会被提交。
- 图片放 `image/`，tex 里用相对路径 `image/xxx.png` 引用。

## 三、完整操作流程

### 步骤 1：放置 .tex 文件

把天赢给的 `.tex` 文件（和 image/ 图片）放到对应目录：
```
/workspace/DaC/latex/<分类>/<子分类>/<项目名>/xxx.tex
```

### 步骤 2：提交并推送

```bash
cd /workspace/DaC
git add -A
git commit -m "add: <简短描述>"
git push origin main
```

### 步骤 3：轮询 Actions 构建状态 + 下载 PDF

> **必须用 `workspace_shell_session` 执行，禁止裸 shell 跑轮询！**

打开一个 session，然后用 session_id 执行以下脚本：

```bash
# === DaC Actions 轮询 + PDF 下载脚本 ===
# 用法：push 之后直接跑，会自动等最新一次 run 完成

REPO="timigohehe-web/DaC"
TOKEN="$GITHUB_TOKEN_TIMIGOHEHE"
API="https://api.github.com/repos/$REPO"
HEADERS=(-H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json")

echo "[1/4] 等待 Actions run 出现..."
for i in $(seq 1 12); do
  LATEST=$(curl -s "${HEADERS[@]}" "$API/actions/runs?per_page=1&branch=main" \
    | jq -r '.workflow_runs[0] | "\(.id) \(.status) \(.conclusion) \(.created_at)"')
  RUN_ID=$(echo "$LATEST" | awk '{print $1}')
  STATUS=$(echo "$LATEST" | awk '{print $2}')
  echo "  run=$RUN_ID status=$STATUS"
  [ "$STATUS" != "queued" ] && [ "$STATUS" != "null" ] && break
  sleep 10
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
  sleep 15
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
# 先解压到临时目录看看有啥
TMPDIR="/tmp/dac-pdfs-$RUN_ID"
mkdir -p "$TMPDIR"
cd "$TMPDIR"
# unzip 可能没装，用 python 替代
python3 -c "
import zipfile, os, shutil
with zipfile.ZipFile('$TMPZIP', 'r') as z:
    z.extractall('.')
    for f in z.namelist():
        print(f'  extracted: {f}')
"

# 把 PDF 分发到源 tex 文件对应的 pdf/ 目录
cd /workspace/DaC
for pdf in "$TMPDIR"/*.pdf; do
  BASENAME=$(basename "$pdf" .pdf)
  # 找到对应的 .tex 文件位置
  TEX_PATH=$(find latex/ -name "${BASENAME}.tex" -type f | head -1)
  if [ -n "$TEX_PATH" ]; then
    TARGET_DIR=$(dirname "$TEX_PATH")/pdf
    mkdir -p "$TARGET_DIR"
    cp "$pdf" "$TARGET_DIR/"
    echo "  ✅ $BASENAME.pdf → $TARGET_DIR/"
  else
    # 找不到对应 tex，放到根 output
    mkdir -p output/
    cp "$pdf" output/
    echo "  ⚠️ $BASENAME.pdf → output/ (未找到对应 .tex)"
  fi
done

# 清理临时文件
rm -rf "$TMPZIP" "$TMPDIR"
echo "🎉 全部完成！"
```

### 超时与异常处理

- 轮询总超时 ≈ 15 分钟（60 × 15s），LaTeX 编译通常 2-5 分钟内完成
- 如果构建失败，去 Actions 页面看日志，常见问题：
  - 缺宏包 → 在 workflow yml 的 `extra_system_packages` 加
  - tex 语法错误 → 看 log 修源文件
  - 编译超时 → 文件太大或死循环引用

## 四、Workflow 维护

### 当前 LaTeX workflow 要点

- 文件：`.github/workflows/latex-build.yml`
- 触发：push 到 main 且 `latex/**` 有变更，或手动 `workflow_dispatch`
- 编译器：`xelatex`（支持中文 ctex）
- 输出：所有 PDF 收集到 `compiled-pdfs` artifact，保留 90 天

### 新增编译语言

在 `.github/workflows/` 下新建 yml 即可，例如：
- `typst-build.yml` → 监听 `typst/**`
- `pandoc-build.yml` → 监听 `markdown/**`

各 workflow 独立触发、互不干扰。

## 五、Git 操作备忘

```bash
# 拉取最新
cd /workspace/DaC && git pull origin main

# 推送
cd /workspace/DaC && git add -A && git commit -m "xxx" && git push origin main

# 凭证已在 remote URL 里，不需要额外配置
```

## 六、注意事项

1. **轮询必须走 shell_session**，铁律，不解释。
2. **pdf/ 目录不提交**——`.gitignore` 已排除，编译产物只存本地。
3. **图片路径**——tex 里用相对路径 `image/xxx.png`，不要用绝对路径。
4. **多个 tex 文件**——workflow 会自动扫描 `latex/**/*.tex` 全部编译，不用改 yml。
5. **Push 之前先 pull**——避免冲突（虽然大概率只有老子一个人在推）。
