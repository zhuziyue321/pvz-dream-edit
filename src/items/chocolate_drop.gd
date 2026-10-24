extends DropItemBase
class_name ChocolateDrop
## 僵尸掉落的巧克力
##
## 原版口径(一代 PC):巧克力不在商店出售,杀了僵尸随机掉;买了蜗牛(Stinky the Snail)之前一块都不掉
## 数据来源: PVZ Wiki(https://plantsvszombies.wiki.gg/wiki/Chocolate)
##   "Randomly from killing zombies"、
##   "Chocolate will not appear until the player purchases Stinky the Snail"、
##   "It can be obtained in all game modes, with the exception of the Zen Garden itself"
##
## 掉落逻辑与金币 / 种子包一致(见 DropItemComponent.drop_chocolate / DIM_Chocolate):
##   僵尸死亡处 -> 抛物线弹出 -> 落地等玩家点击 -> 点开加一块巧克力库存
## 巧克力是消耗型花园工具(喂蜗牛 / 喂完美状态的植物),持有上限 ConstShop.TOOL_MAX_OWN_NUM

## 拾取提示(原版见 data/strings/lawn_strings.txt 的 ADVICE_FOUND_CHOCOLATE)
const TIP_FOUND_CHOCOLATE := "你找到了巧克力！把它喂给蜗牛吃，就能让蜗牛速度加快！"

@onready var texture_button: TextureButton = $TextureButton


## 点开拾取:加一块巧克力库存 -> 弹提示 -> 淡出
func pick() -> void:
	if is_opened:
		return
	is_opened = true
	SoundManager.play_other_SFX("prize")
	## 打断抛物线
	kill_launch_tween()
	texture_button.queue_free()

	Global.global_game_state.add_garden_tool_num(GardenManager.E_GardenTool.Chocolate, 1)
	Global.save_service.save_now()

	var reminder_info: ReminderInformation = SceneRegistry.REMINDER_INFORMATION.instantiate()
	get_tree().current_scene.add_child(reminder_info)
	reminder_info._init_info([TIP_FOUND_CHOCOLATE], tip_show_time)

	fade_and_delete()


## 老名字的入口（联机重放 / 探针直接点巧克力时调）：一律走 `pick()`
func _on_texture_button_pressed() -> void:
	pick()
