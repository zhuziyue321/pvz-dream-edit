<!-- AGENT-DOC: pointer -->
# README.md —— `src/mods/` 目录指针

> 本文件**只做指针**：模组机制的正文在 [../../docs/参考存档/模组机制.md](../../docs/参考存档/模组机制.md)。

## 一句话

**原版之外的玩法做成模组**：本体（`main_game_base.tscn` / 管理器 / 卡槽）不认识任何模组，
关掉模组 = 不装载，场景里不会多出任何节点。开关在 `data/mods/mod_config.tres`。

## 文件

| 文件 | 作用 |
|---|---|
| `mod_manager.gd` | `ModManager`（autoload）：id → 入口脚本的唯一映射表 + 装载 |
| `mod_base.gd` | `ModBase`：模组基类，`install()` / `on_level_para_ready()` / `install_to_main_game()`（时序见类注释） |
| `mod_ids.gd` | `ModIds`：模组 id 常量表 |
| `mod_config.gd` | `ModConfig`：开关数据资源（`data/mods/mod_config.tres` 用它） |
| `glove/` | 手套模组：把场上已种下的植物搬到另一个格子 |
| `custom_level/` | 自制关卡模组：加载 `data/levels/params` 下的玩家自制关卡，并在主菜单加入口 |
| `netplay/` | 联机模组（骨架）：ENet 连线 + 玩家操作命令上行，主菜单加入口；未做状态同步 |

## 新增一个模组

`ModIds` 加常量 → `ModManager.MOD_SCRIPT_PATHS` 加一行 → `src/mods/<id>/` 写入口脚本（继承 `ModBase`）。
三步的细则与边界规则见 [docs/参考存档/模组机制.md](../../docs/参考存档/模组机制.md) §四 / §五。
