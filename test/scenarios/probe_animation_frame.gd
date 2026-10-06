extends RefCounted
## 探针：取一个动画的某一帧当图片（AnimationFrameUtil / AnimationFrameIcon）
##
## 覆盖：
##   1. 水路小推车 PoolCleaner_land_static 第 0 帧能渲染出有内容的图片
##   2. 屋顶小推车 RoofCleaner 第 0 帧同上
##   3. create_frame_node：脚本已剥离、播放器已摘掉、可见部件还在、包围盒有效
##   4. 商店里这两件商品的图标被换成渲染出来的那一帧（不再是兜底的单张贴图）
##
## 机器可读汇总：最后一行 [ANIMFRAME] result=PASS|FAIL failed=<n>

const POOL_SCENE := "res://src/items/lawn_mower/pool_cleaner.tscn"
const ROOF_SCENE := "res://src/items/lawn_mower/roof_cleaner.tscn"
const SNAIL_SCENE := "res://src/garden/stinky.tscn"
const STORE_SCENE := "res://src/store/store.tscn"
const PATH_POOL_ICON := "Bg/Car2/Panel/RowTools/GoodsPoolCleaner/StoreIcon"
const PATH_ROOF_ICON := "Bg/Car2/Panel/RowTools/GoodsRoofCleaner/StoreIcon"
const PATH_SNAIL_ICON := "Bg/Car2/Panel/RowGarden/GoodsStinky/StoreIcon"
## 商店图标格子尺寸（见 goods_pool_cleaner.tscn 的 StoreIcon）
const ICON_SIZE := Vector2(67.0, 68.0)

var _failed := 0


func run(a) -> void:
	a.log("")
	a.log("========== PROBE 动画取帧 ==========")
	await a.wait(1.0)

	# ------------------------------------------------ STEP1 一步到位取图片
	a.log("STEP1 取动画某一帧渲染成图片")
	var pool_tex := await AnimationFrameUtil.create_frame_texture(
			load(POOL_SCENE), &"PoolCleaner_land_static", 0, ICON_SIZE, 2.0)
	_check(a, "水路小推车取帧拿到图片", pool_tex != null, str(pool_tex))
	_check_image(a, "水路小推车", pool_tex)

	var roof_tex := await AnimationFrameUtil.create_frame_texture(
			load(ROOF_SCENE), &"RoofCleaner", 0, ICON_SIZE, 2.0)
	_check(a, "屋顶小推车取帧拿到图片", roof_tex != null, str(roof_tex))
	_check_image(a, "屋顶小推车", roof_tex)

	var snail_tex := await AnimationFrameUtil.create_frame_texture(
			load(SNAIL_SCENE), &"Stinky_idle", 0, ICON_SIZE, 2.0)
	_check(a, "蜗牛取帧拿到图片", snail_tex != null, str(snail_tex))
	_check_image(a, "蜗牛", snail_tex)

	# ------------------------------------------------ STEP2 只取定格节点
	a.log("STEP2 取定格的静态形象节点")
	var node := AnimationFrameUtil.create_frame_node(load(POOL_SCENE), &"PoolCleaner_land_static", 0)
	_check(a, "定格节点非空", node != null, str(node))
	if node != null:
		_check(a, "定格节点已剥离脚本", node.get_script() == null)
		_check(a, "定格节点已摘掉播放器", AnimationFrameUtil.find_animation_player(node) == null)
		var sprite_num := _count_sprite(node)
		_check(a, "定格节点还留着可见部件", sprite_num > 0, "sprite=%d" % sprite_num)
		var rect := AnimationFrameUtil.get_content_rect(node)
		_check(a, "定格节点包围盒有效", rect.size.x > 0.0 and rect.size.y > 0.0, str(rect))
		node.free()

	# ------------------------------------------------ STEP3 商店里的图标
	await _check_store(a)
	_finish(a)


## 进商店看两件小推车商品的图标有没有换成渲染出来的那一帧
func _check_store(a) -> void:
	a.log("STEP3 商店里的水路 / 屋顶小推车图标")
	_mark_cleared(Global.global_game_state, 50)
	a.get_tree().change_scene_to_file(STORE_SCENE)
	if not await a.wait_scene("store", 15.0):
		_check(a, "进入商店", false, str(a.get_tree().current_scene))
		return
	## 图标是离屏渲染出来的，等两帧以上再验
	await a.wait(3.0)
	var store: Node = a.get_tree().current_scene
	var pool_icon := store.get_node_or_null(PATH_POOL_ICON) as TextureRect
	var roof_icon := store.get_node_or_null(PATH_ROOF_ICON) as TextureRect
	var snail_icon := store.get_node_or_null(PATH_SNAIL_ICON) as TextureRect
	_check(a, "找到水路小推车图标", pool_icon != null, str(pool_icon))
	_check(a, "找到屋顶小推车图标", roof_icon != null, str(roof_icon))
	_check(a, "找到蜗牛图标", snail_icon != null, str(snail_icon))
	if pool_icon == null or roof_icon == null or snail_icon == null:
		return
	## 兜底贴图是从 assets 载入的(有 resource_path)，渲染出来的 ImageTexture 没有
	_check(a, "水路图标已换成渲染帧",
		pool_icon.texture != null and pool_icon.texture.resource_path == "",
		str(pool_icon.texture))
	_check(a, "屋顶图标已换成渲染帧",
		roof_icon.texture != null and roof_icon.texture.resource_path == "",
		str(roof_icon.texture))
	_check(a, "蜗牛图标已换成渲染帧",
		snail_icon.texture != null and snail_icon.texture.resource_path == "",
		str(snail_icon.texture))


#region 断言与工具
func _check_image(a, label: String, tex: Texture2D) -> void:
	if tex == null:
		_check(a, label + " 图片有可见内容", false)
		return
	var img := tex.get_image()
	_check(a, label + " 图片尺寸 = 图标格", img.get_size() == Vector2i(ICON_SIZE), str(img.get_size()))
	var visible_pixels := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.05:
				visible_pixels += 1
	_check(a, label + " 图片有可见内容", visible_pixels > 100,
		"visible=%d/%d" % [visible_pixels, img.get_width() * img.get_height()])


func _count_sprite(root: Node) -> int:
	var num := 1 if root is Sprite2D else 0
	for child in root.get_children():
		num += _count_sprite(child)
	return num


func _check(a, label: String, ok: bool, detail: String = "") -> void:
	if ok:
		a.log("  [OK] " + label + ("  " + detail if detail != "" else ""))
	else:
		_failed += 1
		a.log("  [NG] " + label + ("  " + detail if detail != "" else ""))


func _finish(a) -> void:
	a.log("")
	a.log("[ANIMFRAME] result=%s failed=%d" % ["PASS" if _failed == 0 else "FAIL", _failed])
	a.quit_game()


func _mark_cleared(state, upto: int) -> void:
	state.curr_all_level_state_data = {}
	for i in range(1, upto + 1):
		state.curr_all_level_state_data["101_0_%04d" % i] = {"IsSuccess": true}
#endregion
