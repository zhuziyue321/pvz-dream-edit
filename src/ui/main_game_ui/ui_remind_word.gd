extends Control
class_name UIRemindWord

@onready var ready_plant: TextureRect = $Ready
@onready var set_plant: TextureRect = $Set
@onready var plant: TextureRect = $Plant
@onready var approaching: TextureRect = $Approaching
@onready var final_wave: TextureRect = $FinalWave
@onready var zombies_won: TextureRect = $ZombiesWon

## 「一大波僵尸正在接近」红字的显示时长
const TIME_APPROACH_SHOW := 4.0
## 红字出现到僵尸真正刷出的总时长（原版约 7.45 秒）
## 旗前波拖满 45 秒 + 本值 = 原版「大波前拖满 52.45 秒」
## 数据来源: 新PVZ通关技术理论1.1 第二章 2.2 波长与刷新(https://www.bilibili.com/read/cv40586093)
const TIME_ZOMBIE_APPROACH := 7.45


## 准备放置植物
func ready_set_plant() -> void:
	visible = true
	SoundManager.play_other_SFX("readysetplant")
	for node in [ready_plant, set_plant, plant]:
		node.visible = true
		await get_tree().create_timer(0.6, false).timeout  # 等待 1 秒
		node.visible = false
	visible = false


## 僵尸靠近
func zombie_approach(final:bool) -> void:
	visible = true
	SoundManager.play_other_SFX("hugewave")
	approaching.visible = true
	await get_tree().create_timer(TIME_APPROACH_SHOW, false).timeout  # 红字显示 4 秒
	approaching.visible = false
	if final:
		await get_tree().create_timer(2, false).timeout  # 等待 2 秒
		# SFX 最后一波红字音效
		SoundManager.play_other_SFX("finalwave")
		final_wave.visible = true
		await get_tree().create_timer(3, false).timeout  # 等待 3 秒
		final_wave.visible = false
	else:
		## 红字出现到僵尸刷出共 TIME_ZOMBIE_APPROACH 秒（原版 7.45 秒）
		await get_tree().create_timer(TIME_ZOMBIE_APPROACH - TIME_APPROACH_SHOW, false).timeout

	visible = false

## 僵尸获胜
func zombie_won_word_appear() -> void:

	visible = true
	zombies_won.visible = true
	#await get_tree().create_timer(0.8).timeout  # 等待 1 秒
	#zombies_won.visible = false
	#visible = false
