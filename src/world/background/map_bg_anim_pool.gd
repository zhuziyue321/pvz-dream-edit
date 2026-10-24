extends MapBgAnimBase
class_name MapBgAnimPool
## 泳池 / 浓雾的背景动画：泳池水面（白天 / 夜晚 / 雨滴）+ 浓雾 + 雨。
## 这三种都只影响画面，不参与出怪 / 卡槽 / 罐子等关卡逻辑，因此全部收在这里。

var POOL_SCENE = AssetRegistry.get_scene("res://src/world/background/pool.tscn")
var FOG_SCENE = AssetRegistry.get_scene("res://src/world/background/fog.tscn")
var RAIN_SCENE = AssetRegistry.get_scene("res://src/world/background/rain.tscn")

var pool: Pool
var fog: Fog
var rain: MainGameRain


func init_anim() -> void:
	## 水面挂在背景层：要盖在背景图上，但在植物格子之下
	pool = POOL_SCENE.instantiate()
	background.add_child(pool)
	pool.init_pool(game_para)
	## 雾和雨挂在前景层：要盖在格子之上
	if game_para.is_fog:
		fog = FOG_SCENE.instantiate()
		frontground.add_child(fog)
	if game_para.is_rain:
		rain = RAIN_SCENE.instantiate()
		frontground.add_child(rain)
		## 雷雨关(4-10):屏幕压暗 + 随机闪电,非雷雨关只下雨
		rain.set_lightning(game_para.is_lightning)


func get_fog() -> Fog:
	return fog


func start_game() -> void:
	if is_instance_valid(fog):
		fog.come_back_game(5.0)


func start_next_round() -> void:
	if is_instance_valid(fog):
		fog.fog_outside()
