<!-- AGENT-DOC: pointer -->
# AGENTS.md —— `src/` 目录指针

> **[面向 AI Agent]** ｜ **触发条件**：进入 / 新建 / 改动 `src/` 下任何 `.gd` 或 `.tscn` 之前
> **读完你能**：知道本目录装什么、一个功能的代码与场景放在哪、改之前先读哪份文档
> **强制级别**：**参考**（纯指针） ｜ **不读的风险**：不知道 `docs/` 里有必读规范，手摆节点导致与数据驱动机制冲突
> **关联**：仓库唯一入口 [../AGENTS.md](../AGENTS.md) ｜ **文档总目录** [../docs/README.md](../docs/README.md) ｜ 必读规范 [../docs/项目规范.md](../docs/项目规范.md)

本文件**只做指针**：规则正文一律在 `docs/`。

## 动手前必读

| 顺序 | 文档 | 什么时候 |
|----|----|----|
| 1 | [../AGENTS.md](../AGENTS.md) | 任何改动之前（任务路由表 + 8 条硬约束速查） |
| 2 | [../docs/项目规范.md](../docs/项目规范.md) | 写 / 改脚本、场景与挂载组件（§1 宏观硬约束） |
| 3 | [../docs/参考存档/地图实现.md](../docs/参考存档/地图实现.md) | 改地图 / 植物格子 / 僵尸行（**数据在资源里，不在 `.tscn` 里手摆**） |
| 4 | [../docs/验证流程.md](../docs/验证流程.md) | 交付前判断「要不要打开游戏实测」 |
| 5 | [../docs/README.md](../docs/README.md) | 找不到某份文档时（**全仓库文档总目录**） |

## 本目录是什么

游戏代码与场景的**唯一根目录**：516 个 `.gd` + 227 个 `.tscn`。

采用**按功能就近放置（feature-first）**：同一功能的 `.gd` 与 `.tscn` 放同一个目录，不再分 `scripts/` 与 `scenes/` 两棵平行树。

| 子目录 | 内容 |
|------|------|
| [`core/`](core/) | 框架层：`autoload/` 单例与类型注册表（`character_registry.gd` `bullet_registry.gd` …）、`consts/` 全局枚举与常量、`utils/` 通用工具 |
| [`entities/`](entities/) | 游戏实体：`character/`（base / components / plant / zombie）、`bullet/` |
| [`levels/`](levels/AGENTS.md) | 内置关卡（按 `mode_*` 分目录）+ `core/` 关卡基类与时间轴 |
| [`managers/`](managers/) | 管理器：波次、卡槽、手持物、格子、掉落、时间轴 |
| [`ui/`](ui/) | 界面：卡片 / 卡槽 / 金币 / 关卡内 HUD / 菜单 |
| [`world/`](world/) | 战斗场景世界：`background/` 背景、`camera/` 相机 |
| [`main/`](main/) | 主战斗场景入口 `main_game_base.tscn` |
| [`menus/`](menus/) | 主菜单与选关（`start_menu/` `choose_level/`） |
| `items/` | 场上物件：小推车、耙子、掉落物、墓碑、罐子等 |
| `fx/` | 特效（子弹命中、植物爆炸、其它） |
| `garden/` | 禅境花园 |
| `store/` | 商店 |
| `almanac/` | 图鉴 |
| `dave/` | 疯狂戴夫（含 `hand_item/` 手持物） |

> 改完 `.tscn`（尤其移动 / 重命名）**必须**连 `.uid` 一起处理，并确认 `res://` 引用字符串同步更新 —— 见 [../docs/项目规范.md](../docs/项目规范.md) §1-5。

## 命名约定

- 目录与文件一律 **snake_case**。
- **不再用数字编号前缀**（如 `plant_pea_shooter_single.gd`）：编号是注册表的 id，不是文件名的一部分；语义名才是。
  - 植物 / 僵尸 / 子弹的 id 唯一落在 `CharacterRegistry` / `BulletRegistry`（硬约束 §1-4）。
