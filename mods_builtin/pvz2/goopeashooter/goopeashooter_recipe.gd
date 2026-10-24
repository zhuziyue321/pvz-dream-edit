extends PlantRuntimeRecipe
## 毒液豌豆（Goo Peashooter）的配方：与通用配方的差别**只有卡面**
##
## ★ 为什么卡面要单独走一条：通用配方 `PlantRuntimeRecipe.build_card_face()` 用
##   `AnimationFrameUtil.create_frame_node()` 取帧，而那条路是按 **`AnimationPlayer`** 取帧的；
##   本株的播放器是 PAM 路线（在 `_draw()` 里画四边形），没有 `AnimationPlayer` ——
##   取帧不会报错，只会返回一棵什么都画不出来的树（卡面全空、手持报「卡片静态角色为空」）。
##   所以这里直接给一个「定格一帧」的 PAM 节点（`../pam_bridge.gd` 的 `create_static_frame()`）。
##
## ⚠️ 本文件**不写 `class_name`**（模组跑在 `user://` 下，那里的脚本不注册全局类；
##    基类 `PlantRuntimeRecipe` 在 `res://`，可以直接按类名继承）。

const PamBridge := preload("../pam_bridge.gd")
## 植物脚本只用来取那几份常量（bin / 图集 / 装扮黑名单 / 摆位），避免两处各写一份漂移
const PlantScript := preload("goopeashooter_plant.gd")


## 造卡面形象（同步返回；`PlantRuntimeKit` 会把它挂到卡片的 `CharacterStatic` 下）
func build_card_face() -> Node2D:
	var frame: Node2D = PamBridge.create_static_frame(
		PlantScript.BIN_REL_PATH, PlantScript.ATLAS_REL_PATH, PlantScript.HIDDEN_PARTS,
		PlantScript.ANIM_PIVOT, PlantScript.ANIM_SCALE, "idle")
	if frame == null:
		return null
	var root := Node2D.new()
	root.name = "PlantPVZ2GooPeashooter"
	root.scale = card_face_scale
	root.position = card_face_position
	root.add_child(frame)
	return root
