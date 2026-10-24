# `pam/` —— PAM 动画播放器（能力模组）

PVZ2 那套 PopAnim（`.pam.bin`）的**运行时播放器**。本身不加任何玩法：单独打开它没有任何可见变化，
它只是把「怎么播一段 PAM」这套口径提供给别的模组。

| 文件 | 作用 |
|---|---|
| `pam_mod.gd` | 入口（`ModIds.PAM`）。能力模组，`get_mod_categories()` 返回空 = 未分类 |
| `runtime/pam_animator.gd` | 播放器：一个 `Node2D` 在 `_draw()` 里按帧画四边形，**没有** `Sprite2D` / `AnimationPlayer` |
| `runtime/pam_static_frame.gd` | 定格渲染器（卡面 / 图鉴）：`extends "pam_animator.gd"`，`_process()` 顶成空实现 |
| `runtime/pam_binary_reader.gd` | 读 `PAM2 v1` 二进制（格式定义见文件头，与 `tools/bake_pam_bin.py` 一一对应） |
| `runtime/pam_anim_data.gd` / `pam_image_def.gd` / `pam_instance_state.gd` | 解析结果的数据类 |

## 谁在用

- `mods_builtin/pvz2/`（五株植物）—— 通过 `get_mod_dependencies()` 声明依赖，打开 PVZ2 会自动带上本模组。

## 别的模组怎么用（**别 `preload("res://mods_builtin/pam/...")`**）

模组可以被拷到 `user://mods/`，那条绝对路径就会指到另一份。照 `mods_builtin/pvz2/pam_bridge.gd` 的写法：

1. 脚本：`ModManager.get_mod_asset_path(ModIds.PAM, "runtime/pam_animator.gd")` → `load()`
2. 贴图 / bin：`ModManager.load_mod_asset(ModIds.PVZ2, "<相对路径>")` / `get_mod_asset_path(...)`
3. 挂到场景里的**空 Node2D** 上：`set_script()` → `set("binary_path", ...)` / `set("hidden_parts", ...)`
   → `set_process(true)` → `load_bin()`（脚本是进树之后挂的，`_ready()` 不会自动跑）

细节与踩坑见 [../../docs/参考存档/模组机制.md §6.7](../../docs/参考存档/模组机制.md) 与
[../../docs/参考存档/动画导入.md](../../docs/参考存档/动画导入.md) 的路线 D。
