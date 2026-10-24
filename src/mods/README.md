<!-- AGENT-DOC: pointer -->
# README.md —— `src/mods/` 目录指针

> 本文件**只做指针**：模组机制的正文在 [../../docs/参考存档/模组机制.md](../../docs/参考存档/模组机制.md)。

## 一句话

**原版之外的玩法做成模组**：本体（`main_game_base.tscn` / 管理器 / 卡槽）不认识任何模组，
关掉模组 = 不装载，场景里不会多出任何节点。

开关与**模组自己的设置**都在一份存档文件里：`user://<用户名>/mod_config.ini`（一人一份，模组页面上改的就是它）；
`data/mods/mod_config.tres` 只是没有存档文件时播种用的工程默认。

## 现在这个目录里有什么

这里是**模组框架**：装载器 + 基类 + id / 配置 / 分类三份契约。内置模组的**源码**在
[../../mods_builtin/](../../mods_builtin/README.md)（那个目录**只放模组目录**）。
两个加载源**不互相复制**（2026-10-15 起），启动时的顺序是：
**`user://mods/<入口脚本>` 在就用玩家那份，不在就用 `res://mods_builtin/`**
（这样「只给玩家一个游戏文件」时，模组也一定装得起来）。
> 想改内置模组：把它**整个目录**拷到 `user://mods/` 下再改 —— 一个模组只从一个根加载
> （`preload("相对路径")` 不能跨根混用），拷漏了 `ModManager` 会打一行 warn 列清单。
> `mod_base.gd` **不用拷**：它不在任何加载根里，只有这里这一份。

| 文件 | 作用 |
|---|---|
| `mod_manager.gd` | `ModManager`（autoload）：id → 入口脚本的映射表 + **定加载根（`user://mods/` 优先，没有就用 `res://mods_builtin/`）** + **读写模组存档文件** + 装载 |
| `mod_base.gd` | `ModBase`：模组基类（抽象），`install()` / `on_level_para_ready()` / `install_to_main_game()` / `create_detail_control()` + `get_mod_categories()` / `get_mod_dependencies()` |
| `mod_ids.gd` | `ModIds`：模组 id 常量表（保留 `class_name`，本体与模组共用） |
| `mod_config.gd` | `ModConfig`：工程默认开关数据资源（保留 `class_name`；`data/mods/mod_config.tres` 用它） |
| `mod_category.gd` | `ModCategory`：模组分类契约（维度 C：内容性质），保留 `class_name` |

**框架脚本只有这一份**：模组入口一律 `extends "res://src/mods/mod_base.gd"` —— 绝对路径在两个加载根下
都指向同一份，所以把模组目录拷到 `user://mods/` 时不必再带 `mod_base.gd`。
autoload 脚本（`mod_manager.gd`）也必须是 `res://` 资源，所以它也留在这里。

## 新增一个模组

`ModIds` 加常量 → `ModManager.MOD_SCRIPT_PATHS` 加一行 → `mods_builtin/<id>/` 写入口脚本
（`extends "res://src/mods/mod_base.gd"`）。

三步的细则与边界规则见 [docs/参考存档/模组机制.md](../../docs/参考存档/模组机制.md) §四 / §五。
改了 `mods_builtin/` 里的文件**直接生效**（那就是默认加载源）；玩家目录里有同名模组时才是玩家那份优先。
