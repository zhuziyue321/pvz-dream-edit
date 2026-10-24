extends Node2D
## 脑子阳光（PVZ2 的 `BrainSun`）
##
## 挂在阳光节点底下：把原版那套阳光贴图藏掉，换成 PVZ2 的「脑子」，
## 再加一圈脑光。**只换外观** —— 收集、飞向计数器、数值、落地判定都不动。

## 脑子贴图 37×37，原版阳光的核心更大一点，按比例放大
const BRAIN_SCALE := 1.4
## 脑光贴图 120×120（星芒可见范围约 104×107）
##
## ⚠️ 这层光晕是**画在脑子后面**的，得明显大于脑子（脑子放大后可见约 48×49）才看得出是
## 「一圈光托着脑子」；0.5 时星芒只有约 52×54，几乎与脑子一样大，光全被脑子盖住了。
const GLOW_SCALE := 0.9

var _brain: Sprite2D
var _glow: Sprite2D


## 装到一颗阳光上
func setup(brain_tex: Texture2D, glow_tex: Texture2D) -> void:
	if brain_tex == null:
		return
	if glow_tex != null:
		_glow = Sprite2D.new()
		_glow.texture = glow_tex
		_glow.scale = Vector2(GLOW_SCALE, GLOW_SCALE)
		_glow.modulate = Color(1, 1, 1, 0.3)
		add_child(_glow)
	_brain = Sprite2D.new()
	_brain.texture = brain_tex
	_brain.scale = Vector2(BRAIN_SCALE, BRAIN_SCALE)
	add_child(_brain)
	## 脑子**不转**：原版这颗脑子是定着的，只有一圈脑光在呼吸
	## 脑光一闪一闪
	if _glow != null:
		var glow_tween := create_tween().set_loops()
		glow_tween.tween_property(_glow, "modulate:a", 0.7, 0.6).set_trans(Tween.TRANS_SINE)
		glow_tween.tween_property(_glow, "modulate:a", 0.2, 0.6).set_trans(Tween.TRANS_SINE)
