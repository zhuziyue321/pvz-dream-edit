extends ResourceLevelTimelineEvent
class_name LevelTimelineEventCameraBack
## 相机移回原位（不选卡的预览僵尸关：预览完把镜头移回来）
## 没有参数

func run(main_game: MainGameManager) -> void:
	await main_game.camera_2d.move_back_ori()
