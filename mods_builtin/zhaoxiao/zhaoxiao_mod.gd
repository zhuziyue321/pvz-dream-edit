extends "../mod_base.gd"
## 模组「招笑版」：只改**向日葵**、**豌豆射手**与**樱桃炸弹**三只植物（都是原版没有的，所以做成模组）
##
## ★ 向日葵（改名 + 产阳光时的集体转头与流汗），四件事：
##   1. **改名**：向日葵 → 「朝阳葵」。名字来自图鉴数据里那一条的「名字」字段
##      （图鉴页 / 商店卡的说明 / 「获得新植物」提示都读它），所以改这一处就全改了；
##      **不改**那一行的键（键 = 注册表里的 `PlantName`，图鉴页是拿它去查表的）。
##   2. **集体转头**：任何一株朝阳葵产阳光时，场上**其余**朝阳葵一起转头看向它。
##      **只转头** —— 花茎和叶子不动，转的只有花瓣与脸那几张贴图；口径见 `zhaoxiao_sunflower.gd`。
##   3. **流汗**：产光那一株的花心上挂一颗汗滴贴图（借的正是本体禅境花园那颗「缺水」水珠），
##      **纯贴图、不做动画**。
##   4. 转头与流汗都是**持续**的：转到目标方向就停在那儿，汗滴贴上就一直挂着；直到下一株产阳光时，
##      全体改看新的那株，旧的停止流汗。
##
## ★ 豌豆射手 → 「傻豆射手」（改名 + 打傻豆攒怒气 + 满怒放大招），四件事：
##   1. **改名**：豌豆射手 → 「傻豆射手」（与向日葵同一套：只改图鉴那一条的「名字」字段）。
##   2. **普通攻击改成打傻豆**：本体射击组件每次要出弹时，观察者替它造一颗**傻豆** ——
##      两种随机，且**没有碰撞箱、不造成伤害**（就是图一乐）；见 `zhaoxiao_shadou.gd`。
##   3. **攒怒气**：每打一颗傻豆攒一点，**怒气把整株慢慢染红**。
##   4. **满怒放大招**：怒气**匀速**降下去，这段时间里朝正前方 ±一定角度、以随机速度
##      散射**普通豌豆**（真子弹，会打伤害）；见 `zhaoxiao_peashooter.gd`。
##
## ★ 樱桃炸弹 → 「烟熏樱桃」（改名 + 改成上烟熏、不再炸血），三件事：
##   1. **改名**：樱桃炸弹 → 「烟熏樱桃」（与另两只同一套：只改图鉴那一条的「名字」字段）。
##   2. **不造成伤害**：炸弹组件的伤害压成 0（爆炸表现 / 音效照旧，一滴血不掉）。
##   3. **范围内的僵尸吃 30 秒烟熏**：爆炸那一下按**同一个爆炸框**找僵尸，逐个挂状态节点
##      （状态挂在僵尸身上 —— 樱桃炸弹爆完当场就死，挂在它身上会跟着没）；见
##      `zhaoxiao_cherry.gd` 与 `zhaoxiao_smoke.gd`。
##      烟熏的两条效果：**遇到植物就站着不啃**（伤害压 0 + 动画换成待机站姿）、
##      **被同类索敌**（把它标成「谁都能打它」`Character000Base.is_enemy_to_all_camps` ——
##      只改「能不能被打」，归属阵营不变 ⇒ 玩家的植物照旧打得中它）。
##
## ★ 怎么装：本体场景里没有本模组任何节点，全靠现场挂 ——
##   每局 `install_to_main_game()` 遍历格子，给已经种着的两种植物各挂一个观察者节点，
##   并接上格子的 `signal_plant_create`，后种的（含读档 / 传送带补种）种下即挂。
##   观察者是宿主植物的子节点，植物没了它跟着没，不必自己清理。
##
## ★ 只在战斗里发生：观察者是在主游戏里挂的，禅境花园 / 图鉴那份植物不会被挂上。
##
## 装载时机与写法见 [模组机制](../../docs/参考存档/模组机制.md)：
##   开关在 `user://<用户名>/mod_config.ini` 的 `[zhaoxiao]` 段，默认关闭。

## 跨文件引用：`user://` 下脚本的 class_name **不会注册成全局类**（实测 Godot 4.6.2），
## 上级目录与同目录的文件一律 preload 成常量再引用，不能写 `extends ModBase`
const ModBase := preload("../mod_base.gd")
const Settings := preload("zhaoxiao_settings.gd")
const SunflowerWatcher := preload("zhaoxiao_sunflower.gd")
const PeashooterWatcher := preload("zhaoxiao_peashooter.gd")
const CherryWatcher := preload("zhaoxiao_cherry.gd")

## 改过名的植物：图鉴 `Plant` 段的**键** → 原来的名字（关掉模组时按它还原）
var _original_names := {}


func get_mod_id() -> StringName:
	return ModIds.ZHAOXIAO


func get_mod_name() -> String:
	return "招笑版"


func get_mod_description() -> String:
	return "向日葵改叫「朝阳葵」（产阳光时全体转头看它、它自己流汗）；豌豆射手改叫「傻豆射手」" \
		+ "（打出去的是不伤害人的傻豆，攒满怒气就把整株憋红、散射一堆普通豌豆）；" \
		+ "樱桃炸弹改叫「烟熏樱桃」（不炸掉血，改成给范围内的僵尸上 30 秒烟熏）"


## 模组页面右侧：它改了什么、口径是什么
func create_detail_control() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(ModBase.create_detail_label(
		"【向日葵 → %s】任何一株产阳光时，其余朝阳葵一起转头看它，它自己持续流汗"
			% Settings.PLANT_NAME_NEW))
	box.add_child(ModBase.create_detail_label(
		"只转头：花茎和叶子不动，转的只有花瓣与脸；目标在左边就把花头镜像过去，再转到「右侧对准目标」"))
	box.add_child(ModBase.create_detail_label(
		"转一次头花的时间所有朝阳葵都一样（%.2f 秒，按时长插值而不是角速度），所以同一批被叫到的花一起转完"
			% Settings.TURN_TIME))
	box.add_child(ModBase.create_detail_label(
		"都是持续的：转到目标方向就停在那儿、汗滴贴上就一直挂着；直到下一株产阳光时全体改看新的那株，旧的停止流汗"))
	box.add_child(ModBase.create_detail_label(
		"汗滴是**纯贴图、不做动画**（就是花心上挂一颗本体禅境花园的「缺水」水珠）—— 只借贴图，本体一个字都没为它改"))
	box.add_child(ModBase.create_detail_label(
		"【豌豆射手 → %s】普通攻击打出去的是**傻豆**：看着像正常豌豆，其实**没有碰撞箱、不造成伤害**"
			% Settings.PEASHOOTER_NAME_NEW))
	box.add_child(ModBase.create_detail_label(
		"傻豆两种随机：一种飞到**僵尸前面就掉到地上**（落地那一下原地播本体的「豌豆命中」特效，"
		+ "然后这颗傻豆消失），一种**射偏** —— 方向是照僵尸受击框算出来的，"
		+ "**恰好**擦着头顶 / 贴着脚底过去，想打中都打不中"))
	box.add_child(ModBase.create_detail_label(
		"每打一颗傻豆攒 %.2f 怒气（满 %d 颗），怒气把整株**慢慢染红**；满了放大招：怒气 %.1f 秒内**匀速**降到 0，"
			% [Settings.ANGER_PER_SHOT, int(Settings.ANGER_MAX / Settings.ANGER_PER_SHOT),
				Settings.ULTIMATE_TIME]))
	box.add_child(ModBase.create_detail_label(
		"大招期间朝正前方 ±%.0f 度、以 %.0f~%.0f 的随机速度散射**普通豌豆**（真子弹，会打伤害）；这段时间不再打傻豆"
			% [Settings.ULTIMATE_ANGLE_DEG, Settings.ULTIMATE_SPEED_RANGE.x,
				Settings.ULTIMATE_SPEED_RANGE.y]))
	box.add_child(ModBase.create_detail_label(
		"【樱桃炸弹 → %s】爆炸**一点伤害都不造成**（炸弹伤害压成 0，爆炸表现 / 音效照旧），"
			% Settings.CHERRY_NAME_NEW
		+ "改成给爆炸范围内的僵尸上 %.0f 秒**烟熏**" % Settings.SMOKE_TIME))
	box.add_child(ModBase.create_detail_label(
		"烟熏的僵尸**遇到植物就站着不啃**：伤害压成 0，动画从「啃」换成**待机站姿**（就是选卡界面那种站法）；"
		+ "植物没了就自己走回去，全程不啃掉一滴血"))
	box.add_child(ModBase.create_detail_label(
		"烟熏的僵尸会被**同类索敌**：模组把它标成「谁都能打它」（本体的通用口子），"
		+ "别的僵尸于是会走过来啃它；而它自己的归属阵营不变，玩家的植物照旧打得中它"))
	box.add_child(ModBase.create_detail_label(
		"只在战斗里发生：禅境花园 / 图鉴里的植物不参与（本模组只在主游戏里挂观察者）"))
	box.add_child(ModBase.create_detail_label(
		"关掉本模组：名字还回去，下一局不再挂任何节点，回到原版"))
	return box


#region 生命周期
func install() -> void:
	_rename_plant(Settings.ALMANAC_KEY, Settings.PLANT_NAME_NEW)
	_rename_plant(Settings.PEASHOOTER_ALMANAC_KEY, Settings.PEASHOOTER_NAME_NEW)
	_rename_plant(Settings.CHERRY_ALMANAC_KEY, Settings.CHERRY_NAME_NEW)


func uninstall() -> void:
	_restore_names()


## 每局装一次：给场上已种着的两种植物补挂观察者，并接上「以后再种」那条信号
func install_to_main_game(main_game: MainGameManager) -> void:
	if main_game == null or main_game.plant_cell_manager == null:
		Log.error("招笑版模组：主游戏缺少格子管理器，本局不安装")
		return
	for row in main_game.plant_cell_manager.all_plant_cells:
		for cell: PlantCell in row:
			if cell == null:
				continue
			if not cell.signal_plant_create.is_connected(_on_plant_create):
				cell.signal_plant_create.connect(_on_plant_create)
			## 先扫一遍：关卡预置 / 读档开局的植物不会再有 signal_plant_create
			_attach_to_cell(cell)
#endregion


#region 改名（图鉴数据里那一条的「名字」）
## 把图鉴里某个植物那一条的「名字」改成新名字
##
## 为什么不改注册表的 `PlantName`：图鉴页是拿 `PlantName` 当**键**去查 `Plant` 段的
## （`data_almanac["Plant"][plant_name]`），键一改就查不到那一条。改的只是那一行里的
## 「名字」字段，键原样不动，界面到处都读这一处，于是全部跟着变。
## 关掉模组时按 `_original_names` 还原 —— 只改内存里的字典，`data/` 里那个 json 不动。
func _rename_plant(almanac_key: String, new_name: String) -> void:
	var entry := _almanac_plant_entry(almanac_key)
	if entry.is_empty():
		Log.warn("招笑版模组：图鉴里找不到 [%s] 那一条，改名跳过" % almanac_key)
		return
	if not _original_names.has(almanac_key):
		_original_names[almanac_key] = String(entry.get("名字", ""))
	entry["名字"] = new_name
	Log.info("招笑版模组：%s 改名 → %s" % [almanac_key, new_name])


## 关掉模组：名字都还回去
func _restore_names() -> void:
	for almanac_key in _original_names:
		var entry := _almanac_plant_entry(String(almanac_key))
		if not entry.is_empty():
			entry["名字"] = _original_names[almanac_key]
	_original_names.clear()


## 图鉴 `Plant` 段里某个植物那一条（一个**引用**：就地在上面写字段，等于改掉读数据源）
func _almanac_plant_entry(almanac_key: String) -> Dictionary:
	var read_data := Global.global_read_data
	read_data.ensure_almanac_loaded()
	var all_plant_data: Dictionary = read_data.data_almanac.get("Plant", {})
	var entry: Dictionary = all_plant_data.get(almanac_key, {})
	return entry
#endregion


#region 挂观察者
## 格子种下了东西：是这两只之一就挂对应观察者
func _on_plant_create(cell: PlantCell, plant_type: StringName) -> void:
	match plant_type:
		PlantIds.SUN_FLOWER:
			_attach_to_cell(cell)
		PlantIds.PEA_SHOOTER_SINGLE:
			_attach_to_cell(cell)
		PlantIds.CHERRY_BOMB:
			_attach_to_cell(cell)


func _attach_to_cell(cell: PlantCell) -> void:
	_attach_to_plant(cell.get_plant(CharacterRegistry.PlacePlantInCell.Norm))


## 给一株植物挂它该有的观察者（不是本模组管的这几只 / 实例已释放 → 什么都不做）
func _attach_to_plant(plant: Plant000Base) -> void:
	if not is_instance_valid(plant):
		return
	match plant.plant_type:
		PlantIds.SUN_FLOWER:
			_attach_sunflower(plant)
		PlantIds.PEA_SHOOTER_SINGLE:
			_attach_peashooter(plant)
		PlantIds.CHERRY_BOMB:
			_attach_cherry(plant)


## 挂朝阳葵观察者（已经挂过 → 什么都不做）
func _attach_sunflower(plant: Plant000Base) -> void:
	if plant.get_node_or_null(SunflowerWatcher.NODE_PATH) != null:
		return
	var watcher: Node = SunflowerWatcher.new()
	watcher.name = SunflowerWatcher.NODE_NAME
	plant.add_child(watcher)


## 挂傻豆射手观察者（已经挂过 → 什么都不做）
func _attach_peashooter(plant: Plant000Base) -> void:
	if plant.get_node_or_null(PeashooterWatcher.NODE_PATH) != null:
		return
	var watcher: Node = PeashooterWatcher.new()
	watcher.name = PeashooterWatcher.NODE_NAME
	plant.add_child(watcher)


## 挂烟熏樱桃观察者（已经挂过 → 什么都不做）
func _attach_cherry(plant: Plant000Base) -> void:
	if plant.get_node_or_null(CherryWatcher.NODE_PATH) != null:
		return
	var watcher: Node = CherryWatcher.new()
	watcher.name = CherryWatcher.NODE_NAME
	plant.add_child(watcher)
#endregion
