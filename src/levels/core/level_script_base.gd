extends ResourceLevelData
class_name LevelScriptBase
## 关卡脚本基类 —— **关卡 = 一个 .gd（属性 + 流程），不再有 .tres**
##
## 一条关卡脚本同时承担两件事：
##   1. 关卡属性：在 _init() 里给继承来的字段赋值（start_sun = 150 …），
##      消费方（各 manager）照旧读 para.start_sun，**一处都不用改**
##   2. 关卡流程：run_flow()，一段顺序结构的协程，用 await 串起下面的流程方法
##
## 流程控制是 GDScript 本身：if / for / while / match 随便用，
## 不再需要「数据轴 + 控制流事件」那一层（Sequence / Repeat / Branch 已无必要）。
##
## **流程方法就长在本基类上**（与 init_level_items / is_curr_level_success 这些平级）：
## 关卡脚本里直接写 `await show_zombie()` —— 不再经过 `prefab.xxx()` 那层门面
## （原 `LevelPrefabs` 门面已拆掉：事件脚本 → 本基类上的同名方法，少一层转发）。
## 加一种流程 = `timeline_event/` 下新建一个事件脚本 + 本基类加一个同名方法。
##
## 谁在用它：
##   LevelTimelineManager.run_timeline()  —— 注入 _mg 后 await run_flow(mg)
##   各 manager 读字段 —— 与读 ResourceLevelData 完全一致
##
## 老 .tres 关卡（ResourceLevelData 实例）没有 run_flow，执行器仍走旧的事件数组，
## 所以迁移可以逐关进行。

## 主游戏管理器：由执行器在 run_flow 之前注入（关卡脚本不要自己赋值）
## 流程方法（show_zombie / start_battle …）靠它拿到主游戏
## 名字带下划线：关卡脚本自己要存主游戏引用时不会撞名（minigame_12_column 就有一份自己的）
var _mg: MainGameManager

## true = run_flow 整关只跑一遍（跨轮继续往下跑，比如砸罐子三批写在同一段里）
## false（默认）= 每轮重跑一遍，一轮 = 这段流程，轮与轮之间由 MainGameManager 摆场
var is_one_shot_flow := false


## 进关时摆放本关专属的场景物品 / 给格子打规则标记 —— **关卡脚本可覆写**
##
## 调用时机：GameItemManager.init_manager() → GIM_Other.init_other_item()，
## 排在 plant_cell_manager.init_manager() **之后**（格子已经建好）、玩家能动手**之前**。
## 所以「这几格只能种某几种植物」这类限制必须写在这里，不能留到 run_flow()
## —— 那时玩家已经选完卡了，限制生效得太晚。
##
## 有了这个钩子，特殊玩法自己的场景物品（观星的星星轮廓这类）就不必在 GIM_Other 里
## 加 `if is_xxx` 分支：玩法逻辑留在关卡脚本里，通用代码不认识任何具体玩法。
##
## [mg] 主游戏管理器：解析格子、打限制这类要用宿主的覆写从这里取
## [item_root] 背景层的物品容器：本关要挂的节点 add_child 到这里，引用由脚本自己留一份
## 基类是空实现（两个参数都不用，故加下划线前缀），覆写时把名字改回 mg / item_root 直接用
func init_level_items(_mg: MainGameManager, _item_root: Node2D) -> void:
	pass


## 本关的关卡进度条数据源 —— **关卡脚本可覆写**（想让进度条代表别的东西就改这里）
##
## 进度条默认代表战斗进度（波次走完多少）；僵王关自动换成僵王血量百分比
## （见 LevelProgressBarController._pick_provider）。
## 想换口径就返回一个自己的 `LevelProgressProvider` 子类实例，比如「砸完几个罐子」：
##   func create_progress_provider() -> LevelProgressProvider:
##       return MyVaseProgressProvider.new()
## 返回 null（默认）= 用上面那套默认挑选；**运行期也能换**，找
## `mg.level_progress_controller.set_provider()` 现场换一个。
func create_progress_provider() -> LevelProgressProvider:
	return null


## 本波僵尸「怎么进场」 —— **关卡脚本可覆写**
##
## 波次管理器每波都会来问这里一次：僵尸清单（wave_spawn）是通用波次按战力算出来的，
## **关卡脚本只改进场方式，不改出什么怪** —— 想改出什么怪就改 zombie_refresh_types。
## 默认实现 = 通用进场（僵尸从场地边缘走进来，见 ZombieWaveCreateManager）。
##
## 有了这个钩子，「本关僵尸改由蹦极僵尸空投进场」这类一关专属玩法就不必在
## ZombieWaveCreateManager 里加 `if is_xxx` 分支：玩法留在关卡脚本里，通用波次代码
## 不认识任何具体玩法名（硬约束 §1-8）。
##
## 返回值必须是**本波真正参战的僵尸**：波次血量统计与提前刷新判定都按它算
## （所以「空投用的蹦极僵尸」也要算进去，它没离场前本波不会清完）。
##
## [create_manager] 波次生成管理器：覆写里要用它的通用能力（普通进场、选行）就从这个参数取
## [wave_spawn] 本波按战力算出来的僵尸清单
## [wave] 当前波次
func create_wave_zombies(
	create_manager: ZombieWaveCreateManager,
	wave_spawn: Array[CharacterRegistry.ZombieType],
	wave: int
) -> Array[Zombie000Base]:
	return create_manager.create_norm_wave_zombies(wave_spawn, wave)


#region 卡槽快捷工具
## 在出战卡槽里放一张「特殊种子包」—— **关卡脚本专用快捷工具**
##
## 卡片长什么样（贴图 / 背景 / 静态形象）照抄 [param card_reference] 对应的那张源卡：
## 植物、普通僵尸、僵王都行；模仿者（植物编号 P999Imitater）没有出战模板，
## 会退回 `AllCards.imitater_card` 那张源卡（见它的注释）。
##
## **点击行为完全由 [param on_click] 决定**：本体不会把它交给手持管理器去种植，
## 也不认识任何具体玩法（硬约束 §1-8）——「花阳光换掉全场植物」这类一关专属的效果写在回调里。
## 回调收到本卡自己（[code]func(card: Card)[/code]）：
##   · 阳光够不够由卡片自己按 [param sun_cost] 判（这个数字同时写在卡片上），不够就置灰 + 蜂鸣，
##     回调不会被调用
##   · **扣阳光与冷却不会自动发生**：要扣就自己扣（或 `card.signal_card_use_end.emit(card)`
##     走出战卡槽那套「扣阳光 + 冷却」），要冷却就 `card.card_cool()`
##   · 一次性卡买完就 `card.set_card_disabled_forever()` 永久置灰
##
## [param cool_time] 冷却秒数，0 = 点了立刻能再点。
## 返回 null = 本关没有出战卡槽 / 身份非法或未注册 / 卡槽没有空位。
func create_custom_seed_packet(
	card_reference: ResourceCardReference,
	sun_cost: int,
	on_click: Callable,
	cool_time: float = 0.0
) -> Card:
	var battle := _get_battle_card_slot()
	if battle == null:
		Log.error("关卡脚本：本关没有出战卡槽，自定义种子包已跳过")
		return null
	if card_reference == null or not card_reference.is_valid():
		Log.error("关卡脚本：自定义种子包的卡牌身份为空，已跳过")
		return null
	## 源卡：模仿者（P999）不出战，没有登记模板，单独取源目录里那一张
	var template: Card = AllCards.get_template(card_reference)
	if template == null and card_reference.card_type == ResourceCardReference.CardType.Plant \
			and card_reference.content_id == CharacterRegistry.PlantType.P999Imitater:
		template = AllCards.imitater_card
	if template == null:
		Log.error("关卡脚本：自定义种子包的卡牌身份未注册：%s" % str(card_reference.to_dict()))
		return null
	if not _ensure_free_placeholder(battle):
		Log.error("关卡脚本：出战卡槽没有空位放自定义种子包")
		return null
	var card: Card = template.duplicate()
	## 副本默认与源卡共享身份资源，先换成独立引用
	card.make_reference_unique()
	var placeholder: CanvasItem = battle.cards_placeholder[battle.curr_cards.size()]
	placeholder.add_child(card)
	card.position = Vector2.ZERO
	battle.curr_cards.append(card)
	## 价格 / 冷却要在入树之后写：卡上的数字与冷却遮罩是 _ready 里取到的节点
	card.card_context = Card.CardContext.Custom
	card.custom_click = on_click
	card.cool_time = cool_time
	card.sun_cost = sun_cost
	card.judge_sun_enough(battle.sun_value)
	return card


## 当前出战卡槽；本关没有常规卡槽 / 主游戏还没起来时返回 null
func _get_battle_card_slot() -> CardSlotBattle:
	var mg: MainGameManager = Global.main_game
	if mg == null or mg.card_manager == null:
		return null
	return mg.card_manager.card_slot_battle


## 保证出战卡槽上还有一个空占位；没有就补一格。
## 补一格是复制现有占位（CardSlotBattle.add_one_card_placeholder），而 Node.duplicate() 会连
## 子节点一起复制，所以补完要把占位里被一起复制出来的卡清掉 ——
## 否则卡槽上会多出一张不在 curr_cards 里、点了也没人管的卡。
func _ensure_free_placeholder(battle: CardSlotBattle) -> bool:
	if battle.curr_cards.size() < battle.cards_placeholder.size():
		return true
	var old_num: int = battle.cards_placeholder.size()
	battle.add_one_card_placeholder()
	if battle.cards_placeholder.size() <= old_num:
		return false
	var new_placeholder: Node = battle.cards_placeholder[battle.cards_placeholder.size() - 1]
	for child in new_placeholder.get_children():
		if child is Card:
			new_placeholder.remove_child(child)
			child.queue_free()
	return true
#endregion


## 本关流程 —— **顺序结构的程序**：上一个流程方法结束才开下一个
## 默认实现等价于 ResourceLevelData.build_default_timeline() 生成的那条轴：
## 戴夫推销 → 戴夫对话 → 保龄球红线 → 展示僵尸 → 选卡 → 初始化小推车 → 准备安放植物 → 开战
## 只生成本关**真实生效**的步骤（判据与 build_default_timeline 一致）
## （教学演出不算默认步骤：那是关卡自己的流程，想教什么由关卡脚本写在 run_flow() 里）
func run_flow(mg: MainGameManager) -> void:
	var is_first_round: bool = mg.curr_game_round == 1
	if is_dave_sell_possible() and is_first_round:
		await dave_sell()
	if has_dave_dialog_on_any_round():
		await dave_dialog()
	if is_bowling_stripe and is_first_round:
		await bowling_stripe()
	if look_show_zombie:
		## 老 .tres 关卡的出怪表还在关卡数据上，这里把它带过去给预览僵尸用
		## （脚本关的出怪表写在自己的 show_zombie / start_battle 调用上，本字段是空的）
		await show_zombie(zombie_refresh_types)
		if can_choosed_card:
			await choose_card()
		else:
			## 不能选卡：相机在预览位停 3 秒再归位开战（等价旧的 no_choosed_card_start_game）
			await wait(3.0)
			await camera_back()
	## 初始化小推车：出生在屏幕外左侧，按从下到上的顺序开到位
	## （推车之前一直看不见 —— 这一步才登场，正好赶在「准备…安放…植物」之前）
	await init_lawn_mover()
	## 「准备…安放…植物」红字：砸罐子关不播（罐子摆好就能直接砸，见原版冒险 4-5）
	if is_show_ready_set_plant:
		await ready_set_plant()
	## 开战自己会等到本段打完，所以末尾不再挂别的流程步骤
	await start_battle()


#region 快捷工具：通关记录查询
## **按关卡存档名查某一关有没有通关过**（没打过 / 打了没打通，都是 false）
##
## level_save_key —— 关卡存档名：V2 关卡就是它在 _init() 里写死的那个 save_key
## （"101_0_0001" = 冒险 1-1；取值见关卡脚本的 save_key，或 ResourceLevelData.save_game_name）。
## 关卡脚本靠它就能问「另一关打没打通」，比如某一关要看前置关通没通过决定演不演某段：
##   if is_level_success("101_0_0001"):
##       await dave_dialog(_build_dialog())
func is_level_success(level_save_key: String) -> bool:
	return Global.global_game_state.is_level_success(level_save_key)


## **本关有没有通关过**（存档里本关 IsSuccess）—— 上面那条把名字换成「本关自己」的版本
##
## 「只给第一次进本关的玩家看」的东西（新手教程、一次性开场演出…）都用这一个开关：
##   if not is_curr_level_success():
##       await _tutorial_flow()
## 查的是同一份存档，所以和 `mg.is_curr_level_success()` 完全等价 ——
## 直接走本关自己的存档名，不依赖主游戏，意思是「本关脚本自己就答得上来」。
func is_curr_level_success() -> bool:
	return is_level_success(save_game_name)
#endregion


#region 流程方法（与 timeline_event/ 下的事件脚本一一对应）
## 跑一个流程事件：填备注后 await 它的 run()
##
## **主游戏没了就直接放弃这段流程**：关卡协程挂在教程的等待上时玩家可能退回主菜单，
## MainGameManager 一被释放，教程那边的 signal/timer 会把协程唤醒 —— 这时候再 `event.run()`
## 传的就是个已释放的对象（GDScript 会报 "previously freed ... is not a subclass of"）。
## 这里挡一道，后面每个 await 都会立刻返回，协程自己跑完退出。
func _run_event(event: ResourceLevelTimelineEvent, note: String) -> void:
	event.note = note
	if not is_instance_valid(_mg):
		return
	await event.run(_mg)


## 戴夫推销卡槽扩充（默认流程里只在第 1 轮跑）
func dave_sell() -> void:
	await _run_event(LevelTimelineEventDaveSell.new(), "戴夫推销卡槽扩充")


## 快捷工具：**开场让戴夫推销一次卡槽扩充**（原版：商店解锁之前，2-2 ~ 3-4 这段关卡）
##
## 关卡脚本在 run_flow() 开头写一行 `await dave_sell_card_slot()` 就够 —— 「该不该推销」全由
## 它自己判，脚本里不用再补条件：
##   · 非冒险模式 / 冒险序号 < 2-2 / 本关不能选卡（传送带）→ 整句空转（is_dave_sell_possible）；
##   · **商店已解锁（通关 3-4 之后）→ 戴夫不来**：卡槽扩充改由商店出售，这条判据在
##     is_dave_sell_possible() 与 DaveSellManager.is_can_sell() 里各写一次，互为保险；
##   · 卡槽已买满 → 戴夫不来；
##   · **金币不够当前档价 → 戴夫也不来**（只有 2-2 会预告一次「攒到 $N 我就卖给你」）。
## 判据后面两条在 DaveSellManager.is_can_sell()，也就是说这句话**只在钱足够时才真推销**：
## 戴夫报价、玩家同意即扣钱 + 卡槽 +1，本关立刻用上新卡槽。
## 多轮关只在第 1 轮跑，第 2 轮起不再打断玩家。
## 本关有戴夫对话时**不要**写这一句 —— 免得开场连播两段戴夫（对话关以关卡对话为准）。
func dave_sell_card_slot() -> void:
	if not is_dave_sell_possible():
		return
	if is_instance_valid(_mg) and _mg.curr_game_round != 1:
		return
	await dave_sell()


## 关卡戴夫对话：**说哪一段由流程现场给**（`await dave_dialog(对话)`）
## 多轮关卡按 mg.curr_game_round 自己挑（见 adventure_04_05 的三批罐子）
## 不传时才回落到关卡资源上的 crazy_dave_dialog / crazy_dave_dialog_next_round（老写法）
func dave_dialog(dialog_resource: CrazyDaveDialogResource = null) -> void:
	var event := LevelTimelineEventDaveDialog.new()
	event.dialog_resource = dialog_resource
	await _run_event(event, "关卡戴夫对话")


## 保龄球红线
func bowling_stripe() -> void:
	await _run_event(LevelTimelineEventBowlingStripe.new(), "保龄球红线")


## 展示僵尸（相机拉到预览位，僵尸走两步）
## zombie_refresh_types —— 本关出怪表，预览僵尸按它生成；留空 = 沿用关卡数据
## （预览跑在开战之前，本关出怪表要在这里一起给，见 LevelTimelineEventShowZombie）
func show_zombie(zombie_refresh_types: Array[CharacterRegistry.ZombieType] = []) -> void:
	var event := LevelTimelineEventShowZombie.new()
	event.zombie_refresh_types = zombie_refresh_types
	await _run_event(event, "展示僵尸")


## 选卡：等玩家选完卡
func choose_card() -> void:
	await _run_event(LevelTimelineEventChooseCard.new(), "选卡")


## 相机归位（不能选卡时：预览位停一会儿再回来）
func camera_back() -> void:
	await _run_event(LevelTimelineEventCameraBack.new(), "相机归位")


## 纯等待 seconds 秒
func wait(seconds: float = 1.0) -> void:
	var event := LevelTimelineEventWait.new()
	event.wait_time = seconds
	await _run_event(event, str("等待", seconds, "秒"))


## 初始化小推车：出生在屏幕外左侧，串行地按从下到上开到位
func init_lawn_mover() -> void:
	await _run_event(LevelTimelineEventLawnMover.new(), "初始化小推车")


## 「准备…安放…植物」红字
func ready_set_plant() -> void:
	await _run_event(LevelTimelineEventReadySetPlant.new(), "准备安放植物")


## 布阵阶段：放开玩家的手（能种植）并放一个「开始战斗！」按钮，等玩家点它
## （原版迷你游戏「坚不可摧」：开局那笔阳光先拿去种防线，种好了自己点按钮开打）
## 本方法自己会先允许操作，点完按钮再往下走，下一步通常是「开战」
func wait_battle_start() -> void:
	await _run_event(LevelTimelineEventWaitBattleStart.new(), "等待开始战斗")


## 开战：跑到本段打完为止（出怪关 = 最后一波刷完 + 僵尸清空；砸罐子 = 罐子全开 + 僵尸清空）
## 本段的出怪参数可以在这里给（关卡脚本里一眼看出「这一仗怎么打」），留默认 = 沿用关卡数据上的值：
##   max_wave —— 本段波数（> 0 生效）
##   zombie_refresh_types —— 本段出怪表（非空生效）
## timeout > 0 时最多等这么多秒
func start_battle(max_wave: int = -1,
		zombie_refresh_types: Array[CharacterRegistry.ZombieType] = [],
		timeout: float = 0.0) -> void:
	var event := LevelTimelineEventStartBattle.new()
	event.max_wave = max_wave
	event.zombie_refresh_types = zombie_refresh_types
	event.timeout = timeout
	await _run_event(event, "开战")


## 系统代种植物：不消耗阳光、不需要卡片、不走手牌
## 开局摆造型（1-5 教程要铲掉的那几株豌豆射手）、中途补种都走这条；屋顶铺花盆见
## `plant_flower_pot_columns()` —— 那条是本函数的快捷封装。
func system_plant(plants: Array[SystemPlantResource]) -> void:
	var event := LevelTimelineEventSystemPlant.new()
	event.plants = plants
	await _run_event(event, "系统种植")


## 快捷工具：**沿整列种下若干列花盆**（屋顶 / 夜屋顶的种植位）
##
## 屋顶是裸地，没有花盆什么都种不下 —— 屋顶关都要先沿整列铺出种植位。
## 老写法是一列一条 `SystemPlantResource`（铺 4 列要写 13 行，
## （铺 4 列要写 13 行，而且多轮关切轮清场后花盆不会回来），现在在 run_flow() 里一句话：
##   await plant_flower_pot_columns(4)        ## 第 1~4 列（绝大多数屋顶关）
##   await plant_flower_pot_columns(8)        ## 第 1~8 列（排山倒海）
##   await plant_flower_pot_columns(2, 5)     ## 第 5~6 列
## 走的是「系统种植」事件：不消耗阳光、不需要卡片，一格上已经有花盆就跳过
## （`PlantCell.create_plant` 的既有植物判据），多轮关每轮切回来都会重新铺一次。
## **要写在玩家能动手之前**（一般是 run_flow 开头），否则「先有盆再种」的顺序就反了。
## [col_count] 铺几列；[begin_col] 从第几列开始铺（都从 1 起）
func plant_flower_pot_columns(col_count: int, begin_col: int = 1) -> void:
	await system_plant(SystemPlantResource.create_flower_pot_columns(col_count, begin_col))


## 清场：清空场上僵尸 / 罐子等，为下一批摆场做准备
func clear_field() -> void:
	await _run_event(LevelTimelineEventClearField.new(), "清场")


## 切换背景音乐：**跑到这一句当场换曲，不等**
## 曲目见 ConstLevelData.GameBGM（GameBGM.NoBGM = 停掉音乐）
## keep_as_main_game_bgm 留 true（默认）：开战一秒后 / 下一轮开局时主游戏会重播 BGM，不同步会被本关原曲盖回去
func change_bgm(bgm: ConstLevelData.GameBGM, keep_as_main_game_bgm: bool = true) -> void:
	var event := LevelTimelineEventChangeBgm.new()
	event.bgm = bgm
	event.keep_as_main_game_bgm = keep_as_main_game_bgm
	await _run_event(event, "切换BGM")
#endregion


#region 快捷工具：提示与箭头
## 这一组**与教程无关**：任何关卡都能在屏幕下方显示一句提示 / 用箭头指一样东西。
## 两者各自独立开关（提示归提示、箭头归箭头），不需要任何管理器 ——
## 没有教程、不是教程关，照样能出提示条与箭头
## （共用同一个提示条实例，见 TutorialAdviceUI.ensure_level_hint）。
## 要「等玩家做点什么」用下一区的 wait_* 系列，与这两个工具自由搭配。

## 屏幕下方显示一段提示文本：
##   await hint("点击种子包，把它捡起来！")
## **传空串 = 关掉提示条**（只收文本；箭头要一起收就再调一句 hide_arrow()）
func hint(text: String = "") -> void:
	var event := LevelTimelineEventHint.new()
	event.text = text
	await _run_event(event, "提示：" + text)


## 关掉屏幕下方的提示条（hint("") 的同义写法，读起来更直白）
func hide_hint() -> void:
	await hint("")


## 箭头指到 target 那类东西上（跟着目标走：阳光会飘、卡片会位移，箭头每帧重算落点）
## plant_type 给 Card / Lawn 两个目标用（找那张卡 / 找能种它的格子）
func arrow(target: PointerTargetResolver.E_PointerTarget,
		plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null) -> void:
	var event := LevelTimelineEventArrow.new()
	event.target = target
	event.plant_type = plant_type
	await _run_event(event, "箭头指向" + _arrow_target_name(target))


## 箭头指到这张种子包上
func arrow_card(plant_type: CharacterRegistry.PlantType) -> void:
	await arrow(PointerTargetResolver.E_PointerTarget.Card, plant_type)


## 箭头指到一块能种下 plant_type 的草地上（留 Null = 草坪中心那一格）
func arrow_lawn(plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null) -> void:
	await arrow(PointerTargetResolver.E_PointerTarget.Lawn, plant_type)


## 箭头指到场上一颗还没收的阳光上（还没掉下来就先不显示，掉下来自动跟上）
func arrow_sun() -> void:
	await arrow(PointerTargetResolver.E_PointerTarget.Sun)


## 箭头指到卡槽里的铲子上
func arrow_shovel() -> void:
	await arrow(PointerTargetResolver.E_PointerTarget.Shovel)


## 箭头指到草坪上第一株还活着的植物
func arrow_plant() -> void:
	await arrow(PointerTargetResolver.E_PointerTarget.Plant)


## 收起箭头（玩家该用的东西已经在手上时不该再指）
func hide_arrow() -> void:
	await arrow(PointerTargetResolver.E_PointerTarget.None)


## 箭头目标的名字（只用于事件备注，给人看流程日志）
func _arrow_target_name(target: PointerTargetResolver.E_PointerTarget) -> String:
	match target:
		PointerTargetResolver.E_PointerTarget.Card:
			return "种子包"
		PointerTargetResolver.E_PointerTarget.Lawn:
			return "草地"
		PointerTargetResolver.E_PointerTarget.Sun:
			return "阳光"
		PointerTargetResolver.E_PointerTarget.Shovel:
			return "铲子"
		PointerTargetResolver.E_PointerTarget.Plant:
			return "草坪上的植物"
	return "无（收起箭头）"
#endregion


#region 快捷工具：等玩家做点什么（与提示 / 箭头自由搭配）
## 这一组把「教程长什么样」直接写进 run_flow()：一句提示 + 一个等待，逐个 await 排下来。
## 每个等待都是**事件自己判定**（轮询 / 事件订阅），不依赖任何管理器 ——
## 有没有教程、是不是教程关都能用，判定逻辑见各事件脚本与 LevelWaitCondition。
##
## 教程要玩家先能动手 —— 在第一个 wait_* 之前 await allow_operation()，
## 用完提示 / 箭头记得自己关掉（hint("") / hide_arrow()），没有「教程收尾」会替你收。

## 允许操作：放开玩家的手（能点卡 / 种植 / 收阳光 / 拿铲子），但还**不开战**
## （开战 = 天降阳光 / 出怪 / 生成墓碑，见 start_battle）
## 教程要让玩家先动手，就用它把「能操作」排在「开打」之前
func allow_operation() -> void:
	await _run_event(LevelTimelineEventAllowOperation.new(), "允许操作")


## 掉一颗阳光下来（给玩家收）；不是关卡的天降阳光定时器，只是单独一颗
func spawn_sun() -> void:
	await _run_event(LevelTimelineEventSpawnSun.new(), "生成一颗阳光")


## 等玩家把这张卡捡到手上；plant_type 留 Null = 任意卡
func wait_take_card(plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null) -> void:
	var event := LevelTimelineEventWaitTakeCard.new()
	event.plant_type = plant_type
	await _run_event(event, "等待玩家捡起卡片")


## 等玩家把铲子拿在手上（铲子教学）
func wait_take_shovel() -> void:
	await _run_event(LevelTimelineEventWaitTakeShovel.new(), "等待玩家拿起铲子")


## 等玩家种下 count 株植物；plant_type 留 Null = 任意植物
func wait_plant(count: int = 1, plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null) -> void:
	var event := LevelTimelineEventWaitPlant.new()
	event.count = count
	event.plant_type = plant_type
	await _run_event(event, "等待玩家种下植物")


## 等玩家铲掉 count 株植物（铲一株就用掉一把铲子，铲下一株要重新拿）
func wait_dig_plant(count: int = 1) -> void:
	var event := LevelTimelineEventWaitDigPlant.new()
	event.count = count
	await _run_event(event, "等待玩家铲掉植物")


## 等玩家把草坪上的植物全部铲光
func wait_dig_all_plants() -> void:
	var event := LevelTimelineEventWaitDigPlant.new()
	event.is_dig_all = true
	await _run_event(event, "等待玩家铲光草坪")


## 限时等玩家种下 count 株植物：**时限内种下返回 true，到点还没动手返回 false**
##
## 给「说完一句提示先让玩家自己试」用的 —— 原版 1-1 说完「阳光够了」之后是直接等的，
## 只有玩家自己不动手的那 4 秒过去了，才补那句「点击豌豆射手，再种一棵！」。
func wait_plant_timeout(count: int = 1,
		plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null,
		timeout: float = 4.0) -> bool:
	var event := LevelTimelineEventWaitPlant.new()
	event.count = count
	event.plant_type = plant_type
	event.timeout = timeout
	await _run_event(event, "限时等待玩家种下植物")
	return event.is_planted


## 等玩家点掉一颗阳光
func wait_collect_sun() -> void:
	await _run_event(LevelTimelineEventWaitCollectSun.new(), "等待玩家收集阳光")


## 等玩家的阳光攒到 sun_value
func wait_sun_enough(sun_value: int = 100) -> void:
	var event := LevelTimelineEventWaitSunEnough.new()
	event.sun_value = sun_value
	await _run_event(event, "等待阳光足够")
#endregion
