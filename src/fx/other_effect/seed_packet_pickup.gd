extends Node2D
class_name LootSeedPacketPickup
## **种子包被点开时那串「僵尸头」粒子**（原版 PARTICLE_SEED_PACKET_PICKUP）
##
## 原版出处：`pak/particles/SeedPacketPickup.xml`；触发点是原版 `Coin::Collect` 关卡奖励那一支
## `mApp->AddPvzpParticle(..., PARTICLE_SEED_PACKET_PICKUP)` + `AttachParticle(...)`
## （PvZ-Portable `src/Lawn/Coin.cpp:1238`，原版只在开了 3D 加速时才播）。
## 种子包被点开后它**跟着种子包一起飞向屏幕中心**（原版是 AttachParticle 挂在掉落物身上），
## 所以本仓库把它作为种子包的子节点 —— 见 `SeedPacket.play_seed_packet_pickup_fx`。
##
## 原版那两组发射器（贴图都是 IMAGE_ZombieHead）：
##   · 颜色 (.9, .9, .7)，另一个 (.9, .9, .9)
##   · 缩放 .5 起、按 EaseIn 长到 5
##   · 发射半径 40（圆周均布）、寿命 120 帧（60fps → 2 秒）、整段 200 帧（3.33 秒）
##   · alpha：0 → 1（20 帧内）→ 保持 → 90 帧后归 0
##   · 一个「Away」场（径向推开）与一个「Circle」场（绕圈）
##
## ⚠️ 原版的场（Field）在 Godot 里没有一一对应的实现：
##   · Away 场  → `radial_accel` + 曲线（径向推开）
##   · Circle 场 → `orbit_velocity`（绕发射器转圈）
## 两处都按「观感接近」取值，不是逐项照抄。

## 特效自身的存活秒数（略大于整段粒子时长 3.33 秒，留点余量）
const LIFE_TIME := 3.6
## 径向推开的速度（像素/秒²）：原版 Away 场把粒子从中心推开
const RADIAL_PUSH := 180.0
## 绕圈的速度（像素/秒）：原版 Circle 场让粒子绕着中心转
const ORBIT_SPEED := 30.0


func _ready() -> void:
	_apply_curves()


## 把原版那几条「随时间变化」的曲线做出来（Godot 的曲线只能在代码里建，
## 写进 .tscn 的话 Curve 的序列化格式太啰嗦）
func _apply_curves() -> void:
	for child in get_children():
		if not (child is GPUParticles2D):
			continue
		var system := child as GPUParticles2D
		var mat := system.process_material as ParticleProcessMaterial
		if mat == null:
			continue
		## 缩放：.5 起，EaseIn 长到 5（原版 ParticleScale .5 EaseIn 5）
		mat.scale_curve = _curve_texture(_make_scale_curve())
		## 透明度：0 -> 1（20 帧）-> 保持 -> 90 帧后归 0（原版 ParticleAlpha）
		mat.alpha_curve = _curve_texture(_make_alpha_curve())


## 缩放曲线：起步慢、后面猛（原版 EaseIn）
func _make_scale_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0), 0.0, 0.0)
	## 右切线给 2.0：曲线起步平缓、后段陡 —— 就是 EaseIn 的形状
	curve.add_point(Vector2(1.0, 1.0), 0.0, 2.0)
	return curve


## 透明度曲线：按粒子寿命的进度（0~1）分段
func _make_alpha_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0), 0.0, 0.0)
	curve.add_point(Vector2(20.0 / 120.0, 1.0), 0.0, 0.0)
	curve.add_point(Vector2(90.0 / 120.0, 1.0), 0.0, 0.0)
	curve.add_point(Vector2(1.0, 0.0), 0.0, 0.0)
	return curve


## 把一条 Curve 包成 ParticleProcessMaterial 要的 CurveTexture
func _curve_texture(curve: Curve) -> CurveTexture:
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex


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
