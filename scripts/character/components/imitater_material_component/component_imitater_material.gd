extends ComponentNormBase
class_name ImitaterMaterialComponent

## 植物模仿者材质组件
## 模仿者复制出的植物使用该组件修改body材质

@onready var body: BodyCharacter = %Body

## 是否为模仿者材质
var is_imitater_material := false

## 初始化是否为模仿者材质（植物加入场景树之前调用）
func init_imitater_material(value:bool) -> void:
	is_imitater_material = value

func _ready() -> void:
	super()
	if is_imitater_material:
		body.imitater_update_material()
