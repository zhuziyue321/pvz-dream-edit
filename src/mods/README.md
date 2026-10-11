<!-- AGENT-DOC: pointer -->
# README.md —— `src/mods/` 目录指针

> 本文件**只做指针**：模组机制的正文在 [../../docs/参考存档/模组机制.md](../../docs/参考存档/模组机制.md)。

## 一句话

**原版之外的玩法做成模组**：本体（`main_game_base.tscn` / 管理器 / 卡槽）不认识任何模组，
关掉模组 = 不装载，场景里不会多出任何节点。
开关与**模组自己的设置**都在一份存档文件里：`user://<用户名>/mod_config.ini`（一人一份，模组页面上改的就是它）；
`data/mods/mod_config.tres` 只是没有存档文件时播种用的工程默认。

## 文件

| 文件 | 作用 |
|---|---|
| `mod_manager.gd` | `ModManager`（autoload）：id → 入口脚本的唯一映射表 + **读写模组存档文件** + 装载 |
| `mod_base.gd` | `ModBase`：模组基类，`install()` / `on_level_para_ready()` / `install_to_main_game()`（时序见类注释） |
| `mod_ids.gd` | `ModIds`：模组 id 常量表 |
| `mod_config.gd` | `ModConfig`：**工程默认**开关数据资源（`data/mods/mod_config.tres` 用它；只在存档文件不存在时播种一次） |
| `glove/` | 手套模组：把场上已种下的植物搬到另一个格子 |
| `custom_level/` | 自制关卡模组：加载 `user://custom_level` 下的玩家自制关卡，并在主菜单加入口 |
| `netplay/` | 联机模组（骨架）：ENet 连线 + 玩家操作命令上行，主菜单加入口；未做状态同步 |
| [../ui/mod_page/](../ui/mod_page/) | **模组页面**（左列模组列表 + 右侧详情）：入口在主菜单「选项」→「控制台」→「模组」；详情里模组自己那一块由 `ModBase.create_detail_control()` 给 |

## 新增一个模组

`ModIds` 加常量 → `ModManager.MOD_SCRIPT_PATHS` 加一行 → `src/mods/<id>/` 写入口脚本（继承 `ModBase`）。
三步的细则与边界规则见 [docs/参考存档/模组机制.md](../../docs/参考存档/模组机制.md) §四 / §五。
