<!-- AGENT-DOC: human -->
# 🌱 PVZ-Dream-Edit

> **[给 AI Agent]** 本仓库的文档面向 Agent 编写：**动手前请先读 [AGENTS.md](./AGENTS.md)** —— 它是唯一入口，含「按任务路由的文档表」与「硬约束速查」。全部文档地图见 **[docs/README.md](./docs/README.md)**。

用 **Godot 4.6 / GDScript** 复刻原版《植物大战僵尸》的学习 / 同人改版基座。

> 本项目基于上游开源项目 **[hsk-dream/PVZ-Godot-Dream](https://github.com/hsk-dream/PVZ-Godot-Dream)**（作者 hsk-dream）二次开发而来，并沿用其非商用许可。**在此向前辈致谢。**
>
> 本仓库地址：<https://github.com/zhuziyue321/pvz-dream-edit>

---

## 📌 项目定位

| | |
| --- | --- |
| **上游基座** | [PVZ-Godot-Dream](https://github.com/hsk-dream/PVZ-Godot-Dream) —— 提供最初的工程骨架、玩法移植与社区基础 |
| **本仓库** | 在上游之上继续做两件事：**① 玩法对齐原版**（数值 / 出怪 / 行为逐项对照原版 C++ 源码）；**② 工程化改造**（组件化、注册表、模组框架、自动化回归、面向 AI Agent 的文档体系） |
| **一句话** | 「能跑起来的原版复刻 + 一套让 Agent 能自己改、自己验的工程底座」 |

欢迎在本项目基础上做属于自己的 PVZ 同人改版。有兴趣交流可加上游社区 QQ 群：**1046565016**。

---

## ⚠️ 版权与素材说明（重要）

> ⚠️ **本仓库的 `pak/` 目录存放的是从原版《植物大战僵尸》（PopCap Games / Electronic Arts）安装包里解包得到的原始游戏素材**（图片、音频、reanim 动画、粒子等），**并且是入库的**（`git ls-files pak` = 5919 个文件，2026-10-24 实测）。
>
> - 这些素材的版权归 **PopCap / EA** 所有，**不属于本项目的开源许可范围**。
> - 请勿随仓库**二次分发** `pak/` 目录，也不要将其用于任何商业用途；仅限个人学习、研究与本地运行。
> - 本项目的 Custom Non-Commercial License 只覆盖**代码与原创 / 替换素材**（`assets_custom/`），不涵盖 `pak/` 中的原版素材。
> - **上游仓库为规避版权已移除了原版素材**；本仓库为了「克隆下来就能直接跑」才保留 `pak/`，这一点请知悉。

| 目录 | 内容 | 许可 |
| --- | --- | --- |
| `pak/` | 原版素材：2437 张 `.png` + 171 个 `.ogg` + 146 段 `.reanim` 等（5919 个文件） | ❌ 版权归 PopCap / EA，**不随本项目授权** |
| `assets_custom/` | 本项目自制 / AI 生成的替换素材（100 `.png` + 12 `.mp3` + 5 `.ogg` + 1 `.otf`） | ✅ 随本项目非商用许可 |

---

## 🚀 当前版本简述

### 引擎与规模

| 项 | 值 |
| --- | --- |
| 引擎 / 渲染 | Godot 4.6 / GDScript，`gl_compatibility`，视口 800×600（口径 = `project.godot` 的 `config/features`） |
| 主场景 | `res://src/main/main_game_base.tscn`（**只有一份**，关卡内容全部运行时装配） |
| 规模 | `src/` **709** 个 `.gd` + **247** 个 `.tscn`；`data/` **125** 个 `.tres`；`animation/` **533** 个 `.tres` + **15** 个 `.res`；`docs/` **299** 份 `.md`；`test/` **165** 个 `.gd`（`scenarios/` 下 **157** 个探针场景） |

> 口径 = `git ls-files`，2026-10-24 实测。

### 已实装的原版内容

冒险模式 **1-1 ~ 5-10**（5-10 为僵王博士 Dr. Zomboss：出兵 / 踩踏 / 扔房车 / 空投蹦极 / 冰火球 / 低头受击窗口）、迷你游戏、解谜、生存四类模式，**共 108 个内置关卡脚本**；地图、格子、僵尸行、波次、卡槽 / 传送带、关卡进度条、场景设置（底图 / BGM / 昼夜）均可配置。

### 相对原版**新增的玩法逻辑**

- **二周目 / 多周目**：通关 5-10 → 周目 +1 → 冒险进度回到 1-1，而植物 / 金币 / 商店 / 图鉴 / 花园**全部保留**（经典 New Game+）；二周目起每关换用自己的一套关卡脚本（普通关多 10 波、开局锁定前 3 个随机卡槽、1-1 ~ 1-3 直接给满 5 行草皮），周目数无上限。
- **衍生玩法**：**僵尸迷阵**（含旋风）、**僵尸水族馆**（图鉴 / 收藏向）等原版没有或未完整实现的玩法。
- **禅境花园 + 智慧树**：挑战树、树肥料；**商店**可买僵尸 / 奖杯 / 投脑子；**图鉴**（植物 / 僵尸 / 水族馆）；**墓碑**机制。
- **关卡系统 = 数据 + 脚本 + 时间轴**：`ResourceLevelData`（数据）+ `LevelScriptBase`（流程 DSL + 可重写钩子）+ **关卡时间轴**（事件序列）；玩家自制关卡从 `user://custom_level/` 加载，也可由模组注入。
- **运行期扩展**：**僵尸热注册**（一个本体 + 一个脚本即可在运行期加一只僵尸）与**运行期植物**（模组 / 关卡脚本 / 控制台都能注入），防具、行为脚本都能现场拼装。
- **统一伤害系统**：`DamageSystem` 单例集中结算，伤害类型 / 减免 / 无敌可扩展（防御力、法术抗性等玩法都建在这一层上）。
- **联机 / 多人**：ENet 连线 + 命令同步的联机模组；多人对战目前**只做了界面**，对局逻辑待补。
- **新手教程 / 选关解锁 / 关卡进度条**：教学流程、按进度解锁下一关、各类关卡的进度条口径（血月、传送带等）。

### 相对原版**新增的工程框架**

- **数据驱动 + 组件化**：地图 / 格子 / 僵尸行 / 波次全部由 `ResourceMapData` + `ResourceLevelData` 在运行时装配；**角色 = base 场景 + 若干 `ComponentNormBase` 组件**，状态本体在组件里，宿主只做转发。
- **注册表唯一入口**：`CharacterRegistry` / `BulletRegistry` / `MainSceneRegistry` / `LevelRegistry` —— 类型映射只有一处；新增单位 = 一个场景 + 一行登记，并支持**运行期热注册**。
- **11 个 autoload 单例**：`Log` `Global` `SoundManager` `SceneRegistry` `AllCards` `GlobalUtils` `EventBus` `DamageSystem` `TreePauseManager` `ModManager` `DebugChannel`。
- **模组框架**：`ModManager` + `ModBase` + 契约（`ModIds` / `ModConfig` / `ModCategory`），双加载源（`user://mods/` 优先、`mods_builtin/` 兜底）、多标签分类、依赖声明、模组设置页。内置十余个模组（手套、锤子、自制关卡、联机、DLC 植物与新地图、PVZ2 角色与 PAM 播放器、生态版、招笑版、明日方舟数值、调试模式等），**默认全关＝纯原版体验**。
- **自动化验证链**：编译门禁 `test/check_scripts.ps1`（秒级）+ **157 个 autopilot 探针场景**（`test/run_all_scenarios.ps1` 批量跑批，失败非 0 退出）+ 云端 CI；游戏内还有 **Ctrl+Q 调试窗口**（7 页）、内置控制台、`EventBus` 事件追踪、僵尸卡片调试页。
- **素材管线**：reanim → Godot 动画（`R2Ga_PVZ`，已移出仓库，需时从[上游](https://github.com/hsk-dream/PVZ_reanim2godot_animation)取回）、**PAM（PVZ2 PopAnim）运行时播放器**、自定义 shader（雨 / 雾 / 水面 / 模仿者 / 身体遮罩 / 粒子）。
- **面向 AI Agent 的文档体系**：`docs/` 下 **299** 份 `.md`（顶层规则 + `参考存档/` 机制说明 + `工作记录/` 逐次任务记录），每个代码目录另有 `AGENTS.md` / `README.md` 指针。

---

## 🛠️ 快速开始

1. 准备 **Godot 4.6**（版本口径 = `project.godot` 的 `config/features`）。
2. 克隆仓库 —— `pak/` 与 `assets_custom/` 都在版本控制内，**clone 即得**；首次打开 Godot 需要导入 5900+ 个资源，请等导入跑完。
3. 用 Godot 打开 `project.godot`，直接运行（主场景 `src/main/main_game_base.tscn`）。
4. 改完代码先过**编译门禁**（退出码 0 = 无编译错误）：
   ```powershell
   powershell -ExecutionPolicy Bypass -File test/check_scripts.ps1
   ```
5. 需要跑批回归（串行执行，有 FAIL 非 0 退出）：
   ```powershell
   powershell -ExecutionPolicy Bypass -File test/run_all_scenarios.ps1
   powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_gameplay_core -Windowed   # 单场景带窗口
   ```
6. **玩法类改动仍要开游戏（带窗口）实测** —— 无头跑批只证明「跑得完」，不能替代人工回归。详见 [docs/验证流程.md](./docs/验证流程.md)。

---

## 📁 目录结构

```
Dream/
├── src/           唯一代码根（按功能就近放置）：core 框架层 / entities 实体 / levels 关卡 / managers 管理器 / ui 界面 / mods 模组框架 …
├── data/          数据层（.tres）：地图、种植条件、戴夫对话、存档结构、角色数值表、图鉴 json
├── animation/     动画资源（工具生成，不建议手改）：植物 / 僵尸 / 僵王 / 特效
├── shaders/       自定义 shader：水面、雨、雾、模仿者、身体遮罩、粒子
├── addons/        编辑器插件 9 个（3 自研 + 6 第三方），非运行时业务代码
├── mods_builtin/  内置模组源码（手套 / 锤子 / DLC / PVZ2 / 联机 / 明日方舟 …）
├── pak/           ⚠️ 原版素材（入库，版权归 PopCap / EA，不在授权范围内）
├── assets_custom/ 自制 / AI 生成素材（在授权范围内）
├── test/          自动回归 + AI 调试通道：scenarios/ 157 个探针 + run_autopilot / run_all_scenarios / check_scripts
├── tools/         离线资源加工脚本（Python / PowerShell），不参与运行时
├── docs/          面向 Agent 的文档体系：顶层规则 + 参考存档 + 工作记录
├── AGENTS.md      AI Agent 唯一入口（路由表 + 8 条硬约束）
├── 架构总览.md     项目全景测绘：分层 / 目录 / 注册表 / 运行时链路 / 技术债
└── project.godot  工程文件（`config/features` = 4.6）
```

---

## 📚 文档与开发规范

| 文档 | 什么时候看 |
| --- | --- |
| [AGENTS.md](./AGENTS.md) | **Agent 唯一入口**：按任务路由的文档表 + 8 条硬约束 |
| [架构总览.md](./架构总览.md) | 项目全景测绘：分层、目录、注册表、运行时链路、已知技术债 |
| [docs/README.md](./docs/README.md) | 全仓库文档总目录与维护约定 |
| [docs/项目规范.md](./docs/项目规范.md) | 硬约束正文（写任何 `.gd` 前必读） |
| [docs/验证流程.md](./docs/验证流程.md) | 改完代码怎么验、要不要开游戏、人工回归清单 |
| [docs/AI调试通道.md](./docs/AI调试通道.md) | Agent 自己启动游戏、模拟操作、取回运行期证据 |

---

## 📜 许可协议：Custom Non-Commercial License

本项目为学习作品，仅供个人学习与研究使用，**禁止任何形式的商业用途**，其余条款与 MIT 一致；原作《植物大战僵尸》相关版权归 PopCap Games 及其母公司 Electronic Arts（EA）所有。**[LICENSE](./LICENSE) 沿用上游项目的协议（v1.0，署名 hsk-dream）。**

---

## 🙌 致谢

### 上游项目（本仓库的基座）

- **[PVZ-Godot-Dream](https://github.com/hsk-dream/PVZ-Godot-Dream)** —— 作者 [hsk-dream](https://github.com/hsk-dream)。
  本项目的工程骨架、玩法移植与社区基础都来自它；本仓库是在其之上的二次开发（原版素材、玩法对齐、模组框架、自动化验证链等）。**特别致谢。**

### 原作

- 致敬《植物大战僵尸》原作团队（**PopCap & EA**）—— 本仓库是同人复刻作品，与 PopCap / EA 无隶属关系，也未获得其官方认可。

### 项目贡献

- 植物图鉴初稿整理：[多003\_](https://space.bilibili.com/472181151)
- 宽屏（16:9）的部分素材使用[豆包 AI](https://www.doubao.com/chat)生成，感谢 AI

### 参考项目与工具

- 樱桃炸弹爆炸动画粒子特效：[HYTommm](https://space.bilibili.com/3493140163988287) 开源项目 [Godot-PVZ](https://github.com/HYTommm/Godot-PVZ)
- 信号总线、随机选择器：[玩物不丧志的老李](https://space.bilibili.com/8618918) 开源项目 [godot_core_system](https://github.com/LiGameAcademy/godot_core_system)
- 种子雨雨幕：[简单的小雨氛围：shader 写的雾、粒子做的雨和水花 | godot4 教程](https://www.bilibili.com/video/BV15ibAz4EZi)
- reanim → Godot 动画转换工具 [PVZ_reanim2godot_animation](https://github.com/hsk-dream/PVZ_reanim2godot_animation)（HYTomZ + hsk-dream，已从本仓库移出，需要时从上游取回）
- 行为 / 数值对照用的原版 C++ 参照工程：`PvZ-Portable`（C++ 跨平台复刻，玩法接近 100% 还原，主参照）与 `re-plants-vs-zombies`（反编译 + 引擎现代化，交叉验证）—— 行号与常量口径见 [docs/参考存档/植物僵尸逻辑对照.md](./docs/参考存档/植物僵尸逻辑对照.md)
