extends ComponentNormBase
class_name HpComponent
## 血量组件
##
## 已接入组件体系（`ComponentNormBase`），初始化写在 `component_ready()` 里。
##
## 关于「血量组件会不会被禁用机制误伤」：全仓没有任何代码对 hp_component /
## anim_component 调 `disable_component()`，所有调用都是按名字取到特定组件（攻击、
## 生产、受击框等）再禁用；`owner_update_speed()` 也都是针对具体组件调用，不存在
## 「遍历所有组件批量禁用」。所以继承来的 `is_enabling` 恒为 true，不影响血量结算。
##
## 注：曾经接入后出现过「植物和僵尸都不攻击」的回归，但已查明元凶是攻击组件
## `_ready()` 改名 `component_ready()` 时漏了 `super()`（见 ComponentNormBase 那条注释），
## 与本类接入无关 —— 回退本类后症状并未消失。详见 2026-10-07 的工作记录。

@onready var owner_character: Character000Base = owner

@onready var progress_bar_hp: ProgressBar = %ProgressBarHp
@onready var label_hp: Label = %LabelHp

@export var max_hp:int
## 本体受击音效
@export var sfx_be_attack_body :SoundManagerClass.TypeBeAttackSFX= SoundManagerClass.TypeBeAttackSFX.Null

## 是否可以查看血条(norm正常出战角色可以)
var is_can_look_hp:=true
## 角色是否死亡，判断是否发射死亡信号
var is_death := false

var death_hp:int = 0
var curr_hp:int:
	set(value):
		value = max(value, 0)
		curr_hp = value
		label_hp.text = str(curr_hp)
		progress_bar_hp.value = float(curr_hp) / max_hp

		## 如果血量小于死亡血量临界值,并且角色还未死亡时
		if value <= death_hp and not is_death:
			is_death = true
			## 角色死亡
			signal_hp_component_death.emit()


## 血量损失信号(curr_hp:当前血量值),给血量变化组件(僵尸\坚果\南瓜)使用
signal signal_hp_loss(curr_hp:int, is_drop:bool)
## 血量组件检测到死亡信号
signal signal_hp_component_death

func component_ready() -> void:
	curr_hp = max_hp
	## 出战角色连接信号，显示血量
	if owner_character.character_init_type == Character000Base.E_CharacterInitType.IsNorm:
		if self is HpComponentZombie:
			visible = Global.config_service.display_zombie_HP_label
			Global.config_service.signal_change_display_zombie_HP_label.connect(change_display_HP_label)

		else:
			visible = Global.config_service.display_plant_HP_label
			Global.config_service.signal_change_display_plant_HP_label.connect(change_display_HP_label)
	else:
		is_can_look_hp = false
		visible = false

func change_display_HP_label(value:bool):
	if is_can_look_hp:
		visible = value

func set_death_hp(new_death_hp:int):
	self.death_hp = new_death_hp

func get_all_hp():
	return curr_hp

## attack_value(int): 掉血的值
## bullet_mode(AttackMode): 伤害类型
## trigger_be_attack_SFX:=true:是否触发受击音效
## [is_drop_on_death:bool] 死亡时是否有掉落
## [is_drop_2:bool] 是否有掉落额外条件
## return bool: 返回是否死亡
func Hp_loss(attack_value:int, _bullet_mode:BulletRegistry.AttackMode =BulletRegistry.AttackMode.Norm, is_drop_on_death: bool = true, trigger_be_attack_SFX: bool = true, is_drop_2: bool = true):
	curr_hp -= attack_value
	var is_drop = not (owner.is_death and not is_drop_on_death) and is_drop_2
	signal_hp_loss.emit(curr_hp, is_drop)

	## 如果有受击音效并且触发受击音效
	if sfx_be_attack_body != SoundManager.TypeBeAttackSFX.Null and trigger_be_attack_SFX:
		SoundManager.play_be_attack_SFX(sfx_be_attack_body)

	return curr_hp == 0

## 掉血死亡
##[is_drop:bool]是否有掉落body
func Hp_loss_death(is_drop:=true):
	Hp_loss(get_all_hp(),BulletRegistry.AttackMode.Norm, is_drop, false)
