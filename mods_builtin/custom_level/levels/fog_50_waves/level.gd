extends LevelScriptBase
## fog_50_waves —— 自制关卡：浓雾地图（没有雾 / 没有墓碑）、开局 5000 阳光、只有普通僵尸的 50 波硬仗
##
## 关卡 = 属性（`_init()` 里赋值）+ 流程（`run_flow()` 一段顺序程序），不再有 `.tres`。
## 流程与 `LevelScriptBase` 的默认流程同构（展示僵尸 → 选卡 → 小推车 → 准备安放植物 → 开战），
## 区别只在「开战」那一步把**波数**与**出怪表**写成具名常量 —— 翻这一个文件就知道本关怎么打。
##
## 本关卡包由「自制关卡」模组扫描（`mods_builtin/custom_level/levels/`，一个子目录 = 一个关卡，
## 关卡 id = 目录名 `fog_50_waves`），要玩它得先在模组页面打开「自制关卡」。

## 本关波数：每 10 波一次大波（旗帜波），第 50 波是最终大波
const WAVE_NUM := 50
## 开局阳光：一次给足（浓雾场景在夜里，本来就没有天降阳光）
const START_SUN := 5000


func _init() -> void:
	## 场景：泳池·浓雾 —— 主游戏槽位 / 底图 / BGM / 雾 / 昼夜 / 天降阳光全由场景脚本给出
	## （场景是「赋值即套用」，所以覆盖项必须写在 scene_name 之后，见 docs/参考存档/场景设置.md）
	scene_name = SceneSettingRegistry.SCENE_FOG

	## 没有雾：要的是浓雾地图的夜色底图，但不要泳池前景层那层飘动的雾（见 map_bg_anim_pool.gd）
	is_fog = false

	## 没有墓碑：不生成墓碑，最后一大波也不会从墓碑里冒出伏击僵尸
	is_have_tombston = false
	init_tombstone_num = 0
	is_tombstone_respawn = false

	## 开局阳光
	start_sun = START_SUN

	## 本关波数：运行期由 start_battle(WAVE_NUM) 一并写进波次管理器，
	## 这里写同一个常量，让关卡数据字段读起来与本关实际波数一致
	max_wave = WAVE_NUM

	## 出怪表：只有普通僵尸（大波会自动补一只旗帜僵尸，见 zm_zombie_wave_create_manager）
	zombie_refresh_types.assign([ZombieIds.NORM])


## ⚠️ 参数只能叫 `mg`：基类的 `_mg` 字段存在，改叫 `_mg` 会遮蔽它（见 LevelScriptBase 那行说明）。
## 本关流程用不上 mg（流程方法自己会去取主游戏），照抄基类签名并按下这条未使用告警。
@warning_ignore("unused_parameter")
func run_flow(mg: MainGameManager) -> void:
	## 出怪表：本关多处要用同一份，抽成变量避免重复写
	var zombie_list: Array[StringName] = [ZombieIds.NORM]

	## 展示僵尸：镜头拉到草坪右侧，先看一眼马上要面对的是什么
	await show_zombie(zombie_list)
	## 选卡
	await choose_card()
	## 初始化小推车：从屏幕外左侧按从下到上的顺序开到位
	await init_lawn_mover()
	## 「准备…安放…植物」红字
	await ready_set_plant()
	## 开战：50 波、只有普通僵尸（开战会打到最后一波清完为止）
	await start_battle(WAVE_NUM, zombie_list)
