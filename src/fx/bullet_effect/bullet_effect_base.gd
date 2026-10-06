extends Node2D
class_name BulletEffect000Base
## 子弹特效基类

## 是否有子弹特效
@export var is_bullet_effect := true

## 激活子弹特效
func activate_bullet_effect():
	## 子弹父类
	## 不走 get_sibling_layer()：那个接口挂在 Character000Base 上，而这里的 owner 是子弹
	## （Bullet000Base extends Node2D），两条继承链互不相干。子弹挂回自己的父层是结构性约定。
	var bullet_parent = owner.get_parent()
	z_index = owner.z_index
	#GlobalUtils.child_node_change_parent(self, bullet_parent)

	reparent(bullet_parent)
