
import glob, os
from compression import zstd

roots = [os.path.expanduser("~/.dsh/sessions"), os.environ["TEMP"] + "\\dsh-spill-ZK1qSm"]
cands = []
for r in roots:
    for dp, dn, fn in os.walk(r):
        for f in fn:
            cands.append(os.path.join(dp, f))
print("files:", len(cands))

needle = "RoofSlope"
for f in cands:
    try:
        data = open(f, "rb").read()
        if f.endswith(".zstd"):
            data = zstd.decompress(data)
        txt = data.decode("utf-8", "replace")
    except Exception as e:
        continue
    if needle not in txt:
        continue
    # 找出 RoofSlope 附近是否是场景文件内容（含 offset_left 与 PanelZombieGoHome）
    i = txt.find('[node name="RoofSlope"')
    if i < 0:
        print("HIT(no node block):", os.path.basename(f), len(txt))
        continue
    print("==== HIT:", f, "len", len(txt))
    print(txt[max(0, i-1600):i+700].replace("\\n", "\n")[:2600])
