## 把每个「角色」场景的 AnimationTree 树根统一成同一种结构：
##
##     AnimationNodeBlendTree（树根）
##        ├─ TimeScale      : AnimationNodeTimeScale    ← 速度钩子 parameters/TimeScale/scale
##        └─ StateMachine   : AnimationNodeStateMachine ← playback 钩子 parameters/StateMachine/playback
##
## 做法（两种待改造的场景）：
##   RENO  — 树里已有状态机，只是节点名叫 `AnimationNodeStateMachine` ⇒ 改名为 `StateMachine`
##   WRAP  — 树里只有动画叶子（混合树直挂 Animation）：把 `Animation` 这个节点换成
##           单状态状态机（状态名 = 原动画名），节点名随之改成 `StateMachine`
##
## 用法： python tools/tmp_unify_anim_tree.py [--apply]
##        不带 --apply 只打印计划（dry run）
import os, re, sys, collections

TOOLSDIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLSDIR)

SM_NAME = 'StateMachine'
TS_NAME = 'TimeScale'
OLD_SM_NAMES = ('AnimationNodeStateMachine',)
LEAF_NAME = 'Animation'

APPLY = '--apply' in sys.argv


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def key_of(line):
    """解析 `key = value` 形式的行，返回 (key, value, raw)"""
    s = line.rstrip('\r\n')
    if s.startswith('"'):
        m = re.match(r'"([^"]+)"\s*=\s*(.*)$', s)
        if m:
            return m.group(1), m.group(2), s
        return None, None, s
    if '=' in s:
        k, v = s.split('=', 1)
        return k.strip(), v.strip(), s
    return None, None, s


def find_blocks(lines):
    """返回 [(start, end, type, id)]：每个 sub_resource 块的行区间（end 为块尾之后）"""
    out = []
    n = len(lines)
    i = 0
    while i < n:
        m = re.match(r'\[sub_resource\s+type="([^"]+)"\s+id="([^"]+)"\]\s*$', lines[i])
        if m:
            start = i
            j = i + 1
            while j < n and not lines[j].startswith('['):
                j += 1
            out.append((start, j, m.group(1), m.group(2)))
            i = j
        else:
            i += 1
    return out


def block_of(lines, sid):
    for start, end, typ, bid in find_blocks(lines):
        if bid == sid:
            return start, end, typ
    return None


def subid_of(value):
    m = re.match(r'SubResource\("([^"]+)"\)', value)
    if m:
        return ('sub', m.group(1))
    m = re.match(r'ExtResource\("([^"]+)"\)', value)
    if m:
        return ('ext', m.group(1))
    return (None, None)


def nkey(name, prefix, suffix):
    """key 的「裸」形式（`Animation 2` 这类带空格的名字不带引号，用于比对）"""
    return '%s%s%s' % (prefix, name, suffix)


def qkey(name, prefix, suffix):
    """写 nodes/xxx/node 这类 key：名字里有空格要加引号（与 Godot 序列化一致）"""
    k = nkey(name, prefix, suffix)
    return '"%s"' % k if ' ' in k else k


def uniq(base, taken):
    cand = base
    i = 0
    while cand in taken:
        i += 1
        cand = '%s%d' % (base, i)
    return cand


class Scene:
    def __init__(self, rel):
        self.rel = rel
        self.path = os.path.join(ROOT, rel)
        self.text = read(self.path)
        self.lines = self.text.split('\n')
        self.taken = set(re.findall(r'\[sub_resource\s+type="[^"]+"\s+id="([^"]+)"\]', self.text))

    def save(self):
        with open(self.path, 'w', encoding='utf-8', newline='') as f:
            f.write('\n'.join(self.lines))

    def bump_load_steps(self, delta):
        for i, ln in enumerate(self.lines):
            if ln.startswith('[gd_scene') and 'load_steps=' in ln:
                self.lines[i] = re.sub(r'load_steps=(\d+)', lambda m: 'load_steps=%d' % (int(m.group(1)) + delta), ln)
                return True
        return False

    def insert_block(self, before_idx, text_lines):
        self.lines[before_idx:before_idx] = text_lines


## ── 解析「哪些树要改造」 ────────────────────────────────────────────────
def plan_scene(rel):
    sc = Scene(rel)
    text = sc.text
    # 场景里有 AnimComponent 且脚本最终解析到 component_anim_norm.gd ⇒ 这才是「角色」
    if not uses_norm_component(rel, text):
        return None
    plans = []
    for bid in root_tree_ids(text):
        res = plan_tree(sc, text, bid)
        if res:
            plans.append(res)
    if not plans:
        return None
    return {'scene': sc, 'plans': plans}


def uses_norm_component(rel, text):
    """沿 instance 链找出 AnimComponent 最终挂的脚本是不是 component_anim_norm.gd"""
    chain = rel
    seen = set()
    while True:
        if chain in seen:
            return False
        seen.add(chain)
        p = os.path.join(ROOT, chain)
        if not os.path.exists(p):
            return False
        t = read(p)
        # 本层是否 override AnimComponent 的 script
        m = re.search(r'\[node\s+name="AnimComponent"([^\]]*)\](.*?)(?=\n\[|\Z)', t, re.S)
        if m and re.search(r'^\s*script\s*=', m.group(2), re.M):
            mm = re.search(r'script\s*=\s*ExtResource\("([^"]+)"\)', m.group(2))
            if mm:
                em = re.search(r'\[ext_resource\s+type="Script"[^\]]*id="%s"\]' % re.escape(mm.group(1)), t)
                if em:
                    pm = re.search(r'path="([^"]+)"', em.group(0))
                    return bool(pm) and pm.group(1).endswith('component_anim_norm.gd')
            return False
        # 往上找根 instance（头里没有 parent=、带 instance= 的那个节点便是场景根）
        for hm in re.finditer(r'\[node\s+([^\]]*)\]', t):
            head = hm.group(1)
            if 'parent=' in head:
                continue
            rm = re.search(r'instance=ExtResource\("([^"]+)"\)', head)
            if rm:
                break
        else:
            rm = None
        if not rm:
            return False
        em = re.search(r'\[ext_resource\s+type="PackedScene"[^\]]*id="%s"\]' % re.escape(rm.group(1)), t)
        if not em:
            return False
        pm = re.search(r'path="([^"]+)"', em.group(0))
        if not pm:
            return False
        nxt = pm.group(1)
        if not nxt.startswith('res://'):
            return False
        chain = nxt[len('res://'):]


def root_tree_ids(text):
    """只取「真的挂在 AnimationTree.tree_root 上」的那棵树（树内的子混合树不算）"""
    ids = []
    for nm in re.finditer(r'\[node\s+[^\]]*type="AnimationTree"[^\]]*\](.*?)(?=\n\[|\Z)', text, re.S):
        body = nm.group(1)
        tm = re.search(r'^\s*tree_root\s*=\s*SubResource\("([^"]+)"\)', body, re.M)
        if tm:
            ids.append(tm.group(1))
    return ids


def plan_tree(sc, text, bid):
    start, end, typ = block_of(sc.lines, bid)
    body = sc.lines[start + 1:end]
    nodes = {}
    for i in range(start + 1, end):
        k, v, _ = key_of(sc.lines[i])
        if k and k.startswith('nodes/') and k.endswith('/node'):
            nodes[k[len('nodes/'):-len('/node')]] = v
    params = None
    for i in range(start + 1, end):
        k, v, _ = key_of(sc.lines[i])
        if k == 'node_connections':
            params = v
    if SM_NAME in nodes:
        return None  # 已经合规
    for old in OLD_SM_NAMES:
        if old in nodes:
            if nodes[old] and 'AnimationNodeStateMachine' in nodes[old]:
                return {'kind': 'RENO', 'block': (start, end, bid), 'old': old}
    else:
        leaf = pick_leaf(sc, start, end, bid)
        if leaf is None:
            return {'kind': 'UNSUPPORTED', 'block': (start, end, bid), 'nodes': sorted(nodes)}
        kind, aid = subid_of(nodes[leaf])
        anim = None
        if kind == 'sub':
            ast, aen, at = block_of(sc.lines, aid)
            if at != 'AnimationNodeAnimation':
                return {'kind': 'UNSUPPORTED', 'block': (start, end, bid),
                        'nodes': ['%s(not AnimationNodeAnimation)' % leaf]}
            for i in range(ast + 1, aen):
                k, v, _ = key_of(sc.lines[i])
                if k == 'animation':
                    anim = v
        return {'kind': 'WRAP', 'block': (start, end, bid), 'leaf': leaf, 'leaf_id': aid,
                'leaf_kind': kind, 'anim': anim}
    return {'kind': 'UNSUPPORTED', 'block': (start, end, bid), 'nodes': sorted(nodes)}


## ★ 选「主干动画叶子」：从 TimeScale 顺着 port 0 一路下钻到第一个动画叶子
##
## ⚠️ 为什么不能一律取名为 `Animation` 的那个节点：`plant_pea_shooter_single` 这类树里
##   `Animation`（Head_Attack）挂在 OneShot 的 **port 1** 上，OneShot 没被 request 触发时
##   这条链路**根本不被处理** —— 包出来的状态机会永远停在 Start（实测验证：headless 探针里
##   该场景 `get_current_node()` 恒为 `"Start"`）。顺着 port 0 找才能拿到**一直在播**的那条。
def pick_leaf(sc, start, end, bid):
    nodes, conns = {}, None
    for i in range(start + 1, end):
        k, v, _ = key_of(sc.lines[i])
        if k and k.startswith('nodes/') and k.endswith('/node'):
            nodes[k[len('nodes/'):-len('/node')]] = v
        elif k == 'node_connections':
            conns = v
    if conns is None:
        return None
    consumer = {}  # 消费节点 -> [(自己的输入端口, 供给它的节点)]
    for tm in re.finditer(r'&"([^"]+)"\s*,\s*(\d+)\s*,\s*&"([^"]+)"', conns):
        consumer.setdefault(tm.group(1), {})[int(tm.group(2))] = tm.group(3)
    cur, seen = TS_NAME, set()
    while True:
        if cur in seen or cur not in consumer or 0 not in consumer[cur]:
            return None
        seen.add(cur)
        nxt = consumer[cur][0]
        kind, aid = subid_of(nodes.get(nxt, ''))
        ast, aen, at = block_of(sc.lines, aid) if kind == 'sub' else (None, None, None)
        if at == 'AnimationNodeAnimation':
            return nxt
        if at is None:
            return None
        cur = nxt


## ── 执行改造 ───────────────────────────────────────────────────────────
def apply_plan(entry):
    sc = entry['scene']
    total_added = 0
    for pl in entry['plans']:
        total_added += apply_tree(sc, pl)
    if total_added:
        sc.bump_load_steps(total_added)
    return total_added


def apply_tree(sc, pl):
    start, end, bid = pl['block']
    if pl['kind'] == 'RENO':
        old = pl['old']
        for i in range(start + 1, end):
            k, v, raw = key_of(sc.lines[i])
            if k is None:
                continue
            if k == nkey(old, 'nodes/', '/node'):
                sc.lines[i] = '%s = %s' % (qkey(SM_NAME, 'nodes/', '/node'), v)
            elif k == nkey(old, 'nodes/', '/position'):
                sc.lines[i] = '%s = %s' % (qkey(SM_NAME, 'nodes/', '/position'), v)
            elif k == 'node_connections':
                sc.lines[i] = raw.replace('&"%s"' % old, '&"%s"' % SM_NAME)
        return 0

    if pl['kind'] == 'WRAP':
        leaf = pl['leaf']
        anim = (pl['anim'] or '').strip()
        mm = re.match(r'&?"([^"]+)"', anim) or re.match(r'&?(\S+)', anim)
        state = mm.group(1) if mm else 'Idle'
        base = bid.split('_', 1)[-1]
        smid = uniq('AnimationNodeStateMachine_%s' % base, sc.taken)
        sc.taken.add(smid)
        trid = uniq('AnimationNodeStateMachineTransition_%s' % base, sc.taken)
        sc.taken.add(trid)

        for i in range(start + 1, end):
            k, v, raw = key_of(sc.lines[i])
            if k is None:
                continue
            if k == nkey(leaf, 'nodes/', '/node'):
                sc.lines[i] = '%s = SubResource("%s")' % (qkey(SM_NAME, 'nodes/', '/node'), smid)
            elif k == nkey(leaf, 'nodes/', '/position'):
                sc.lines[i] = '%s = %s' % (qkey(SM_NAME, 'nodes/', '/position'), v)
            elif k == 'node_connections':
                sc.lines[i] = raw.replace('&"%s"' % leaf, '&"%s"' % SM_NAME)

        new_blocks = [
            '[sub_resource type="AnimationNodeStateMachineTransition" id="%s"]' % trid,
            'advance_mode = 2',
            '',
            '[sub_resource type="AnimationNodeStateMachine" id="%s"]' % smid,
            '%s = %s' % (qkey(state, 'states/', '/node'),
                         ('%s("%s")' % ('SubResource' if pl['leaf_kind'] == 'sub' else 'ExtResource', pl['leaf_id']))),
            '%s = %s' % (qkey(state, 'states/', '/position'), 'Vector2(300, 100)'),
            'transitions = ["Start", "%s", SubResource("%s")]' % (state, trid),
            '',
        ]
        sc.insert_block(start, new_blocks)
        return 2
    return 0


def main():
    scenes = []
    for dirpath, dirnames, filenames in os.walk(os.path.join(ROOT, 'src')):
        for f in filenames:
            if f.endswith('.tscn'):
                scenes.append(os.path.relpath(os.path.join(dirpath, f), ROOT).replace('\\', '/'))
    scenes.sort()

    counts = collections.Counter()
    rows = []
    for rel in scenes:
        ent = plan_scene(rel)
        if not ent:
            continue
        for pl in ent['plans']:
            counts[pl['kind']] += 1
            rows.append((rel, pl))
        if APPLY:
            apply_plan(ent)
            ent['scene'].save()

    print('kind counts:', dict(counts))
    print()
    for rel, pl in rows:
        extra = pl.get('anim') or pl.get('old') or ','.join(pl.get('nodes', []))
        print('%-6s %-62s root=%-34s leaf=%-14s %s' % (
            pl['kind'], rel, pl['block'][2], pl.get('leaf', '-'), extra))
    print()
    print('scenes touched:', len(set(r[0] for r in rows)))
    print('APPLIED' if APPLY else 'dry-run (no file written)')


if __name__ == '__main__':
    main()
