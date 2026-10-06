extends RefCounted
## 临时探针：打印每个关卡资源的「地图/玩法开关」实际取值。
## 用来核对 .tres 里写成 null 的属性到底落到了什么值（nil 赋值会退回脚本默认值）。


func run(a) -> void:
	var paths := _find("res://src/levels")
	paths.sort()
	a.log("[LVL] 共 %d 个关卡资源" % paths.size())
	for p in paths:
		var para: Resource = (load(p) as GDScript).new()
		if para == null:
			a.log("[LVL] !! 加载失败 " + p)
			continue
		var mini_zombie: bool = para.get_zombie_init_para_extra().get(
			Zombie000Base.E_ZInitAttr.IsMiniZombie, false)
		a.log("[LVL] %s" % p.replace("res://src/levels/", ""))
		a.log("   sences=%s BG=%s round=%s monster=%s card=%s pot=%s potmode=%s maxwave=%s multy=%s start_sun=%s" % [
			str(para.game_sences), str(para.game_BG), str(para.game_round), str(para.monster_mode),
			str(para.card_mode), str(para.is_pot_mode), str(para.pot_mode), str(para.max_wave),
			str(para.zombie_multy), str(para.start_sun)])
		a.log("   bowling=%s bowling_col=%s seed_rain=%s mini_zombie=%s zombie_mode=%s" % [
			str(para.is_bowling_stripe), str(para.plant_cell_col_j),
			str(para.is_seed_rain), str(mini_zombie), str(para.is_zombie_mode)])
		a.log("   day=%s daysun=%s mower=%s canhome=%s choose=%s show=%s fog=%s rain=%s" % [
			str(para.is_day), str(para.is_day_sun), str(para.is_lawn_mover), str(para.is_zombie_can_home),
			str(para.can_choosed_card), str(para.look_show_zombie), str(para.is_fog), str(para.is_rain)])
		a.log("   refresh_types=%s bungi=%s" % [
			str(para.zombie_refresh_types), str(para.is_bungi)])
		a.log("   BGM=%s conveyor_cards=%s" % [
			str(para.game_BGM), str(para.conveyor_weights.map(func(w): return w.card_reference.content_id))])
	a.log("[LVL] 结束")
	a.quit_game()


func _find(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if dir.current_is_dir():
			## core/ 与 script/ 放的是关卡脚本基类 / 事件脚本，不是关卡（同 LevelRegistry._scan_dir）
			if n == "core" or n == "script":
				n = dir.get_next()
				continue
			out.append_array(_find(dir_path + "/" + n))
		elif n.ends_with(".gd"):
			## 关卡专属的场景脚本这类不是关卡的 .gd 跳过（判据同 LevelRegistry._scan_dir）
			if not LevelRegistry.is_level_script(dir_path + "/" + n):
				n = dir.get_next()
				continue
			out.append(dir_path + "/" + n)
		n = dir.get_next()
	dir.list_dir_end()
	return out
