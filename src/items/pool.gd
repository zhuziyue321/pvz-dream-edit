extends Node2D
class_name Pool

@onready var pool_drop: ColorRect = $Pool/PoolDrop
## 原版泳池波光（PARTICLE_POOL_SPARKLY）：原版只在白天泳池常驻，浓雾关不生成（Board.cpp UpdateBoard）
@onready var sparkly: PoolSparkly = $PoolSparkly

@onready var pool_base: Sprite2D = $PoolBase
@onready var pool: Sprite2D = $Pool
## 泳池白天图片（已用 tools/merge_alpha.ps1 把 pool_base_.png 蒙版烘焙进 alpha 通道）
## 贴图走 AssetRegistry：进泳池 / 浓雾关时加载，之后复用缓存
var POOL_BASE: Texture2D = AssetRegistry.get_texture("res://assets_custom/image/background/pool_base.png")
var POOL: Texture2D = AssetRegistry.get_texture("res://pak/images/pool.jpg")

## 泳池黑夜图片（夜间底图复用同一张 pool_base_.png 蒙版烘焙）
var POOL_BASE_NIGHT: Texture2D = AssetRegistry.get_texture("res://assets_custom/image/background/pool_base_night.png")
var POOL_NIGHT: Texture2D = AssetRegistry.get_texture("res://pak/images/pool_night.jpg")

## 水面明暗层（pool_shading_.jpg 蒙版已烘进 alpha）与焦散源图：原版 PoolEffect 的层 1 / 层 2
var POOL_SHADING: Texture2D = AssetRegistry.get_texture("res://assets_custom/image/background/pool_shading.png")
var POOL_SHADING_NIGHT: Texture2D = AssetRegistry.get_texture("res://assets_custom/image/background/pool_shading_night.png")
var POOL_CAUSTIC: Texture2D = AssetRegistry.get_texture("res://pak/images/pool_caustic_effect.jpg")


func init_pool(game_para:ResourceLevelData):
	sparkly.visible = game_para.game_BG == ConstLevelData.GameBg.Pool
	var water_mat: ShaderMaterial = pool.material
	water_mat.set("shader_parameter/caustic_tex", POOL_CAUSTIC)
	match game_para.game_BG:
		ConstLevelData.GameBg.Pool:
			pool_base.texture = POOL_BASE
			pool.texture = POOL
			water_mat.set("shader_parameter/shading_tex", POOL_SHADING)
			water_mat.set("shader_parameter/is_night", 0.0)

		ConstLevelData.GameBg.Fog:
			pool_base.texture = POOL_BASE_NIGHT
			pool.texture = POOL_NIGHT
			water_mat.set("shader_parameter/shading_tex", POOL_SHADING_NIGHT)
			water_mat.set("shader_parameter/is_night", 1.0)

	if game_para.is_rain:
		pool_drop.visible = true
		var mat := pool_drop.material
		match game_para.game_BG:
			ConstLevelData.GameBg.Pool:
				mat.set("shader_parameter/drop_color", Color(0.0, 0.914, 0.941, 1.0))
			ConstLevelData.GameBg.Fog:
				mat.set("shader_parameter/drop_color", Color(0.0, 0.502, 0.773, 1.0))
	else:
		pool_drop.visible = false
