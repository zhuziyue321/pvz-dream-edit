## 检查编辑后的 .tscn：sub_resource id 重复 / 悬空引用 / load_steps 是否对得上
import os, re, collections

TOOLSDIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLSDIR)
targets = [l.strip() for l in open(os.path.join(TOOLSDIR, 'tmp_targets.txt'), encoding='utf-8') if l.strip()]

for rel in targets:
    p = os.path.join(ROOT, rel)
    t = open(p, encoding='utf-8').read()
    sub_ids = re.findall(r'\[sub_resource\s+type="[^"]+"\s+id="([^"]+)"\]', t)
    ext_ids = re.findall(r'\[ext_resource\s+type="[^"]+"[^)]*?id="([^"]+)"\]', t)
    ext_ids = re.findall(r'\[ext_resource[^\]]*id="([^"]+)"\]', t)
    dup = [k for k, v in collections.Counter(sub_ids).items() if v > 1]
    declared = set(sub_ids) | set(ext_ids)
    used = set(re.findall(r'(?:Sub|Ext)Resource\("([^"]+)"\)', t))
    dangling = sorted(u for u in used if u not in declared)
    steps = re.search(r'load_steps=(\d+)', t)
    expect = len(sub_ids) + len(ext_ids) + 1
    flags = []
    if dup:
        flags.append('DUP=' + ','.join(dup))
    if dangling:
        flags.append('DANGLING=' + ','.join(dangling))
    if steps and int(steps.group(1)) != expect:
        flags.append('STEPS=%s!=%d' % (steps.group(1), expect))
    print('%-58s sub=%d ext=%d steps=%s %s' % (
        rel, len(sub_ids), len(ext_ids), steps.group(1) if steps else '?', ' '.join(flags)))
