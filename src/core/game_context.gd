extends RefCounted
class_name GameContext
## 「当前这一局」的上下文：目前只有主游戏一个成员
##
## 为什么把 `main_game` 从 Global 里挪出来单独放：
## Global 混着两类东西 ——
##   ① **跨场景持久态**（存档 / 配置 / 解锁）：单例是它的正确形态，不动；
##   ② **当前局上下文**（正在跑的这一局 MainGameManager）：它随关卡生灭，
##      却被 37 个文件当全局单例直连（`Global.main_game`），是真正的污染面。
## 本类把 ② 单独拎出来，做成一个**静态持有者**（不新增 autoload，避免第 10 个单例）。
##
## 生命周期由 MainGameManager 自己维护（见它的 `_enter_tree` / `_exit_tree`）：
##   进树登记、出树且还是自己时清空 —— 避免切场景后残留野指针。
##
## **分层纪律**：
##   - 角色 / 子弹 / 组件 → 用各自基类提供的 `get_main_game()`，它转问本类；
##   - 别处**不要**再直接写 `Global.main_game`（`Global.main_game` 现在是本类的转发，
##     见 global.gd，留着是为了存量代码，新代码请走这里）。
##
## 将来的方向：把「谁是当前局」改成由 MainGameManager 向下注入，而不是全局查。
## 到那时只要改「谁给这个字段赋值」，实体层的三个访问器一行都不用动 —— 这正是
## 把它收成一处的目的（架构总览 §5.3：注入式改造的单点）。

## 当前这一局的主游戏；不在关卡内时为 null（展示态：图鉴 / 卡片预览 / 花园）
static var curr_main_game: MainGameManager = null


## 是否正处在某一局里（比到处写 `xxx != null` 可读，也避免漏判已释放实例）
static func is_in_main_game() -> bool:
	return is_instance_valid(curr_main_game)
