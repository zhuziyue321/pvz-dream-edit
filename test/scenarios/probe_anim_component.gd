extends RefCounted
## 探针：动画组件的**封装**（驱动源 + 本地请求 + 远端包驱动）
##
## 覆盖（都是编译门禁抓不到、只能跑起来才知道的那类）：
##   1. `AnimComponentNorm` 用 `host_node_of(owner, ^"AnimationTree")` 能取到树
##      （原来是 `$"../AnimationTree"`；取不到会打到一条 WARN，本探针同时断言树非空）
##   2. `snapshot()` 的 名字 / 下标 / 相位 三者自洽（下标 ↔ 名字往返一致）
##   3. `take_over()` 把驱动源切到 REMOTE，且幂等
##   4. `apply_anim_index()` 真能切播另一条动画
##   5. `apply_anim_phase()` 真能把播放头拉过去
##   6. `release()` 把树还给本地驱动
##   7. 表现接口：`on_anim_event()` 转发成 `anim_event` 信号；`apply_visual()` 的
##      四种操作（tint / z / part_visible / swap_texture）真改到节点且能还原
##
## 做法：进 1-1（不必等开战），挂一株**展示状态**的豌豆射手，直接在它身上验组件。
## 展示角色走的是同一条 `character_base.tscn` 主链，动画组件完全一样。
##
## 机器可读汇总：最后一行 [ANIMCOMP] result=PASS|FAIL failed=<n>

const MENU_BUTTON := "/root/StartMenu/BG_Right/Menu/Button1"
const PLANT_SCENE := "res://src/entities/character/plant/plant_pea_shooter_single.tscn"
## 地刺：状态机的状态名固定为 `Caltrop_idle` / `BlendTree`，用来验本地显式切状态
const CALTROP_SCENE := "res://src/entities/character/plant/plant_caltrop.tscn"
## 睡眠组的 10 株（状态名 / 展示体醒来后应在的状态）
## ⚠️ 冰菇有两套待机：展示体走 `IceShroom_idle_only`（`is_show` 分支）
const SLEEP_PLANTS := [
	["res://src/entities/character/plant/plant_doom_shroom.tscn", "DoomShroom_sleep", "DoomShroom_idle"],
	["res://src/entities/character/plant/plant_fume_shroom.tscn", "FumeShroom_sleep", "FumeShroom_idle"],
	["res://src/entities/character/plant/plant_gloom_shroom.tscn", "GloomShroom_sleep", "GloomShroom_idle"],
	["res://src/entities/character/plant/plant_hypno_shroom.tscn", "HypnoShroom_sleep", "HypnoShroom_idle"],
	["res://src/entities/character/plant/plant_ice_shroom.tscn", "IceShroom_sleep", "IceShroom_idle_only"],
	["res://src/entities/character/plant/plant_magnet_shroom.tscn", "Magnetshroom_sleep", "Magnetshroom_idle"],
	["res://src/entities/character/plant/plant_puff.tscn", "PuffShroom_sleep", "PuffShroom_idle"],
	["res://src/entities/character/plant/plant_scaredy_shroom.tscn", "ScaredyShroom_sleep", "ScaredyShroom_idle"],
	["res://src/entities/character/plant/plant_sea_shroom.tscn", "SeaShroom_sleep", "SeaShroom_idle"],
	["res://src/entities/character/plant/plant_sun_shroom.tscn", "SunShroom_sleep", "SunShroom_idle"],
]

## 已从「表达式推导」迁到「脚本点名」的植物及其状态名（防状态名写错 —— 写错只会静默不动）
const MIGRATED_STATES := [
	["res://src/entities/character/plant/plant_spike_rock.tscn", ["SpikeRock_attack", "SpikeRock_idle"]],
	["res://src/entities/character/plant/plant_squash.tscn", ["Squash_idle", "Squash_lookleft", "Squash_lookright"]],
	["res://src/entities/character/plant/plant_umbrella_leaf.tscn", ["Umbrellaleaf_idle", "Umbrellaleaf_block"]],
	["res://src/entities/character/plant/plant_chomper.tscn", ["Chomper_idle", "Bite", "Chomper_chew", "Chomper_swallow"]],
	["res://src/entities/character/plant/plant_cob_cannon.tscn", ["CobCannon_shooting", "CobCannon_charge"]],
	["res://src/entities/character/plant/plant_magnet_shroom.tscn", ["Magnetshroom_shooting", "Magnetshroom_idle"]],
	["res://src/entities/character/plant/plant_potato_mine.tscn", ["PotatoMine_rise"]],
	["res://src/entities/character/plant/plant_sun_shroom.tscn", ["SunShroom_grow"]],
	["res://src/entities/character/plant/plant_scaredy_shroom.tscn", ["ScaredyShroom_scared", "ScaredyShroom_grow"]],
	["res://src/entities/character/plant/plant_cactus.tscn", ["Cactus_rise", "Cactus_lower"]],
]

## 本次改过动画状态的**全部**植物（展示体必须有动画在播 —— 兜住"Start 边改手动后漏了 request"）
const TOUCHED_PLANTS := [
	"plant_blover", "plant_cactus", "plant_caltrop", "plant_cherry_bomb", "plant_chomper",
	"plant_cob_cannon", "plant_coffee_bean", "plant_doom_shroom", "plant_flower_pot",
	"plant_fume_shroom", "plant_gloom_shroom", "plant_grave_buster", "plant_hypno_shroom",
	"plant_ice_shroom", "plant_imitater", "plant_jalapeno", "plant_magnet_shroom",
	"plant_potato_mine", "plant_puff", "plant_scaredy_shroom", "plant_sea_shroom",
	"plant_spike_rock", "plant_squash", "plant_sun_shroom", "plant_tanglekelp",
	"plant_umbrella_leaf", "plant_wall_nut",
]

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 动画组件封装 ==========")
	if not await _goto_level(a):
		_finish(a)
		return
	var plant := await _spawn_show_plant(a, PLANT_SCENE)
	if plant == null:
		_check(a, "挂上一株展示状态的豌豆射手", false)
		_finish(a)
		return
	_check(a, "挂上一株展示状态的豌豆射手", true)
	await _check_component(a, plant)
	await _check_presentation(a, plant)
	plant.queue_free()
	await _check_local_state(a)
	await _check_sleep_group(a)
	await _check_spike_rock_switch(a)
	await _check_migrated_states(a)
	await _check_initial_state_all(a)
	_finish(a)


#region 前置：进关卡、造一株展示植物
func _goto_level(a) -> bool:
	await a.wait_stable(MENU_BUTTON, 8.0)
	await a.click_first(MENU_BUTTON)
	if not await a.wait_scene("main_game", 25.0):
		_check(a, "进入 1-1 关卡", false, str(a.get_tree().current_scene))
		return false
	## 不必等开战：展示角色不参与战斗，组件初始化在同一条 `_ready` 链上
	await a.wait(1.0)
	return true


func _spawn_show_plant(a, scene_path: String = PLANT_SCENE) -> Plant000Base:
	var main_game = GameContext.curr_main_game
	if main_game == null:
		return null
	var scene: PackedScene = load(scene_path)
	if scene == null:
		return null
	var plant: Plant000Base = scene.instantiate()
	## ⚠️ 初始化参数必须在入树之前给（见 `Plant000Base.init_plant`）
	plant.init_plant({
		Plant000Base.E_PInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsShow,
	})
	main_game.add_child(plant)
	await a.frames(3)
	return plant
#endregion


#region 组件断言
func _check_component(a, plant: Plant000Base) -> void:
	a.log("")
	a.log("--- 动画组件（%s）---" % plant.get_script().resource_path.get_file())
	var comp: AnimComponentBase = plant.anim_component
	_check(a, "角色挂上了动画组件", is_instance_valid(comp))
	if not is_instance_valid(comp):
		return
	_check(a, "默认驱动源是本地（单机由角色代码控制）", not comp.is_remote_driven())

	## 1. 树 / 播放器取得到（换过访问方式，取不到就是静默失同步）
	var player := comp.get_animation_player()
	_check(a, "组件拿得到 AnimationPlayer", player != null)
	var norm := comp as AnimComponentNorm
	_check(a, "该角色走的是 AnimationTree 那条实现", norm != null)
	if norm != null:
		_check(a, "★ 动画树取得到（host_node_of 生效）", norm.animation_tree != null)
	if player == null:
		return

	## 2. 采集自洽
	await a.frames(2)
	comp.update_current_anim()
	var anim_name := comp.anim_name_now
	_check(a, "读得到当前动画名", anim_name != &"", str(anim_name))
	var snap := comp.snapshot()
	_check(a, "快照里的名字与上报一致", snap[&"name"] == anim_name, str(snap))
	var idx := int(snap[&"index"])
	_check(a, "下标不是 ANIM_NONE", idx != AnimComponentBase.ANIM_NONE, str(idx))
	_check(a, "★ 下标 ↔ 名字 往返一致",
		comp.anim_name_at(idx) == anim_name, "%s -> %d -> %s" % [anim_name, idx, comp.anim_name_at(idx)])

	## 3. 接管（幂等）
	comp.take_over()
	comp.take_over()
	_check(a, "★ 接管后驱动源是 REMOTE", comp.is_remote_driven())
	if norm != null:
		_check(a, "接管后动画树已冻结（本地逻辑抢不回动画）", not norm.animation_tree.active)

	## 4. 按下标切播另一条
	var other := _other_index(comp, idx)
	if other == AnimComponentBase.ANIM_NONE:
		a.log("  [SKIP] 这个角色只有一条动画，跳过切换断言")
	else:
		comp.apply_anim_index(other)
		await a.frames(2)
		var expect := comp.anim_name_at(other)
		_check(a, "★ apply_anim_index 真的切到了另一条",
			player.current_animation == expect,
			"expect=%s got=%s" % [expect, player.current_animation])

	## 5. 相位对齐
	comp.apply_anim_phase(0.2)
	await a.frames(1)
	if player.current_animation != &"":
		_check(a, "★ apply_anim_phase 把播放头拉到位",
			absf(player.current_animation_position - 0.2) < 0.12,
			"pos=%.3f" % player.current_animation_position)

	## 6. 交还本地
	comp.release()
	_check(a, "★ 交还本地驱动后驱动源是 LOCAL", not comp.is_remote_driven())
	if norm != null:
		_check(a, "交还后动画树恢复运行", norm.animation_tree.active)


## 本地驱动：`request_state()` 真能切状态机（地刺迁移试点的回归点）
##
## ⚠️ 这一段是补上次漏测的：远端 API 全测了，本地 `request_state()` 却没测，
##    结果树根是混合树、状态机在它下面 —— 函数里 `tree_root is AnimationNodeStateMachine`
##    恒为 false，静默 return，地刺于是完全不攻击。
func _check_local_state(a) -> void:
	a.log("")
	a.log("--- 本地驱动：request_state 切状态（地刺）---")
	var plant := await _spawn_show_plant(a, CALTROP_SCENE)
	if plant == null:
		_check(a, "挂上地刺展示体", false)
		return
	var comp: AnimComponentBase = plant.anim_component
	var norm := comp as AnimComponentNorm
	_check(a, "地刺走 AnimationTree 实现", norm != null)
	if norm == null:
		plant.queue_free()
		return
	var pb = norm.animation_tree.get(AnimComponentNorm.PLAYBACK_PARAM)
	_check(a, "拿得到顶层状态机 playback", pb != null)
	if pb == null:
		plant.queue_free()
		return
	comp.request_state(&"BlendTree")
	## 过渡有 xfade（0.2 秒），等够再读当前状态
	await a.wait(0.5)
	_check(a, "★ request_state 切到攻击状态（BlendTree）",
		String(pb.get_current_node()) == "BlendTree",
		"%s path=%s" % [pb.get_current_node(), str(pb.get_travel_path())])
	comp.request_state(&"Caltrop_idle")
	await a.wait(0.5)
	_check(a, "★ request_state 切回待机（Caltrop_idle）",
		String(pb.get_current_node()) == "Caltrop_idle",
		"%s path=%s" % [pb.get_current_node(), str(pb.get_travel_path())])
	## 再走一遍**实战链路**：检测信号 → 地刺脚本回调 → 组件 → 状态机
	plant._on_can_attack()
	await a.wait(0.5)
	_check(a, "★ 检测到敌人的回调能把地刺切去攻击",
		String(pb.get_current_node()) == "BlendTree", String(pb.get_current_node()))
	plant._on_not_can_attack()
	await a.wait(0.5)
	_check(a, "★ 敌人离开的回调能把地刺切回待机",
		String(pb.get_current_node()) == "Caltrop_idle", String(pb.get_current_node()))
	plant.queue_free()


## 睡眠组：`*_sleep` / `*_idle` 后缀切换由基类一条逻辑覆盖全部蘑菇类植物
func _check_sleep_group(a) -> void:
	a.log("")
	a.log("--- 睡眠组（基类通用切换，共 %d 株）---" % SLEEP_PLANTS.size())
	for entry in SLEEP_PLANTS:
		var scene_path: String = entry[0]
		var sleep_state: String = entry[1]
		var idle_state: String = entry[2]
		var file_name := scene_path.get_file()
		var plant := await _spawn_show_plant(a, scene_path)
		if plant == null:
			_check(a, "%s 挂得上" % file_name, false)
			continue
		var norm := plant.anim_component as AnimComponentNorm
		if norm == null or norm.animation_tree == null:
			_check(a, "%s 有动画树" % file_name, false)
			plant.queue_free()
			continue
		var pb = norm.animation_tree.get(AnimComponentNorm.PLAYBACK_PARAM)
		plant._on_anim_sleep_start()
		await a.wait(0.35)
		_check(a, "%s 睡着 → %s" % [file_name, sleep_state],
			String(pb.get_current_node()) == sleep_state, String(pb.get_current_node()))
		plant._on_anim_sleep_end()
		await a.wait(0.35)
		_check(a, "%s 醒来 → %s" % [file_name, idle_state],
			String(pb.get_current_node()) == idle_state, String(pb.get_current_node()))
		plant.queue_free()


## 钢地刺：把「检测信号 → 脚本 → 组件 → 状态机」的实战链路再验一遍（与地刺同构）
func _check_spike_rock_switch(a) -> void:
	a.log("")
	a.log("--- 钢地刺：信号链路切状态 ---")
	var plant := await _spawn_show_plant(a, "res://src/entities/character/plant/plant_spike_rock.tscn")
	if plant == null:
		_check(a, "挂上钢地刺展示体", false)
		return
	var norm := plant.anim_component as AnimComponentNorm
	if norm == null or norm.animation_tree == null:
		_check(a, "钢地刺有动画树", false)
		plant.queue_free()
		return
	var pb = norm.animation_tree.get(AnimComponentNorm.PLAYBACK_PARAM)
	plant._on_can_attack()
	await a.wait(0.35)
	_check(a, "★ 钢地刺：检测到敌人 → SpikeRock_attack",
		String(pb.get_current_node()) == "SpikeRock_attack", String(pb.get_current_node()))
	plant._on_not_can_attack()
	## ⚠️ 这条转换是 `switch_mode = 2`（At End）：要等攻击动画播完才真的切，
	##    等 0.35 秒读到的还是 attack（不是没生效）
	await a.wait(1.5)
	_check(a, "★ 钢地刺：敌人离开 → SpikeRock_idle",
		String(pb.get_current_node()) == "SpikeRock_idle", String(pb.get_current_node()))
	plant.queue_free()


## 已迁移植物：状态名必须真实存在（写错 → `request_state()` 只打一条 WARN，动画不动）
func _check_migrated_states(a) -> void:
	a.log("")
	a.log("--- 已迁移植物：状态名存在性（%d 株）---" % MIGRATED_STATES.size())
	for entry in MIGRATED_STATES:
		var scene_path: String = entry[0]
		var file_name := scene_path.get_file()
		var plant := await _spawn_show_plant(a, scene_path)
		if plant == null:
			_check(a, "%s 挂得上" % file_name, false)
			continue
		var comp: AnimComponentBase = plant.anim_component
		for state_name in entry[1]:
			var want := StringName(state_name)
			var found := comp.find_state_by_suffix(want)
			_check(a, "%s 有状态 %s" % [file_name, state_name], found == want, str(found))
		plant.queue_free()


## 全部改过的植物：展示体必须有动画在播
##
## ★ 这是把 `Start → *` 也改成手动 travel 之后的**兜底断言**：任何一株漏了
##   `_apply_initial_anim_state()` 的 request，就会停在 Start（完全没有动画），这里立刻暴露。
func _check_initial_state_all(a) -> void:
	a.log("")
	a.log("--- 初始状态：全部改过的植物（%d 株）---" % TOUCHED_PLANTS.size())
	for short_name in TOUCHED_PLANTS:
		var scene_path := "res://src/entities/character/plant/%s.tscn" % short_name
		var plant := await _spawn_show_plant(a, scene_path)
		if plant == null:
			_check(a, "%s 挂得上" % short_name, false)
			continue
		await a.frames(3)
		var comp: AnimComponentBase = plant.anim_component
		var norm := comp as AnimComponentNorm
		if norm == null or norm.animation_tree == null:
			_check(a, "%s 有动画树" % short_name, false)
			plant.queue_free()
			continue
		var pb = norm.animation_tree.get(AnimComponentNorm.PLAYBACK_PARAM)
		var current := String(pb.get_current_node())
		## ⚠️ 判据是"已离开 Start"，不能判 `anim_name_now != &""`：
		##    仙人掌的初始状态是**混合树**（`BlendTree`），下钻拿不到叶子动画名（本来就读不到）
		_check(a, "%s 已进入初始状态" % short_name, current != "" and current != "Start", current)
		## 场景里配了 `show_anim_state` 的（阳光菇 / 土豆雷），状态机当前节点必须是它
		if plant.show_anim_state != &"":
			_check(a, "%s 展示态 = %s" % [short_name, plant.show_anim_state],
				current == String(plant.show_anim_state), current)
		plant.queue_free()


## 表现接口：动画事件转发 + 四种视觉操作
##
## ★ 这一层的意义：业务代码（攻击组件 / 受击窗口 / 各种"看起来怎样"）以后只走这两个入口，
##   动画资源只认 `on_anim_event`，颜色 / 层级 / 部件显隐不再由业务直接写节点属性。
func _check_presentation(a, plant: Plant000Base) -> void:
	a.log("")
	a.log("--- 表现接口（anim_event / apply_visual）---")
	var comp: AnimComponentBase = plant.anim_component
	_check(a, "角色有动画组件", is_instance_valid(comp))
	if not is_instance_valid(comp):
		return

	## 1. 动画方法轨 → 事件信号
	## ⚠️ 用 Array 收事件：GDScript 的 lambda 按**值**捕获局部变量，直接 `got = event` 改不到外面
	var got: Array[StringName] = []
	var cb := func(event: StringName) -> void: got.append(event)
	comp.anim_event.connect(cb)
	comp.on_anim_event("shoot")
	comp.anim_event.disconnect(cb)
	_check(a, "★ on_anim_event 转发成 anim_event 信号", got.has(&"shoot"), str(got))

	## 2. 整体着色（走 Body 的合成色，动画轨道盖不掉）
	var body: BodyCharacter = plant.body
	var before := body.modulate
	comp.apply_visual({&"kind": AnimComponentBase.VISUAL_TINT, &"color": Color(0.5, 0.5, 0.5)})
	await a.frames(1)
	_check(a, "★ VISUAL_TINT 改到 Body 的合成色", not body.modulate.is_equal_approx(before), str(body.modulate))
	comp.apply_visual({&"kind": AnimComponentBase.VISUAL_TINT, &"color": Color.WHITE})
	await a.frames(1)
	_check(a, "VISUAL_TINT 能还原", body.modulate.is_equal_approx(before), str(body.modulate))

	## 3. 层级增量（记的是偏移，不是绝对 z）
	var z0 := plant.z_index
	comp.apply_visual({&"kind": AnimComponentBase.VISUAL_Z, &"offset": 10})
	_check(a, "★ VISUAL_Z 加 10", plant.z_index == z0 + 10, str(plant.z_index))
	comp.apply_visual({&"kind": AnimComponentBase.VISUAL_Z, &"offset": 0})
	_check(a, "VISUAL_Z 归零回到原点", plant.z_index == z0, str(plant.z_index))

	## 4. 部件显隐 / 换贴图（挑一个真带贴图的部件）
	var sprite := _first_body_sprite(body)
	if sprite == null:
		a.log("  [SKIP] 这株植物的 Body 下没有带贴图的 Sprite2D")
		return
	var part := sprite.name
	var visible_before := sprite.visible
	comp.apply_visual({&"kind": AnimComponentBase.VISUAL_PART_VISIBLE, &"part": part, &"visible": false})
	_check(a, "★ VISUAL_PART_VISIBLE 隐藏部件 %s" % part, not sprite.visible)
	comp.apply_visual({&"kind": AnimComponentBase.VISUAL_PART_VISIBLE, &"part": part, &"visible": visible_before})
	_check(a, "VISUAL_PART_VISIBLE 能还原", sprite.visible == visible_before)

	var tex_before := sprite.texture
	var tex_other := _other_texture(body, tex_before)
	if tex_before == null or tex_other == null:
		a.log("  [SKIP] 没有第二张贴图可换（换图断言跳过）")
		return
	comp.apply_visual({&"kind": AnimComponentBase.VISUAL_SWAP_TEXTURE, &"part": part, &"texture": tex_other})
	_check(a, "★ VISUAL_SWAP_TEXTURE 换掉部件贴图", sprite.texture == tex_other)
	comp.apply_visual({&"kind": AnimComponentBase.VISUAL_SWAP_TEXTURE, &"part": part, &"texture": tex_before})
	_check(a, "VISUAL_SWAP_TEXTURE 能还原", sprite.texture == tex_before)


## `Body` 子树里第一个带贴图的 Sprite2D
func _first_body_sprite(node: Node) -> Sprite2D:
	for child in node.get_children():
		if child is Sprite2D and (child as Sprite2D).texture != null:
			return child
		var found := _first_body_sprite(child)
		if found != null:
			return found
	return null


## `Body` 子树里另一张贴图（换图断言用）
func _other_texture(node: Node, exclude: Texture2D) -> Texture2D:
	for child in node.get_children():
		if child is Sprite2D:
			var tex := (child as Sprite2D).texture
			if tex != null and tex != exclude:
				return tex
		var found := _other_texture(child, exclude)
		if found != null:
			return found
	return null


## 找一条与当前不同的动画下标；没有就返回 ANIM_NONE
func _other_index(comp: AnimComponentBase, current: int) -> int:
	var player := comp.get_animation_player()
	if player == null:
		return AnimComponentBase.ANIM_NONE
	var list := player.get_animation_list()
	for i in range(list.size()):
		if i != current:
			return i
	return AnimComponentBase.ANIM_NONE
#endregion


#region 断言与收尾
func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[ANIMCOMP] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()
#endregion
