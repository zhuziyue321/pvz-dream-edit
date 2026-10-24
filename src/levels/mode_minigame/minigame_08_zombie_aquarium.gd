extends LevelScriptBase
## minigame_08_zombie_aquarium —— 原版迷你游戏**第 8 关**「僵尸水族馆」(Zombie Aquarium)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## ⚠️ 本关没有草坪玩法：不出怪、不种植物、不天降阳光，整关就是一口鱼缸，
## 玩法本体在 `src/zombiquarium/`（数值见 `src/core/consts/const_zombiquarium.gd`，
## **逐条标了原版源码出处**）：
##   点鱼缸花 5 阳光造脑子喂潜水僵尸 -> 僵尸定时产阳光 -> 100 阳光买僵尸、1000 阳光买奖杯通关；
##   宠物僵尸一直在掉血（血量 ≤150 才找脑子，吃一个 +200），掉到 0 就死，全死光判负。
## 因此这里**不走** show_zombie / choose_card / start_battle 那套流程，只负责把
## 主游戏推进到 MAIN_GAME 阶段，然后把流程挂在水族馆的结束信号上。


## **本关唯一的操作入口是出战卡槽里的两张自定义种子包**（见 `_create_seed_packets`）：
##   100 阳光「购买潜水僵尸」一张、1000 阳光「购买奖杯」一张（点了就通关）；
##   右下角那条进度条换成阳光口径 = 阳光 / 1000（见 `ZombiquariumProgressProvider`）。
## 两套工具走的都是本体给的通用口子（`LevelScriptBase.create_custom_seed_packet()` /
## `create_progress_provider()`），本体不认识「水族馆」这个概念（硬约束 §1-8）。

## 奖杯种子包的卡面：本体没有「奖杯」这种卡类型，只能拿奖杯贴图自己贴到静态形象那一块
var PACKET_TROPHY_TEXTURE: Texture2D = AssetRegistry.get_texture("res://pak/images/trophy_hi_res.png")
## 卡上静态形象的可用范围（见 card.tscn 的 CardBg/CharacterStatic）：奖杯原图比它大，要缩到放得进
const PACKET_FACE_MAX_SIZE := Vector2(46.0, 34.0)

## 本关的进度条数据源：进度 = 阳光 / 1000（见 create_progress_provider）
var progress_provider := ZombiquariumProgressProvider.new()
## 出战卡槽里的两张自定义种子包：买潜水僵尸 / 买奖杯
var custom_seed_packets: Array[Card] = []

## 水族馆所在的画布层：**必须夹在泳池底图(-10)与出战卡槽(-1)之间**
##
## 出战卡槽那一层在 MAIN_GAME 阶段会被压到 layer = -1（见 canvas_layer_card_slot.gd），
## 泳池底图那一层是 -10（见 main_game_base.tscn 的 CanvasLayerBG）。
## 鱼缸画在 -2：
##   · 比底图高 → 进关第一帧就是鱼缸，不会先露出泳池；
##   · 比卡槽低 → 阳光计数与两张种子包压在鱼缸上面，看得见也点得到。
const AQUARIUM_CANVAS_LAYER := -2
## 画布层的节点名（探针 / 调试通道按名字找得到）
const AQUARIUM_LAYER_NAME := "CanvasLayerZombiquarium"


func _init() -> void:
	## 存档键写死（V2）：选关按钮顺序调整后存档键不变，玩家的老通关记录不会错位
	save_key = "102_0_0009"
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	game_BG = ConstLevelData.GameBg.Pool
	## 原版水族馆播夜晚曲「Moongrains」，**不是**通用小游戏曲
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Music_(PvZ))
	## ——「The Night music is called 'Moongrains.' … This music also plays in Zombiquarium.」
	game_BGM = ConstLevelData.GameBGM.FrontNight
	## 开局 50 阳光（原版数值，见 ConstZombiquarium.SUN_START）
	start_sun = ConstZombiquarium.SUN_START
	## 本关不出怪：僵尸是养在缸里的宠物，不是敌人
	monster_mode = ConstLevelData.E_MonsterMode.Null
	## 没有植物，也就不需要选卡、小推车、天降阳光、准备安放植物
	can_choosed_card = false
	is_lawn_mover = false
	is_day_sun = false
	is_show_ready_set_plant = false
	look_show_zombie = false
	## 出战卡槽两格：本关玩家不能自己挑卡，两格全被下面的自定义种子包占满
	## （买潜水僵尸 + 买奖杯；留着卡槽本身也让阳光计数有地方显示）
	max_choosed_card_num = 2
	## 相机直接停在归位位（水族馆按相机左上角对齐整屏，见 ZombiquariumManager）
	camera_init_x = MainGameCamera.CAM_POS_ORI.x


## 本关的进度条口径：**阳光 / 1000**（水族馆没有波次，进度条在这里就是「离奖杯还差多少阳光」）
## 数据源是本脚本自己的实例（`progress_provider`），水族馆挂上之后由它 `bind_manager()`
func create_progress_provider() -> LevelProgressProvider:
	return progress_provider


func run_flow(mg: MainGameManager) -> void:
	## ① 水族馆**先建、先画**：进关第一帧就得是鱼缸
	##    （推进到 MAIN_GAME 那段里有卡槽进场动画 + 开战 1 秒定时器，
	##    水族馆要是等它跑完再建，中间这一两秒画面就是泳池底图）
	var aquarium: ZombiquariumScene = _create_aquarium(mg)

	## ② 推进到 MAIN_GAME 阶段：本关不出怪（monster_mode = Null），波次管理器不会刷僵尸，
	## 这一步只是把阶段切过去、相机归位、BGM 起来、出战卡槽进场（卡槽位这时候才建好）
	await mg.main_game_start()

	## ③ 开战那一步会按新阶段把铲子 / 手套那套 UI 再刷一遍（见 HandManager 的阶段刷新），
	## 本关没有草坪，铲子不该出现 —— 再藏一次
	aquarium.get_manager().hide_lawn_ui()

	## ④ 进度条这时才拿得到水族馆：之后每帧向它问一次阳光，算出「阳光 / 1000」
	progress_provider.bind_manager(aquarium.get_manager())
	## ⑤ 卡槽里的两张自定义种子包：玩家的买东西入口全在这两张卡上
	_create_seed_packets(aquarium.get_manager())

	var is_win: bool = await aquarium.signal_finished
	Log.info("僵尸水族馆：关卡流程结束，is_win = %s" % str(is_win))


## 建水族馆：先建画布层，再把入口场景挂进去，最后初始化
##
## 画布层是**单独一层**（AQUARIUM_CANVAS_LAYER），不是挂在主游戏根节点上：
## 出战卡槽那一层在 MAIN_GAME 阶段是 -1，鱼缸要是还在默认画布（layer 0），
## 就会把卡槽整块盖住（阳光计数与两张种子包全看不见）。
## `follow_viewport_enabled` 与底图那一层一致：层内坐标 = 世界坐标，
## 所以本体那套「按相机左上角对齐」（见 ZombiquariumManager.init_zombiquarium）不用改。
func _create_aquarium(mg: MainGameManager) -> ZombiquariumScene:
	var layer := CanvasLayer.new()
	layer.name = AQUARIUM_LAYER_NAME
	layer.layer = AQUARIUM_CANVAS_LAYER
	layer.follow_viewport_enabled = true
	mg.add_child(layer)
	var aquarium: ZombiquariumScene = SceneRegistry.ZOMBIQUARIUM_SCENE.instantiate()
	layer.add_child(aquarium)
	## 初始化（关卡模式）：本体这时就按相机左上角对齐，并造出开局的 2 只潜水僵尸
	aquarium.init_zombiquarium(mg)
	return aquarium


#region 出战卡槽里的自定义种子包（本关专属）
## 两张种子包：100 阳光买一只潜水僵尸（卡面就是潜水僵尸）、1000 阳光买奖杯通关。
## 两张都走 `create_custom_seed_packet()` 这个通用口子：本体只管「点击交给回调」，
## 不认识「水族馆的买僵尸 / 买奖杯」是什么（硬约束 §1-8）。
func _create_seed_packets(aquarium: ZombiquariumManager) -> void:
	if aquarium == null:
		Log.error("僵尸水族馆：拿不到玩法本体，买东西的种子包没建出来")
		return
	## 第一张：买潜水僵尸（原版就是这条 tooltip「购买潜水僵尸」）
	var snorkel_ref := ResourceCardReference.create(
		ResourceCardReference.CardType.Zombie,
		ZombieIds.SNORKLE
	)
	_append_packet(create_custom_seed_packet(snorkel_ref, ConstZombiquarium.PET_SUN_COST,
		_on_buy_pet_packet_click.bind(aquarium)))
	## 第二张：买奖杯（1000 阳光，买下即通关）
	var trophy_ref := ResourceCardReference.create(
		ResourceCardReference.CardType.Zombie,
		ZombieIds.SNORKLE
	)
	var trophy_packet := create_custom_seed_packet(trophy_ref, ConstZombiquarium.TROPHY_SUN_COST,
		_on_trophy_packet_click.bind(aquarium))
	_set_trophy_face(trophy_packet)
	_append_packet(trophy_packet)


## 奖杯种子包的卡面：本体没有「奖杯」这类角色可以引用，卡面借用潜水僵尸那张卡的模板，
## 再把静态形象整块换成奖杯贴图（同 minigame_05_beghouled 的专用卡面做法）
func _set_trophy_face(card: Card) -> void:
	if card == null:
		return
	for child in card.character_static.get_children():
		child.queue_free()
	var trophy := Sprite2D.new()
	trophy.texture = PACKET_TROPHY_TEXTURE
	trophy.scale = Vector2.ONE * minf(
		PACKET_FACE_MAX_SIZE.x / PACKET_TROPHY_TEXTURE.get_width(),
		PACKET_FACE_MAX_SIZE.y / PACKET_TROPHY_TEXTURE.get_height()
	)
	card.character_static.add_child(trophy)


func _append_packet(card: Card) -> void:
	if card == null:
		Log.error("僵尸水族馆：自定义种子包没建出来，本关卡槽会少一格")
		return
	custom_seed_packets.append(card)


## 「购买潜水僵尸」被点击：买成了由水族馆自己扣阳光（见 ZombiquariumManager.try_buy_pet）
func _on_buy_pet_packet_click(_card: Card, aquarium: ZombiquariumManager) -> void:
	if not is_instance_valid(aquarium):
		return
	if not aquarium.try_buy_pet():
		SoundManager.play_other_SFX("buzzer")


## 「购买奖杯」被点击：买成了就把这张卡永久置灰（本关也就结束了）
## 奖杯抛在卡片上：canvas_layer_temp 走屏幕坐标（见规范 S-03）
func _on_trophy_packet_click(card: Card, aquarium: ZombiquariumManager) -> void:
	if not is_instance_valid(aquarium):
		return
	if not aquarium.try_buy_trophy(card.get_global_transform_with_canvas().origin):
		SoundManager.play_other_SFX("buzzer")
		return
	card.set_card_disabled_forever()
#endregion
