extends AnimatedSprite2D
## DLC 序列帧特效播放器（模组「DLC植物」的表现层小工具）
##
## ★ 为什么自己写：本体 `src/fx/` 那套特效是「一个 `.tscn` 挂 `GPUParticles2D` + 手摆 `Sprite2D`」，
##   而 DLC 这批素材是**一张横向 N 帧的 PNG**（美术按「横向单行」给的，见需求单 §1 通用规格），
##   没有粒子参数可挂；为 13 张图各建一个场景又太碎。
##   这里把「横向切帧 → `SpriteFrames` → 播一遍」收成一个小工具，脚本里 new + add_child + setup 就能用。
##
## ★ 用法（**先 `add_child` 再 `setup`**：离树时 `play()` 跑不动）：
##   var fx := FX_SCRIPT.new()
##   parent.add_child(fx)
##   fx.setup(TEXTURE, 6, 12.0)
##
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：`class_name` 不会注册成全局类（实测 Godot 4.6.2），
##    所以这里不写 class_name，由调用方 preload 后 `new()`。

## 本工具只用这一条动画名
const ANIM := &"dlc_fx"

## 播完（非循环时）自动 `queue_free`？
var _auto_free := true


## 按一张横向序列帧贴图起一段动画
## [param sheet] 横向 N 帧的贴图（单帧尺寸 = 宽 ÷ hframes × 高）
## [param hframes] 横向帧数
## [param fps] 每秒帧数
## [param loop] 是否循环（循环时不自动释放）
## [param auto_free] 非循环播完时自动 `queue_free`
func setup(sheet: Texture2D, hframes: int, fps: float, loop := false, auto_free := true) -> void:
	if sheet == null or hframes <= 0:
		Log.error("DLC 序列帧特效：贴图为空或帧数 %d 非法，这帧特效已跳过" % hframes)
		queue_free()
		return
	var frames := SpriteFrames.new()
	frames.add_animation(ANIM)
	frames.set_animation_speed(ANIM, fps)
	frames.set_animation_loop(ANIM, loop)
	var frame_w := float(sheet.get_width()) / float(hframes)
	var frame_h := float(sheet.get_height())
	for i in hframes:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(frame_w * float(i), 0.0, frame_w, frame_h)
		frames.add_frame(ANIM, atlas)
	sprite_frames = frames
	_auto_free = auto_free and not loop
	animation_finished.connect(_on_animation_finished)
	play(ANIM)


func _on_animation_finished() -> void:
	if _auto_free:
		queue_free()
