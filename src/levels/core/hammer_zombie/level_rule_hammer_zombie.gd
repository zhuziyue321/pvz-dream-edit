extends RefCounted
class_name LevelRuleHammerZombie
## 「锤僵尸」玩法规则 —— 迷你游戏 15（Whack a Zombie）与冒险 2-5（打地鼠）**两关共用**
##
## 这是这两关在本体里的**唯一入口**：关卡脚本在自己的 `init_level_items()` 里调一次 `install(mg)`，
## 之后所有与「有锤子」相关的东西都由本规则装配，本体（`MainGameManager` / `ZombieManager`）
## 不需要为这个玩法留任何 `if` 分支（硬约束 §1-8）。
##
## 装上的是三样本体不必认识的东西：
##   1. **锤子手持物**：启用手持物组件 `HandComponentHammer`，并把它设成**本关的空闲手持物取代空手**
##      —— 进 MAIN_GAME 自动拿在手上、种完植物 / 放下铲子后回到手上、非游玩阶段收起，
##      全由本体那套手持物调度管（见 HandManager.set_idle_hand_type）。锤子美术常驻
##      `canvas_layer_temp`（与真铲子 / 真手套同层），本体只认一个 `E_HandComponentType`。
##   2. **自定义光标开关**：锤子跟着鼠标当光标，系统鼠标什么时候该露出来由本体按游戏阶段管
##      （见 MainGameManager.set_custom_cursor_mode）。
##   3. **出怪器**：僵尸不从边缘走进来，改从草坪右侧的墓碑里冒头（见 HammerZombieManager），
##      注入 ZombieManager 后由它开波；旗帜进度条由 ZombieManager 转交给它
##
## 两关各自的差异（出战卡、开局墓碑数、难度数值）仍旧写在各自的关卡脚本 / 关卡数据上，不搬到这里。

## 装上本玩法；执行一次即可（关卡脚本只在 init_level_items() 里调一次）
static func install(mg: MainGameManager) -> void:
	_install_hand(mg)
	_install_cursor(mg)
	_install_wave_source(mg)


## 把锤子装成本关的手持物：启用锤子手持物组件 + 把它设成空闲手持物取代空手（硬约束 §1-8）
## 排在 `init_manager()` 末尾的回调里（见 MainGameManager.register_level_init_callback）：
## 手持物组件要等 `HandManager.init_manager()` 注册完才拿得到，而本规则跑在它之前
static func _install_hand(mg: MainGameManager) -> void:
	mg.register_level_init_callback(func() -> void:
		var hand_manager := mg.hand_manager
		hand_manager.change_hand_component_enable(HandComponentBase.E_HandComponentType.Hammer, true)
		hand_manager.set_idle_hand_type(HandComponentBase.E_HandComponentType.Hammer)
	)


## 打开本体的自定义光标开关：锤子跟着鼠标当光标，系统鼠标的显隐交给本体
## （进 MAIN_GAME 藏起来 / 悬停可点控件露出来 / 面板期间保持可见，见 MainGameManager）
static func _install_cursor(mg: MainGameManager) -> void:
	mg.set_custom_cursor_mode(true)


## 装出怪器：挂到僵尸管理器下并注入，取代原来常驻在主场景里的那个节点
## （注入要排在 ZombieManager.init_manager() 之前，所以这里直接装，不再绕 register_level_init_callback）
static func _install_wave_source(mg: MainGameManager) -> void:
	var wave_source: ZombieWaveSourceBase = SceneRegistry.HAMMER_ZOMBIE_SOURCE.instantiate()
	mg.zombie_manager.add_child(wave_source)
	mg.zombie_manager.set_wave_source(wave_source)
