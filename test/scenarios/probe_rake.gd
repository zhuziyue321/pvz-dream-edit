extends RefCounted
## 探针：钉耙（Garden Rake）
##
## 覆盖：
##   1. 存档：买一次 = 3 关；手上还有钉耙时不能重复买；通关消耗一次后递减
##   2. 生成：手上有钉耙时关卡放下 1 把；落点在「从右数第 2 列」、行号符合地图数据/中间行兜底
##   3. 触发：僵尸踩上钉耙 → 吃 ConstShop.RAKE_ATTACK_VALUE 穿透伤害 → 普通僵尸当场死亡
##   4. 表现：触发后钉耙把手弹起（is_triggered）并在动画结束后消失
##   5. 过滤：已经死亡的僵尸不会触发钉耙
##
## 机器可读汇总：最后一行 [RAKE] result=PASS|FAIL failed=<n>

const LEVEL := "res://src/levels/mode_adventure/adventure_01_01.gd"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 钉耙 ==========")
	_check_save_state(a)
	await _check_store_goods(a)

	if not await _boot(a):
		_finish(a)
		return

	var rake := _get_rake(a)
	if rake == null:
		_finish(a)
		return
	_check_rake_pos(a, rake)

	await _check_trigger(a, rake)
	_check_consume_on_success(a)
	_finish(a)


## 通关结算：本关放过钉耙就消耗一次（原版没踩到也算用掉）
func _check_consume_on_success(a) -> void:
	var state = Global.global_game_state
	var before: int = state.get_rake_use_num()
	Global.main_game.save_manager.update_level_state_data_success()
	_check(a, "通关结算消耗一次钉耙使用次数", state.get_rake_use_num() == before - 1,
		"before=%d after=%d" % [before, state.get_rake_use_num()])


#region 存档（不依赖关卡）

func _check_save_state(a) -> void:
	var state = Global.global_game_state
	state.rake_use_num = 0
	_check(a, "手上没钉耙时 is_rake_owned() 为 false", not state.is_rake_owned())
	_check(a, "买一次钉耙返回成功", state.buy_rake() == true)
	_check(a, "买一次得到 %d 关" % ConstShop.RAKE_USE_NUM_PER_BUY,
		state.get_rake_use_num() == ConstShop.RAKE_USE_NUM_PER_BUY,
		"rake_use_num=%d" % state.get_rake_use_num())
	_check(a, "手上还有钉耙时不能重复买", state.buy_rake() == false)
	_check(a, "消耗一次后剩余关数 -1", state.consume_rake_use() and state.get_rake_use_num() == ConstShop.RAKE_USE_NUM_PER_BUY - 1,
		"rake_use_num=%d" % state.get_rake_use_num())
	## 还原成满次数，供后面的关卡用例使用
	state.rake_use_num = ConstShop.RAKE_USE_NUM_PER_BUY

#endregion


#region 商店商品（真实走 Goods.comfirm_get_this_goods 的扣钱 → 发货链路）

func _check_store_goods(a) -> void:
	var scene: PackedScene = load("res://src/store/goods_rake.tscn")
	if scene == null:
		_check(a, "钉耙商品场景可加载", false, "res://src/store/goods_rake.tscn")
		return
	var goods: GoodsRake = scene.instantiate()
	a.get_tree().root.add_child(goods)
	await a.frames(2)

	var state = Global.global_game_state
	state.rake_use_num = 0
	state.coin_value = ConstShop.RAKE_PRICE
	goods._refresh_goods_state()
	_check(a, "钉耙商品售价 = ConstShop.RAKE_PRICE", goods.price == ConstShop.RAKE_PRICE,
		"price=%d" % goods.price)
	_check(a, "没买过时商品有货", goods.is_have_goods == true)

	goods.comfirm_get_this_goods()
	_check(a, "购买后扣掉金币", state.coin_value == 0, "coin=%d" % state.coin_value)
	_check(a, "购买后手上拿到钉耙", state.is_rake_owned(),
		"rake_use_num=%d" % state.get_rake_use_num())
	_check(a, "购买后商品标记为已拥有（不可再买）", goods.is_have_goods == false)
	_check(a, "已拥有时再次购买不扣钱也不加次数", (func() -> bool:
		state.coin_value = 10000
		goods.comfirm_get_this_goods()
		return state.coin_value == 10000 and state.get_rake_use_num() == ConstShop.RAKE_USE_NUM_PER_BUY
	).call())
	state.coin_value = 0
	goods.queue_free()

#endregion


#region 关卡与钉耙

func _boot(a) -> bool:
	var para: Resource = (load(LEVEL) as GDScript).new()
	if para == null:
		a.log("!! 关卡资源加载失败: " + LEVEL)
		return false
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameFront]
	)
	await a.wait(2.0)
	if Global.main_game == null:
		a.log("!! Global.main_game 为空")
		return false
	if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		Global.main_game.main_game_start()
	await a.wait(3.0)
	return Global.main_game != null


## 取本关放下的第一把钉耙，没有则记一条失败
func _get_rake(a) -> Rake:
	var gim = Global.main_game.game_item_manager.gim_rake
	if gim == null:
		_check(a, "钉耙管理器可用", false, "gim_rake 为空")
		return null
	_check(a, "手上有钉耙时本关放下了钉耙", gim.is_have_rake(),
		"all_rakes=%d" % gim.all_rakes.size())
	if gim.all_rakes.is_empty():
		return null
	return gim.all_rakes[0]


func _check_rake_pos(a, rake: Rake) -> void:
	var map_data: ResourceMapData = Global.game_para.map_data
	var col: int = maxi(0, map_data.get_col_num() - 2)
	var expect_x: float = map_data.col_x[col] + map_data.col_width[col] * 0.5
	_check(a, "钉耙落在从右数第 2 列", absf(rake.global_position.x - expect_x) < 2.0,
		"rake_x=%.1f expect_x=%.1f col=%d" % [rake.global_position.x, expect_x, col])
	_check(a, "钉耙行号合法且在陆地行上",
		rake.lane >= 0 and rake.lane < map_data.get_row_num()
		and map_data.rows[rake.lane].zombie_row_type == CharacterRegistry.ZombieRowType.Land,
		"lane=%d row_num=%d" % [rake.lane, map_data.get_row_num()])
	_check(a, "钉耙脚部 y 与该行僵尸生成点一致",
		absf(rake.global_position.y - map_data.rows[rake.lane].zombie_create_global_pos.y) < 2.0,
		"rake_y=%.1f" % rake.global_position.y)


## 真实链路：生成一只普通僵尸挪到钉耙上，等 Area2D 触发
func _check_trigger(a, rake: Rake) -> void:
	var zm = Global.main_game.zombie_manager
	var lane: int = rake.lane
	var zombie_init_para: Dictionary = {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
		Zombie000Base.E_ZInitAttr.CurrWave: 1,
	}
	var zombie := zm.create_norm_zombie(
		CharacterRegistry.ZombieType.Z001Norm,
		zm.all_zombie_rows[lane],
		zombie_init_para,
		rake.global_position + Vector2(10, 0)
	)
	if zombie == null:
		_check(a, "生成测试僵尸", false, "create_norm_zombie 返回空")
		return
	await a.frames(3)
	_check(a, "僵尸踩上钉耙后钉耙触发", rake.is_triggered == true,
		"is_triggered=%s" % str(rake.is_triggered))
	_check(a, "普通僵尸被钉耙当场击杀", zombie.is_death == true,
		"is_death=%s lane=%d" % [str(zombie.is_death), zombie.lane])

	## 已经死亡的僵尸不该再触发钉耙（换一把新的钉耙验证）
	var second := Global.main_game.game_item_manager.gim_rake.create_rake(
		Global.game_para.map_data, lane)
	await a.frames(2)
	second._try_trigger(zombie)
	_check(a, "已死亡的僵尸不会触发钉耙", second.is_triggered == false,
		"is_triggered=%s" % str(second.is_triggered))
	second.queue_free()

	## 触发动画结束后钉耙自己消失
	await a.wait(2.0)
	_check(a, "触发动画结束后钉耙消失", not is_instance_valid(rake))

#endregion


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[RAKE] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
