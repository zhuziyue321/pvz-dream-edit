extends "res://src/entities/character/components/component_create_sun.gd"
## 产脑子组件（模组「玩家对战」的产脑光墓碑专用）
##
## 完整复用产阳光组件的节奏（首次 3~12.5 s、之后 23.5~25 s、全场加速 / 暂停、
## 主游戏阶段闸门），只把「出阳光」那一步换成「出一颗**脑子阳光**」：
##   · 走 `SunSpawner.pop_up()` —— 与向日葵同一套「弹起来再落下」的掉落与点击收集；
##   · 外观换 PVZ2 的脑子（复用「我是僵尸」接线那套 BrainSun 皮）；
##   · 换上 `sun_brain.gd` 脚本：收走时入**脑子账**，不进植物方的阳光池。
##
## ⚠️ `user://` 下脚本 extends 要用绝对路径（同模组入口 `zombie_card_mod.gd` 的口径）；
##    素材与同目录脚本用相对路径 preload（两个加载根都认）。

const SunBrainScript := preload("sun_brain.gd")


## 替换父类的「出阳光」：弹一颗脑子阳光（掉落 / 收集行为与向日葵的阳光一致）
func _spawn_sun() -> void:
	var main_game := get_main_game()
	if main_game == null or not is_instance_valid(main_game.suns):
		return
	var wiring = main_game.get_node_or_null("ZombieCardPvpWiring")
	if wiring == null:
		## 接线不在（玩家对战模组没开 / 不是对战关）：不产也不报错，
		## 墓碑卡只在玩家对战里发得出来，正常到不了这一步
		return
	## 播放音效
	SoundManager.play_character_SFX(&"Throw1")
	for _i in range(num_create_sun):
		var sun := SunSpawner.pop_up(main_game.suns,
			main_game.suns.to_local(marker_2d_create_sun.global_position), sun_value)
		if sun == null:
			continue
		wiring.restyle_sun_as_brain(sun)
		## 换上「收走入脑子账」的脚本（掉落已起跑）：先把跑起来的状态记下来，
		## 换完再写回去 —— set_script 对成员值的保留不作保证，这几样丢了会出怪
		## （弹跳 tween 引用丢了，拾取时打断不了它，阳光会一边飞一边弹）
		var old_tween: Tween = sun.spawn_sun_tween
		var old_target := sun.spawn_target
		var old_fall: float = sun.spawn_fall
		var old_value: int = sun.sun_value
		var old_entity_id: int = sun.entity_id
		sun.set_script(SunBrainScript)
		sun.spawn_sun_tween = old_tween
		sun.spawn_target = old_target
		sun.spawn_fall = old_fall
		sun.sun_value = old_value
		sun.entity_id = old_entity_id
