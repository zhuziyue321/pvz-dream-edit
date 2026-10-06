<!-- AGENT-DOC: pointer -->
# AGENTS.md —— `src/levels/` 目录指针

> **[面向 AI Agent]** ｜ **触发条件**：进入 / 新建 / 改动 `src/levels/` 下任何关卡脚本（`.gd`）或关卡资源之前
> **读完你能**：知道本目录装什么、改关卡前该先读哪份文档、关卡路径从哪拿
> **强制级别**：**参考**（纯指针） ｜ **不读的风险**：不知道 `docs/` 里有必读规范，改坏关卡数据 / 引用路径
> **关联**：仓库唯一入口 [../AGENTS.md](../../AGENTS.md) ｜ **文档总目录** [../docs/README.md](../../docs/README.md) ｜ 必读规范 [../docs/项目规范.md](../../docs/项目规范.md)

本文件**只做指针**：规则正文一律在 `docs/`。

## 动手前必读

| 顺序 | 文档 | 什么时候 |
|----|----|----|
| 1 | [../AGENTS.md](../../AGENTS.md) | 任何改动之前（任务路由表 + 8 条硬约束速查） |
| 2 | [../docs/项目规范.md](../../docs/项目规范.md) | 新增 / 改关卡（§1-5：`res://` 绝对路径、移动要带 `.uid`；**§1-8：一关专属机制留在关卡脚本，不进本体**） |
| 3 | [../docs/参考存档/关卡格式V2.md](../../docs/参考存档/关卡格式V2.md) | 改关卡资源字段 / 加新玩法（参考） |
| 4 | [../docs/参考存档/关卡时间轴.md](../../docs/参考存档/关卡时间轴.md) | 改开场流程 / 波次与对话顺序（参考） |
| 5 | [../docs/参考存档/关卡数据与出怪表.md](../../docs/参考存档/关卡数据与出怪表.md) | 改出怪表 / 关卡数值（参考） |

## 本目录是什么

内置关卡目录，**根目录 `res://src/levels/`**（2026-10-03 从 `res://data/level_date_resource/` 移出并改名）。

| 子目录 | 内容 |
|------|------|
| `mode_adventure/` | 冒险模式关卡（目录名即模式，注册表靠目录认模式） |
| `mode_minigame/` | 小游戏关卡 |
| `mode_puzzle/` | 解谜关卡 |
| `mode_survival/` | 生存关卡 |
| `core/` | 关卡脚本基类与工具（2026-10-03 从 `script/` 改名）：`level_data.gd` `level_script_base.gd`（流程方法也长在这上面）`level_registry.gd`（关卡 id ↔ 路径注册表）`level_timeline_data.gd` `level_timeline_event.gd`；**不是关卡**，`LevelRegistry._scan_dir()` 会跳过本目录（旧名 `script/` 同样跳过） |
| `core/timeline_event/` | 时间轴事件脚本 |
| `core/zomboss/` | 僵王关（2 关）共用：**进度条数据源** `zomboss_progress_provider.gd`（僵王战把关卡进度条换成血量百分比，见 [关卡进度条.md](../../docs/参考存档/关卡进度条.md)） |
| `core/beghouled/` | 僵尸迷阵（05 / 09 两关）**共用**的三消代码：`beghouled_manager.gd` `beghouled_ui.gd` `const_beghouled.gd` |
| `core/hammer_zombie/` | 锤僵尸玩法（冒险 2-5 / 迷你游戏 15 两关）**共用**的玩法规则：`level_rule_hammer_zombie.gd` |

> `mode_*/` 下除关卡本体 `<关卡>.gd` 外，还可能有**只服务这一关**的脚本（文件名带该关前缀），
> 如 `mode_minigame/minigame_03_slot_machine_ui.gd`、`minigame_07_seeing_stars_cell_star_overlay.gd/.tscn`、
> `minigame_09_beghouled_twist_manager.gd`、`mode_adventure/adventure_05_05_bungi_blitz.gd`。

## 五条硬约定

- **一关专属机制写在关卡脚本里，不进游戏本体**：只有这一关（或极少数关）用到的特殊机制**必须**写在本目录 `mode_*/<关卡>.gd`（继承 `LevelScriptBase`）里 —— 属性 `_init()`、流程 `run_flow()`、专属物品与格子限制 `init_level_items()`；被 ≥2~3 关复用时才上浮成通用字段 / 组件 / 规则（硬约束 §1-8；细则见 [规范细则存档 D-07](../../docs/参考存档/规范细则存档.md#d-07-关卡脚本-vs-游戏本体一次性机制的落位)）。
- **一关不止一个脚本时，辅助脚本跟着关卡本体走**：只服务这一关的脚本（场景节点 / 绘制层 / UI / 进度条数据源）**必须**与本体的 `<关卡>.gd` 放**同一个 `mode_*/` 目录**，且**文件名以关卡文件名为前缀**（`minigame_07_seeing_stars.gd` → `minigame_07_seeing_stars_progress_provider.gd`）（硬约束 §1-8；细则见 [D-07](../../docs/参考存档/规范细则存档.md#d-07-关卡脚本-vs-游戏本体一次性机制的落位)）。
- **关卡的识别走白名单，不看文件名**：`LevelRegistry` 只在脚本继承链上出现 `LevelScriptBase` / `ResourceLevelData` 时才登记成关卡（`LEVEL_BASE_CLASS_NAMES` / `is_level_script()`），带前缀的辅助脚本不会被误登记（见 [关卡格式V2.md §3.4](../../docs/参考存档/关卡格式V2.md#34-关卡注册表-levelregistryp0-已落地)）。
- **被 ≥2 关共用的关卡侧代码进 `core/<玩法>/`**：不再属于「某一关专属」时**不**硬套关卡名前缀，按玩法分子目录放进 `core/`（先例 `core/zomboss/`，现有 `core/beghouled/`、`core/hammer_zombie/`）；只有 1 关用的时候才按上一条进 `mode_*/`（硬约束 §1-8；细则见 [D-07](../../docs/参考存档/规范细则存档.md#d-07-关卡脚本-vs-游戏本体一次性机制的落位)）。
- **关卡路径不要硬编码**：一律走 `LevelRegistry`（`src/levels/core/level_registry.gd`，`LEVEL_DIR = "res://src/levels"`），业务代码不散落 `res://` 关卡路径（硬约束 §1-4）。
- **关卡 id = 文件名 basename**，与玩家自制关卡（`data/levels/params/`）共用一套 id 规则。

> 批量改名 / 移动**必须先关闭 Godot 编辑器**（否则 `.uid` 与引用会错乱）—— 见 [../docs/项目规范.md](../../docs/项目规范.md) §1-5。
