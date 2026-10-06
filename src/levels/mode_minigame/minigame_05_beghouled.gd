extends LevelScriptBase
## minigame_05_beghouled —— 原版迷你游戏**第 5 关**「僵尸迷阵」(Beghouled)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## **本关的三消玩法全部归本文件管**（硬约束 §1-8：一关专属机制不进游戏本体）：
##   · 玩法本体 `BeghouledManager` / UI `BeghouledUI` / 数值 `ConstBeghouled` 与 09 关共用，
##     放在 `src/levels/core/beghouled/`；只属于本关的进度数据源在同目录
##     `minigame_05_beghouled_progress_provider.gd`
##   · 管理器由**本脚本自己 new() 并持有**（见 init_level_items / _init_beghouled），
##     本体（`MainGameManager`）不认识它，关卡数据上也没有「是不是三消关」这种开关字段
##   · 本体给的是通用口子 `MainGameManager.register_level_init_callback()`：
##     本脚本注册一条回调，主游戏跑完所有子管理器 init_manager() 之后回调它
##   · 关卡右下角那条进度条换成三消口径：`create_progress_provider()` 返回
##     `BeghouledProgressProvider`（进度 = 配对次数 / 75，见该类）
##
## 玩法：草坪开局铺满植物（最右一列留空给僵尸入场）→ 按住一株拖到相邻株（原版是拖动，不是点两下）
##   → 凑三个及以上同类连线
##   → 消除给阳光（3 连 25 / 4 连 50 / 5 连及以上 100）→ 累计 75 次配对通关。
##   植物被僵尸啃掉会留弹坑（花 200 阳光填），阳光还能买三档升级与手动重置。
##
## 数据来源: Plants vs Zombies Wiki(https://plantsvszombies.wiki.gg/wiki/Beghouled)（一代原版口径）

## 本关的三消玩法管理器（本脚本创建并持有，本体没有对应字段）
var beghouled: BeghouledManager = null
## 本关的进度条数据源：进度 = 配对次数 / 75（见 create_progress_provider）
var progress_provider := BeghouledProgressProvider.new()
## 卡槽里的五张自定义种子包：三档升级 + 刷新盘面 + 填坑（见 _create_seed_packets）
var custom_seed_packets: Array[Card] = []
## 第五张（填坑）：要跟着盘面上的弹坑数置灰 / 点亮，所以单独留个把手
var crater_fill_packet: Card = null


func _init() -> void:
	## 存档键写死（V2）：选关按钮顺序调整后存档键不变，玩家的老通关记录不会错位
	save_key = "102_0_0006"
	## 场景曲：本关是夜晚前院 → 夜晚曲 Moongrains
	game_BGM = ConstLevelData.GameBGM.FrontNight
	game_BG = ConstLevelData.GameBg.FrontNight
	## 夜晚关：is_day = false 表示夜晚，蘑菇不睡觉（原版僵尸迷阵里的蘑菇是醒着的，
	## 盘面里有小喷菇 / 磁力菇两种蘑菇，写成 true 会全程睡觉且不攻击）
	is_day = false
	## 阳光只来自配对，不天降
	is_day_sun = false
	## 原版没有小推车也没有钉耙：任意一只僵尸走到屋里就算输
	is_lawn_mover = false
	## 植物是系统铺的，玩家没有卡片可选，也不能铲（原版植物不能铲掉）
	can_choosed_card = false
	is_shovel = false
	## 出战卡槽五格：本关玩家不能自己挑卡，五格全被下面的自定义种子包占满
	## （升级三档 + 刷新盘面 + 填坑；留着卡槽本身也让阳光计数有地方显示）
	max_choosed_card_num = 5
	## 开局没有阳光，全靠配对攒
	start_sun = 0
	## 原版本关是无限波（wiki：unlimited number of flags），这里给一个足够大的波数；
	## 必须是 10 的倍数，否则进度条上的旗帜数（max_wave / 10）会对不上大波
	max_wave = 100


#region 三消的接入（本关专属，本体不认识）
## 进关时（格子已建好、玩家还动手不了）把三消接进主游戏：
## **只注册一条回调，不立刻创建** —— 棋盘要读 PlantCellManager 的格子，
## 进度条数据源也等这一拍才拿得到三消管理器；回调排在所有子管理器 init_manager() 之后，两样都齐了
## （时机说明见 MainGameManager.level_init_callbacks）
func init_level_items(mg: MainGameManager, _item_root: Node2D) -> void:
	mg.register_level_init_callback(Callable(self, "_init_beghouled").bind(mg))


## 真正创建三消管理器：挂到主游戏的 Manager 节点下，与本体的其它子管理器同一套路
func _init_beghouled(mg: MainGameManager) -> void:
	if is_instance_valid(beghouled):
		return
	beghouled = BeghouledManager.new()
	beghouled.name = "BeghouledManager"
	mg.manager.add_child(beghouled)
	beghouled.init_manager()
	## 进度条数据源这时才拿得到三消管理器：之后每帧问它要配对次数
	progress_provider.bind_manager(beghouled)
	## 卡槽五张自定义种子包：建在这里（卡槽已按 max_choosed_card_num 建好占位，
	## 玩家还没开打），开战后它们就跟着出战卡槽一起进场
	_create_seed_packets()


## 本关的进度条口径：**配对次数 / 75**（原版没有波次旗帜，进度条在这里代表配对进度）
## 数据源是本脚本自己的实例（`progress_provider`），三消管理器建好后绑给它（见 _init_beghouled）
func create_progress_provider() -> LevelProgressProvider:
	return progress_provider
#endregion


#region 卡槽里的自定义种子包（本关专属）
## 五张种子包：三档升级各一张（贴图用升级后的那种植物，价格见 ConstBeghouled.UPGRADE_LIST），
## 第四张 100 阳光刷新（重排）场上所有植物（卡面 = seeds.png 裁出的刷新种子包整图），
## 第五张 200 阳光填一个弹坑（卡面 = seeds.png 裁出的填坑种子包整图）。
## 本关玩家能按的东西全在这五张卡上（底部按钮条已移除），
## 全部走 `create_custom_seed_packet()` 这个通用口子：本体只管「点击交给回调」，
## 不认识「僵尸迷阵的升级 / 刷新 / 填坑」是什么（硬约束 §1-8）。
func _create_seed_packets() -> void:
	for i in range(ConstBeghouled.UPGRADE_LIST.size()):
		var info: Dictionary = ConstBeghouled.UPGRADE_LIST[i]
		## 卡面用升级**之后**的那种植物（原版升级按钮上画的就是升级版）
		var icon_type: CharacterRegistry.PlantType = info["to"]
		_create_upgrade_packet(i, icon_type, int(info["sun"]))
	## 第四张：刷新盘面（身份引用只用来取卡片模板，卡面在下面整张换成专用贴图）
	var refresh_ref := ResourceCardReference.create(
		ResourceCardReference.CardType.Plant,
		CharacterRegistry.PlantType.P999Imitater
	)
	var refresh_card := create_custom_seed_packet(refresh_ref, ConstBeghouled.SHUFFLE_SUN, _on_refresh_packet_click)
	ConstBeghouled.set_packet_face(refresh_card, ConstBeghouled.PACKET_REFRESH_TEXTURE)
	_append_packet(refresh_card)
	## 第五张：填坑（花 200 阳光填一个弹坑，填完那格立刻长出新植物）
	var fill_ref := ResourceCardReference.create(
		ResourceCardReference.CardType.Plant,
		CharacterRegistry.PlantType.P016DoomShroom
	)
	crater_fill_packet = create_custom_seed_packet(fill_ref, ConstBeghouled.CRATER_FILL_SUN, _on_fill_packet_click)
	ConstBeghouled.set_packet_face(crater_fill_packet, ConstBeghouled.PACKET_FILL_TEXTURE)
	_append_packet(crater_fill_packet)
	## 没有弹坑可填时这张卡是灰的：跟着盘面上的弹坑数开关（只报数字，怎么显示由本脚本定）
	beghouled.crater_num_changed.connect(_on_crater_num_changed)
	_on_crater_num_changed(beghouled.get_crater_cells().size())


## 弹坑数量变了：有坑就点亮填坑卡，没坑就封住（card.set_card_blocked）
func _on_crater_num_changed(crater_num: int) -> void:
	if crater_fill_packet != null:
		crater_fill_packet.set_card_blocked(crater_num <= 0)


## 一张升级种子包：点了把场上（以及以后长出来的）from 植物全换成 to，买过一次就永久置灰
func _create_upgrade_packet(index: int, icon_type: CharacterRegistry.PlantType, sun_cost: int) -> void:
	var card_ref := ResourceCardReference.create(ResourceCardReference.CardType.Plant, icon_type)
	_append_packet(create_custom_seed_packet(card_ref, sun_cost, _on_upgrade_packet_click.bind(index)))


func _append_packet(card: Card) -> void:
	if card == null:
		Log.error("僵尸迷阵：自定义种子包没建出来，本关卡槽会少一格")
		return
	custom_seed_packets.append(card)


## 升级种子包被点击：买成了就把这张卡永久置灰（一档只能买一次）
func _on_upgrade_packet_click(card: Card, index: int) -> void:
	if not is_instance_valid(beghouled):
		return
	if not beghouled.try_buy_upgrade(index):
		SoundManager.play_other_SFX("buzzer")
		return
	card.set_card_disabled_forever()


## 刷新种子包被点击：花 100 阳光把场上所有植物重排一遍（阳光与盘面校验都在 try_shuffle 里）
func _on_refresh_packet_click(card: Card) -> void:
	if not is_instance_valid(beghouled):
		return
	if not beghouled.try_shuffle():
		SoundManager.play_other_SFX("buzzer")
		return
	card.card_cool()


## 填坑种子包被点击：花 200 阳光填掉一个弹坑（有没有坑 / 阳光够不够都在 try_fill_crater 里）
## 填完还有坑就能接着点，坑填完了由 crater_num_changed 把它封住
func _on_fill_packet_click(card: Card) -> void:
	if not is_instance_valid(beghouled):
		return
	if not beghouled.try_fill_crater():
		SoundManager.play_other_SFX("buzzer")
		return
	card.card_cool()
#endregion


func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z006Paper,
	]

	## 展示僵尸
	await show_zombie(zombie_list)
	## 相机归位（本关不走选卡，预览后直接回来摆场）
	await camera_back()
	## 正常走 init_level_items 注册进来的回调时管理器已经有了；
	## 没走到的场合（比如关卡脚本被直接跑）这里兜底建一次，保证流程拿得到它
	if not is_instance_valid(beghouled):
		_init_beghouled(mg)
	if not is_instance_valid(beghouled):
		Log.error("僵尸迷阵：三消管理器没建起来，本关无法开局")
		return
	## 摆场：草坪铺满植物，并放出三消界面（配对进度 + 升级 / 重置 / 填坑按钮）
	## 必须 await：摆场内部要等两帧让格子槽位空出来，不等的话它会和 main_game_start() 抢着跑
	await beghouled.setup_board()
	## 开战并等到达标：结束条件是配对次数，不是「打完最后一波 + 僵尸清空」
	## （所以这里不走 start_battle()，见 BeghouledManager.start_beghouled）
	await beghouled.start_beghouled(zombie_list)
