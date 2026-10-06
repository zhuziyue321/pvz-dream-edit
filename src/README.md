<!-- AGENT-DOC: pointer -->
# src/ —— 游戏代码与场景

> **[给 AI Agent]** 动手前先看本目录 [AGENTS.md](./AGENTS.md)；仓库文档入口 [../AGENTS.md](../AGENTS.md)，**文档总目录** [../docs/README.md](../docs/README.md)。

516 个 `.gd` + 227 个 `.tscn`，按功能就近放置：同一功能的脚本与场景在同一个目录。

- `core/` 框架层（autoload / consts / utils）、`entities/` 角色与子弹、`levels/` 关卡、`managers/` 管理器、`ui/` 界面、`world/` 世界与相机、`menus/` 主菜单与选关，其余按功能分（`items/` `fx/` `garden/` `store/` `almanac/` `dave/`）。
- 角色 = base 场景 + 若干组件，组件状态本体在组件里，宿主只做转发（见 [../docs/项目规范.md](../docs/项目规范.md)）。
- 关卡里的植物格子 / 僵尸行由数据在运行时生成，**不要在 `.tscn` 里手摆**（详见 [../docs/参考存档/地图实现.md](../docs/参考存档/地图实现.md)）。

**规则与约定不写在这里**，一律在 [docs/](../docs/README.md)。
