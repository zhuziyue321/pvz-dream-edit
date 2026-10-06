<!-- AGENT-DOC: pointer -->
# AGENTS.md —— `addons/` 目录指针

> **[面向 AI Agent]** ｜ **触发条件**：要改 `addons/` 下插件、或排查「插件导致的异常」时
> **读完你能**：知道本目录是**第三方 / 编辑器插件**，改动前该先确认什么
> **强制级别**：**参考**（纯指针） ｜ **不读的风险**：把插件代码当业务代码改，升级时冲突、或影响编辑器
> **关联**：仓库唯一入口 [../AGENTS.md](../AGENTS.md) ｜ **文档总目录** [../docs/README.md](../docs/README.md)

本文件**只做指针**：规则正文一律在 `docs/`。

## 动手前必读

| 顺序 | 文档 | 什么时候 |
|----|----|----|
| 1 | [../AGENTS.md](../AGENTS.md) | 任何改动之前（任务路由表 + 8 条硬约束速查） |
| 2 | [../README.md](../README.md) §插件 | 插件来源与已知注意事项（如 `anim_player_refactor` 的中文菜单适配） |
| 3 | [../docs/README.md](../docs/README.md) | 找不到某份文档时（**全仓库文档总目录**） |

## 本目录是什么

第三方与自研的**编辑器插件**，不属于游戏运行时业务代码：

`anim_player_refactor`（动画重构）、`R2Ga_PVZ`（原版动画转换）、`script-ide`、`SignalVisualizer`、`sprite_painter`、`todo_controller`、`DragNDropNodes`、`anim_delete_track` / `anim_free_common_tracks` / `calculate_roration`。

> **不建议**在这里写业务逻辑；确需改插件代码时**建议**在文件头注明「本仓库改动」，便于后续升级对比。
