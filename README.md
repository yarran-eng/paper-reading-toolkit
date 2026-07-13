# 📄 Paper Reading Toolkit

> **双引擎 PDF 解析 + 四阶段深度精读 · 为中文研究者量身打造**

一个工具，两种用法：**精确提取 PDF**，或者**像导师一样读懂一篇文献**。

---

## 🎯 你能用它做什么

```
                    ┌──────────────────────────┐
                    │  你有一个 PDF（论文）      │
                    └──────────┬───────────────┘
                               │
               ┌───────────────┴───────────────┐
               ▼                               ▼
    ┌──────────────────┐            ┌──────────────────────┐
    │  用法一：提取 PDF  │            │  用法二：读文献        │
    │                  │            │                      │
    │  双引擎并行解析    │            │  双引擎并行解析        │
    │  逐单元质量融合    │            │  逐单元质量融合        │
    │  → 输出融合精校版  │            │  → 四阶段深度精读      │
    │     Markdown     │            │    最终输出中文结论    │
    └──────────────────┘            └──────────────────────┘
```

| | 用法一：提取 PDF | 用法二：读文献 |
|---|---|---|
| **输入** | PDF 文件 / URL / 目录 | PDF 文件 / URL / 目录 |
| **过程** | 双引擎解析 → 内容对比融合 | 双引擎解析 → 融合 → **四阶段精读** |
| **输出** | 融合精校的 Markdown 文件 | 中文深度分析报告（四阶段递进） |
| **对谁说** | `parse-paper paper.pdf` | `读文献：paper.pdf` |

---

## ⚙️ 双引擎融合解析

不是单一工具，而是两条独立引擎**并行跑**，然后逐段比质量、择优合并。

```
用户 PDF
   │
   ├── 引擎 A：MinerU VLM（云端视觉模型）
   │     擅长：公式 → LaTeX、复杂表格、扫描件 OCR、版面理解
   │     耗时：1～5 分钟
   │
   ├── 引擎 B：智能体 PDF 技能（本地高精度提取）
   │     擅长：文字层精确提取、无损图片导出、表格数值保真
   │     耗时：秒级
   │
   └── 内容对比融合（逐单元质量仲裁）
         每个段落 / 表格 / 公式 / 图表 ——
         比完整性 → 比正确性 → 比结构 → 比保真度
         → 择优选用，逐段标注来源
         → 数值冲突处标记，留待人工核实
```

**关键原则**：不靠静态查表决定"谁更好"——每次都比**实际输出质量**。引擎 A 的 OCR 在某一页翻车了？引擎 B 上。引擎 B 读不懂无边框表格？引擎 A 上。真正的互补。

---

## 📖 四阶段深度精读（仅读文献模式）

如果你选择"读文献"，融合精校后的论文会进入一个严格的四阶段递进流程——像一个导师带你从宏观到微观、从理解到能用。

| 阶段 | 做什么 | 回答的问题 |
|---|---|---|
| **阶段一** | 宏观骨架与全局地图 | 这篇论文在学术版图里什么位置？用了什么方法论？需要哪些前置知识？ |
| **阶段二** | 机制深度理解 | 核心 Trick 是什么？公式为什么这样设计？实验数据说明什么？ |
| **阶段三** | 知识内化与复现路线 | 哪些代码/超参可以直接复用？局限在哪？怎么一步步复现？ |
| **阶段四** | 体系定位与结论 | 画出领域全流程，圈出本文改了什么。旧 → 新 → 为什么更好。哪些实锤，哪些推测。 |

**递进规则**：绝不一次输出全部。每阶段结束后，由你主动输入 `进入阶段N` 推进——节奏由你掌控，每阶段之间可以追问细节。

**输出语言**：全部中文。术语处理：首次出现的关键术语用 **中文加粗**（English），如 **注意力机制**（Attention Mechanism）。

---

## 🚀 安装

```powershell
.\install.ps1 -MineruToken "你的Token"
```

安装器自动完成：
1. 校验 / 设置 `MINERU_TOKEN`（**必需，否则无法使用**）
2. 添加 `parse-paper` 到用户 PATH
3. 安装技能文件到 `~/.agents/skills/`（ZCode / Codex / Claude Code 等通用）
4. 设置 `PAPER_TOOLKIT_ROOT` 环境变量

Token 获取：https://mineru.net/apiManage/token

---

## 📋 使用方式

### 用法一：提取 PDF

```
# 在智能体中
用 MinerU 提取这篇论文：path\to\paper.pdf

# 在命令行中
parse-paper "paper.pdf" -Ocr -Chunk

# 直接调 Python（跨平台）
python MinerU-Skill/scripts/mineru.py "paper.pdf" --output parsed --ocr --chunk --lang ch
```

### 用法二：读文献

```
# 在智能体中（推荐）
读文献：path\to\paper.pdf
读文献：C:\Users\...\paper.pdf
读文献：https://example.com/paper.pdf
```

智能体会自动完成双引擎解析 → 融合 → 输出阶段一。随后交互式推进至阶段四。

---

## 🔑 环境变量

| 变量 | 必须 | 用途 |
|---|---|---|
| `MINERU_TOKEN` | **是** | MinerU Standard API 密钥 |
| `PAPER_TOOLKIT_ROOT` | 推荐 | 工具包根目录（install.ps1 自动设置） |
| `PAPER_TOOLKIT_PYTHON` | 可选 | 指定 Python 解释器路径 |

---

## 📦 组件清单

| 组件 | 用途 |
|---|---|
| `skills/paper-mineru-reader/SKILL.md` | 编排层：双引擎融合 + 四阶段精读入口 |
| `skills/literature-deep-reading/SKILL.md` | 四阶段深度阅读方法论 |
| `MinerU-Skill/scripts/mineru.py` | 核心引擎：零依赖 MinerU CLI（1997 行） |
| `MinerU-Skill/scripts/mineru_mcp.py` | MCP Server（stdio JSON-RPC） |
| `mineru-vlm-mcp.py` | 定制 MCP Server（Standard API 专用，强制 Token） |
| `parse-pdf.ps1` | PowerShell 包装器：Python 发现 + 参数组装 |
| `parse-paper.cmd` | 全局 CLI 入口 |
| `install.ps1` | 一键安装脚本 |

---

## 🌐 兼容性

- **智能体**：ZCode、Codex、Claude Code、Trae Work，以及所有从 `~/.agents/skills/` 读取技能的平台
- **操作系统**：Windows（完整支持 .ps1 / .cmd）、Linux / macOS（Python 脚本直接运行）
- **质量策略**：仅使用 Standard API VLM——免费 Agent API 有意禁用，保证每次解析均为最高精度

---

## 📄 许可

内置 MinerU-Skill 引擎为 MIT 许可（版权 Nebutra）。工具包包装器和技能文件采用相同许可条款。
