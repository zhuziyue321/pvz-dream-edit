extends RefCounted
## 探针：模组「招笑版」（向日葵 → 朝阳葵：只转头 + 持续流汗）
##
## ① 改名：装模组前图鉴里叫「向日葵」，装上叫「朝阳葵」，关掉又还回去
## ② 每局安装：进一个白天关，种两株向日葵（产光那株在左下）→ 两株身上各挂一个观察者
## ③ **只转头**：让左下那株产一次阳光 →
##      · 右上那株的**整株**（`Body`）纹丝不动（没转、没镜像）—— 花茎和叶子不动
##      · 它的**花头**（花瓣 / 脸那几张贴图）镜像了过去（scale.x < 0）并转向目标
##      · 花茎那张贴图没被镜像（scale.x > 0）
##      · 近的那株与**更远**的那株（要转的角度更大）**转头进度一致**、一起转完
##        —— 转一次头的时长是固定的，跟远近无关
## ④ **持续**：等 4 秒，花头还盯着那株（没转回来）、汗滴还挂着
## ⑤ 焦点换人：让右上那株也产阳光 → 左下那株的汗没了、花头摆正；汗挂到右上那株身上
##
## 机器可读汇总：最后一行 [ZHAOXIAO] result=PASS|FAIL failed=<n>

const LEVEL := "res://src/levels/mode_adventure/adventure_01_01.gd"

## 花头里离花心较远的一张贴图（镜像时位置明显往另一边跑）
const HEAD_SPRITE := ^"Body/BodyCorrect/SunFlower_leftpetal6"
## 花茎上的一张贴图（必须一点都不动）
const STEM_SPRITE := ^"Body/BodyCorrect/Stalk_top"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：模组「招笑版」==========")

	# ------------------------------------------------ STEP1 装上模组之前
	a.log("STEP1 模组关着时，图鉴里叫「向日葵」")
	_check(a, "图鉴名字 = 向日葵", _almanac_name() == "向日葵", _almanac_name())

	# ------------------------------------------------ STEP2 装上 → 改名
	a.log("STEP2 装上模组 → 名字变成「朝阳葵」")
	ModManager.set_mod_enabled(ModIds.ZHAOXIAO, true)
	_check(a, "图鉴名字 = 朝阳葵", _almanac_name() == "朝阳葵", _almanac_name())

	# ------------------------------------------------ STEP3 进关种两株
	a.log("STEP3 进一个白天关，种两株向日葵（产光那株在左下）")
	var para = (load(LEVEL) as GDScript).new()
	if para == null:
		_check(a, "关卡脚本可实例化", false, LEVEL)
		_finish(a)
		return
	Global.game_para = para
	GlobalUtils.change_scene(Global.main_scene_registry.get_scene_path(para.game_sences))
	await a.wait(3.0)
	var mg = GameContext.curr_main_game
	if mg == null:
		_check(a, "已进入主游戏", false, "GameContext.curr_main_game 为空")
		_finish(a)
		return
	var manager: PlantCellManager = mg.plant_cell_manager
	var producer: Plant000Base = _plant(manager, 2, 1, PlantIds.SUN_FLOWER)
	var watcher_plant: Plant000Base = _plant(manager, 1, 4, PlantIds.SUN_FLOWER)
	## 第三株：离产光那株**更远**（要转的角度更大）—— 用来验「转一次头的时长跟远近无关」
	var far_plant: Plant000Base = _plant(manager, 0, 7, PlantIds.SUN_FLOWER)
	if producer == null or watcher_plant == null or far_plant == null:
		_check(a, "三株向日葵都种得下", false, "格子不可用")
		_finish(a)
		return
	## 观察者节点上的方法要动态调，这里一律用**无类型**变量接（见 check_scripts.ps1 的 KNOWN LIMITATION 2）
	var producer_watch = producer.get_node_or_null(^"ChaoyangWatcher")
	var other_watch = watcher_plant.get_node_or_null(^"ChaoyangWatcher")
	var far_watch = far_plant.get_node_or_null(^"ChaoyangWatcher")
	_check(a, "产光那株挂上了观察者", producer_watch != null)
	_check(a, "近的那株挂上了观察者", other_watch != null)
	_check(a, "远的那株挂上了观察者", far_watch != null)
	var body: Node2D = watcher_plant.get_node_or_null(^"Body") as Node2D
	var head_sprite: Sprite2D = watcher_plant.get_node_or_null(HEAD_SPRITE) as Sprite2D
	var stem_sprite: Sprite2D = watcher_plant.get_node_or_null(STEM_SPRITE) as Sprite2D
	if producer_watch == null or other_watch == null or far_watch == null or body == null \
			or head_sprite == null or stem_sprite == null:
		_check(a, "花头 / 花茎那两张对照贴图都找得到", false, "节点缺失")
		_finish(a)
		return
	var head_x_before := head_sprite.position.x
	_check(a, "初始：整株没被碰过（rotation = 0，scale.x > 0）",
		is_zero_approx(body.rotation) and body.scale.x > 0.0,
		"rot=%s scale.x=%s" % [str(body.rotation), str(body.scale.x)])
	## 关掉三株的**真实**产光计时器（首产 3~12.5 秒随机）：本探针只按自己的节奏手动触发，
	## 不然随时会有一株"真的"产光，把焦点抢走、断言飘
	_stop_create_sun_timer(producer)
	_stop_create_sun_timer(watcher_plant)
	_stop_create_sun_timer(far_plant)

	# ------------------------------------------------ STEP4 产光 → 只转头
	a.log("STEP4 左下那株产一次阳光：另外两株**只转头**（花茎叶子不动），且转的时长一样")
	producer_watch.on_sun_produced()
	## 先趁转头走到一半看一眼：两株的进度应当一模一样（同一帧起、同一个固定时长）
	await a.wait(0.1)
	var near_progress := float(other_watch.get_turn_progress())
	var far_progress := float(far_watch.get_turn_progress())
	_check(a, "同一批被叫到的花，转头进度一致（时长与远近无关）",
		absf(near_progress - far_progress) < 0.2,
		"近 %.2f vs 远 %.2f" % [near_progress, far_progress])
	_check(a, "两株都还在转的途中（不是一帧就闪过去）",
		near_progress > 0.02 and near_progress < 0.98
		and far_progress > 0.02 and far_progress < 0.98,
		"近 %.2f / 远 %.2f" % [near_progress, far_progress])
	await a.wait(0.5)   ## 等这一段转头走完
	_check(a, "整株没转也没镜像（只动花头）",
		is_zero_approx(body.rotation) and body.scale.x > 0.0,
		"rot=%s scale.x=%s" % [str(body.rotation), str(body.scale.x)])
	_check(a, "花头镜像了过去（目标在左边）", head_sprite.scale.x < 0.0, str(head_sprite.scale.x))
	_check(a, "花头位置确实翻到了另一边", head_sprite.position.x - head_x_before > 5.0,
		"x %.1f → %.1f" % [head_x_before, head_sprite.position.x])
	_check(a, "花茎没被镜像（scale.x 还是正的）", stem_sprite.scale.x > 0.0, str(stem_sprite.scale.x))
	_check(a, "花头转了个角度（右侧对准目标；不同行所以不是 0）",
		absf(float(other_watch.get_head_angle())) > 0.05, str(other_watch.get_head_angle()))
	_check(a, "两株都转完了（进度到 1）",
		float(other_watch.get_turn_progress()) >= 1.0 and float(far_watch.get_turn_progress()) >= 1.0,
		"近 %.2f / 远 %.2f" % [float(other_watch.get_turn_progress()), float(far_watch.get_turn_progress())])
	_check(a, "产光那株开始流汗", producer.get_node_or_null(^"ChaoyangSweat") != null)

	# ------------------------------------------------ STEP5 持续
	a.log("STEP5 都是持续的：等 4 秒，花头还盯着它、汗还挂着")
	await a.wait(4.0)
	_check(a, "花头没转回来（还是镜像的）", head_sprite.scale.x < 0.0, str(head_sprite.scale.x))
	_check(a, "花头角度还在", absf(float(other_watch.get_head_angle())) > 0.05,
		str(other_watch.get_head_angle()))
	_check(a, "汗滴还挂着（纯贴图，不做动画，不自己消失）",
		producer.get_node_or_null(^"ChaoyangSweat") != null)

	# ------------------------------------------------ STEP6 焦点换人
	a.log("STEP6 右上那株也产阳光：焦点换人 —— 旧的停汗、花头摆正，汗挂到新的身上")
	other_watch.on_sun_produced()
	await a.wait(0.6)
	_check(a, "左下那株的汗没了", producer.get_node_or_null(^"ChaoyangSweat") == null)
	_check(a, "右上那株开始流汗（焦点在它身上）",
		watcher_plant.get_node_or_null(^"ChaoyangSweat") != null)
	_check(a, "右上那株花头摆正（它自己是产光那株）", head_sprite.scale.x > 0.0, str(head_sprite.scale.x))
	_check(a, "左下那株转头看向它（目标在右边 → 不镜像，但转了角度）",
		absf(float(producer_watch.get_head_angle())) > 0.05, str(producer_watch.get_head_angle()))
	_check(a, "整株照旧没被碰过（只动花头）",
		is_zero_approx(body.rotation) and body.scale.x > 0.0,
		"rot=%s scale.x=%s" % [str(body.rotation), str(body.scale.x)])

	# ------------------------------------------------ STEP7 关掉模组
	a.log("STEP7 关掉模组 → 名字还回去")
	ModManager.set_mod_enabled(ModIds.ZHAOXIAO, false)
	_check(a, "图鉴名字回到向日葵", _almanac_name() == "向日葵", _almanac_name())
	## 开关是**持久化**的，跑完必须存回去，别把后面的探针带歪
	ModManager.save_mods()
	_finish(a)


#region 小工具
## 图鉴里向日葵那一条的「名字」（界面到处读的就是这一处）
func _almanac_name() -> String:
	var read_data := Global.global_read_data
	read_data.ensure_almanac_loaded()
	var all_plant_data: Dictionary = read_data.data_almanac.get("Plant", {})
	var entry: Dictionary = all_plant_data.get("SunFlower", {})
	return String(entry.get("名字", ""))


## 在指定格子种一株，返回那株植物（格子不可种 / 种不出来返回 null）
func _plant(manager, row: int, col: int, plant_type: StringName) -> Plant000Base:
	var cell: PlantCell = manager.all_plant_cells[row][col]
	if cell == null or not cell.can_common_plant:
		return null
	var plant := cell.create_plant(plant_type)
	return plant if is_instance_valid(plant) else null


## 停掉一株向日葵的真实产光计时器（说见 STEP3 那句注释）
func _stop_create_sun_timer(plant: Plant000Base) -> void:
	var timer: Timer = plant.get_node_or_null(
		^"CreateSunComponent/CreateSunTimer") as Timer
	if timer != null:
		timer.stop()
#endregion


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[ZHAOXIAO] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
