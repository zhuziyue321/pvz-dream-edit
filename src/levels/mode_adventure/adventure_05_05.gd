extends LevelScriptBase
## adventure_05_05 —— 由同目录的 adventure_05_05.tres 迁移而来
##
## 关卡 = 属性（_init 里赋值）+ 流程（run_flow 一段顺序程序），不再有 .tres。
## 原 .tres 上的 timeline 事件数组已按原顺序平铺成 run_flow() 里的 await 序列。
##
## 本关专属玩法「蹦极闪电战」见同目录 adventure_05_05_bungi_blitz.gd：
## 管理器由本脚本在 init_level_items() 里创建，波次进场方式由 create_wave_zombies() 换掉。


#region 蹦极闪电战（本关专属）
## 本关的蹦极闪电战：僵尸全部由蹦极僵尸空投进场，只有 5-5 用得到，所以挂在关卡脚本这一侧
var bungi_blitz: Adventure0505BungiBlitz


## 进关时把空投管理器建起来（格子已建好、玩家还动手不了，见 LevelScriptBase.init_level_items）
func init_level_items(mg: MainGameManager, item_root: Node2D) -> void:
	bungi_blitz = Adventure0505BungiBlitz.new()
	bungi_blitz.name = "BungiBlitz"
	item_root.add_child(bungi_blitz)
	bungi_blitz.init_bungi_blitz(mg.zombie_manager)


## 本波僵尸不从场地边缘走进来，改由空投蹦极僵尸吊进场（清单仍由通用波次按战力算）
func create_wave_zombies(
	create_manager: ZombieWaveCreateManager,
	wave_spawn: Array[CharacterRegistry.ZombieType],
	wave: int
) -> Array[Zombie000Base]:
	if bungi_blitz == null:
		return create_manager.create_norm_wave_zombies(wave_spawn, wave)
	return bungi_blitz.create_drop_wave_zombies(create_manager, wave_spawn, wave)
#endregion


func _init() -> void:
	game_sences = MainSceneRegistry.MainScenes.MainGameRoof
	game_BG = ConstLevelData.GameBg.Roof
	game_BGM = ConstLevelData.GameBGM.Roof
	## 蹦极闪电战:不直接出怪,僵尸全部由蹦极僵尸空投进场;大波另外来偷植物的蹦极僵尸
	## 空投本身是本关专属玩法,写在同目录的 adventure_05_05_bungi_blitz.gd 里,由本脚本创建
	## 传送带补种 花盆/南瓜头/大嘴花/樱桃炸弹
	is_bungi = true
	card_mode = ConstLevelData.E_CardMode.ConveyorBelt
	conveyor_weights = ResourceCardWeight.create_plant_weights({
	3: 2,
	7: 2,
	31: 2,
	34: 2
	})


## 关卡开场戴夫对话：在 run_flow() 里现场构造并传给 dave_dialog
func _build_dave_dialog() -> CrazyDaveDialogResource:
	var crazy_dave_dialog_detail_resource_0 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	crazy_dave_dialog_detail_resource_0.text = "花园很漂亮，对吧？"
	var crazy_dave_dialog_detail_resource_1 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	crazy_dave_dialog_detail_resource_1.text = "你随时都可以从主菜单那里来到这个花园。"
	var crazy_dave_dialog_detail_resource_2 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	crazy_dave_dialog_detail_resource_2.text = "现在是时间保卫你的房子了！"
	var crazy_dave_dialog_detail_resource_3 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	crazy_dave_dialog_detail_resource_3.text = "我不得不警告你…"
	var crazy_dave_dialog_detail_resource_4 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	crazy_dave_dialog_detail_resource_4.text = "你会讨厌下一关的。"
	var crazy_dave_dialog_detail_resource_5 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	crazy_dave_dialog_detail_resource_5.text = "为什么？ 因为接下来是一个接一个的飞贼僵尸。"
	var crazy_dave_dialog_detail_resource_6 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	crazy_dave_dialog_detail_resource_6.text = "我讨厌这些糊涂的飞贼僵尸!!!"
	crazy_dave_dialog_detail_resource_6.is_crazy = true
	var crazy_dave_dialog_detail_resource_7 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	crazy_dave_dialog_detail_resource_7.text = "我恨他们！！"
	var crazy_dave_dialog_detail_resource_8 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	crazy_dave_dialog_detail_resource_8.text = "恨它们的那种执着劲！"
	var crazy_dave_dialog_detail_resource_9 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	crazy_dave_dialog_detail_resource_9.text = "还有那种报复心！"
	var crazy_dave_dialog_detail_resource_10 := CrazyDaveDialogDetailResource.new()
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	## 原版冒险模式 5-5 开场戴夫台词
	## 台词文本: data/strings/lawn_strings.txt 的 CRAZY_DAVE_1301~1311
	## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Plants_vs._Zombies/Dialogue) 的 Level 5-5 段
	## 原版口径: 前 3 句(1301~1303,禅境花园收尾)只在第一轮说,后 8 句(1304~1311,警告飞贼僵尸)每轮都说;
	## 本仓库的 dave_dialog_only_first_playthrough 是整段级开关,这里按"每轮都播"处理(见 docs/参考存档/特殊关卡.md)
	crazy_dave_dialog_detail_resource_10.text = "啊—啊—啊—那个白痴来啦！"
	var crazy_dave_dialog_resource_0 := CrazyDaveDialogResource.new()
	crazy_dave_dialog_resource_0.dialog_detail_list.assign([crazy_dave_dialog_detail_resource_0, crazy_dave_dialog_detail_resource_1, crazy_dave_dialog_detail_resource_2, crazy_dave_dialog_detail_resource_3, crazy_dave_dialog_detail_resource_4, crazy_dave_dialog_detail_resource_5, crazy_dave_dialog_detail_resource_6, crazy_dave_dialog_detail_resource_7, crazy_dave_dialog_detail_resource_8, crazy_dave_dialog_detail_resource_9, crazy_dave_dialog_detail_resource_10])
	return crazy_dave_dialog_resource_0


func run_flow(_mg: MainGameManager) -> void:
	await plant_flower_pot_columns(4)
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[CharacterRegistry.ZombieType] = [
		CharacterRegistry.ZombieType.Z001Norm,
		CharacterRegistry.ZombieType.Z003Cone,
		CharacterRegistry.ZombieType.Z005Bucket,
		CharacterRegistry.ZombieType.Z022Ladder,
	]

	## 关卡戴夫对话
	await dave_dialog(_build_dave_dialog())
	## 展示僵尸
	await show_zombie(zombie_list)
	## 选卡
	await choose_card()
	## 准备安放植物
	## 初始化小推车
	await init_lawn_mover()
	await ready_set_plant()
	## 开战
	await start_battle(20, zombie_list)


