# DaC — Documents as Code

> **一个仓库、多用途：文档备份 + 云端 CI 自动编译工厂。**  
> 支持 LaTeX / Typst 等排版源码版本控制，利用 GitHub Actions 免费算力全自动构建 PDF，产物自动分发回本地。

---

## 一、目录规范

```text
DaC/
├── latex/                               # LaTeX 源文件根目录
│   └── <分类>/<子分类>/<项目名>/
│       ├── image/                       # 图片及静态素材（tex 中使用相对路径 image/xxx.png 引用）
│       ├── pdf/                         # 编译产物下载目录（仅本地存在，.gitignore 已忽略，不提交）
│       └── *.tex                        # LaTeX 源码文件
├── typst/                               # Typst 源码目录（预留）
├── scripts/
│   └── poll_and_download.sh             # Actions 构建轮询与 PDF 自动下载分发脚本
├── .github/
│   └── workflows/
│       └── latex-build.yml              # XeLaTeX 自动化编译工作流
├── AGENT.md                             # Agent (江峰) 自动化作业执行规范
└── README.md
```

- **隔离规则**：编译生成的 `pdf/` 目录已在 `.gitignore` 排除，仅用于本地阅读和同步，绝不污染 git 提交历史。
- **资源引用**：所有插图放于 `.tex` 同级的 `image/` 目录中，源码中使用相对路径 `image/foo.png`。

---

## 二、编译引擎与环境

| 语言 / 引擎 | 工作目录 | 编译器 | 状态 | 核心能力与宏包 |
|---|---|---|---|---|
| **LaTeX (XeLaTeX)** | `latex/**` | `latexmk` (-xelatex) | ✅ 已上线 | `ctex` 中文排版、`amsmath`、`amssymb`、`pifont`、`geometry` 等 TeX Live Full 全量宏包 |
| **Typst** | `typst/**` | `typst compile` | 🚧 预留 | 待后续接入工作流 |

---

## 三、操作流程

### 1. 放置源码与提交
把 `.tex` 源码（及 `image/`）按分类丢入对应路径后直接 push：

```bash
cd /workspace/DaC
git add -A
git commit -m "add: xxx.tex"
git push origin main
```

### 2. 云端自动化构建
- 每次 push 到 `main` 且涉及 `latex/**` 变更时，GitHub Actions 自动触发 `latex-build.yml`。
- 自动运行 `latexmk` 并结合 XeLaTeX 多轮编译，自动解决公式交叉引用、目录生成和中文排版。
- 构建成功的产物打包存储于 GitHub Actions Artifacts（保留 90 天）。

### 3. 一键轮询与本地回流
仓库提供自动化轮询脚本，提交后直接运行即可：

```bash
/workspace/DaC/scripts/poll_and_download.sh
```

**脚本行为**：
1. 自动绑定当前 commit SHA 并追踪最新 Actions run 状态；
2. 构建成功后自动通过 GitHub API 下载 Artifacts；
3. 将解压出的 PDF 自动匹配并放入对应源码目录下的 `pdf/`；
4. 自动镜像一份至 Obsidian 考研笔记对应习题目录，便于多端（MatePad / 手机）开箱即刷。

---

## 四、Agent 协作提示

- **Agent 专览指南**：Agent 请参阅根目录下的 [`AGENT.md`](./AGENT.md)。
- **长任务禁令**：运行 `poll_and_download.sh` 等 CI 轮询命令时，**必须使用 `workspace_shell_session`**，严禁裸跑单次 shell 导致超时挂起。
