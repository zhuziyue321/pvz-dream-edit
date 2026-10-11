## 生成「待验清单」：每个改过的场景 -> (树根 sub id, AnimationPlayer 的动画库列表)
import os, re, json

TOOLSDIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLSDIR)


def read(p):
    with open(p, encoding='utf-8') as f:
        return f.read()


def ext_map(t):
    d = {}
    for m in re.finditer(r'\[ext_resource\s+([^\]]*)\]', t):
        head = m.group(1)
        tid = re.search(r'id="([^"]+)"', head)
        if not tid:
            continue
        te = re.search(r'type="([^"]+)"', head)
        tp = re.search(r'path="([^"]+)"', head)
        d[tid.group(1)] = (te.group(1) if te else '', tp.group(1) if tp else '')
    return d


def node_blocks(t):
    out = []
    for m in re.finditer(r'\[node\s+([^\]]*)\](.*?)(?=\n\[(?:node|connection|sub_resource|ext_resource)|\Z)', t, re.S):
        head, body = m.group(1), m.group(2)
        nm = re.search(r'name="([^"]+)"', head)
        out.append({'name': nm.group(1) if nm else '', 'head': head, 'body': body})
    return out


def libraries_of(scene_rel, t, player_head_name):
    """取 AnimationPlayer 的 libraries 字典： [(key, resref)]"""
    for nb in node_blocks(t):
        if nb['name'] != player_head_name:
            continue
        m = re.search(r'libraries\s*=\s*\{(.*?)\n?\}', nb['body'], re.S)
        if not m:
            continue
        out = []
        for em in re.finditer(r'&?"([^"]*)"\s*:\s*(SubResource\("([^"]+)"\)|ExtResource\("([^"]+)"\))', m.group(1)):
            key = em.group(1)
            if em.group(3):
                out.append((key, 'sub', em.group(3)))
            else:
                out.append((key, 'ext', em.group(4)))
        return out
    return None


def main():
    targets = []
    for line in open(os.path.join(TOOLSDIR, 'tmp_targets.txt'), encoding='utf-8'):
        line = line.strip()
        if line:
            targets.append(line)
    rows = []
    for rel in targets:
        t = read(os.path.join(ROOT, rel))
        exts = ext_map(t)
        # AnimationTree 节点
        for nb in node_blocks(t):
            if 'type="AnimationTree"' not in nb['head']:
                continue
            rm = re.search(r'tree_root\s*=\s*SubResource\("([^"]+)"\)', nb['body'])
            pm = re.search(r'anim_player\s*=\s*NodePath\("([^"]+)"\)', nb['body'])
            if not rm:
                continue
            player = pm.group(1).split('/')[-1] if pm else 'AnimationPlayer'
            libs = libraries_of(rel, t, player) or []
            entries = []
            for key, kind, rid in libs:
                if kind == 'sub':
                    entries.append('%s|sub|%s' % (key, rid))
                else:
                    p = exts.get(rid, ('', ''))[1]
                    p = p[len('res://'):] if p.startswith('res://') else p
                    entries.append('%s|tres|%s' % (key, p))
            rows.append({'scene': rel, 'root': rm.group(1), 'libs': entries})
    with open(os.path.join(TOOLSDIR, 'tmp_manifest.json'), 'w', encoding='utf-8') as f:
        json.dump(rows, f, ensure_ascii=False, indent=1)
    print('wrote', len(rows), 'entries')


if __name__ == '__main__':
    main()
