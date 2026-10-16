extends Zombie001Norm
## 「更多的防具」模组：矿石桶僵尸的公共部分 —— 把一套桶贴图 + 血量装到铁桶僵尸的骨架上
##
## **为什么拿 `zombie_bucket.tscn` 当本体**：铁桶僵尸那个场景里已经配好了整套桶的骨架 ——
## 头顶的桶精灵、磁力菇要吸的铁器节点（`IronNode`）、掉在地上的桶、三层破损外观，
## 矿石桶只是「换一套贴图 + 换一个血量」，自己再搭一遍等于把这份配置抄一遍
## （抄漏一处就是静默少一层破损表现）。所以本体复用铁桶僵尸，本脚本只做换皮与改血量。
##
## 子类只给两样东西：
##   · `get_ore_textures()` —— 从完好到破损的贴图，**最后一张 = 打烂时掉在地上的那个桶**；
##   · `get_ore_max_hp()`   —— 这一层防具的血量。
##
## 装配时机：`Zombie000Base.build_runtime_parts()` —— 正常出战走 `ready_norm()`、
## 图鉴 / 开局预览走 `ready_show()`，**两处都会调到**，所以本文件里的方法要能重复执行。
##
## 关联：[防具](../../../../docs/参考存档/防具.md) ｜ ArmorComponent ｜ [僵尸热注册](zombie_runtime_recipe.gd)

## 头顶那张桶的精灵
const ARMOR_SPRITE_PATH := ^"Body/BodyCorrect/Anim_bucket/Anim_bucket"
## 掉在地上那个桶的精灵（防具被打掉时飞出去的那一个）
const DROP_SPRITE_PATH := ^"Body/NodeDrop/Node2D_Arm1_Drop/Node2D/Anim_bucket"
## 磁力菇吸桶那一瞬顶上来的那张桶（挂在铁器节点下；铁桶场景的 IronNode）
const IRON_SPRITE_PATH := ^"Body/BodyCorrect/IronNode/Anim_bucket"

## 防具的 `body_change` 里 NodePath 是**相对防具节点**解析的（防具是根节点的直接子节点），
## 所以这三条都要带一个 `../` —— 与 `zombie_bucket.tscn` 里那三个 `ResourceBodyChange` 一致
const CHANGE_SPRITE_PATH := ^"../Body/BodyCorrect/Anim_bucket/Anim_bucket"
const CHANGE_NODE_PATH := ^"../Body/BodyCorrect/Anim_bucket"
const CHANGE_DROP_PATH := ^"../Body/NodeDrop/Node2D_Arm1_Drop"


## 本种矿石桶的贴图（子类重写）：从完好到破损，**最后一张是掉在地上的那个桶**
func get_ore_textures() -> Array:
	return []


## 本种矿石桶这一层防具的血量（子类重写）
func get_ore_max_hp() -> int:
	return 0


## 装配：换贴图 + 改防具血量（正常出战与图鉴预览都会走这里）
func build_runtime_parts() -> void:
	super()
	var textures := get_ore_textures()
	if textures.is_empty():
		Log.error("%s：矿石桶没有配贴图，防具保持铁桶原样" % name)
		return
	## 头上戴的那张 = 完好的桶；掉在地上那张 = 打烂的桶；
	## 磁力菇吸走那一瞬顶上来的那张也按完好桶换（铁桶场景里的 IronNode 自带铁器贴图）
	_set_sprite_texture(ARMOR_SPRITE_PATH, textures[0])
	_set_sprite_texture(DROP_SPRITE_PATH, textures[-1])
	_set_sprite_texture(IRON_SPRITE_PATH, textures[0])

	var armor := _get_armor()
	if armor == null:
		return
	_apply_armor(armor, get_ore_max_hp(), textures)


## 换一个精灵的贴图（节点找不到只报错，不让整只僵尸起不来）
func _set_sprite_texture(sprite_path: NodePath, texture: Texture2D) -> void:
	var sprite := get_node_or_null(sprite_path) as Sprite2D
	if sprite == null:
		Log.error("%s：找不到精灵节点 %s，矿石桶的贴图没换上" % [name, sprite_path])
		return
	sprite.texture = texture


## 取本体上那层防具（铁桶僵尸场景里带着的那一个 —— 矿石桶就是改它，不另挂一层）
func _get_armor() -> ArmorComponent:
	var zombie_hp := hp_component as HpComponentZombie
	if zombie_hp == null:
		Log.error("%s：血量组件不是 HpComponentZombie，矿石桶没装上去" % name)
		return null
	var armors := zombie_hp.get_all_armors()
	if armors.is_empty():
		Log.error("%s：本体上没有防具组件，矿石桶没装上去" % name)
		return null
	return armors[0]


## 把血量与破损阶段写进这一层防具
##
## 阶段的切法：贴图有几张就切几段，最后一段是「防具没了（消失 + 掉落）」。
## 三张贴图 = 铁桶的三段（2/3、1/3、0），四张就是四段（3/4、2/4、1/4、0）。
func _apply_armor(armor: ArmorComponent, max_hp: int, textures: Array) -> void:
	if max_hp <= 0:
		Log.error("%s：矿石桶的血量没配（%d），防具保持铁桶原样" % [name, max_hp])
		return
	var stage_count := textures.size()
	var boundaries: Array[int] = []
	for i in range(stage_count - 1):
		## 整数除法是刻意的：与 `ArmorComponent.component_ready()` 自动切段的口径一致
		@warning_ignore("integer_division")
		boundaries.append(max_hp * (stage_count - 1 - i) / (stage_count - 1) - 1)
	boundaries.append(0)

	## 临界值与破损表现要先写好：`curr_hp` 的 setter 会照着它们推进破损阶段
	armor.boundary_value_hp = boundaries
	armor.body_change = _build_body_change(textures)
	armor.max_hp = max_hp
	armor.curr_hp = max_hp
	## 小僵尸大麻烦：防具血量减半。基类那次减半发生在本钩子**之前**（那时防具还是铁桶的数值），
	## 这里改完要自己补一次，否则小僵尸会顶着一整层矿石桶
	if is_mini_zombie:
		armor.update_mini_zombie_hp()


## 造这套桶的破损表现：每到一个临界值换一张贴图，最后一段是消失 + 掉落
func _build_body_change(textures: Array) -> Array[ResourceBodyChange]:
	var changes: Array[ResourceBodyChange] = []
	## 前 n-1 段：第 i 段换成 `textures[i + 1]`（第 0 张是头上那张完好的，不用换）
	for i in range(1, textures.size()):
		var change := ResourceBodyChange.new()
		change.sprite_change = [CHANGE_SPRITE_PATH]
		change.sprite_change_texture = [textures[i] as Texture2D]
		changes.append(change)
	## 最后一段：桶从头上消失，掉一个桶到地上
	var broken := ResourceBodyChange.new()
	broken.sprite_disappear = [CHANGE_NODE_PATH]
	broken.node_drop = CHANGE_DROP_PATH
	changes.append(broken)
	return changes
