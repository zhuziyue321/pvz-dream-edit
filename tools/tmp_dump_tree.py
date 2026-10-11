## 按场景 dump AnimationTree 树（含每个子节点类型与连线）
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def parse(path):
    txt = open(path, encoding='utf-8').read()
    res_ext = {}
    for m in re.finditer(r'\[ext_resource\s+type="(\w+)"[^)]*?uid="([^"]+)"[^)]*?path="([^"]+)"[^)]*?id="([^"]+)"', txt, re.S):
        res_ext[m.group(4)] = (m.group(1), m.group(3))
    sub_types, sub_fields = {}, {}
    for m in re.finditer(r'\[sub_resource\s+type="(\w+)"\s+id="([^"]+)"\](.*?)(?=\n\[(?:sub_resource|node|ext_resource|connection|gd_scene)|\Z)', txt, re.S):
        sid = m.group(2)
        sub_types[sid] = m.group(1)
        fields = []
        for line in m.group(3).splitlines():
            line = line.strip()
            if not line or line.startswith(';'): continue
            if '=' in line:
                k, v = line.split('=', 1)
                fields.append((k.strip(), v.strip()))
        sub_fields[sid] = fields
    return txt, res_ext, sub_types, sub_fields

targets = sys.argv[1:]
for rel in targets:
    p = os.path.join(ROOT, rel)
    print('=' * 90)
    print('SCENE', rel)
    txt, res_ext, sub_types, sub_fields = parse(p)
    # 找 AnimationTree 节点的 tree_root
    for m in re.finditer(r'\[node\s+name="(\w+)"\s+type="AnimationTree"([^\]]*)\](.*?)(?=\n\[(?:node|connection|sub_resource|ext_resource)|\Z)', txt, re.S):
        head, body = m.group(2), m.group(3)
        props = {}
        for line in body.splitlines():
            line = line.strip()
            if '=' in line:
                k, v = line.split('=', 1)
                props[k.strip()] = v.strip()
        if 'tree_root' not in props: continue
        print('  NODE', m.group(1), '-> tree_root =', props['tree_root'])
        mm = re.match(r'SubResource\("([^"]+)"\)', props['tree_root'])
        if not mm:
            print('   (ext root)', props['tree_root']); continue
        rid = mm.group(1)
        print('  ROOT sub', rid, type)
        for k, v in sub_fields.get(rid, []):
            print('    ', k, '=', v)
    # 打印所有和动画树相关的子资源定义
    print('  --- animation-related sub_resources ---')
    for sid, t in sub_types.items():
        if t.startswith('AnimationNode') or t == 'Animation' or t == 'AnimationLibrary':
            print('  [%s] %s' % (sid, t))
            for k, v in sub_fields.get(sid, []):
                print('      ', k, '=', v)
