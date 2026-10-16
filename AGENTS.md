<!-- AGENT-DOC: index -->
# AGENTS.md —— AI Agent 唯一入口（先读这一份）

> **[给 AI Agent] 本仓库的文档是面向 Agent 写的。**  
> `docs/` 下每一份 md 开头都有「面向 AI Agent」元信息头，写明**什么时候必须读、读完你能做什么、违反会怎样**。  
> 动手前按下面 §2 的路由表取文档，**不要凭猜测改代码**。
>
> 本文只做「路由 + 红线速查」，细节一律在 `docs/`，本文不重复细节。

---

## 1. 项目速览

| 项           | 值                                                                                                                   |
| ----------- | ------------------------------------------------------------------------------------------------------------------- |
| 项目          | 用 Godot 复刻原版《植物大战僵尸》的学习 / 同人改版基座（原版素材因版权已移除）                                                                        |
| 引擎 / 语言     | Godot 4.6 / GDScript（版本口径以 `project.godot` 的 `config/features` 为准）                                                                                              |
| 规模          | `src/` 643 个 `.gd` + 239 个 `.tscn`；`data/` 122 个 `.tres`；`animation/` 497 段动画；`docs/` 225 份 `.md`；11 个 autoload 单例（2026-10-16 实测；**规模数字的唯一权威来源是 [架构总览.md](./架构总览.md) §15**，本条与之不一致时以后者为准）                                                              |
| 架构主线        | 数据驱动 + 组件化：角色 = base 场景 + 若干 `ComponentNormBase` 组件；资源一律 `res://` 绝对路径引用                                            |
| 顶层排布        | `src/`（代码 + 场景，按功能就近放置）、`data/`（`.tres` 数据层）、`animation/`、`shaders/`、`assets/`（图片/音频/字体/reanim，**在版本控制内**：`git ls-files assets` = 5339，2026-10-16 实测）、`test/`、`docs/`、`tools/` |
| autoload 单例 | `Log` `Global` `SoundManager` `SceneRegistry` `AllCards` `GlobalUtils` `EventBus` `DamageSystem` `TreePauseManager` `ModManager` `DebugChannel`（共 11 个，见 `project.godot` 的 `[autoload]`） |
| 验证方式        | **编译门禁必过**：`test/check_scripts.ps1`（硬约束 §1-7）；**打开游戏实测默认不跑（可选）**——完成工作、编译门禁通过后即交付，确有需要时再开，或反馈里附人工验证方法，见 [docs/验证流程.md](./docs/验证流程.md)              |

人类向项目介绍见 [README.md](./README.md)，文档地图见 [docs/README.md](./docs/README.md)。

---

## 2. 按任务路由（先查这张表）

| 你要做的事                                       | 必读文档                                                                                                                                          |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| 刚进仓库，还不知道从哪下手                               | 本文 + [架构总览.md](./架构总览.md)（**项目全景测绘**：分层 / 目录 / 注册表 / 运行时链路）+ [docs/README.md](./docs/README.md)（**全仓库文档总目录**）                                                                                          |
| 已身处某个代码目录（`src/` `data/` `animation/` …）  | **该目录的 `AGENTS.md`**（一眼版指针，见 §6）→ 再回本文取正文                                                                                                 |
| 改某个具体玩法 / 机制（地图 / 子弹 / 植物种植 / 关卡 / 手持物 / 特殊关 / 波次 / 防具 / 联机 / 模组 / 图鉴 / 禅境花园 / 新手教程 / 选关 / 卡片 / 僵尸热注册 / 运行期植物 / 调试窗口 / 控制台 / 墓碑 / 场景设置 / 创建新角色 / 伤害系统 / 关卡时间轴 / 进度条 / 卡槽传送带 / AI查wiki…） | **单一来源**：[docs/参考存档/README.md §1](./docs/参考存档/README.md)（41 份机制文档明细索引）；本表不再逐份列出，新增 / 改一份机制文档只动那一处，无需同步本表 |
| 改完代码要交付                                     | [验证流程.md](./docs/验证流程.md)（先判断要不要验证，要验证就打开游戏）                                                                                                  |
| 需要自己启动游戏、模拟操作、取回运行期证据                       | [AI调试通道.md](./docs/AI调试通道.md)（**打开游戏调试**；无头只做 CI 回归）                                                                                          |
| 同时有多个 agent 改本仓库                            | [Agent协作协议.md](./docs/Agent协作协议.md)（所有权分区 + 编号段配额）                                                                                            |
| 开工前找参考 / 任务收尾                               | [docs/工作记录/](./docs/工作记录/README.md)（收尾**建议**新建一条记录文件；索引由 `tools/gen_worklog_index.ps1` 自动生成，无需补行；开工前查同类任务的最简路径）                                                                    |
| 想知道「仓库通常怎么做」的排版 / 命名习惯                      | [参考意见存档.md](./docs/参考意见存档.md)（**参考，不强制**：排版 / 命名 / 目录习惯等细枝末节条目，不做也不打回）                                                                                |
| 想找「还剩哪些待办」 / 删注释前判断它是不是垃圾                | [TODO清单.md](./docs/TODO清单.md)（**参考**：2 条代码 TODO + 22 条架构债的汇总快照 + 已销项历史）                                                                                               |

> 找不到对应条目时，默认读 [项目规范.md](./docs/项目规范.md) §2 规则目录，再按条目跳到存档看细则。

---

## 3. 硬约束速查（红线，违反即打回）

只有这 8 条，完整表述见 [项目规范.md §1](./docs/项目规范.md)：

1. **架构主线：数据驱动 + 组件化** —— 角色 = base 场景 + 若干 `ComponentNormBase` 组件；状态本体在组件里，宿主只做转发、不复制组件状态。
2. **组件只通过 `owner` / 信号 / 场景配置通信** —— 禁止 `get_parent()` 抓宿主改字段、禁止组件间硬编码绝对路径。
3. **角色与组件的生命周期入口固定** —— **仅** `Character000Base` / `ComponentNormBase` 的子类禁止重写 `_ready()`，改重写角色侧的 `character_ready()` / `ready_norm()` / `ready_show()` / `ready_garden()` / `ready_norm_signal_connect()`、组件侧的 `component_ready()`；UI / 管理器 / 子弹 / 僵王技能等其余类不受此限。
4. **类型映射一律走注册表** —— `CharacterRegistry` / `BulletRegistry` / `MainSceneRegistry`；禁止业务代码散落「类型 ID → 场景 / 脚本」映射表（`preload` 一个具体数据资源不受此限）。
6. **日志一律 `Log.*`** —— 禁止裸 `print()` / `printerr()`。

**应该**（默认遵守，例外写明理由）：跨 Agent 记忆只落在文档里 —— 踩坑与流程结论写进 `docs/`，只写在回复里下一个 Agent 看不到。

> **其余细则均为参考**：命名、目录、组件写法、资源落位、UI 坐标、字典读取、自检清单、踩坑沉淀、流程归档等  
> **不做也不打回**；目录与跳转见 [项目规范.md §2](./docs/项目规范.md)。  
> 排版类参考意见见 [docs/参考意见存档.md](./docs/参考意见存档.md)。

---

## 4. 改代码的标准流程

> 流程动作 + 关键入口；硬约束细节见 §3 与 [项目规范.md §1](./docs/项目规范.md)。

1. **取文档**：按 §2 路由表找对应文档，先过一遍 `项目规范.md §1` 的 8 条硬约束。
2. **写代码**：照 `参考存档` 对应条目的正例；新增单位（植物 / 僵尸 / 子弹）先取空闲编号并登记注册表（硬约束 §1-4）。
3. **判断验证**：按 `验证流程.md §1` 决定要不要开游戏；变动小 → 免验证，但反馈里必须写清人工验证方法（§1.1）。
4. **编译门禁**：交付前必跑 `test/check_scripts.ps1`（`real compile errors = 0`）；值得时再开游戏按 `验证流程.md §3` 逐条回归。
5. **文档同步（按需）**：优先同步**硬约束与机制文档**；其余文档仅在机制 / 数值 / 用法确已变化且文档未覆盖时再补，**漂移不再等同 bug**（详见 §5）。
6. **收尾归档（建议）**：踩坑**建议**按 E-04 写进文档（可选，非必须）；按 E-05 在 `docs/工作记录/` 建 `<日期>_<主题>.md`（弯路 / 踩坑三段式 / 推荐度 / 最简路径）—— 索引由 `tools/gen_worklog_index.ps1` 自动生成，无需补行。照旧记录做 → 可在文末追加「补充 / 评价」（只追加、双向引用、不占新行）。
7. **提交 git**：一个逻辑单元一笔，代码 / 文档 / 跑批产物分开，**别 `git add -A`**（细则 E-09）；提交前过 V-02 自检，留意 `git status` 别带未跟踪临时物（本仓 `pre-commit` 钩子会拦危险文件）。

---

## 5. 文档维护约定（改文档也要守）

- **判层级**：规则 / 方法论 → `docs/` 顶层；机制 / 内容说明 → `docs/参考存档/`；流程流水 → `docs/工作记录/`。新增文档必须带「面向 AI Agent」元信息头（模板见 `docs/README.md §5`）；索引由对应目录 README / 脚本维护，无需手补行。
- **指针只写指针**：§6 那些 AGENTS / README 不复制规范正文；规则变了只改 `docs/` 正文，指针无需同步。新增一级目录补一份并登记一行。
- **硬规范只进 `项目规范.md §1`**：具体细则一律进 `参考存档`（按 E-01 编号），不要新开「规范」文档。
- **三层不混排**：同一件事只在一处写，别在顶层 / 参考存档 / 工作记录之间复制。
- **强制级别**：新细则默认就是参考；把某条移出硬约束时正文搬进参考存档（措辞改「建议 / 不建议」），并**必须**同步摘掉 §1 硬约束表与本文 §3 的强制字样。
- **改名 / 移动文档**：必须全局替换引用（其他 md、`test/`、以及 `src/` 注释里的 `docs/xxx.md`）。
- **玩法类约束兜底**：仓库已无静态检查器；需要自动回归就写 `test/scenarios/probe_*.gd`，用 `run_autopilot.ps1 -Scenario <name> -Windowed` 跑（见 E-02）。

---

## 6. 目录内 README / AGENTS 指针（显眼位置，只做目录不写规则）

> 目的：**任何一个 Agent 在任何目录里都能注意到 `docs/`**。这些文件一律**只做指针**，不复制规范正文（两处写必漂移）。

| 位置 | 文件 | 内容 |
|------|------|------|
| 仓库根 | [AGENTS.md](./AGENTS.md) / [README.md](./README.md) | 唯一入口 / 人类向介绍 |
| `docs/` | [docs/AGENTS.md](./docs/AGENTS.md) | 进 `docs/` 的一眼版入口 → [docs/README.md](./docs/README.md) |
| `src/` | [AGENTS.md](./src/AGENTS.md) / [README.md](./src/README.md) | 全部 `.gd` 与 `.tscn`（按功能就近放置）：动手前必读 + 子目录速查 |
| `data/` | [AGENTS.md](./data/AGENTS.md) / [README.md](./data/README.md) | `.tres` 数据层：数值改这里 |
| `src/levels/` | [AGENTS.md](./src/levels/AGENTS.md) / [README.md](./src/levels/README.md) | 内置关卡（按模式分目录），走 `LevelRegistry` |
| `mods_builtin/` | [README.md](./mods_builtin/README.md) | **内置模组源码**（手套 / 锤子 / 更多防具 / 自制关卡 / 联机）：两个加载源之一 —— `user://mods/` 优先，那里没有这个模组时才从这里加载（两源不互相复制） |
| `src/mods/` | [README.md](./src/mods/README.md) | **模组框架**：只剩 `mod_manager.gd`（autoload，必须在 `res://`）；内置模组本身在 `mods_builtin/` |
| `animation/` | [AGENTS.md](./animation/AGENTS.md) / [README.md](./animation/README.md) | 动画资源（工具生成） |
| `test/` | [AGENTS.md](./test/AGENTS.md) / [README.md](./test/README.md) | 自动回归 / 调试通道入口 |
| `addons/` | [AGENTS.md](./addons/AGENTS.md) / [README.md](./addons/README.md) | 第三方插件，非业务代码 |
| `shaders/` | [AGENTS.md](./shaders/AGENTS.md) / [README.md](./shaders/README.md) | 自定义 shader |
| `src/core/consts/` | [README.md](./src/core/consts/readme.md) | 全局枚举与关卡常量 |
| `docs/工作记录/` | [README.md](./docs/工作记录/README.md) | 逐次任务的流程记录索引 + 模板 |

新增一级目录 → **建议**补一份 `AGENTS.md` + `README.md`，并在 [docs/README.md §3](./docs/README.md) 与本表各登记一行。

---

## 7. 一句话提醒

> **打开游戏（带窗口）才能证明「能玩」**；无头跑批只证明「跑得完」，不能用来排查  
> （[AI调试通道.md](./docs/AI调试通道.md) 第〇节）。  
> 但也别过度验证：**改动较小、确定不会出问题就不用开游戏**。
