extends RefCounted
## 探针：植物僵尸（原版 ZomBotany）的结构回归
##
## 为什么有这个探针：
##   植物僵尸是「一份配置表 + 一批只改属性的继承场景」生成的，
##   场景里任何一个节点索引 / 属性名写错（例如防具组件的 max_hp 写不进去），
##   在编辑器里看不出来，只有跑起来才发现「头顶植物没有耐久」或者「发射组件没挂上」。
##   这里锁死：配置自洽 + 场景属性能落地。
##
## 只做静态检查，不进关卡（不 add_child，不会触发僵尸 / 子弹的 _ready）。

## 会发射子弹的那几只（其余用普通啃咬或自带特殊行为）
const C_SHOOT_ZOMBIE_TYPES: Array[StringName] = [
	ZombieIds.GATLING_ZOMBIE,
	ZombieIds.SNOW_PEA_ZOMBIE,
	ZombieIds.CABBAGE_PULT_ZOMBIE,
	ZombieIds.COB_CANNON_ZOMBIE,
	ZombieIds.MELON_PULT_ZOMBIE,
	ZombieIds.WINTER_MELON_ZOMBIE,
]
## 恒定发射的那几只（原版口径：本体就是普通僵尸，照常走、照常啃，子弹只是附加项）
## 与上面那批的区别见 component_attack_zom_botany_pea.gd 的文件注释
const C_CONSTANT_SHOOT_ZOMBIE_TYPES: Array[StringName] = [
	ZombieIds.PEA_SHOOTER_ZOMBIE,
]

## 原版一代 6 只的总耐久（数据来源: PVZ Wiki 各僵尸条目，见 zom_botany_config.gd 文件头）：
## 总耐久 = 僵尸本体 270 + 头顶植物那层耐久，所以「植物头耐久」= 总耐久 − 270。
## 豌豆 / 窝瓜 / 机枪 的总耐久就是 270 —— 它们的植物头没有独立耐久（`plant_hp = 0`）。
const C_ORIGINAL_TOTAL_HP: Dictionary[StringName, int] = {
	ZombieIds.PEA_SHOOTER_ZOMBIE: 270,
	ZombieIds.WALL_NUT_ZOMBIE: 1370,
	ZombieIds.SQUASH_ZOMBIE: 270,
	ZombieIds.JALAPENO_ZOMBIE: 500,
	ZombieIds.GATLING_ZOMBIE: 270,
	ZombieIds.TALL_NUT_ZOMBIE: 2470,
}

## 原版 6 只的「首次允许波次」（`ZombieDefinition.mFirstAllowedWave`，1 起算）
const C_ORIGINAL_FIRST_WAVE: Dictionary[StringName, int] = {
	ZombieIds.PEA_SHOOTER_ZOMBIE: 1,
	ZombieIds.WALL_NUT_ZOMBIE: 1,
	ZombieIds.SQUASH_ZOMBIE: 10,
	ZombieIds.JALAPENO_ZOMBIE: 10,
	ZombieIds.GATLING_ZOMBIE: 10,
	ZombieIds.TALL_NUT_ZOMBIE: 10,
}

## 原版 ZomBotany 的两关（关卡脚本路径）：出怪 / 旗帜波规则与原版对齐的那两关
const C_ZOM_BOTANY_LEVEL_SCRIPTS: Array[String] = [
	"res://src/levels/mode_minigame/minigame_01_zom_botany.gd",
	"res://src/levels/mode_minigame/minigame_17_zom_botany_2.gd",
]

var _failed := 0


func run(a) -> void:
	a.log("PROBE 植物僵尸 启动")
	_check_config(a)
	_check_levels(a)
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
		## 植物头两种形态至少有一个：静态贴图（`sprites`）或带动画的头场景（`head_scene`）
		_expect(a, "配置 " + str(zombie_type) + " 有植物头",
			info.sprites.size() > 0 or info.head_scene != null, true)
		if info.head_scene != null:
			## 头场景是运行时 instantiate + play 的：少了播放器 / 少了 Head_Idle 只会静默变成静态图
			var head := info.head_scene.instantiate() as Node2D
			_expect(a, "配置 " + str(zombie_type) + " 的头场景有 " + str(ZombiePlantComponent.C_HEAD_IDLE_ANIM) + " 动画",
				_head_has_idle_anim(head), true)
			_expect(a, "配置 " + str(zombie_type) + " 的攻击动画有发射方法轨",
				_head_attack_has_shoot_track(head), true)
			## 动画头**复用植物自己的动画资源**（轨道路径仍是植物空间的 `Body/BodyCorrect/...`），
			## 头场景里少一个节点 / 少写 `root_node` 都只会刷 "Node not found" 而不是报错，
			## 表现是「植物的某个部件不动」——这里逐条轨道核对节点是否存在
			_expect(a, "配置 " + str(zombie_type) + " 的头场景里每条动画轨道都能解析到节点",
				_head_tracks_resolve(head), true)
			## 配了 head_body_path 就必须能找到（坚果 / 高坚果的受损裂纹换的是它）
			if not info.head_body_path.is_empty():
				_expect(a, "配置 " + str(zombie_type) + " 的动画头主体贴图节点存在",
					is_instance_valid(head) and head.get_node_or_null(info.head_body_path) is Sprite2D, true)
			if is_instance_valid(head):
				head.free()
		## 耐久可以是 0：原版豌豆 / 窝瓜 / 机枪僵尸的植物头没有独立耐久（见 C_ORIGINAL_TOTAL_HP）
		_expect(a, "配置 " + str(zombie_type) + " 植物耐久 >= 0", info.plant_hp >= 0, true)
		_expect(a, "配置 " + str(zombie_type) + " 出怪战力 > 0", info.power > 0, true)
		_expect(a, "配置 " + str(zombie_type) + " 出怪权重 > 0", info.weight > 0, true)
		## 原版 6 只：本体 + 植物头 必须正好等于 wiki 的总耐久（改了其中任一边都会在这里露出来）
		if C_ORIGINAL_TOTAL_HP.has(zombie_type):
			_expect(a, "配置 " + str(zombie_type) + " 总耐久 = 本体 + 植物头",
				ZomBotanyConfig.C_ZOMBIE_BODY_HP + info.plant_hp, C_ORIGINAL_TOTAL_HP[zombie_type])
	_expect(a, "普僵不是植物僵尸", ZomBotanyConfig.is_zom_botany(ZombieIds.NORM), false)
	_expect(a, "未知类型不是植物僵尸", ZomBotanyConfig.get_info(ZombieIds.NULL), null)
	## 高坚果僵尸（原版 ZomBotany 2 专属，此前用南瓜僵尸顶替这个位置）
	_expect(a, "高坚果僵尸的头顶植物耐久",
		ZomBotanyConfig.get_info(ZombieIds.TALL_NUT_ZOMBIE).plant_hp, 2200)
	## 窝瓜僵尸没有鸭子圈版本：行类型必须是陆地，否则泳池关水面行会刷出「没有鸭子圈却在水上走」的它
	_expect(a, "窝瓜僵尸只在陆地行",
		Global.character_registry.get_zombie_info(ZombieIds.SQUASH_ZOMBIE, CharacterRegistry.ZombieInfoAttribute.ZombieRowType),
		CharacterRegistry.ZombieRowType.Land)
	## 首次允许波次（原版 `ZombieDefinition.mFirstAllowedWave`，1 起算）：
	## 豌豆 / 坚果全程可出；窝瓜 / 辣椒 / 机枪 / 高坚果第 10 波起才进随机池
	for zombie_type in C_ORIGINAL_FIRST_WAVE:
		_expect(a, "配置 " + str(zombie_type) + " 首次允许波次",
			ZomBotanyConfig.get_info(zombie_type).first_allowed_wave, C_ORIGINAL_FIRST_WAVE[zombie_type])
	## 受损裂纹：只有坚果 / 高坚果有原版裂纹贴图（`WALLNUT_CRACKED1/2`、`TALLNUT_CRACKED1/2`）
	for zombie_type in [ZombieIds.WALL_NUT_ZOMBIE, ZombieIds.TALL_NUT_ZOMBIE]:
		_expect(a, "配置 " + str(zombie_type) + " 有 2 张裂纹贴图",
			ZomBotanyConfig.get_info(zombie_type).cracked_sprites.size(), 2)
		## 动画头的贴图由动画资源自己设，换裂纹只能按节点路径找主体贴图 —— 路径不能缺
		_expect(a, "配置 " + str(zombie_type) + " 的动画头有主体贴图节点路径",
			not ZomBotanyConfig.get_info(zombie_type).head_body_path.is_empty(), true)
	## 外观移植（2026-10-23）：原版 6 只全部改用动画头 ——
	## 直接播植物自己的 idle 动画（reanim 转出来的那套），不再用拼起来的静态 PNG；
	## 摆位照抄原版 `AttachReanim`（挂点轨道 = 图层），必须给出 attach 参数
	for zombie_type in C_ORIGINAL_TOTAL_HP:
		var info := ZomBotanyConfig.get_info(zombie_type)
		_expect(a, "原版 " + str(zombie_type) + " 用动画头（head_scene）", info.head_scene != null, true)
		_expect(a, "原版 " + str(zombie_type) + " 配了原版 attach 参数", info.attach != null, true)
	## 原版的挂点：这三只挂身体贴图 `Zombie_body`（跟身体走、画在身体之上）
	for zombie_type in [ZombieIds.WALL_NUT_ZOMBIE, ZombieIds.TALL_NUT_ZOMBIE, ZombieIds.JALAPENO_ZOMBIE]:
		var info := ZomBotanyConfig.get_info(zombie_type)
		_expect(a, "原版 " + str(zombie_type) + " 挂 Zombie_body 轨道",
			info.attach != null and info.attach.to_body, true)
	## 其余三只挂僵尸头 `Anim_head1`（跟着摇头 / 点头）
	for zombie_type in [ZombieIds.PEA_SHOOTER_ZOMBIE, ZombieIds.SQUASH_ZOMBIE, ZombieIds.GATLING_ZOMBIE]:
		var info := ZomBotanyConfig.get_info(zombie_type)
		_expect(a, "原版 " + str(zombie_type) + " 挂 Anim_head1 轨道",
			info.attach != null and not info.attach.to_body, true)
	## 原版对这三只 `ReanimShowPrefix("Zombie_tie", RENDER_GROUP_HIDDEN)`：整颗植物替换了头，领带会露出来
	for zombie_type in [ZombieIds.WALL_NUT_ZOMBIE, ZombieIds.TALL_NUT_ZOMBIE, ZombieIds.JALAPENO_ZOMBIE]:
		_expect(a, "原版 " + str(zombie_type) + " 藏掉领带",
			ZomBotanyConfig.get_info(zombie_type).hide_tie, true)
	## 窝瓜僵尸的移速倍率（原版 0.79~0.81 vs 普僵均值 0.3 ≈ 2.6 倍）
	_expect(a, "窝瓜僵尸移速倍率下限 > 2", Zombie033Squash.C_SPEED_FACTOR_RANGE.x > 2.0, true)


## 两关的关卡参数：原版 `Board::InitZombieWaves` 对 `WAR_AND_PEAS` / `WAR_AND_PEAS_2` 特判 ——
## 两关整关只出植物僵尸，旗帜波既不补旗子僵尸也不补普僵（点数残差同样不补）。
## 关 2 的出怪表里多写一个 `ZombieIds.NORM` 就等于把这条开关绕过去了，所以两处都要锁。
func _check_levels(a) -> void:
	for path in C_ZOM_BOTANY_LEVEL_SCRIPTS:
		var level_script := load(path) as GDScript
		if level_script == null:
			_failed += 1
			a.log("  FAIL 找不到关卡脚本 " + path)
			continue
		var level = level_script.new()
		_expect(a, path.get_file() + " 旗帜波不补普僵 / 旗子僵尸", level.spawn_plain_zombie_extra, false)
		## 出怪倍率：原版 `Board::PickZombieWaves()` 对 WAR_AND_PEAS / _2 不乘任何倍率，
		## 写成 >1 就是「每波出怪数是原版的 N 倍」（2026-10-24 用户反馈「植物僵尸明显过多」就是这里曾是 10）
		_expect(a, path.get_file() + " 出怪倍率（原版无倍率）", level.zombie_multy, 1)


## 场景属性落地
func _check_scenes(a) -> void:
	for zombie_type in ZomBotanyConfig.C_ZOM_BOTANY_INFO:
		var info := ZomBotanyConfig.get_info(zombie_type)
		var scene: PackedScene = Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieScenes)
		if scene == null:
			_failed += 1
			a.log("  FAIL 注册表里没有植物僵尸场景 " + str(zombie_type))
			continue
		var zombie: Zombie000Base = scene.instantiate()
		_expect(a, "场景 " + str(zombie_type) + " 的 zombie_type", zombie.zombie_type, zombie_type)
		## 换头组件挂在 `Body/BodyCorrect/Anim_head/Anim_head1`（僵尸自己的头）下面：
		## 场景结构（继承的 base 或部件改名）一动，这条路径就没了 —— 而它失效的表现是
		## 「僵尸顶着一颗没被替换的人头」，静态检查查不出来，所以在这里钉住
		_expect(a, "场景 " + str(zombie_type) + " 有可被替换的僵尸头节点",
			zombie.get_node_or_null(^"Body/BodyCorrect/Anim_head/Anim_head1") is Sprite2D, true)
		## 死亡掉落的头也要换成植物头（`ZombiePlantComponent._replace_drop_head()`）：
		## 这条路径没了只会静默掉普僵头，不报错，所以在这里盯住
		_expect(a, "场景 " + str(zombie_type) + " 有可替换的掉头节点",
			zombie.get_node_or_null(^"Body/NodeDrop/Node2D_Head_Drop/Head_Drop") is Node2D, true)
		if zombie.get_node_or_null(^"HpComponent") == null:
			_failed += 1
			a.log("  FAIL 植物僵尸 " + str(zombie_type) + " 没有 HpComponent")
			zombie.free()
			continue
		## 头顶植物的耐久 = 挂在同一角色下那件 `ArmorComponentPlantHead` 的血量
		## （防具改成组件之后不再是 HpComponent 上的一个数字），场景漏配就变成「植物打不掉」
		var head_armor: ArmorComponent = null
		for child in zombie.get_children():
			if child is ArmorComponent and child.armor_type == ConstArmor.E_ArmorType.PlantHead:
				head_armor = child
				break
		if head_armor == null:
			_failed += 1
			a.log("  FAIL 植物僵尸 " + str(zombie_type) + " 没有 PlantHead 防具组件")
		else:
			_expect(a, "场景 " + str(zombie_type) + " 头顶植物耐久", head_armor.max_hp, info.plant_hp)
		var attack_component := zombie.get_node_or_null(^"AttackComponent")
		if zombie_type in C_SHOOT_ZOMBIE_TYPES:
			_expect(a, "场景 " + str(zombie_type) + " 用的是植物僵尸发射组件",
				attack_component is AttackComponentZomBotany, true)
			if zombie_type == ZombieIds.GATLING_ZOMBIE:
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
		if zombie_type == ZombieIds.TORCHWOOD_ZOMBIE:
			var up_area := zombie.get_node_or_null(^"Area2DUpBullet") as Area2D
			_expect(a, "火炬僵尸有升级子弹的区域", up_area != null and up_area.collision_mask == 8, true)
			_expect(a, "火炬僵尸 Area2DUpBullet 已勾场景唯一名",
				up_area != null and up_area.unique_name_in_owner, true)
		zombie.free()


## 动画版植物头场景：根下要有 AnimationPlayer，且里面有 Head_Idle
func _head_has_idle_anim(head: Node2D) -> bool:
	if not is_instance_valid(head):
		return false
	var anim_player := head.get_node_or_null(ZombiePlantComponent.C_HEAD_ANIM_PLAYER_NAME) as AnimationPlayer
	if not is_instance_valid(anim_player):
		return false
	return anim_player.has_animation(ZombiePlantComponent.C_HEAD_IDLE_ANIM)


## 动画版植物头的攻击动画：库里配了 `Head_Attack` 就必须有一条调 `_shoot_bullet` 的方法轨 ——
## 豌豆就是靠那条轨在「吐出」那一帧发出去的，删了它只会变成「只演动画、不发子弹」。
## 没配 `Head_Attack` 的头（原版其余 5 只只搬了 idle，发射仍是冷却到点直接发）视为通过。
func _head_attack_has_shoot_track(head: Node2D) -> bool:
	if not is_instance_valid(head):
		return false
	var anim_player := head.get_node_or_null(ZombiePlantComponent.C_HEAD_ANIM_PLAYER_NAME) as AnimationPlayer
	if not is_instance_valid(anim_player) or not anim_player.has_animation(ZombiePlantComponent.C_HEAD_ATTACK_ANIM):
		return true
	var anim := anim_player.get_animation(ZombiePlantComponent.C_HEAD_ATTACK_ANIM)
	for track in anim.get_track_count():
		if anim.track_get_type(track) != Animation.TYPE_METHOD:
			continue
		## `method_track_get_name()` 要 (轨道, 关键帧) 两个下标
		for key in anim.track_get_key_count(track):
			if anim.method_track_get_name(track, key) == ZombiePlantComponent.C_HEAD_SHOOT_METHOD:
				return true
	return false


## 头场景里的每条动画轨道都要能在场景里解析到节点：
## 动画头复用植物场景的动画资源，轨道路径写的是植物空间（`Body/BodyCorrect/...`），
## 解析起点是 `AnimationPlayer.root_node`（头场景里没写，默认 `..` = 场景根 `PlantHead`）——
## 少一个部件节点 / 改错 `root_node` 都只会刷 Node not found，表现是「某个部件不动」
func _head_tracks_resolve(head: Node2D) -> bool:
	if not is_instance_valid(head):
		return false
	var anim_player := head.get_node_or_null(ZombiePlantComponent.C_HEAD_ANIM_PLAYER_NAME) as AnimationPlayer
	if not is_instance_valid(anim_player):
		return false
	## `root_node` 是相对播放器本身的路径（默认 ".." = 它的父节点）
	var track_root := anim_player.get_node_or_null(anim_player.root_node)
	if track_root == null:
		return false
	for anim_name in anim_player.get_animation_list():
		var anim := anim_player.get_animation(anim_name)
		for track in anim.get_track_count():
			## 方法轨是**故意**指到植物场景里的 `AttackComponent` 的（头挂到僵尸身上后由
			## `_bind_head_attack_shoot_track()` 在运行期重定向），这里不参与「节点是否存在」的判断
			if anim.track_get_type(track) == Animation.TYPE_METHOD:
				continue
			var path := anim.track_get_path(track)
			## 轨道可能是 `节点:属性` 或 `节点:属性:子分量`，只取节点部分
			var node_part := str(path).get_slice(":", 0)
			if node_part.is_empty():
				continue
			if track_root.get_node_or_null(NodePath(node_part)) == null:
				return false
	return true


func _expect(a, name: String, got, want) -> void:
	if got == want:
		a.log("  OK   " + name + " = " + str(got))
	else:
		_failed += 1
		a.log("  FAIL " + name + " = " + str(got) + "（期望 " + str(want) + "）")
