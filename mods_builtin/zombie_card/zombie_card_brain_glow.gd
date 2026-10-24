extends Node2D
## 脑子上的脑光（PVZ2 的 `BrainGlow`）
##
## 挂在**脑子的同级**上（不是脑子底下）：脑子被吃掉时会 `queue_free()`，
## 挂在它底下的话「爆一下」那一下会跟着一起没了。
##
## 三种状态：
##   · 平时 —— 一点呼吸着的粉色星芒（弱一点，别抢脑子的戏）
##   · 被啃一口 —— 接线每帧盯脑子血量，血少了就调 `flash()` 闪一下
##   · 脑子被吃掉 —— 爆一下再收掉

## 星芒贴图尺寸 120×120，脑子本体在 (0, -16)
const GLOW_SCALE := 0.5
const FLASH_SCALE := 0.95
const DEATH_SCALE := 1.5
const PULSE_HALF_TIME := 0.55

## 常亮的那层
var _glow: Sprite2D
## 闪烁的那层（跟常亮分开，免得两个 tween 抢同一个 alpha）
var _flash: Sprite2D
var _pulse_tween: Tween
var _flash_tween: Tween
var _is_dying := false


## 装到某个脑子上
func setup(brain: BrainOnZombieMode, tex: Texture2D) -> void:
	if brain == null or tex == null:
		return
	## 跟脑子待在同一个父节点下，位置照抄脑子（脑子不动，够了）
	position = brain.position
	z_index = brain.z_index + 1
	_glow = _make_sprite(tex, GLOW_SCALE, 0.0)
	_flash = _make_sprite(tex, GLOW_SCALE, 0.0)
	if not brain.signal_brain_death.is_connected(_on_brain_death):
		brain.signal_brain_death.connect(_on_brain_death)
	_start_pulse()


## 被啃一口：闪一下
func flash() -> void:
	if _is_dying or _flash == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "scale", Vector2(FLASH_SCALE, FLASH_SCALE), 0.08)
	_flash_tween.parallel().tween_property(_flash, "modulate:a", 1.0, 0.08)
	_flash_tween.tween_property(_flash, "scale", Vector2(GLOW_SCALE, GLOW_SCALE), 0.25)
	_flash_tween.parallel().tween_property(_flash, "modulate:a", 0.0, 0.25)


## 脑子被吃掉：爆一下，然后收掉自己
func _on_brain_death() -> void:
	if _is_dying:
		return
	_is_dying = true
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	var tween := create_tween()
	tween.tween_property(_flash, "scale", Vector2(DEATH_SCALE, DEATH_SCALE), 0.18)
	tween.parallel().tween_property(_flash, "modulate:a", 1.0, 0.18)
	tween.tween_property(_flash, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)


## 常亮那层的呼吸
func _start_pulse() -> void:
	if _glow == null:
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_glow, "modulate:a", 0.35, PULSE_HALF_TIME).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_glow, "modulate:a", 0.05, PULSE_HALF_TIME).set_trans(Tween.TRANS_SINE)


## 造一层星芒
func _make_sprite(tex: Texture2D, sprite_scale: float, alpha: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.position = Vector2(0, -16)
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	sprite.modulate = Color(1, 1, 1, alpha)
	add_child(sprite)
	return sprite
