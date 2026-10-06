extends LevelScriptBase
## puzzle_zombie_10 —— 由同目录的 puzzle_zombie_10.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。


func _init() -> void:
	# 存档键写死：解谜模式 20 关合并成一页后按钮序号会变，写死后玩家存档不丢
	save_key = "103_1_0010"
	game_round = -1
	game_BG = ConstLevelData.GameBg.FrontNight
	game_BGM = ConstLevelData.GameBGM.Puzzle
	is_day = false
	is_day_sun = false
	is_lawn_mover = false
	look_show_zombie = false
	can_choosed_card = false
	monster_mode = ConstLevelData.E_MonsterMode.Null
	start_sun = 300
	## 本关可用僵尸 9 只（原版无尽没有巨人）：卡槽数跟随可用僵尸数
	## （不写就会退回存档的卡槽数，多余的僵尸卡会被丢弃）
	max_choosed_card_num = 9
	prechosen_cards = ResourceCardReference.create_zombie_list([25, 3, 4, 5, 21, 18, 22, 8, 9])
	is_zombie_mode = true
	## 原版本关的纸板植物 19 种: 大混战那 14 种去掉高坚果(24)，
	## 再加 双发射手(8) / 小喷菇(9) / 地刺(22) / 火炬树桩(23) / 伞叶(38)
	plant_col_on_zombie_mode = 5
	all_plants_weight_on_zombie_mode.assign({
	1: 1,
	2: 9,
	4: 1,
	5: 1,
	6: 1,
	7: 1,
	8: 1,
	9: 1,
	11: 1,
	14: 1,
	18: 1,
	19: 1,
	22: 1,
	23: 1,
	29: 1,
	30: 1,
	32: 1,
	35: 1,
	38: 1
	})
	is_bowling_stripe = true
	plant_cell_col_j = 4
	plant_cell_can_use.assign({
	"left_can_plant": false,
	"left_can_zombie": false,
	"right_can_plant": false,
	"right_can_zombie": true
	})


func run_flow(mg: MainGameManager) -> void:
	if mg.curr_game_round == 1:
		## 保龄球红线（仅第 1 轮）
		await bowling_stripe()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	await start_battle(-1, [
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z004PoleVaulter,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z008Football,
		CharacterRegistry.ZombieType.Z009Jackson,
		CharacterRegistry.ZombieType.Z018Digger,
		CharacterRegistry.ZombieType.Z021Bungi,
		CharacterRegistry.ZombieType.Z022Ladder,
		CharacterRegistry.ZombieType.Z025Imp,
	])
