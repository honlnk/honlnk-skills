---
name: picsense-usage
description: picsense 本地图片/视频/文档识别 MCP 工具的正确使用方法：4 个工具怎么选、怎么读一篇带图片链接的文章（linkseek 抓来的或用户直接给的都行）——图片 URL 三种形态与修正方法、analyze_document 全文标注的适用场景与混 HTML 误判自救、analyze_images 单图任务性深读、session 多轮迭代、analyze_video 抽帧识别。当可用工具列表中出现 mcp__picsense__* 工具（analyze_images / analyze_document 等，前缀以实际配置为准）且任务涉及识别图片内容、理解文章/文档配图、对比多张图、分析视频内容时使用。Use whenever an image, an illustrated article/document, or a video needs visual understanding and picsense MCP tools are available.
---

# picsense 图片识别工具使用指南

picsense 是本地视觉识别 MCP（stdio）。本技能解决四个问题：工具怎么选、**怎么读一篇带图片链接的文章**（核心场景，第二节）、session 怎么迭代、识别失败或"一张图都没识别"时怎么诊断。第二节的两条防坑（URL 形态、混 HTML 误判）做错任何一条，拿到的就是报错或 `images_analyzed: 0`。

## 一、工具怎么选

| 需求 | 工具 | 说明 |
|---|---|---|
| 回答关于某张/某几张图的问题 | `analyze_images` | 传 URL / 本地路径 / base64，prompt 由你按任务写 |
| 通览一整篇文档的所有配图 | `analyze_document` | 传文档（URL / HTML / markdown），返回每张图后插描述注释的全文 |
| 分析视频内容 | `analyze_video` | 默认每秒抽 1 帧、最多 30 帧（约前 30 秒） |
| 查历史识别会话 | `list_sessions` | session_id 忘了/丢了时查 |

选择逻辑（三分法）：

- **要针对图片回答问题**（"这个架构图设计合理吗""这两张截图差在哪"）→ `analyze_images` + 任务性 prompt
- **要通览全文配图**（"这篇文章里的图都在讲什么"）→ `analyze_document`
- 两者常组合：先 `analyze_document` 速览全文，再挑值得深挖的图走 `analyze_images`

## 二、核心场景：读一篇带图片链接的文章

典型请求："分析这篇文章里的架构图"。文章来源两路——linkseek 抓的、用户直接给的——处理流程相同，共四步。

### 第 1 步：拿到正文

- linkseek 已配置：`web_fetch` 抓正文（SPA / 懒加载严重的站换 `web_fetch_render`）。返回的 markdown **保留配图**，形态为 `![alt](src)`
- 不要依赖 `web_search_and_fetch` 读长文配图：它每页只取正文前 8000 字符，长文后部的图会被截掉；要全文配图就单独 `web_fetch`
- linkseek 未配置：`analyze_document` 也接受文章 URL 自己抓，但它不带浏览器 UA、不渲染 JS，SPA / 反爬页面基本失败——能用 linkseek 就先 linkseek
- 用户直接给文章内容：markdown / HTML 文本直接进第 3 步；本地文件先读出内容再传（`analyze_document` 不接受文件路径）；给的是一组图片文件就逐张或批量走 `analyze_images`

### 第 2 步：修正图片 URL（高频坑，实测 2026-10-01）

正文里图片 URL 常见三种形态，**只有第一种能直接用**：

| 形态 | 例子 | 处理 |
|---|---|---|
| 绝对 URL ✅ | `https://cdn.example.com/a.png` | 直接用 |
| 协议相对 | `//thumb.example.com/a.png` | 前面补 `https:` |
| 站内相对 | `/img/a.png`、`./img/a.png` | 用文章地址拼成绝对 URL |

原因：picsense 只把 `https?://` 开头的字符串当 URL，其余一律按**本地文件路径**解析（必然找不到，报 `识别失败: Image file not found or unreadable`）。注意从正文提取 URL 时图常被链接包裹成 `[![alt](图URL)](跳转页URL)`，取内层。

### 第 3 步：按任务选读法

**读法 A —— `analyze_document` 全文标注**（适合"这篇文章的图都在讲什么"）：

- 把正文（内容字符串或 URL）传给 `analyze_document`，返回完整文档，每张图后插一条 `<!-- image-vision: 描述 -->`
- 识别提示词是**固定的通用描述**，不能自定义——要按任务分析（评估/对比/找问题）必须用读法 B
- 逐张串行识别，每张一次视觉模型调用，图多时明显变慢；描述只有一两句，适合速览定位

**读法 B —— `analyze_images` 单图/选图深读**（适合"分析这张架构图是否合理"）：

1. 从正文找到目标图的 URL，按第 2 步修正形态
2. `analyze_images` 传 URL 数组 + 按任务写的 prompt（把用户的问题翻译成对图片的指令）
3. 需要追问时传返回的 `session_id` 继续问，不必重传图片（见第三节）

原型示例（2026-10-01 实测走通）：用户"分析这篇文章里的架构图" → `web_fetch` 拿正文 → 图 URL 为 `//thumb.wikimedia.org/...` 补 `https:` → `analyze_images` 问"组件角色 / 连接关系 / 表达优缺点" → 得到结构化分析 → 传 `session_id` 追问"几个 Server 几个 Client"得到精确回答。

### 第 4 步（读了法 A 后必做）：核对 images_analyzed

`analyze_document` 对输入做自动识别：**内容里只要混有任何 HTML 标签**（Wikipedia 信息框表格、技术文代码块里的 `<div>` 等），整篇就按 HTML 处理——markdown 语法的 `![]()` 图片一张都提取不到。更隐蔽的是识别失败**不报错**：失败的图只插 `[识别失败: ...]` 占位注释、不计入计数（实测：混 HTML 的 Wikipedia 正文返回 `images_analyzed: 0`，全程无报错）。

所以拿到结果先核对：`images_analyzed` 是否等于正文里可见的图片数（`![` 与 `<img` 出现次数之和）。为 0 或明显偏少时自救：自己从正文提取图片 URL → 按第 2 步修正 → 传给 `analyze_images`（多张可一次批量传入，prompt 说明每张要什么）。

## 三、analyze_images 与 session

- `image_sources` 每项自动识别：`https?://` URL / 本地文件路径 / base64
- URL 是**直传给视觉模型**，picsense 不下载：本地文件和 base64 才校验 5MB 与 jpg/jpeg/png；URL 的大小格式由模型 API 侧把关。**直传可能被模型侧网关拒绝**——防盗链（模型侧 403）或网关不代抓某些图床域名（实测 2026-10-01：upload.wikimedia.org 被 vibebabo 网关拒绝）。出现这类拒绝**不要反复换 URL 变体重试**（换缩略图尺寸等大概率仍被拒），直接走兜底：curl 带 UA 和 Referer 下载到本地，改传文件路径（实测有效；注意 Wikimedia 缩略图服务对小于目标宽度的原图会返回错误页，拿不准就直接下原图）
- session 多轮：首次调用返回 `session_id`；之后只传 `session_id` + prompt 续问。**后续轮不能再追加新图**（传了 `image_sources` 也被忽略），多图必须在首轮一次传齐
- session 有效期 24 小时、纯内存态（MCP 进程重启全部丢失）；报 `Session not found` 就是过期或重启了，重新首发即可
- 批量/对比：`image_sources` 数组一次传多张，prompt 里说明任务（如"对比第一张和第二张的差异"）

## 四、analyze_video 简述

- `video_source`：URL（服务端下载，120 秒超时）或本地路径（≤100MB，mp4/mov/m4v 等常见格式）
- 默认每秒抽 1 帧、最多 30 帧——**只覆盖约前 30 秒**；更长的内容要么明确告知用户此限制，要么分段处理
- 同样支持 `session_id` 追问（不重复抽帧）

## 五、已知边界（源码核对 + 2026-10-01 实测）

- markdown 混 HTML 的输入误判 → markdown 图提取不到且不报错（见第二节第 4 步）
- 协议相对 / 站内相对图片 URL 必坏，必须先修正（见第二节第 2 步）
- `analyze_document` 自带抓取不带 UA、不渲染 JS——网页永远优先 linkseek 抓、传内容字符串
- 单张图识别失败不中断整篇标注，只插占位注释且不计入 `images_analyzed`
- 提取不到的图：CSS 背景图、`srcset`、og:image；纯 `data-src` 懒加载图在 linkseek 抓取阶段就已丢失
- 图片格式 jpg/jpeg/png（本地/base64 强校验；URL 直传不受此限）；视觉模型调用对 429/5xx 自动重试（最多 3 次）
- 本技能创建于 2026-10-01，基于 picsense 0.2.1 源码与实测编写；行为可能随版本漂移，遇到不符先怀疑版本变化
