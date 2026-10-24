extends RefCounted
## 探针：智慧树（Tree of Wisdom）对齐原版的口径
## 覆盖：
##   1. 台词编号：施肥（TreeOfWisdomGiveWisdom）/ 闲聊（Babble）/ 重复（SayRepeat）/ 里程碑
##   2. 台词表 80 条一条不缺（编号 = 原版 [TREE_OF_WISDOM_<编号>]）
##   3. 页面接线：气泡 / 台词 / 高度文字节点都在
##   4. 点击判定四档固定矩形（TreeOfWisdomHitTest）
##   5. 状态机：0→1 不进弹跳、1→2 进 JUST_GREW、没长高时嘟囔会露出气泡、
##      ≥ 50 英尺才显示高度文字、100 英尺长高后讲里程碑台词
##   6. 悬停高亮：树干组挂上 shader 材质、取消后摘掉
## 机器可读汇总：最后一行 [TREEWISDOM] result=PASS|FAIL failed=<n>

var _failed := 0

const GARDEN_SCENE := "res://src/garden/garden.tscn"


func run(a) -> void:
	a.log("")
	a.log("========== 探针 智慧树（对齐原版） ==========")
	await a.wait(2.0)

	var state = Global.global_game_state
	_mark_cleared(state, 50)
	state.garden_data = {"num_bg_page_0": 1}
	state.curr_num_new_garden_plant = 0
	_check(a, "买下智慧树", state.buy_tree_of_wisdom())
	var bag_num: int = state.get_garden_tool_num(GardenManager.E_GardenTool.TreeFood)
	_check(a, "白送 5 袋树肥料", bag_num == ConstTreeOfWisdom.TREE_FOOD_START_NUM, str(bag_num))

	a.log("STEP1 台词编号（原版 TreeOfWisdomGiveWisdom / Babble / SayRepeat）")
	_check(a, "高度 2 讲第 1 句", ConstTreeOfWisdom.get_give_wisdom_talk(2) == 1,
		str(ConstTreeOfWisdom.get_give_wisdom_talk(2)))
	_check(a, "高度 3 讲第 2 句", ConstTreeOfWisdom.get_give_wisdom_talk(3) == 2)
	_check(a, "高度 50 讲第 49 句", ConstTreeOfWisdom.get_give_wisdom_talk(50) == 49)
	_check(a, "高度 200 仍讲第 49 句", ConstTreeOfWisdom.get_give_wisdom_talk(200) == 49)
	_check(a, "100 英尺讲里程碑 800", ConstTreeOfWisdom.get_give_wisdom_talk(100) == 800)
	_check(a, "500 英尺讲里程碑 900", ConstTreeOfWisdom.get_give_wisdom_talk(500) == 900)
	_check(a, "1000 英尺讲里程碑 1000", ConstTreeOfWisdom.get_give_wisdom_talk(1000) == 1000)
	_check(a, "1001 英尺讲 1100", ConstTreeOfWisdom.get_give_wisdom_talk(1001) == 1100)

	_check(a, "一次没喂过时讨食 600",
		ConstTreeOfWisdom.get_babble_talk(0, 0) == ConstTreeOfWisdom.TALK_INDEX_HUNGRY)
	var t_hit0_small := ConstTreeOfWisdom.get_babble_talk(4, 0)
	_check(a, "高度 4 时 hit=0 不说开场白（走 201 池）",
		t_hit0_small >= 201 and t_hit0_small <= 205, str(t_hit0_small))
	_check(a, "高度 6 时 hit=0 说开场白 500",
		ConstTreeOfWisdom.get_babble_talk(6, 0) == ConstTreeOfWisdom.TALK_INDEX_REPEAT_INTRO)
	var t_hit1 := ConstTreeOfWisdom.get_babble_talk(60, 1)
	_check(a, "hit=1 取 101 池", t_hit1 >= 101 and t_hit1 <= 110, str(t_hit1))
	var t_mid := ConstTreeOfWisdom.get_babble_talk(11, 2)
	_check(a, "高度 11 取 201 池", t_mid >= 201 and t_mid <= 205, str(t_mid))
	var t_tall := ConstTreeOfWisdom.get_babble_talk(12, 2)
	_check(a, "高度 12 取 301 池", t_tall >= 301 and t_tall <= 305, str(t_tall))
	var t_huge := ConstTreeOfWisdom.get_babble_talk(50, 2)
	_check(a, "高度 50 取 401 池", t_huge >= 401 and t_huge <= 405, str(t_huge))
	var t_repeat := ConstTreeOfWisdom.get_repeat_talk(3)
	_check(a, "高度 3 重复旧台词只取 2..3", t_repeat >= 2 and t_repeat <= 3, str(t_repeat))

	var missing: Array[int] = []
	for i in range(1, 50):
		if ConstTreeOfWisdom.get_talk_line(i) == "":
			missing.append(i)
	for pool_start: int in [101, 201, 301, 401]:
		var size := 10 if pool_start == 101 else 5
		for i in range(pool_start, pool_start + size):
			if ConstTreeOfWisdom.get_talk_line(i) == "":
				missing.append(i)
	for special in [500, 600, 800, 900, 1000, 1100]:
		if ConstTreeOfWisdom.get_talk_line(special) == "":
			missing.append(special)
	_check(a, "台词表一条不缺", missing.is_empty(), str(missing))
	## 49 条智慧 + 10 + 5 + 5 + 5 条闲聊 + 500/600/800/900/1000/1100 = 80
	_check(a, "台词表共 80 条", ConstTreeOfWisdom.TALK_LINES.size() == 80,
		str(ConstTreeOfWisdom.TALK_LINES.size()))

	a.log("STEP2 进花园的智慧树页")
	GlobalUtils.change_scene(GARDEN_SCENE)
	if not await a.wait_scene("garden", 15.0):
		_check(a, "进入花园", false, str(a.get_tree().current_scene))
		_finish(a)
		return
	await a.wait(1.5)

	var garden = a.get_tree().current_scene
	garden.curr_bg_page_node.queue_free()
	garden.curr_bg_type = GardenManager.E_GardenBgType.TreeBg
	garden.init_new_page()
	await a.wait(1.0)

	var tree: TreeOfWisdom = garden.curr_bg_page_node
	_check(a, "当前页是智慧树", tree is TreeOfWisdom, str(tree))
	_check(a, "气泡 / 台词 / 高度文字都接上了",
		tree.speech_bubble != null and tree.speech_label != null and tree.height_label != null)
	_check(a, "高度 0 不显示高度文字", not tree.height_label.visible)
	_check(a, "刚进场还没说话，气泡隐藏", not tree.speech_bubble.visible)

	a.log("STEP3 点击判定（原版四档矩形）")
	_check(a, "高度 0 点树正中命中", tree.is_hit(Vector2(400, 300)))
	_check(a, "高度 0 点屏幕左上不命中", not tree.is_hit(Vector2(60, 60)))

	a.log("STEP3b 施肥落点（原版 TreeOfWisdomFertilize 的 (340,300)）")
	var food: TreeFood = garden.tree_food
	_check(a, "落点按原版 (340,300)", tree.get_feed_position().is_equal_approx(Vector2(340, 300)),
		str(tree.get_feed_position()))
	## 场景里 Body 为了让手持时袋子居中在光标上带了 (-40,-46)，落点必须抵掉它，
	## 否则整袋偏左上 40×46 像素（"肥料动画有偏移"就是这么来的）
	var probe_clone := food.clone_self() as TreeFood
	probe_clone.global_position = tree.get_feed_position() - food.body.position
	var probe_bag: Sprite2D = probe_clone.get_node("Body/Bag")
	_check(a, "袋子首帧的左上角落在原版坐标 (338.6, 302.9)",
		probe_bag.global_position.is_equal_approx(Vector2(338.6, 302.9)),
		str(probe_bag.global_position))
	probe_clone.queue_free()

	a.log("STEP4 长高与状态机")
	tree.add_height()
	_check(a, "0 → 1 英尺不进弹跳（原版 size<=1 走 NORMAL）", not tree.is_growing())
	tree.add_height()
	_check(a, "1 → 2 英尺进 JUST_GREW", tree.is_growing())
	_check(a, "高度 2 用小树矩形：点 (320,290) 命中", tree.is_hit(Vector2(320, 290)))

	a.log("STEP5 长高的拉伸动画（原版 PlayReanim 8 帧/秒）")
	var player: AnimationPlayer = tree._anim_player
	var anim := player.get_animation("grow2") if player != null and player.has_animation("grow2") else null
	_check(a, "grow2 动画存在", anim != null)
	if anim != null:
		var pos_track := -1
		for i in anim.get_track_count():
			if String(anim.track_get_path(i)) == "Tree1:position":
				pos_track = i
		_check(a, "grow2 的 Tree1 有多个关键帧（不是单帧定妆）",
			pos_track >= 0 and anim.track_get_key_count(pos_track) > 1,
			"track=%d keys=%d" % [pos_track, anim.track_get_key_count(pos_track) if pos_track >= 0 else -1])
		_check(a, "长高按 8 帧/秒 播（素材 12fps ⇒ 约 0.67 倍速）",
			absf(player.speed_scale - ConstTreeOfWisdom.ANIM_PLAY_RATE_GROW * anim.step) < 0.001,
			str(player.speed_scale))
		_check(a, "长高时在播（不是停住定妆）", player.is_playing())
		var grow_sprite: Sprite2D = tree._anim_layer.get_node_or_null("Tree1") if tree._anim_layer else null
		if grow_sprite != null and pos_track >= 0:
			## 隐藏期必须用「出场那一帧的姿态」顶住，否则 Godot 会从 (0,0) 插值过来，
			## 画面就是"新贴图从左上角滑进来"（Tree1 出场姿态是 381/308.2）
			player.seek(0.0, true)
			var y_hidden := grow_sprite.position.y
			_check(a, "隐藏期坐标已顶在出场姿态（不会从左上角滑入）",
				absf(y_hidden - 308.2) < 0.5 and not grow_sprite.visible, "y=%.1f" % y_hidden)
			## 原版这一档是「先拉长（sy ≈1.2、y 更靠上），再收回定妆姿态」
			player.seek(0.45, true)
			var y_mid := grow_sprite.position.y
			var sy_mid := grow_sprite.scale.y
			player.seek(player.current_animation_length, true)
			var y_end := grow_sprite.position.y
			var sy_end := grow_sprite.scale.y
			_check(a, "拉伸动画：Tree1 被拉长后收回定妆姿态",
				y_mid < y_end - 5.0 and sy_mid > sy_end + 0.1,
				"y %.1f -> %.1f, sy %.2f -> %.2f" % [y_mid, y_end, sy_mid, sy_end])

	tree.add_height(10)
	await a.wait(0.2)
	_check(a, "高度 12 用大树矩形：点 (440,180) 命中", tree.is_hit(Vector2(440, 180)))
	_check(a, "高度 12 用大树矩形：点 (280,120) 不命中", not tree.is_hit(Vector2(280, 120)))
	_check(a, "高度 12 还不显示高度文字", not tree.height_label.visible)

	tree._babble()
	_check(a, "嘟囔时气泡出现", tree.speech_bubble.visible)
	_check(a, "气泡里有台词", tree.speech_label.text != "", tree.speech_label.text)
	_check(a, "高度 12 的气泡位置取大树那档",
		tree.speech_bubble.position == ConstTreeOfWisdom.SPEECH_BUBBLE_POS_BIG,
		str(tree.speech_bubble.position))

	tree._set_hover(true)
	var hover_ok := not tree._trunk_sprites.is_empty() \
		and tree._trunk_sprites[0].material is ShaderMaterial
	_check(a, "悬停高亮给树干组挂上 shader 材质", hover_ok,
		str(tree._trunk_sprites.size()))
	tree._set_hover(false)
	_check(a, "取消悬停摘掉材质",
		tree._trunk_sprites.is_empty() or tree._trunk_sprites[0].material == null)

	tree.add_height(88)
	await a.wait(1.0)
	_check(a, "高度 100 显示高度文字", tree.height_label.visible and
		tree.height_label.text == "100英尺高", tree.height_label.text)
	await a.wait(0.5)
	_check(a, "100 英尺长高后讲里程碑台词",
		tree.speech_label.text.contains("daisies") and tree.speech_bubble.visible,
		tree.speech_label.text)

	_finish(a)


#region 断言与工具
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[TREEWISDOM] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


func _mark_cleared(state, upto: int) -> void:
	state.curr_all_level_state_data = {}
	for i in range(1, upto + 1):
		state.curr_all_level_state_data["101_0_%04d" % i] = {"IsSuccess": true}
#endregion
