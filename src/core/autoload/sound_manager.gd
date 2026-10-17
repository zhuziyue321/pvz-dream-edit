extends Node
class_name SoundManagerClass

enum Bus {MASTER, BGM, SFX}

@onready var bgm_play: AudioStreamPlayer = $BGMPlay
@onready var sfx_all: Node = $SFXAll
@onready var crazy_dave_player: AudioStreamPlayer = $SFXAll/CrazyDavePlayer
@onready var rain_player: AudioStreamPlayer = $SFXAll/RainPlayer

## 当前帧播放的音效(每隔25物理帧清除一次)
## 音效每25物理帧内不可以重复播放
var curr_frame_sfx:Array[AudioStream] = []
var frame_num:=0

#func _ready() -> void:
	#Global.config_service.load_and_apply_config()
	#Global.save_config()

@warning_ignore("unused_parameter")
func _physics_process(delta: float) -> void:
	frame_num = wrapi(frame_num + 1, 0, 25)
	if frame_num == 0:
		curr_frame_sfx.clear()

#region 播放音乐和音效
## 播放背景音乐
## stream 为 null 表示静音(如冒险 4-10):只停掉当前 BGM,不改动已加载的 stream
func play_bgm(stream: AudioStream):
	if stream == null:
		bgm_play.stop()
		return
	bgm_play.stream = stream
	bgm_play.play()

#region 植物和僵尸有关音效(植物、僵尸、子弹、受击)
"""
 音效分为 僵尸受击 子弹音效 角色(植物僵尸) 戴夫 和其他音效
"""

## 僵尸受击音效种类
enum TypeBeAttackSFX{
	Null,		## 无声音
	Plastic,	## 塑料
	Shield		## 铁器
}

## 僵尸受击音效资源字典
const SFXBeAttackMap := {
	TypeBeAttackSFX.Null: null,
	TypeBeAttackSFX.Plastic: [
		preload("res://pak/sounds/plastichit.ogg"),
		preload("res://pak/sounds/plastichit2.ogg")
	],
	TypeBeAttackSFX.Shield: [
		preload("res://assets_custom/audio/SFX/bullet/shieldhit1.ogg"),
		preload("res://pak/sounds/shieldhit2.ogg")
	],
}

## 子弹音效种类
enum TypeBulletSFX{
	Null,		## 无声音
	Pea,		## 豌豆
	PeaFire,	## 火焰豌豆
	Corn,		## 玉米粒
	Butter,		## 黄油
	Melon,		## 西瓜
	Bowling = 1001,		## 保龄球
}

## 子弹音效资源字典
const SFXBulletMap := {
	TypeBulletSFX.Null: null,
	TypeBulletSFX.Pea: [
		preload("res://assets_custom/audio/SFX/bullet/splat1.ogg"),
		preload("res://pak/sounds/splat2.ogg"),
		preload("res://pak/sounds/splat3.ogg")
	],
	TypeBulletSFX.PeaFire: [
		preload("res://pak/sounds/firepea.ogg"),
	],
	TypeBulletSFX.Corn:[
		preload("res://pak/sounds/kernelpult2.ogg"),
		preload("res://pak/sounds/kernelpult.ogg")
	],
	TypeBulletSFX.Butter:[
		preload("res://pak/sounds/butter.ogg")
	],
	TypeBulletSFX.Melon:[
		preload("res://pak/sounds/melonimpact.ogg"),
		preload("res://pak/sounds/melonimpact2.ogg")
	],

	TypeBulletSFX.Bowling: [
		preload("res://pak/sounds/bowlingimpact.ogg"),
		preload("res://pak/sounds/bowlingimpact2.ogg"),
	],

}

## 植物\僵尸音效字典
const SFXCharacterMap := {
	## -------------------------------植物-------------------------------
	## 豌豆射手发射字典
	&"Throw":[
		preload("res://assets_custom/audio/SFX/plant/throw1.ogg"),
		preload("res://pak/sounds/throw2.ogg")
	],
	## 向日葵发射阳光
	&"Throw1":preload("res://assets_custom/audio/SFX/plant/throw1.ogg"),
	## 樱桃炸弹爆炸
	&"CherryBomb":preload("res://pak/sounds/cherrybomb.ogg"),
	## 土豆雷爆炸
	&"PotatoMine": preload("res://pak/sounds/potato_mine.ogg"),
	## 大嘴花
	&"BigChomp": preload("res://pak/sounds/bigchomp.ogg"),
	## 小喷菇发射子弹
	&"Puff": preload("res://pak/sounds/puff.ogg"),
	## 阳光菇长大
	&"PlantGrow": preload("res://pak/sounds/plantgrow.ogg"),
	## 大喷菇发射子弹
	&"Fume": preload("res://pak/sounds/fume.ogg"),
	## 墓碑吞噬者
	&"GraveBusterChomp":preload("res://pak/sounds/gravebusterchomp.ogg"),
	## 魅惑菇
	&"MindControlled": preload("res://pak/sounds/mindcontrolled.ogg"),
	## 寒冰菇
	&"Frozen": preload("res://pak/sounds/frozen.ogg"),
	## 毁灭菇
	&"DoomShroom": preload("res://pak/sounds/doomshroom.ogg"),
	## 倭瓜发现敌人
	&"SquashHmm":[
		preload("res://pak/sounds/squash_hmm2.ogg"),
		preload("res://pak/sounds/squash_hmm.ogg")
	],
	## 火爆辣椒
	&"Jalapeno": preload("res://pak/sounds/jalapeno.ogg"),
	## 三叶草
	&"blover": preload("res://pak/sounds/blover.ogg"),
	## 磁力菇
	&"magnetshroom": preload("res://pak/sounds/magnetshroom.ogg"),
	## 磁力菇
	&"coblaunch": preload("res://pak/sounds/coblaunch.ogg"),




	## -------------------------------僵尸-------------------------------
	## 通用音效
	## 掉头
	&"limbs_pop": preload("res://pak/sounds/limbs_pop.ogg"),

	## 啃食
	&"Chomp":[
		preload("res://pak/sounds/chomp.ogg"),
		preload("res://pak/sounds/chomp2.ogg"),
		preload("res://pak/sounds/chompsoft.ogg")
	],
	## 掉头
	&"Shoop":preload("res://pak/sounds/shoop.ogg"),
	## 啃食大蒜
	&"yuck":[
		preload("res://pak/sounds/yuck2.ogg"),
		preload("res://pak/sounds/yuck.ogg")
	],
	## 撑杆跳
	&"Polevault":preload("res://pak/sounds/polevault.ogg"),
	## 读报僵尸愤怒
	&"Rarrgh":[
		preload("res://pak/sounds/newspaper_rarrgh.ogg"),
		preload("res://pak/sounds/newspaper_rarrgh2.ogg")
	],
	## 读报僵尸报纸掉落
	&"Rip":	preload("res://pak/sounds/newspaper_rip.ogg"),
	## 舞王入场
	&"Dancer":preload("res://pak/sounds/dancer.ogg"),
	## 冰车僵尸入场
	&"zamboni":preload("res://pak/sounds/zamboni.ogg"),
	## 冰车僵尸爆炸\小丑僵尸爆炸
	&"explosion":preload("res://pak/sounds/explosion.ogg"),
	## 僵王博士踩踏 / 扔房车落地
	&"bossboulderattack":preload("res://pak/sounds/bossboulderattack.ogg"),
	## 僵王博士爆炸（死亡）
	&"bossexplosion":preload("res://pak/sounds/bossexplosion.ogg"),
	## 僵王博士低头 / 抬头的液压动作
	&"hydraulic":preload("res://pak/sounds/hydraulic.ogg"),
	## 僵王博士放置僵尸及蹦极时的手臂动作
	&"hydraulic_short":preload("res://pak/sounds/hydraulic_short.ogg"),
	## 僵王博士丢车时的投掷动作
	&"RVthrow":preload("res://pak/sounds/RVthrow.ogg"),
	## 海豚僵尸入场
	&"dolphin_appears":preload("res://pak/sounds/dolphin_appears.ogg"),
	## 海豚僵尸跳跃
	&"dolphin_before_jumping":preload("res://pak/sounds/dolphin_before_jumping.ogg"),
	## 小丑僵尸入场
	&"jackinthebox":preload("res://pak/sounds/jackinthebox.ogg"),
	## 小丑僵尸爆炸惊讶
	&"jack_suprise":[
		preload("res://pak/sounds/jack_surprise.ogg"),
		preload("res://pak/sounds/jack_surprise2.ogg"),
	],
	## 小丑僵尸盒子打开
	&"boing":preload("res://pak/sounds/boing.ogg"),
	## 气球僵尸入场
	&"ballooninflate":preload("res://pak/sounds/ballooninflate.ogg"),
	## 气球爆炸
	&"balloon_pop":preload("res://pak/sounds/balloon_pop.ogg"),
	## 矿工僵尸绝地
	&"digger_zombie": preload("res://pak/sounds/digger_zombie.ogg"),
	## 跳跳僵尸跳跃
	&"pogo_zombie": preload("res://pak/sounds/pogo_zombie.ogg"),
	## 蹦极僵尸入场
	&"bungee_scream":[
		preload("res://pak/sounds/bungee_scream.ogg"),
		preload("res://pak/sounds/bungee_scream2.ogg"),
		preload("res://pak/sounds/bungee_scream3.ogg")
	],
	## 扶梯僵尸放置梯子
	&"ladder_zombie": preload("res://pak/sounds/ladder_zombie.ogg"),
	## 篮球僵尸发射篮球子弹
	&"basketball": preload("res://pak/sounds/basketball.ogg"),

	## 巨人僵尸攻击\倭瓜
	&"gargantuar_thump": preload("res://pak/sounds/gargantuar_thump.ogg"),
	## 巨人僵尸死亡
	&"gargantudeath": preload("res://pak/sounds/gargantudeath.ogg"),
	## 小鬼被抛射
	&"imp":[
		preload("res://pak/sounds/imp.ogg"),
		preload("res://pak/sounds/imp2.ogg")
	],
	## 传送门（迷你游戏「斗转星移」：僵尸 / 子弹进门传出）
	&"Portal":[
		preload("res://pak/sounds/portal.ogg")
	]
}

## 戴夫音效字典
const SFXCarzyDaveMap := {
	## 一秒左右
	&"crazydaveshort" : [
		preload("res://pak/sounds/crazydaveshort1.ogg"),
		preload("res://pak/sounds/crazydaveshort2.ogg"),
		preload("res://pak/sounds/crazydaveshort3.ogg")
	],
	## 两秒左右
	&"crazydavelong" : [
		preload("res://pak/sounds/crazydavelong1.ogg"),
		preload("res://pak/sounds/crazydavelong2.ogg"),
		preload("res://pak/sounds/crazydavelong3.ogg")
	],
	## 三秒左右
	&"crazydaveextralong" : [
		preload("res://pak/sounds/crazydaveextralong1.ogg"),
		preload("res://pak/sounds/crazydaveextralong2.ogg"),
		preload("res://pak/sounds/crazydaveextralong3.ogg")
	],
	&"crazydavecrazy" : [
		preload("res://pak/sounds/crazydavecrazy.ogg")
	],
	&"crazydavescream" : [
		preload("res://pak/sounds/crazydavescream2.ogg"),
		preload("res://pak/sounds/crazydavescream.ogg")
	],
}

## 音效对象池实现
var sfx_bullet_pool = []

func play_sfx_with_pool(sfx_resource: AudioStream) -> AudioStreamPlayer:
	if sfx_resource in curr_frame_sfx:
		return
	curr_frame_sfx.append(sfx_resource)

	var player: AudioStreamPlayer
	# 从池中获取可用播放器
	for p in sfx_bullet_pool:
		if not p.playing:
			player = p
			break

	# 如果没有可用播放器，创建新的
	if not player:
		player = AudioStreamPlayer.new()
		player.bus = AudioServer.get_bus_name(Bus.SFX)
		sfx_all.add_child(player)
		sfx_bullet_pool.append(player)

	## 配置播放器
	player.stream = sfx_resource
	player.play()
	return player

## 播放僵尸受击音效
func play_be_attack_SFX(type_bullet_zombie_sfx:TypeBeAttackSFX):
	var sfx_array: Array = SFXBeAttackMap[type_bullet_zombie_sfx]

	var sfx_selected = sfx_array.pick_random()
	play_sfx_with_pool(sfx_selected)

## 播放子弹攻击音效
func play_bullet_attack_SFX(type_bullet_sfx:TypeBulletSFX):
	var sfx_array: Array = SFXBulletMap[type_bullet_sfx]

	var sfx_selected = sfx_array.pick_random()
	play_sfx_with_pool(sfx_selected)

## 播放植物\僵尸相关音效
## 音效名多来自动画帧事件（play_animation_sfx），字典里查不到时只告警不崩溃，
## 避免一份动画资源引用了未登记的音效就中断整局游戏。
func play_character_SFX(option:StringName):
	if not SFXCharacterMap.has(option):
		Log.warn("SoundManager：SFXCharacterMap 未登记音效 ", option)
		return null
	var sfx_resource:AudioStream
	if SFXCharacterMap[option] is Array:
		sfx_resource = SFXCharacterMap[option].pick_random()
	else:
		sfx_resource = SFXCharacterMap[option]
	var player: AudioStreamPlayer = play_sfx_with_pool(sfx_resource)
	return player


## 播放戴夫音效
func play_crazy_dave_SFX(option:StringName):
	var sfx_array: Array = SFXCarzyDaveMap[option]

	var sfx_selected = sfx_array.pick_random()
	crazy_dave_player.stream = sfx_selected
	crazy_dave_player.play()

## 雷声:雷雨关打闪电时播放(assets/audio/sounds/thunder.ogg)
const THUNDER_SFX: AudioStream = preload("res://pak/sounds/thunder.ogg")

## 雨声:雷雨关循环播放。与 THUNDER_SFX 一样走 preload —— 运行期 load() 会卡帧，
## 且这里原先写的是 uid:// 引用，改资源名后全文搜 res:// 搜不到（见硬约束 1-5）
const RAIN_SFX: AudioStream = preload("res://pak/sounds/rain.ogg")

func play_rain_SFX():
	rain_player.stream = RAIN_SFX
	rain_player.play()

func stop_rain_SFX():
	rain_player.stop()

## 播放雷声(与 MainGameRain 的闪光配合,光在前声在后)
func play_thunder_SFX():
	play_sfx_with_pool(THUNDER_SFX)
#endregion

#region 其余音效
const SFXOtherMap := {
	##-------------------------- 按钮相关 --------------------------
	## 开始菜单点击
	&"gravebutton": preload("res://pak/sounds/gravebutton.ogg"),
	## 鼠标进入开始菜单
	&"bleep":preload("res://pak/sounds/bleep.ogg"),
	##
	&"tap":preload("res://pak/sounds/tap.ogg"),
	## 选项按钮
	&"buttonclick":preload("res://pak/sounds/buttonclick.ogg"),
	## 暂停
	&"pause": preload("res://pak/sounds/pause.ogg"),
	## 点击阳光
	&"points": preload("res://pak/sounds/points.ogg"),
	## 点击金币
	&"coin":preload("res://pak/sounds/coin.ogg"),
	## 掉落花园植物
	&"chime":preload("res://pak/sounds/chime.ogg"),
	##-------------------------- 卡片相关 --------------------------
	&"buzzer":preload("res://pak/sounds/buzzer.ogg"),
	&"seedlift":preload("res://pak/sounds/seedlift.ogg"),
	&"shovel":preload("res://pak/sounds/shovel.ogg"),
	&"tap2":preload("res://pak/sounds/tap2.ogg"),

	##-------------------------- 进度相关 --------------------------
	## 原版 progress 目录下的两条**不同**音效（文件名不同、不是同一条的两种叫法）：
	##   siren  = 汽笛
	##   awooga = 原版"一大波僵尸逼近"的警报音
	## ⚠️ 二者当前在 `src/` 里**都还没有播放点**（只有本表这一处声明），是留着待接线的库存音效，
	##    不是"重复登记" —— 别当成冗余删掉，接线时按上面的口径选。
	&"siren": preload("res://pak/sounds/siren.ogg"),
	&"awooga":preload("res://pak/sounds/awooga.ogg"),
	## 最后一波
	&"finalwave":preload("res://pak/sounds/finalwave.ogg"),
	## 大波僵尸
	&"hugewave":preload("res://pak/sounds/hugewave.ogg"),
	## 失败
	&"losemusic":preload("res://pak/sounds/losemusic.ogg"),
	## 准备安放植物
	&"readysetplant":preload("res://pak/sounds/readysetplant.ogg"),
	## 戴夫尖叫
	&"scream":preload("res://pak/sounds/scream.ogg"),
	## 获胜音效
	&"winmusic":preload("res://pak/sounds/winmusic.ogg"),


	##-------------------------- 主游戏场景物品相关 --------------------------
	## 墓碑生成
	&"gravestone_rumble":preload("res://pak/sounds/gravestone_rumble.ogg"),
	## 植物种植音效
	&"plant1": preload("res://pak/sounds/plant.ogg"),
	## 植物铲除音效
	&"plant2":preload("res://pak/sounds/plant2.ogg"),
	## 植物种植在水上
	&"plant_water": preload("res://pak/sounds/plant_water.ogg"),
	## 僵尸入水音效、水花音效
	&"zombie_entering_water": preload("res://pak/sounds/zombie_entering_water.ogg"),
	## -------- 小推车 --------
	&"lawnmower": preload("res://pak/sounds/lawnmower.ogg"),
	&"pool_cleaner": preload("res://pak/sounds/pool_cleaner.ogg"),
	## -------- 锤子 --------
	&"swing": preload("res://pak/sounds/swing.ogg"),
	&"bonk": preload("res://pak/sounds/bonk.ogg"),
	## -------- 花园 -----------
	&"prize": preload("res://pak/sounds/prize.ogg"),
	## -------- 僵尸出土 ------------
	&"dirt_rise": preload("res://pak/sounds/dirt_rise.ogg"),
	## 主菜单"僵尸手破土"过场里手伸出时的僵尸笑声(原版 EVILLAUGH)
	## 数据来源: 原版解包资源清单 pak/properties/resources.xml
	##           (<Sound id="EVILLAUGH" path="evillaugh" />), 音频本体 pak/sounds/evillaugh.ogg
	&"evillaugh": preload("res://pak/sounds/evillaugh.ogg"),
	## --------- 花瓶破碎     -------------
	&"vase_breaking": preload("res://pak/sounds/vase_breaking.ogg"),


	##-------------------------- 花园相关 --------------------------
	&"watering":preload("res://pak/sounds/watering.ogg"),
	&"fertilizer":preload("res://pak/sounds/fertilizer.ogg"),
	&"bugspray":preload("res://pak/sounds/bugspray.ogg"),
	&"phonograph":preload("res://pak/sounds/phonograph.ogg"),
	&"wakeup": preload("res://pak/sounds/wakeup.ogg"),

}
## 播放其它相关音效
func play_other_SFX(option:StringName):
	var sfx_resource: AudioStream
	if SFXOtherMap[option] is Array:
		sfx_resource = SFXOtherMap[option].pick_random()
	else:
		sfx_resource = SFXOtherMap[option]
	play_sfx_with_pool(sfx_resource)


#endregion

#endregion

#region 按钮信号连接辅助函数
## 更新开始菜单的UI音效
func setup_ui_start_menu_sound(node:Node, is_menu_button:=false):
	if node is BaseButton:
		var button := node
		## 同一节点可能被 setup_ui_*_sound 访问多次，所有连接都要幂等，
		## 否则音效会叠加播放（原来只给 tap 那一行加了守卫）
		var bleep_callback := play_other_SFX.bind("bleep")
		if not button.mouse_entered.is_connected(bleep_callback):
			button.mouse_entered.connect(bleep_callback)

		if is_menu_button:
			var gravebutton_callback := play_other_SFX.bind("gravebutton")
			if not button.button_down.is_connected(gravebutton_callback):
				button.button_down.connect(gravebutton_callback)
		else:
			## 实际连接的是 bind("tap") 后的 Callable，拿裸方法名判断恒为 false，
			## 重复调用本函数会导致音效重复连接
			var tap_callback := play_other_SFX.bind("tap")
			if not button.button_down.is_connected(tap_callback):
				button.button_down.connect(tap_callback)


	for child in node.get_children():
		## 如果是Menu或者其上面的节点为Menu
		if child.name == "Menu" or is_menu_button:
			setup_ui_start_menu_sound(child, true)
		else:
			setup_ui_start_menu_sound(child, false)


## 更新主游戏按钮的UI音效
func setup_ui_main_game_sound(node:Node):
	if node is BaseButton:
		if node is CheckButton:
			var click_callback := play_other_SFX.bind("buttonclick")
			if not node.pressed.is_connected(click_callback):
				node.pressed.connect(click_callback)
		else:
			var gravebutton_callback := play_other_SFX.bind("gravebutton")
			if not node.button_down.is_connected(gravebutton_callback):
				node.button_down.connect(gravebutton_callback)

			if node.name == "Return":
				var return_callback := play_other_SFX.bind("buttonclick")
				if not node.pressed.is_connected(return_callback):
					node.pressed.connect(return_callback)


	for child in node.get_children():
		setup_ui_main_game_sound(child)
#endregion

#region 音量大小调整
func get_volum(bus_index:int):
	var db := AudioServer.get_bus_volume_db(bus_index)
	return db_to_linear(db)

func set_volume(bus_index:int, v:float) ->void:
	var db := linear_to_db(v)
	AudioServer.set_bus_volume_db(bus_index, db)
#endregion
