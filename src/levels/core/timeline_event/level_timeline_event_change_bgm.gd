extends ResourceLevelTimelineEvent
class_name LevelTimelineEventChangeBgm
## 切换背景音乐：走到这一份事件就当场换曲，**不等任何条件**（换完立刻走下一个事件）
##
## 参数：
##   bgm —— 换成哪一首，取值见 ConstLevelData.GameBGM（与关卡数据 ResourceLevelData.game_BGM 同口径）
##          NoBGM = 停掉音乐（本段要留白时就用这个）
##   keep_as_main_game_bgm —— true（默认）= 连本关的主游戏 BGM 一起换，见下面的坑
##
## **为什么要改 main_game.bgm_main_game**：MainGameManager 在开战一秒后会播一次主游戏 BGM
## （`await 1 秒 -> SoundManager.play_bgm(bgm_main_game)`），下一轮重新开局时也会重播它 --
## 只调 `play_bgm()` 不改字段，本事件换好的曲会被这两次重播盖回去。
## 同步了字段之后，换曲就等于把「本关接下来放什么」改掉，后面自然接着放新曲。
##
## **不要用本事件去设关卡开场曲**：开场曲写在关卡数据的 `game_BGM` 上，改那儿就够。
## 本事件是给关卡**中途**换曲用的（进场时的紧张曲 -> 开打的战斗曲 -> Boss 曲）。

## 换成哪一首（GameBGM.NoBGM = 停掉音乐）
@export var bgm: ConstLevelData.GameBGM = ConstLevelData.GameBGM.FrontDay

## 是否连本关主游戏 BGM 一起换（关掉的话，开战时会被本关原曲盖回去）
@export var keep_as_main_game_bgm: bool = true


func run(main_game: MainGameManager) -> void:
	if not is_instance_valid(main_game):
		return
	var stream := load_bgm_stream()
	if keep_as_main_game_bgm:
		main_game.bgm_main_game = stream
	SoundManager.play_bgm(stream)


## 按 GameBGM 取出音频资源；NoBGM / 路径为空时返回 null（交给 SoundManager 停掉音乐）
func load_bgm_stream() -> AudioStream:
	var path_bgm: String = ConstLevelData.GameBGMMap.get(bgm, "")
	if path_bgm.is_empty():
		return null
	return load(path_bgm) as AudioStream
