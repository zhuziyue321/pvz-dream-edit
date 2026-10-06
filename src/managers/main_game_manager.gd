extends Node2D
class_name MainGameManager

#region 游戏测试
@export_group("测试相关")
## 游戏时测试方便修改阳光数
@export var test_change_sun_value := 9999:
	set(value):
		test_change_sun_value = value
		EventBus.push_event("test_change_sun_value", [value])

## 所有僵尸死亡
@export var test_death_all_zombie:=false:
	set(value):
		Log.debug("设置值")
		EventBus.push_event("test_death_all_zombie")

## 游戏速度
## INFO: 游戏速度超过8会代码执行顺序会有问题，可能会导致一些莫名其妙的bug
@export var test_time_scale:=1:
	set(value):
		test_time_scale = value
		Engine.time_scale = test_time_scale

#endregion
#region 游戏管理器
@onready var manager: Node = %Manager
@onready var card_manager: CardManager = %CardManager
@onready var hand_manager: HandManager = %HandManager
@onready var zombie_manager: ZombieManager = %ZombieManager
@onready var game_item_manager: GameItemManager = %GameItemManager
@onready var plant_cell_manager: PlantCellManager = %PlantCellManager
@onready var background_manager: BackgroundManager = %BackgroundManager
@onready var day_suns_manager: DaySunsManagner = %DaySunsManager
@onready var drop_item_manager: DropItemManager = %DropItemManager

## 通关结算子管理器（奖杯 / 通关奖励掉落 / 通关结算 / 跳商店，见 mgm_reward_manager.gd）
var reward_manager: MgmRewardManager
## 存档与全局关卡数据子管理器（存档 / 读档 / 解锁进度，见 mgm_save_manager.gd）
var save_manager: MgmSaveManager
## 僵尸进家的失败流程子管理器（见 mgm_lose_manager.gd）
var lose_manager: MgmLoseManager
## **关卡脚本自己注册的初始化回调**（通用口子，本体不认识任何具体玩法名）
## 注册时机：`LevelScriptBase.init_level_items()`（由 GIM_Other 调用，见 gim_other.gd：
##   格子已建好、玩家还动手不了）—— 一关专属玩法要接进主游戏就在这里注册一条
## 执行时机：`init_manager()` 末尾，排在 zombie_manager 等所有子管理器 init_manager() 之后
##   （要读格子 / 要改波次进度条的玩法都等得起）
## 有了这个口子，一关专属玩法不必在本体里留字段或 `if is_xxx` 分支（硬约束 §1-8）
var level_init_callbacks: Array[Callable] = []

## 关卡脚本注册一条初始化回调（时机见 level_init_callbacks 的注释）
func register_level_init_callback(callback: Callable) -> void:
	if callback.is_null() or not callback.is_valid():
		return
	level_init_callbacks.append(callback)

## 创建主游戏自己的子管理器
## 与 DaveSellManager 同一套路：运行时 new() 出来挂到 Manager 节点下
## （这些在场景里没有对应节点，见 MainGameSubManager._get_main_game 的 Global.main_game 兜底）
## 必须在任何存档逻辑之前建好：不支持续玩的多轮关卡一进关就要 re_main_game()
func init_main_game_sub_managers() -> void:
	reward_manager = MgmRewardManager.new()
	reward_manager.name = "RewardManager"
	manager.add_child(reward_manager)
	save_manager = MgmSaveManager.new()
	save_manager.name = "SaveManager"
	manager.add_child(save_manager)
	lose_manager = MgmLoseManager.new()
	lose_manager.name = "LoseManager"
	manager.add_child(lose_manager)

#endregion

#region 关卡进度判定
## 本关是否已有通关记录（「只给第一次进本关的玩家看」的东西都查它，见 LevelScriptBase.is_curr_level_success）
func is_curr_level_success() -> bool:
	return Global.global_game_state.is_level_success(game_para.save_game_name)


## 当前玩家是否可以操作草坪与主界面手持物（卡片 / 铲子 / 手套）
##
## **只看主游戏阶段**：教学演出也是关卡流程的一部分，
## 要让玩家先动手就用「允许操作」事件把阶段推到 MAIN_GAME（见 LevelTimelineEventAllowOperation），
## 本体不认识「教程」这种东西（硬约束 §1-8）。
func is_lawn_playable() -> bool:
	return main_game_progress == E_MainGameProgress.MAIN_GAME


## 关卡开场戴夫对话是否跳过（时间轴的 DaveDialog 事件也走这里）
## 本轮根本没有对话时事件自己就先返回了（见 LevelTimelineEventDaveDialog.run），这里只管「有对话要不该播」
##
## **教学演出里的戴夫对话不归这里管**：那是关卡流程自己写的（`await dave_dialog(对话)`），
## 「只播一次」由关卡脚本自己判（`if not is_curr_level_success()`），见 adventure_01_05。
func is_skip_level_dave_dialog() -> bool:
	## 关卡资源显式声明「只播一次」时，本关已经有通关记录就不再播
	## （原版：进入夜晚场景 2-1 的这段开场白只在第一次进夜晚时说）
	if game_para.dave_dialog_only_first_playthrough and is_curr_level_success():
		Log.debug("本关已通关，跳过开场戴夫对话")
		return true
	return false

## 选卡流程结束信号：时间轴的「选卡」事件等它（见 LevelTimelineManager._run_choose_card）
signal signal_choose_card_finished

## 时间轴的「选卡」事件是否正在等玩家点「开始游戏」
## 为 true 时选卡结束只收面板，开战交给时间轴的「开战」事件，避免开战走两遍
var is_timeline_waiting_choose_card := false

## 主游戏是否已经开打：开战流程只跑第一次（时间轴 / 调试入口都可能触发）
var is_main_game_started := false

## 玩家是否已经被允许在草坪上操作（见 allow_lawn_operation）
## 教程关把它提前到「开战」之前：允许操作阶段不能出怪、不能天降阳光，只是放手让玩家动
var is_lawn_operation_allowed := false

## 戴夫推销管理器：商店解锁前戴夫在冒险模式 2-2 开场卖卡槽扩充（原版流程，见 DaveSellManager）
var dave_sell_manager: DaveSellManager

## 创建夜晚戴夫推销管理器（在 init_manager() 之后：推销成功要立刻给本关出战卡槽补一格）
func init_dave_sell_manager() -> void:
	dave_sell_manager = DaveSellManager.new()
	dave_sell_manager.name = "DaveSellManager"
	manager.add_child(dave_sell_manager)


## 播一次戴夫对话并等他离场：关卡开场对话（run_flow() 里传给 dave_dialog 的那段，
## 或老关卡的 ResourceLevelData.crazy_dave_dialog）与教学中途对话（关卡流程自己写的那段）都走这里
## 戴夫挂在界面层，对话期间游戏照常运行
func play_crazy_dave_dialog(dialog_resource: CrazyDaveDialogResource) -> void:
	if dialog_resource == null:
		return
	var crazy_dave: CrazyDave = SceneRegistry.CRAZY_DAVE.instantiate()
	crazy_dave.init_dave(dialog_resource)
	canvas_layer_ui.add_child(crazy_dave)
	await crazy_dave.signal_dave_leave_end
	crazy_dave.queue_free()
#endregion

#region 关卡时间轴
## 关卡时间轴管理器：关卡流程按时间轴走，一个事件结束才开下一个（见 LevelTimelineManager）
var level_timeline_manager: LevelTimelineManager

## 创建时间轴管理器（在 init_manager() 之后：关卡流程要用它初始化的那些子管理器）
func init_level_timeline_manager() -> void:
	level_timeline_manager = LevelTimelineManager.new()
	level_timeline_manager.name = "LevelTimelineManager"
	manager.add_child(level_timeline_manager)
#endregion

#region 第一次掉落钱的提示
## 第一次掉落钱的提示文本（原版 ADVICE_CLICKED_ON_COIN，见 data/strings/lawn_strings.txt）
const ADVICE_FIRST_COIN := "存钱来买更酷的道具吧！"
## 提示停留时长（秒）
const ADVICE_FIRST_COIN_SHOW_TIME := 5.0


## 第一次掉落钱：弹一次提示，箭头指向掉出来的那枚金币
## 全局只弹一次：弹完立刻落存档（GlobalGameState.is_first_coin_advice_shown），
## 事件由 DIM_Coin 在生成金币后推送（金钱在冒险模式 2-1 才解锁，见 ConstUnlockLevel）
func _on_first_coin_drop(coin: Coin) -> void:
	var game_state: GlobalGameState = Global.global_game_state
	if game_state == null or game_state.is_first_coin_advice_shown:
		return
	game_state.is_first_coin_advice_shown = true
	Global.save_service.save_now()
	Log.debug("第一次掉落钱，弹出金钱提示")
	var advice_ui: TutorialAdviceUI = SceneRegistry.TUTORIAL_ADVICE.instantiate()
	canvas_layer_ui.add_child(advice_ui)
	advice_ui.show_advice_once(ADVICE_FIRST_COIN, coin, ADVICE_FIRST_COIN_SHOW_TIME)
#endregion

#region UI元素、相机
@onready var camera_2d: MainGameCamera = %Camera2D
@onready var ui_remind_word: UIRemindWord = %UIRemindWord
@onready var level_info: LevelInfo = $CanvasLayerUI/LevelInfo
## 关卡进度条控制器：进关时给它装一个数据源（默认战斗进度，僵王关是僵王血量），
## 之后进度条由它自己每帧驱动，出怪侧与关卡都不再直接碰进度条节点
@onready var level_progress_controller: LevelProgressBarController = %LevelProgressBarController
## 关卡道具容器：僵王的冰火球、地面轨迹等一次性道具挂在这里，不跟随僵王自身变换
@onready var items: Node2D = %Items

#endregion

#region 游戏主元素
@onready var canvas_layer_temp: CanvasLayer = %CanvasLayerTemp
@onready var canvas_layer_ui: CanvasLayer = %CanvasLayerUI

## 阳光收集位置,出战卡槽时更新
var marker_2d_sun_target: Marker2D
@onready var marker_2d_sun_target_default: Marker2D = %Marker2DSunTargetDefault

## 将子弹\爆炸\阳光
@onready var bullets: Node2D = %Bullets
@onready var bombs: Node2D = %Bombs
@onready var suns: Node2D = %Suns

@onready var coin_bank_label: CoinBankLabel = %CoinBankLabel
## 卡槽
@onready var card_slot_root: CardSlotRoot = %CardSlotRoot
## 全局检测组件,用于检测敌人
##TODO:可能会用于检测敌人离开场景后删除
@onready var detect_component_global: DetectComponent = %DetectComponentGlobal

## 指定行的基准 y（角色脚下的地面 y）
## 植物行与僵尸行共用同一套行数据（下标一致），所以"僵尸行的出生位置 y"就是这一行的地面 y，
## 子弹（抛物线影子、保龄球换行）取行高统一走这里，不要直接摸 zombie_manager.all_zombie_rows
func get_row_base_global_y(row:int) -> float:
	return zombie_manager.all_zombie_rows[row].zombie_create_position.global_position.y

#endregion

#region 自定义光标（用自己的道具代替系统鼠标的光标）
## 是否处于自定义光标模式：某些关卡把自己一个道具挂在鼠标上当光标（追着鼠标走），
## 系统鼠标就得藏起来；藏起来之后碰上能点的 UI（卡牌、金币、菜单…）又得露出来，否则玩家点不动。
## 这套开关由关卡侧的玩法规则打开（见 LevelRuleHammerZombie.install / set_custom_cursor_mode），
## **本体不认识任何具体道具**，只管系统鼠标什么时候该露出来
var is_custom_cursor_mode := false
## 系统光标保持可见：打开了菜单 / 重开面板期间置 true，鼠标离开 UI 也不再藏回去
## （由 EventBus "set_keep_system_cursor_visible" 推送，见 canvas_layer_control / main_game_menu_option_dialog）
var is_keep_system_cursor_visible := false
## 鼠标进这些节点时要露出系统光标（自定义光标模式下不露出来玩家没法点按钮）
@onready var node_custom_cursor_hover_ui: Array[Control] = [
	## 卡槽
	%CardSlotRoot,
	## 菜单
	%MainGameMenuButton, %MainGameMenuOptionDialog, %Dialog
]

#endregion

#region bgm
@export_group("bgm")
## 选卡bgm
var bgm_choose_card: AudioStream = preload("res://assets/audio/BGM/choose_your_seeds.mp3")
## 主游戏bgm
var bgm_main_game: AudioStream
#endregion


#region 主游戏运行阶段
enum E_MainGameProgress{
	NONE,			## 无
	CHOOSE_CARD,	## 选卡界面
	PREPARE,		## 准备阶段(红字)
	MAIN_GAME,		## 游戏阶段
	GAME_OVER,		## 游戏结束阶段
	RE_CHOOSE_CARD,	## 多轮游戏重新选卡阶段
}

## 重新选卡是否暂停
var is_pause_on_re_choose_card:=false
var main_game_progress := E_MainGameProgress.NONE:
	set(value):
		main_game_progress = value
		EventBus.push_event("main_game_progress_update", [value])
		_apply_custom_cursor_mode(value)

#endregion

#region 游戏数据
@export_group("地图特殊地形")
## 斜面(屋顶)
@export var main_game_slope:MainGameSlope
## 雪人僵尸逃跑概率(默认不使用该概率,赌狗小游戏使用)
var p_yeti_run :float= -1
#endregion

#region 游戏参数
@export_group("本局游戏参数")
## 正常进入游戏会自动更新对应关卡数据,直接进入该场景会使用该关卡数据,并设置is_test=true
@export var game_para : ResourceLevelData
## 僵王博士是正式角色：出场与登记全在 ZombieManager（见 zombie_manager.gd 的僵王区），
## 本管理器不认识任何僵王关的玩法分支，关卡只通过 LevelData 的 boss_* 字段声明
## 若为true,选卡无冷却
var is_test := false
## 当前轮次
var curr_game_round = 1:
	set(value):
		curr_game_round = value
		level_info.set_round(curr_game_round)

## 初始化时是否存档
var is_save_game_data_on_init:=false

#endregion

func _enter_tree() -> void:
	set_game_para()

## 进入树时更新游戏参数，子管理器赋值对应的游戏参数
func set_game_para() -> void:
	Global.main_game = self
	## 先获取当前关卡参数
	if Global.game_para != null:
		game_para = Global.game_para
	else:
		is_test = true
	if game_para == null:
		Log.error(
			"主游戏缺少关卡数据 ResourceLevelData：请从选关流程进入，或在编辑器中为该主游戏场景根节点指定「本局游戏参数 / game_para」。"
		)
		queue_free()
		return
	## 地图数据要在子管理器 _ready（生成格子/僵尸行）之前就绪
	game_para.resolve_map_data()

func _exit_tree() -> void:
	## 避免切场景后主游戏节点已释放，Global 仍持有野指针
	if Global.main_game == self:
		Global.main_game = null

func _ready() -> void:
	## set_game_para() 里已 queue_free() 时会话缺失关卡数据，queue_free 是延迟释放，
	## _ready 仍会执行，这里必须提前返回，否则 game_para 空引用崩溃
	if game_para == null:
		return
	game_para.init_para()
	## 结算 / 存档 / 失败流程三个子管理器要在 re_main_game() 之前建好
	init_main_game_sub_managers()
	## 不支持续玩的多轮关卡（砸罐子：罐子不进存档）：清掉历史存档文件和
	## 选关界面上的「第 N 轮」标记，保证每次进关都从第 1 轮开始
	if game_para.game_round != 1 and not game_para.is_save_multi_round_data:
		save_manager.re_main_game()
	## 多轮游戏并且有存档
	is_save_game_data_on_init = game_para.game_round != 1 and game_para.save_game_data_main_game != null

	## 订阅总线事件
	event_bus_subscribe()
	## 默认禁用全局敌人检测组件(追踪子弹调用, 放置追踪植物时启用,追踪植物死亡时,检测是否关闭)
	detect_component_global.disable_component(ComponentNormBase.E_IsEnableFactor.Global)
	## 主游戏进程
	main_game_progress = E_MainGameProgress.CHOOSE_CARD
	## 播放选卡bgm
	SoundManager.play_bgm(bgm_choose_card)
	## 连接子节点信号
	signal_connect()
	## 初始化子管理器
	init_manager()
	## 时间轴管理器在子管理器之后：关卡流程要用卡槽 / 植物格子 / 僵尸管理器
	init_level_timeline_manager()
	coin_bank_label.visible = false
	## 初始化游戏背景音乐
	_init_game_BGM()

	## 若有存档
	if is_save_game_data_on_init:
		save_manager.load_game_main_game()
		## 存档存的是「第 N 轮已经打完」，正常从这里接着打第 N+1 轮；
		## 存档已经到最后一轮时没有下一轮了，直接按当前轮次开局（见 start_curr_round_game）
		## （不支持续玩的多轮关卡不会走到这里：进关前已经把存档删了）
		if curr_game_round < game_para.game_round:
			await start_next_round_game()
		else:
			await start_curr_round_game()
	else:
		## 关卡流程交给时间轴：戴夫推销 -> 戴夫对话 -> 开场教程 -> 保龄球红线
		## -> 展示僵尸 -> 选卡 -> 开战 -> 波次，一个事件结束才开下一个
		## （见 LevelTimelineManager；没配 timeline 时跑的是关卡开关生成的等价默认时间轴）
		await level_timeline_manager.run_timeline()

## 主游戏管理器事件总线订阅
func event_bus_subscribe():
	## 自定义光标模式下，打开 / 关闭面板时是否保持系统鼠标可见
	EventBus.subscribe("set_keep_system_cursor_visible", set_keep_system_cursor_visible)
	## 僵尸进家 / 创建奖杯 / 游戏胜利：这三个事件由对应的子管理器自己订阅
	## （见 MgmLoseManager.init_manager 与 MgmRewardManager.init_manager）
	## 正常选卡结束后开始游戏
	EventBus.subscribe("card_slot_norm_start_game", _on_card_slot_norm_start_game)
	## 多轮游戏触发下一轮游戏
	EventBus.subscribe("start_next_round_game", start_next_round_game)
	## 更新阳光收集位置
	EventBus.subscribe("update_marker_2d_sun_target", update_marker_2d_sun_target)
	## 第一次掉落钱（提示由 MainGameManager 弹出，全局只弹一次）
	EventBus.subscribe("first_coin_drop", _on_first_coin_drop)


## 更新阳光收集位置
func update_marker_2d_sun_target(new_marker_2d_sun_target:Marker2D):
	marker_2d_sun_target = new_marker_2d_sun_target

#region 游戏关卡初始化
## 初始化管理器
func init_manager():
	## 背景管理器必须第一个初始化：泳池 / 屋顶斜面 / 僵尸进家位置都由它按地图数据装配，
	## 屋顶小推车 roof_cleaner._ready 里就要查 main_game_slope，晚于 game_item_manager 会漏掉斜面修正
	background_manager.init_manager()
	card_manager.init_manager()
	plant_cell_manager.init_manager()
	game_item_manager.init_manager()
	hand_manager.init_manager()
	zombie_manager.init_manager()
	## 进度条排在波次管理器之后：波数这时候才定下来，进度条上画几面旗要读它
	level_progress_controller.setup(self)
	drop_item_manager.init_manager()
	day_suns_manager.init_manager()
	## 主游戏自己的子管理器：在这里订阅事件总线（见各自的 init_manager）
	reward_manager.init_manager()
	save_manager.init_manager()
	lose_manager.init_manager()
	## 关卡脚本自己注册的初始化回调（一关专属玩法在这里接入，本体不认识任何玩法名）
	_run_level_init_callbacks()
	validate_map_consistency()
	Log.debug("info:管理器初始化完成")


## 跑一遍关卡脚本注册的初始化回调；跑完清空，避免重开一局时把同一条注册两遍
func _run_level_init_callbacks() -> void:
	var callbacks := level_init_callbacks
	level_init_callbacks = []
	for callback in callbacks:
		if callback.is_valid():
			callback.call()


## 地图生成结果自检（关卡初始化的一部分，见 docs/参考存档/地图实现.md）
## 格子/僵尸行是按 ResourceMapData 在运行时生成的，这里核对生成结果与数据是否一致：
## 行数列数、每行格子地形、每行僵尸行类型、以及每个格子的矩形。
## 不一致说明生成逻辑或数据有问题，直接报错。
func validate_map_consistency() -> void:
	var map_data: ResourceMapData = game_para.map_data
	if map_data == null or not map_data.is_valid():
		Log.error("关卡 %s 缺少可用的地图数据" % str(game_para.level_id))
		return

	var cell_rows: Array[Array] = plant_cell_manager.all_plant_cells
	var zombie_rows: Array[ZombieRow] = zombie_manager.all_zombie_rows
	if cell_rows.size() != map_data.get_row_num():
		Log.error(
			"地图行数不符：数据 %d 行，实际生成植物格子 %d 行"
			% [map_data.get_row_num(), cell_rows.size()]
		)
	if zombie_rows.size() != map_data.get_row_num():
		Log.error(
			"地图行数不符：数据 %d 行，实际生成僵尸行 %d 行"
			% [map_data.get_row_num(), zombie_rows.size()]
		)

	var check_num := mini(cell_rows.size(), map_data.get_row_num())
	for i in range(check_num):
		var row_data: ResourceMapRowData = map_data.rows[i]
		var cells: Array = cell_rows[i]
		if cells.size() != map_data.get_col_num():
			Log.error(
				"地图第 %d 行列数不符：数据 %d 列，实际生成 %d 列"
				% [i, map_data.get_col_num(), cells.size()]
			)
		for col_j in range(cells.size()):
			var plant_cell: PlantCell = cells[col_j]
			if plant_cell.plant_cell_type != row_data.plant_cell_type:
				Log.error(
					"地图第 %d 行第 %d 列地形不符：数据 %s，实际 %s"
					% [i, col_j, str(row_data.plant_cell_type), str(plant_cell.plant_cell_type)]
				)
			if col_j < map_data.get_col_num():
				var expect_rect: Rect2 = map_data.get_cell_rect(i, col_j)
				if not plant_cell.get_rect().is_equal_approx(expect_rect):
					Log.error(
						"地图第 %d 行第 %d 列矩形不符：数据 %s，实际 %s"
						% [i, col_j, str(expect_rect), str(plant_cell.get_rect())]
					)
		if i < zombie_rows.size() and zombie_rows[i].zombie_row_type != row_data.zombie_row_type:
			Log.error(
				"地图第 %d 行僵尸行类型不符：数据 %s，实际 %s"
				% [i, str(row_data.zombie_row_type), str(zombie_rows[i].zombie_row_type)]
			)


## 信号连接
func signal_connect():
	## 自定义光标模式下这些 UI 节点悬停时要露出系统鼠标
	## （不是自定义光标的关卡连上也没用，处理函数一进来就判断了）
	for ui_node: Control in node_custom_cursor_hover_ui:
		bind_custom_cursor_hover(ui_node)

## 初始化游戏bgm
func _init_game_BGM():
	#Log.debug(game_para.game_BGM)
	## 路径为空表示该关不放 BGM(如冒险 4-10),此时保持 bgm_main_game 为 null
	var path_bgm_game: String = ConstLevelData.GameBGMMap.get(game_para.game_BGM, "")
	if path_bgm_game.is_empty():
		bgm_main_game = null
		return
	bgm_main_game = load(path_bgm_game) as AudioStream


## 选卡阶段入口（时间轴的「选卡」事件走这里）
## 玩家没有选卡权时(见 level_data.is_no_choose_permission:卡槽被锁死 / 被系统预选卡填满),
## 选卡界面没有任何可操作空间,直接跳过选卡阶段
func enter_choose_card_progress() -> void:
	if game_para.is_no_choose_permission():
		Log.debug(str("种子包不足,跳过选卡阶段: 卡槽数") + str(game_para.get_max_choosed_card_num()) \
			+ str(", 拥有植物卡数") + str(Global.global_game_state.curr_plant.size()) \
			+ str(", 系统预选卡数") + str(game_para.get_valid_pre_choosed_card_num()))
		await skip_choose_card_start_game()
		return
	card_manager.card_slot_appear_choose()

## 跳过选卡阶段:等价于玩家直接点了「开始游戏」
func skip_choose_card_start_game() -> void:
	if card_manager.card_slot_norm != null:
		card_manager.card_slot_norm.save_choosed_cards()
	await _on_card_slot_norm_start_game()

## 玩家点了「开始游戏」/ 跳过选卡后的去向
## 时间轴接管关卡流程时只收面板（开战由时间轴的「开战」事件触发），
## 否则按旧流程一步到位直接开战（调试通道 / 自动测试的入口，见 docs/AI调试通道.md）
func _on_card_slot_norm_start_game() -> void:
	if is_timeline_waiting_choose_card:
		is_timeline_waiting_choose_card = false
		await choose_card_finish()
		return
	await choosed_card_start_game()
#endregion

#region 多轮游戏下一轮
func start_next_round_game():
	## 多轮游戏僵尸管理器计时器触发时，判断是否为最后一轮
	if curr_game_round == game_para.game_round:
		return
	Log.debug("-----------------开始下一轮游戏---------------")
	Log.debug(str("下一轮次：") + str(curr_game_round + 1))
	## 先存档（不支持续玩的多轮关卡不存：存了下次进关会直接跳到这一轮，见 is_save_multi_round_data）
	if game_para.is_save_multi_round_data:
		save_manager.save_game_main_game()
	## 等待3秒后进行下一轮
	await get_tree().create_timer(3).timeout
	## 播放选卡bgm
	if game_para.look_show_zombie:
		## 重新选卡阶段暂停游戏
		start_pause_on_re_choose_card_progress()
		Log.debug(str("----------------播放选卡bgm") + str(bgm_choose_card))
		SoundManager.play_bgm(bgm_choose_card)
	curr_game_round += 1
	await start_curr_round_game()


## 开始当前轮次的游戏（摆罐子 / 更新卡槽 / 正式开局）
## 多轮关卡切轮时由 start_next_round_game() 调用；
## 读档继续时也可能直接调用：存档已经到最后一轮时没有「下一轮」了（不支持续玩的多轮关卡不读档，不会走这里）；
## 不走这里的话砸罐子关读档进来场上不会摆罐子（罐子不进存档），玩家没得砸。
func start_curr_round_game():
	main_game_progress = E_MainGameProgress.RE_CHOOSE_CARD
	## 本轮重新开打，开战流程要能再跑一次
	is_main_game_started = false
	## 暂停天降阳光
	if game_para.is_day_sun:
		day_suns_manager.pause_day_sun()
	## 更新卡槽数据
	card_manager.start_next_game_card_manager_update()
	## 更新背景,浓雾回退
	background_manager.start_next_game_background_manager_update()
	coin_bank_label.visible = false
	## 更新僵尸管理器
	zombie_manager.start_next_game_zombie_mananger_update()
	## 整关只跑一遍的时间轴（ResourceLevelTimelineData.is_one_shot）：
	## 摆下一批（清场）和跑流程都写在时间轴上（ClearField 事件），而且轴现在还在跑，
	## 这里再摆一次场 / 再跑一次轴就重复了 —— 砸罐子关会多摆一批罐子
	if level_timeline_manager.is_one_shot_timeline():
		return
	## 更新植物格子数据，（创建罐子） 清除植物数据需要等待两帧
	await plant_cell_manager.start_next_game_plant_cell_manager_update()
	game_item_manager.start_next_game_game_item_manager_update()

	## 本轮的流程同样交给时间轴：本轮戴夫对话 -> 展示僵尸 -> 选卡 -> 准备安放植物 -> 开战
	## （首轮专属的事件用 is_first_round_only 标了，本轮会自动跳过）
	await level_timeline_manager.run_timeline()


## 下轮选卡时暂停游戏
func start_pause_on_re_choose_card_progress():
	is_pause_on_re_choose_card = true
	## 设置相机可以移动
	camera_2d.process_mode = Node.PROCESS_MODE_ALWAYS
	card_slot_root.process_mode = Node.PROCESS_MODE_ALWAYS
	TreePauseManager.start_tree_pause(TreePauseManager.E_PauseFactor.ReChooseCard)

## 下轮选卡结束时取消暂停游戏
func end_pause_on_re_choose_card_progress():
	is_pause_on_re_choose_card = false
	## 设置相机可以移动
	camera_2d.process_mode = Node.PROCESS_MODE_INHERIT
	card_slot_root.process_mode = Node.PROCESS_MODE_INHERIT
	TreePauseManager.end_tree_pause(TreePauseManager.E_PauseFactor.ReChooseCard)

#endregion

## 选卡结束：收起待选卡槽、相机归位，并通知时间轴的「选卡」事件
func choose_card_finish():
	Log.debug("选卡完成")
	## 主游戏进程阶段
	main_game_progress = E_MainGameProgress.PREPARE
	## 隐藏待选卡槽
	await card_manager.card_slot_disappear_choose()
	## 相机移动回游戏场景
	await camera_2d.move_back_ori()
	signal_choose_card_finished.emit()

## 选择卡片完成并直接开战
## 时间轴接管关卡流程时不要走这里：开战由时间轴的「开战」事件触发，否则会开两次
func choosed_card_start_game():
	await choose_card_finish()
	main_game_start()

## 播「准备…安放…植物」红字（时间轴的「准备安放植物」事件，见 LevelTimelineManager）
## 这段红字原本写在 main_game_start() 里，现已提成时间轴上的一个事件：
## 关卡可以自己决定红字在流程里的位置（默认排在「开战」之前，见 build_default_timeline）。
## 砸罐子关不播（is_show_ready_set_plant = false）：罐子摆好就能直接砸，见原版冒险 4-5
func ready_set_plant() -> void:
	main_game_progress = E_MainGameProgress.PREPARE
	## 等待1秒红字出现
	await get_tree().create_timer(1.0).timeout
	await ui_remind_word.ready_set_plant()


## 允许玩家在草坪上操作（拿起卡片 / 种植 / 收集阳光），但**不开战**
##
## 教程要在正式开战之前教玩家种植物（原版 1-1：捡种子包 → 种豌豆射手 → 收阳光），
## 而「能不能操作」的判据是 `main_game_progress == MAIN_GAME`
## （见 Card._on_button_pressed 与 HandManager._on_main_game_progress_update），
## 所以这一步就是把阶段推进到 MAIN_GAME，并把出战卡槽放出来。
## 出怪 / 天降阳光 / 生成墓碑仍由「开战」事件触发（见 main_game_start），两者要分开。
func allow_lawn_operation() -> void:
	if is_lawn_operation_allowed:
		return
	is_lawn_operation_allowed = true
	Log.debug("允许玩家操作草坪")
	## 主游戏进程阶段：这一步同时会刷一次铲子 / 手套的显隐（见 HandManager）
	main_game_progress = E_MainGameProgress.MAIN_GAME
	## 出战卡槽进场（原本在 main_game_start() 里，教程阶段就要能看到种子包）
	await card_manager.card_slot_update_main_game()
	## 预览僵尸只是给玩家看的，到了能操作的阶段就收回去
	if game_para.look_show_zombie:
		zombie_manager.delete_prepare_show_zombies()


## 选卡结束，开始游戏（时间轴的「开战」事件）
## 红字不在这里播：已提成时间轴的「准备安放植物」事件（见 ready_set_plant）
func main_game_start():
	if is_main_game_started:
		return
	is_main_game_started = true
	if is_pause_on_re_choose_card:
		end_pause_on_re_choose_card_progress()
	## 相机兜底归位：跳过选卡直接开战的入口（调试通道 / 自动测试 / 关卡脚本直接调 main_game_start）
	## 不走 choose_card_finish，相机还停在进关时的 CAM_POS_INIT（背景最左，只拍到房子）。
	## 正常流程走到这里时早已归位，snap_to 不动它，也不改变时序（用 await 会把开战推迟一轮位移）。
	camera_2d.snap_to(MainGameCamera.CAM_POS_ORI)
	Log.debug("主游戏开始")
	## 主游戏进程阶段
	main_game_progress = E_MainGameProgress.PREPARE
	## 背景表现（浓雾进场等）交给地图动画脚本
	background_manager.start_main_game_background_manager_update()

	## 删除展示僵尸
	if game_para.look_show_zombie:
		zombie_manager.delete_prepare_show_zombies()

	## 开始天降阳光
	if game_para.is_day_sun:
		day_suns_manager.start_day_sun()
	Log.debug(str("生成墓碑") + str(game_para.init_tombstone_num))
	## 生成墓碑
	if game_para.init_tombstone_num > 0:
		plant_cell_manager.create_tombstone(game_para.init_tombstone_num)

	## 主游戏进程阶段
	main_game_progress = E_MainGameProgress.MAIN_GAME
	await card_manager.card_slot_update_main_game()
	## 传送带随开战一起启动：1-5 这类关卡的教学排在开战之前，
	## 「允许操作」事件（见 allow_lawn_operation）不该顺手把传送带放出来
	await card_manager.start_conveyor_belt()

	## 开战一秒后切换主游戏bgm
	await get_tree().create_timer(1.0).timeout
	SoundManager.play_bgm(bgm_main_game)

	zombie_manager.start_game()


## 关卡流程改写出怪表：**预览僵尸 / 开战事件带了 zombie_refresh_types 时走这里**
## （见 LevelTimelineEventShowZombie / LevelTimelineEventStartBattle）
## 关卡流程跑在各子管理器 init_manager() 之后，所以这里改完关卡数据还要把已经读进
## 僵尸管理器的那一份一起改掉（随机池要按新表重建），否则本关还是按旧表出怪 / 预览
func apply_level_zombie_refresh_types(types: Array[CharacterRegistry.ZombieType]) -> void:
	if types.is_empty() or game_para == null:
		return
	## 与 init_para() 同一道过滤：表外的僵尸类型会被剔掉（白名单为空的本关不滤，免得滤成空表）
	var filtered := types
	if not game_para.whitelist_refresh_zombie_types.is_empty():
		filtered = game_para.filter_invalid_zombie_refresh_types(types, game_para.whitelist_refresh_zombie_types)
	game_para.zombie_refresh_types = filtered
	if is_instance_valid(zombie_manager):
		zombie_manager.apply_zombie_refresh_types(filtered)


## 僵尸进家的失败流程在 MgmLoseManager（订阅 EventBus "zombie_go_home"）





#region 快捷键
## 清场快捷键：Ctrl+K（输入映射 ShortcutKeys_KillAllZombie）→ shortcut_kill_all_zombie()
## 通关类快捷键（Ctrl+D 然后按 0 / 1）不在这里：它们要在选关界面 / 主菜单也能按，
## 所以挂在常驻 autoload Global 上（见 src/core/autoload/global.gd 的 #region 调试快捷键），
## 由它回调本管理器的 shortcut_win_main_game()（结算本关必须要有 MainGameManager 在场）。
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	if Input.is_action_just_pressed("ShortcutKeys_KillAllZombie"):
		shortcut_kill_all_zombie()


## 快捷键立刻通关本关（由 Global 的调试快捷键转发过来：Ctrl+D 然后按 0）
## 只在本局关卡进行中生效（选卡 / 准备 / 游戏中）；游戏已结束（奖杯已出）时不再重复结算，
## 否则会在 GAME_OVER 阶段再次写一次通关存档并重复切场景。
func shortcut_win_main_game() -> void:
	## 缺关卡数据时节点已被 queue_free，input 仍可能在当帧末回调进来
	if game_para == null:
		return
	if main_game_progress == E_MainGameProgress.NONE or main_game_progress == E_MainGameProgress.GAME_OVER:
		return
	Log.debug("快捷键 Ctrl+D + 0：直接通关本关")
	reward_manager.win_main_game()


## 快捷键杀死场上所有僵尸
## 复用 zombie_manager.death_all_zombie()（与 EventBus "test_death_all_zombie" 同一入口），
## 僵尸走的是正常死亡流程（血量归零 + 死亡信号），所以 curr_zombie_num 会正确递减，
## 最后一波清完同样会触发奖杯结算，不会出现「僵尸没了但关卡不结束」。
## 只在游戏进行阶段生效：其它阶段场上没有僵尸，按了也没有意义。
func shortcut_kill_all_zombie() -> void:
	## 缺关卡数据时节点已被 queue_free，input 仍可能在当帧末回调进来
	if game_para == null:
		return
	if main_game_progress != E_MainGameProgress.MAIN_GAME:
		return
	if not is_instance_valid(zombie_manager):
		return
	var num := zombie_manager.curr_zombie_num
	if num <= 0:
		return
	Log.debug("快捷键 Ctrl+K：杀死场上所有僵尸（%d 只）" % num)
	zombie_manager.death_all_zombie()
#endregion


#region 自定义光标（系统鼠标的显隐）
## 打开 / 关闭自定义光标模式：由关卡侧的玩法规则调用（见 LevelRuleHammerZombie.install）
## 打开之后系统鼠标的显隐按游戏阶段走：可操作草坪的阶段藏起来（道具自己跟着鼠标），
## 其余阶段（戴夫对话 / 选卡 / 结算 / 菜单）交还给玩家，见 _apply_custom_cursor_mode
func set_custom_cursor_mode(value: bool) -> void:
	is_custom_cursor_mode = value
	_apply_custom_cursor_mode(main_game_progress)


## 自定义光标模式下系统鼠标的显隐跟着游戏阶段走
## （原来靠道具自己 set_mouse_mode：道具改成手持物后不再碰鼠标，统一由本体按阶段管）
func _apply_custom_cursor_mode(progress: E_MainGameProgress) -> void:
	if not is_custom_cursor_mode:
		return
	if progress == E_MainGameProgress.MAIN_GAME:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


## 让鼠标进出该控件时自动切换系统鼠标：
## 场景里那几个固定的 UI 见 signal_connect()，运行期才建出来的（金币 / 奖杯这类）
## 在自己 _ready() 里调本函数一次即可
func bind_custom_cursor_hover(control: Control) -> void:
	if control == null:
		return
	control.mouse_entered.connect(on_cursor_ui_hover_enter)
	control.mouse_exited.connect(on_cursor_ui_hover_exit)


## 鼠标进入 UI：自定义光标模式下把系统鼠标露出来，玩家才点得动按钮
func on_cursor_ui_hover_enter() -> void:
	if not is_custom_cursor_mode:
		return
	if main_game_progress == E_MainGameProgress.MAIN_GAME:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


## 鼠标离开 UI：把系统鼠标藏回去（面板打开期间保持显示，见 is_keep_system_cursor_visible）
func on_cursor_ui_hover_exit() -> void:
	if not is_custom_cursor_mode:
		return
	if not is_keep_system_cursor_visible and main_game_progress == E_MainGameProgress.MAIN_GAME:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


## 打开 / 关闭菜单、点重新开始 / 返回主菜单时由 UI 推送
## （EventBus "set_keep_system_cursor_visible"）：面板期间一直用系统鼠标
func set_keep_system_cursor_visible(value: bool) -> void:
	if not is_custom_cursor_mode:
		return
	is_keep_system_cursor_visible = value

#endregion


## 通关结算（奖杯 / 通关奖励 / 跳商店）在 MgmRewardManager，存档与全局关卡数据在 MgmSaveManager
