extends Resource
class_name PlantRuntimeRecipe
## 运行期新增一株植物的**配方**（模组 / 控制台 / 自制关卡用）
##
## 内置的 48 株植物是「一个 `.tscn` + `PlantInfoData.PLANT_INFO` 一行」：那是**编译期**的事，
## 而模组不能让人去改本体的静态表（`PLANT_INFO` 是 const，而且本体不 import 模组 —— 硬约束 §1）。
## 所以新增植物走运行期登记：把「它是什么」填进本配方，交给
## `PlantRuntimeKit.install()`（一键装：登记 + 卡片 + 卡面 + 解锁）。
##
## ★ 本体为此只留通用口子，一个模组名字都不认识：
##   · `CharacterRegistry.register_runtime_plant_recipe()` 运行期登记（`PLANT_INFO` 写不进去）
##   · `AllCards.rebuild()` 往卡片源目录插卡后重排编号
##   · `Plant000DownBase.own_condition_bit` 底部植物自己声明「我给格子加哪个地形位」
##
## 用法（模组里三步，见 `mods_builtin/dlc/dlc_mod.gd` 的 `_build_water_bowl_recipe()`）：
## ```gdscript
## var recipe := PlantRuntimeRecipe.new()
## recipe.plant_type = &"my_plant"        ## 留空由注册表自动分配 `runtime_plant_1`
## recipe.plant_scene = preload("my_plant.tscn")
## recipe.cool_time = 7.5
## recipe.sun_cost = 25
## recipe.condition_bits = PlantConditionBits.GRASS | PlantConditionBits.ROOF
## recipe.place_in_cell = CharacterRegistry.PlacePlantInCell.Down
## recipe.card_face_anim = &"MyPlant_idle"   ## 卡面从这帧动画里取（留空 = 不取，见 card_face_fallback_plant）
## var kit := PlantRuntimeKit.new()
## kit.install(recipe)
## ```
##
## 关联：[运行期植物](../../../../docs/参考存档/运行期植物.md) ｜ `PlantRuntimeKit` ｜ `CharacterRegistry` ｜
## `PlantConditionBits` ｜ 僵尸那一侧的对口文件 `ZombieRuntimeRecipe`

#region 配方
## 植物 id（必填其一）：写自己的（如 `&"my_mod_plant"`），留空由注册表分配 `runtime_plant_N`
##
## ⚠️ 不能撞内置植物已用的 id（`PlantIds` 里有就会拒绝）—— 建议带模组自己的前缀。
## 本体**不再需要**为模组预留 id 常量：`PlantIds.WATER_BOWL` 那种空槽位是编号时代的产物
## （见 `PlantIds` 文件头第 ② 条），字符串 id 想加几个加几个。
@export var plant_type: StringName = PlantIds.NULL

## 植物名（图鉴 / 日志用）；留空时按 id 兜一个
@export var plant_name: StringName = &""

## 植物场景（必填）：根节点必须是 `Plant000Base`
@export var plant_scene: PackedScene

## 种植冷却（秒）
@export var cool_time: float = 7.5

## 阳光消耗
@export var sun_cost: int = 25

## 可以种在哪些地形上（位掩码，见 `PlantConditionBits`）
@export_flags("1 无", "2 草地", "4 花盆", "8 水", "16 睡莲", "32 屋顶/裸地", "64 水盆")
var condition_bits: int = PlantConditionBits.DEFAULT_NORM

## 种进格子的哪个位置（普通位 / 保护壳 / 花盆睡莲那一层…）
@export var place_in_cell: CharacterRegistry.PlacePlantInCell = CharacterRegistry.PlacePlantInCell.Norm

## 是否为**紫卡**（升级植物）：卡面自动换紫背景，只能种在 `purple_pre_plant` 上（原版机制）
## 种下去时前置植物会被顶掉（见 `PlantCell.create_plant()`），场上每有一株同种还要 +50 阳光
@export var is_purple_card := false

## 紫卡的前置植物：`is_purple_card = true` 时必填，否则卡会永远「不能种」且种植时裸索引崩
@export var purple_pre_plant: StringName = PlantIds.NULL
#endregion


#region 卡面
## 卡面形象取哪一帧动画（如 `&"Pot_waterplants"`）；留空 = 不取帧
## （那就只能靠 `card_face_fallback_plant` 借一张现成的脸，借不到就是一张空白卡）
@export var card_face_anim: StringName = &""

## 取第几帧
@export var card_face_frame: int = 0

## 取帧失败 / 没配动画时，借这张植物卡的卡面（如花盆）；留空 = 不借
@export var card_face_fallback_plant: StringName = PlantIds.NULL

## 卡面形象的缩放与落点（照 `all_cards.tscn` 里手摆形象的口径写）
@export var card_face_scale: Vector2 = Vector2(0.4, 0.4)
@export var card_face_position: Vector2 = Vector2(1, 11)

## 卡面只留 `Body` 那一枝（默认开）：卡面的成分要与普通植物卡一致
## —— `all_cards.tscn` 里那 48 张手摆卡面就是 `CharacterStatic → PlantXXX → Body → …` 这一棵纯精灵树，
## 而取帧拿到的整株还带着血条 / 组件容器那批 UI（脚本已被剥掉，visible 停在 true），
## 不剥就会把半格血条画到卡面上（观星关的格子虚影、水盆的卡面都踩过）
@export var card_face_body_only := true
#endregion


## 显示名：没起名时按 id 兜一个，保证日志与图鉴里不会空着
func get_display_name() -> StringName:
	if not plant_name.is_empty():
		return plant_name
	return "PlantRuntime_" + str(plant_type)


## 造一份种植条件资源（每次都新建：条件资源是**共享对象**，不能就地改）
func build_condition() -> ResourcePlantCondition:
	var condition := ResourcePlantCondition.new()
	condition.plant_condition = condition_bits
	condition.place_plant_in_cell = place_in_cell
	## 紫卡标记必须在这里落进去：卡片 `_ready()` 读的就是这份条件资源，
	## 等 `install()` 之后再换资源，卡面背景已经按普通卡画好了
	condition.is_purple_card = is_purple_card
	return condition


## 生成注册表要的那一条 `PLANT_INFO`（与 `PlantInfoData.PLANT_INFO` 的条目同构）
func build_info() -> Dictionary:
	return {
		CharacterRegistry.PlantInfoAttribute.PlantName: get_display_name(),
		CharacterRegistry.PlantInfoAttribute.CoolTime: cool_time,
		CharacterRegistry.PlantInfoAttribute.SunCost: sun_cost,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource: build_condition(),
		CharacterRegistry.PlantInfoAttribute.PlantScenes: plant_scene,
	}


#region 卡面
## 造卡面形象节点：从 `plant_scene` 的 `card_face_anim` 里取一帧定格（同步返回）
##
## ⚠️ 取帧要往 `tree.root` 挂临时容器，而 root 正"忙着布置子节点"时 `add_child()` 会被拒
## （多半是在某个 `_ready()` 里调的，见 `AnimationFrameUtil` 文件头第 8 条）——
## 所以别在 `_ready()` 里调，`PlantRuntimeKit` 是推到**帧末**才调的。
##
## [return] 没配动画 / 取帧失败返回 null，由调用方兜底
func build_card_face() -> Node2D:
	if plant_scene == null or card_face_anim == &"":
		return null
	var face := AnimationFrameUtil.create_frame_node(plant_scene, card_face_anim, card_face_frame)
	if face == null:
		return null
	## 影子藏掉：卡上其它形象的 shadow 都是 visible=false 的，留着会在卡面拖一坨黑影
	AnimationFrameUtil.strip_nodes(face, _is_shadow_node)
	if card_face_body_only:
		_keep_body_only(face)
	face.scale = card_face_scale
	face.position = card_face_position
	return face


## 只有 `Body` 这一枝时什么都不剥：那说明这株植物的结构不是标准的 Body 树，
## 与其把卡面剥空（卡面一空，手持会直接报「卡片静态角色为空」拿不起来），不如原样留着
static func _keep_body_only(face: Node2D) -> void:
	var has_body := false
	for child in face.get_children():
		if child.name == &"Body":
			has_body = true
			break
	if not has_body:
		return
	for child in face.get_children():
		if child.name == &"Body":
			continue
		face.remove_child(child)
		child.free()


static func _is_shadow_node(n: Node) -> bool:
	return n.name == &"shadow" or n.name == &"Shadow"
#endregion
