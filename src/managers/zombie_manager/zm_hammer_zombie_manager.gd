extends ZombieWaveSourceBase
class_name HammerZombieManager

"""
参考：https://www.bilibili.com/video/BV12e4y1J7hH/
共计11大组僵尸、每大组结束后会停顿较长时间，并生成一次墓碑
每大组僵尸有11-15小组僵尸

修改为：每10波为1大波，每10小组为1波

游戏开始后，墓碑可能出现普通僵尸
第2次停顿后，2个墓碑可能同时召唤同一种僵尸
第4次停顿后，可能出现路障僵尸
第6次停顿后，可能出现铁桶僵尸
第8次停顿后，3个墓碑可能同时召唤同一种僵尸
最后1波时，所有墓碑同时召唤铁桶或路障，但是不超过20只


游戏开始时，长9个墓碑
每次长墓碑时，如果墓碑数量<5，则把墓碑数量长至5
每次长墓碑时，如果墓碑数量=>5，则长1个墓碑
墓碑只长第4列~第9列，如果都被占满则不长墓碑，只有停顿
"""
@onready var hammer_zombie_timer: Timer = $HammerZombieTimer

## 最多波数
@export var max_wave = 10
## 开第一波之前的入场延迟（秒）：本玩法固定 2 秒，不读关卡数据的 first_wave_delay
const FIRST_WAVE_DELAY := 2.0
## 最后一波（大波）的出怪上限，见头注「最后1波时，所有墓碑同时召唤铁桶或路障，但是不超过20只」
const BIG_WAVE_MAX_ZOMBIE := 20

## 当前小组数量总和
var curr_all_group_min_num_sum:=-1
var curr_wave := -1		#当前波
var curr_group_min := -1		#当前小组数

## 每一小组的进度条占比（%）
var progress_bar_segment_every_groud_min :float

#region 战斗进度（关卡进度条的数据源每帧读一次，本管理器不碰进度条节点）
## 当前战斗进度（0~100）：已出场的小组数 × 每小组占比
var battle_progress := 0.0
## 第一波是否已经开打（开打前进度条不显示）
var is_wave_started := false
## 本帧要升旗的旗帜下标（-1 = 不升），被读走后清掉
var _flag_to_raise := -1
## 本帧是否要把旗帜全部收起（多轮游戏切新一轮），被读走后清掉
var _is_flag_reset_pending := false
#endregion

## 当前可以生成的僵尸类型
var curr_zombie_type_candidate :Array[CharacterRegistry.ZombieType] = [CharacterRegistry.ZombieType.Z001Norm]
## 当前每小组可以生成的僵尸数量
var curr_num_new_zombie_every_group := 1
## 当前每小组间隔时间（从1s开始，每大组减速0.05秒，真正使用时增加0.1秒波动）最小为0.5
var interval_every_group := 1.0
## 是否围为大波（每10波一大波）
var big_wave := false

## 出怪倍率
var zombie_multy:= 1

## 初始化僵尸速度
var curr_speed_zombie := 1.0
## 每小组僵尸速度提升
var speed_zombie_add := 0.15
## 僵尸速度提升最大值
var speed_zombie_max := 2.0


## 波次刷新信号,给zombie_manager,删除魅惑僵尸，更新是否为最后一波（声明见 ZombieWaveSourceBase）

func _ready() -> void:
	hammer_zombie_timer.one_shot = true
	## 本出怪器是运行期 `instantiate()` 出来的，场景里只挂了 Timer 节点、**没有连 timeout 信号**
	## （见 zm_hammer_zombie_manager.tscn）。这一行不补上的话，只有 `start_first_wave()`
	## 手动跑的那一组僵尸会出场，之后 `hammer_zombie_timer.start()` 再也没人接 ——
	## 整局就此停摆（墓碑完好、一只也不再冒）
	if not hammer_zombie_timer.timeout.is_connected(_on_hammer_zombie_timer_timeout):
		hammer_zombie_timer.timeout.connect(_on_hammer_zombie_timer_timeout)

func init_source(game_para:ResourceLevelData) -> void:
	zombie_multy = game_para.zombie_multy_hammer
	max_wave = game_para.max_wave_hammer_zombie
	curr_speed_zombie = game_para.speed_zombie_init
	speed_zombie_add = game_para.speed_zombie_add
	speed_zombie_max = game_para.speed_zombie_max

	## 旗帜数量由进度条控制器按 get_flag_num() 自己建，本管理器只管算进度
	progress_bar_segment_every_groud_min = 100.0 / (max_wave*10)

## 开第一波：本玩法的入场延迟固定 2 秒（不读关卡数据的 first_wave_delay）；
## 原来这段等待写在 ZombieManager.start_game() 里，现在跟着出怪器走 ——
## 本玩法自己的节奏就改这里，不用动本体
func start_first_wave() -> void:
	await get_tree().create_timer(FIRST_WAVE_DELAY).timeout
	_on_hammer_zombie_timer_timeout()
	is_wave_started = true

## 生成一小组僵尸
func create_one_group_min_zombie():
	## 一块墓碑同时只能放一只僵尸，本组只从**空闲**的墓碑里挑：
	## 抽到正在冒头的墓碑会被静默跳过，本组实际出怪数会比配置少
	var idle_tombstones := _idle_tombstone_list()
	if idle_tombstones.is_empty():
		## 场上没有墓碑了（都被啃光）→ 先补一批
		if Global.main_game.plant_cell_manager.tombstone_list.is_empty():
			EventBus.push_event("create_tombstone", [randi()%3+1])
			await get_tree().create_timer(2).timeout
			idle_tombstones = _idle_tombstone_list()
		## 墓碑还在、只是都在冒头：本组跳过，等下一小组
		if idle_tombstones.is_empty():
			return

	idle_tombstones.shuffle()

	if big_wave:
		## 最后一波：所有墓碑同时召唤僵尸，每只单独挑类型（原版上限 20 只）
		for i in range(min(idle_tombstones.size(), BIG_WAVE_MAX_ZOMBIE)):
			idle_tombstones[i].create_new_zombie(curr_zombie_type_candidate.pick_random(), curr_speed_zombie)
		return

	## 同一小组出同一种僵尸
	var new_zombie_type = curr_zombie_type_candidate.pick_random()
	## 真正生成的僵尸数量
	var real_zombie_num = min(randi_range(1, curr_num_new_zombie_every_group) * zombie_multy, idle_tombstones.size())
	for i in range(real_zombie_num):
		idle_tombstones[i].create_new_zombie(new_zombie_type, curr_speed_zombie)

## 当前可以出怪的墓碑（排除正在冒头的、以及已被销毁但还没从列表里摘掉的）
func _idle_tombstone_list() -> Array[TombStone]:
	var idle_tombstones: Array[TombStone] = []
	for tombstone: TombStone in Global.main_game.plant_cell_manager.tombstone_list:
		if is_instance_valid(tombstone) and not tombstone.is_creating_zombie():
			idle_tombstones.append(tombstone)
	return idle_tombstones

## 计算当前进度（只算不写：进度条由控制器每帧来取，见 get_battle_progress）
func set_progress_bar(curr_flag: int = -1) -> void:
	battle_progress = curr_all_group_min_num_sum * progress_bar_segment_every_groud_min
	_flag_to_raise = curr_flag

func _on_hammer_zombie_timer_timeout() -> void:
	## 如果上一小组为最后一小组
	if curr_group_min == -1:
		curr_wave += 1
	curr_group_min += 1
	curr_all_group_min_num_sum += 1
	## 如果为第10波最后一小组
	if curr_wave % 10 == 9 and curr_group_min == 9:
		await get_tree().create_timer(3).timeout
		set_progress_bar(int(curr_wave/10.0))
		big_wave = true
	else:
		set_progress_bar()
		big_wave = false

	## 生成一小组僵尸
	## 必须 await：没有空闲墓碑时它会先补墓碑并等 2 秒，不等的话后面的
	## 「停顿 → 补墓碑 → 起下一组」会和这 2 秒并发，出怪节奏串在一起
	await create_one_group_min_zombie()
	#Log.debug(str("当前波：") + str(curr_wave))
	## 如果是大组的最后一小组（从0开始计数）
	if curr_group_min == 9:
		curr_group_min = -1
		## 如果是最后一大组
		if curr_wave == max_wave - 1:
			## 生成僵尸之后，更新zombie_manager的end_wave,使其管理最后一波僵尸死亡后奖杯
			signal_wave_refresh.emit(true)
			return
		else:
			signal_wave_refresh.emit(false)
			match curr_wave:
				2:
					curr_num_new_zombie_every_group = 2
				4:
					curr_zombie_type_candidate.append(CharacterRegistry.ZombieType.Z003Cone)
				6:
					curr_zombie_type_candidate.append(CharacterRegistry.ZombieType.Z005Bucket)
				8:
					curr_num_new_zombie_every_group = 3
			## 更新僵尸动画速度和小组间隔

			curr_speed_zombie = clampf(curr_speed_zombie+speed_zombie_add, curr_speed_zombie, speed_zombie_max)
			interval_every_group = clampf(interval_every_group-0.05, 0.5, 1.0)

			## 等待3秒创建墓碑后再等待两秒
			await get_tree().create_timer(3).timeout
			if Global.main_game.plant_cell_manager.tombstone_list.size() >= 5:
				EventBus.push_event("create_tombstone", [1])
			else:
				EventBus.push_event("create_tombstone", [5 - Global.main_game.plant_cell_manager.tombstone_list.size()])
			await get_tree().create_timer(2).timeout
			hammer_zombie_timer.wait_time = interval_every_group + randf_range(-0.1, 0.1)

	else:
		hammer_zombie_timer.wait_time = interval_every_group + randf_range(-0.1, 0.1)

	hammer_zombie_timer.start()


#region 战斗进度查询（关卡进度条的数据源从这里取，见 ZombieManager 的同名转发）
## 当前战斗进度百分比（0~100）
func get_battle_progress() -> float:
	return clampf(battle_progress, 0.0, 100.0)

## 本玩法的波次是否已经开打（开打前进度条不显示）
func is_battle_started() -> bool:
	return is_wave_started

## 进度条上要画几面旗帜（每 10 波一面）
func get_flag_num() -> int:
	return max_wave / 10

## 取走「本帧要升旗」的旗帜下标（-1 = 不升）
func take_flag_raise_index() -> int:
	var flag_i := _flag_to_raise
	_flag_to_raise = -1
	return flag_i

## 取走「本帧要收起所有旗帜」的请求（本玩法是单轮，恒为 false）
func take_flag_reset() -> bool:
	var is_reset := _is_flag_reset_pending
	_is_flag_reset_pending = false
	return is_reset
#endregion

