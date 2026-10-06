extends Zombie000Base
class_name Zombie037Torchwood
## 火炬僵尸（原版 ZomBotany）：把玩家射过来的豌豆点成火豌豆
##
## 原版这一只的恶心之处就在"反向利用玩家的豌豆" —— 火豌豆伤害更高，飞过去把后面的僵尸烧得更惨。
## 所以这里只升级**植物方**的子弹（bullet_camp == Plant），僵尸方（植物僵尸）自己射的豌豆不点。
##
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Torchwood_Zombie)

## 豌豆升级表（与火炬树桩一致：豌豆 → 火豌豆；寒冰豌豆先被解冻成普通豌豆）
const bullet_upgrade_data: Dictionary[BulletRegistry.BulletType, BulletRegistry.BulletType] = {
	BulletRegistry.BulletType.Bullet001Pea: BulletRegistry.BulletType.Bullet006PeaFire,
	BulletRegistry.BulletType.Bullet002PeaSnow: BulletRegistry.BulletType.Bullet001Pea,
}

## 检测玩家子弹的区域（场景里配置：mask 只开 layer4 BulletFromPlant）
@onready var area_2d_up_bullet: Area2D = %Area2DUpBullet

## 已经升级过的子弹，避免同一颗反复升级
var curr_bullet_up: Array[Bullet000Base] = []
## 子弹父节点
var bullets: Node2D


func ready_norm() -> void:
	super()
	bullets = Global.main_game.bullets


func ready_norm_signal_connect() -> void:
	super()
	area_2d_up_bullet.area_entered.connect(_on_area_2d_up_bullet_area_entered)


## 子弹进入升级区域
func _on_area_2d_up_bullet_area_entered(area: Area2D) -> void:
	var bullet := area.owner as Bullet000Base
	if not is_instance_valid(bullet):
		return
	## 只点玩家的豌豆
	if bullet.bullet_camp != CharacterRegistry.CharacterType.Plant:
		return
	if bullet.is_can_up and bullet.bullet_type in bullet_upgrade_data.keys():
		_up_bullet(bullet)


## 升级子弹：原豌豆消失，换一颗同参数的新子弹继续飞
func _up_bullet(curr_bullet: Bullet000Base) -> void:
	if curr_bullet in curr_bullet_up:
		return
	var new_type: BulletRegistry.BulletType = bullet_upgrade_data[curr_bullet.bullet_type]
	var bullet_up: Bullet000Base = Global.bullet_registry.get_bullet_scenes(new_type).instantiate()
	bullet_up.init_bullet(curr_bullet.get_bullet_paras())
	curr_bullet_up.append(bullet_up)
	bullets.call_deferred("add_child", bullet_up)
	curr_bullet.queue_free()
