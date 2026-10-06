extends MainGameSubManager
class_name HandManager
## 手持物管理器（调度器）
##
## 只负责三件事：
##   1. 注册挂在它下面的手持物组件（HandComponentBase 子类，组件自己声明类型）
##   2. 把格子 / 输入事件派发给「当前手持组件」
##   3. 维护「手持中 ⇄ 空闲手持物」的切换（含启停、界面刷新、跨阶段清理）
##      —— 空闲手持物默认是空手，关卡可以把自己的道具设成空闲手持物（见 idle_hand_type）
##
## 具体的手持行为（手持谁、能不能种、界面怎么显示）全部在组件内部实现，
## 所以新增手持物不需要改动本文件（详见 HandComponentBase 的说明）。
## 节点结构：Manager/HandManager/{HM_Null, HM_Character, HM_Item, HM_Glove, HM_Hammer}
## 手持物的可视节点在 CanvasLayerTemp 下（layer 20，跟随画布变换），组件只引用它们。

## 当前鼠标所在植物格子
var curr_plant_cell: PlantCell = null
## 已注册的手持物组件（类型 → 组件）
var all_hand_components: Dictionary[HandComponentBase.E_HandComponentType, HandComponentBase] = {}
## 当前手持组件，注册完成后永远非空（空手时为 HandComponentNull）
var curr_hand_component: HandComponentBase = null
## 「空闲手持物」：放下手持物 / 进入可操作草坪的阶段时回到它，**默认是空手**
## 某些关卡把空手换成自己的道具（锤僵尸关的锤子），由关卡侧的玩法规则注入
## （见 LevelRuleHammerZombie.set_idle_hand_type）；本体只认一个类型，
## 不认识锤子这类具体手持物，也不为此留任何分支（硬约束 §1-8）
var idle_hand_type: HandComponentBase.E_HandComponentType = HandComponentBase.E_HandComponentType.Null


func _ready() -> void:
	EventBus.subscribe("main_game_progress_update", _on_main_game_progress_update)


func init_manager() -> void:
	_register_all_hand_components()


#region 对外接口
## 当前手持类型（调试 / 测试用）
func get_curr_hand_type() -> HandComponentBase.E_HandComponentType:
	if curr_hand_component == null:
		return HandComponentBase.E_HandComponentType.Null
	return curr_hand_component.get_hand_component_type()


## 是否真的拿着东西：空手不算，本关的「空闲手持物」也不算 ——
## 那几关的空闲手持物就是它们的空手（锤僵尸关的锤子，见 set_idle_hand_type）
func is_holding_hand() -> bool:
	if curr_hand_component == null or curr_hand_component.is_null_component():
		return false
	return curr_hand_component.get_hand_component_type() != idle_hand_type


## 取某个手持物组件
func get_hand_component(hand_type: HandComponentBase.E_HandComponentType) -> HandComponentBase:
	return all_hand_components.get(hand_type)


## 手持指定类型的物品，payload 原样透传给组件（角色组件收 Card，铲子不需要参数）
## 返回是否真的拿到手上
func take_hand(hand_type: HandComponentBase.E_HandComponentType, payload: Variant = null) -> bool:
	var component := get_hand_component(hand_type)
	if component == null:
		Log.error("HandManager: 没有注册手持物组件 " + str(hand_type))
		return false
	## 组件被禁用（关卡参数、游戏阶段等）时不允许手持
	if not component.is_enabling:
		return false
	return _change_curr_hand_component(component, payload)


## 放回手持物：回到本关的「空闲手持物」（默认是空手，锤僵尸关回到锤子）
func drop_hand() -> void:
	_switch_to_idle_hand()


## 把某个手持物设成「空闲手持物」取代空手：由关卡侧的玩法规则调用
## （见 LevelRuleHammerZombie）。之后放下手持物、以及进入可操作草坪的阶段都回到它。
## 本体只认一个 E_HandComponentType，不认识任何具体手持物（硬约束 §1-8）
func set_idle_hand_type(hand_type: HandComponentBase.E_HandComponentType) -> void:
	idle_hand_type = hand_type
	_switch_to_idle_hand()


## 启用 / 禁用一个手持物组件（例如关卡没有铲子、轮次切换期间禁用）
## 被禁用的组件不能手持；如果它正在手上会被放下
func change_hand_component_enable(
	hand_type: HandComponentBase.E_HandComponentType,
	value: bool,
	is_enable_factor: ComponentNormBase.E_IsEnableFactor = ComponentNormBase.E_IsEnableFactor.HandItem
) -> void:
	var component := get_hand_component(hand_type)
	if component == null:
		return
	component.change_is_enabling(value, is_enable_factor)
	if not value and curr_hand_component == component:
		drop_hand()


## 刷新所有手持物的界面显隐
func refresh_all_hand_ui() -> void:
	for component in all_hand_components.values():
		component.refresh_ui()
#endregion


#region 组件注册
## 注册所有手持物组件
func _register_all_hand_components() -> void:
	all_hand_components.clear()
	for child in get_children():
		var component := child as HandComponentBase
		if component == null:
			continue
		var hand_type := component.get_hand_component_type()
		if all_hand_components.has(hand_type):
			Log.error("HandManager: 手持物组件类型重复 %s：%s 与 %s" % [
				str(hand_type), all_hand_components[hand_type].name, component.name
			])
			continue
		all_hand_components[hand_type] = component
		component.init_component(self)

	## 空手组件是兜底状态，必须存在
	var null_component := get_hand_component(HandComponentBase.E_HandComponentType.Null)
	if null_component == null:
		Log.error("HandManager: 缺少空手手持物组件(HM_Null)")
		return
	## 初始为空手
	curr_hand_component = null_component
	refresh_all_hand_ui()
#endregion


#region 手持切换
## 切换当前手持组件
func _change_curr_hand_component(component: HandComponentBase, payload: Variant = null) -> bool:
	## 先退出旧手持物：同一个组件重复进入时等价于「重置」
	if curr_hand_component != null:
		curr_hand_component.exit_hand()

	if not component.enter_hand(payload):
		## 进入失败：退回空手，避免停留在半状态
		Log.warn("HandManager: 手持物组件进入失败 " + component.name)
		var null_component := get_hand_component(HandComponentBase.E_HandComponentType.Null)
		if null_component == null:
			return false
		null_component.enter_hand(null)
		_set_curr_hand_component(null_component)
		return false

	_set_curr_hand_component(component)

	## Godot 不会因为「手持物变了」而重发格子 hover 事件，
	## 这里补一次，否则已悬停在格子上时点卡会没有虚影
	if curr_plant_cell != null:
		component.mouse_enter(curr_plant_cell)
	return true


## 回到本关的「空闲手持物」；空闲手持物不可用（没启用 / 不在可操作阶段）时退回空手
func _switch_to_idle_hand() -> void:
	if not _is_idle_hand_available():
		_drop_to_null()
		return
	if curr_hand_component != null and curr_hand_component.get_hand_component_type() == idle_hand_type:
		return
	if not take_hand(idle_hand_type):
		_drop_to_null()


## 强制回到空手：离开可操作草坪的阶段时用（锤子不该在戴夫对话 / 结算时挂在鼠标上）
func _drop_to_null() -> void:
	## 组件还没注册完（阶段事件会比 init_manager() 先到）时手上本来就没东西，静默返回
	if curr_hand_component == null:
		return
	var null_component := get_hand_component(HandComponentBase.E_HandComponentType.Null)
	if null_component == null:
		Log.error("HandManager: 缺少空手组件，无法放下手持物")
		return
	if curr_hand_component == null_component:
		return
	_change_curr_hand_component(null_component)


## 本关的空闲手持物现在能不能拿在手上：有空闲手持物 + 处在可操作草坪的阶段
func _is_idle_hand_available() -> bool:
	if idle_hand_type == HandComponentBase.E_HandComponentType.Null:
		return false
	return is_instance_valid(main_game) and main_game.is_lawn_playable()


func _set_curr_hand_component(component: HandComponentBase) -> void:
	curr_hand_component = component
	refresh_all_hand_ui()
#endregion


#region 事件派发
func _process(_delta: float) -> void:
	if curr_hand_component != null:
		curr_hand_component.hand_process()


## 鼠标点击格子
func _on_click_cell(plant_cell: PlantCell) -> void:
	if curr_hand_component == null:
		return
	## 组件返回 true 表示这次点击用完了手持物
	if curr_hand_component.click_cell(plant_cell):
		drop_hand()


## 鼠标进入格子
func _on_cell_mouse_enter(plant_cell: PlantCell) -> void:
	curr_plant_cell = plant_cell
	if curr_hand_component != null:
		curr_hand_component.mouse_enter(plant_cell)


## 鼠标移出格子
func _on_cell_mouse_exit(plant_cell: PlantCell) -> void:
	curr_plant_cell = null
	if curr_hand_component != null:
		curr_hand_component.mouse_exit(plant_cell)


## 右键 或 左键点击空白处：取消手持
func _input(event: InputEvent) -> void:
	## 空手时不需要处理
	if not is_holding_hand():
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return
	## 右键 或 左键点击空白处
	var is_cancel: bool = mouse_event.button_index == MOUSE_BUTTON_RIGHT \
		or (mouse_event.button_index == MOUSE_BUTTON_LEFT and curr_plant_cell == null)
	if is_cancel:
		SoundManager.play_other_SFX("tap2")
		drop_hand()


## 游戏阶段变化：非游玩阶段不允许手持物跨阶段存活（轮次切换、游戏结束）
## 回到可操作草坪的阶段时补上「空闲手持物」（锤僵尸关这一步把锤子交回玩家手上）
func _on_main_game_progress_update(curr_main_game_progress: MainGameManager.E_MainGameProgress) -> void:
	if curr_main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
		_drop_to_null()
	elif not is_holding_hand():
		## 手上已经有东西（例如教程期间正拿着卡）就别抢
		_switch_to_idle_hand()
	refresh_all_hand_ui()
#endregion
