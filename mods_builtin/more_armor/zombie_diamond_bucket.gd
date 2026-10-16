extends "ore_bucket_zombie_base.gd"
## 「更多的防具」模组：钻石桶僵尸 —— 铁桶 + **受击 20 次后变下界合金桶**
##
## 钻石桶其余与铁桶完全一致（**血量与铁桶一样是 1100**、破损仍是三段、贴图换色）；
## 唯一特殊：头上那层防具挂的是模组自己的 `armor_diamond_bucket.gd`（不是基类防具），
## 它会累计挨打次数，满 20 次就发个 `sig_need_transform` 信号。
##
## 收到信号的宿主**不在 `absorb_damage()` 里直接换** —— 此刻血量组件正遍历防具链，
## 改遍历目标会跳过 / 重复。改用 `call_deferred()` 推到帧末再换：
## ① 把整层旧防具摘掉、挂上下界合金桶那层（脚本换成 `armor_netherite_bucket.gd`）；
## ② 贴图换成下界合金的（头 / 吸走 / 掉地三张）；
## ③ 继承旧防具的 `max_hp / curr_hp`（**上限与当前血量都沿用**，血条与破损阶段连续）。
##
## 关联：[防具](../../../../docs/参考存档/防具.md) ｜ [模组机制 §6.3](../../../../docs/参考存档/模组机制.md) ｜
##       ArmorComponent ｜ OreBucketZombieBase

## 钻石桶的变身阈值
const TRANSFORM_HIT_COUNT := 20
## 这一层防具的血量（**与铁桶一致** —— 钻石桶的特殊点在变身，不在血量）
const ARMOR_MAX_HP := 1100

## 三张贴图（完好 → 受损 → 打烂）的文件名，**相对模组目录** —— 走
## `ModManager.load_mod_asset()` 读，说明同 `zombie_copper_bucket.gd`
const TEXTURE_FILES := ["zuanshitong.png", "zuanshitong2.png", "zuanshitong3.png"]

## 钻石桶那一层防具（带挨打计数 + 变身信号）
const DIAMOND_ARMOR := preload("armor_diamond_bucket.gd")
## 变身后挂上去的那层（与 `ZombieNetheriteBucket` 同款）
const NETHERITE_ARMOR := preload("armor_netherite_bucket.gd")
## 变身时换上的贴图文件名（**借用下界合金桶的**，变身后从外观到机制都是下界合金）
const NETHERITE_TEXTURE_FILES := [
	"xiajiehejintong.png",
	"xiajiehejintong2.png",
	"xiajiehejintong3.png",
	"xiajiehejintong4.png",
]

## 钻石桶那层防具的引用：变身信号要连到它身上
var _diamond_armor
## 读到的贴图（首次用到时读一次，见 `get_ore_textures()` / `_get_netherite_textures()`）
var _ore_textures: Array = []
var _netherite_textures: Array = []


func get_ore_max_hp() -> int:
	return ARMOR_MAX_HP


func get_ore_textures() -> Array:
	if _ore_textures.is_empty():
		for file in TEXTURE_FILES:
			_ore_textures.append(ModManager.load_mod_asset(ModIds.MORE_ARMOR, file))
	return _ore_textures


## 变身时换上的下界合金桶贴图（借用 `ZombieNetheriteBucket` 那套；同样是懒加载 + 缓存）
func _get_netherite_textures() -> Array:
	if _netherite_textures.is_empty():
		for file in NETHERITE_TEXTURE_FILES:
			_netherite_textures.append(ModManager.load_mod_asset(ModIds.MORE_ARMOR, file))
	return _netherite_textures


## 装配：先换防具（基类 → 钻石桶那层），再走公共那条（换贴图 + 写血量与破损段），
## 最后把变身信号挂上
func build_runtime_parts() -> void:
	_equip_diamond_armor()
	super()
	if _diamond_armor != null and is_instance_valid(_diamond_armor):
		if not _diamond_armor.sig_need_transform.is_connected(_on_diamond_armor_need_transform):
			_diamond_armor.sig_need_transform.connect(_on_diamond_armor_need_transform)


## 把本体那层基类防具换成钻石桶那层（配置先抄下来再搬，参数一个都不丢）
## —— 走 [铜桶 _equip_copper_armor](../../../../docs/工作记录/2026-10-14_铜桶氧化易伤与铜锈色.md)
## 那条「`set_script()` 会清掉场景配好的字段」的路子
func _equip_diamond_armor() -> void:
	if _diamond_armor != null and is_instance_valid(_diamond_armor):
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
	var armor := add_armor(armor_type, ARMOR_MAX_HP, armor_class, DIAMOND_ARMOR, absorb_priority)
	if armor == null:
		return
	armor.sfx_be_attack = sfx
	armor.iron_node = iron
	_diamond_armor = armor


## 钻石桶满 20 次：推到帧末再换（**不能同步换**：血量组件正遍历防具链）
func _on_diamond_armor_need_transform() -> void:
	_transform_to_netherite.call_deferred()


## 把整层防具换成下界合金桶、贴图也换、hp 接着用
##
## **继承口径**：新防具的 `max_hp / curr_hp` 都沿用旧防具当时的值 —— 血条比例连续、
## 破损阶段不跳变；只是贴图换掉 + 加 50% 减伤。下界合金桶自身上限是 1100（看
## `ZombieNetheriteBucket.ARMOR_MAX_HP`），但 1100 刚好与钻石桶一致，所以这里不会出现
## 「上限被默默换成另一档」的情况。
func _transform_to_netherite() -> void:
	var old := _get_armor()
	if old == null or not old.is_alive():
		## 第 20 击恰好把钻石桶打没了：没东西可继承，跳过（会留着一只没桶的钻石桶）
		Log.warn("%s：钻石桶想变身时已破，没东西可继承" % name)
		return
	var armor_type := old.armor_type
	var armor_class := old.armor_class
	var absorb_priority := old.absorb_priority
	var sfx := old.sfx_be_attack
	var iron := old.iron_node
	var inherited_max := old.max_hp
	var inherited_curr := old.curr_hp
	remove_child(old)
	old.queue_free()
	var armor := add_armor(armor_type, inherited_max, armor_class, NETHERITE_ARMOR, absorb_priority)
	if armor == null:
		return
	armor.sfx_be_attack = sfx
	armor.iron_node = iron
	## 装配：换贴图 + 写上限 + 切破损段（基类的方法把 curr 也设成上限）
	var netherite_textures := _get_netherite_textures()
	_apply_armor(armor, inherited_max, netherite_textures)
	## 继承当前血量（**这个赋值要走 setter**，它会按临界值推进破损阶段）
	armor.curr_hp = inherited_curr
	## 贴图换掉三张：头上 / 掉地上 / 磁力菇吸走那一瞬
	_set_sprite_texture(ARMOR_SPRITE_PATH, netherite_textures[0])
	_set_sprite_texture(DROP_SPRITE_PATH, netherite_textures[-1])
	_set_sprite_texture(IRON_SPRITE_PATH, netherite_textures[0])
	_diamond_armor = null
