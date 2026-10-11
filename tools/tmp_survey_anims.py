## 测绘全仓 .tscn 里 AnimationTree 的树结构，以及该场景最终用的是哪个动画组件脚本
import os, re, json, collections

TOOLSDIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLSDIR)

ext_scene_re = re.compile(r'\[ext_resource\s+type="PackedScene"[^)]*?uid="([^"]+)"[^)]*?path="([^"]+)"[^)]*?id="([^"]+)"', re.S)
ext_script_re = re.compile(r'\[ext_resource\s+type="Script"[^)]*?uid="([^"]+)"[^)]*?path="([^"]+)"[^)]*?id="([^"]+)"', re.S)
ext_res_re   = re.compile(r'\[ext_resource\s+type="(\w+)"[^)]*?uid="([^"]+)"[^)]*?path="([^"]+)"[^)]*?id="([^"]+)"', re.S)

def load_scene_info(path):
    """返回 (scene ext scripts dict, packed-instance ext map, ext resource map, text)"""
    try:
        txt = open(path, encoding='utf-8').read()
    except Exception as e:
        return None
    return txt

def parse(path):
    txt = load_scene_info(path)
    if txt is None:
        return None
    info = {
        'path': os.path.relpath(path, ROOT).replace('\\', '/'),
        'text': txt,
        'scene_ext': {},   # id -> res path
        'res_ext': {},     # id -> (type, path)
        'sub_types': {},   # sub id -> type
        'sub_fields': {},  # sub id -> list of (key, value)
        'nodes': [],       # (name, type, parent, instance_id, props dict)
    }
    for m in ext_res_re.finditer(txt):
        info['res_ext'][m.group(4)] = (m.group(1), m.group(3))
    # sub resources
    sub_re = re.compile(r'\[sub_resource\s+type="(\w+)"\s+id="([^"]+)"\](.*?)(?=\n\[(?:sub_resource|node|ext_resource|connection|gd_scene)|\Z)', re.S)
    for m in sub_re.finditer(txt):
        sid = m.group(2)
        info['sub_types'][sid] = m.group(1)
        fields = []
        for line in m.group(3).splitlines():
            line = line.strip()
            if not line or line.startswith(';'):
                continue
            if '=' in line:
                k, v = line.split('=', 1)
                fields.append((k.strip(), v.strip()))
        info['sub_fields'][sid] = fields
    # nodes
    node_re = re.compile(r'\[node\s+([^\]]*)\](.*?)(?=\n\[(?:node|connection|sub_resource|ext_resource)|\Z)', re.S)
    for m in node_re.finditer(txt):
        head = m.group(1)
        body = m.group(2)
        name = None; typ = None; parent = None; inst = None
        for tok in re.findall(r'(\w+)\s*=\s*("(?:[^"\\]|\\.)*"|\S+)', head):
            pass
        nm = re.search(r'\bname="([^"]+)"', head)
        if nm: name = nm.group(1)
        tp = re.search(r'\btype="([^"]+)"', head)
        if tp: typ = tp.group(1)
        pa = re.search(r'\bparent="([^"]*)"', head)
        if pa: parent = pa.group(1)
        it = re.search(r'\binstance=ExtResource\("([^"]+)"\)', head)
        if it: inst = it.group(1)
        props = {}
        for line in body.splitlines():
            line = line.strip()
            if not line or line.startswith(';'):
                continue
            if '=' in line:
                k, v = line.split('=', 1)
                props[k.strip()] = v.strip()
        info['nodes'].append({'name': name, 'type': typ, 'parent': parent, 'instance': inst, 'props': props})
    return info

# gather all scenes
all_scenes = {}
for dirpath, dirnames, filenames in os.walk(os.path.join(ROOT, 'src')):
    for f in filenames:
        if f.endswith('.tscn'):
            p = os.path.join(dirpath, f)
            i = parse(p)
            if i:
                all_scenes[i['path']] = i

def resolve_res_ref(info, val):
    """把 SubResource("x") / ExtResource("x") 解析成 (kind, id)"""
    m = re.match(r'SubResource\("([^"]+)"\)', val)
    if m: return ('sub', m.group(1))
    m = re.match(r'ExtResource\("([^"]+)"\)', val)
    if m: return ('ext', m.group(1))
    return (None, None)

def describe_tree(info, root_ref):
    """返回 (kind, detail)"""
    kind, rid = root_ref
    if kind == 'sub':
        t = info['sub_types'].get(rid)
        if t == 'AnimationNodeStateMachine':
            return ('StateMachineRoot', t)
        if t == 'AnimationNodeBlendTree':
            names = set()
            mapping = {}
            for k, v in info['sub_fields'].get(rid, []):
                mm = re.match(r'nodes/([^/]+)/node$', k)
                if mm:
                    names.add(mm.group(1))
                    kk, vv = resolve_res_ref(info, v)
                    subT = None
                    if kk == 'sub':
                        subT = info['sub_types'].get(vv)
                    elif kk == 'ext':
                        subT = 'EXT:' + info['res_ext'].get(vv, ('?','?'))[1].rsplit('/',1)[-1]
                    mapping[mm.group(1)] = subT
            return ('BlendTree', mapping)
        return ('Other', t)
    elif kind == 'ext':
        p = info['res_ext'].get(rid, ('?','?'))[1]
        return ('ExtRoot', p)
    return ('None', None)

# 解析继承链上 AnimComponent 的脚本
def anim_component_script(scene_path, chain=None):
    info = all_scenes.get(scene_path)
    if info is None:
        return None, []
    if chain is None: chain = []
    chain = chain + [scene_path]
    # 本场景是否 override AnimComponent script
    override = None
    for n in info['nodes']:
        if n['name'] == 'AnimComponent' and 'script' in n['props']:
            v = n['props']['script']
            k, rid = resolve_res_ref(info, v)
            if k == 'ext':
                override = info['res_ext'].get(rid, ('?','?'))[1]
    if override:
        return override, chain
    # 往上找 instanced 的 PackedScene
    for n in info['nodes']:
        if n['instance'] and n['parent'] is None:
            base_path = info['res_ext'].get(n['instance'], ('?','?'))[1]
            if base_path.startswith('res://'):
                base_path = base_path[len('res://'):]
                if base_path in all_scenes:
                    return anim_component_script(base_path, chain)
    return None, chain

rows = []
for path, info in sorted(all_scenes.items()):
    for n in info['nodes']:
        if n['type'] == 'AnimationTree' and 'tree_root' in n['props']:
            k, d = describe_tree(info, resolve_res_ref(info, n['props']['tree_root']))
            comp, chain = anim_component_script(path)
            # 取出 anim_player / parameters 关键字
            params = sorted(set(re.findall(r'^parameters/([^/=]+)/', '\n'.join(
                '%s = %s' % (a,b) for a,b in n['props'].items()), re.M)))
            rows.append({
                'scene': path, 'node': n['name'], 'kind': k, 'detail': d,
                'comp': (comp.rsplit('/',1)[-1] if comp else None),
                'params': params,
                'chain': chain,
            })

print('total animation trees:', len(rows))
summary = collections.Counter()
for r in rows:
    if r['kind'] == 'BlendTree':
        sm = [k2 for k2, v in r['detail'].items() if v == 'AnimationNodeStateMachine']
        key = 'BlendTree/' + ('SM:' + ','.join(sorted(sm)) if sm else 'noSM:' + ','.join(sorted(r['detail'])))
    else:
        key = r['kind']
    summary[(key, r['comp'])] += 1

print()
for k, v in sorted(summary.items(), key=lambda x: -x[1]):
    print(v, '|', k[0], '| comp=', k[1])

print('\n=== 明细 ===')
for r in rows:
    if r['kind'] == 'BlendTree':
        det = '; '.join('%s=%s' % (a, b) for a, b in sorted(r['detail'].items()))
    else:
        det = str(r['detail'])
    print('%-70s %-16s %-14s %-28s %s' % (r['scene'], r['node'], r['kind'], det, r['comp']))
