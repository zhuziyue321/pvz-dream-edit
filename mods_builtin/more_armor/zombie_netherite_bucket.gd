extends "ore_bucket_zombie_base.gd"
## 「更多的防具」模组：下界合金桶僵尸 —— **50% 减伤**
##
## 三种矿石桶里最硬的一层。自身血量与铁桶 / 钻石桶一致（**1100**），但减伤让本层防具
## 实际能挡 2200 的原始伤害；贴图四张，所以破损分四段（比铁桶多一层过渡）。
##
## 防具效果（减伤）长在 `armor_netherite_bucket.gd` 里 —— 走铜桶同一条「在防具自己
## 吃的那一步改」的路子，本体一行不用动。
## 详见 [防具 §4](../../../../docs/参考存档/防具.md) 与 [模组机制 §6.3](../../../../docs/参考存档/模组机制.md)
##
## 关联：ArmorComponent ｜ OreBucketZombieBase

## 这一层防具的血量（**与铁桶 / 钻石桶一致** —— 减伤让「实际能挡的伤害」翻倍）
const ARMOR_MAX_HP := 1100

## 下界合金桶那一层防具（带 50% 减伤）
const NETHERITE_ARMOR := preload("armor_netherite_bucket.gd")

## 四张贴图（完好 → 受损 → 更损 → 打烂）的文件名，**相对模组目录** —— 走
## `ModManager.load_mod_asset()` 读，说明同 `zombie_copper_bucket.gd`
const TEXTURE_FILES := [
	"xiajiehejintong.png",
	"xiajiehejintong2.png",
	"xiajiehejintong3.png",
	"xiajiehejintong4.png",
]

## 下界合金桶那层防具的引用
var _netherite_armor
## 读到的贴图（首次用到时读一次，见 `get_ore_textures()`）
var _ore_textures: Array = []


func get_ore_max_hp() -> int:
	return ARMOR_MAX_HP


func get_ore_textures() -> Array:
	if _ore_textures.is_empty():
		for file in TEXTURE_FILES:
			_ore_textures.append(ModManager.load_mod_asset(ModIds.MORE_ARMOR, file))
	return _ore_textures


## 装配：先换防具（基类 → 下界合金桶那层），再走公共那条（换贴图 + 写血量与破损段）
func build_runtime_parts() -> void:
	_equip_netherite_armor()
	super()


## 把本体那层基类防具换成下界合金桶那层（走 `zombie_copper_bucket.gd._equip_copper_armor()` 同款）
func _equip_netherite_armor() -> void:
	if _netherite_armor != null and is_instance_valid(_netherite_armor):
		return
	var old := _get_armor()
	if old == null:
		return
	var armor_type := old.armor_type
	var armor_class := old.armor_class
	var absorb_priority := old.absorb_priority
	var sfx := old.sfx_be_attack
	var iron := old.iron_node
	remove_child(old)
	old.queue_free()
	var armor := add_armor(armor_type, ARMOR_MAX_HP, armor_class, NETHERITE_ARMOR, absorb_priority)
	if armor == null:
		return
	armor.sfx_be_attack = sfx
	armor.iron_node = iron
	_netherite_armor = armor
