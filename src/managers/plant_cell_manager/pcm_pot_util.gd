class_name PcmPotUtil
## 砸罐子关的「罐子生成」：从 PlantCellManager 里抽出来的纯逻辑
## （见 docs/参考存档/重构拆分方案.md 的 B6）
##
## 为什么单独放一个文件：
##   罐子这一块（固定数量模式 / 戴夫提示罐 / 候选格子筛选）占了管理器近一半行数，
##   但它只关心「往哪些格子上摆什么罐子」，和格子管理器的网格职责没有交集，
##   抽走后管理器里只剩 init_pot / cerate_pot / clear_all_pot 三个转发。
##
## 约定：
##   · 全部 static，不持有状态：本批罐子列表、候选格子分组
##     都还留在 PlantCellManager 上（对外还有人在读 curr_pot_num），这里只管怎么算、怎么摆
##   · 需要改管理器自身字段时一律显式传 pcm 进来，不用 get_parent()
##   · 不做成子管理器节点：罐子逻辑不是一条独立生命周期，做成 static 不需要动 .tscn
##
## 罐子只有一种生成模式：
##   Fixd 固定模式：关卡配置里写死"几个僵尸罐、几个植物罐、几个随机罐"，按数量摆完为止
##   （Fixd 是原配置里的拼写，不是笔误，别顺手改掉——改了要连带改 ResourceLevelData 的枚举）
## 早期还有一套 Weight 权重模式（每个格子独立按权重掷一次），没有关卡在用，
## 已随 E_PotMode.Weight 一起删掉（见 docs/工作记录/2026-10-04_清理提前上浮的死字段与空骨架.md）

#region 对外入口

## 罐子初始化：按关卡模式准备候选格子分组
static func init_pot(pcm: PlantCellManager) -> void:
	pcm.is_pot_mode = pcm.game_para.is_pot_mode
	if pcm.game_para.pot_mode == ConstLevelData.E_PotMode.Fixd:
		init_plant_cell_row_on_zombie_row_type(pcm)

## 摆一批罐子（多轮砸罐子关每轮都会调一次）
static func cerate_pot(pcm: PlantCellManager) -> void:
	pcm.curr_round_pots.clear()
	if pcm.game_para.pot_mode == ConstLevelData.E_PotMode.Fixd:
		create_all_pot_on_fixed_mode(pcm)
	create_pot_hint(pcm)

## 清除场上所有还没砸开的罐子（切换批次时兜底：正常流程罐子已经被砸光了）
static func clear_all_pot(pcm: PlantCellManager) -> void:
	for plant_cell_lane in pcm.all_plant_cells:
		for plant_cell: PlantCell in plant_cell_lane:
			if is_instance_valid(plant_cell.pot):
				plant_cell.pot.queue_free()
				plant_cell.pot = null
				plant_cell.open_pot_update_plant_cell_data()
	pcm.curr_pot_num = 0

#endregion


#region 候选格子

## 把罐子要用到的植物格子按僵尸行类型（陆 / 水）分组
## 多轮砸罐子关每批罐子的列数不一样（原版冒险 4-5：3 列 → 4 列 → 5 列），
## 每轮摆罐子前都会重新调一次，所以开头必须先清空，不清空会越攒越多
static func init_plant_cell_row_on_zombie_row_type(pcm: PlantCellManager) -> void:
	for zombie_row_type in pcm.plant_cell_row_on_zombie_row_type:
		pcm.plant_cell_row_on_zombie_row_type[zombie_row_type].clear()
	if pcm.game_para.pot_col_range.y > pcm.row_col.y:
		pcm.game_para.pot_col_range.y = pcm.row_col.y
		Log.debug("warning:生成罐子的结束列数大于当前场景植物格子的列数，生成罐子的结束列数已修改为植物格子列数")
	## 罐子需要的列
	var need_col: int = pcm.game_para.pot_col_range.y - pcm.game_para.pot_col_range.x
	var num_pot_candidate: int = need_col * pcm.row_col.x
	Log.debug(str("设置罐子的列数：") + str(need_col) + str(" 罐子生成位置数量为：") + str(num_pot_candidate))

	if need_col == 0:
		Log.debug("warning: 罐子列数为0，取消生成罐子")
		return

	if pcm.game_para.pot_mode == ConstLevelData.E_PotMode.Fixd:
		Log.debug(str("罐子生成模式为 固定数量生成模式， 罐子生成总数为：") + str(pcm.game_para.pot_num_on_fixed_mode))
		assert(
			pcm.game_para.pot_num_on_fixed_mode <= num_pot_candidate,
			"罐子需求总数为：" + str(pcm.game_para.pot_num_on_fixed_mode)
			+ "生成罐子候选植物格子数量为：" + str(num_pot_candidate)
		)

	for i in range(pcm.all_plant_cells.size()):
		var plant_cell_row: Array = pcm.all_plant_cells[i]
		## 用 has() 兜底：ZombieRowType 以后新增取值（例如 Both）时不会因为字典缺键而报错
		var zombie_row_type: CharacterRegistry.ZombieRowType = \
			Global.main_game.zombie_manager.all_zombie_rows[i].zombie_row_type
		if not pcm.plant_cell_row_on_zombie_row_type.has(zombie_row_type):
			pcm.plant_cell_row_on_zombie_row_type[zombie_row_type] = []
		pcm.plant_cell_row_on_zombie_row_type[zombie_row_type].append_array(
			plant_cell_row.slice(pcm.game_para.pot_col_range.x, pcm.game_para.pot_col_range.y)
		)

## 筛掉不能摆罐子的格子：已经种了植物、或者已经摆了一个罐子的格子跳过。
## 多轮砸罐子关（原版冒险 4-5）必须这么做：上一批罐子里开出的植物还留在草坪上，
## 戴夫只能把新的一批罐子摆在空格子上。
static func filter_can_create_pot_plant_cell(plant_cell_row: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for zombie_row_type in plant_cell_row:
		out[zombie_row_type] = plant_cell_row[zombie_row_type].filter(
			func(plant_cell: PlantCell) -> bool:
				return plant_cell.get_curr_plant_num() == 0 and not is_instance_valid(plant_cell.pot)
		)
	return out

#endregion


#region 戴夫提示罐

## 本关配置了提示个数时，从本批罐子里挑出几个「装着植物」的罐子，
## 把它们换成绿色植物罐的外观，玩家一眼就知道那几个是植物（看不出是哪一种，砸开才知道）
## （原版冒险 4-5：第 1 批全是棕色罐，第 2 批 2 个绿罐，第 3 批 3 个）
## 只挑棕色的神秘罐去换：本来就是绿罐的不用再提示。
static func create_pot_hint(pcm: PlantCellManager) -> void:
	var hint_num: int = pcm.game_para.pot_hint_num
	if hint_num <= 0:
		return
	var candidates: Array[ScaryPot] = []
	for pot: ScaryPot in pcm.curr_round_pots:
		if not is_instance_valid(pot):
			continue
		## 只能提示「这里面是植物」
		if pot.curr_plant_type == CharacterRegistry.PlantType.Null:
			continue
		if pot.pot_type != ScaryPot.E_PotType.Random:
			continue
		candidates.append(pot)
	candidates.shuffle()
	for i in range(mini(hint_num, candidates.size())):
		candidates[i].set_hint_plant_pot()
	Log.debug(
		str("戴夫提示罐数量：") + str(mini(hint_num, candidates.size())) + str(" / 配置 ") + str(hint_num)
	)

#endregion


#region 固定数量模式

## 固定模式创建所有的罐子
static func create_all_pot_on_fixed_mode(pcm: PlantCellManager) -> void:
	var plant_cell_row_on_zombie_row_type_copy = filter_can_create_pot_plant_cell(pcm.plant_cell_row_on_zombie_row_type)
	## 先对僵尸陆地和水路罐子划分创建僵尸罐子，先创建对僵尸行类型有要求的罐子
	for zombie_row_type in [CharacterRegistry.ZombieRowType.Land, CharacterRegistry.ZombieRowType.Pool]:
		## 先打乱植物格子顺序
		plant_cell_row_on_zombie_row_type_copy[zombie_row_type].shuffle()
		plant_cell_row_on_zombie_row_type_copy[zombie_row_type] = create_multi_zombie_pot(
			pcm,
			pcm.game_para.random_pot_zombie_with_zombie_row_type[zombie_row_type],
			plant_cell_row_on_zombie_row_type_copy[zombie_row_type],
			ScaryPot.E_PotType.Random
		)
		plant_cell_row_on_zombie_row_type_copy[zombie_row_type] = create_multi_zombie_pot(
			pcm,
			pcm.game_para.zombie_pot_with_zombie_row_type[zombie_row_type],
			plant_cell_row_on_zombie_row_type_copy[zombie_row_type],
			ScaryPot.E_PotType.Zombie
		)
	## 将剩余的植物格子放到一起
	var plant_cell_remaining: Array = []
	plant_cell_remaining.append_array(plant_cell_row_on_zombie_row_type_copy[CharacterRegistry.ZombieRowType.Land])
	plant_cell_remaining.append_array(plant_cell_row_on_zombie_row_type_copy[CharacterRegistry.ZombieRowType.Pool])
	## 打乱植物格子顺序
	plant_cell_remaining.shuffle()
	## 创建 both僵尸行类型的僵尸罐子
	plant_cell_remaining = create_multi_zombie_pot(
		pcm,
		pcm.game_para.random_pot_zombie_with_zombie_row_type[CharacterRegistry.ZombieRowType.Both],
		plant_cell_remaining,
		ScaryPot.E_PotType.Random
	)
	plant_cell_remaining = create_multi_zombie_pot(
		pcm,
		pcm.game_para.zombie_pot_with_zombie_row_type[CharacterRegistry.ZombieRowType.Both],
		plant_cell_remaining,
		ScaryPot.E_PotType.Zombie
	)

	plant_cell_remaining = create_multi_plant_pot(
		pcm, pcm.game_para.random_pot_plant, plant_cell_remaining, ScaryPot.E_PotType.Random
	)
	plant_cell_remaining = create_multi_plant_pot(
		pcm, pcm.game_para.plant_pot, plant_cell_remaining, ScaryPot.E_PotType.Plant
	)

	Log.debug(str("当前已经生成的罐子数量:") + str(pcm.curr_pot_num))
	Log.debug(str("结果固定罐子生成完成后剩余植物格子数量：") + str(plant_cell_remaining.size()))

	## 随机罐子数量和
	var random_pot_num_sum = pcm.game_para.random_pot_num_on_fixed_mode.x \
		+ pcm.game_para.random_pot_num_on_fixed_mode.y \
		+ pcm.game_para.random_pot_num_on_fixed_mode.z
	Log.debug(str("还需生成结果随机罐子数量(随机、植物、僵尸)：") + str(random_pot_num_sum))
	## 打乱顺序
	plant_cell_remaining.shuffle()

	if plant_cell_remaining.size() < random_pot_num_sum:
		Log.warn(
			"随机罐子数量(" + str(random_pot_num_sum) + ")超过剩余植物格子数("
			+ str(plant_cell_remaining.size()) + ")，多余的随机罐子将被跳过"
		)

	for i in range(pcm.game_para.random_pot_num_on_fixed_mode.x):
		if plant_cell_remaining.is_empty():
			break
		create_random_res_pot(pcm, plant_cell_remaining.pop_back(), ScaryPot.E_PotType.Random)

	for i in range(pcm.game_para.random_pot_num_on_fixed_mode.y):
		if plant_cell_remaining.is_empty():
			break
		create_random_res_pot(pcm, plant_cell_remaining.pop_back(), ScaryPot.E_PotType.Plant)

	for i in range(pcm.game_para.random_pot_num_on_fixed_mode.z):
		if plant_cell_remaining.is_empty():
			break
		create_random_res_pot(pcm, plant_cell_remaining.pop_back(), ScaryPot.E_PotType.Zombie)

	Log.debug(str("剩余罐子数量：") + str(plant_cell_remaining.size()) + str(" 使用 随机类型 结果随机罐子填充"))
	for plant_cell in plant_cell_remaining:
		create_random_res_pot(pcm, plant_cell)

	Log.debug(str("生成的所有罐子数量:") + str(pcm.curr_pot_num))

## 创建一个结果随机罐子
static func create_random_res_pot(
	pcm: PlantCellManager, plant_cell: PlantCell, pot_type := ScaryPot.E_PotType.Random
) -> void:
	var pot_para: Dictionary = {
		ScaryPot.E_PotInitParaAttr.PotType: pot_type,
		ScaryPot.E_PotInitParaAttr.IsFixedRes: false,
		ScaryPot.E_PotInitParaAttr.PlantCell: plant_cell,
		ScaryPot.E_PotInitParaAttr.IsAlwaysLookPot: Global.main_game.game_para.is_can_look_random_res_pot
	}
	plant_cell_creat_pot(pcm, plant_cell, pot_para)

## 创建多个僵尸罐子（按配置的数量逐个摆，格子用完就停）
static func create_multi_zombie_pot(
	pcm: PlantCellManager,
	pot_num_zombie_types: Dictionary,
	plant_cells_candidate: Array,
	pot_type: ScaryPot.E_PotType
) -> Array:
	for zombie_type in pot_num_zombie_types:
		## 循环数量
		for i in range(pot_num_zombie_types[zombie_type]):
			if plant_cells_candidate.is_empty():
				Log.debug(
					str("warning: 僵尸类型")
					+ str(Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieName))
					+ str("没有对应的空闲植物格子")
				)
				return plant_cells_candidate
			var plant_cell: PlantCell = plant_cells_candidate.pick_random()
			var pot_para: Dictionary = {
				ScaryPot.E_PotInitParaAttr.PotType: pot_type,
				ScaryPot.E_PotInitParaAttr.IsFixedRes: true,
				ScaryPot.E_PotInitParaAttr.ZombieType: zombie_type,
				ScaryPot.E_PotInitParaAttr.PlantCell: plant_cell
			}
			plant_cell_creat_pot(pcm, plant_cell, pot_para)
			plant_cells_candidate.erase(plant_cell)
	return plant_cells_candidate

## 创建多个植物罐子（按配置的数量逐个摆，格子用完就停）
static func create_multi_plant_pot(
	pcm: PlantCellManager,
	pot_num_plant_types: Dictionary,
	plant_cells_candidate: Array,
	pot_type: ScaryPot.E_PotType
) -> Array:
	for plant_type in pot_num_plant_types:
		## 循环数量
		for i in range(pot_num_plant_types[plant_type]):
			if plant_cells_candidate.is_empty():
				Log.warn("植物罐子候选格子已用尽，剩余的固定植物罐子将被跳过")
				return plant_cells_candidate
			var plant_cell: PlantCell = plant_cells_candidate.pick_random()
			var pot_para: Dictionary = {
				ScaryPot.E_PotInitParaAttr.PotType: pot_type,
				ScaryPot.E_PotInitParaAttr.IsFixedRes: true,
				ScaryPot.E_PotInitParaAttr.PlantType: plant_type,
				ScaryPot.E_PotInitParaAttr.PlantCell: plant_cell
			}
			plant_cell_creat_pot(pcm, plant_cell, pot_para)
			plant_cells_candidate.erase(plant_cell)
	return plant_cells_candidate

#endregion


#region 落罐

## 植物格子创建罐子
static func plant_cell_creat_pot(pcm: PlantCellManager, plant_cell: PlantCell, pot_para: Dictionary) -> void:
	var pot: ScaryPot = plant_cell.create_pot(pot_para)
	if pcm.is_pot_mode:
		pot.signal_open_pot.connect(pcm.pot_open_update)
	pcm.curr_round_pots.append(pot)
	pcm.curr_pot_num += 1

#endregion
