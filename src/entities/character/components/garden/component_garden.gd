extends ComponentNormBase
class_name GardenComponent

## 禅境花园植物组件：成长 / 需求 / 产币。
##
## 口径对齐原版 `ZenGarden.cpp`（`PottedPlantUpdate` / `GetPlantsNeed` / `PlantWatered` /
## `PlantFertilized` / `PlantFulfillNeed` / `PlantUpdateProduction` / `PlantCanHaveChocolate`）：
##   · 4 个成长阶段（Sprout / Small / Medium / Full），**满级不再降级**；
##   · 需求按**真实时间戳**每帧算（原版是按 `mNowTime` 实时求值，不是会话内定时器）；
##   · 满级植物「今天被照顾过」才产币，产币间隔随「距上次满足需求的分钟数」放缓；
##   · 杀虫剂 / 留声机是**满级植物的日常维护**（原版 PlantFulfillNeed：掉金币），
##     不是 Large→Perfect 的成长步骤 —— 原来的第 5 阶 Large/Perfect 已删除。
##
## 时间戳一律是 **unix 秒**，存进 garden_data（键名见 get_curr_plant_data）。
## 关掉游戏这段时间的需求照旧会推进（与原版一致），跨自然日的判定用本地日期字符串。

## 植物身体
@onready var body: BodyCharacter = %Body
## 花园需求气泡
var garden_speech_bubble : GardenSpeehBubble
## 该植物下的花盆
var flower_pot:GardenFlowerPot
## 当前植物类型
var curr_plant_type : StringName = PlantIds.NULL
## 入手时定下的物种（原版 PottedPlant::mSeedType）：发芽期画的是通用幼苗，
## 但长大以后是哪一株在**入手那一刻**就定了，不再是发芽时随机摇
var curr_plant_species : StringName = PlantIds.NULL
## 是否为花园水族馆背景（动画变化）
var is_garden_aquarium := false
## 植物朝向x
var direction_x := 1.0
## 植物种植条件（默认为草地）
var curr_plant_condition:int = 2
## 当前花园背景种类(阳光房 / 蘑菇园 / 水族馆 / 智慧树),用于夜行植物需求判定
var curr_garden_bg_type: GardenManager.E_GardenBgType = GardenManager.E_GardenBgType.GreenHouse
## 该植物是否夜行(原版 Plant::IsNocturnal),夜行植物在阳光房里不需要照顾
var curr_plant_is_nocturnal := false

#region 原版常量（ZenGarden.cpp / PottedPlant）
## 浇过水后 15 秒内不会立刻再要水（原版 aTooLongSinceWatering = now - lastWatered > 15）
const WATER_INTERVAL := 15
## 同一株连续浇水的最小间隔（原版 aTooShortSinceWatering < 3）
const WATER_MIN_INTERVAL := 3
## "今天已照顾过"的兜底时长（原版 WasPlantNeedFulfilledToday: 1 小时内算今天）
const HAPPY_LASTS := 3600
## 施过肥 1 小时内不再要肥（原版 WasPlantFertilizedInLastHour）
const FERTILIZED_LASTS := 3600
## 喂一次巧克力的产币加速时长（原版 PlantHighOnChocolate < 300 秒）
const CHOCOLATE_TIME := 300
## 满级产币间隔：原版 mLaunchCounter 是帧，RandRangeInt(1800, counterMax)，
## counterMax 随"距上次满足需求的分钟数"从 3000(5 分钟) 线性涨到 15000(30 分钟)
const LAUNCH_COUNTER_MIN_FRAMES := 1800
const LAUNCH_COUNTER_MAX_FRAMES := 15000
const LAUNCH_COUNTER_SLOW_START_MINUTE := 5
const LAUNCH_COUNTER_SLOW_FULL_MINUTE := 30
## 原版喂巧克力时把 mLaunchCounter 直接设成 60 帧（约 1 秒后就产一枚）
const CHOCOLATE_LAUNCH_COUNTER := 1.0
#endregion

#region 植物状态属性
## 当前成长阶段
var curr_growth_stage := GardenManager.E_GrowthStage.Sprout
## 当前**算出来的**需求（原版 GetPlantsNeed 的返回值），只用于显示与判定，不落盘
var curr_need_item := GardenManager.E_NeedItem.Null
## 满级植物的"每日随机需求"（原版 PottedPlant::mPlantNeed：浇水时摇成杀虫剂 / 留声机）
var daily_need_item := GardenManager.E_NeedItem.Null
## 已浇水次数（原版 mTimesFed）
var times_fed := 0
## 长一阶需要浇几次水（原版 mFeedingsPerGrow，范围 [3,5]）
var feedings_per_grow := 5
## 四个时间戳（原版 mLastWateredTime / mLastNeedFulfilledTime / mLastFertilizedTime / mLastChocolateTime）
var last_watered_time := 0
var last_need_fulfilled_time := 0
var last_fertilized_time := 0
var last_chocolate_time := 0
## 距下一枚币的秒数（原版 mLaunchCounter 的秒制版本）
var launch_counter := 0.0
#endregion

## 当前植物格子,发芽成长时
var plant_cell_garden:PlantCellGarden
## 发芽成长信号,组件与植物根节点连接信号
signal signal_sprout_grow
## 上一帧的"开心发光"状态,避免每帧重设花盆粒子
var _is_happy_glow := false
## 盆口是否显示深色土（原版 SetImageOverride("Pot_top", ...)：WATERED / NEEDY / HAPPY 三态都是深色）
var _is_pot_top_dark := false


func component_ready() -> void:
	## 「场景里配了 is_enable_default = false 就禁用组件」由基类 ComponentNormBase._ready()
	## 负责，基类在里面调用本 component_ready()，这里不需要（也不许）自己调 super
	garden_speech_bubble = SceneRegistry.GARDEN_SPEECH_BUBBLE.instantiate()
	add_child(garden_speech_bubble)


#region 启用 / 禁用
func enable_component(is_enable_factor:E_IsEnableFactor):
	super(is_enable_factor)

func disable_component(is_enable_factor:E_IsEnableFactor):
	super(is_enable_factor)
	## 睡着 / 离开花园时不显示需求气泡（数据本身不清，醒来照旧）
	if is_instance_valid(garden_speech_bubble):
		garden_speech_bubble.change_plant_need_item(GardenManager.E_NeedItem.Null)
	## 睡着时盆口回到普通色（原版 NOTREADY）
	if is_instance_valid(flower_pot):
		flower_pot.plant_change_pot_top_dark(false)
#endregion


#region 初始化
## 初始化花园组件数据(ready之后)
func init_garden_component(garden_date_init:Dictionary):
	flower_pot = garden_date_init["flower_pot"]
	curr_plant_condition = garden_date_init["curr_plant_condition"]
	is_garden_aquarium = garden_date_init["curr_garden_bg_type"] == GardenManager.E_GardenBgType.Aquarium
	curr_garden_bg_type = garden_date_init["curr_garden_bg_type"]

	var garden_plant_data: Dictionary = garden_date_init["curr_garden_plant_data"]
	direction_x = float(garden_plant_data.get("direction_x", direction_x))
	## JSON 里没有整数:枚举 / 计数读回来是 float,直接赋给 int 变量会报类型错,这里一律 int()
	curr_plant_type = PlantIds.from_legacy(garden_plant_data.get("curr_plant_type", curr_plant_type))
	curr_plant_species = PlantIds.from_legacy(garden_plant_data.get("curr_plant_species", PlantIds.NULL))
	curr_plant_is_nocturnal = is_nocturnal_species(curr_plant_type) or is_nocturnal_species(curr_plant_species)

	## 旧枚举是 5 阶(多出 Large / Perfect),读档时并成原版的 4 阶
	var raw_growth_stage := int(garden_plant_data.get("curr_growth_stage", GardenManager.E_GrowthStage.Sprout))
	curr_growth_stage = _migrate_growth_stage(raw_growth_stage) as GardenManager.E_GrowthStage

	times_fed = int(garden_plant_data.get("times_fed", garden_plant_data.get("curr_water_time", 0)))
	feedings_per_grow = int(garden_plant_data.get(
		"feedings_per_grow", garden_plant_data.get("max_water_time", 0)))
	if feedings_per_grow <= 0:
		feedings_per_grow = randi_range(3, 5)
	daily_need_item = int(garden_plant_data.get(
		"daily_need_item", garden_plant_data.get("curr_need_item", GardenManager.E_NeedItem.Null))) \
		as GardenManager.E_NeedItem

	last_watered_time = int(garden_plant_data.get("last_watered_time", 0))
	last_need_fulfilled_time = int(garden_plant_data.get("last_need_fulfilled_time", 0))
	last_fertilized_time = int(garden_plant_data.get("last_fertilized_time", 0))
	last_chocolate_time = int(garden_plant_data.get("last_chocolate_time", 0))
	launch_counter = float(garden_plant_data.get("launch_counter", 0.0))

	## 老存档的"完美态"(旧枚举 4)迁移成满级:当成今天已照顾过,
	## 免得玩家的满级植物一读档就停产;旧的 Large(3)只并阶,不额外送开心
	if raw_growth_stage >= 4 and last_need_fulfilled_time == 0:
		last_need_fulfilled_time = get_now_time()

	_reset_timers_if_future()
	if launch_counter <= 0.0 and curr_growth_stage == GardenManager.E_GrowthStage.Full:
		set_launch_counter()
	update_growth_stage()
	_refresh_need_state()


## 旧 5 阶 → 原版 4 阶：Large(3) / Perfect(4) 都并到 Full
static func _migrate_growth_stage(raw_stage: int) -> int:
	return clampi(raw_stage, 0, GardenManager.E_GrowthStage.Full)


## 该物种是否夜行(原版 Plant::IsNocturnal)
static func is_nocturnal_species(species: StringName) -> bool:
	return PlantIds.NOCTURNAL.has(species)
#endregion


#region 每帧：需求求值 + 满级产币（原版 PottedPlantUpdate / PlantUpdateProduction）
func _process(delta: float) -> void:
	if not is_enabling:
		return
	_reset_timers_if_future()
	_refresh_need_state()
	## 原版只在 PLANTAGE_FULL && WasPlantNeedFulfilledToday 时递减产币计数
	if curr_growth_stage != GardenManager.E_GrowthStage.Full or not is_need_fulfilled_today():
		return
	launch_counter -= delta * (2.0 if is_high_on_chocolate() else 1.0)
	if launch_counter <= 0.0:
		set_launch_counter()
		_produce_coin()


## 重排下一次产币间隔（原版 PlantSetLaunchCounter）
func set_launch_counter() -> void:
	var minutes := get_minutes_since_happy()
	var ratio := clampf(
		(float(minutes) - LAUNCH_COUNTER_SLOW_START_MINUTE) \
			/ float(LAUNCH_COUNTER_SLOW_FULL_MINUTE - LAUNCH_COUNTER_SLOW_START_MINUTE),
		0.0, 1.0)
	var counter_max := lerpf(float(LAUNCH_COUNTER_MIN_FRAMES), float(LAUNCH_COUNTER_MAX_FRAMES), ratio)
	launch_counter = randf_range(float(LAUNCH_COUNTER_MIN_FRAMES), counter_max) / 60.0


## 产一枚币（原版 PlantUpdateProduction：默认银币，金/银按
## Rand(1000) + curve(距上次满足 5→30 分钟, 0→80) < 100 判定）
func _produce_coin() -> void:
	var minutes := get_minutes_since_happy()
	var ratio := clampf(
		(float(minutes) - LAUNCH_COUNTER_SLOW_START_MINUTE) \
			/ float(LAUNCH_COUNTER_SLOW_FULL_MINUTE - LAUNCH_COUNTER_SLOW_START_MINUTE),
		0.0, 1.0)
	var hit := randi_range(0, 999) + int(lerpf(0.0, 80.0, ratio))
	if hit < 100:
		_drop_coin([0.0, 1.0, 0.0])
	else:
		_drop_coin([1.0, 0.0, 0.0])


## 距上次满足需求的分钟数（原版 PlantGetMinutesSinceHappy：吃巧克力期间算 0）
func get_minutes_since_happy() -> int:
	if is_high_on_chocolate():
		return 0
	@warning_ignore("integer_division")
	return (get_now_time() - last_need_fulfilled_time) / 60
#endregion


#region 需求（原版 GetPlantsNeed 的移植）
## 当前这株植物需要什么（每帧算，不落盘）
func get_plants_need() -> GardenManager.E_NeedItem:
	## 原版:夜行植物在主花园且不是幼苗 -> 不需要任何照顾
	if curr_growth_stage != GardenManager.E_GrowthStage.Sprout \
			and curr_plant_is_nocturnal \
			and curr_garden_bg_type == GardenManager.E_GardenBgType.GreenHouse:
		return GardenManager.E_NeedItem.Null
	if was_fertilized_in_last_hour() or is_need_fulfilled_today():
		return GardenManager.E_NeedItem.Null

	var now := get_now_time()
	var too_long_since_watering := now - last_watered_time > WATER_INTERVAL
	var too_short_since_watering := now - last_watered_time < WATER_MIN_INTERVAL

	## 水生植物：满级走每日需求；非满级只在水族馆里要肥料（原版口径）
	if is_aquatic() and curr_growth_stage != GardenManager.E_GrowthStage.Sprout:
		if curr_growth_stage == GardenManager.E_GrowthStage.Full:
			if should_refresh_need():
				return GardenManager.E_NeedItem.Null
			return daily_need_item
		if curr_garden_bg_type != GardenManager.E_GardenBgType.Aquarium:
			return GardenManager.E_NeedItem.Null
		return GardenManager.E_NeedItem.Fertilizer

	if not too_long_since_watering:
		return GardenManager.E_NeedItem.Null
	if times_fed < feedings_per_grow:
		return GardenManager.E_NeedItem.WateringCan
	if too_short_since_watering:
		return GardenManager.E_NeedItem.Null
	if curr_growth_stage != GardenManager.E_GrowthStage.Full:
		return GardenManager.E_NeedItem.Fertilizer
	if should_refresh_need():
		return GardenManager.E_NeedItem.Null
	if daily_need_item != GardenManager.E_NeedItem.Null:
		return daily_need_item
	return GardenManager.E_NeedItem.WateringCan


## 今天是否已经被照顾过（原版 WasPlantNeedFulfilledToday）
func is_need_fulfilled_today() -> bool:
	var now := get_now_time()
	if now - last_need_fulfilled_time < HAPPY_LASTS:
		return true
	return get_day_key(now) <= get_day_key(last_need_fulfilled_time)


## 满级植物的每日需求是否该刷新了（原版 PlantShouldRefreshNeed：跨小时 + 跨自然日）
func should_refresh_need() -> bool:
	var now := get_now_time()
	if now - last_watered_time < HAPPY_LASTS:
		return false
	return get_day_key(now) > get_day_key(last_watered_time)


## 一小时内施过肥（原版 WasPlantFertilizedInLastHour）
func was_fertilized_in_last_hour() -> bool:
	return get_now_time() - last_fertilized_time < FERTILIZED_LASTS


## 是否处于巧克力"嗨"状态（原版 PlantHighOnChocolate：300 秒）
func is_high_on_chocolate() -> bool:
	return get_now_time() - last_chocolate_time < CHOCOLATE_TIME


## 现在能不能喂巧克力（原版 PlantCanHaveChocolate：满级 + 今天已照顾 + 当前不嗨）
func can_have_chocolate() -> bool:
	return curr_growth_stage == GardenManager.E_GrowthStage.Full \
		and is_need_fulfilled_today() \
		and not is_high_on_chocolate()


## 是不是水生植物（curr_plant_condition 的 bit1 = 陆地）
func is_aquatic() -> bool:
	return (curr_plant_condition & 2) == 0


## 刷新需求显示与"开心"发光：只在状态变化时才动节点
func _refresh_need_state() -> void:
	## init_garden_component 之前（场景刚实例化那一帧）还没有花盆 / 气泡
	if not is_instance_valid(garden_speech_bubble) or not is_instance_valid(flower_pot):
		return
	var new_need := get_plants_need()
	if new_need != curr_need_item:
		curr_need_item = new_need
		garden_speech_bubble.change_plant_need_item(curr_need_item)
	var is_happy := is_need_fulfilled_today()
	if is_happy != _is_happy_glow:
		_is_happy_glow = is_happy
		if is_instance_valid(flower_pot):
			flower_pot.plant_change_profect(is_happy)
	## 盆口深色：只有"要浇水"才是普通色，其余（刚浇过 / 有肥药留声机需求 / 今天已照顾）都是深色
	var is_dark_pot: bool = new_need != GardenManager.E_NeedItem.WateringCan
	if is_dark_pot != _is_pot_top_dark:
		_is_pot_top_dark = is_dark_pot
		if is_instance_valid(flower_pot):
			flower_pot.plant_change_pot_top_dark(is_dark_pot)


## 时钟被改到未来时把时间戳清掉（原版 PottedPlantUpdate 的 reset-on-future）
func _reset_timers_if_future() -> void:
	var now := get_now_time()
	if last_watered_time > now or last_need_fulfilled_time > now \
			or last_fertilized_time > now or last_chocolate_time > now:
		last_watered_time = 0
		last_need_fulfilled_time = 0
		last_fertilized_time = 0
		last_chocolate_time = 0


static func get_now_time() -> int:
	return int(Time.get_unix_time_from_system())


## 本地日期字符串（年-月-日），用于"跨自然日"判定
static func get_day_key(unix_time: int) -> String:
	return Time.get_datetime_string_from_unix_time(unix_time, true).substr(0, 10)
#endregion


#region 满足需求（原版 PlantWatered / PlantFertilized / PlantFulfillNeed）
## 满足当前需求
func satisfy_need(item: GardenManager.E_NeedItem):
	## 以「此刻真实需求」为准：道具不匹配什么也不做（原版 DoFeedingTool 的 aNeed == theToolType）
	var need := get_plants_need()
	if need == GardenManager.E_NeedItem.Null or item != need:
		return
	match need:
		GardenManager.E_NeedItem.WateringCan:
			plant_watered()
		GardenManager.E_NeedItem.Fertilizer:
			plant_fertilized()
		GardenManager.E_NeedItem.BugSpray, GardenManager.E_NeedItem.Phonograph:
			plant_fulfill_need()
	_refresh_need_state()


## 浇水（原版 PlantWatered）：掉 1 银币、浇水次数 +1；满级时顺带摇出每日需求
func plant_watered() -> void:
	times_fed += 1
	last_watered_time = get_now_time() - randi_range(0, 8)
	_drop_coin([1.0, 0.0, 0.0])
	if curr_growth_stage == GardenManager.E_GrowthStage.Full \
			and daily_need_item == GardenManager.E_NeedItem.Null:
		daily_need_item = [GardenManager.E_NeedItem.BugSpray,
			GardenManager.E_NeedItem.Phonograph].pick_random()
	SoundManager.play_other_SFX("plant_water")


## 施肥（原版 PlantFertilized）：长一阶 + 按新阶掉币（小 1 金 / 中 2 金 / 满级钻）
func plant_fertilized() -> void:
	last_fertilized_time = get_now_time()
	daily_need_item = GardenManager.E_NeedItem.Null
	times_fed = 0
	if curr_growth_stage < GardenManager.E_GrowthStage.Full:
		up_growth_stage()

	match curr_growth_stage:
		GardenManager.E_GrowthStage.Small:
			_drop_coin([0.0, 1.0, 0.0])
		GardenManager.E_GrowthStage.Medium:
			_drop_coin([0.0, 1.0, 0.0])
			_drop_coin([0.0, 1.0, 0.0])
		GardenManager.E_GrowthStage.Full:
			## 满级：金盏花 1 钻，其余 2 钻
			_drop_coin([0.0, 0.0, 1.0])
			if curr_plant_type != PlantIds.MARI_GOLD:
				_drop_coin([0.0, 0.0, 1.0])

	SoundManager.play_other_SFX("plant1")
	## 苗→小：原版会 RemovePottedPlant + PlacePottedPlant 换一株（换动画），
	## 本仓库由植物格子重建（signal_sprout_grow -> PlantCellGarden.sprout_up_new_plant）
	if curr_growth_stage == GardenManager.E_GrowthStage.Small:
		signal_sprout_grow.emit()
		return
	update_growth_stage()


## 满足满级植物的日常需求（原版 PlantFulfillNeed）：掉 1 金币，水生 / 夜行再 +2
func plant_fulfill_need() -> void:
	last_need_fulfilled_time = get_now_time()
	daily_need_item = GardenManager.E_NeedItem.Null
	times_fed = 0
	_drop_coin([0.0, 1.0, 0.0])
	if is_aquatic() or curr_plant_is_nocturnal:
		_drop_coin([0.0, 1.0, 0.0])
		_drop_coin([0.0, 1.0, 0.0])
	SoundManager.play_other_SFX("prize")


## 喂巧克力（原版 FeedChocolateToPlant）：进入"嗨"状态、产币间隔减半，
## 并把下一次产币压到约 1 秒后。不能喂时返回 false（调用方不要扣库存）
func feed_chocolate() -> bool:
	if not can_have_chocolate():
		return false
	last_chocolate_time = get_now_time()
	launch_counter = CHOCOLATE_LAUNCH_COUNTER
	SoundManager.play_other_SFX(&"wakeup")
	## 原版喂植物会放 PRESENT_PICKUP 粒子;这里用一次"弹一下"的缩放做近似反馈
	if body:
		var pop := create_tween()
		var target_scale := body.scale * 1.12
		pop.tween_property(body, "scale", target_scale, 0.08)
		pop.tween_property(body, "scale", body.scale, 0.18)
	return true


## 掉一枚钱（weights = [银, 金, 钻]）
func _drop_coin(weights: Array) -> void:
	EventBus.push_event(ConstEventName.CREATE_COIN, [weights, global_position + Vector2(0, -60)])
#endregion


#region 成长
## 更新外观：原版 DrawPottedPlant 的 Small 0.5 / Medium 0.75 / Full 1.0
func update_growth_stage():
	match curr_growth_stage:
		GardenManager.E_GrowthStage.Sprout:
			pass
		GardenManager.E_GrowthStage.Small:
			change_body_scale(Vector2(0.5 * direction_x, 0.5))
		GardenManager.E_GrowthStage.Medium:
			change_body_scale(Vector2(0.75 * direction_x, 0.75))
		GardenManager.E_GrowthStage.Full:
			change_body_scale(Vector2(1.0 * direction_x, 1.0))


## 成长状态升级
## 苗→小时把物种定下来：物种在**入手那一刻**就该定（原版 InitializePottedPlant 的 mSeedType），
## 老存档没有 curr_plant_species 时才兜底随机一次
func up_growth_stage():
	if curr_growth_stage >= GardenManager.E_GrowthStage.Full:
		return
	if curr_growth_stage == GardenManager.E_GrowthStage.Sprout:
		if curr_plant_species == PlantIds.NULL:
			curr_plant_species = Global.global_game_state.pick_random_garden_plant_species()
		curr_plant_type = curr_plant_species
		direction_x = [-1, 1].pick_random()
	curr_growth_stage = (curr_growth_stage + 1) as GardenManager.E_GrowthStage
	curr_plant_is_nocturnal = is_nocturnal_species(curr_plant_type) \
		or is_nocturnal_species(curr_plant_species)


## 改变植物大小
func change_body_scale(new_scale:Vector2):
	## 如果是原始大小，即初始化时，非生长变大
	if body.scale == Vector2(1,1) or body.scale == Vector2(-1,1):
		## 修改大小，影子位置不变
		body.scale = new_scale
	else:
		SoundManager.play_other_SFX("wakeup")
		var tween :Tween = create_tween()
		tween.tween_property(body, "scale", new_scale, 1)
#endregion


func get_curr_plant_data() -> Dictionary:
	return {
		"curr_plant_type": curr_plant_type,
		"curr_plant_species": curr_plant_species,
		"direction_x": direction_x,
		"curr_growth_stage": curr_growth_stage,
		"times_fed": times_fed,
		"feedings_per_grow": feedings_per_grow,
		"daily_need_item": daily_need_item,
		"last_watered_time": last_watered_time,
		"last_need_fulfilled_time": last_need_fulfilled_time,
		"last_fertilized_time": last_fertilized_time,
		"last_chocolate_time": last_chocolate_time,
		"launch_counter": launch_counter,
		"curr_plant_condition": curr_plant_condition,
	}
