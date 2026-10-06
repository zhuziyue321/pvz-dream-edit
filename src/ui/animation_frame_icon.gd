extends TextureRect
class_name AnimationFrameIcon
## 把「某个动画的某一帧」直接当图标用的 TextureRect
##
## 用法：场景里摆一个 TextureRect、挂上本脚本，填 scene / anim_name / frame 三个导出量即可，
## 不用写一行代码 —— 商店里的水路 / 屋顶小推车图标就是这么来的
## (见 src/store/goods_pool_cleaner.tscn 与 goods_roof_cleaner.tscn)
##
## texture 属性上可以先配一张兜底图：离屏渲染要等两帧，
## 渲染完成之前(以及渲染失败时)显示的就是这张兜底图

## 取帧的源场景：带 AnimationPlayer 的角色 / 物件场景
@export var scene: PackedScene
## 动画名(AnimationLibrary 里的名字，不是资源文件名)
@export var anim_name: StringName = &""
## 取第几帧(从 0 起，按动画的 step 换算时间)
@export var frame: int = 0
## 图片四周留白(像素)
@export var margin: float = 2.0
## TextureRect 没被布局撑开时的兜底尺寸
@export var fallback_size: Vector2 = Vector2(64.0, 64.0)


func _ready() -> void:
	if scene == null:
		return
	_render_async(_target_size())


## 渲染尺寸：优先用自己被撑出来的尺寸
func _target_size() -> Vector2:
	if size.x < 1.0 or size.y < 1.0:
		return fallback_size
	return size


## 离屏渲染这一帧并贴到 texture 上(内部 await，不阻塞 _ready)
func _render_async(target: Vector2) -> void:
	var tex := await AnimationFrameUtil.create_frame_texture(scene, anim_name, frame, target, margin)
	if tex == null or not is_instance_valid(self):
		return
	texture = tex
