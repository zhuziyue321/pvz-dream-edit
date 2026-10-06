extends Control
class_name FlagProgressBar
## 使用真实进度值和追赶进度值，使进度条平滑移动
##
## **本节点只被 `LevelProgressBarController` 驱动**：进度代表什么由数据源
## （`LevelProgressProvider`）算，控制器每帧写进来；出怪侧（波次管理器 / 出怪器）
## 不再直接碰进度条，换口径不用改它们。

## 真实进度值 (0-100)
var real_value: float = 0.0
## 追赶进度值 (0-100)
var chase_value: float = 0.


## 进度条
@onready var texture_progress_bar: TextureProgressBar = $TextureProgressBar
## 小僵尸头表示进度条
@onready var mini_zombie: TextureRect = $MiniZombie
## 旗帜
@onready var flag: FlagProgressBarFlag = $Flag

## 小僵尸的起始位置
var start_minizombie :float = 142
## 小僵尸的结束位置
var end_minizombie :float = -4
## 小僵尸的当前位置
var curr_minizombie : float
## 进度条开始位置，用于生成旗帜
var start_flag = start_minizombie + 6
## 进度条结束位置，用于生成旗帜
var end_flag = end_minizombie + 6
## 存储生成的旗帜
var flag_arr : Array[FlagProgressBarFlag] = []
## 当前旗帜的索引
#@export var curr_flag_i : int = 0


func _ready() -> void:
	curr_minizombie = start_minizombie
	set_progress(0)
	texture_progress_bar.value = 0
	mini_zombie.position.x = start_minizombie


## 按旗帜数量生成旗帜，并删除原本的旗帜
## **可以重复调用**：旗帜数量变了（波数被改写、换成僵王血量这类没有波次的口径）就会再走一次，
## 所以模板旗帜 $Flag 不删（只隐藏），留给下一次复制用；上一批旗帜在这里先清干净。
## flag_num <= 0 = 本关不画旗帜，只把上一批清掉
func create_flag(flag_num:int):
	for old_flag: FlagProgressBarFlag in flag_arr:
		old_flag.queue_free()
	flag_arr.clear()
	## 模板旗帜只是样板，不画旗帜时也要藏起来（不删：下次还要再复制一份）
	flag.visible = false
	if flag_num <= 0:
		return
	# 计算总距离
	var total_distance = start_flag - end_flag

	# 计算每个分段的结束位置
	for i in range(1, flag_num+1):  # 1到10
		var end_pos = start_flag - total_distance * ((i*10.0-1)/(flag_num * 10.0-1))

		var flag_new : FlagProgressBarFlag = flag.duplicate()

		add_child(flag_new)
		move_child(flag_new, 1)
		flag_arr.append(flag_new)
		flag_new.position.x = end_pos
		## 模板旗帜第二次起是隐藏的，复制出来的这一批要显式显示（duplicate 会连 visible 一起复制）
		flag_new.visible = true


## 收起所有旗帜（多轮游戏切新一轮时由数据源发话）
func down_all_flags():
	for curr_flag:FlagProgressBarFlag in flag_arr:
		curr_flag.down_flag()


## 设置真实进度（由 LevelProgressBarController 每帧写入；flag_i >= 0 时顺手升起那一面旗）
func set_progress(value: float, flag_i:int = -1):
	real_value = clamp(value, 0.0, 100.0)

	## 加边界保护：关卡 max_wave 不是 10 的倍数时下标可能越界
	if flag_i >= 0 and flag_i < flag_arr.size():
		flag_arr[flag_i].up_flag()


# 动画追赶进度
func _process(delta: float) -> void:
	# 在1秒内追赶真实进度
	if abs(chase_value - real_value) > 0.1:
		# 计算追赶速度 (每秒10单位)
		var speed = 10.0 * delta

		if chase_value < real_value:
			chase_value = min(chase_value + speed, real_value)
		else:
			# 如果真实进度减小，追赶进度也会减小
			chase_value = max(chase_value - speed, real_value)

		# 更新UI
		texture_progress_bar.value = chase_value
		curr_minizombie = start_minizombie + chase_value * (end_minizombie - start_minizombie) * 0.01
		mini_zombie.position.x = curr_minizombie

	else:
		# 如果非常接近，直接设为相等
		if chase_value != real_value:
			chase_value = real_value

			texture_progress_bar.value = chase_value
			curr_minizombie = start_minizombie + chase_value * (end_minizombie - start_minizombie) * 0.01
			mini_zombie.position.x = curr_minizombie
