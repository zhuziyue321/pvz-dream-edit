extends Node2D
class_name LootPickupArrow
## **战利品上方的弹跳箭头**（原版「关卡奖励」那套最显眼的表现）
##
## 原版出处：`pak/particles/AwardPickupArrow.xml`（原版 PARTICLE_AWARD_PICKUP_ARROW；
## 种子包那一版是 PARTICLE_SEED_PACKET，见 `pak/particles/SeedPacket.xml`，箭头部分一模一样）：
##   · 贴图   IMAGE_DOWNARROW = `pak/particles/DownArrow.png`
##   · 颜色   (1, .9, .4) 偏暖的黄色
##   · 位置场 Y = `0 EaseInOutWeak 10 EaseInOutWeak 0` —— **上下弹跳 10 像素**
##   · 粒子寿命 40 帧（60fps → 0.667 秒）走完一个来回
##
## 本仓库用一条循环 tween 复刻那个「0 → 10 → 0」；挂在战利品身上，
## 由 `DropItemBase.start_level_award_effects()` 起（见 docs/参考存档/掉落物说明.md §7）。
##
## 位置：箭头的**本体**留在「战利品上方那个位置」（由掉落物摆好），
## 弹跳动的是里面的贴图子节点 —— 否则一动就把位置也带跑了。

## 上下弹跳的振幅（原版位置场的 10 像素）
const BOB_HEIGHT := 10.0
## 一次来回的秒数（原版粒子寿命 40 帧 @60fps）
const BOB_PERIOD := 40.0 / 60.0

## 箭头贴图：弹跳动的是它，本体留给「战利品上方那个位置」
@onready var arrow_sprite: Sprite2D = $Arrow

## 弹跳那条 tween
var _bob_tween: Tween = null


## 开始弹跳（战利品落地之后调）
func start_bob() -> void:
	stop_bob()
	_bob_tween = create_tween()
	_bob_tween.set_loops()
	var half := BOB_PERIOD * 0.5
	_bob_tween.tween_property(arrow_sprite, "position:y", BOB_HEIGHT, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(arrow_sprite, "position:y", 0.0, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 停掉弹跳（战利品被拾取时）
func stop_bob() -> void:
	TweenUtil.kill_tween(_bob_tween)
	_bob_tween = null
	if is_instance_valid(arrow_sprite):
		arrow_sprite.position.y = 0.0
