extends "ore_bucket_zombie_base.gd"
## 「更多的防具」模组：铜桶僵尸 —— **除了会氧化，与铁桶僵尸完全一致**
##
## 与铁桶的两处差别（血量与贴图本身仍走 `OreBucketZombieBase` 那条公共装配）：
##   1. **随时间获得易伤（仅对防具有效）** —— 长在防具上：把本体那层铁桶防具换成
##      `armor_copper_bucket.gd`，它自己按在场时间涨易伤倍率，且只放大防具吃到的伤害；
##   2. **贴图变成铜锈色** —— 归本文件：按氧化进度把桶从铜色染成铜绿（铜锈）。
##
## 为什么防具要整层换掉：铁桶僵尸本体（`zombie_bucket.tscn`）上那层是**基类**防具，
## 而「易伤」必须长在防具自己身上才只影响防具。运行期 `set_script()` 会把场景里配好的
## 类别 / 铁器 / 音效清回默认值（`ZombieRuntimeRecipe._apply_script()` 那条注释就是这事），
## 所以照热注册那条路走 `add_armor()`：先把旧那层的配置抄下来，摘掉它，再挂一层铜的上去。
##
## 关联：[防具](../../../../docs/参考存档/防具.md) ｜ ArmorComponent ｜ OreBucketZombieBase

## 铜桶那一层防具（易伤长在它身上）
const COPPER_ARMOR := preload("armor_copper_bucket.gd")

## 这一层防具的血量：**与铁桶一致**（铜桶不是靠血薄，是靠氧化变脆）
const ARMOR_MAX_HP := 1100

## 三张贴图（完好 → 受损 → 打烂）的文件名，**相对模组目录** —— 走 `ModManager.load_mod_asset()`
## 读：按本模组当前加载根（`user://mods/` 优先 / `res://mods_builtin/` 兜底）解析，
## 导出后在 `user://` 下也能读到，不必再往本体 `assets/` 塞文件
const TEXTURE_FILES := ["tongtong.png", "tongtong2.png", "tongtong3.png"]

## 铜锈色：铜放久了氧化成的铜绿（`modulate` 是乘法，铜色 × 铜锈色 = 氧化后的颜色）
const PATINA_COLOR := Color(0.42, 0.86, 0.72)

## 读到的贴图（首次用到时读一次，见 `get_ore_textures()`）
var _ore_textures: Array = []

## 铜桶那一层防具。**不标类型**：`user://` 下的脚本不注册成全局类，
## 而基类 `ArmorComponent` 上没有「氧化进度」这个成员，标了就读不到
var _copper_armor
## 三张桶精灵：头上戴的 / 被吸走那一瞬的 / 掉在地上的 —— 都跟着氧化
var _bucket_sprites: Array[Sprite2D] = []


func get_ore_max_hp() -> int:
	return ARMOR_MAX_HP


func get_ore_textures() -> Array:
	if _ore_textures.is_empty():
		for file in TEXTURE_FILES:
			_ore_textures.append(ModManager.load_mod_asset(ModIds.MORE_ARMOR, file))
	return _ore_textures


## 装配：先换防具，再走公共那条（换贴图 + 写血量与破损段），最后染一次色
func build_runtime_parts() -> void:
	_equip_copper_armor()
	super()
	_collect_bucket_sprites()
	_apply_patina(_get_oxidation_progress())


## 氧化进度会随时间变，桶的颜色也跟着变（每帧刷一次，三张精灵成本可忽略）
func _process(_delta: float) -> void:
	if _bucket_sprites.is_empty():
		return
	_apply_patina(_get_oxidation_progress())


## 把本体那层铁桶防具换成铜桶那层（配置先抄下来再搬，参数一个都不丢）
func _equip_copper_armor() -> void:
	if _copper_armor != null and is_instance_valid(_copper_armor):
		return
	var old := _get_armor()
	if old == null:
		return
	var armor_type := old.armor_type
	var armor_class := old.armor_class
	var absorb_priority := old.absorb_priority
	var sfx := old.sfx_be_attack
	var iron := old.iron_node
	## 摘下来再挂：直接改脚本会把上面这几项清回默认值
	remove_child(old)
	old.queue_free()
	var armor := add_armor(armor_type, ARMOR_MAX_HP, armor_class, COPPER_ARMOR, absorb_priority)
	if armor == null:
		return
	armor.sfx_be_attack = sfx
	armor.iron_node = iron
	_copper_armor = armor


## 三张桶精灵（掉了 / 被吸走了也要是铜锈色，所以一次收齐）
func _collect_bucket_sprites() -> void:
	_bucket_sprites.clear()
	for sprite_path in [ARMOR_SPRITE_PATH, IRON_SPRITE_PATH, DROP_SPRITE_PATH]:
		var sprite := get_node_or_null(sprite_path) as Sprite2D
		if sprite == null:
			Log.error("%s：找不到桶精灵 %s，铜锈色没染上" % [name, sprite_path])
			continue
		_bucket_sprites.append(sprite)


## 氧化进度：问防具要（状态本体在防具组件里，宿主不自己存一份）
func _get_oxidation_progress() -> float:
	if _copper_armor == null or not is_instance_valid(_copper_armor):
		return 0.0
	return float(_copper_armor.get_oxidation_progress())


## 按氧化进度把桶从铜色染向铜锈色
func _apply_patina(progress: float) -> void:
	var color := Color.WHITE.lerp(PATINA_COLOR, clampf(progress, 0.0, 1.0))
	for sprite in _bucket_sprites:
		sprite.modulate = color
