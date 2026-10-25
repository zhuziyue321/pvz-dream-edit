extends Sun
## 脑子阳光（模组「僵尸卡」的产脑光墓碑掉的）
##
## 与 `Sun` 唯一的区别：收走时入**脑子账**（`ZombieCardPvpWiring.add_brains()`），
## 不发 `ADD_SUN_VALUE` —— 对战里阳光池是**植物方**的，僵尸方的产出不能长到对手口袋里。
##
## ★ 为什么整个 pick() 抄一遍：入账那句在 `Sun.pick()` 中间（`EventBus.push_event`），
##   GDScript 没法"只跳过中间一句地调 super"，只能整段重写。
##   掉落 / 弹跳 / 落地 / 自动收集开关 / 点击闸门全在基类，一行没动。
##
## ⚠️ 本文件可能跑在 `user://mods/zombie_card/` 下：extends 用绝对路径（同模组入口口径）。
##    这份脚本是**运行期换上去的**（`set_script`，见 `component_create_brains.gd`）——
##    `Sun` / `DropItemBase` 全是普通变量、没有 `@onready`，换脚本不丢状态；
##    拾取按钮连的还是节点方法名，换脚本后照常解析到这条 pick()。


## 收走这一颗：入脑子账 → 飞向计数器 → 淡出（飞行段与 `Sun.pick()` 同款）
func pick() -> void:
	if spawn_sun_tween != null:
		if spawn_sun_tween.is_valid():
			spawn_sun_tween.kill()
		spawn_sun_tween = null
	kill_launch_tween()
	if is_opened:
		return
	is_opened = true
	SoundManager.play_other_SFX("points")
	## 收走了就不能再点
	var button := get_pick_button()
	if button != null:
		button.queue_free()
	var target_position := Vector2()
	if is_instance_valid(GameContext.curr_main_game):
		## 与 `Sun.pick()` 唯一的分岔有两条：
		##   · 入**脑子账**，不发 ADD_SUN_VALUE（阳光池是植物方的）
		##   · 飞向**右上银行的脑子计数**，不是左上植物卡槽的阳光计数
		var wiring = GameContext.curr_main_game.get_node_or_null("ZombieCardPvpWiring")
		if wiring != null:
			wiring.add_brains(sun_value)
			target_position = wiring.get_brain_fly_target()
		if target_position == Vector2.ZERO:
			## 拿不到银行落点（接线不在 / 没装上）：退回植物计数器那套口径，
			## 总比原地消失强；脑子照样已经入账（wiring 在的话）
			if is_instance_valid(GameContext.curr_main_game.marker_2d_sun_target):
				## 出战卡槽在canvaslayer中，位置和摄像头位置有偏移
				target_position = GameContext.curr_main_game.marker_2d_sun_target.global_position \
					+ GameContext.curr_main_game.camera_2d.global_position
			else:
				target_position = GameContext.curr_main_game.marker_2d_sun_target_default.global_position
	fly_to_target(target_position, Callable(), 0.3)
