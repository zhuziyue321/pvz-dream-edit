<!-- AGENT-DOC: pointer -->
# README.md —— `src/mods/` 目录指针

> 本文件**只做指针**：模组机制的正文在 [../../docs/参考存档/模组机制.md](../../docs/参考存档/模组机制.md)。

## 一句话

**原版之外的玩法做成模组**：本体（`main_game_base.tscn` / 管理器 / 卡槽）不认识任何模组，
关掉模组 = 不装载，场景里不会多出任何节点。

开关与**模组自己的设置**都在一份存档文件里：`user://<用户名>/mod_config.ini`（一人一份，模组页面上改的就是它）；
`data/mods/mod_config.tres` 只是没有存档文件时播种用的工程默认。

## 现在这个目录里只剩什么

**内置模组本体已经搬到 `mods_builtin/`**。两个加载源**不互相复制**（2026-10-15 起），
启动时的顺序是：**`user://mods/<入口脚本>` 在就用玩家那份，不在就用 `res://mods_builtin/`**
（这样「只给玩家一个游戏文件」时，模组也一定装得起来）。
> 想改内置模组：把它**整个目录**拷到 `user://mods/` 下再改（含 `mod_base.gd`）——
> 一个模组只从一个根加载（`preload("相对路径")` 不能跨根混用），拷漏了 `ModManager` 会打一行 warn 列清单。

| 文件 | 作用 |
|---|---|
| `mod_manager.gd` | `ModManager`（autoload）：id → 入口脚本的映射表 + **定加载根（`user://mods/` 优先，没有就用 `res://mods_builtin/`）** + **读写模组存档文件** + 装载 |

autoload 脚本必须是 `res://` 下的资源，所以这个文件留在 `src/mods/`；
`mod_base.gd` / `mod_ids.gd` / `mod_config.gd` 与六个模组本体都在 [../../mods_builtin/](../../mods_builtin/README.md)。

## 新增一个模组

`ModIds` 加常量 → `ModManager.MOD_SCRIPT_PATHS` 加一行 → `mods_builtin/<id>/` 写入口脚本（继承 `ModBase`）。

三步的细则与边界规则见 [docs/参考存档/模组机制.md](../../docs/参考存档/模组机制.md) §四 / §五。
改了 `mods_builtin/` 里的文件**直接生效**（那就是默认加载源）；玩家目录里有同名模组时才是玩家那份优先。
