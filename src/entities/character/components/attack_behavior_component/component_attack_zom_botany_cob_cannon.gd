extends AttackComponentZomBotany
class_name AttackComponentZomBotanyCobCannon
## 玉米加农炮僵尸的攻击组件（原版 ZomBotany）
##
## 玉米炮子弹（Bullet016CobCannon）不是普通子弹：它不走 `init_bullet`，
## 而是 `init_cannon(目标全局位置)` 之后自己飞到目标点爆炸，所以这里重写发射，
## 其余（冷却 / 检测 / 阵营 / 头顶植物的发射表现）全部沿用 AttackComponentZomBotany。

func _shoot_bullet() -> void:
	signal_shoot_bullet.emit()
	var target := detect_component.enemy_can_be_attacked
	if not is_instance_valid(target) or markers_2d_bullet.is_empty():
		return
	var bullet: Bullet016CobCannon = Global.bullet_registry.get_bullet_scenes(
		BulletRegistry.BulletType.Bullet016CobCannon
	).instantiate()
	bullet.init_cannon(target.global_position)
	## 阵营：僵尸方玉米炮，炸弹炸的是玩家的植物（见 bullet_cob_cannon.gd）
	bullet.bullet_camp = get_bullet_camp()
	bullets.add_child(bullet)
	bullet.global_position = markers_2d_bullet[0].global_position
	play_throw_sfx()
	_play_head_shoot_anim()
