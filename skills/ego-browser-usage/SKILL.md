---
name: ego-browser-usage
description: Ego Lite（ego-browser）AI 浏览器的实战经验层：与官方 ego-browser skill 的关系、工具使用边界、taskSpace 生命周期与 SPA 空快照等已踩过的坑、站点实测经验索引（BOSS 直聘等，含批量抓取方案）。当 ego-browser 命令可用、用户提到 Ego 浏览器，或需要浏览器自动化（开网页、读页面、填表、截图、操作求职网站）时使用；操作 BOSS 直聘时必读本技能的站点经验。BOSS 的浏览、搜索、JD 抓取与投递统一使用 Ego，不再使用 Chrome 或独立抓取器。
---

# Ego Lite 浏览器实战经验

Ego Lite 是专为 AI Agent 设计的 Chromium 浏览器。本技能是**经验层**，与官方 `ego-browser` skill（API 手册层）配套使用：

1. 官方 skill 规定：每次浏览器任务前先跑 `ego-browser skill` 读当前版本的 API 指南——照做，版本升级后 API 会变。
2. 本技能沉淀官方手册里没有的东西：工具选型、已踩过的坑、站点实测结论。冲突时**以官方指南为准**（它是版本匹配的），再回来更新本技能。

## 一、工具使用边界

BOSS 的浏览、搜索、JD 抓取、投递沟通**统一使用 Ego**；不再使用 Chrome 电脑操作、boss-zhipin-scraper 或其它独立抓取器（2026-11-17 起）。仅以下情况用其它工具：

| 场景 | 用什么 | 说明 |
|---|---|---|
| 网页自动化（开页、搜索、读正文、填表、截图、投递交互） | **ego-browser** | 语义快照 + 元素 ref + 页内 JS，一次脚本批量动作 |
| 桌面应用（非浏览器）或 Ego 服务不可用 | **computer-use** | OS 级无障碍树，适合原生 UI；不用于网页操作 |
| ZCode 内置浏览器 IAB | 仅兜底 | 能力弱于 Ego（无 file chooser、无 CDP），Ego 不可用时才用 |

判断口诀：**网页全用 Ego，桌面应用用 computer-use。**

## 二、通用实战经验

### taskSpace 生命周期

- 一个用户目标只用一个 taskSpace，用语义化中文名（如 `"只读验证 Ego Lite 操作 BOSS"`），后续轮次 `taskSpace(name)` 恢复，不要为恢复卡住的页面开新 space（官方指南明令禁止）。
- 每轮 `ego-browser nodejs` 都是独立进程：变量不保留，但 space / page 标签（`p1`…）保留。
- 任务收尾 `await task.finish({ keep: [] })`，且与最后一轮页面操作分开执行；卡在等用户操作时用 `handOff()` 而不是 finish。

### SPA 空快照（2026-11-12 BOSS 实测）

`goto()` 返回后立刻 `snapshot()` 拿到空树 ≠ 页面坏了，常见原因：

1. **重定向未完成**：BOSS `/web/geek/job`（单数）会 302 到 `/web/geek/jobs`（复数），首拍常为空。
2. **SPA 渲染慢**：快照只拍当下，不等待稳定。

正确姿势：goto 后等**业务元素**就绪，不要只等 `body.innerText` 长度——骨架屏阶段导航文字就有 500+ 字符，长度判据会误判（2026-11-17 实测：body 已有 578 字符时列表还是 canvas 骨架）。例如 BOSS 列表等 `document.querySelectorAll('a[href*="/job_detail/"]').length >= 3`。诊断时 `document.body.innerText.slice(0, 300)` 比 screenshot 便宜。同理，等待结果优先用 `waitForURL` / `waitForSelector` / `waitForFunction`，不用固定 sleep。

### 其它要点

- **登录态来源**：Ego 可导入已有浏览器的 profile（`ego-browser import`，支持 Chrome/Edge/Brave 等）。实测 BOSS 等站点直接是登录态——操作时注意别误触外发按钮，也别假设它是全新无痕环境。
- 快照（语义）与截图（视觉）默认二选一；canvas / 快照读不到时才截图，不传 path 会写入临时目录并返回路径，可直接用 Read 查看。
- 升级（`ego-browser upgrade`）后：重跑 `ego-browser skill`；官方 learnings 目录在版本目录内，手工写入的站点经验可能被换版本清掉——**本技能仓库才是经验的主副本**，丢失后从这里重新同步（见第四节）。

## 三、站点经验索引

| 站点 | 经验文件 | 实测日期 |
|---|---|---|
| BOSS 直聘（zhipin.com） | [references/boss-zhipin.md](references/boss-zhipin.md)（含批量抓取方案） | 2026-11-12 初测 / 11-17 复测 |

操作对应站点前先读经验文件；没有的站点，首次实测后把结论沉淀成新的 references 文件并登记到上表。

## 四、ego 官方 learnings 机制的现状（2026-11-12 实测）

Ego 自带站点经验机制：`learnings/<站点>/manifest.json + notes/*.md`，官方示例有 github / google / x-com 三个站点。但**本机无法使用它沉淀自己的经验**，两个实测结论：

1. learnings 实际位于 `ego lite.app` 应用包内的版本目录（`active_version_dir` 符号链接指向那里），macOS 应用包保护拒绝写入（`Operation not permitted`）。
2. 即使写入成功，`ego-browser upgrade` 切换版本目录后也会丢失。

因此：**本仓库的 references 是站点经验的唯一主副本**，不要往官方 learnings 里写。若未来 ego 提供用户级 learnings 目录（如 `~/.local/share/ego/learnings/`），可把本仓库经验按下面模板同步过去再受益于官方按域名加载：

```json
{
  "id": "boss-zhipin",
  "name": "BOSS直聘",
  "domains": ["zhipin.com", "*.zhipin.com"],
  "notes": ["notes/overview.md"],
  "nodeTools": {},
  "browserTools": {}
}
```
