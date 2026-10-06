extends Resource
class_name SceneSettingBase
## 场景设置基类 —— **一个场景一份脚本**，脚本里写死这个场景「长什么样」的具体信息。
##
## 关卡只认「场景的名字」（ResourceLevelData.scene_name，取值见 SceneSettingRegistry.SCENE_*），
## 具体信息由这里的场景脚本给出 —— 关卡脚本不必再把这些逐项抄一遍：
##
##   func _init() -> void:
##       scene_name = SceneSettingRegistry.SCENE_FOG
##
## 需要偏离本场景的关卡（例：冒险 1-5 用前院场景，但播小游戏曲）：
## 场景在 `scene_name` **赋值那一刻**就套用，写在它后面的同名字段即为覆盖：
##
##   func _init() -> void:
##       scene_name = SceneSettingRegistry.SCENE_FRONT_DAY
##       game_BGM = ConstLevelData.GameBGM.MiniGame
##
## 覆盖项多 / 要按运行时条件改时，也可以覆写 ResourceLevelData.apply_scene_setting()。
##
## 消费方：ResourceLevelData.apply_scene_setting()（scene_name 一赋值就调用）。
## 加一个场景 = 本目录新建一个子类脚本 + 在 SceneSettingRegistry 登记名字与路径。
##
## 边界：表现层的背景子场景 / 动画由地图数据装配（ResourceMapData.map_bg_scene / map_bg_script），
## 本脚本只给「这个场景是什么样」的数据，不装配节点；
## 雨 / 闪电（is_rain / is_lightning）是**关卡级**天气开关（原版只有冒险 4-10 是雷雨夜），
## 不属于场景，关卡自己写。

## 场景名（日志 / 备注用；注册表的键另见 SceneSettingRegistry.SCENE_*）
@export var display_name: String = ""
## 主游戏场景槽位（前院 / 泳池 / 屋顶三选一，见 MainSceneRegistry）
@export var game_sences: MainSceneRegistry.MainScenes = MainSceneRegistry.MainScenes.MainGameFront
## 底图（见 ConstLevelData.GameBg）
@export var game_BG: ConstLevelData.GameBg = ConstLevelData.GameBg.FrontDay
## 背景音乐（见 ConstLevelData.GameBGM）
@export var game_BGM: ConstLevelData.GameBGM = ConstLevelData.GameBGM.FrontDay
## 是否有雾
@export var is_fog: bool = false
## 是否白天（false = 夜晚：蘑菇不睡觉）
@export var is_day: bool = true
## 是否天降阳光
@export var is_day_sun: bool = true
