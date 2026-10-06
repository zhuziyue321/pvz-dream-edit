extends ResourceLevelTimelineEvent
class_name LevelTimelineEventShowZombie
## 展示僵尸：创建预览僵尸并把相机移过去
##
## 参数：
##   zombie_refresh_types —— 本关出怪表，非空时先改写关卡数据上的出怪表再生成预览僵尸；
##              空 = 沿用关卡数据。**预览僵尸跑在开战之前**，本关出怪表要跟着一起给，
##              否则预览里出现的会是关卡数据上那份默认出怪表（见 MainGameManager.apply_level_zombie_refresh_types）

@export var zombie_refresh_types: Array[CharacterRegistry.ZombieType] = []


func run(main_game: MainGameManager) -> void:
	## 预览僵尸按出怪表抽样生成，出怪表要在生成之前改好
	main_game.apply_level_zombie_refresh_types(zombie_refresh_types)
	main_game.zombie_manager.create_prepare_show_zombies()
	await wait_seconds(main_game, 1.0)
	await main_game.camera_2d.move_look_zombie()
