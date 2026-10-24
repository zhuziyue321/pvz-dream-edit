extends "pam_animator.gd"
## PAM 的「定格一帧」渲染器 —— 卡面 / 图鉴这类地方用
##
## ★ 为什么需要它：本体通用配方 `PlantRuntimeRecipe.build_card_face()` 走的是
##   `AnimationFrameUtil`，那条路是按 **`AnimationPlayer`** 取帧的（`find_animation_player()` → `seek()`）。
##   PAM 路线的播放器是自己 `_draw()` 里画四边形，**没有 AnimationPlayer** —— 取帧不会报错，
##   只会返回一棵什么都画不出来的树（卡面全空、手持还会报「卡片静态角色为空」拿不起来）。
##   所以 PAM 路线的卡面直接用同一个播放器，把时间钉死在某一帧上。
##
## ★ 定格姿势与场上同一套数据：同一份 `.pam.bin`、同一份 `hidden_parts`，
##   所以卡面看到的就是场上那株的样子（含 PVZ2 原版自带的那几块土）。
##
## ⚠️ `_process()` 被**整个顶成空实现**（而不是 `set_process(false)`）：
##   卡面节点会被 `duplicate()` 复制到待选区种子包 / 出战卡槽 / 手持 / 整列虚影，
##   复制出来的实例必须同样定格 —— `_process` 是脚本级行为，复制一定会带上它；
##   `set_process(false)` 是节点级状态，复制时不一定跟着走。
##
## ⚠️ 与 `pam_animator.gd` 一样**不写 `class_name`**（模组跑在 `user://` 下不注册全局类）。

## 定格在哪一段状态（默认 `idle` = 站在地上的待机）
@export var static_state := "idle"


func _ready() -> void:
	super()
	## 基类 `_ready()` 已经按默认播了第一段，这里钉到指定段
	if not set_state(static_state):
		Log.warn("[PAM] 卡面状态不存在：", static_state, " @ ", binary_path)


## 不推进时间：一直是同一帧
func _process(_delta: float) -> void:
	pass
