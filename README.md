# DaC — Documents as Code

> 一个仓库、多用途：文档备份 + 自动编译工厂。

## 目录结构

```
DaC/
├── latex/                    # LaTeX 源文件
│   └── 考研/
│       └── 数学一/
│           └── 线代-向量方程限时训练/
│               ├── image/
│               └── *.tex
├── typst/                    # Typst 源文件（预留）
├── .github/
│   └── workflows/
│       └── latex-build.yml   # LaTeX 自动编译
└── README.md
```

## 使用方式

1. 把 `.tex` 文件放到 `latex/` 下对应目录
2. `git push` 到 `main` 分支
3. GitHub Actions 自动扫描所有 `.tex` 文件并编译为 PDF
4. 到 Actions 页面下载 Artifacts（编译好的 PDF）

## 支持的编译语言

| 语言 | 目录 | 状态 |
|------|------|------|
| LaTeX (XeLaTeX) | `latex/` | ✅ 已配置 |
| Typst | `typst/` | 🚧 预留 |

## 注意事项

- 默认使用 `xelatex` 编译，支持中文（ctex 宏包）
- 每个 `.tex` 文件独立编译，互不干扰
- 图片等资源放在 `.tex` 同级的 `image/` 目录下
