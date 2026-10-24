extends Bullet000ParabolaBase
## 臼炮蘑菇的炮弹（DLC 模组「DLC植物」提供）
##
## ★ 玩法：落地时按「溅射组件」对附近敌人结算一次 AoE 伤害（迷你西瓜投手式）；
##   直接命中走本体 `attack_value`，溅射走 `SpatterComponent.sum_attack_value`。
##
## ★ 抛物线落点跟随目标（见 `BulletMovementParabola`）；这里只接一下溅射。
##
## ⚠️ 本文件跑在 `user://mods/dlc/` 下：`class_name` 不会注册成全局类，所以不写 class_name，
##    由同目录的 `bullet_mortarshroom_shell.tscn` 按路径引用。

## 炮弹落地 / 溅射的音效（DLC 自己的两条 impact，随机取一条）
## 发射那一头仍借本体 `Throw`（DLC 里没有臼炮「开火」的音效），落地才换成 DLC 自己的
const IMPACT_SFX: Array[AudioStream] = [
	preload("../audio/mortarimpact.ogg"),
	preload("../audio/mortarimpact2.ogg"),
]

@onready var spatter_component: SpatterComponent = $SpatterComponent

## 攻击一次：本体先结算直接命中，再按溅射组件炸一片
func attack_once(enemy: Character000Base):
	super(enemy)
	spatter_component.spatter_all_area_enemy(enemy, lane)
	SoundManager.play_sfx_with_pool(IMPACT_SFX.pick_random())
