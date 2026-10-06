extends RefCounted
## 探针：禅境花园的蜗牛与巧克力
## 覆盖：
##   1. 没买蜗牛时，花园里没有蜗牛，巧克力按钮也一并藏起来
##   2. 商店买断蜗牛 + 买了巧克力后，蜗牛出现在花园里（初始是睡着的）
##   3. 点一下（wake_up）能把蜗牛叫醒，喂巧克力会扣库存并让它加速
##   4. 醒着的蜗牛会爬向掉落的钱并把它捡走
##   5. 爬到爬行范围边界会掉头(不会卡在边界反复播转身动画)
##   6. 转身期间清醒计时照走(转身不冻结"再过一会儿就睡着"的倒计时)
##   7. 锁钱:盯上最近的一枚就一直追,捡到手 / 消失才换下一枚(中途不改主意)
##   8. 只在初始花园(阳光房)露面:翻到蘑菇园就藏起来且不再捡钱,翻回来还是原来那只
## 机器可读汇总：最后一行 [SNAIL] result=PASS|FAIL failed=<n>

## 探针里放钱常用的 y:花园下半部分的某个高度,落在蜗牛爬行范围内即可
## (钱的实际落点在产出它的植物旁边,见 DIM_Coin.create_coin)
const GROUND_Y := 505.0

var _failed := 0

const GARDEN_SCENE := "res://src/garden/garden.tscn"


func run(a) -> void:
	a.log("")
	a.log("========== 探针 蜗牛与巧克力 ==========")
	await a.wait(2.0)

	var state = Global.global_game_state
	## 通关到 5-10：花园已解锁
	_mark_cleared(state, 50)
	_reset_garden(state)

	a.log("STEP1 没买蜗牛时，花园里没有蜗牛、巧克力按钮隐藏")
	a.get_tree().change_scene_to_file(GARDEN_SCENE)
	if not await a.wait_scene("garden", 15.0):
		_check(a, "进入花园", false, str(a.get_tree().current_scene))
		_finish(a)
		return
	await a.wait(2.0)

	var garden = a.get_tree().current_scene
	_check(a, "花园根节点是 GardenManager", garden is GardenManager, str(garden))
	_check(a, "没买蜗牛时花园里没有蜗牛", garden.stinky == null, str(garden.stinky))
	_check(a, "没买蜗牛时巧克力按钮隐藏",
		not garden.chocolate.item_button.visible, str(garden.chocolate.item_button.visible))

	a.log("STEP2 买下蜗牛与巧克力后，蜗牛登场（初始睡着）")
	_check(a, "买断蜗牛成功",
		state.buy_garden_tool(GardenManager.E_GardenTool.Snail))
	_check(a, "买一份巧克力（5 个）成功",
		state.add_garden_tool_num(GardenManager.E_GardenTool.Chocolate, 5))
	a.get_tree().change_scene_to_file(GARDEN_SCENE)
	if not await a.wait_scene("garden", 15.0):
		_check(a, "重新进入花园", false, str(a.get_tree().current_scene))
		_finish(a)
		return
	await a.wait(2.0)

	garden = a.get_tree().current_scene
	_check(a, "蜗牛已出现在花园里", garden.stinky != null, str(garden.stinky))
	_check(a, "巧克力按钮已显示",
		garden.chocolate.item_button.visible, str(garden.chocolate.item_button.visible))
	_check(a, "蜗牛初始是睡着的",
		garden.stinky != null and garden.stinky.is_sleep, str(garden.stinky))
	_check(a, "巧克力道具拿到了蜗牛的引用",
		garden.chocolate.stinky == garden.stinky, str(garden.chocolate.stinky))

	var stinky = garden.stinky

	a.log("STEP3 点击可以把蜗牛叫醒")
	stinky.wake_up()
	await a.wait(0.2)
	_check(a, "叫醒后不再睡眠", not stinky.is_sleep, str(stinky.is_sleep))
	_check(a, "没吃巧克力时是原速",
		is_equal_approx(stinky.get_speed_scale(), 1.0), str(stinky.get_speed_scale()))

	a.log("STEP4 喂巧克力：扣一块库存并加速")
	var chocolate_num_before: int = state.get_garden_tool_num(GardenManager.E_GardenTool.Chocolate)
	garden.chocolate.use_it()
	await a.wait(0.2)
	var chocolate_num_after: int = state.get_garden_tool_num(GardenManager.E_GardenTool.Chocolate)
	_check(a, "喂一次扣一块巧克力",
		chocolate_num_after == chocolate_num_before - 1,
		str(chocolate_num_before) + " -> " + str(chocolate_num_after))
	_check(a, "吃了巧克力后加速",
		stinky.get_speed_scale() > 1.0, str(stinky.get_speed_scale()))
	_check(a, "吃完巧克力是醒着的", not stinky.is_sleep, str(stinky.is_sleep))

	a.log("STEP5 醒着的蜗牛会爬过去捡钱")
	stinky.wake_up()
	_check(a, "捡钱前蜗牛是醒着的", not stinky.is_sleep, str(stinky.is_sleep))
	var coin: Coin = _make_coin(garden, Vector2(450.0, GROUND_Y))
	stinky.global_position = Vector2(400.0, 480.0)
	await a.wait(2.5)
	## 捡到手的钱会被回收(Coin.collect 走完就 queue_free),所以"节点没了"也算捡到了
	var coin_got: bool = (not is_instance_valid(coin)) or coin.is_get
	_check(a, "蜗牛爬到钱边上把它捡走了", coin_got, str(coin_got))
	## 拾取判据是二维距离:横向对齐但还差着一截高度时不能算捡到
	var gap: float = -1.0
	if is_instance_valid(coin):
		gap = stinky.global_position.distance_to(coin.global_position)
	_check(a, "没捡到时说明还没爬到它旁边", coin_got or gap <= stinky.PICK_COIN_DISTANCE + 1.0,
		"距离 " + str(snappedf(gap, 0.1)) + " <= " + str(stinky.PICK_COIN_DISTANCE))

	a.log("STEP6 巧克力用完（库存 0）后，工具栏把它藏起来")
	state.garden_data[GlobalGameState.GARDEN_TOOL_NUM_KEY] = {"5": 0}
	a.get_tree().change_scene_to_file(GARDEN_SCENE)
	if not await a.wait_scene("garden", 15.0):
		_check(a, "重新进入花园", false, str(a.get_tree().current_scene))
		_finish(a)
		return
	await a.wait(2.0)
	garden = a.get_tree().current_scene
	_check(a, "没有巧克力时按钮隐藏",
		not garden.chocolate.item_button.visible, str(garden.chocolate.item_button.visible))

	await _step7_turn_at_edge(a, garden)
	await _step8_wake_timer_runs_while_turning(a, garden)
	await _step9_facing_matches_direction(a, garden)
	await _step10_wander_changes_y(a, garden)
	await _step11_high_coin_collected(a, garden)
	await _step12_move_toward_coin(a, garden)
	await _step13_lock_nearest_coin(a, garden)
	await _step14_only_in_initial_garden(a, garden)

	_finish(a)


## STEP7 爬到爬行范围边界要掉头并离开,不能卡在边界反复播转身动画
func _step7_turn_at_edge(a, garden) -> void:
	a.log("STEP7 爬到边界会掉头")
	var stinky = garden.stinky
	if stinky == null:
		_check(a, "花园里有蜗牛", false, "null")
		return
	var max_x: float = stinky.move_range.position.x + stinky.move_range.size.x
	stinky.wake_up()
	stinky.direction = 1
	stinky.global_position = Vector2(max_x, 500.0)
	## 屏蔽"闲逛随机掉头",这一轮只允许边界把蜗牛掉头,否则测不出边界卡死
	stinky._idle_turn_cd = 999.0
	await a.wait(2.5)
	_check(a, "撞到右边界后掉头朝左", stinky.direction == -1, str(stinky.direction))
	_check(a, "掉头后确实离开了边界", stinky.global_position.x < max_x - 10.0,
		str(stinky.global_position.x) + " < " + str(max_x - 10.0))
	_check(a, "转身动画已结束", not stinky.is_turn, str(stinky.is_turn))


## STEP8 转身期间清醒倒计时照走:转身把 _move 停了,但不该把睡觉时间一起冻住
func _step8_wake_timer_runs_while_turning(a, garden) -> void:
	a.log("STEP8 转身期间清醒计时照走")
	var stinky = garden.stinky
	if stinky == null:
		_check(a, "花园里有蜗牛", false, "null")
		return
	var coin2: Coin = SceneRegistry.COIN_SILVER.instantiate()
	coin2.setup(Vector2.ZERO)
	garden.drop_coin_parent.add_child(coin2)
	stinky.wake_up()
	stinky.direction = 1
	## 钱放在蜗牛左边,逼它先转身再往左爬
	coin2.global_position = Vector2(stinky.global_position.x - 200.0, stinky.global_position.y)
	## 等蜗牛认到这枚钱并开始转身
	await a.wait(0.5)
	stinky.wake_time_left = 0.05
	await a.wait(0.4)
	_check(a, "转身中也会到点睡着", stinky.is_sleep, str(stinky.is_sleep))
	if is_instance_valid(coin2):
		coin2.queue_free()


## STEP9 身体朝向要跟着走的方向:往右爬时头朝右(素材默认朝左,要翻面)
func _step9_facing_matches_direction(a, garden) -> void:
	a.log("STEP9 朝向跟着行走方向")
	var stinky = garden.stinky
	if stinky == null:
		_check(a, "花园里有蜗牛", false, "null")
		return
	stinky.wake_up()
	stinky._idle_turn_cd = 999.0
	stinky.global_position = Vector2(300.0, 500.0)
	## 朝向只由 _start_turn 改,所以靠"钱在哪边"来引导它自己转身
	var coin3: Coin = _make_coin(garden, Vector2(550.0, GROUND_Y))
	await a.wait(2.0)
	var x_right: float = stinky.global_position.x
	await a.wait(0.6)
	_check(a, "往右爬时位置在增大", stinky.global_position.x > x_right,
		str(x_right) + " -> " + str(stinky.global_position.x))
	_check(a, "往右爬时身体翻面朝右(scale.x < 0)", stinky.body.scale.x < 0.0,
		str(stinky.body.scale.x))
	if is_instance_valid(coin3):
		coin3.queue_free()

	## 钱挪到左边,逼它自己转身往左爬
	var coin4: Coin = _make_coin(garden, Vector2(150.0, GROUND_Y))
	await a.wait(2.0)
	var x_left: float = stinky.global_position.x
	await a.wait(0.6)
	_check(a, "往左爬时位置在减小", stinky.global_position.x < x_left,
		str(x_left) + " -> " + str(stinky.global_position.x))
	_check(a, "往左爬时身体回到素材原样(scale.x > 0)", stinky.body.scale.x > 0.0,
		str(stinky.body.scale.x))
	if is_instance_valid(coin4):
		coin4.queue_free()


## STEP10 闲逛也要在爬行范围里上下挪,不能只沿一条横线爬
func _step10_wander_changes_y(a, garden) -> void:
	a.log("STEP10 闲逛时会上下挪")
	var stinky = garden.stinky
	if stinky == null:
		_check(a, "花园里有蜗牛", false, "null")
		return
	var top_y: float = stinky.move_range.position.y
	var bottom_y: float = top_y + stinky.move_range.size.y
	stinky.wake_up()
	stinky._idle_turn_cd = 999.0
	stinky.global_position = Vector2(400.0, top_y)
	## 直接指定落脚点,免得随机值让断言飘
	stinky._target_y = bottom_y
	stinky._wander_y_cd = 999.0
	await a.wait(3.0)
	_check(a, "闲逛时会上下挪", stinky.global_position.y > top_y + 10.0,
		str(top_y) + " -> " + str(stinky.global_position.y))
	_check(a, "纵向也没爬出地面条带", stinky.global_position.y <= bottom_y + 0.5,
		str(stinky.global_position.y) + " <= " + str(bottom_y))


## STEP11 钱掉在高处架子上时,蜗牛要爬上去捡,不是站在下面隔空收
## (钱落在产出它的植物旁边,见 DIM_Coin.create_coin,不再飞到屏幕最下面)
func _step11_high_coin_collected(a, garden) -> void:
	a.log("STEP11 高处的钱会爬上去捡")
	var stinky = garden.stinky
	if stinky == null:
		_check(a, "花园里有蜗牛", false, "null")
		return
	var coin: Coin = SceneRegistry.COIN_SILVER.instantiate()
	coin.setup(Vector2.ZERO)
	garden.drop_coin_parent.add_child(coin)
	## 最上面一排植物的落钱高度
	coin.global_position = Vector2(400.0, 150.0)
	stinky.wake_up()
	stinky._idle_turn_cd = 999.0
	stinky.global_position = Vector2(400.0, 260.0)
	await a.wait(1.0)
	_check(a, "架子上的钱也被当成目标", stinky.target_coin == coin, str(stinky.target_coin))
	await a.wait(2.0)
	_check(a, "会往架子上爬(纵向靠近钱)", stinky.global_position.y < 245.0,
		"260 -> " + str(snappedf(stinky.global_position.y, 0.1)))
	## 爬到钱边上才收,不是站在下面隔空取物
	var got := false
	for _t in 5:
		await a.wait(1.0)
		## 先判"节点还在吗"再读 is_get:钱被收走后 1 秒就 queue_free,
		## 反着写会在已释放对象上读属性(SCRIPT ERROR: previously freed)
		if not is_instance_valid(coin) or coin.is_get:
			got = true
			break
	## 钱可能已经被回收,别在已释放对象上读 global_position
	var coin_pos_text := str(coin.global_position) if is_instance_valid(coin) else "(已回收)"
	_check(a, "爬上去把钱捡走了", got,
		str(snappedf(stinky.global_position.y, 0.1)) + " 钱 " + coin_pos_text)
	if is_instance_valid(coin) and not coin.is_get:
		coin.queue_free()


## STEP12 追钱时是"朝钱爬":纵向也跟着钱走,不是只把横向对齐就完事
func _step12_move_toward_coin(a, garden) -> void:
	a.log("STEP12 追钱时朝钱爬(纵向也靠近钱)")
	var stinky = garden.stinky
	if stinky == null:
		_check(a, "花园里有蜗牛", false, "null")
		return
	var top_y: float = stinky.move_range.position.y
	var bottom_y: float = top_y + stinky.move_range.size.y
	## 钱放在条带最下面,蜗牛从条带最上面出发:横向纵向都得动才追得上
	var coin: Coin = _make_coin(garden, Vector2(600.0, bottom_y))
	stinky.wake_up()
	stinky.global_position = Vector2(300.0, top_y)
	await a.wait(3.0)
	_check(a, "追钱时横向在靠近钱", stinky.global_position.x > 320.0,
		str(stinky.global_position.x))
	_check(a, "追钱时纵向也在靠近钱", stinky.global_position.y > top_y + 15.0,
		str(top_y) + " -> " + str(stinky.global_position.y))
	if is_instance_valid(coin):
		coin.queue_free()


## STEP13 锁钱:盯上最近的一枚就一直追它,中途冒出更近的也不改主意,捡到手才换下一枚
func _step13_lock_nearest_coin(a, garden) -> void:
	a.log("STEP13 锁定最近的钱直到捡到手")
	var stinky = garden.stinky
	if stinky == null:
		_check(a, "花园里有蜗牛", false, "null")
		return
	stinky.wake_up()
	stinky._idle_turn_cd = 999.0
	stinky.global_position = Vector2(300.0, GROUND_Y)
	## 近的 A / 远的 B
	var coin_a: Coin = _make_coin(garden, Vector2(360.0, GROUND_Y))
	var coin_b: Coin = _make_coin(garden, Vector2(600.0, GROUND_Y))
	await a.wait(0.5)
	_check(a, "锁的是最近的那一枚", stinky.target_coin == coin_a, str(stinky.target_coin))
	await a.wait(2.5)
	var a_got: bool = (not is_instance_valid(coin_a)) or coin_a.is_get
	_check(a, "近的那枚被捡走了", a_got, str(a_got))
	## 远的那枚必须还活着:两枚都成了已释放对象时 == 会假绿(踩坑见 docs/工作记录 2026-10-04_蜗牛爬行逻辑排查)
	var b_alive: bool = is_instance_valid(coin_b) and not coin_b.is_get
	_check(a, "远的那枚还在场上", b_alive, str(coin_b))
	_check(a, "捡到手之后才换下一枚", b_alive and stinky.target_coin == coin_b,
		str(stinky.target_coin))
	var x_before: float = stinky.global_position.x
	await a.wait(0.6)
	_check(a, "换锁定后朝新的钱爬", b_alive and stinky.global_position.x > x_before,
		str(x_before) + " -> " + str(stinky.global_position.x))
	if is_instance_valid(coin_a):
		coin_a.queue_free()
	if is_instance_valid(coin_b):
		coin_b.queue_free()


## STEP14 蜗牛只在初始花园(阳光房)露面:翻到蘑菇园要藏起来,翻回阳光房还是原来那只
func _step14_only_in_initial_garden(a, garden) -> void:
	a.log("STEP14 蜗牛只在初始花园(阳光房)出现")
	var stinky = garden.stinky
	if stinky == null:
		_check(a, "花园里有蜗牛", false, "null")
		return
	_check(a, "初始花园里蜗牛是露着的", stinky.visible, str(stinky.visible))
	## 商店买下蘑菇园,花园里才有第二个能翻过去的背景(见 GardenManager._get_next_owned_bg_type)
	Global.global_game_state.garden_data["num_bg_page_1"] = 1
	## 走玩家真正的翻页路径
	garden._on_next_pressed()
	await a.wait(1.0)
	_check(a, "翻页后到了蘑菇园",
		garden.curr_bg_type == GardenManager.E_GardenBgType.MushroomGraden, str(garden.curr_bg_type))
	_check(a, "蘑菇园里蜗牛藏起来了", not stinky.visible, str(stinky.visible))
	_check(a, "藏起来时连 _process 也停了", not stinky.is_processing(), str(stinky.is_processing()))
	## 藏起来时点不到也喂不到(命中判定走 visible,见 Stinky.is_hit)
	_check(a, "藏起来时点不到蜗牛", not stinky.is_hit(stinky.global_position), "")
	## 别的花园里掉的钱不该被它隔空吃掉
	var coin: Coin = _make_coin(garden, stinky.global_position)
	stinky.wake_up()
	await a.wait(2.0)
	_check(a, "别的花园里的钱没被吃掉", is_instance_valid(coin) and not coin.is_get, str(coin))
	if is_instance_valid(coin):
		coin.queue_free()
	## 翻回初始花园:还是原来那只(位置与巧克力引用都没丢)
	garden._on_next_pressed()
	await a.wait(1.0)
	_check(a, "翻页后又回到阳光房",
		garden.curr_bg_type == GardenManager.E_GardenBgType.GreenHouse, str(garden.curr_bg_type))
	_check(a, "回到初始花园蜗牛又出现了", stinky.visible, str(stinky.visible))
	_check(a, "回来的还是原来那只蜗牛", garden.stinky == stinky, str(garden.stinky))


#region 断言与工具
## 在花园里放一枚钱(落点用花园真实的落地高度,见 GROUND_Y)
func _make_coin(garden, pos: Vector2) -> Coin:
	var coin: Coin = SceneRegistry.COIN_SILVER.instantiate()
	coin.setup(Vector2.ZERO)
	garden.drop_coin_parent.add_child(coin)
	coin.global_position = pos
	return coin


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[SNAIL] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


## 复位成「只拥有阳光房、没买过花园工具」的存档
func _reset_garden(state) -> void:
	state.garden_data = {
		"num_bg_page_0": 1,
		"num_bg_page_1": 0,
		"num_bg_page_2": 0,
		GlobalGameState.BOUGHT_GARDEN_TOOLS_KEY: [],
		GlobalGameState.GARDEN_TOOL_NUM_KEY: {},
	}
	state.curr_num_new_garden_plant = 0


func _mark_cleared(state, upto: int) -> void:
	state.curr_all_level_state_data = {}
	for i in range(1, upto + 1):
		state.curr_all_level_state_data["101_0_%04d" % i] = {"IsSuccess": true}
#endregion
