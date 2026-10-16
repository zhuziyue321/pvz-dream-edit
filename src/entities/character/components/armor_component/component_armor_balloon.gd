extends ArmorComponent
class_name ArmorComponentBalloon
## 气球（一种**自带特殊效果**的防具）：只要气球还在，僵尸就浮在空中、不能啃植物；
## 气球一破立刻落地恢复行走与啃咬。
##
## 这两个效果**由防具组件自己定义**（重写 `on_armor_equip()` / `on_armor_break()`），
## `zombie_balloon.gd` 里不再有"气球还在吗"的分支 —— 它只留被门框挤破与被三叶草吹走的入口。


## 气球还在：进入空中状态 + 禁止啃咬
func on_armor_equip() -> void:
	var zombie := owner_character as Zombie017Balloon
	if zombie == null or not is_alive():
		return
	zombie.curr_be_attack_status = Zombie000Base.E_BeAttackStatusZombie.IsSky
	zombie.attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Balloon)


## 气球破了：落地（落地动画播完由 `balloon_pop_end()` 解禁攻击组件）
func on_armor_break() -> void:
	var zombie := owner_character as Zombie017Balloon
	if zombie == null or zombie.is_death:
		return
	zombie.is_pop = true
	zombie.move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsAnimGap)
	zombie.move_component.update_move_mode(MoveComponent.E_MoveMode.Ground)
	zombie.curr_be_attack_status = Zombie000Base.E_BeAttackStatusZombie.IsNorm
	SoundManager.play_character_SFX(&"balloon_pop")
	## 气球在水路上方破裂 = 掉进水里淹死（原版行为）
	if zombie.curr_zombie_row_type == CharacterRegistry.ZombieRowType.Pool:
		zombie.character_death_disappear()
