extends RefCounted
## 明日方舟模组的**精英化规则共享契约**（入口 `arknights_mod.gd` 与将来的脚本共用；
## 单独一份防 `preload` 成环，照 `hammer_settings.gd` / `glove_settings.gd` 的拆法）：
##   · 精英副本的 id / 命名规则、哪些原版植物要有副本（排除名单）
##   · 精英加成数值（默认 profile + 按植物覆盖表）
##   · 「普通关 / 特殊关」判据 + 「特殊关卡注明用原版」名单
##   · 实例层加血 / 加伤 / 加法抗（幂等，由格子的种植信号驱动）
##
## ⚠️ 这里**不写** `class_name`：`user://` 下的脚本不注册全局类（实测 Godot 4.6.2），
##    引用方一律 `const ArknightsElite := preload("arknights_elite.gd")`。
## ⚠️ `user://` 下 `var x :=` 推断自无类型返回值会被判编译错误（见 `eco_wiring.gd` 头注），
##    从数组 / `get_node_or_null()` / `.get()` 取出来的值一律显式写类型。

const ArknightsStats := preload("arknights_stats.gd")

#region 精英副本的 id 与命名
## 精英副本 id = 前缀 + 原版 id（如 `arknights_elite_pea_shooter_single`）。
## 带模组前缀：不会撞内置植物（`register_runtime_plant()` 会拒），也不会撞别的模组
const ID_PREFIX := "arknights_elite_"
## 精英副本的显示名后缀（卡面 / 日志 / 图鉴用；原版 PlantName 是内部英文名，照旧拼后缀）
const NAME_SUFFIX := "_Elite"

## 不给精英副本的植物（工具 / 特殊段，给了也没有意义）：
##   · 模仿者：它的「副本」就是复制别人，再造一层精英模仿者语义重复
##   · 萌芽：教程用的工具植物（没有卡）
##   · 保龄球三兄弟：只属于保龄球迷你游戏，不进选卡流程
## 其余「在 `PlantInfoData.PLANT_INFO` 里且进了 `PlantIds.ALL`」的内置植物都要有副本；
## 别的模组运行期注册的植物（菜问 / 水盆…）**不**做副本 —— 跨模组耦合，那个模组关掉就挂
const EXCLUDED_PLANT_TYPES: Array[StringName] = [
	PlantIds.IMITATER,
	PlantIds.SPROUT,
	PlantIds.WALL_NUT_BOWLING,
	PlantIds.WALL_NUT_BOWLING_BOMB,
	PlantIds.WALL_NUT_BOWLING_BIG,
]

## 原版植物 id → 它的精英副本 id
static func elite_id_of(plant_type: StringName) -> StringName:
	return StringName(ID_PREFIX + str(plant_type))


## 一个植物 id 是不是本模组的精英副本；是则返回它的原版 id，不是返回 `PlantIds.NULL`
static func original_type_of(plant_type: StringName) -> StringName:
	if not str(plant_type).begins_with(ID_PREFIX):
		return PlantIds.NULL
	return StringName(str(plant_type).substr(ID_PREFIX.length()))


## 要有精英副本的原版植物清单（安装时按它逐个登记）
static func elite_target_types() -> Array[StringName]:
	var targets: Array[StringName] = []
	for plant_type: StringName in PlantIds.ALL:
		if EXCLUDED_PLANT_TYPES.has(plant_type):
			continue
		if not PlantInfoData.PLANT_INFO.has(plant_type):
			continue
		if Global.character_registry.is_runtime_plant(plant_type):
			continue
		targets.append(plant_type)
	return targets
#endregion


#region 精英加成数值（「一定的加强」配在这）
## 默认 profile：每株植物的精英副本都按这套加强（明日方舟「精英化」= 全面小幅提升 + 降价提速）
const HP_MULT := 2.0				## 血量 ×2
const DAMAGE_MULT := 1.5			## 子弹 / 爆炸 / 大嘴花啃咬伤害 ×1.5
const SUN_MULT := 0.8				## 阳光消耗 ×0.8（向上取整，至少 1）
const COOL_MULT := 0.8				## 种植冷却 ×0.8
const DEFENSE_ADD := 15				## 额外 +15 防御力（接本模组的伤害减免，见 arknights_stats.gd）
const SPELL_RESIST_ADD := 15.0		## 额外 +15% 法术抗性

## 按植物覆盖默认值：键 = 原版植物 id，值 = 只写要改的那几项
## （例：`PlantIds.CHERRY_BOMB: {&"hp_mult": 1.0}` —— 樱桃炸弹是一次性的，加血没意义）
const ELITE_STATS: Dictionary = {
	## 填法：PlantIds.PLANT_NAME: {&"hp_mult": 2.0, &"damage_mult": 1.5},
}

## 取某株植物的精英加成（默认 profile 与覆盖表合并）
static func buffs_of(plant_type: StringName) -> Dictionary:
	var buffs: Dictionary = {
		&"hp_mult": HP_MULT,
		&"damage_mult": DAMAGE_MULT,
		&"sun_mult": SUN_MULT,
		&"cool_mult": COOL_MULT,
		&"defense_add": DEFENSE_ADD,
		&"spell_resist_add": SPELL_RESIST_ADD,
	}
	var override: Variant = ELITE_STATS.get(plant_type)
	if override != null:
		buffs.merge(override as Dictionary, true)
	return buffs
#endregion


#region 普通关 / 特殊关
## **特殊关卡注明使用原版植物**：列在这里的关卡（level_id，即关卡脚本 basename）
## 不用精英版。没列的关卡按 `is_general_level()` 的数据判据走。
## 预置一跳：蹦极闪电战本体**没有**数据字段标记它（只在关卡脚本里，见特殊关卡.md §40-63），
## 所以在这里显式注明
const LEVELS_USE_ORIGINAL: Array[StringName] = [
	&"adventure_05_05",
]

## 当前关是不是「普通关」（普通关 = 玩家的植物全部以精英版呈现）：
##   冒险模式 + 正常选卡卡槽 + 非砸罐子 / 我是僵尸 / 僵王 / 种子雨 / 保龄球 / 传送门 / 锤僵尸
## 传送带关（1-5 / 1-10 / 2-10…）card_mode 不是 Norm，算**特殊关**（传送带是特殊关卡机制）
static func is_general_level(para) -> bool:
	if para == null:
		return false
	## level_id 是 String，与 Array[StringName] 比较按字符值判等（String / StringName 可互比）
	if para.level_id in LEVELS_USE_ORIGINAL:
		return false
	if para.game_mode != MainSceneRegistry.MainScenes.ChooseLevelAdventure:
		return false
	if para.card_mode != ConstLevelData.E_CardMode.Norm:
		return false
	if para.is_pot_mode or para.is_zombie_mode:
		return false
	if para.has_boss():
		return false
	if para.is_seed_rain or para.is_bowling_stripe or para.is_portal_combat:
		return false
	if para.monster_mode != ConstLevelData.E_MonsterMode.Norm:
		return false
	return true

## 本局是否启用了精英化（入口在 `on_level_para_ready()` 里按关卡置位；
## 种植信号 handler 是静态域，读这一面旗标决定加不加成）
static var elite_level_active := false
#endregion


#region 种子包标记（区分精英卡）
## 「精英化」标记图标：文件就在本模组目录（`elite_icon.png`，原图 30x20、纯白）
##
## 落点是**植物右下角**（植物根节点在脚下，碰撞盒 `(0,-40)` / `40x80`，见 `plant_base.tscn`）：
## x = 27 压到右脚外侧、y = 0 落在脚下水平线上；再往右下就出卡边（会卡片裁掉）。
## 原图纯白，卡片底图是浅绿 / 紫 —— 染成蓝色才看得清（`ICON_COLOR` 是乘法）。
const ICON_FILE := "elite_icon.png"
const ICON_POSITION := Vector2(27.0, 0.0)
## 标记自身的缩放（1 = 原图 30x20）；挂点那株植物本身缩到 0.5，所以卡面上是 15x10
const ICON_SCALE := Vector2(1.0, 1.0)
const ICON_COLOR := Color(0.25, 0.55, 1.0)
## 标记节点名（幂等判据：卡面植物下已经有它就不再贴）
const ICON_NODE_NAME := &"EliteMark"

## 给**种子包**（卡片）贴标记
##
## ★ 卡面就是「本体那棵精灵树的缩小图片」（`all_cards.tscn` 里手摆的同一套
##   `CharacterStatic → PlantXXX → Body`，缩到 0.5），所以标记挂在**卡面那株植物**下：
##   跟着卡面的 0.5 一起缩，落点就是「植物右下角」；挂在卡面植物下（不是 `CardBg`）
##   才能跟着整卡的 `duplicate()` 走进待选区候选格。
## ⚠️ 卡面是 `PlantRuntimeKit` **帧末**才画的（`_build_card_face.call_deferred()`）：
##   这里也推到帧末，且比它晚入队（同帧按入队顺序执行），那时植物那一枝已经在卡上了。
static func mark_card(elite_type: StringName) -> void:
	_attach_card_mark.call_deferred(elite_type)


static func _attach_card_mark(elite_type: StringName) -> void:
	var card: Card = AllCards.all_plant_card_prefabs.get(elite_type, null)
	if card == null or not is_instance_valid(card) or not is_instance_valid(card.character_static):
		return
	if card.character_static.get_child_count() == 0:
		Log.warn("明日方舟：%s 的卡面没画出来，种子包上贴不了精英化标记" % str(elite_type))
		return
	var face: Node2D = card.character_static.get_child(0) as Node2D
	if face == null or face.get_node_or_null(NodePath(ICON_NODE_NAME)) != null:
		return
	var texture: Texture2D = ModManager.load_mod_asset(ModIds.ARKNIGHTS, ICON_FILE) as Texture2D
	if texture == null:
		Log.warn("明日方舟：读不到精英化标记 %s，种子包上分不出精英卡" % ICON_FILE)
		return
	var icon := Sprite2D.new()
	icon.name = ICON_NODE_NAME
	icon.texture = texture
	icon.position = ICON_POSITION
	icon.scale = ICON_SCALE
	icon.modulate = ICON_COLOR
	face.add_child(icon)
#endregion


#region 实例层加成（种下那一刻加一次，幂等）
## 加过精英成之后的标记（写在本体给模组留的 `mod_custom_effects` 容器里）
const KEY_ELITE_APPLIED := &"arknights_elite_applied"

## 有精英副本的植物集合（懒建缓存；判据与 `elite_target_types()` 一致）
static var _elite_target_set: Dictionary = {}

## 某株植物（按实例上的 `plant_type`）是不是精英化对象
static func is_elite_target(plant_type: StringName) -> bool:
	if _elite_target_set.is_empty():
		for target: StringName in elite_target_types():
			_elite_target_set[target] = true
	return _elite_target_set.has(plant_type)


## 给一株植物加精英加成（血量 / 伤害 / 防御 / 法抗），返回是否真的加了
##
## ★ 为什么按**实例的 plant_type** 判、不按精英 id 判：精英副本复用原版场景，
##   场景根节点烘焙的 `plant_type` 就是原版 id（连 `signal_plant_create` 发的也是它）——
##   实例上区分不出「这张卡是精英卡」。所以普通关里**按原版类型一视同仁**：
##   选卡界面走精英卡（名字 / 阳光 / 冷却是精英数据），实体与数值结算是精英加强版；
##   系统预选卡（`prechosen_cards` 那条路发的原版 id，见卡片选卡流程）也同样加强。
##   精英副本因此同时是「卡面 / 数据层的副本」+「全局数值替换」两层，缺一不可。
##
## ⚠️ 幂等：同一实例只加一次（标记在 `mod_custom_effects` 上）——
##    铲掉再种是新实例、手套搬运不重发种植信号，都不会重复叠加
## ⚠️ 时机：必须在植物 `_ready()` 之后调（读的是组件上的现值）——
##    由格子 `signal_plant_create` 驱动，那一瞬实例已就绪（见 `plant_cell.create_plant()` 末尾）
static func apply_instance_buffs(plant) -> bool:
	if plant == null or not is_instance_valid(plant):
		return false
	if not elite_level_active:
		return false
	var plant_type: StringName = plant.plant_type
	if not is_elite_target(plant_type):
		return false
	var effects: Dictionary = plant.mod_custom_effects
	if bool(effects.get(KEY_ELITE_APPLIED, false)):
		return false
	var buffs := buffs_of(plant_type)

	var hp_comp: HpComponent = plant.hp_component
	if hp_comp != null and float(buffs[&"hp_mult"]) != 1.0:
		var new_max: int = maxi(1, roundi(hp_comp.max_hp * float(buffs[&"hp_mult"])))
		hp_comp.max_hp = new_max
		hp_comp.curr_hp = new_max

	_apply_damage_buffs(plant, float(buffs[&"damage_mult"]))

	## 防御 / 法抗接本模组的伤害减免系统（单实例覆盖，效果结束由调用方清）
	ArknightsStats.set_instance_defense(plant, int(buffs[&"defense_add"]))
	ArknightsStats.set_instance_spell_resist(plant, float(buffs[&"spell_resist_add"]))

	effects[KEY_ELITE_APPLIED] = true
	return true


## 伤害加成落在三类组件上（覆盖绝大多数攻击植物）：
##   · 子弹类（豌豆家族 / 仙人掌 / 投手 / 猫尾草…）：`AttackComponentBulletBase.attack_value_bullet`
##   · 爆炸类（樱桃 / 土豆雷 / 毁灭菇）：`BombComponentBase.bomb_value`；
##     伤害已改由角色攻击力承载的（辣椒 / 寒冰菇）：`Character000Base.attack_value`
##   · 大嘴花：角色攻击力 `Character000Base.attack_value`（啃咬伤害，按原版类型点名）
## 其余植物（窝瓜 / 地刺 / 缠绕水草…）不吃这条伤害加成，只拿血量 / 防御 / 法抗
static func _apply_damage_buffs(plant, damage_mult: float) -> void:
	if damage_mult == 1.0:
		return
	var attack: AttackComponentBulletBase = \
		plant.get_node_or_null(^"AttackComponent") as AttackComponentBulletBase
	if attack != null:
		var base_value: int = attack.attack_value_bullet
		if base_value <= 0:
			## 组件上没写覆盖值：伤害在子弹场景自己的 `attack_value` 上，取那颗子弹的
			base_value = _bullet_base_attack(attack.attack_bullet_type)
		if base_value > 0:
			attack.attack_value_bullet = maxi(1, roundi(base_value * damage_mult))
	var bomb: BombComponentBase = plant.get_node_or_null(^"BombComponent") as BombComponentBase
	if bomb != null:
		## 辣椒 / 寒冰菇的伤害在角色攻击力上（> 0 已配）；其余炸弹仍读 `bomb_value`
		var plant_attack: int = int(plant.get("attack_value"))
		if plant_attack > 0:
			plant.set("attack_value", maxi(1, roundi(plant_attack * damage_mult)))
		else:
			bomb.bomb_value = maxi(1, roundi(bomb.bomb_value * damage_mult))
	## 大嘴花的啃咬伤害在角色攻击力上。地刺 / 钢地刺也用同一个字段，但它们按约定
	## 不吃这条加成，所以这里按原版类型点名，不做通用兜底（免得连地刺一起加强）
	if plant.get("plant_type") == PlantIds.CHOMPER:
		var bite_value: int = int(plant.get("attack_value"))
		if bite_value > 0:
			plant.set("attack_value", maxi(1, roundi(bite_value * damage_mult)))
#endregion


#region 小工具
## 某种子弹场景自带的基础伤害（造一颗出来读 `attack_value`，读完就释放；按类型缓存）
##
## 为什么读子弹而不是读植物组件：`attack_value_bullet` 默认 -1 = 「用子弹自己的值」，
## 基础伤害在子弹场景的 `@export var attack_value` 上，注册表里没有这一项
static var _bullet_attack_cache: Dictionary = {}

static func _bullet_base_attack(bullet_type: StringName) -> int:
	if bullet_type == &"":
		return -1
	var cached: Variant = _bullet_attack_cache.get(bullet_type)
	if cached != null:
		return int(cached)
	var value := -1
	var scene: PackedScene = Global.bullet_registry.get_bullet_scenes(bullet_type)
	if scene != null:
		var bullet: Node = scene.instantiate()
		if bullet != null:
			var raw: Variant = bullet.get("attack_value")
			if raw != null:
				value = int(raw)
			bullet.free()
	_bullet_attack_cache[bullet_type] = value
	return value
#endregion
