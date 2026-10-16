extends LevelScriptBase
## minigame_13_bobsled_bonanza —— 原版迷你游戏**第 13 关**「全面冻结」(Bobsled Bonanza)
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 文件名里的编号 = 选关界面上的原版顺序（01~20），与 `src/menus/choose_level/mini_game_choose_level.tscn` 的按钮顺序一致。
##
## 本关的三件事（冰面是本关的地形，不是装饰）：
##   1. 开局冰道 —— 四条地面路线从右向左各铺 `PRESET_ICE_ROAD_CELL_NUM` 格冰，
##      铺完那一整段就不能种东西了（`PlantCell.E_SpecialStatePlant.IsIceRoad`），
##      泳池两条水面路线不铺（冰车 / 雪橇队的行类型都是 Land）
##      **铺冰排在关卡最开始**（`init_level_items`，玩家选卡时冰面已经在场上），
##      不是排在关卡流程里 —— 玩家的阵型从选卡那一刻起就得绕着冰面布置
##   2. 冰上的僵尸 —— 洗冰车（Z013Zamboni）**自己在冰面上往前开一路铺冰**，
##      雪橇队（Z014Bobsled）只在有冰的行上出、沿冰滑行，滑到冰面尽头就散架成四个雪橇兵
##      （见 Zombie014Bobsled.judge_is_in_ice_road / death_language）
##   3. 融冰与复冰 —— 冰面只能被火爆辣椒整行融掉（`jalapeno_bomb_item_lane`），
##      融掉之后这一行的雪橇队就出不来，只能出洗冰车，等洗冰车把冰铺回来才恢复
##      （见 ZombieWaveCreateManager.select_bobsled_spawn_row）
##
## 原版口径（Pool / Four flags / Plants:Zombies:Choice）：
##   数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Bobsled_Bonanza)
##   · "starts with four permanently placed ice trails on four ground lanes (up to the fourth column)"
##     → 四条地面行开局就结着冰（剩下列数按「从最右列往左铺 PRESET_ICE_ROAD_CELL_NUM 格」记账），
##       **且 unlike any other game modes, the ice trails do not disappear** —— 预铺的冰没有倒计时
##   · "If the player melts the preplaced ice, they will face several Zombonis before any Zombie Bobsled Teams"
##     → 融冰后先来的全是洗冰车（上面第 3 条）
##   · "45-second wait time" —— 摆完植物到第一波僵尸要等 45 秒（第一波延迟），仅次于「蹦蹦舞会」的 55 秒
##   · Four flags = 40 波 → start_battle(40, ...)
##
## 融冰后的**出怪密度**（原版 Trivia，已实现，见下面 before_wave_spawn）：
##   预置冰面被全部融掉后，普通僵尸的出现密度明显提高 —— 洗冰车把冰铺回来就自动恢复原密度


## 开局每条地面行从最右列往左铺几格冰（铺到的格子不能种植物，剩下的留给玩家）
const PRESET_ICE_ROAD_CELL_NUM := 4

## 预置冰面被**全部**融掉之后，普通僵尸的出怪密度倍率
## 原版口径（wiki Trivia）：「If the player manages to clear out all of the pre-existent ice trails,
## regular zombies will appear in a much higher density.」（同页 Gallery 图注更绝对：
## "When all the ice is melted, only regular Zombies will appear."）
## wiki 只给了「明显提高」这个定性描述，**没有解包数值** —— 3.0 是按「占比翻倍」倒推的保守值
## （普僵权重 4000 → 12000，在同池占比约 27% → 52%），**待核实**
const NORM_DENSITY_WHEN_ICE_MELTED := 3.0


func _init() -> void:
	## 存档键写死（V2）：选关按钮顺序调整后存档键不变，玩家的老通关记录不会错位
	save_key = "102_0_0012"
	game_sences = MainSceneRegistry.MainScenes.MainGameBack
	game_BG = ConstLevelData.GameBg.Pool
	## 场景曲：本关是泳池 → 泳池曲 Watery Graves
	game_BGM = ConstLevelData.GameBGM.Pool
	zombie_multy = 3
	## 原版本关的超长开场：摆完植物要等 45 秒才来第一波（仅次于「蹦蹦舞会」的 55 秒）
	first_wave_delay = 45.0


#region 开局冰道（本关专属地形，硬约束 §1-8：不进游戏本体）
## 进关时（格子已建好、玩家还动手不了）就把冰铺上 —— **只注册一条回调，不在这里立刻铺**：
## 铺冰要同时读僵尸行的落脚点（`ZombieManager` 建行）与植物格子（`PlantCellManager` 建格子），
## 回调排在所有子管理器 `init_manager()` 之后，两样都齐了（时机见 `MainGameManager.level_init_callbacks`）。
## 原版口径：一进场四条地面路线就结着冰，所以冰面必须在玩家选卡时就摆在场地上
func init_level_items(mg: MainGameManager, _item_root: Node2D) -> void:
	mg.register_level_init_callback(Callable(self, "_create_preset_ice_roads").bind(mg))


func _create_preset_ice_roads(mg: MainGameManager) -> void:
	mg.zombie_manager.create_preset_ice_roads(PRESET_ICE_ROAD_CELL_NUM)
#endregion


#region 融冰后的出怪密度（本关专属，硬约束 §1-8：不进游戏本体）
## 每一波「随机挑僵尸之前」按当前还有没有冰，调普僵的出怪密度
##
## 冰面还在 → 普僵回到原版密度（雪橇队能出，本来就占着出怪大头）
## 冰全融了 → 普僵明显变多（洗冰车会把冰铺回来，铺回来就自动恢复原密度）
##
## 只改「随机挑到谁」，不碰战力上限 / 波数 / 出怪节奏
func before_wave_spawn(create_manager: ZombieWaveCreateManager, _wave: int, _is_big_wave: bool) -> void:
	if _mg == null:
		return
	var has_ice := false
	for row_ice_roads: Array[IceRoad] in _mg.zombie_manager.all_ice_roads:
		if not row_ice_roads.is_empty():
			has_ice = true
			break
	if has_ice:
		create_manager.set_zombie_density(ZombieIds.NORM, 1.0)
	else:
		create_manager.set_zombie_density(ZombieIds.NORM, NORM_DENSITY_WHEN_ICE_MELTED)
#endregion


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[StringName] = [
		ZombieIds.ZAMBONI,
		ZombieIds.BOBSLED,
		ZombieIds.NORM,
		ZombieIds.CONE,
		ZombieIds.BUCKET,
	]

	## 展示僵尸
	await show_zombie(zombie_list)
	## 选卡
	await choose_card()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	## （冰面已经在进关时铺好了，见 init_level_items —— 玩家的阵型要绕着那四条冰面布置，
	##  想在冰面上种得先拿火爆辣椒融冰）
	await ready_set_plant()
	## 开战（原版 Four flags = 40 波）
	await start_battle(40, zombie_list)
