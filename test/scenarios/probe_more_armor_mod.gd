extends RefCounted

## 妯＄粍鎼埌 `user://mods/` 鍚?class_name 涓嶅啀娉ㄥ唽涓哄叏灞€绫伙紝鎺㈤拡杩欓噷 preload 鎴愬父閲忓啀寮曠敤
const ZombieCopperBucket := preload("res://mods_builtin/more_armor/zombie_copper_bucket.gd")
const ZombieDiamondBucket := preload("res://mods_builtin/more_armor/zombie_diamond_bucket.gd")
const ZombieNetheriteBucket := preload("res://mods_builtin/more_armor/zombie_netherite_bucket.gd")
## 探针：模组「更多的防具」—— 铜桶 / 钻石桶 / 下界合金桶
##
## 为什么有这个探针：这三只僵尸是**运行期热注册**的（没有自己的 `.tscn`，本体复用铁桶僵尸
## 再换脚本），它们的脚本只在模组被装载时才被 `load()` —— 编译门禁那道 `--import`
## **覆盖不到**（见 `test/check_scripts.ps1` 的 KNOWN LIMITATION 1），写错了不会有任何报错，
## 只是「桶还是铁桶那个样、血量还是铁桶的 1100」。这里锁死五件事：
##   1. 开开关之后三只都注册进 `CharacterRegistry`，编号落在热注册段（9001–9999）；
##   2. 每只的防具血量换成了矿石桶那一份（不是铁桶的 1100）；
##   3. 头顶那张贴图换成了对应矿石（不是 `Zombie_bucket1`）；
##   4. 破损阶段数与贴图张数一致，铁器节点还在（磁力菇吸得走）；
##   5. 每只都有一张**僵尸卡**（有卡位 / 在已解锁名单里 / 卡面画出来了），
##      关掉模组后卡位与解锁一并撤掉 —— 想在选卡界面里亲手放一只就靠这三张。
##
## 只做**展示态实例化**（图鉴那条路：`ready_show()` 也会走 `build_runtime_parts()`），
## 不进关卡、不触发掉落。铜桶额外打**一发不会打破防具**的小伤害验易伤（打大了会掉桶，
## 掉落物要挂到 `zombie_manager` 下，关卡之外会报 Nil）。

## 标题 / 注册名 / 防具血量 / 破损段数（= 贴图张数）/ 完好那张贴图
const C_EXPECTS := [
	["铜桶", "ZombieCopperBucket", 1100, 3, "res://mods_builtin/more_armor/tongtong.png"],
	["钻石桶", "ZombieDiamondBucket", 1100, 3, "res://mods_builtin/more_armor/zuanshitong.png"],
	["下界合金桶", "ZombieNetheriteBucket", 1100, 4, "res://mods_builtin/more_armor/xiajiehejintong.png"],
]

const C_ARMOR_SPRITE := ^"Body/BodyCorrect/Anim_bucket/Anim_bucket"

var _failed := 0
## 探针找到的三只僵尸 id（关掉模组之后注册表里就没了，撤销那几断言要按这份名单查）
var _found_types: Array[StringName] = []


func run(a) -> void:
	a.log("PROBE 更多的防具 启动")
	## 根节点还在装配里就 `add_child` 会被引擎拒（"Parent node is busy"），
	## 探针是 `_run_scenario → run` 从 debug_channel 的 `_ready` 里同步进来的，
	## 先让一帧过去再开干
	await a.frames(1)
	## 模组默认关：探针要自己打开（与 `probe_glove_unlock` 同一条规矩）
	ModManager.set_mod_enabled(ModIds.MORE_ARMOR, true)
	_expect(a, "模组已启用", ModManager.is_mod_enabled(ModIds.MORE_ARMOR), true)
	## 模组页面那一块（里面读的是防具脚本上的常量）：写错只有打开页面那一刻才会炸
	var mod = ModManager.all_mods.get(ModIds.MORE_ARMOR)
	var detail = null if mod == null else mod.create_detail_control()
	_expect(a, "模组页面那一块造得出来", detail != null, true)
	if detail != null:
		detail.free()
	_check_registered(a)
	for item: Array in C_EXPECTS:
		_check_one(a, item)
	## ⚠️ 里面有 `await`，**必须** await 调用：不 await 的话它会在第一个 await 处挂起，
	## 而 `run()` 继续往下跑完直接 quit，它那一段永远不执行（表现为断言"凭空消失"且不报错）
	await _check_copper_extra(a)
	await _check_netherite_dr(a)
	await _check_diamond_transform(a)
	await _check_cards(a)
	_check_uninstall(a)
	await a.frames(2)
	a.log("")
	a.log("[MORE_ARMOR] result=%s failed=%d" % [("PASS" if _failed == 0 else "FAIL"), _failed])
	a.quit_game()


## 三只都注册上了？id 带热注册前缀？（改字符串 id 之后没有编号段了，只看前缀）
func _check_registered(a) -> void:
	var types := Global.character_registry.get_runtime_zombie_types()
	_expect(a, "热注册僵尸的数量", types.size(), C_EXPECTS.size())
	for zombie_type in types:
		var name := str(Global.character_registry.get_zombie_info(
				zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieName))
		a.log("  已注册 " + name + "（id " + zombie_type + "）")
		if not str(zombie_type).begins_with(CharacterRegistry.RUNTIME_ZOMBIE_ID_PREFIX):
			_failed += 1
			a.log("  [NG] " + name + " 的 id " + zombie_type + " 没有热注册前缀")


## 一只矿石桶僵尸：防具血量 / 贴图 / 破损段数 / 铁器节点
func _check_one(a, item: Array) -> void:
	var title: String = item[0]
	var zombie_type := _find_type(item[1])
	if zombie_type == ZombieIds.NULL:
		_failed += 1
		a.log("  [NG] " + title + "：注册表里找不到 " + item[1])
		return
	var zombie := Global.character_registry.instantiate_zombie(zombie_type)
	if zombie == null:
		_failed += 1
		a.log("  [NG] " + title + "：实例化失败")
		return
	## 展示态：不领实体 id、不进战斗，与图鉴里的那只走同一条装配路
	zombie.character_init_type = Character000Base.E_CharacterInitType.IsShow
	Engine.get_main_loop().root.add_child(zombie)

	var hp := zombie.hp_component as HpComponentZombie
	if hp == null:
		_failed += 1
		a.log("  [NG] " + title + "：血量组件不是 HpComponentZombie")
		zombie.queue_free()
		return
	var armors := hp.get_all_armors()
	_expect(a, title + " 的防具层数", armors.size(), 1)
	if armors.is_empty():
		zombie.queue_free()
		return
	var armor := armors[0]
	_expect(a, title + " 的防具血量", armor.max_hp, item[2])
	_expect(a, title + " 的防具满血", armor.curr_hp, item[2])
	_expect(a, title + " 的破损段数", armor.boundary_value_hp.size(), item[3])
	_expect(a, title + " 的破损表现条数", armor.body_change.size(), item[3])
	_expect(a, title + " 的铁器节点还在（磁力菇吸得走）", armor.get_iron_node() != null, true)

	var sprite := zombie.get_node_or_null(C_ARMOR_SPRITE) as Sprite2D
	if sprite == null:
		_failed += 1
		a.log("  [NG] " + title + "：找不到头顶的桶精灵 " + str(C_ARMOR_SPRITE))
	else:
		_expect(a, title + " 头顶的贴图", sprite.texture.resource_path, item[4])
	zombie.queue_free()


## 铜桶专属两件事：① 随时间获得易伤（**只放大防具吃到的那部分**）② 贴图氧化成铜锈色
func _check_copper_extra(a) -> void:
	var zombie_type := _find_type("ZombieCopperBucket")
	if zombie_type == ZombieIds.NULL:
		_failed += 1
		a.log("  [NG] 铜桶：注册表里找不到 ZombieCopperBucket")
		return
	var zombie := Global.character_registry.instantiate_zombie(zombie_type)
	if zombie == null:
		_failed += 1
		a.log("  [NG] 铜桶：实例化失败")
		return
	zombie.character_init_type = Character000Base.E_CharacterInitType.IsShow
	Engine.get_main_loop().root.add_child(zombie)
	var hp := zombie.hp_component as HpComponentZombie
	if hp == null or hp.get_all_armors().is_empty():
		_failed += 1
		a.log("  [NG] 铜桶：拿不到防具")
		zombie.queue_free()
		return
	## 故意不标类型：氧化进度 / 易伤倍率只有铜桶那一层防具才有，基类 `ArmorComponent` 上没有
	var armor = hp.get_all_armors()[0]
	_expect(a, "铜桶那一层防具换上了铜桶的（有易伤倍率）", "damage_rate" in armor, true)
	await a.frames(20)
	_expect(a, "铜桶的氧化进度随时间上涨", armor.get_oxidation_progress() > 0.0, true)

	## 拉满氧化：桶该染成铜锈色，易伤倍率也该到顶
	armor.oxidized_time = armor.OXIDIZE_FULL_TIME
	await a.frames(2)
	var sprite := zombie.get_node_or_null(C_ARMOR_SPRITE) as Sprite2D
	_expect(a, "完全氧化后桶变成铜锈色",
			sprite != null and sprite.modulate.is_equal_approx(ZombieCopperBucket.PATINA_COLOR), true)

	## 打一发（远小于 1100，防具不会破）：防具掉双倍，本体一滴不掉
	var armor_hp_before: int = armor.curr_hp
	var body_hp_before: int = hp.curr_hp
	var info := DamageInfo.create(zombie, 100,
			ConstDamage.E_DamageMode.Norm, ConstDamage.E_DamageCause.Script)
	DamageSystem.apply(info)
	_expect(a, "易伤倍率拉满时防具掉双倍血", armor_hp_before - armor.curr_hp,
			int(100 * armor.MAX_DAMAGE_RATE))
	_expect(a, "放大出来的伤害不漏到本体（仅对防具有效）", hp.curr_hp, body_hp_before)
	zombie.queue_free()


## 下界合金桶专属：50% 减伤（只减本层防具吃掉的那部分，**不外溢到本体**）
func _check_netherite_dr(a) -> void:
	var zombie_type := _find_type("ZombieNetheriteBucket")
	if zombie_type == ZombieIds.NULL:
		_failed += 1
		a.log("  [NG] 下界合金桶：注册表里找不到 ZombieNetheriteBucket")
		return
	var zombie := Global.character_registry.instantiate_zombie(zombie_type)
	if zombie == null:
		_failed += 1
		a.log("  [NG] 下界合金桶：实例化失败")
		return
	zombie.character_init_type = Character000Base.E_CharacterInitType.IsShow
	Engine.get_main_loop().root.add_child(zombie)
	var hp := zombie.hp_component as HpComponentZombie
	if hp == null or hp.get_all_armors().is_empty():
		_failed += 1
		a.log("  [NG] 下界合金桶：拿不到防具")
		zombie.queue_free()
		return
	## 故意不标类型：减伤那段在子类上
	var armor = hp.get_all_armors()[0]
	_expect(a, "下界合金桶的防具脚本是 armor_netherite_bucket",
		is_same(armor.get_script(), ZombieNetheriteBucket.NETHERITE_ARMOR), true)

	var armor_hp_before: int = armor.curr_hp
	var body_hp_before: int = hp.curr_hp
	var info := DamageInfo.create(zombie, 100,
			ConstDamage.E_DamageMode.Norm, ConstDamage.E_DamageCause.Script)
	DamageSystem.apply(info)
	_expect(a, "下界合金桶 100 伤害下防具掉 50", armor.curr_hp, armor_hp_before - 50)
	_expect(a, "下界合金桶减伤不外溢到本体", hp.curr_hp, body_hp_before)
	zombie.queue_free()


## 钻石桶专属：挨打 20 次后变身（防具换成下界合金桶、贴图也换、hp 沿用），
## 之后再挨打验变身后的下界合金桶 50% 减伤
func _check_diamond_transform(a) -> void:
	var zombie_type := _find_type("ZombieDiamondBucket")
	if zombie_type == ZombieIds.NULL:
		_failed += 1
		a.log("  [NG] 钻石桶：注册表里找不到 ZombieDiamondBucket")
		return
	var zombie := Global.character_registry.instantiate_zombie(zombie_type)
	if zombie == null:
		_failed += 1
		a.log("  [NG] 钻石桶：实例化失败")
		return
	zombie.character_init_type = Character000Base.E_CharacterInitType.IsShow
	Engine.get_main_loop().root.add_child(zombie)
	var hp := zombie.hp_component as HpComponentZombie
	if hp == null or hp.get_all_armors().is_empty():
		_failed += 1
		a.log("  [NG] 钻石桶：拿不到防具")
		zombie.queue_free()
		return
	var diamond_armor = hp.get_all_armors()[0]
	_expect(a, "钻石桶初始防具脚本是 armor_diamond_bucket",
		is_same(diamond_armor.get_script(), ZombieDiamondBucket.DIAMOND_ARMOR), true)
	var max_before: int = diamond_armor.max_hp
	_expect(a, "钻石桶初始防具满血", diamond_armor.curr_hp, max_before)

	## 20 次 × 50 = 1000：触发变身，桶剩 100 / 1100（没破）
	for i in 20:
		var info := DamageInfo.create(zombie, 50,
				ConstDamage.E_DamageMode.Norm, ConstDamage.E_DamageCause.Script)
		DamageSystem.apply(info)
	## 变身走 deferred：让帧末跑完
	await a.frames(2)

	if hp.get_all_armors().is_empty():
		_failed += 1
		a.log("  [NG] 钻石桶：变身后没防具了")
		zombie.queue_free()
		return
	var new_armor = hp.get_all_armors()[0]
	_expect(a, "挨打 20 次后钻石桶的防具换成了下界合金桶那层",
		is_same(new_armor.get_script(), ZombieDiamondBucket.NETHERITE_ARMOR), true)
	_expect(a, "变身后防具上限沿用", new_armor.max_hp, max_before)
	_expect(a, "变身后防具当前血量沿用", new_armor.curr_hp, max_before - 1000)
	var sprite := zombie.get_node_or_null(C_ARMOR_SPRITE) as Sprite2D
	_expect(a, "变身后头顶贴图换成下界合金完好那张",
		sprite != null and sprite.texture.resource_path == "res://mods_builtin/more_armor/xiajiehejintong.png", true)

	## 再打一发 100：变身后的下界合金桶 50% 减伤 → 防具掉 50、本体一滴不掉
	var armor_hp_before: int = new_armor.curr_hp
	var body_hp_before: int = hp.curr_hp
	var info2 := DamageInfo.create(zombie, 100,
			ConstDamage.E_DamageMode.Norm, ConstDamage.E_DamageCause.Script)
	DamageSystem.apply(info2)
	_expect(a, "变身后下界合金桶 100 伤害下防具掉 50", new_armor.curr_hp, armor_hp_before - 50)
	_expect(a, "变身后下界合金桶减伤不外溢到本体", hp.curr_hp, body_hp_before)
	zombie.queue_free()


## 三张僵尸卡（想在选卡界面的僵尸卡页里亲手放一只，就靠这三张）：卡位 / 已解锁 / 卡面
##
## 卡面是**这只僵尸自己那一棵 Body**（贴图是脚本换的，不是本体那张铁桶脸）——
## 画不出来就是一张空白卡，手持会报「卡片静态角色为空」拿不起来。
func _check_cards(a) -> void:
	## 卡面延迟到帧末才画（见 `ZombieRuntimeKit._install_card`），先让两帧过去
	await a.frames(2)
	for item: Array in C_EXPECTS:
		var title: String = item[0]
		var zombie_type := _find_type(item[1])
		if zombie_type == ZombieIds.NULL:
			_failed += 1
			a.log("  [NG] " + title + "：注册表里找不到 " + item[1])
			continue
		_found_types.append(zombie_type)
		_expect(a, title + " 有僵尸卡位", AllCards.zombie_card_ids.has(zombie_type), true)
		_expect(a, title + " 在已解锁名单里（待选区才点亮）",
				Global.global_game_state.curr_zombie.has(zombie_type), true)
		var card := AllCards.all_zombie_card_prefabs.get(zombie_type, null) as Card
		if card == null:
			_failed += 1
			a.log("  [NG] " + title + "：僵尸卡源目录里没有这张卡")
			continue
		_expect(a, title + " 的卡面画出来了", card.character_static.get_child_count() > 0, true)
		## 选卡界面就是照这条路径造卡的（按身份造一张出来）
		var reference := ResourceCardReference.create(
				ResourceCardReference.CardType.Zombie, zombie_type)
		var new_card := AllCards.create_card(reference)
		_expect(a, title + " 能按身份造出一张卡", new_card != null, true)
		if new_card != null:
			new_card.free()


## 关掉模组：三张卡与解锁一并撤掉（**摘卡要在注销僵尸之前**，顺序错了这里会报错）
func _check_uninstall(a) -> void:
	ModManager.set_mod_enabled(ModIds.MORE_ARMOR, false)
	_expect(a, "关掉模组后热注册僵尸的数量",
			Global.character_registry.get_runtime_zombie_types().size(), 0)
	for zombie_type in _found_types:
		_expect(a, "%s 的僵尸卡位已撤掉" % zombie_type,
				AllCards.zombie_card_ids.has(zombie_type), false)
		_expect(a, "%s 的解锁已撤掉" % zombie_type,
				Global.global_game_state.curr_zombie.has(zombie_type), false)


## 按注册名找僵尸类型（编号由注册表自动分配，不能写死）
func _find_type(zombie_name: String) -> StringName:
	for zombie_type in Global.character_registry.get_runtime_zombie_types():
		var name := str(Global.character_registry.get_zombie_info(
				zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieName))
		if name == zombie_name:
			return zombie_type
	return ZombieIds.NULL


func _expect(a, name: String, got, want) -> void:
	if got == want:
		a.log("  [OK] " + name + " = " + str(got))
	else:
		_failed += 1
		a.log("  [NG] " + name + " = " + str(got) + "（期望 " + str(want) + "）")
