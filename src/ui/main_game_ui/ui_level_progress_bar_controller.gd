extends Node
class_name LevelProgressBarController
## 关卡进度条控制器 —— **进度条归它管，「进度条代表什么」归数据源管**
##
## 进关时装一个数据源（见 `_pick_provider`），之后每帧只做三件事：
## 问进度 → 写进度条 → 问旗帜。谁都不许绕过它直接碰 `FlagProgressBar`
## （原来波次管理器和出怪器各写各的，换个口径就要改出怪侧的代码）。
##
## 关卡脚本要换口径：覆写 `LevelScriptBase.create_progress_provider()`。
## 运行期也能换：`set_provider()`（关卡流程打到一半换口径用）。

## 被控的进度条：常驻在 LevelInfo 下（同场景唯一名）
@onready var progress_bar: FlagProgressBar = %FlagProgressBar

## 主游戏：由 `MainGameManager.init_manager()` 注入（进度条要跟着本局的波次 / 僵王走）
var main_game: MainGameManager
## 当前数据源
var provider: LevelProgressProvider

## 关卡整体开关：关掉后不管数据源说什么都不显示（原版僵尸迷阵没有旗帜进度条）
var _is_enabled := true
## 已经建好的旗帜数量（数据源报的数字变了才重建）
var _flag_num := -1


## 本关装一次数据源：由 `MainGameManager.init_manager()` 在波次管理器初始化之后调用
## （波数这时候才定下来，进度条上画几面旗要读它）
func setup(mg: MainGameManager) -> void:
	main_game = mg
	set_provider(_pick_provider())


## 换数据源（关卡流程中途换口径 / 关卡脚本自己接管）；传 null = 只收起进度条
func set_provider(new_provider: LevelProgressProvider) -> void:
	if provider != null:
		provider.on_unbind()
	provider = new_provider
	_flag_num = -1
	if provider == null:
		progress_bar.visible = false
		return
	provider.controller = self
	provider.on_bind()


## 关卡整体开关：整关都不显示进度条时关掉它（数据源之外再叠的一层总闸）
func set_enabled(is_enabled: bool) -> void:
	_is_enabled = is_enabled


## 本关该用哪个数据源：关卡脚本指定 > 僵王关 = 僵王血量 > 默认 = 战斗进度
func _pick_provider() -> LevelProgressProvider:
	if main_game == null or main_game.game_para == null:
		return LevelProgressBattleProvider.new()
	var para := main_game.game_para
	## 关卡脚本自己给：一关专属的进度口径留在关卡脚本里（硬约束 §1-8）
	if para is LevelScriptBase:
		var custom := (para as LevelScriptBase).create_progress_provider()
		if custom != null:
			return custom
	## 僵王关：这一条就是僵王的血量百分比（原版僵王战没有波次进度）
	if para.has_boss():
		return ZombossProgressProvider.new()
	return LevelProgressBattleProvider.new()


func _process(_delta: float) -> void:
	if provider == null or not is_instance_valid(main_game):
		return
	progress_bar.visible = _is_enabled and provider.is_bar_visible()
	if not progress_bar.visible:
		return
	_update_flags()
	progress_bar.set_progress(provider.get_progress(), provider.take_flag_raise_index())


## 旗帜：数据源报的数量变了才重建一次；「全部收起」是事件，取到就做一次
func _update_flags() -> void:
	var flag_num := provider.get_flag_num()
	if flag_num != _flag_num:
		_flag_num = flag_num
		## 传 0 = 清掉上一批旗帜（僵王战这类没有波次的玩法）
		progress_bar.create_flag(maxi(flag_num, 0))
	if provider.take_flag_reset():
		progress_bar.down_all_flags()
