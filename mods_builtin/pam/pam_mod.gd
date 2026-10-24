extends "res://src/mods/mod_base.gd"
## 模组「PAM 动画播放器」：把 PVZ2 的 PopAnim（`.pam.bin`）播出来的**运行时组件**
##
## ★ 这是个**能力模组**（library mod），本身不加任何玩法：
##   它只提供 `runtime/pam_animator.gd` 这一套脚本，谁要播 PVZ2 的动画就**声明依赖它**
##   （写法见 [模组机制](../../docs/参考存档/模组机制.md) §2.3）：
##
##   ```gdscript
##   func get_mod_dependencies() -> Array[StringName]:
##       return [ModIds.PAM]
##   ```
##
##   打开「PVZ2」时会自动带上本模组；单独打开它没有任何可见变化。
##
## ★ 为什么单独拆成一个模组（而不是塞在 PVZ2 目录里）：
##   PVZ2 的植物、子弹、僵尸、特效**都要播 PAM**，将来别的模组（联机同步的敌人 / 自制关卡里
##   摆一只 PVZ2 单位）也会用同一套播放器。播放器跟着「内容」走的话，第二家要用的就得复制一份
##   —— 拆出来之后，播放口径（状态机 / 循环 / 单次 / 部件显隐 / 包围盒）只在这里维护一次。
##
## ★ 跨模组怎么用（**别写 `preload("res://mods_builtin/pam/...")`**：模组可以被拷到
##   `user://mods/`，那条绝对路径就指到另一份了）。照 `mods_builtin/pvz2/pam_bridge.gd` 的写法：
##   按 `ModManager.get_mod_asset_path(ModIds.PAM, "runtime/pam_animator.gd")` 取**当前生效的加载根**
##   下的脚本，`load()` 出来 `.new()`，再把 `binary_path` / `hidden_parts` / `texture_override` 塞进去。
##   贴图同理走 `ModManager.load_mod_asset()`，所以 `.pam.bin` 里内嵌的 `res://` 路径只是**烘焙时的痕迹**，
##   运行时一律由调用方覆盖。
##
## ★ 数据从哪来：`tools/bake_pam_bin.py`（PAM json + 图集矩形 → `PAM2 v1` 二进制），
##   运行时**不解析 PAM / 不解析 json**，只读压平后的每帧快照（零解析开销）。

const ModBase := preload("res://src/mods/mod_base.gd")


func get_mod_id() -> StringName:
	return ModIds.PAM


func get_mod_name() -> String:
	return "PAM 动画播放器"


func get_mod_description() -> String:
	return "PVZ2 的 PopAnim（PAM）运行时播放器：读 `.pam.bin`，一个 Node2D 在 `_draw()` 里按帧画，零节点 / 零动画轨道。本身不加玩法，是 PVZ2 模组的依赖"


func get_mod_categories() -> Array[StringName]:
	## 能力模组，不属于「新增单位 / 工具 / 规则 / 结构」任何一类
	return []


func create_detail_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(ModBase.create_detail_label(
		"作用：提供 PVZ2 那套 PopAnim 动画的播放器（`runtime/pam_animator.gd`）。单独打开本模组没有任何可见变化"))
	box.add_child(ModBase.create_detail_label(
		"为什么单独拆出来：PVZ2 的植物、子弹、僵尸、特效都要播 PAM，别的模组以后也会用同一套 —— 播放口径只在这里维护一次"))
	box.add_child(ModBase.create_detail_label(
		"数据形态：PAM 离线烘成「一张图集 + 一个 `.pam.bin`」（每帧全量快照），运行时零解析、零节点树；一株几百帧的植物也只占一个 `Node2D`"))
	box.add_child(ModBase.create_detail_label(
		"公开接口：切状态 / 单次与循环 / 状态内帧号回调 / 部件显隐 / 当前帧包围盒 / 部件落点。清单见脚本头"))
	box.add_child(ModBase.create_detail_label(
		"依赖关系：「PVZ2」模组依赖本模组，打开 PVZ2 会自动带上它；关掉 PVZ2 不会自动关它（关它 PVZ2 就动不了）"))
	return box


func install() -> void:
	Log.info("PAM：播放器已就绪（提供 runtime/pam_animator.gd）")


func uninstall() -> void:
	Log.info("PAM：播放器已撤下")
