extends RefCounted
## 探针：子弹阵营 → 碰撞层（为「植物僵尸」做的阵营对称重构的回归）
##
## 为什么有这个探针：
##   重构前子弹的碰撞层写死在每个 .tscn 的 Area2DAttack 上，且 `bullet_camp` 只是场景导出值，
##   发射方无法指定 —— 同一份子弹场景没法被僵尸方复用（植物僵尸要向玩家的植物开火）。
##   现在阵营由 init_bullet 的 E_InitParasAttr.BulletCamp 决定，碰撞层在 BulletCampConfig 里集中映射。
##   这里锁死「同一份场景、两种阵营、两组碰撞层」的行为，防止以后有人把层改回写死。
##
## 只用到 autoload（BulletRegistry），不需要进关卡，所以不 add_child、不触发子弹 _ready。

var _failed := 0


func run(a) -> void:
	a.log("PROBE 子弹阵营 → 碰撞层 启动")
	_check_linear(a)
	_check_parabola(a)
	_check_bowling(a)
	_check_pure_func(a)
	a.log("")
	a.log("[BULLETCAMP] result=%s failed=%d" % [("PASS" if _failed == 0 else "FAIL"), _failed])
	a.quit_game()


## 直线子弹（豌豆）：场景额外带 layer1 World（判斜坡），换阵营后要保留
func _check_linear(a) -> void:
	var b := _make_bullet(a, BulletRegistry.BulletType.Bullet001Pea, {
		Bullet000NormBase.E_InitParasAttr.BulletCamp: CharacterRegistry.CharacterType.Plant,
	})
	if b == null:
		return
	_expect(a, "豌豆[植物方] layer", b.area_2d_attack.collision_layer, 8)
	_expect(a, "豌豆[植物方] mask", b.area_2d_attack.collision_mask, 512 + 1)
	set_camp(b, CharacterRegistry.CharacterType.Zombie)
	_expect(a, "豌豆[僵尸方] layer", b.area_2d_attack.collision_layer, 128)
	_expect(a, "豌豆[僵尸方] mask", b.area_2d_attack.collision_mask, 256 + 1024 + 1)
	_expect(a, "豌豆[僵尸方] get_bullet_paras 带出阵营",
		b.get_bullet_paras()[Bullet000NormBase.E_InitParasAttr.BulletCamp],
		CharacterRegistry.CharacterType.Zombie)
	b.free()


## 抛物线子弹（篮球：场景原本手改成僵尸方），切回植物方也要能用
func _check_parabola(a) -> void:
	var b := _make_bullet(a, BulletRegistry.BulletType.Bullet013Basketball, {
		Bullet000NormBase.E_InitParasAttr.BulletCamp: CharacterRegistry.CharacterType.Zombie,
	})
	if b == null:
		return
	_expect(a, "篮球[僵尸方] layer", b.area_2d_attack.collision_layer, 128)
	_expect(a, "篮球[僵尸方] mask", b.area_2d_attack.collision_mask, 256 + 1024)
	set_camp(b, CharacterRegistry.CharacterType.Plant)
	_expect(a, "篮球[植物方] layer", b.area_2d_attack.collision_layer, 8)
	_expect(a, "篮球[植物方] mask", b.area_2d_attack.collision_mask, 512)
	b.free()


## 保龄球：场景额外带 layer7 Bowling（撑杆跳检测），换阵营不能把它丢掉
func _check_bowling(a) -> void:
	var b := _make_bullet(a, BulletRegistry.BulletType.Bullet1001Bowling, {
		Bullet000NormBase.E_InitParasAttr.BulletCamp: CharacterRegistry.CharacterType.Plant,
	})
	if b == null:
		return
	_expect(a, "保龄球[植物方] layer", b.area_2d_attack.collision_layer, 8 + 64)
	_expect(a, "保龄球[植物方] mask", b.area_2d_attack.collision_mask, 512 + 1)
	b.free()


## 纯函数：敌我判定 / 阵营推导 / 索敌方向
func _check_pure_func(a) -> void:
	_expect(a, "植物方的敌人是僵尸", BulletCampConfig.get_enemy_camp(CharacterRegistry.CharacterType.Plant),
		CharacterRegistry.CharacterType.Zombie)
	_expect(a, "僵尸方的敌人是植物", BulletCampConfig.get_enemy_camp(CharacterRegistry.CharacterType.Zombie),
		CharacterRegistry.CharacterType.Plant)
	_expect(a, "非角色没有阵营", BulletCampConfig.get_camp_of_character(null),
		CharacterRegistry.CharacterType.Null)
	_expect(a, "植物方不把 null 当敌人", BulletCampConfig.is_enemy(CharacterRegistry.CharacterType.Plant, null), false)
	_expect(a, "植物方子弹 x 更小优先", BulletCampConfig.is_nearer(CharacterRegistry.CharacterType.Plant, 10.0, 20.0), true)
	_expect(a, "僵尸方子弹 x 更大优先", BulletCampConfig.is_nearer(CharacterRegistry.CharacterType.Zombie, 10.0, 20.0), false)


func _make_bullet(a, bullet_type: BulletRegistry.BulletType, paras: Dictionary) -> Bullet000Base:
	var scene: PackedScene = Global.bullet_registry.get_bullet_scenes(bullet_type)
	if scene == null:
		_failed += 1
		a.log("  FAIL 注册表里没有子弹类型 %d" % bullet_type)
		return null
	var b: Bullet000Base = scene.instantiate()
	## 用与攻击组件相同的类型化字典，避免踩「形参是类型化字典」的坑
	var typed: Dictionary[Bullet000NormBase.E_InitParasAttr, Variant] = {}
	for k in paras:
		typed[k as Bullet000NormBase.E_InitParasAttr] = paras[k]
	b.init_bullet(typed)
	return b


func set_camp(b: Bullet000Base, camp: CharacterRegistry.CharacterType) -> void:
	b.set_bullet_camp(camp, true)


func _expect(a, name: String, got, want) -> void:
	if got == want:
		a.log("  OK   %s = %s" % [name, str(got)])
	else:
		_failed += 1
		a.log("  FAIL %s = %s（期望 %s）" % [name, str(got), str(want)])
