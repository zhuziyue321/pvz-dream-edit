extends "res://src/mods/mod_base.gd"
## 模组「PVZ2」：把《植物大战僵尸 **2**》的角色搬进本作
## （当前五只：**菜问**、**潜伏芹菜**、**火焰豌豆射手**、**豌豆荚**、**毒液豌豆**）
##
## ★ 为什么做成模组：本仓库的目标是复刻**原版（PVZ1）**。这五株都是 PVZ2 的植物，
##   原版没有，美术甚至不是同一套格式（PVZ2 是 PAM / XFL，不是原版的 `.reanim`）。
##   判据就一条：原版有 → 本体；原版没有 → 模组。关掉本模组 = 回到原版。
##
## ★ 动画全部走**模组「PAM 动画播放器」**（`ModIds.PAM`，本模组声明依赖它）：
##   `..\2代解包资源` 里的 PAM 由 `tools/bake_pam_bin.py` 离线烘成
##   「一张图集 + 一个自包含 `.pam.bin`」，运行时由播放器在 `_draw()` 里按帧画四边形
##   —— 零节点、零动画轨道（一株几百帧换成动画资源要几十万关键帧，那条路走不通）。
##
##   ★ 播放器为什么**不在本目录里**：PVZ2 的植物、子弹、僵尸、特效将来都要播 PAM，
##     别的模组（联机同步的敌人 / 自制关卡里摆一只 PVZ2 单位）也要用同一套；
##     跟着内容走的话第二家就得复制一份。所以播放口径只在「PAM 动画播放器」里维护一次，
##     本模组通过 `ModIds.PAM` 依赖它，再由 `pam_bridge.gd` 按**当前加载根**取脚本与素材
##     （`.tscn` 里不写死 `res://` 路径，理由见 `pam_bridge.gd` 文件头）。
##
##   ★ 卡面**不能**走通用取帧：`PlantRuntimeRecipe.build_card_face()` 找的是 `AnimationPlayer`，
##     PAM 播放器没有 —— 取帧不报错，只返回一棵空树（卡面全空、手持报「卡片静态角色为空」）。
##     所以五株各有一个 `*_recipe.gd` 覆盖那一步，给一个**定格一帧**的播放器节点。
##
## ★ 数值来自 `..\2代解包资源` 的 RTON（**不是**照 wiki 抄的）：
##   · 阳光 / 冷却 / 血量 / 近战伤害 —— `PACKAGES/PLANTTYPES.RTON` + `PACKAGES/PLANTPROPERTIES.RTON`
##   · 子弹伤害 —— `PACKAGES/PROJECTILETYPES.RTON`（`PeaDefault` 20 / `FirePeaDefault` 40 /
##     `PoisonPeaDefault` 10）
##   读取链路见 `tools/rton2json.py`（RTON → JSON）与 `tools/bake_pvz2_assets.py`（一键重烘）。
##
##   ⚠️ 伤害是 PVZ2 口径原样搬过来的：本作僵尸血量比 PVZ2 低，会比原版更快被打死。
##      要平衡就改各株 `*_plant.gd` 顶部的 `@export`（场景里也能改），别改这里的常量。
##
## ★ 装一只植物的四件事（登记 / 卡片 / 卡面 / 解锁）全在本体的通用口子里，
##   本模组只填一张配方，其余（被啃 / 被铲 / 被蹦极偷 / 手套搬运）由植物脚本继承
##   `Plant000Base`，一行都不用写。豌豆荚的「同格叠层」也走通用口子
##   （`Plant000Base.can_stack_up()` / `try_stack_up()`）。
##
## 装载时机与写法见 [模组机制](../../docs/参考存档/模组机制.md)：
##   开关与设置都在 `user://<用户名>/mod_config.ini` 的 `[pvz2]` 段，默认关闭。

## 跨文件引用：`user://` 下脚本的 `class_name` **不会注册成全局类**（实测 Godot 4.6.2），
## 所以上级目录的文件一律 preload 成常量再引用，不能写 `extends ModBase`
const ModBase := preload("res://src/mods/mod_base.gd")
## 五株的配方（子类：只为覆盖「卡面取帧」那一步，见各文件头）
const BonkChoyRecipe := preload("bonkchoy/bonkchoy_recipe.gd")
const CeleryStalkerRecipe := preload("celerystalker/celerystalker_recipe.gd")
const FirePeashooterRecipe := preload("firepeashooter/firepeashooter_recipe.gd")
const PeaPodRecipe := preload("peapod/peapod_recipe.gd")
const GooPeashooterRecipe := preload("goopeashooter/goopeashooter_recipe.gd")

#region 常量
## 植物的 id：字符串 id 自己起即可，本体不必再留 `PlantIds` 空槽位
## （见 `PlantRuntimeRecipe.plant_type`；`PlantIds.WATER_BOWL` 那种槽位是编号时代的产物）
const BONK_CHOY := &"pvz2_bonkchoy"
const CELERY_STALKER := &"pvz2_celerystalker"
const FIRE_PEA := &"pvz2_firepeashooter"
const PEA_POD := &"pvz2_peapod"
const GOO_PEA := &"pvz2_goopeashooter"

## 场景：本体 `plant_base.tscn` + 一个**空**的动画挂点（脚本由 `pam_bridge.gd` 运行时挂上）
const BONK_CHOY_SCENE := preload("bonkchoy/plant_bonkchoy.tscn")
const CELERY_STALKER_SCENE := preload("celerystalker/plant_celerystalker.tscn")
const FIRE_PEA_SCENE := preload("firepeashooter/plant_firepeashooter.tscn")
const PEA_POD_SCENE := preload("peapod/plant_peapod.tscn")
const GOO_PEA_SCENE := preload("goopeashooter/plant_goopeashooter.tscn")

## 阳光 / 冷却：RTON `PLANTTYPES.RTON`（阳光）与 `PLANTPROPERTIES.RTON` 的 `PacketCooldown`
const BONK_CHOY_COOL_TIME := 5.0
const BONK_CHOY_SUN_COST := 150
const CELERY_STALKER_COOL_TIME := 15.0
const CELERY_STALKER_SUN_COST := 50
const FIRE_PEA_COOL_TIME := 5.0
const FIRE_PEA_SUN_COST := 175
const PEA_POD_COOL_TIME := 5.0
const PEA_POD_SUN_COST := 125
const GOO_PEA_COOL_TIME := 5.0
const GOO_PEA_SUN_COST := 100

## 卡面：大小 = 卡面节点里那层「场上缩放」× 这里的 0.4，
## 落点 (1, 14) 与本体手摆卡面同口径（`all_cards.tscn` 里那一批都是这个位置）
const PAM_CARD_FACE_SCALE := Vector2(0.4, 0.4)
const PAM_CARD_FACE_POSITION := Vector2(1, 14)
#endregion

## 每株植物一个 Kit（登记 + 卡片 + 卡面 + 解锁；卸的时候反向全撤）
var _kits: Array[PlantRuntimeKit] = []
## 本模组登记的那页选卡（句柄；-1 = 没登记）
var _choose_page := -1


func get_mod_id() -> StringName:
	return ModIds.PVZ2


func get_mod_name() -> String:
	return "PVZ2"


func get_mod_description() -> String:
	return ("新增《植物大战僵尸 2》的角色（菜问 / 潜伏芹菜 / 火焰豌豆射手 / 豌豆荚 / 毒液豌豆）：PAM 动画离线烘焙后接进来，原版没有这些角色")


func get_mod_categories() -> Array[StringName]:
	return [ModCategory.ADD_UNIT]


## 依赖「PAM 动画播放器」：打开本模组会把它一起打开（关掉它本模组什么都动不了）
func get_mod_dependencies() -> Array[StringName]:
	return [ModIds.PAM]


## 模组页面右侧：它做了什么
func create_detail_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(ModBase.create_detail_label(
		"作用：新增五株战斗植物 —— 「菜问」「潜伏芹菜」「火焰豌豆射手」「豌豆荚」「毒液豌豆」（PVZ2 角色）。原版没有这几株，连美术格式都不是原版那套 —— 所以整件东西放在模组里"))
	box.add_child(ModBase.create_detail_label(
		"动画：全部走模组「PAM 动画播放器」。PVZ2 的 PAM 由 `tools/bake_pam_bin.py` 离线烘成「一张图集 + 一个 .pam.bin」，运行时一个 Node2D 按帧画四边形 —— 零节点、零动画轨道"))
	box.add_child(ModBase.create_detail_label(
		"依赖：本模组依赖「PAM 动画播放器」，打开本模组会把它一起打开；反过来单独开播放器没有任何可见变化"))
	box.add_child(ModBase.create_detail_label(
		"美术：PVZ2 那套装扮（草帽 / 海盗帽 / 水手装 / 围巾 / 腰带…）不带 —— 它们在 PAM 里和本体同一条时间轴，已按部件名单关掉"))
	box.add_child(ModBase.create_detail_label(
		"数值：阳光 / 冷却 / 近战伤害 / 子弹伤害全部取自解包资源的 RTON（`PLANTTYPES` / `PLANTPROPERTIES` / `PROJECTILETYPES`），不是抄 wiki"))
	box.add_child(ModBase.create_detail_label(
		"菜问：近战打本行左右两格。阳光 150、冷却 5 秒、出手 0.35 秒；直拳 15，能一拳打死时改上勾拳 60"))
	box.add_child(ModBase.create_detail_label(
		"潜伏芹菜：伏击。平时缩在地里（僵尸从头上走过去也不吃它），左边一有僵尸就冒出来照着后背连打。阳光 50、冷却 15 秒、每拳 100"))
	box.add_child(ModBase.create_detail_label(
		"火焰豌豆射手：直线射手，一发火豌豆 40。阳光 175、冷却 5 秒、攻击间隔 1.4 秒"))
	box.add_child(ModBase.create_detail_label(
		"豌豆荚：叠层射手，同格最多 5 层，攻击时按层数连发（5 层一次吐 5 颗）。阳光 125、冷却 5 秒、每颗 20"))
	box.add_child(ModBase.create_detail_label(
		"毒液豌豆：直线射手，单发 10（PVZ2 的「中毒持续掉血」本作没做，见植物脚本头）"))
	box.add_child(ModBase.create_detail_label(
		"卡位：本模组自己登记一页选卡（排在原版植物页之后），五只按「菜问 → 潜伏芹菜 → 火焰豌豆 → 豌豆荚 → 毒液豌豆」排"))
	box.add_child(ModBase.create_detail_label(
		"关掉本模组：卡片、植物、解锁与图鉴条目一并撤掉，回到原版"))
	return box


#region 生命周期
func install() -> void:
	var choose_types: Array[StringName] = []
	for recipe: PlantRuntimeRecipe in [
		_build_bonkchoy_recipe(), _build_celerystalker_recipe(),
		_build_firepeashooter_recipe(), _build_peapod_recipe(),
		_build_goopeashooter_recipe(),
	]:
		var kit := PlantRuntimeKit.new()
		if not kit.install(recipe):
			## 一株登记失败只跳过这一株，别让整包模组起不来
			Log.error("PVZ2：%s 登记失败，已跳过" % str(recipe.get_display_name()))
			continue
		choose_types.append(kit.recipe.plant_type)
		_kits.append(kit)
	## 注册 / 解锁都只是「这株植物存在」，还要自己登记一页选卡才进选卡界面
	## （见 AllCards.register_plant_choose_page）：五株按上面的顺序排进本模组这一页
	if not choose_types.is_empty():
		_choose_page = AllCards.register_plant_choose_page(choose_types)
	_register_almanac_entries()


## 每局补一次解锁：读档会按存档记录重建 `curr_plant`（见 `SaveService._build_curr_plant`），
## 只装一次的话，玩家一读档这几株就又没了
func install_to_main_game(_main_game: MainGameManager) -> void:
	for kit: PlantRuntimeKit in _kits:
		kit.unlock()


func uninstall() -> void:
	## 先撤页再卸植物：页是模组自己登记的，Kit 不代撤
	AllCards.unregister_plant_choose_page(_choose_page)
	_choose_page = -1
	for kit: PlantRuntimeKit in _kits:
		kit.uninstall()
	_kits.clear()
	Global.global_read_data.clear_extra_almanac_entry(BONK_CHOY)
	Global.global_read_data.clear_extra_almanac_entry(CELERY_STALKER)
	Global.global_read_data.clear_extra_almanac_entry(FIRE_PEA)
	Global.global_read_data.clear_extra_almanac_entry(PEA_POD)
	Global.global_read_data.clear_extra_almanac_entry(GOO_PEA)
#endregion


#region 图鉴条目
## 五株的图鉴条目：**自己登记，自己摘**
##
## ★ 为什么不写进本体的 `almanac_data.json`：本体不认识任何一个模组（硬约束），
##   图鉴的「扩展植物」页只认运行期登记的条目（`GlobalReadData.register_extra_almanac_entry`）。
##   关掉模组就把条目摘掉 —— 没装模组时不该在图鉴里看见一只谁都种不出来的植物。
func _register_almanac_entries() -> void:
	Global.global_read_data.register_extra_almanac_entry(BONK_CHOY, {
		"名字": "菜问",
		"描述": "菜问是《植物大战僵尸 2》的近战植物：不吐子弹，抬起拳头就打本行左右相邻两格里的僵尸。",
		"参数": {
			"阳光": "150",
			"冷却": "5 秒",
			"伤害": "直拳 15 ／ 上勾拳 60（能一拳打死时自动改用上勾拳）",
			"出手间隔": "0.35 秒",
			"可种在": "草地 / 花盆 / 睡莲"
		},
		"简介": "“我从不远程。”菜问活动了一下腕子，“离得近，才谈得上诚意。”",
		"提示": "由模组「PVZ2」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})
	Global.global_read_data.register_extra_almanac_entry(CELERY_STALKER, {
		"名字": "潜伏芹菜",
		"描述": "潜伏芹菜是《植物大战僵尸 2》的伏击植物：平时缩在地里，僵尸从它头上走过去也没辙；左边一有僵尸，它就从土里冒出来照着后背连打，左边空了才缩回去。",
		"参数": {
			"阳光": "50",
			"冷却": "15 秒",
			"伤害": "每拳 100（左边还有僵尸就一直打）",
			"够得着": "左侧约一格半；右边来的僵尸它打不到，得先挨啃",
			"可种在": "草地 / 花盆 / 睡莲"
		},
		"简介": "“正面上我？那多没意思。”潜伏芹菜从土里探出半个脑袋，“等你走过去再说。”",
		"提示": "由模组「PVZ2」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})
	Global.global_read_data.register_extra_almanac_entry(FIRE_PEA, {
		"名字": "火焰豌豆射手",
		"描述": "火焰豌豆射手是《植物大战僵尸 2》的直线射手：本行右边有僵尸就朝前吐一颗火豌豆，一发 40 点伤害。",
		"参数": {
			"阳光": "175",
			"冷却": "5 秒",
			"伤害": "每颗火豌豆 40（火豌豆会取消目标的冰冻）",
			"攻击间隔": "1.4 秒",
			"可种在": "草地 / 花盆 / 睡莲"
		},
		"简介": "“豌豆是凉的，火是热的。”火焰豌豆射手清了清嗓子，“我这两样都有。”",
		"提示": "由模组「PVZ2」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})
	Global.global_read_data.register_extra_almanac_entry(PEA_POD, {
		"名字": "豌豆荚",
		"描述": "豌豆荚是《植物大战僵尸 2》的叠层射手：一个格子里最多种 5 层，每层一个头；攻击时按层数连发，5 层就一次吐 5 颗豌豆。",
		"参数": {
			"阳光": "125（每叠一层同样花 125）",
			"冷却": "5 秒",
			"伤害": "每颗豌豆 20，按层数连发（1~5 颗）",
			"攻击间隔": "1.5 秒",
			"可种在": "草地 / 花盆 / 睡莲（同格可叠 5 层）"
		},
		"简介": "“一颗也是种，五颗也是种。”豌豆荚把五个脑袋挤在一起，“挤一挤，火力就上来了。”",
		"提示": "由模组「PVZ2」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})
	Global.global_read_data.register_extra_almanac_entry(GOO_PEA, {
		"名字": "毒液豌豆",
		"描述": "毒液豌豆是《植物大战僵尸 2》的直线射手：本行右边有僵尸就朝前吐一颗毒豌豆。",
		"参数": {
			"阳光": "100",
			"冷却": "5 秒",
			"伤害": "每颗 10（PVZ2 的「中毒持续掉血」本作未实现，只保留直射伤害）",
			"攻击间隔": "1.4 秒",
			"可种在": "草地 / 花盆 / 睡莲"
		},
		"简介": "“我只是想让它们慢一点。”毒液豌豆擦了擦嘴，“慢到走不完这一行就行。”",
		"提示": "由模组「PVZ2」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})
#endregion


#region 五张配方
## 菜问：与本体植物的差别只有「场景 / 卡面 / 数值」，
## 被啃、被铲、被蹦极偷、手套搬运、睡觉、模仿者材质这些全在 `Plant000Base` 那一份里。
func _build_bonkchoy_recipe() -> PlantRuntimeRecipe:
	var recipe: PlantRuntimeRecipe = BonkChoyRecipe.new()
	recipe.plant_type = BONK_CHOY
	recipe.plant_name = &"BonkChoy"
	recipe.plant_scene = BONK_CHOY_SCENE
	recipe.cool_time = BONK_CHOY_COOL_TIME
	recipe.sun_cost = BONK_CHOY_SUN_COST
	## 普通陆生植物：草地 / 花盆 / 睡莲（与本体绝大多数植物同一套）
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	recipe.card_face_scale = PAM_CARD_FACE_SCALE
	recipe.card_face_position = PAM_CARD_FACE_POSITION
	return recipe


## 潜伏芹菜：卡面走 PAM 定格节点（子类里覆盖 `build_card_face()`）。
func _build_celerystalker_recipe() -> PlantRuntimeRecipe:
	var recipe: PlantRuntimeRecipe = CeleryStalkerRecipe.new()
	recipe.plant_type = CELERY_STALKER
	recipe.plant_name = &"CeleryStalker"
	recipe.plant_scene = CELERY_STALKER_SCENE
	recipe.cool_time = CELERY_STALKER_COOL_TIME
	recipe.sun_cost = CELERY_STALKER_SUN_COST
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	recipe.card_face_scale = PAM_CARD_FACE_SCALE
	recipe.card_face_position = PAM_CARD_FACE_POSITION
	return recipe


## 火焰豌豆射手：卡面同潜伏芹菜那条路（PAM 定格节点）。
func _build_firepeashooter_recipe() -> PlantRuntimeRecipe:
	var recipe: PlantRuntimeRecipe = FirePeashooterRecipe.new()
	recipe.plant_type = FIRE_PEA
	recipe.plant_name = &"FirePeashooter"
	recipe.plant_scene = FIRE_PEA_SCENE
	recipe.cool_time = FIRE_PEA_COOL_TIME
	recipe.sun_cost = FIRE_PEA_SUN_COST
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	recipe.card_face_scale = PAM_CARD_FACE_SCALE
	recipe.card_face_position = PAM_CARD_FACE_POSITION
	return recipe


## 豌豆荚：卡面同潜伏芹菜那条路；**叠层走本体通用口子**（`max_stack_layers = 5` 在场景里配）。
func _build_peapod_recipe() -> PlantRuntimeRecipe:
	var recipe: PlantRuntimeRecipe = PeaPodRecipe.new()
	recipe.plant_type = PEA_POD
	recipe.plant_name = &"PeaPod"
	recipe.plant_scene = PEA_POD_SCENE
	recipe.cool_time = PEA_POD_COOL_TIME
	recipe.sun_cost = PEA_POD_SUN_COST
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	recipe.card_face_scale = PAM_CARD_FACE_SCALE
	recipe.card_face_position = PAM_CARD_FACE_POSITION
	return recipe


## 毒液豌豆：卡面同上（新增的一株，见 `goopeashooter/goopeashooter_plant.gd`）。
func _build_goopeashooter_recipe() -> PlantRuntimeRecipe:
	var recipe: PlantRuntimeRecipe = GooPeashooterRecipe.new()
	recipe.plant_type = GOO_PEA
	recipe.plant_name = &"GooPeashooter"
	recipe.plant_scene = GOO_PEA_SCENE
	recipe.cool_time = GOO_PEA_COOL_TIME
	recipe.sun_cost = GOO_PEA_SUN_COST
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	recipe.card_face_scale = PAM_CARD_FACE_SCALE
	recipe.card_face_position = PAM_CARD_FACE_POSITION
	return recipe
#endregion
