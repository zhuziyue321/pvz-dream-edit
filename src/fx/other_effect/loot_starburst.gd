extends Node2D
class_name LootStarburst
## **拾取战利品时的星星爆裂**（原版 PARTICLE_STARBURST）
##
## 原版出处：`pak/particles/Starburst.xml`；触发点是原版 `Coin::Collect` 里关卡奖励那一支
## `mApp->AddPvzpParticle(mPosX + 30, mPosY + 30, mRenderOrder + 1, PARTICLE_STARBURST)`
## （PvZ-Portable `src/Lawn/Coin.cpp:1220`）。原版那三组发射器：
##   · STAR40 偏橙（1, .9, 0~.4）
##   · STAR40 偏白（1, 1, .6~.8）
##   · AWARDRAYS_STAR 偏绿（1, .6~.7, 0）
## 共同参数：贴图缩放 0.1~0.3、寿命 50 帧（60fps → 0.83 秒）、
## 发射半径 1~75、初速 500~1800（原版单位是「像素/帧」，这里换算成像素/秒：×60）、
## 带下坠加速度与阻尼，整体是加色混合的火花。
##
## **挂在掉落物所在的容器里，不挂在战利品身上** —— 战利品被拾取后还要放大飞向屏幕中心，
## 挂在身上会被一起放大（见 `DropItemBase.play_level_award_pick_fx`）。
##
## 播完自己删掉。

## 特效自身的存活秒数（略大于粒子寿命，留点余量）
const LIFE_TIME := 1.1


## 播一次爆裂（节点已经入树）
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
