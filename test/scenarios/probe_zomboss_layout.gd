extends RefCounted
## 探针：僵王博士在 800x600 视口下的实际落点
## 覆盖：进冒险 5-10（僵王关）→ 等博士出场并播完入场 → dump 各部件的**屏幕坐标**+ 截图。
## 背景：博士是从 1066x600 版本整体移植的（BodyCorrect=(100,0)、部件局部 x 高达 900~1050），
##      spawn 点 (1030,330) 也是 1066 时代的数字，800 视口下要整体位移。
## 机器可读汇总：最后一行 [ZOMBOSSLAYOUT] result=PASS|FAIL failed=<n>

const LEVEL_PATH := "res://src/levels/mode_adventure/adventure_05_10.gd"
const SHOT_PATH := "res://test/shots/zomboss_layout.png"

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 僵王博士落点 ==========")
	var para: Resource = (load(LEVEL_PATH) as GDScript).new()
	Global.game_para = para
	a.get_tree().change_scene_to_file(
		Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameRoof]
	)
	await a.wait(3.0)

	var mg := Global.main_game
	_check(a, "已进入主游戏", mg != null, "Global.main_game 为空")
	if mg == null:
		_finish(a)
		return
	a.log("  进度 = " + str(mg.main_game_progress))
	if mg.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD:
		mg.main_game_start()
	await a.wait(2.0)
	a.log("  进度 = " + str(mg.main_game_progress))

	## 等博士出场（boss_spawn_wave = 0，开战即自动出场）
	var boss: Node2D = null
	for _i in 40:
		var bosses := mg.zombie_manager.get_living_bosses()
		if not bosses.is_empty():
			boss = bosses[0]
			break
		await a.wait(0.5)
	_check(a, "博士已出场", boss != null, "20 秒内没有僵王实例")
	if boss == null:
		_finish(a)
		return
	a.log("  博士已出场")

	## 等入场动画走完、首个技能放完，落到 idle 再量（Spawn 姿势头是低着的）
	for _i in 60:
		var sm2 = boss.get("state_machine")
		var st_name: String = str(sm2.current_state.name) if sm2 != null and sm2.get("current_state") != null else ""
		if st_name == "Idle":
			break
		await a.wait(0.5)
	await a.wait(1.0)

	var vp: Vector2 = a.get_tree().root.get_visible_rect().size
	var cam := mg.camera_2d.global_position
	a.log("视口 = " + str(vp) + "  相机 = " + str(cam))
	a.log("博士根 position = " + str(boss.position) + "  global = " + str(boss.global_position))
	var sm = boss.get("state_machine")
	if sm != null and sm.get("current_state") != null:
		a.log("当前状态 = " + str(sm.current_state.name))

	var body: Node2D = boss.get_node_or_null("Body")
	_check(a, "Body 节点存在", body != null, "节点缺失")
	if body == null:
		_finish(a)
		return

	var total := Rect2()
	for node in body.find_children("*", "Sprite2D", true, false):
		var sp := node as Sprite2D
		if not sp.visible or sp.texture == null or sp.self_modulate.a < 0.05:
			continue
		var r := _screen_rect(sp)
		total = total.merge(r) if total.size != Vector2.ZERO else r
		a.log("  [INFO] " + str(sp.get_parent().name) + "/" + str(sp.name) \
			+ " 屏幕 x " + str(snappedf(r.position.x, 0.1)) + " .. " + str(snappedf(r.end.x, 0.1)) \
			+ "  y " + str(snappedf(r.position.y, 0.1)) + " .. " + str(snappedf(r.end.y, 0.1)))

	a.log("")
	a.log("  ==> 机甲整体屏幕包围盒 x " + str(snappedf(total.position.x, 0.1)) + " .. " + str(snappedf(total.end.x, 0.1)) \
		+ "   y " + str(snappedf(total.position.y, 0.1)) + " .. " + str(snappedf(total.end.y, 0.1)))
	a.log("  ==> 视口宽 = " + str(vp.x) + "  右溢出 = " + str(snappedf(total.end.x - vp.x, 0.1)) \
		+ "  左溢出 = " + str(snappedf(-total.position.x, 0.1)))

	## 关键锚点的屏幕坐标
	for p in ["Body/BodyCorrect/Head/Boss_head2", "Body/BodyCorrect/InnerLeg/Boss_innerleg_foot",
		"Body/BodyCorrect/OuterLeg/Boss_outerleg_foot", "Shadow", "HurtBoxComponent"]:
		var n: Node2D = boss.get_node_or_null(p)
		if n == null:
			continue
		var s := n.get_global_transform_with_canvas() * Vector2.ZERO
		a.log("  [锚点] " + p + " 屏幕 (" + str(snappedf(s.x, 0.1)) + ", " + str(snappedf(s.y, 0.1)) + ")")

	## 截图
	var tex: ViewportTexture = a.get_tree().root.get_texture()
	if tex != null:
		var img: Image = tex.get_image()
		var err := img.save_png(SHOT_PATH)
		a.log("  截图 -> " + SHOT_PATH + "  err=" + str(err))

	_finish(a)


## Sprite2D 的屏幕矩形（近似：只变换四角，不做旋转外接）
func _screen_rect(sp: Sprite2D) -> Rect2:
	var xform := sp.get_global_transform_with_canvas()
	var size := sp.texture.get_size()
	var off := Vector2.ZERO
	if sp.centered:
		off = -size * 0.5
	var r := Rect2(xform * off, Vector2.ZERO)
	r = r.expand(xform * (off + Vector2(size.x, 0.0)))
	r = r.expand(xform * (off + Vector2(0.0, size.y)))
	r = r.expand(xform * (off + size))
	return r


#region 断言
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label)
	else:
		_failed += 1
		a.log("  [NG] " + label + "  " + detail)


func _finish(a) -> void:
	a.log("")
	a.log("[ZOMBOSSLAYOUT] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
