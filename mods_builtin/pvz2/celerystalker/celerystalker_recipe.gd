extends PlantRuntimeRecipe
## 潜伏芹菜（Celery Stalker）的配方：与通用配方的差别**只有卡面**
##
## ★ 为什么卡面要单独走一条：通用配方 `PlantRuntimeRecipe.build_card_face()` 用
##   `AnimationFrameUtil.create_frame_node()` 取帧，而那条路是按 **`AnimationPlayer`** 取帧的
##   （`find_animation_player()` → `seek()`）；本株的播放器是 PAM 路线（在 `_draw()` 里画四边形），
##   **没有 AnimationPlayer** —— 取帧不会报错，只会返回一棵什么都画不出来的树，
##   卡面全空、手持还会报「卡片静态角色为空」拿不起来。
##   所以这里直接给一个「定格一帧」的 PAM 节点（`../pam_bridge.gd` 的 `create_static_frame()`）。
##
## ★ 两层缩放的用意（与 `plant_celerystalker.tscn` 里那份 0.55 一致）：
##   外层 = 卡片上的大小（配方字段 `card_face_scale` 再乘一次），
##   内层 = 场上这株的大小；`HandComponentCharacter` 会把**外层** scale 还原成 1，
##   手持虚影因此与场上一样大（本体手摆卡面就是这个口径）。
##
## ⚠️ 本文件**不写 `class_name`**（模组跑在 `user://` 下，那里的脚本不注册全局类；
##    基类 `PlantRuntimeRecipe` 在 `res://`，可以直接按类名继承）。

const PamBridge := preload("../pam_bridge.gd")
## 植物脚本只用来取那几份常量（bin / 图集 / 装扮黑名单 / 摆位），避免两处各写一份漂移
const PlantScript := preload("celerystalker_plant.gd")


## 造卡面形象（同步返回；`PlantRuntimeKit` 会把它挂到卡片的 `CharacterStatic` 下）
func build_card_face() -> Node2D:
	var frame: Node2D = PamBridge.create_static_frame(
		PlantScript.BIN_REL_PATH, PlantScript.ATLAS_REL_PATH, PlantScript.HIDDEN_PARTS,
		PlantScript.ANIM_PIVOT, PlantScript.ANIM_SCALE, "idle")
	if frame == null:
		return null
	## 外层挂点：尺寸与落点仍按配方里那两个字段（与本体手摆卡面的口径一致）
	var root := Node2D.new()
	root.name = "PlantPVZ2CeleryStalker"
	root.scale = card_face_scale
	root.position = card_face_position
	root.add_child(frame)
	return root
