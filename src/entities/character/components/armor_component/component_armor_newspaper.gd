extends ArmorComponent
class_name ArmorComponentNewspaper
## 报纸（一种**自带特殊效果**的防具）：报纸还在时是慢悠悠的读报僵尸，
## 报纸一破就暴走（原版 Rarrgh + 撕纸音效 + 攻击与移动提速）。
##
## 效果**由防具组件自己定义**（重写 `on_armor_break()`），`zombie_paper.gd` 里不再连
## 「防具掉了」的信号 —— 破防该发生什么，全在本文件里。


## 暴走移速补差：原版 `PHASE_NEWSPAPER_MAD` 的 `mVelX = 0.89~0.91`，是普通僵尸（0.23~0.37，
## 均值 0.30）的 **3 倍**；`paper_gasp` 子状态机只能把动画（也就是 Ground 模式位移）提到 2 倍，
## 所以再用 `MoveComponent.ground_speed_scale` 补上差额。
##
## 实测（`test/scenarios/probe_zombie_speed.gd`，个体随机压成 1.0）：
##   本作 破报 29.0 / 普僵 14.2 = 2.04 倍，原版 3.0 倍 ⇒ 补 1.5 倍 ≈ 3.06 倍
## 注：本作僵尸整体移速约为原版一半（普僵 14.2 vs 原版 23~37），报纸按**相对普僵的倍率**
## 对齐；绝对 90 px/s 需要全局提速，是另一件事，别在这里硬凑。
const MAD_GROUND_SPEED_SCALE := 1.5


## 报纸被打掉：暴走
func on_armor_break() -> void:
	var zombie := owner_character as Zombie006Paper
	if zombie == null:
		return
	zombie.is_gasp = true
	zombie.move_component.set_ground_speed_scale(MAD_GROUND_SPEED_SCALE)
	SoundManager.play_character_SFX(&"Rarrgh")
	SoundManager.play_character_SFX(&"Rip")
	zombie.attack_component.update_attack_value(2, AttackComponentZombieNorm.E_AttackValueFactor.Speed)
