extends RefCounted
## 探针：植物僵尸（原版 ZomBotany）的结构回归
##
## 为什么有这个探针：
##   植物僵尸是「一份配置表 + 一批只改属性的继承场景」生成的，
##   场景里任何一个节点索引 / 属性名写错（例如 HpComponent 的 max_hp_armor1 写不进去），
##   在编辑器里看不出来，只有跑起来才发现「头顶植物没有耐久」或者「发射组件没挂上」。
##   这里锁死：配置自洽 + 场景属性能落地。
##
## 只做静态检查，不进关卡（不 add_child，不会触发僵尸 / 子弹的 _ready）。

## 会发射子弹的那几只（其余用普通啃咬或自带特殊行为）
const C_SHOOT_ZOMBIE_TYPES: Array[CharacterRegistry.ZombieType] = [
	CharacterRegistry.ZombieType.Z035GatlingZombie,
	CharacterRegistry.ZombieType.Z036SnowPeaZombie,
	CharacterRegistry.ZombieType.Z040CabbagePultZombie,
	CharacterRegistry.ZombieType.Z041CobCannonZombie,
	CharacterRegistry.ZombieType.Z042MelonPultZombie,
	CharacterRegistry.ZombieType.Z043WinterMelonZombie,
]
## 恒定发射的那几只（原版口径：本体就是普通僵尸，照常走、照常啃，子弹只是附加项）
## 与上面那批的区别见 component_attack_zom_botany_pea.gd 的文件注释
const C_CONSTANT_SHOOT_ZOMBIE_TYPES: Array[CharacterRegistry.ZombieType] = [
	CharacterRegistry.ZombieType.Z031PeaShooterZombie,
]

var _failed := 0


func run(a) -> void:
	a.log("PROBE 植物僵尸 启动")
	_check_config(a)
	_check_scenes(a)
	a.log("")
	a.log("[ZOMBOTANY] result=%s failed=%d" % [("PASS" if _failed == 0 else "FAIL"), _failed])
	a.quit_game()


## 配置表自洽
func _check_config(a) -> void:
	_expect(a, "配置表里植物僵尸数量", ZomBotanyConfig.C_ZOM_BOTANY_INFO.size(), 14)
	for zombie_type in ZomBotanyConfig.C_ZOM_BOTANY_INFO:
		var info := ZomBotanyConfig.get_info(zombie_type)
		_expect(a, "配置 " + str(zombie_type) + " 的僵尸类型自洽", info.zombie_type, zombie_type)
		_expect(a, "配置 " + str(zombie_type) + " 有贴图", info.sprites.size() > 0, true)
		_expect(a, "配置 " + str(zombie_type) + " 植物耐久 > 0", info.plant_hp > 0, true)
		_expect(a, "配置 " + str(zombie_type) + " 出怪战力 > 0", info.power > 0, true)
		_expect(a, "配置 " + str(zombie_type) + " 出怪权重 > 0", info.weight > 0, true)
	_expect(a, "普僵不是植物僵尸", ZomBotanyConfig.is_zom_botany(CharacterRegistry.ZombieType.Z001Norm), false)
	_expect(a, "未知类型不是植物僵尸", ZomBotanyConfig.get_info(CharacterRegistry.ZombieType.Null), null)
	## 高坚果僵尸（原版 ZomBotany 2 专属，此前用南瓜僵尸顶替这个位置）
	_expect(a, "高坚果僵尸的头顶植物耐久",
		ZomBotanyConfig.get_info(CharacterRegistry.ZombieType.Z044TallNutZombie).plant_hp, 2200)
	## 窝瓜僵尸没有鸭子圈版本：行类型必须是陆地，否则泳池关水面行会刷出「没有鸭子圈却在水上走」的它
	_expect(a, "窝瓜僵尸只在陆地行",
		CharacterRegistry.ZombieInfo[CharacterRegistry.ZombieType.Z033SquashZombie][CharacterRegistry.ZombieInfoAttribute.ZombieRowType],
		CharacterRegistry.ZombieRowType.Land)


## 场景属性落地
func _check_scenes(a) -> void:
	for zombie_type in ZomBotanyConfig.C_ZOM_BOTANY_INFO:
		var info := ZomBotanyConfig.get_info(zombie_type)
		var scene: PackedScene = CharacterRegistry.ZombieInfo[zombie_type][CharacterRegistry.ZombieInfoAttribute.ZombieScenes]
		if scene == null:
			_failed += 1
			a.log("  FAIL 注册表里没有植物僵尸场景 " + str(zombie_type))
			continue
		var zombie: Zombie000Base = scene.instantiate()
		_expect(a, "场景 " + str(zombie_type) + " 的 zombie_type", zombie.zombie_type, zombie_type)
		var hp_component := zombie.get_node_or_null(^"HpComponent") as HpComponent
		if hp_component == null:
			_failed += 1
			a.log("  FAIL 植物僵尸 " + str(zombie_type) + " 没有 HpComponent")
			zombie.free()
			continue
		## 头顶植物的耐久挂在一类防具血量上，场景没写进去就变成「植物打不掉」
		_expect(a, "场景 " + str(zombie_type) + " 头顶植物耐久", hp_component.max_hp_armor1, info.plant_hp)
		var attack_component := zombie.get_node_or_null(^"AttackComponent")
		if zombie_type in C_SHOOT_ZOMBIE_TYPES:
			_expect(a, "场景 " + str(zombie_type) + " 用的是植物僵尸发射组件",
				attack_component is AttackComponentZomBotany, true)
			if zombie_type == CharacterRegistry.ZombieType.Z035GatlingZombie:
				_expect(a, "机枪僵尸一次 4 发", attack_component.burst_num, 4)
		if zombie_type in C_CONSTANT_SHOOT_ZOMBIE_TYPES:
			## 恒定发射 = 普通僵尸的啃咬 + 头顶植物一直开火，两个行为都不能少
			_expect(a, "场景 " + str(zombie_type) + " 用的是恒定发射组件",
				attack_component is AttackComponentZomBotanyPea, true)
			_expect(a, "场景 " + str(zombie_type) + " 仍然会啃植物",
				attack_component is AttackComponentZombieNorm, true)
			## 啃咬检测区必须是近身那一小块：撑成远程区的话僵尸会停在几百像素外啃空气
			var shape := attack_component.get_node_or_null(^"DetectComponent/Area2d/CollisionShape2D") as CollisionShape2D
			_expect(a, "场景 " + str(zombie_type) + " 啃咬检测区是近身范围",
				shape != null and shape.shape is RectangleShape2D and shape.shape.size.x < 100.0, true)
		if zombie_type in C_SHOOT_ZOMBIE_TYPES or zombie_type in C_CONSTANT_SHOOT_ZOMBIE_TYPES:
			## 发射点在场景里存的是 NodePath，节点头必须写 node_paths=PackedStringArray("markers_2d_bullet")：
			## 漏了这一句，实例化时会报 "Unable to convert array index 0 from NodePath to Object"，
			## 僵尸一进场就把关卡流程打断（zm_zombie_show_in_start.create_show_zombie）
			var markers: Array = attack_component.markers_2d_bullet
			_expect(a, "场景 " + str(zombie_type) + " 发射点已解析成 Marker2D",
				markers.size() > 0 and markers[0] is Marker2D, true)
		## 火炬僵尸：脚本用 %Area2DUpBullet 取节点，场景里必须勾「场景唯一名」
		## （漏了 unique_name_in_owner 的话，@onready 会报 Node not found 并让整个僵尸 null，
		##  一进场就把关卡流程打断 —— 见 zm_zombie_show_in_start.create_show_zombie）
		if zombie_type == CharacterRegistry.ZombieType.Z037TorchwoodZombie:
			var up_area := zombie.get_node_or_null(^"Area2DUpBullet") as Area2D
			_expect(a, "火炬僵尸有升级子弹的区域", up_area != null and up_area.collision_mask == 8, true)
			_expect(a, "火炬僵尸 Area2DUpBullet 已勾场景唯一名",
				up_area != null and up_area.unique_name_in_owner, true)
		zombie.free()


func _expect(a, name: String, got, want) -> void:
	if got == want:
		a.log("  OK   " + name + " = " + str(got))
	else:
		_failed += 1
		a.log("  FAIL " + name + " = " + str(got) + "（期望 " + str(want) + "）")
