extends BulletLinear000Base
## 蜜蜂射手吐出的蜜蜂（模组「DLC植物」的子弹）
##
## ★ 只做一件事：**振翅** —— `beeshooter_bee_fly.png` 是横向 3 帧（单帧 61×46，与原先那张
##   静态 `beeshooter_bee.png` 同尺寸），靠改 `BulletBody` 的 `region_rect` 逐帧切出
##   「翅膀在不同位置」的循环，蜜蜂飞起来翅膀才动。
##
## ★ 为什么不换成 `AnimatedSprite2D`：`Bullet000Base.body` 取的是 `Body` 这个 Node2D，
##   里面那张 `BulletBody` 是基类就引用着的 `Sprite2D`（影子 / 旋转 / 贴图都在它身上），
##   换节点类型要连带改基类。`region_rect` 是 `Sprite2D` 自带的能力，不用动基类。
##
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：不写 class_name，
##    由同目录的 `bullet_beeshooter_bee.tscn` 按路径引用。

## 振翅贴图的横向帧数（61 px × 3 = 183 px 宽）
const WING_FRAMES := 3
## 单帧尺寸（与 `beeshooter_bee_fly.png` 的实际切法一致；场景里也按这个写了 `region_rect`）
const WING_FRAME_SIZE := Vector2(61, 46)
## 振翅频率（帧 / 秒）：蜜蜂翅膀快，12 fps 看着是「嗡嗡」的一片
@export var wing_fps := 12.0

@onready var _body_sprite: Sprite2D = $Body/BulletBody

var _frame := 0
var _acc := 0.0


func _process(delta: float) -> void:
	_acc += delta
	var step := 1.0 / maxf(wing_fps, 0.01)
	## 用 while 而不是 if：掉帧时一次补上，别把翅膀卡在某一帧
	while _acc >= step:
		_acc -= step
		_frame = (_frame + 1) % WING_FRAMES
		_apply_frame()


## 切到第 `_frame` 帧（`Sprite2D.region_rect` 就是「取贴图的哪一块」）
func _apply_frame() -> void:
	_body_sprite.region_enabled = true
	_body_sprite.region_rect = Rect2(
		Vector2(WING_FRAME_SIZE.x * float(_frame), 0.0), WING_FRAME_SIZE)
