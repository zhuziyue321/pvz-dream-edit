extends "res://src/levels/core/level_script_base.gd"
## 玩家对战：白天 —— 卡槽 / 靶子僵尸 / 双方胜法都已就位（脑子收入还没做）
##
## 关卡 = 一个 .gd（属性 + 流程），见 LevelScriptBase。
## 这一关把双方的两条卡槽摆进主游戏：
##   - 左上：**植物卡槽**（本体那张，固定六格，选卡 / 种植那套全走本体流程）；
##   - 右上：**僵尸卡槽**（六格，反转 —— 脑子计数在右面）。
##     它由**僵尸卡模组**装（见 `mods_builtin/zombie_card/zombie_card_pvp_wiring.gd`，
##     本模组声明了对它的依赖）：本关的 `game_mode` 是 `ChooseLevelPlayerBattle`，
##     僵尸卡模组认这一条就在右上装槽，并在选卡阶段贴一条选僵尸卡面板
##     （植物待选区右面，一行五张）；**没有默认牌**：没点僵尸卡，僵尸块就是空的。
##   - 右下：**菜单按钮**（本体的 `%MainGameMenuButton`）。它默认贴右上角，而开打后
##     右上角是僵尸卡槽，所以**开打那一刻**（`run_flow` 里 `allow_operation()` 之后）
##     挪到屏幕右下角、并让开底部提示条，见 `_move_menu_button_to_bottom_right`。
##     选卡阶段不挪它：那时右上角本来空着，右下角反而是选僵尸卡的那条面板。
##
## **放置限制：保龄球红线**（`init_level_items` 里摆下去，见那段注释）——
## 红线贴在第 6 列右边缘：植物只能种左边（第 1~6 列），僵尸只能放右边（第 7~9 列）。
##
## **双方的胜法**（这一关只有这两条结束条件，见下面两个 region）：
##   - **植物方赢**：击破 `TARGET_ZOMBIE_DEFEAT_TO_WIN` 只**靶子僵尸**
##     （僵尸方的目标物，每行一只站在**第 10 列**——草坪外那一列，再往右
##     `TARGET_ZOMBIE_STAND_EXTRA_OFFSET_X` 像素，半截身体在屏幕外，见 `../targetzombie/`）；
##   - **僵尸方赢**：**任意一只僵尸走进房子** —— 走的是本体那套「僵尸进家」失败流程
##     （重开存档 + 暂停 + `losemusic` + 屏幕红字「僵尸吃掉了你的脑子」），
##     关卡这边只负责记账 / 掐断植物方的计数（见 `_on_zombie_go_home`）。
##     小推车照旧是植物方每行的最后一次免费拦截（进家之前先把车撞掉）。
##
## ⚠️ **胜利条件 = 关卡流程跑完**（见 LevelTimelineManager._run_level_script）：
## 流程一跑完就强制判胜弹奖杯。所以「击破 3 只靶子」这件事就是让流程跑完 ——
## `run_flow` 结尾停在 `wait_targets_defeated(3)` 上，数够了自然收尾判胜。
## ⚠️ 僵尸方赢的那条**也**会让 `wait_targets_defeated` 返回（流程跟着结束），
## 但那时主游戏已经是 `GAME_OVER`（本体失败流程设的），
## `MgmRewardManager.force_win_on_flow_finished()` 会跳过判胜 —— **不会**弹奖杯。

## 本模组的共享常量（靶子僵尸的 id / 行数 / 击破数 / 列号都在这）
const Settings := preload("../player_battle_settings.gd")


func _init() -> void:
	## 存档键：玩家对战（模式 106）+ 第 0 页 + 第 1 关 = "106_0_0001"
	save_key = "106_0_0001"
	## 白天的前院（默认值就是前院白天，这里写死是为了以后换地图好改）
	game_sences = MainSceneRegistry.MainScenes.MainGameFront
	game_BG = ConstLevelData.GameBg.FrontDay
	## 空关卡：不出怪、不预览僵尸（相机照样拉到预览位 —— 那里没有僵尸可看）
	monster_mode = ConstLevelData.E_MonsterMode.Null
	look_show_zombie = false
	## 出战卡槽：**一个 12 格的槽**（看似左右两条银行，存储是一份）——
	## 前 6 格植物卡（走正常选卡，花阳光）、后 6 格僵尸 / 僵王卡（僵尸卡模组装的
	## 选卡面板选进来，花脑子）；分块与分池的配置由僵尸卡模组的接线装
	## （见 zombie_card_pvp_wiring.gd）。不随存档卡槽数变。
	card_mode = ConstLevelData.E_CardMode.Norm
	can_choosed_card = true
	max_choosed_card_num = 12
	## 铲子先收掉：会顶进右边僵尸那半槽里（对战逻辑做完再定铲子归谁）
	is_shovel = false
	## 与正常关卡同一套开场红字
	is_show_ready_set_plant = true
	## **僵尸能进家** = 僵尸方的胜法（本体的「僵尸进家」失败流程就是它的收尾，见文件头）。
	## 默认值也是 true，这里写出来是因为它是**规则本身**：僵尸进家不判负的话，
	## 僵尸方就没有任何赢法（只靠植物方打靶子，变成单方面挨打）。
	## ⚠️ 千万别开 `is_zombie_mode`（我是僵尸）：那样 `_apply_zombie_mode_rules()` 会把
	##    `is_zombie_can_home` 强制关掉，房子直接不再是判定点。
	is_zombie_can_home = true
	## 相机初始位不配（留 NAN 默认）：进关停在背景最左侧（拍到房子），
	## 由 run_flow 里的 show_zombie() 拉到预览位再归位


#region 放置限制：保龄球红线
## 红线道具（本体保龄球关同款，`src/items/mini_game/wallnut_bowling_stripe.tscn`）
const BowlingStripeScene := preload("res://src/items/mini_game/wallnut_bowling_stripe.tscn")
## 红线贴在哪一列的**右边缘**（0 起算：5 = 第 6 列）
const BOWLING_STRIPE_COL := 5
## 红线两侧各能放什么 —— 这四个开关就是规则本身（键名见 `WallnutBowlingStripe.init_item`）
const BOWLING_STRIPE_CAN_USE := {
	"left_can_plant": true,    ## 左边（第 1~6 列）能种植物
	"right_can_plant": false,  ## 右边不能种植物
	"left_can_zombie": false,  ## 左边不能放僵尸
	"right_can_zombie": true,  ## 右边（第 7~9 列）能放僵尸
}

## 本关的红线节点（`init_level_items` 里建）
var _bowling_stripe: WallnutBowlingStripe = null


## 进关摆场地道具 + 给格子打分区标记 —— **格子已建好、玩家还动手不了**（见 `LevelScriptBase.init_level_items`）
##
## 红线道具在 `init_item()` 里按上面四个开关把**格子标记**打好，与本节点显隐无关：
##   · 植物侧 `can_common_plant`（`set_bowling_no_plant()`）—— 种植条件的第一道闸
##     （`ResourcePlantCondition.judge_is_can_plant`）；
##   · 僵尸侧 `can_common_zombie`（`set_bowling_no_zombie()`）—— 手持组件的放置判定
##     （`hand_component_character.gd` 的虚影 / 点击）。
##
## 两处口径写在这里免得后来者踩：
##   · **产脑光墓碑**（本模组的运行期僵尸 `zombie_card_vsgravestone`）是**僵尸单位**，
##     放置走僵尸链路（`hand_component_character.gd` 的僵尸分支，读 `can_common_zombie`）——
##     于是它自动落在红线**右边** ✓；放下时把所在格子标成 `IsOccupied`
##     （`vsgravestone/vsgravestone_zombie.gd`），同一格放不了第二块
##   · **蹦极僵尸**在原版口径里豁免 `can_common_zombie`（它要空投到植物身上），所以
##     两张边都放得下；要把它也锁在右边，得从对战卡池里去掉它
##     （`zombie_card_settings.gd` 的 `PLAYER_BATTLE_EXCLUDED_ZOMBIES`）
func init_level_items(_game_manager: MainGameManager, item_root: Node2D) -> void:
	_bowling_stripe = BowlingStripeScene.instantiate()
	item_root.add_child(_bowling_stripe)
	_bowling_stripe.init_item(BOWLING_STRIPE_COL, BOWLING_STRIPE_CAN_USE)
	## 对战没有戴夫那句「我们去玩保龄球！」（本体那条 `SHOW_STRIPE_EVENT` 是 1-5 的教程链），
	## 建好就直接画出来
	_bowling_stripe.show_stripe()
#endregion


#region 菜单按钮：开打后挪到屏幕右下角
## 菜单按钮离屏幕底边的距离（像素）：底部那条对局提示条（见 `run_flow` 里的 `hint()`）
##
## 提示条（TutorialAdviceUI）固定贴屏幕底部、按文本行数**往上长**（原版 HINT_LONG 同形：
## 通栏、离底 18、单行 55，见 `src/ui/tutorial_advice_ui.tscn`）：
## 本关这句是两行 ≈ 67 ⇒ 顶到 y≈515。菜单按钮原生 104×38，留 108 时按钮底边在 y=492，
## 正好落在提示条上方 23 像素。
## ⚠️ 改了 `run_flow` 里那句提示的字数（行数变了），这个数要跟着调 —— 提示条按底部往上长。
const MENU_BUTTON_BOTTOM_MARGIN := 108.0


## 把本体的「菜单」按钮从右上角挪到**屏幕右下角**（让开底部提示条）
##
## 为什么挪：开打后右上角是僵尸卡槽（六格反转、脑子计数在右，由僵尸卡模组装），
## 本体那颗菜单按钮默认贴右上角，正好压在卡槽上。
## 为什么在 `run_flow` 的 `allow_operation()` 之后才挪：选卡阶段右上角本来空着，
## 右下角反倒被「选僵尸卡」那条面板（`zombie_card` 模组，x 465 起、高 513）占着 ——
## 那时挪过去会盖住面板最下面那排卡；选卡收尾（`choose_card_finish`）面板滑走，
## 这会儿挪才两头都不挡。
## 为什么改锚点就够：主游戏场景一关一份新实例（`MainSceneRegistry` 各条 MainScenes
## 都指向 main_game_base.tscn），这里动的是本局这一份，别的关卡照旧右上角。
func _move_menu_button_to_bottom_right(mg: MainGameManager) -> void:
	var menu_button := mg.get_node_or_null("%MainGameMenuButton") as Control
	if menu_button == null:
		Log.warn("玩家对战：没找到菜单按钮（%MainGameMenuButton），跳过挪位")
		return
	## 先记下当前尺寸（场景里是 104×38），只换锚点、按原尺寸收偏移 —— 按钮大小不变。
	## 尺寸取**四个偏移之差**：这颗按钮没有容器父节点，矩形本来就是这组偏移定的
	var button_size := Vector2(
		menu_button.offset_right - menu_button.offset_left,
		menu_button.offset_bottom - menu_button.offset_top)
	## 四边锚点全贴父容器右下角；偏移是绝对值，四个都写死后矩形就钉在右下角
	menu_button.anchor_left = 1.0
	menu_button.anchor_top = 1.0
	menu_button.anchor_right = 1.0
	menu_button.anchor_bottom = 1.0
	menu_button.offset_left = -button_size.x
	menu_button.offset_top = -(button_size.y + MENU_BUTTON_BOTTOM_MARGIN)
	menu_button.offset_right = 0.0
	menu_button.offset_bottom = -MENU_BUTTON_BOTTOM_MARGIN


## 本关流程：与正常关卡同一套开场 → 放开玩家的手 → 提示一句 → 等任一方赢
##
## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## ⚠️ 中间**不调 start_battle()**：本关 monster_mode = Null、没有波次，
##    开战事件可能当场判「打完了」→ 流程跑完就强制判胜弹奖杯 —— 所以流程停在
##    `wait_targets_defeated` 上等任一方赢。
func run_flow(mg: MainGameManager) -> void:
	## 重开一局 / 多轮：上一局的计数与胜负都不带过来
	## （关卡脚本实例挂在选关按钮上，同一页里再进一次还是同一份）
	_targets_defeated = 0
	_targets.clear()
	_zombie_side_won = false
	## 展示（相机从最左拉到预览位）：本关没有出怪表，预览位只有相机平移、没有僵尸
	await show_zombie()
	## 选卡：等玩家点「开始战斗！」（相机归位在选卡收尾 choose_card_finish 里做）
	await choose_card()
	## 初始化小推车（正常关卡也是排在归位与红字之间）
	await init_lawn_mover()
	## 「准备…安放…植物」红字
	await ready_set_plant()
	## 放开玩家的手：推进到主游戏（卡槽挪进 HUD、能种植 / 放僵尸）——不开战、不出怪
	await allow_operation()
	## 选卡界面已经收走：把菜单按钮从右上角让到右下角（右上角归僵尸卡槽，见那个函数）
	_move_menu_button_to_bottom_right(mg)
	## 僵尸方胜法：盯住「僵尸进家」这条事件（**必须在摆靶子之前**接上，
	## 免得第一只僵尸跟摆靶子挤在同一帧时没人记账）
	_subscribe_zombie_go_home()
	## 摆靶子僵尸：每行一只（僵尸侧红线右边）
	await spawn_target_zombies(mg)
	## 屏幕下方提示一句：红线两边各放什么 + 双方怎么赢
	await hint("玩家对战：白天 —— 红线左边种植物、右边放僵尸；"
		+ "植物方击破 %d 只靶子僵尸即胜，僵尸方有一只走进房子即胜"
		% Settings.TARGET_ZOMBIE_DEFEAT_TO_WIN)
	## 等到任一方赢：植物方击破 3 只 → 流程跑完判胜；
	## 僵尸方进家 → 本体失败流程已经接管（`GAME_OVER`），这里只是收尾退出
	await wait_targets_defeated(Settings.TARGET_ZOMBIE_DEFEAT_TO_WIN, mg)
	_unsubscribe_zombie_go_home()
	if _zombie_side_won:
		Log.info("玩家对战：本局僵尸方获胜（植物方击破 %d / %d 只靶子）"
			% [_targets_defeated, _targets.size()])
	else:
		Log.info("玩家对战：本局植物方获胜（击破 %d 只靶子）" % _targets_defeated)


#region 靶子僵尸（僵尸方的目标物）
## 已击破的靶子数（植物赢的计数）
var _targets_defeated := 0
## 本关摆下的靶子（留着给探针 / 调试看，不参与判定）
var _targets: Array[Zombie000Base] = []


## 每行摆一只靶子僵尸，位置 = **第 10 列**（草坪 9 列之外那一列的正中，见 `_target_stand_x`）
## 再整体右移 `TARGET_ZOMBIE_STAND_EXTRA_OFFSET_X` 像素
##
## 与小推车同一个口径：小推车站在草坪外最左面（`GlobalXLawnMover = 20`，草坪左边缘之外），
## 靶子就站在草坪外最右面**那一列** —— 不占任何格子，也不跟僵尸进场线（出怪点 950）叠在一起，
## 半截身体露在屏幕外（玩家看得见它在，但不像站在草坪上）。
## ⚠️ y 必须用出怪点 `zombie_create_position` 的 y：行节点自身原点与地面差一截，
##   差这点像素植物的索敌带就够不着它。
## ⚠️ 靶子僵尸自己在脚本里把移动组件按住了（`target_zombie.gd` 的 `ready_norm()`）——
##   这里只管摆位，不干预它的移动。
func spawn_target_zombies(mg: MainGameManager) -> void:
	var zm := mg.zombie_manager
	var lanes := mini(Settings.TARGET_ZOMBIE_LANES, zm.all_zombie_rows.size())
	for lane in range(lanes):
		var row_node: ZombieRow = zm.all_zombie_rows[lane]
		var init_para := {
			Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
			Zombie000Base.E_ZInitAttr.Lane: lane,
			Zombie000Base.E_ZInitAttr.CurrZombieRowType: row_node.zombie_row_type,
		}
		var zombie: Zombie000Base = zm.create_norm_zombie(
			Settings.TARGET_ZOMBIE, row_node, init_para,
			Vector2(_target_stand_x(mg, lane),
				row_node.zombie_create_position.global_position.y))
		if zombie == null:
			Log.error("玩家对战：第 %d 行的靶子僵尸没生成出来" % lane)
			continue
		_targets.append(zombie)
		zombie.signal_character_death.connect(_on_target_defeated)
	## 摆完稳一下再交回流程（避免镜头 / 阴影同时刷新时看起来像卡了一拍）
	await wait(0.5)


## 靶子站位的 x：让**身体**站在第 `TARGET_ZOMBIE_STAND_COLUMN` 列的正中 ——
## 草坪外那一列的中心，再加上「身体视觉中心比原点偏左」的那一段补正，
## 最后再整体右移 `TARGET_ZOMBIE_STAND_EXTRA_OFFSET_X`（见那边的注释）。
## 结果是身体骑在屏幕右边缘上，一半左右露在屏幕外。
##
## 该行没有格子时退回出怪点 x（让生成落到屏幕外，方便一眼看出关卡数据有问题）。
func _target_stand_x(mg: MainGameManager, lane: int) -> float:
	var cells: Array = mg.plant_cell_manager.all_plant_cells[lane]
	if cells.is_empty():
		return mg.zombie_manager.all_zombie_rows[lane].zombie_create_position.global_position.x
	var last := cells[cells.size() - 1] as PlantCell
	if last == null:
		return mg.zombie_manager.all_zombie_rows[lane].zombie_create_position.global_position.x
	## 跨过几列才到站的那一列（草坪 9 列、站第 10 列 ⇒ 1），再走半格到该列中心
	var column_gap: int = Settings.TARGET_ZOMBIE_STAND_COLUMN - cells.size()
	var column_center_x: float = last.global_position.x + last.size.x * (column_gap + 0.5)
	## 身体画在原点左边，要把这一点补回来，视觉上才真的落在该列正中
	## （再叠加右移量：`TARGET_ZOMBIE_STAND_EXTRA_OFFSET_X`）
	return column_center_x - Settings.TARGET_ZOMBIE_BODY_VISUAL_OFFSET_X \
		+ Settings.TARGET_ZOMBIE_STAND_EXTRA_OFFSET_X


## 靶子被击破：计数 +1
##
## 注意：死亡信号发出时身体还没删（删是死亡动画播完那一帧的事），计数按「信号」走，
## 不等尸体消失 —— 否则击破最后一只后会白等一段淡出时间才判胜。
func _on_target_defeated() -> void:
	## 僵尸方已经赢了（有僵尸进了房子）：这一局的结果不再由靶子数决定
	if _zombie_side_won:
		return
	_targets_defeated += 1
	Log.info("玩家对战：靶子僵尸被击破 %d / %d" % [_targets_defeated, _targets.size()])


## 等到击破 [param count] 只靶子；数够了就返回 —— 流程跑完 = 关卡判胜（见文件头）
##
## 僵尸方赢了（有僵尸进了房子）也立刻返回：这一局已经有结果了，不必再等靶子数
## （返回之后那次「流程跑完强制判胜」会被 `GAME_OVER` 挡掉，见文件头 ⚠️）。
## 主游戏被释放（玩家从主菜单按钮退出这一关）时也返回：协程跟着关卡脚本一起没了，
## 不过多一个条件更稳 —— 与改动前那个 `while is_instance_valid(mg)` 同一个口径。
func wait_targets_defeated(count: int, mg: MainGameManager) -> void:
	while _targets_defeated < count and not _zombie_side_won and is_instance_valid(mg):
		await wait(0.2)
#endregion


#region 僵尸方胜法：僵尸进家
## 僵尸方已经赢了（有僵尸走进了房子）
var _zombie_side_won := false
## `ZOMBIE_GO_HOME` 是否已订阅（流程收尾退订；同一份关卡实例再打一局时不会重复订阅）
var _is_zombie_go_home_subscribed := false


## 接上「僵尸进家」这条事件
##
## 本体的 `MgmLoseManager` 也在听它（失败流程归它跑），本关只是**记一笔记**：
## 谁赢了 + 把植物方的击破计数掐掉。不另起一套收尾，免得两处各演一遍。
func _subscribe_zombie_go_home() -> void:
	if _is_zombie_go_home_subscribed:
		return
	EventBus.subscribe(ConstEventName.ZOMBIE_GO_HOME, _on_zombie_go_home)
	_is_zombie_go_home_subscribed = true


## 退订（流程收尾时调；漏了的话下一局会收到两条一模一样的回调，
## 而且关卡脚本实例挂在选关按钮上，会跟着存档页一直活着）
func _unsubscribe_zombie_go_home() -> void:
	if not _is_zombie_go_home_subscribed:
		return
	EventBus.unsubscribe(ConstEventName.ZOMBIE_GO_HOME, _on_zombie_go_home)
	_is_zombie_go_home_subscribed = false


## 有僵尸走进了房子 = **僵尸方获胜**
##
## 收尾（重开存档 / 暂停 / `losemusic` / 屏幕红字「僵尸吃掉了你的脑子」）由本体
## `MgmLoseManager.on_zombie_go_home` 负责 —— 它先订阅，所以这条回调跑到时主游戏
## 已经是 `GAME_OVER` 了。这里只做两件事：记账 + 掐断植物方的计数。
##
## [param _zombie] 进家的那只僵尸（本体拿它做「搬进门口」的演出，本关用不到）
func _on_zombie_go_home(_zombie: Zombie000Base) -> void:
	## 已经记过（多只同时进家）/ 植物方先赢了（奖杯已经在掉）：都不再改结果
	if _zombie_side_won or _targets_defeated >= Settings.TARGET_ZOMBIE_DEFEAT_TO_WIN:
		return
	_zombie_side_won = true
	Log.info("玩家对战：僵尸进家 —— 僵尸方获胜（植物方击破 %d / %d 只靶子）"
		% [_targets_defeated, _targets.size()])
#endregion
