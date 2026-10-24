"""从 pak/reanim/treeofWisdom.reanim 生成智慧树的 51 档 Godot 动画（带帧间运动）。

为什么不用 R2Ga 直接转：转换器一次最多吃 ~49 段动画，51 段会 0xC0000005 崩溃，
所以 2026-10-24 那轮是拆两批转再改名 + 对每条轨道只留最终帧（"定妆"）压到 3.3MB，
结果**施肥时的拉伸动画没了**。本脚本改成直接从 reanim 的 XML 里按动画区间取每一帧，
只为"值真的变了"的帧写关键帧，体积和单帧版接近，但运动保留。

用法：
    python tools/gen_tree_wisdom_anims.py            # 只体检，不写文件
    python tools/gen_tree_wisdom_anims.py --write    # 覆盖 animation/garden/tree_of_wisdom/treeofWisdom_growN.tres

口径（对照原版 Challenge::TreeOfWisdomInit / Grow）：
    · 每段动画的帧区间由 reanim 里 `anim_growN` 标记轨道给出：`<f>0</f>` 那帧是开头，
      该轨道下一个 `<f>-1</f>` 的前一帧是结尾；
    · 部件帧是**继承**语义：<t/> 什么都不改；<t><y>..</y></t> 只改 y；<f>-1</f> = 这帧不画；<i>..</i> = 换成这张图并显示；
    · 坐标是**贴图左上角**（不是中心），所以场景里的 Sprite2D 必须 centered=false；
      kx / ky 是角度（度），Godot 侧 rotation = deg2rad(kx)、skew = deg2rad(ky - kx)；
    · 动画长度 = (末帧 - 首帧) / fps，原版播放速率 8 帧/秒（见 TreeOfWisdomGrow 的 PlayReanim(..., 8.0f)）。
"""

import os
import re
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REANIM = os.path.join(ROOT, 'pak', 'reanim', 'treeofWisdom.reanim')
OUT_DIR = os.path.join(ROOT, 'animation', 'garden', 'tree_of_wisdom')
PREFIX = 'treeofWisdom_grow'
STAGE_COUNT = 51
NODE_PROPS = ('visible', 'position', 'rotation', 'scale', 'skew', 'texture', 'self_modulate')


def load_reanim():
    text = open(REANIM, encoding='utf-8', errors='replace').read()
    root = ET.fromstring('<root>' + text + '</root>')
    fps = float(root.findtext('fps'))
    tracks = root.findall('track')
    return fps, tracks


def anim_ranges(tracks):
    """anim_growN -> (首帧, 末帧)，来自标记轨道的 <f>0</f> / <f>-1</f>"""
    ranges = {}
    for tr in tracks:
        name = tr.findtext('name') or ''
        if not name.startswith('anim_grow'):
            continue
        stage = int(name[len('anim_grow'):])
        frames = tr.findall('t')
        start = None
        end = None
        for i, f in enumerate(frames):
            v = f.findtext('f')
            if v is None:
                continue
            if start is None and int(v) == 0:
                start = i
            elif start is not None and int(v) == -1:
                end = i - 1
                break
        if start is None:
            raise SystemExit('标记轨道 %s 的区间读不出来' % name)
        if end is None:
            ## 最后一段（anim_grow51）后面没有收尾的 -1，区间一直到轨道末尾
            end = len(frames) - 1
        ranges[stage] = (start, end)
    missing = [n for n in range(1, STAGE_COUNT + 1) if n not in ranges]
    if missing:
        raise SystemExit('缺动画段: %s' % missing)
    return ranges


def node_name_for(track_name, seen):
    """reanim 轨道名 -> Godot 节点名：首字母大写，重名追加 _dup2/_dup3...（与既有产物一致）"""
    base = track_name[:1].upper() + track_name[1:]
    seen[track_name] = seen.get(track_name, 0) + 1
    if seen[track_name] == 1:
        return base
    return '%s_dup%d' % (base, seen[track_name])


def part_tracks(tracks):
    """(节点名, 轨道) 列表；跳过 bg（没有对应贴图，页面自带 tree_bg.jpg）"""
    seen = {}
    out = []
    for tr in tracks:
        name = tr.findtext('name') or ''
        if name.startswith('anim_') or name == 'bg':
            continue
        out.append((node_name_for(name, seen), tr))
    return out


def frame_states(track, upto):
    """把一条部件轨道展开成逐帧状态（继承语义）"""
    ## <f> 省略时原版默认是 0（有图）；<f>-1> 才是"这帧不画"
    cur = {'x': 0.0, 'y': 0.0, 'sx': 1.0, 'sy': 1.0, 'kx': 0.0, 'ky': 0.0,
           'frame': 0.0, 'img': None}
    states = []
    frames = track.findall('t')
    for i, f in enumerate(frames):
        if i > upto:
            break
        for child in f:
            tag = child.tag
            text = (child.text or '').strip()
            if tag == 'i':
                cur['img'] = text
            elif tag == 'f':
                cur['frame'] = float(text)
            else:
                cur[tag] = float(text)
        states.append(dict(cur))
    while len(states) <= upto:
        states.append(dict(cur))
    return states


def existing_textures():
    """节点名 -> 贴图路径（从既有产物里读，保证与场景里的贴图一致）"""
    mapping = {}
    for stage in range(1, STAGE_COUNT + 1):
        path = os.path.join(OUT_DIR, '%s%d.tres' % (PREFIX, stage))
        if not os.path.exists(path):
            continue
        text = open(path, encoding='utf-8').read()
        by_id = dict((tid, path) for path, tid in
                     re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', text))
        for m in re.finditer(r'path = NodePath\("([^:]+):texture"\)', text):
            n = re.search(r'ExtResource\("([^"]+)"\)', text[m.end():])
            if n and n.group(1) in by_id:
                mapping.setdefault(m.group(1), by_id[n.group(1)])
    return mapping


def image_to_path(img_name, node):
    """IMAGE_REANIM_XXX -> 仓库里的贴图路径
    命名规律就是「去掉 IMAGE_REANIM_ 前缀、转小写」；tree6~9 / tree_overlay8~9 / tree_grass
    几个大图在 assets_custom 里（JPG+掩膜烘出来的），所以两个目录都找。
    不按节点名查旧产物：重名轨道的 _dupN 编号不保证与 R2Ga 一致，按节点查会串图。
    """
    stem = img_name.replace('IMAGE_REANIM_', '').lower()
    for cand in ('pak/reanim/%s.png' % stem, 'assets_custom/reanim/%s.png' % stem):
        if os.path.exists(os.path.join(ROOT, cand)):
            return 'res://' + cand
    raise SystemExit('找不到贴图: %s（节点 %s）' % (img_name, node))


def fmt(v):
    return '%.6f' % v


def emit_keys(times, values):
    return ('{\n"times": PackedFloat32Array(%s),\n'
            '"transitions": PackedFloat32Array(%s),\n'
            '"update": 0,\n'
            '"values": [%s]\n}\n'
            % (', '.join(fmt(t) for t in times),
               ', '.join('1.0' for _ in times),
               ', '.join(values)))


def build_stage(stage, lo, hi, fps, parts, write):
    tracks_text = []
    textures = {}
    track_index = 0
    for node, track in parts:
        states = frame_states(track, hi)
        visible = [s['frame'] >= 0.0 for s in states]
        img = states[hi]['img']
        if img is None:
            continue  # 到这段末尾还没出现过的部件不写轨道（跟 R2Ga 一致：它连 visible=false 的部件也写，保证状态是完整的）
        tex_path = image_to_path(img, node)
        if tex_path not in textures:
            textures[tex_path] = 't%d' % len(textures)

        ## 这一段之前是隐藏的部件：它现在的坐标是"没定义"的 (0,0)，
        ## 如果照抄成关键帧，Godot 会从 (0,0) 线性插值到出场坐标 —— 画面就是
        ## "新贴图从左下角/左上角平移过来"。所以隐藏期一律用出场那帧的姿态顶住。
        first_vis = None
        for i in range(lo, hi + 1):
            if visible[i]:
                first_vis = i
                break
        appeared_late = first_vis is not None and not visible[lo]
        if appeared_late:
            hold = dict(states[first_vis])
            for i in range(lo, first_vis):
                states[i] = dict(hold)
                visible[i] = False

        # 逐属性：只在值发生变化的那一帧写关键帧（线性插值下与逐帧写等价）
        series = {
            'visible': [(visible[i], i) for i in range(lo, hi + 1)],
            'position': [((states[i]['x'], states[i]['y']), i) for i in range(lo, hi + 1)],
            'rotation': [((states[i]['kx'],), i) for i in range(lo, hi + 1)],
            'scale': [((states[i]['sx'], states[i]['sy']), i) for i in range(lo, hi + 1)],
            'skew': [((states[i]['ky'] - states[i]['kx'],), i) for i in range(lo, hi + 1)],
        }
        for prop in ('visible', 'position', 'rotation', 'scale', 'skew'):
            raw = series[prop]
            keys = []
            last = object()
            for value, i in raw:
                if value != last:
                    ## bool 轨道在 Godot 里也走插值：false@t0 → true@t1 会在**中点**就翻成 true，
                    ## 于是贴图会比坐标早半段出现（这正是"平移过来"的观感）。做法跟 R2Ga 一样：
                    ## 在切换前一帧再放一次旧值，把跳变压进 1 帧内。
                    if prop == 'visible' and keys and i - 1 > keys[-1][1]:
                        keys.append((last, i - 1))
                    keys.append((value, i))
                    last = value
            if not keys or keys[0][1] != lo:
                keys.insert(0, (raw[0][0], lo))
            ## 出场那一帧再钉一个关键帧：否则运动会从隐藏期的"顶住值"就开始插值，
            ## 露头时已经挪了一点（虽然只有几像素，但配合贴图切换会看出滑入）
            if prop != 'visible' and appeared_late and not any(k[1] == first_vis for k in keys):
                keys.append((raw[first_vis - lo][0], first_vis))
                keys.sort(key=lambda kv: kv[1])
            times = [(i - lo) / fps for _, i in keys]
            values = []
            for value, _ in keys:
                if prop == 'visible':
                    values.append('true' if value else 'false')
                elif prop == 'position':
                    values.append('Vector2(%s, %s)' % (fmt(value[0]), fmt(value[1])))
                elif prop == 'rotation':
                    values.append(fmt(r2d(value[0])))
                elif prop == 'scale':
                    values.append('Vector2(%s, %s)' % (fmt(value[0]), fmt(value[1])))
                else:
                    values.append(fmt(r2d(value[0])))
            tracks_text.append(track_block(track_index, '%s:%s' % (node, prop), emit_keys(times, values)))
            track_index += 1
        tracks_text.append(track_block(track_index, '%s:texture' % node,
                                       emit_keys([0.0], ['ExtResource("%s")' % textures[tex_path]])))
        track_index += 1
        tracks_text.append(track_block(track_index, '%s:self_modulate' % node,
                                       emit_keys([0.0], ['Color(1, 1, 1, 1)'])))
        track_index += 1

    head = ['[gd_resource type="Animation"]', '']
    for tex_path, tid in textures.items():
        head.append('[ext_resource type="Texture2D" path="%s" id="%s"]' % (tex_path, tid))
    head.append('')
    head.append('[resource]')
    head.append('resource_name = "%s%d"' % (PREFIX, stage))
    head.append('length = %.6f' % ((hi - lo) / fps))
    head.append('step = %.6f' % (1.0 / fps))
    head.append('')
    content = '\n'.join(head) + '\n' + '\n'.join(tracks_text)

    if write:
        dst = os.path.join(OUT_DIR, '%s%d.tres' % (PREFIX, stage))
        open(dst, 'w', encoding='utf-8', newline='\n').write(content)
    return len(tracks_text), len(textures), (hi - lo) / fps


def r2d(deg):
    return deg * 3.141592653589793 / 180.0


def track_block(index, path, keys):
    return ('tracks/%d/type = "value"\n'
            'tracks/%d/imported = false\n'
            'tracks/%d/enabled = true\n'
            'tracks/%d/path = NodePath("%s")\n'
            'tracks/%d/interp = 1\n'
            'tracks/%d/loop_wrap = true\n'
            'tracks/%d/keys = %s\n'
            % (index, index, index, index, path, index, index, index, keys))


def main():
    write = '--write' in sys.argv
    fps, tracks = load_reanim()
    ranges = anim_ranges(tracks)
    parts = part_tracks(tracks)
    print('reanim fps=%s 部件轨道=%d' % (fps, len(parts)))
    if '--check-tex' in sys.argv:
        ## 交叉核对：按图片名解析出的贴图 vs 旧产物里同名节点用的贴图
        ##（重名轨道的 _dupN 编号不保证一致，所以 _dup 节点只列出来不算错）
        old = existing_textures()
        last = max(hi for _, hi in ranges.values())
        bad = []
        for node, track in parts:
            img = frame_states(track, last)[last]['img']
            if img is None or node not in old:
                continue
            path = image_to_path(img, node)
            if path != old[node] and '_dup' not in node:
                bad.append((node, old[node], path))
        print('贴图交叉核对：不一致（非 _dup 节点）= %d' % len(bad))
        for b in bad[:10]:
            print('  ', b)
    total_tracks = 0
    for stage in range(1, STAGE_COUNT + 1):
        lo, hi = ranges[stage]
        n_tracks, n_tex, length = build_stage(stage, lo, hi, fps, parts, write)
        total_tracks += n_tracks
        if stage in (1, 2, 3, 12, 25, 50, 51):
            print('  grow%-2d 帧 %d..%d  %.3fs  轨道=%d 贴图=%d' % (stage, lo, hi, length, n_tracks, n_tex))
    print('共 %d 条轨道  %s' % (total_tracks, '已写入' if write else '（体检模式，未写文件）'))


if __name__ == '__main__':
    main()
