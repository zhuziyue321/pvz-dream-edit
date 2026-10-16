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

## 宿主角色走基类 `ComponentNormBase.owner_character`（U-06 统一后的唯一写法），
## 这里不再自己 `@onready var owner_character = owner` —— 自己定义会遮蔽基类同名访问器

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


## **秒杀**：直接把血清空（**不看伤害值、不走任何吸收 / 减伤规则，必然致死**）。
##
## 由 `hp_loss()` 在 `info.is_instant_kill` 为真时调用；僵尸子类重写成"防具 + 本体一起清"
## （见 `HpComponentZombie.clear_all_hp()`）。
##
## 走的是血量 setter，所以死亡信号 / 亡语 / 掉落与"被打死"走同一条路（见 `DamageInfo.is_instant_kill`）。
## [return] 清空后的本体血量
func clear_all_hp() -> int:
	curr_hp = 0
	return curr_hp


## **结算层**：把一次伤害真正扣到血量上（植物只有本体血，僵尸子类重写成三层分配）。
##
## ⚠️ 这是**管线的末端**，不是给业务代码直接调的入口 ——
## 直接调它会绕过 `DamageSystem` 的修饰器与伤害事件（将来加护盾 / 联机会各漏一处，且不报错）。
## 要造成伤害请走 `DamageSystem.apply()` 或角色的语义入口（`be_attacked_bullet()` / `be_zombie_eat()` …）。
##
## [param info] 本次伤害（见 `DamageInfo`；`amount` 已被修饰器改好，这里不再改）
## [return] 结算后的本体血量（僵尸子类返回本体血，不是三层之和）
func hp_loss(info: DamageInfo) -> int:
	if info.is_instant_kill:
		clear_all_hp()
	else:
		curr_hp -= info.amount
	var is_drop = not (owner.is_death and not info.is_drop_on_death) and info.is_drop_2
	signal_hp_loss.emit(curr_hp, is_drop)

	## 如果有受击音效并且触发受击音效
	if sfx_be_attack_body != SoundManager.TypeBeAttackSFX.Null and info.trigger_sfx:
		SoundManager.play_be_attack_SFX(sfx_be_attack_body)

	return curr_hp


## **发起层**：直接把血清空（铲子铲除 / 死亡消失 / 关卡脚本强制致死一类）。
##
## 走 `DamageSystem` 而不是自己扣：这条路径同样是"一次伤害"，将来要免疫 / 统计照样该经过它。
## [param is_drop] 是否有掉落
func hp_loss_to_death(is_drop: bool = true) -> DamageResult:
	var info := DamageInfo.create(
		owner_character,
		get_all_hp(),
		ConstDamage.E_DamageMode.Norm,
		ConstDamage.E_DamageCause.Death
	)
	## 本函数要的就是"必死"，所以开秒杀：不看伤害值、不看防具的吸收规则，直接清空。
	## （伤害值照填只是为了 `DamageResult` 上的数字好看，不是靠它致死）
	info.is_instant_kill = true
	info.is_drop_on_death = is_drop
	info.trigger_sfx = false
	return DamageSystem.apply(info)
