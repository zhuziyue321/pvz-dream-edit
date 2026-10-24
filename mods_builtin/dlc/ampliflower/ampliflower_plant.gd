extends Plant000Base
## 增幅鹅河菊（DLC 的 Ampliflower，由模组「DLC植物」提供）
##
## ★ 玩法就一句话：**范围增益，不打僵尸** —— 以自身格子为中心的 3×3 范围内（含上下左右斜邻），
##   除自己外的每一株存活植物，攻击 / 产阳光节奏按 `boost_factor` 倍率提速；
##   植物进范围立即增幅、离开范围 / 本株死亡立即恢复。
##   （wiki：200 阳光 / 冷却 30 秒 / 生命 300 / 3×3 范围；未给倍率，`boost_factor` 由模组自选，可调）
##
## ★ 提速走本体现在就有的「速度倍率」通道，不新造轮子：
##   `Character000Base.update_speed_factor(倍率, 来源)` 会把该来源记进 `influence_speed_factors`，
##   再把**所有来源的乘积**经 `signal_update_speed` 下发给植物的攻击组件 / 产阳光组件
##   （它们各自 `wait_time = attack_cd / 倍率`）。本株专用的来源键是
##   `E_Influence_Speed_Factor.Ampliflower`（本体枚举末尾新增，关掉模组仅多一个没人用的值）。
##   撤销 = 把同一来源设回 1.0，其余来源（关卡全场加速 / 冰冻 / 黄油…）照旧相乘，互不干扰。
##
## ★ 为什么不用检测僵尸那套 `DetectComponent`：增幅鹅河菊要枚举的是**友方植物**，
##   而 `DetectComponent` 只索敌僵尸。枚举走 `PlantCellManager.get_plant_cell_surrounding()`
##   （本体注释原话：「留给模组的查询口，本体自己不用它」）—— 按格子坐标精确取周围一圈，
##   不依赖任何碰撞层，也就不会和僵尸索敌的碰撞体系打架。
##
## ★ 动画走 DLC 的 reanim → Godot 动画（`animation/character/plant/Ampliflower/Ampliflower.tscn`）：
##     · `Ampliflower_idle`（2.0 秒）：待机，靠 `animation_finished` 重播实现循环
##     · `Ampliflower_cheer`（4.33 秒）：增幅演出，播完回待机
##     · `Ampliflower_blink` / `_face`：本株不单独接（眨眼交给动画自己）
##
## ⚠️ 本文件可能跑在 `user://mods/dlc/` 下：`class_name` 不会注册成全局类，
##    所以这里不写 class_name，由同目录的 `plant_ampliflower.tscn` 按路径引用。

## 动画播放器：藏在 `Body` 下面（`Body` 是角色基类节点）
@onready var _anim_player: AnimationPlayer = $Body/AmpliflowerAnim/AnimLib
## 光环扫描计时器：周期性重算「周围 3×3 现在有哪几株植物」
@onready var _boost_scan_timer: Timer = $BoostScanTimer
## 增幅演出计时器：周期性播一次 `cheer`
@onready var _cheer_timer: Timer = $CheerTimer


#region 数值（倍率 wiki 未给，模组自选；都能在场景里调）
## 攻速 / 产阳光倍率：2.0 = 周围植物的攻击与产阳光节奏翻倍
@export var boost_factor := 2.0
## 光环扫描间隔（秒）：越小进出范围响应越快；0.1 足够且开销可忽略
@export var boost_scan_interval := 0.1
## 一次增幅**持续**多久（秒）：wiki 正文「speeds up all plants in a 3x3 radius around her
## **for 4.25 seconds at a time**」—— 是"每隔一阵触发一次、每次 4.25 秒"的**间歇**增益，
## 不是「站进范围就一直生效」的常驻光环（旧实现按常驻做的，这里按 wiki 改成间歇）
@export var boost_duration := 4.25
## 两次 cheer 之间的间隔（秒）：wiki 只给了持续时长、**没给触发间隔**，取模组自定 8 秒
## （= 4.25 秒增益 + 3.75 秒空档）。必须**长于** `Ampliflower_cheer`（4.33 秒），否则动画没播完就被打断
@export var cheer_interval := 8.0
#endregion


#region 动画常量
const STATE_IDLE := &"Ampliflower_idle"
const STATE_CHEER := &"Ampliflower_cheer"
#endregion


#region 增益标记（看得见的「被加强了」）
## 原来只有本株自己 cheer，被增幅的植物身上没有任何标记，玩家看不出谁被加了。
## 标记挂在**被增幅的植物**底下：进范围挂上、离开范围 / 本株死亡摘掉。
const FX_SCRIPT := preload("../dlc_sprite_fx.gd")
## `ampliflower_aura.png`：128×128 的环形放射光（中间镂空、边缘羽化）
const AURA_TEXTURE := preload("ampliflower_aura.png")
## `ampliflower_note.png`：横向 3 帧、单帧 32×32 的小音符，循环飘在光环上方
const NOTE_TEXTURE := preload("ampliflower_note.png")
const NOTE_FRAMES := 3
const NOTE_FPS := 6.0
## 光环落在被增幅植物身上的高度（植物本地坐标；与芦荟治疗光同一条「胸口」口径）
const AURA_POSITION := Vector2(0, -30)
## 音符飘在光环上方（同是植物本地坐标）
const NOTE_POSITION := Vector2(0, -58)
#endregion

## 当前正被本株增幅的植物（键 = 植物实例，值占位 true）：离开范围 / 死亡时据此精确撤销
var _boosted: Dictionary = {}
## 当前是否处在「增幅窗口」内（wiki：一次 cheer 只增益 4.25 秒，窗口外一律不生效）
var _boost_active := false
## 增益窗口的关闭计时器（脚本自建：场景里只有扫描与 cheer 两个 Timer）
var _boost_off_timer: Timer
## 本株挂出去的增益标记（键 = 被增幅的植物，值 = 标记节点）：
## 记在本株自己身上而不是目标的 meta 上 —— 两株鹅河菊叠加增幅同一株时各管各的标记，
## 先撤的那株不会把后一株的标记一起摘掉
var _marks: Dictionary = {}

## 一个格子里可能同时存在的几种「位置」：都要看，别漏了模仿者 / 花盆上的植物
const _ALL_PLACES: Array[CharacterRegistry.PlacePlantInCell] = [
	CharacterRegistry.PlacePlantInCell.Norm,
	CharacterRegistry.PlacePlantInCell.Shell,
	CharacterRegistry.PlacePlantInCell.Down,
	CharacterRegistry.PlacePlantInCell.Float,
	CharacterRegistry.PlacePlantInCell.Imitater,
]


#region 生命周期
## 初始化正常出战角色信号连接
func ready_norm_signal_connect() -> void:
	super()
	## 计时时长以导出值为准：改 `boost_scan_interval` / `cheer_interval` 时不必回头改两个 Timer
	_boost_scan_timer.wait_time = boost_scan_interval
	_cheer_timer.wait_time = cheer_interval
	_boost_scan_timer.timeout.connect(_on_boost_scan_timeout)
	_cheer_timer.timeout.connect(_on_cheer_timeout)
	## 增益窗口的关闭计时器：脚本自建（场景里只有扫描与 cheer 两个 Timer）
	_boost_off_timer = Timer.new()
	_boost_off_timer.one_shot = true
	_boost_off_timer.timeout.connect(_on_boost_off_timeout)
	add_child(_boost_off_timer)
	_anim_player.animation_finished.connect(_on_animation_finished)
	## 本株死亡时把周围植物的增幅全部撤掉（否则僵尸白捡一层永久加速）
	signal_character_death.connect(_on_self_death)


## 初始化正常出战角色
func ready_norm() -> void:
	super()
	_play_idle()
	## 只有出战状态才跑光环：图鉴 / 选卡 / 花园里的形象不增幅任何人
	_boost_scan_timer.start()
	_cheer_timer.start()


## 初始化展示角色（图鉴 / 选卡界面里的形象）
func ready_show() -> void:
	super()
	_play_idle()


## 初始化花园角色
func ready_garden() -> void:
	super()
	_play_idle()
#endregion


#region 光环
func _on_boost_scan_timeout() -> void:
	_update_boost()


## 重算一次光环：新进范围的施加增幅、离开范围的撤销增幅
func _update_boost() -> void:
	if is_death:
		return
	## 间歇增益（wiki：一次只有 4.25 秒）：不在窗口内就把上一轮撤干净，本轮不施加
	if not _boost_active:
		if not _boosted.is_empty():
			for p: Plant000Base in _boosted.keys():
				_apply_to(p, false)
			_boosted.clear()
		return
	var in_range: Dictionary = {}
	for p: Plant000Base in _surrounding_plants():
		in_range[p] = true
	## 新进入范围 → 施加增幅
	for p: Plant000Base in in_range:
		if not _boosted.has(p):
			_apply_to(p, true)
			_boosted[p] = true
	## 离开范围（被铲 / 被吃 / 搬走）→ 撤销；`keys()` 返回副本，遍历时 erase 安全
	for p: Plant000Base in _boosted.keys():
		if not in_range.has(p):
			_apply_to(p, false)
			_boosted.erase(p)


## 周围一圈（3×3，含自身格）所有**别的**存活植物
func _surrounding_plants() -> Array[Plant000Base]:
	var result: Array[Plant000Base] = []
	## 展示 / 花园状态没有格子；也没启动扫描计时器，正常走不到这儿
	if plant_cell == null:
		return result
	## 主场景访问走角色自己的口子（别在实体里直接摸 GameContext）；
	## 无主游戏上下文（探针 / 离场瞬间）时安全返回空，不崩
	var mg := get_main_game()
	if mg == null or mg.plant_cell_manager == null:
		return result
	for cell: PlantCell in plant_cell.get_plant_cell_surrounding():
		if cell == null:
			continue
		for place: CharacterRegistry.PlacePlantInCell in _ALL_PLACES:
			var p := cell.get_plant(place)
			if is_instance_valid(p) and p != self and not p.is_death:
				result.append(p)
	return result


## 给一株植物施加 / 撤销增幅（写进它的 `Ampliflower` 倍率来源），并同步增益标记
func _apply_to(p: Plant000Base, is_boost: bool) -> void:
	if not is_instance_valid(p):
		return
	p.update_speed_factor(boost_factor if is_boost else 1.0,
		Character000Base.E_Influence_Speed_Factor.Ampliflower)
	if is_boost:
		_attach_mark(p)
	else:
		_detach_mark(p)


## 挂上「被增幅了」的标记：一圈放射光 + 循环飘着的小音符
func _attach_mark(p: Plant000Base) -> void:
	if _marks.has(p) and is_instance_valid(_marks[p]):
		return
	var mark := Node2D.new()
	mark.name = &"DlcAmpliflowerMark"
	var aura := Sprite2D.new()
	aura.texture = AURA_TEXTURE
	aura.position = AURA_POSITION
	mark.add_child(aura)
	p.add_child(mark)
	_marks[p] = mark
	## 音符是循环序列帧：先入树再 setup（`play()` 离树跑不动，见 `dlc_sprite_fx.gd` 文件头）
	var note := FX_SCRIPT.new()
	note.position = NOTE_POSITION
	mark.add_child(note)
	note.setup(NOTE_TEXTURE, NOTE_FRAMES, NOTE_FPS, true)


## 摘掉标记（离开范围 / 本株死亡）
func _detach_mark(p: Plant000Base) -> void:
	var mark: Node2D = _marks.get(p)
	if is_instance_valid(mark):
		mark.queue_free()
	_marks.erase(p)


## 本株死亡：撤掉所有增幅、停表
func _on_self_death() -> void:
	_clear_all_boost()


## 撤掉所有增幅并停表（死亡 / 离场都走这里）
func _clear_all_boost() -> void:
	_boost_active = false
	for p: Plant000Base in _boosted.keys():
		_apply_to(p, false)
	_boosted.clear()
	## 目标已经先被移除时标记会跟着一起没，这里兜一次底（正常已在 `_apply_to` 里摘过）
	_marks.clear()
	_boost_scan_timer.stop()
	_cheer_timer.stop()
	if is_instance_valid(_boost_off_timer):
		_boost_off_timer.stop()


## 离场兜底：被直接 `queue_free()`（没走死亡信号）时也要把增幅撤干净
## 不调 super()：父类脚本链（Plant000Base → … → Node）没有脚本级 `_exit_tree()`，
## GDScript 对「父类脚本未定义的 virtual」调 super() 会直接报 parse error；Node 的离场通知仍照常派发到这里。
func _exit_tree() -> void:
	_clear_all_boost()
#endregion


#region 增幅演出
func _on_cheer_timeout() -> void:
	if is_death:
		return
	## 正在演就不重新起，避免打断 4.33 秒的动作
	if _anim_player.current_animation != STATE_CHEER or not _anim_player.is_playing():
		_anim_player.play(STATE_CHEER)
	## 间歇增益：cheer 一响就开窗口，窗口内 3×3 的植物才吃到 `boost_factor`
	_start_boost_window()


## 开一轮增益窗口：`boost_duration`（wiki 的 4.25 秒）之后关掉、把这一轮加的全撤了
func _start_boost_window() -> void:
	_boost_active = true
	_boost_off_timer.start(boost_duration)


## 增益窗口到点：撤掉这一轮施加的所有增幅，等下一次 cheer 再开
func _on_boost_off_timeout() -> void:
	_boost_active = false
	if is_death:
		return
	for p: Plant000Base in _boosted.keys():
		_apply_to(p, false)
	_boosted.clear()
#endregion


#region 动画回调
## 一段动画播完就回待机：cheer 演完、idle 2 秒到头，都靠这里续上（idle 由此实现循环）
func _on_animation_finished(_anim_name: StringName) -> void:
	if is_death:
		return
	_play_idle()


## 待机：已经在播就不打断（避免每帧重置动画）
func _play_idle() -> void:
	if _anim_player.current_animation == STATE_IDLE and _anim_player.is_playing():
		return
	_anim_player.play(STATE_IDLE)
#endregion
