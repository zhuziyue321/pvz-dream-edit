extends "../mod_base.gd"
## 模组「水盆」：新增一只**战斗植物** —— 水盆（`PlantIds.WATER_BOWL`）
##
## ★ 水盆是什么：**花盆的水生形态**。它跟花盆一模一样（同样摆在草地上 / 屋顶上、
##   同样占格子的下层、同样能承载上层植物、同样被啃被铲被偷），**只有一点不同**：
##   盆里装的是水，于是（1）**上面只接水生植物**（海蘑菇 / 缠绕海草）——
##   于是在草地上也能种海蘑菇，这是原版没有的组合，所以整件东西放在模组里；
##   （2）上层植物的**影子藏掉**（影子落在水面上看着别扭），见 `water_bowl_plant.gd`。
##
## ★ 动画是白拿的，一行都没重写：水盆直接实例化花盆那份 `plant_flower_pot.tscn`
##   （`plant_water_bowl.tscn`），而花盆场景里的 AnimationTree 早就按 `is_water`
##   分了 `Pot_idle` / `Pot_waterplants` 两支；战斗侧那只花盆从来没人给它设过
##   `is_water`（读的是个不存在的属性，所以永远播 `Pot_idle`），
##   水盆脚本把这个属性打开，同一套动画就切到水盆那一支。
##
## ★ 装一株植物要做的四件事（登记 / 卡片 / 卡面 / 解锁）全在本体的通用口子里，
##   本模组只填一张配方（见 `_build_recipe()`）：
##   1. `PlantRuntimeRecipe` —— 「这株植物是什么」：场景、冷却、阳光、地形、卡面取哪一帧；
##   2. `PlantRuntimeKit`    —— 「一键装 / 卸」：登记进注册表、往 `AllCards` 插卡并画卡面、解锁，
##                              卸载时反向全撤（坑都收在它里面，见它的类注释）；
##   3. `Plant000DownBase.own_condition_bit` —— 水盆在场景里声明「我占 64 水盆位」，
##      种下后格子地形 = 1 无 + 64 水盆 → 普通植物（条件 22：草地 / 花盆 / 睡莲）认不出这一位；
##   4. `CharacterRegistry.add_runtime_plant_condition_bit()` —— 给水生植物**加**这一位，
##      它们就既能种进水里、也能种进水盆（按位查用 `collect_plant_types_by_condition()`，
##      不写死"海蘑菇 / 缠绕海草"这两张卡）。
##
## 装载时机与写法见 [模组机制](../../docs/参考存档/模组机制.md)：
##   开关与设置都在 `user://<用户名>/mod_config.ini` 的 `[water_bowl]` 段，默认关闭。
##
## 待办：现在是「装了就能用」（模组装载时直接解锁）。正式解锁（通关某关赠送 / 商店购买）留作后续 ——
##   那要动本体商店与通关奖励表，本模组不越界去改。

## 跨文件引用：`user://` 下脚本的 class_name **不会注册成全局类**（实测 Godot 4.6.2），
## 所以上级目录的文件一律 preload 成常量再引用，不能写 `extends ModBase`
const ModBase := preload("../mod_base.gd")

#region 常量
## 水盆的植物 id（本体早就留了这个常量；新模组其实不必再要槽位 —— 见 `PlantRuntimeRecipe.plant_type`）
const WATER_BOWL := PlantIds.WATER_BOWL
## 水盆的场景：花盆那份 + 打开 `is_water`（见 `water_bowl_plant.gd`）
const PLANT_SCENE := preload("plant_water_bowl.tscn")
## 卡面形象从这一支动画里取（花盆场景里 AnimationTree 的第二支，见 `plant_flower_pot.tscn`）
const ANIM_WATER_BOWL := &"Pot_waterplants"
## 花盆：卡面形象只在取帧失败时兜底借用
const FLOWER_POT := PlantIds.FLOWER_POT

## 水盆的冷却与阳光跟花盆保持一致
const COOL_TIME := 7.5
const SUN_COST := 25
#endregion

## 本模组这只植物的「装 / 卸」：登记 + 卡片 + 卡面 + 解锁都归它管
var _kit := PlantRuntimeKit.new()
## 被本模组加过地形位的水生植物（关掉时按这份名单还原）
var _patched_water_plants: Array[StringName] = []


func get_mod_id() -> StringName:
	return ModIds.WATER_BOWL


func get_mod_name() -> String:
	return "水盆"


func get_mod_description() -> String:
	return "新增战斗植物「水盆」：摆在陆地上、只接水生植物（海蘑菇 / 缠绕海草）的盆，其余与花盆完全相同"


func get_mod_categories() -> Array[StringName]:
	return [ModCategory.ADD_UNIT]


## 模组页面右侧：它做了什么
func create_detail_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(ModBase.create_detail_label(
		"作用：新增一只战斗植物「水盆」，它是花盆的水生形态 —— 用的就是花盆场景里那条 Pot_waterplants 动画"))
	box.add_child(ModBase.create_detail_label(
		"怎么玩：跟花盆一样摆在草地 / 屋顶上（25 阳光、冷却 7.5 秒），但盆里装的是水，上面只接水生植物：海蘑菇、缠绕海草 —— 草地上也能种海蘑菇了"))
	box.add_child(ModBase.create_detail_label(
		"盆里是水，所以上层植物的影子藏掉了（落在水面上看着别扭）；水盆被铲掉后影子还回去"))
	box.add_child(ModBase.create_detail_label(
		"其余与花盆完全相同：占格子下层、承载上层植物、被啃被铲被蹦极偷、手套能搬 —— 这些都在本体那一份底部植物里，本模组不复制"))
	box.add_child(ModBase.create_detail_label(
		"卡位：水盆的卡追加在所有已有植物卡之后（选卡界面最后一页）；装上本模组即可选用（正式的通关 / 商店解锁留作后续）"))
	box.add_child(ModBase.create_detail_label(
		"关掉本模组：卡片、植物、解锁与种植判据一并撤掉，回到原版"))
	return box


#region 生命周期
func install() -> void:
	if not _kit.install(_build_recipe()):
		return
	## 注册 / 解锁都只是「这株植物存在」，还要登记进「可选植物列表」才进选卡界面
	## （见 AllCards.add_selectable_plant）—— 水盆是要给玩家挑的，所以补这一行
	_kit.make_selectable()
	_open_water_plants_to_bowl()
	_register_almanac_entry()


## 每局补一次解锁：读档会按存档记录重建 `curr_plant`（见 `SaveService._build_curr_plant`），
## 只装一次的话，玩家一读档水盆就又没了
func install_to_main_game(_main_game: MainGameManager) -> void:
	_kit.unlock()


func uninstall() -> void:
	_restore_water_plants()
	_kit.uninstall()
	Global.global_read_data.clear_extra_almanac_entry(WATER_BOWL)
#endregion


#region 图鉴条目
## 本模组这只植物的图鉴条目：**自己登记，自己摘**
##
## ★ 为什么不在本体的 `almanac_data.json` 里替水盆写一条：本体不认识任何一个模组（硬约束），
##   图鉴的「扩展植物」页只认运行期登记的条目（见 `GlobalReadData.register_extra_almanac_entry`）。
##   关掉模组就把条目摘掉 —— 没装模组时不该在图鉴里看见一个谁都种不出来的盆。
func _register_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(WATER_BOWL, {
		"名字": "水盆",
		"描述": "水盆是花盆的水生形态：摆在草地 / 屋顶上，盆里装的是水，上面只接水生植物（海蘑菇 / 缠绕海草）。",
		"参数": {
			"强度": "同花盆",
			"可种在": "草地 / 屋顶",
			"上面只接": "水生植物（海蘑菇 / 缠绕海草）"
		},
		"简介": "“我跟花盆是同一只盆，”水盆说，“只不过我比较想得开 —— 别人装土，我装水，于是草地上也有了海。”",
		"提示": "由模组「水盆」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Pool"
	})
#endregion


#region 水盆这张配方
## 填一张 `PlantRuntimeRecipe`：水盆与花盆的**差别**只有「地形位」和「卡面取哪一帧」，
## 冷却 / 阳光 / 占下层这些跟花盆一样的值都写在配方里，其余（被啃被铲被偷、承载上层植物）
## 由植物脚本继承本体的 `Plant000DownBase`，一行都不用写。
func _build_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = WATER_BOWL
	recipe.plant_name = &"WaterBowl"
	recipe.plant_scene = PLANT_SCENE
	recipe.cool_time = COOL_TIME
	recipe.sun_cost = SUN_COST
	## 摆在陆地上（草地 / 屋顶），水池行种不了 —— 与花盆同一套
	recipe.condition_bits = PlantConditionBits.GRASS | PlantConditionBits.ROOF
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Down
	## 水盆这个形态只存在于动画里（卡面借不到现成的手摆形象），所以卡面从动画取帧；
	## 取帧失败时退回花盆那张脸（卡面一空，手持会报「卡片静态角色为空」拿不起来）
	recipe.card_face_anim = ANIM_WATER_BOWL
	recipe.card_face_fallback_plant = FLOWER_POT
	return recipe
#endregion


#region 水生植物可以种进水盆
## 水生植物额外认「水盆」这一位
##
## 「哪些是水生植物」是**按地形位查**出来的（条件 = 8 水、占普通位 → 现在只有海蘑菇与缠绕海草），
## 不写死两张卡：将来再加纯水生的植物，不用回头改本模组。
## 加位走 `add_runtime_plant_condition_bit()`（在它们原有条件上按位或），
## 不整份换掉 —— 换要自己抄一遍原条件，抄漏一位就丢一种地形。
func _open_water_plants_to_bowl() -> void:
	_patched_water_plants = Global.character_registry.collect_plant_types_by_condition(
		PlantConditionBits.WATER)
	for plant_type in _patched_water_plants:
		Global.character_registry.add_runtime_plant_condition_bit(
			plant_type, PlantConditionBits.WATER_BOWL)
	Log.info("水盆模组：可以种进水盆的水生植物 = %s" % str(_patched_water_plants))


## 关掉模组：把水生植物的条件换回静态表里那一份
func _restore_water_plants() -> void:
	for plant_type in _patched_water_plants:
		Global.character_registry.clear_runtime_plant_condition(plant_type)
	_patched_water_plants.clear()
#endregion
