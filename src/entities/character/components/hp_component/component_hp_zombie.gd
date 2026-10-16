extends HpComponent
class_name HpComponentZombie
## 僵尸血量组件
##
## **防具不再存在本组件里** —— 防具是挂在同一角色下的 `ArmorComponent` 节点（可多个、同类可叠加），
## 本组件在 `component_ready()` 里自动收集并排好挨打顺序，结算时遍历它们。
## 详见 `ArmorComponent` 的类注释与 `docs/参考存档/防具.md`。
##
## 血条上那一/二类防具的两根条显示的是**该类防具的血量之和**，
## 叠加多个同类防具时看到的是它们的总和，不需要为每层再开一根条。

@onready var progress_bar_hp_armor_2: ProgressBar = %ProgressBarHpArmor2
@onready var label_hp_armor_2: Label = %LabelHpArmor2
@onready var progress_bar_hp_armor_1: ProgressBar = %ProgressBarHpArmor1
@onready var label_hp_armor_1: Label = %LabelHpArmor1

@onready var armor_2_control: Control = %Armor2Control
@onready var armor_1_control: Control = %Armor1Control

## 本角色的所有防具，**按挨打顺序排好**：二类在前、一类在后，同类按 `absorb_priority`
## 从大到小，再相同则按节点在场景里的先后顺序。
## 顺序的真源是这里，宿主与消费方一律只读（K-01）。
var armor_list: Array[ArmorComponent] = []

## 死亡后每4帧掉一次血
var num_frame := 0

## 僵尸掉血信号（只有僵尸使用）,参数为损失的血量值
signal signal_zombie_hp_loss(all_loss_hp:int)


func component_ready() -> void:
	## 必须调 super：HpComponent.component_ready() 负责把 curr_hp 初始化成 max_hp，
	## 并接上血条显示的配置信号。基类 ComponentNormBase._ready() **只分派一次**
	## component_ready()（落在最派生的重写版本），不调 super 父类的整段初始化就丢了。
	super()
	_collect_armors()
	## 防具节点多半排在 HpComponent 之后，它们的 `_ready()`（curr_hp 初始化）还没跑，
	## 这里读到的是 0；推迟一帧再画，拿到的是满血值
	call_deferred("_refresh_armor_bars")


func _physics_process(delta: float) -> void:
	if owner_character.is_death and curr_hp != 0:
		num_frame = wrapi(num_frame + 1, 0, 4)
		if num_frame == 0:
			curr_hp -= max(int(delta * 50 * 4), 1)


func get_all_hp():
	var total := curr_hp
	for armor in armor_list:
		total += armor.curr_hp
	return total


## **秒杀**：重写自 `HpComponent` —— 僵尸要连**所有防具**一起清。
##
## 与"打一个等于总血量的伤害"的区别：这里**不看吸收规则**，防具的减伤 / 固定吸收
## （模组里那些矿石桶）一律绕开，`armor_list` 每层直接归零，本体也归零 —— 必然致死。
## 防具归零走的是它自己的 setter，破损外观 / `signal_armor_death` / `on_armor_break()` 照常触发。
func clear_all_hp() -> int:
	for armor in armor_list:
		armor.begin_damage_settlement()
	for armor in armor_list:
		if armor.is_alive():
			armor.curr_hp = 0
			armor.is_hit_this_time = true
	curr_hp = 0
	return curr_hp


## **结算层**：僵尸的「防具链 → 本体」血量分配，重写自 `HpComponent`。
##
## ⚠️ 与基类一样是**管线末端**，业务代码请走 `DamageSystem.apply()`。
##
## 分配规则：`info.amount` 先沿着 `armor_list`（二类 → 一类，同类按 `absorb_priority`）
## 逐层走，每层吃多少、往下传多少由 `ArmorComponent.get_absorb_rule()` 按 `info.mode`
## （`ConstDamage.E_DamageMode`）决定；走完防具还剩多少就打本体。
##
## **新增一种伤害模式要改两处**：`ConstDamage.E_DamageMode` 的注释里点名的这两处 ——
## `ArmorComponent.get_absorb_rule()` 与本文件的 `get_body_damage()`。漏了就是静默不掉血
## （没有任何报错）。
##
## [param info] 本次伤害
## [return] 结算后的本体血量（**不含防具**，要总和请用 `get_all_hp()`）
func hp_loss(info: DamageInfo) -> int:
	var mode := info.mode
	var ori_hp: int = get_all_hp()
	## 传到下一层（防具 / 本体）的剩余伤害
	var remain := info.amount

	var is_body_hit := false
	if info.is_instant_kill:
		## 秒杀：伤害值与分配规则一律不看，防具与本体一起清空（见 `clear_all_hp()`）
		## 本体本来就 0（已经死了）就不算"本体挨打"，与常规分支的口径保持一致
		is_body_hit = curr_hp > 0
		clear_all_hp()
	else:
		for armor in armor_list:
			armor.begin_damage_settlement()

		for armor in armor_list:
			if remain <= 0:
				break
			if not armor.is_alive():
				continue
			remain = armor.absorb_damage(mode, remain)

		## 血量>0 且防具链没吃完
		if curr_hp > 0 and remain > 0:
			is_body_hit = true
			curr_hp -= get_body_damage(mode, remain)

	var loss_hp: int = ori_hp - get_all_hp()
	var is_drop := info.is_drop_2
	if is_instance_valid(owner_character) and owner_character.is_death and not info.is_drop_on_death:
		is_drop = false

	## 组件发射掉血信号,僵尸发射僵尸掉血信号给僵尸管理器处理残半刷新
	signal_zombie_hp_loss.emit(loss_hp)
	for armor in armor_list:
		if armor.is_hit_this_time:
			armor.notify_hp_loss(is_drop, info.trigger_sfx)

	if is_body_hit:
		signal_hp_loss.emit(curr_hp, is_drop)
		## 如果有受击音效并且触发受击音效
		if sfx_be_attack_body != SoundManager.TypeBeAttackSFX.Null and info.trigger_sfx:
			SoundManager.play_be_attack_SFX(sfx_be_attack_body)

	_refresh_armor_bars()
	return curr_hp


## 防具链走完之后，本体该吃多少
## （保龄球 / 锤子那几个模式打本体是**固定值**，与传进来的剩余伤害无关）
func get_body_damage(mode: ConstDamage.E_DamageMode, remain: int) -> int:
	match mode:
		ConstDamage.E_DamageMode.BowlingFront, ConstDamage.E_DamageMode.BowlingSide:
			return 1800
		ConstDamage.E_DamageMode.Hammer:
			return curr_hp
		_:
			return remain


## 小僵尸大麻烦更新僵尸血量（本体 + 每层防具一起减半）
func update_mini_zombie_hp():
	max_hp /= 2
	for armor in armor_list:
		armor.update_mini_zombie_hp()
	curr_hp = max_hp
	_refresh_armor_bars()


#region 防具查询（宿主与消费方一律走这里，不要自己去找节点）
## 重新收集防具并重排挨打顺序
##
## 谁用：运行期才挂上防具的场合（`Zombie000Base.add_armor()`，热注册僵尸在自己的脚本里装防具）。
## 组件比宿主先 `_ready()`，本组件的 `component_ready()` 那时已经收过一次了，
## 后来加的节点不在表里 —— 补挂完必须调一次，否则那一层**根本不参与伤害结算**（静默不掉血）。
func collect_armors() -> void:
	_collect_armors()
	_refresh_armor_bars()


## 本角色的所有防具（已按挨打顺序排好）
func get_all_armors() -> Array[ArmorComponent]:
	return armor_list


## 按类型取一件防具（同类型有多件时返回最外层那件）；没有返回 null
func get_armor_by_type(armor_type: ConstArmor.E_ArmorType) -> ArmorComponent:
	for armor in armor_list:
		if armor.armor_type == armor_type:
			return armor
	return null


## 是否存在「免疫减速」的防具（原版口径：还举着二类防具就不吃减速）
## 具体由哪件防具免疫，是**防具组件自己**回答的（见 `ArmorComponent.is_immune_slow()`）
func is_immune_slow() -> bool:
	for armor in armor_list:
		if armor.is_alive() and armor.is_immune_slow():
			return true
	return false


## 是否存在「免疫黄油定身」的防具
func is_immune_butter() -> bool:
	for armor in armor_list:
		if armor.is_alive() and armor.is_immune_butter():
			return true
	return false


## 找一件还没被吸走的铁器防具（磁力菇用）；没有返回 null
func get_magnet_armor() -> ArmorComponent:
	for armor in armor_list:
		var iron_node := armor.get_iron_node()
		if armor.is_alive() and iron_node != null and not iron_node.is_be_magnet:
			return armor
	return null


## 把某一层防具（以及排在它前面、还没破的那些更外层防具）打掉。
##
## 走伤害管线而不是直接给 `curr_hp` 赋 0：这条路径同样是"一次伤害"，
## 免疫 / 统计 / 联机事件都该经过它（与重写前 `_clear_armor_hp()` 的做法一致）。
## [param armor] 要打掉的那一层
## [param is_drop_on_death] 死亡时是否掉落（磁力菇吸走铁器不掉落）
## [param is_drop_2] 掉落的额外条件（两个条件都满足才掉）
## [param is_trigger_sfx] 是否播受击音效（气球被挤破算"受击"，磁力菇吸走铁器不算）
func break_armor(armor: ArmorComponent, is_drop_on_death: bool = true,
		is_drop_2: bool = true, is_trigger_sfx: bool = false) -> void:
	if armor == null or not armor.is_alive():
		return
	## 用「从最外层到这一层的血量之和」当伤害值：Norm 模式会沿防具链溢出扣完，
	## 不多不少刚好把这一层（和它外面那些）打光，不会碰到更内层与本体
	var total := 0
	for one in armor_list:
		total += one.curr_hp
		if one == armor:
			break
	if total <= 0:
		return
	var info := DamageInfo.create(owner_character, total,
		ConstDamage.E_DamageMode.Norm, ConstDamage.E_DamageCause.Script)
	info.is_drop_on_death = is_drop_on_death
	info.is_drop_2 = is_drop_2
	info.trigger_sfx = is_trigger_sfx
	DamageSystem.apply(info)
#endregion


#region 防具收集与血条
## 收集角色根目录下的所有防具组件并排好挨打顺序
func _collect_armors() -> void:
	armor_list.clear()
	if owner == null:
		return
	for child in owner.get_children():
		if child is ArmorComponent:
			armor_list.append(child)
	armor_list.sort_custom(_sort_armor)


## 二类在前、一类在后；同类按 `absorb_priority` 从大到小；再相同按节点顺序
func _sort_armor(a: ArmorComponent, b: ArmorComponent) -> bool:
	if a.armor_class != b.armor_class:
		return a.armor_class > b.armor_class
	if a.absorb_priority != b.absorb_priority:
		return a.absorb_priority > b.absorb_priority
	return a.get_index() < b.get_index()


## 刷新两根防具血条（显示的是**该类防具的血量之和**）
func _refresh_armor_bars() -> void:
	_refresh_one_armor_bar(ConstArmor.E_ArmorClass.Armor1, armor_1_control,
		progress_bar_hp_armor_1, label_hp_armor_1)
	_refresh_one_armor_bar(ConstArmor.E_ArmorClass.Armor2, armor_2_control,
		progress_bar_hp_armor_2, label_hp_armor_2)


func _refresh_one_armor_bar(armor_class: ConstArmor.E_ArmorClass, control: Control,
		progress_bar: ProgressBar, label: Label) -> void:
	var total_max := 0
	var total_curr := 0
	for armor in armor_list:
		if armor.armor_class != armor_class:
			continue
		total_max += armor.max_hp
		total_curr += armor.curr_hp
	control.visible = total_max > 0 and total_curr > 0
	label.text = str(total_curr)
	progress_bar.value = (float(total_curr) / total_max) if total_max > 0 else 0.0
#endregion
