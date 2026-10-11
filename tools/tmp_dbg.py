import re, os, sys, importlib.util
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location('u', os.path.join(ROOT, 'tools', 'tmp_unify_anim_tree.py'))
m = importlib.util.module_from_spec(spec)
sys.modules['u'] = m
spec.loader.exec_module(m)

t = m.read('src/entities/character/character_base.tscn')
mm = re.search(r'\[node\s+name="AnimComponent"([^\]]*)\](.*?)(?=\n\[|\Z)', t, re.S)
print('node match:', bool(mm))
print('body:', repr(mm.group(2)) if mm else None)
if mm:
    s = re.search(r'script\s*=\s*ExtResource\("([^"]+)"\)', mm.group(2))
    print('script id:', s.group(1) if s else None)
    if s:
        pat = r'\[ext_resource\s+type="Script"[^)]*?path="([^"]+)"[^)]*?id="%s"\]' % re.escape(s.group(1))
        em = re.search(pat, t, re.S)
        print('path:', em.group(1) if em else None)
