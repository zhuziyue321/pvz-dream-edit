extends "../mod_base.gd"
## 模组「PVZ2」：把《植物大战僵尸 **2**》的角色搬进本作（当前只有**菜问**）
##
## ★ 为什么做成模组：本仓库的目标是复刻**原版（PVZ1）**。菜问是 PVZ2 的植物，
##   原版没有这只角色，美术甚至不是同一套格式（PVZ2 是 PAM / XFL，不是原版的 `.reanim`）。
##   判据就一条：原版有 → 本体；原版没有 → 模组。关掉本模组 = 回到原版。
##
## ★ 动画是怎么来的（**不是**在本体里现做的）：
##   `res://mods_builtin/pvz2/bonkchoy/` —— 48 张从 PVZ2 的 XFL 里拆出来的 png（与脚本/场景同目录，模组自包含）；
##   `bonkchoy/bonkchoy_anim.tscn` —— PVZ2 的 PAM 动画**离线烘焙**的产物：
##     57 个 `Sprite2D` 复用槽（`draw_slot_00` ~ `draw_slot_56`）+ 一个 `AnimationPlayer`，
##     17 段动画全在里面（idle×3 / attack×7 / plantfood×6 / water），
##     每段靠 `visible` 轨道决定哪几个槽亮、靠 `texture` / `transform` 轨道画姿势。
##   烘焙工程不在本仓库里（仓库外的 `新建游戏项目/`，已被 `.gitignore` 排除）——
##   **本仓库只收它的产物**，不再自己解析 PAM。
##
## ★ 装一只植物的四件事（登记 / 卡片 / 卡面 / 解锁）全在本体的通用口子里，
##   本模组只填一张配方（见 `_build_recipe()`），其余（被啃 / 被铲 / 被蹦极偷 / 手套搬运）
##   由植物脚本继承本体的 `Plant000Base`，一行都不用写。
##
## 装载时机与写法见 [模组机制](../../docs/参考存档/模组机制.md)：
##   开关与设置都在 `user://<用户名>/mod_config.ini` 的 `[pvz2]` 段，默认关闭。

## 跨文件引用：`user://` 下脚本的 class_name **不会注册成全局类**（实测 Godot 4.6.2），
## 所以上级目录的文件一律 preload 成常量再引用，不能写 `extends ModBase`
const ModBase := preload("../mod_base.gd")

#region 常量
## 菜问的植物 id：字符串 id 自己起即可，本体不必再留 `PlantIds` 空槽位
## （见 `PlantRuntimeRecipe.plant_type`；`PlantIds.WATER_BOWL` 那种槽位是编号时代的产物）
const BONK_CHOY := &"pvz2_bonkchoy"
## 菜问的场景：本体 `plant_base.tscn` + PVZ2 那棵烘焙动画（见 `bonkchoy/bonkchoy_plant.gd`）
const PLANT_SCENE := preload("bonkchoy/plant_bonkchoy.tscn")
## 卡面形象从这一段动画里取第 0 帧（`AnimationFrameUtil` 会自己往深里找播放器）
const ANIM_IDLE := &"idle"
## 取帧失败时借大嘴花的脸（卡面一空，手持会报「卡片静态角色为空」拿不起来）
const FALLBACK_PLANT := PlantIds.CHOMPER

## 数值都是**模组自己的取值**，不是照 PVZ2 wiki 抄的 —— 要对齐请自己查过再改
const COOL_TIME := 7.5
const SUN_COST := 150
#endregion

## 本模组这只植物的「装 / 卸」：登记 + 卡片 + 卡面 + 解锁都归它管
var _kit := PlantRuntimeKit.new()


func get_mod_id() -> StringName:
	return ModIds.PVZ2


func get_mod_name() -> String:
	return "PVZ2"


func get_mod_description() -> String:
	return "新增《植物大战僵尸 2》的角色（当前只有菜问）：PVZ2 的 PAM 动画离线烘焙成 Godot 动画，原版没有这些角色"


## 模组页面右侧：它做了什么
func create_detail_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(ModBase.create_detail_label(
		"作用：新增战斗植物「菜问」（PVZ2 角色）。原版没有这只植物，连美术格式都不是原版那套 —— 所以整件东西放在模组里"))
	box.add_child(ModBase.create_detail_label(
		"动画：PVZ2 的 PAM 动画已经离线烘焙成「57 个贴图复用槽 + AnimationPlayer」的场景，17 段全在里面（待机三段循环、出拳七段、能量豆六段、浇水一段）。本仓库只收产物，不在运行时解析 PAM"))
	box.add_child(ModBase.create_detail_label(
		"美术：PVZ2 那套装扮（帽子 / 水手装 / 围巾 / 腰带 / 花环 / 绷带…）不带 —— 那 12 件在烘焙产物里是和本体一起画的，已逐帧关掉"))
	box.add_child(ModBase.create_detail_label(
		"玩法：近战，打本行左右相邻两格里的僵尸，不用子弹（检测与伤害走本体的 DetectComponent / DamageInfo，和地刺同一条路）"))
	box.add_child(ModBase.create_detail_label(
		"数值（模组自定，不是 wiki 值）：阳光 150、冷却 7.5 秒、出手间隔 0.35 秒；直拳 15 伤害，这一拳能直接打死目标时改成上勾拳 35 伤害"))
	box.add_child(ModBase.create_detail_label(
		"卡位：菜问的卡追加在所有已有植物卡之后（选卡界面最后一页）；装上本模组即可选用"))
	box.add_child(ModBase.create_detail_label(
		"关掉本模组：卡片、植物、解锁与图鉴条目一并撤掉，回到原版"))
	return box


#region 生命周期
func install() -> void:
	if not _kit.install(_build_recipe()):
		return
	_register_almanac_entry()


## 每局补一次解锁：读档会按存档记录重建 `curr_plant`（见 `SaveService._build_curr_plant`），
## 只装一次的话，玩家一读档菜问就又没了
func install_to_main_game(_main_game: MainGameManager) -> void:
	_kit.unlock()


func uninstall() -> void:
	_kit.uninstall()
	Global.global_read_data.clear_extra_almanac_entry(BONK_CHOY)
#endregion


#region 图鉴条目
## 菜问的图鉴条目：**自己登记，自己摘**
##
## ★ 为什么不写进本体的 `almanac_data.json`：本体不认识任何一个模组（硬约束），
##   图鉴的「扩展植物」页只认运行期登记的条目（`GlobalReadData.register_extra_almanac_entry`）。
##   关掉模组就把条目摘掉 —— 没装模组时不该在图鉴里看见一只谁都种不出来的植物。
func _register_almanac_entry() -> void:
	Global.global_read_data.register_extra_almanac_entry(BONK_CHOY, {
		"名字": "菜问",
		"描述": "菜问是《植物大战僵尸 2》的近战植物：不吐子弹，抬起拳头就打本行左右相邻两格里的僵尸。",
		"参数": {
			"阳光": "150",
			"冷却": "7.5 秒",
			"伤害": "直拳 15 ／ 上勾拳 35（能一拳打死时自动改用上勾拳）",
			"出手间隔": "0.35 秒",
			"可种在": "草地 / 花盆 / 睡莲"
		},
		"简介": "“我从不远程。”菜问活动了一下腕子，“离得近，才谈得上诚意。”",
		"提示": "由模组「PVZ2」提供：关掉模组后这条图鉴与这只植物会一起消失。",
		"背景": "Day"
	})
#endregion


#region 菜问这张配方
## 填一张 `PlantRuntimeRecipe`：菜问与本体植物的差别只有「场景 / 卡面 / 数值」，
## 被啃、被铲、被蹦极偷、手套搬运、睡觉、模仿者材质这些全在 `Plant000Base` 那一份里。
func _build_recipe() -> PlantRuntimeRecipe:
	var recipe := PlantRuntimeRecipe.new()
	recipe.plant_type = BONK_CHOY
	recipe.plant_name = &"BonkChoy"
	recipe.plant_scene = PLANT_SCENE
	recipe.cool_time = COOL_TIME
	recipe.sun_cost = SUN_COST
	## 普通陆生植物：草地 / 花盆 / 睡莲（与本体绝大多数植物同一套）
	recipe.condition_bits = PlantConditionBits.DEFAULT_NORM
	recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Norm
	## 卡面从待机动画的第 0 帧取（模组没有手摆的卡面形象，只能取帧）；
	## 取帧失败时退回大嘴花那张脸
	recipe.card_face_anim = ANIM_IDLE
	recipe.card_face_fallback_plant = FALLBACK_PLANT
	return recipe
#endregion
