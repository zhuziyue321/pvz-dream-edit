extends ArmorComponent
class_name ArmorComponentNewspaper
## 报纸（一种**自带特殊效果**的防具）：报纸还在时是慢悠悠的读报僵尸，
## 报纸一破就暴走（原版 Rarrgh + 撕纸音效 + 攻击与移动提速）。
##
## 效果**由防具组件自己定义**（重写 `on_armor_break()`），`zombie_paper.gd` 里不再连
## 「防具掉了」的信号 —— 破防该发生什么，全在本文件里。


## 报纸被打掉：暴走
func on_armor_break() -> void:
	var zombie := owner_character as Zombie006Paper
	if zombie == null:
		return
	zombie.is_gasp = true
	SoundManager.play_character_SFX(&"Rarrgh")
	SoundManager.play_character_SFX(&"Rip")
	zombie.attack_component.update_attack_value(2, AttackComponentZombieNorm.E_AttackValueFactor.Speed)
