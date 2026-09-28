# honlnk-skills

个人生产力 Skills 合集——honlnk 生态的**第三层：编排知识层**。

MCP 工具描述受限于篇幅，只能说明单个工具「做什么」，装不下「多个工具如何协作」「什么场景该组合」这类知识。本仓库用 Agent Skills 承载这些编排知识：由 Agent 在运行时按任务自动加载，用户不需要手写协作规则。

## 三层模型

```text
┌─────────────────────────────────────────────┐
│ 第三层：编排知识（honlnk-skills，本仓库）      │
│   skill：跨 MCP 编排 / 开发规范 / 工作方法     │
├─────────────────────────────────────────────┤
│ 第二层：原子能力（MCP，互相零耦合）            │
│   linkseek  云端·联网搜索/网页获取/深度研究    │
│   picsense 本地·图片/视频/文档识别            │
├─────────────────────────────────────────────┤
│ 第一层：用户定制（AGENTS.md / CLAUDE.md）      │
└─────────────────────────────────────────────┘
```

- **MCP 提供原子能力，Skills 提供组合范式**：skill 引用工具但不依赖——缺某个 MCP 时该 MCP 照样独立工作，skill 会引导用户去配置
- **渐进披露**：未触发的 skill 只占 name + description 的几十个 token，装很多也不拖累上下文

## 仓库结构

「一个仓库，多个独立 skill」——粗粒度安装，细粒度加载：

```text
honlnk-skills/
├── README.md          # 本文件：合集总览 + 安装说明
├── install.sh         # 安装脚本（symlink 到技能目录）
├── LICENSE
└── skills/            # 每个 skill 一个目录
    └── <skill-name>/
        ├── SKILL.md   # frontmatter(name+description) + 正文
        └── ...        # references/ scripts/ 等按需加载资源
```

## 安装

以 ZCode（用户级技能目录 `~/.agents/skills/`）为例：

```bash
git clone https://github.com/honlnk/honlnk-skills.git
cd honlnk-skills
./install.sh
```

`install.sh` 会把 `skills/` 下每个技能以 **symlink** 接入 `~/.agents/skills/<skill-name>`：

- ZCode 对用户级技能根只扫描一层，但会跟随 symlink（已按源码核实），因此仓库内的 `skills/<name>/` 结构可以原样接入
- 幂等：重复执行安全；目标位置已存在非本仓库内容时默认拒绝，`--force` 才会备份替换
- 卸载：删除 `~/.agents/skills/<skill-name>` 下的对应 symlink 即可

其他 Agent（Claude Code 等）：把 `skills/<name>` 链接或复制到对应技能目录即可，`SKILL.md` 遵循通用 frontmatter 规范（`name` + `description`）。

## 收录状态

| 技能 | 说明 | 状态 |
|---|---|---|
| [`linkseek-usage`](./skills/linkseek-usage/) | linkseek 搜索/抓取 MCP 的使用学说：工具选型三分法（简单同步 / 中等脱手 / 复杂自主多轮）、查询写法、参数手册、空结果诊断应对、异步任务用法（defer / web_research / get_result）、自主实验与技能进化机制 | ✅ 已收录 |

规划中的方向：

- `mcp-orchestration`：linkseek × picsense 跨工具编排（联网搜索 + 视觉识别的协作范式）
- `dev-standards` / `dev-techniques`：开发规范与经验沉淀
- 更多个人工作流

## License

[MIT](./LICENSE)
