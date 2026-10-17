extends RefCounted
## 探针：PVZ2 潜伏芹菜（Celery Stalker）动画 —— `.pam.bin` + PAMAnimator
##
## 无头可跑，不点鼠标、不开局。
##
## 校验：
##   1. 场景加载：`.pam.bin` 解析成功、94 张部件全部绑上图集贴图
##   2. 状态表：17 段，且 idle=50 帧 / attack=8 帧 / attack_loop=21 帧（与 PAM 的 label 段一致）
##   3. 装扮：`custom_*` 六个图层默认关着（PVZ2 把服饰和本体塞在同一条时间轴里）
##   4. 播放：循环状态会推进帧、不发 animation_finished；
##      单次状态（attack）**只发一次** animation_finished（曾经每帧连发，见 pam_animator.gd）
##   5. 缓存：第二个实例共用同一份解析结果（同一个 `.bin` 不重复读盘）
##
## 机器可读汇总：最后一行 `[PVZ2-CELERY] result=PASS|FAIL failed=<n>`

const ANIM_SCENE := preload("res://mods_builtin/pvz2/celerystalker/celerystalker_anim.tscn")
## 动画脚本本身（清缓存是静态方法，必须挂在脚本资源上调，不能挂在被释放的节点实例上）
const PAMAnimator := preload("res://mods_builtin/pvz2/pam/pam_animator.gd")

## 期望的状态与帧数（PAM 导出的 label 段，见 tools/bake_pam_bin.py 烘焙日志）
const EXPECTED_STATES := {
	"idle": 50, "idle2": 50, "idle3": 50, "idle4": 50,
	"down": 32, "idle_down": 50, "idle_down2": 50, "idle_down3": 50,
	"up": 32, "attack": 8, "attack_loop": 21, "attack_end": 18,
	"plantfood_on": 14, "plantfood": 7, "plantfood_off": 16,
	"water": 51, "attack_special": 24,
}
## 装扮图层（PVZ2 的海盗帽 + 蓝外套）
const COSTUME_PARTS: Array[String] = [
	"custom_02", "custom_01", "_custom_left",
	"custom_02_02", "custom_01_01", "_custom_right",
]

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== 探针：PVZ2 潜伏芹菜动画（pam.bin，模组 pvz2）==========")

	# ------------------------------------------------ STEP1 加载
	a.log("STEP1 场景加载 → 数据与贴图")
	var anim = ANIM_SCENE.instantiate()
	a.add_child(anim)
	await a.frames(2)

	_check(a, "动画场景加载成功", anim.is_loaded())
	if not anim.is_loaded():
		_finish(a)
		return

	var data = anim.get("_data")
	_check(a, "主时间轴 573 帧", data.frames.size() == 573, "实际 %d" % data.frames.size())
	_check(a, "图片定义 94 张", data.images.size() == 94, "实际 %d" % data.images.size())
	_check(a, "sprite 定义 52 个", data.sprite_names.size() == 52, "实际 %d" % data.sprite_names.size())
	var unbound := 0
	for idef in data.images:
		if idef.texture == null:
			unbound += 1
	_check(a, "94 张部件全部绑上图集贴图", unbound == 0, "没绑上的 %d 张" % unbound)
	_check(a, "图集尺寸 1024×1024",
		data.images.size() > 0 and data.images[0].texture != null
		and data.images[0].texture.get_width() == 1024,
		str(data.images[0].texture.get_size()) if data.images[0].texture != null else "无贴图")

	# ------------------------------------------------ STEP2 状态表
	a.log("STEP2 状态表")
	var names: PackedStringArray = anim.get_state_names()
	_check(a, "17 段状态", names.size() == EXPECTED_STATES.size(),
		"实际 %d：%s" % [names.size(), ", ".join(names)])
	var wrong: Array[String] = []
	for state_name in EXPECTED_STATES:
		if not anim.set_state(state_name):
			wrong.append("%s(缺失)" % state_name)
			continue
		var frames_count: int = anim.get_current_state_frame_count()
		if frames_count != EXPECTED_STATES[state_name]:
			wrong.append("%s(%d≠%d)" % [state_name, frames_count, EXPECTED_STATES[state_name]])
	_check(a, "每段帧数与 PAM 的 label 段一致", wrong.is_empty(), ", ".join(wrong))

	# ------------------------------------------------ STEP3 装扮
	a.log("STEP3 装扮默认关掉")
	var missing_costume: Array[String] = []
	for part_name in COSTUME_PARTS:
		if part_name not in anim.hidden_parts:
			missing_costume.append(part_name)
	_check(a, "6 个 custom_* 装扮都在 hidden_parts 里", missing_costume.is_empty(),
		", ".join(missing_costume))
	_check(a, "部件名去重后 19 个", anim.get_part_names().size() == 19,
		"实际 %d" % anim.get_part_names().size())

	# ------------------------------------------------ STEP4 播放推进
	a.log("STEP4 播放：循环推进 / 单次只报一次结束")
	anim.set_state("idle")
	var frame_before: int = anim.get_state_frame_index()
	await a.frames(8)
	_check(a, "idle 会推进帧", anim.get_state_frame_index() != frame_before,
		"%d → %d" % [frame_before, anim.get_state_frame_index()])

	var finished_count := [0]
	anim.animation_finished.connect(func(_state_name: String) -> void: finished_count[0] += 1)
	anim.set_state("idle")
	await a.frames(20)
	_check(a, "循环状态不发 animation_finished", finished_count[0] == 0,
		"发了 %d 次" % finished_count[0])

	finished_count[0] = 0
	anim.set_state("attack")
	## attack 8 帧 @30fps ≈ 0.27 秒；给足 40 个渲染帧，且末尾继续等，
	## 确认「播完停在最后一帧」时不再重复上报（这就是当年那个每帧连发的坑）
	await a.frames(40)
	_check(a, "单次状态播完发一次 animation_finished", finished_count[0] == 1,
		"发了 %d 次" % finished_count[0])
	_check(a, "停在最后一帧", anim.get_state_frame_index() == 7,
		"状态内帧号 %d" % anim.get_state_frame_index())

	# ------------------------------------------------ STEP5 缓存共享
	a.log("STEP5 同一个 .bin 只解析一次")
	var anim2 = ANIM_SCENE.instantiate()
	a.add_child(anim2)
	await a.frames(2)
	_check(a, "第二个实例共用同一份解析结果",
		anim2.is_loaded() and anim2.get("_data") == anim.get("_data"))

	anim2.queue_free()
	anim.queue_free()
	await a.frames(2)

	## 退出前清缓存：不清的话静态字典会把数据/贴图留到进程结束，
	## 引擎会打「ObjectDB instances leaked / resources still in use」两条告警
	PAMAnimator.clear_cache()

	_finish(a)


func _check(a, text: String, ok: bool, extra: String = "") -> void:
	if not ok:
		_failed += 1
	a.log("   [%s] %s%s" % ["OK" if ok else "FAIL", text, "" if extra == "" else "  ← " + extra])


func _finish(a) -> void:
	a.log("")
	a.log("[PVZ2-CELERY] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.finish(true)
