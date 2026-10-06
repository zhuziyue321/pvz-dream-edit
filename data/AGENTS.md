<!-- AGENT-DOC: pointer -->
# AGENTS.md —— `data/` 目录指针

> **[面向 AI Agent]** ｜ **触发条件**：进入 / 新建 / 改动 `data/` 下任何 `.tres` 或资源脚本之前
> **读完你能**：知道本目录装什么、改资源前该先读哪份文档
> **强制级别**：**参考**（纯指针） ｜ **不读的风险**：不知道 `docs/` 里有必读规范，改坏关卡数据 / 引用路径
> **关联**：仓库唯一入口 [../AGENTS.md](../AGENTS.md) ｜ **文档总目录** [../docs/README.md](../docs/README.md) ｜ 必读规范 [../docs/项目规范.md](../docs/项目规范.md)

本文件**只做指针**：规则正文一律在 `docs/`。

## 动手前必读

| 顺序 | 文档 | 什么时候 |
|----|----|----|
| 1 | [../AGENTS.md](../AGENTS.md) | 任何改动之前（任务路由表 + 8 条硬约束速查） |
| 2 | [../docs/项目规范.md](../docs/项目规范.md) | 新增 / 改资源（§1-5：`res://` 绝对路径、移动要带 `.uid`） |
| 3 | [../docs/参考存档/关卡数据与出怪表.md](../docs/参考存档/关卡数据与出怪表.md) | 改关卡数据 / 出怪表（含数据来源口径） |
| 4 | [../docs/AI查wiki避坑.md](../docs/参考存档/AI查wiki避坑.md) | 从 wiki 取数值写进资源之前 |
| 5 | [../docs/README.md](../docs/README.md) | 找不到某份文档时（**全仓库文档总目录**） |

## 本目录是什么

数据驱动的资源层（113 个 `.tres` + 15 个资源脚本）。**玩法数值主要改资源，不改代码。**

| 子目录 | 内容 |
|------|------|
| `character/` | 角色属性资源：`plant_condition/` 种植条件（`.tres` + 其 `.gd` 同置）、`body_change/` 换装 |
| `map/` | 地图（格子 / 僵尸行）数据 `ResourceMapData` |
| `dave/` | 疯狂戴夫对话（`dialog/` 剧本 + `dialog_detail/` 台词） |
| `levels/` | 玩家自制关卡参数（`params/`） |
| `tutorial/` | 新手教程步骤数据 |
| `save/` | 存档数据结构 |
| `ui/` | UI 主题与卡片背景等 |
| `almanac/` `strings/` | 图鉴数据、文案表 |

> 关卡（内置）不在本目录，见 [../src/levels/AGENTS.md](../src/levels/AGENTS.md)。

> 批量改名 / 移动资源**必须先关闭 Godot 编辑器**（否则 `.uid` 与引用会错乱）—— 见 [../docs/项目规范.md](../docs/项目规范.md) §1-5。
