extends Node2D
class_name LootPresentPickup
## **拾取「带提示的礼物」时的那团星火**（原版 PARTICLE_PRESENT_PICKUP）
##
## 原版出处：`pak/particles/PresentPickup.xml`；触发点是原版 `Coin::Collect` 里
## 花园植物礼包（`Coin.cpp:1071`）、迷你 / 解谜 / 生存模式解锁（`1090` / `1104` / `1118`）、
## 巧克力（`1134`）与信件（`1231`）那几个分支：
## `mApp->AddPvzpParticle(mPosX + 30, mPosY + 30, mRenderOrder + 1, PARTICLE_PRESENT_PICKUP)`
##
## 原版那三组发射器（与 `Starburst.xml` 同族，差别在速度与颜色）：
##   · STAR40 偏橙（1, .9, 0~.4）
##   · STAR40 偏白（1, 1, .6~.8）
##   · AWARDRAYS_STAR 偏绿（1, .6~.7, 0）
## 共同参数：贴图缩放 0.2~0.5、寿命 50 帧（60fps → 0.83 秒）、发射半径 1~50、
## 初速 300~600、带下坠加速度与阻尼，整体是加色混合的火花。
##
## **单位换算**（与 `loot_starburst.tscn` 同一套，别改）：
##   速度   原版 xml 值 × 0.6   （LaunchSpeed 是「像素/帧 ÷ 100」，×60 换成像素/秒）
##   加速度 原版 xml 值 × 3600 （Acceleration 是「像素/帧²」，×3600 换成像素/秒²）
##
## **挂在掉落物所在的容器里，不挂在战利品身上** —— 与星星爆裂同一个理由
## （见 `DropItemBase.play_present_pickup_fx`）。
##
## 播完自己删掉。

## 特效自身的存活秒数（略大于粒子寿命，留点余量）
const LIFE_TIME := 1.1


## 播一次（节点已经入树）
func play() -> void:
	var systems: Array[GPUParticles2D] = []
	for child in get_children():
		if child is GPUParticles2D:
			systems.append(child as GPUParticles2D)
	if systems.is_empty():
		queue_free()
		return
	for system in systems:
		system.emitting = true
	await get_tree().create_timer(LIFE_TIME).timeout
	queue_free()
