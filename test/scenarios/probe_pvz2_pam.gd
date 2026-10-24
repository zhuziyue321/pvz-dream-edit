extends RefCounted
## 探针：PVZ2 五株植物的 `.pam.bin` + 模组「PAM 动画播放器」（无头可跑、不开局）
##
## 校验：
##   1. 五个 `.bin` 都能解析、部件全部绑上图集贴图（图集是 1536）
##   2. 各株脚本引用的状态名**真的存在**（`set_state()` 返回 true）——
##      状态名对不上时播放器是**静默失败**的（不报错、只是画面不动），只有探针能抓到
##   3. 状态帧数与 PAM 的 label 段一致（换 PAM 版本后这里立刻红）
##   4. 播放能推进；单次状态只发一次 `animation_finished`
##   5. 打印每株待机帧的包围盒（`get_render_rect()`）—— 调 `ANIM_PIVOT` / `ANIM_SCALE` 用
##
## 机器可读汇总：最后一行 `[PVZ2-PAM] result=PASS|FAIL failed=<n>`

const AnimatorScript := preload("res://mods_builtin/pam/runtime/pam_animator.gd")

## 每株：模组目录名 / 脚本（取常量）/ 必须存在的状态 / 期望帧数
const PLANTS := [
	{
		"name": "bonkchoy",
		"script": preload("res://mods_builtin/pvz2/bonkchoy/bonkchoy_plant.gd"),
		"states": {
			"idle": 30, "idle2": 30, "idle3": 31,
			"attack": 10, "attack2": 10, "attack4": 15, "attack5": 15,
		},
	},
	{
		"name": "celerystalker",
		"script": preload("res://mods_builtin/pvz2/celerystalker/celerystalker_plant.gd"),
		"states": {
			"idle": 50, "idle2": 50, "idle3": 50, "idle4": 50,
			"down": 32, "up": 32, "attack": 8, "attack_loop": 21, "attack_end": 18,
		},
	},
	{
		"name": "firepeashooter",
		"script": preload("res://mods_builtin/pvz2/firepeashooter/firepeashooter_plant.gd"),
		"states": {"idle": 31, "idle2": 31, "attack": 31},
	},
	{
		"name": "peapod",
		"script": preload("res://mods_builtin/pvz2/peapod/peapod_plant.gd"),
		"states": {
			"idle": 30, "idle2": 30, "idle3": 30, "idle4": 30, "idle5": 30,
			"attack": 31, "attack 2": 30, "attack 3": 30, "attack 4": 30, "attack 5": 30,
		},
	},
	{
		"name": "goopeashooter",
		"script": preload("res://mods_builtin/pvz2/goopeashooter/goopeashooter_plant.gd"),
		"states": {"idle": 40, "idle2": 40, "idle3": 64, "attack": 48},
	},
]

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：PVZ2 五株 PAM 动画（模组 pam + pvz2）==========")

	var animators: Array = []
	for plant: Dictionary in PLANTS:
		var name: String = plant["name"]
		var script = plant["script"]
		var bin_path := "res://mods_builtin/pvz2/%s/%s.pam.bin" % [name, name]

		a.log("----- %s -----" % name)
		_check(a, "%s：bin 存在" % name, FileAccess.file_exists(bin_path), bin_path)
		if not FileAccess.file_exists(bin_path):
			continue

		var anim = AnimatorScript.new()
		anim.name = name + "_probe"
		anim.set("binary_path", bin_path)
		anim.set("hidden_parts", script.HIDDEN_PARTS)
		anim.set("oneshot_states", script.ONESHOT_STATES)
		anim.set("pivot_offset", script.ANIM_PIVOT)
		anim.scale = Vector2(script.ANIM_SCALE, script.ANIM_SCALE)
		a.add_child(anim)
		animators.append(anim)
		await a.frames(2)

		_check(a, "%s：加载成功" % name, anim.is_loaded())
		if not anim.is_loaded():
			continue

		var data = anim.get("_data")
		var unbound := 0
		for idef in data.images:
			if idef.texture == null:
				unbound += 1
		_check(a, "%s：%d 张部件全部绑上贴图" % [name, data.images.size()], unbound == 0,
			"没绑上的 %d 张" % unbound)

		var wrong: Array[String] = []
		for state_name: String in plant["states"]:
			if not anim.set_state(state_name):
				wrong.append("%s(缺失)" % state_name)
				continue
			var count: int = anim.get_current_state_frame_count()
			var expect: int = plant["states"][state_name]
			if count != expect:
				wrong.append("%s(%d≠%d)" % [state_name, count, expect])
		_check(a, "%s：脚本用到的状态与帧数都对得上" % name, wrong.is_empty(), ", ".join(wrong))

		anim.set_state("idle")
		await a.frames(6)
		var before: int = anim.get_state_frame_index()
		await a.frames(8)
		_check(a, "%s：idle 会推进帧" % name, anim.get_state_frame_index() != before,
			"%d → %d" % [before, anim.get_state_frame_index()])

		var rect: Rect2 = anim.get_render_rect()
		a.log("   [INFO] %s idle 包围盒（节点坐标，scale=%.2f）= %s  → 宽 %.0f 高 %.0f" % [
			name, script.ANIM_SCALE, str(rect), rect.size.x, rect.size.y])
		_check(a, "%s：待机包围盒不是空的" % name, rect.size.x > 1.0 and rect.size.y > 1.0)

	# 单次状态只发一次 finished（拿潜伏芹菜验收：它同时用循环段与单次段）
	a.log("----- 单次状态只报一次 -----")
	var celery = animators[1]
	var finished := [0]
	celery.animation_finished.connect(func(_s: String) -> void: finished[0] += 1)
	celery.set_state("attack")
	await a.frames(40)
	_check(a, "attack 播完只发一次 animation_finished", finished[0] == 1, "发了 %d 次" % finished[0])

	for anim in animators:
		anim.queue_free()
	await a.frames(2)
	## 退出前清缓存：不清的话静态字典会把数据 / 贴图留到进程结束，引擎会打两条泄漏告警
	AnimatorScript.clear_cache()

	_finish(a)


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[PVZ2-PAM] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
