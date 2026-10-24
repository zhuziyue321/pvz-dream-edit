"""把 PopCap 的 RTON 二进制还原成 JSON（PVZ2 解包资源的 `.RTON` 都能读）。

为什么需要
----
`..\\2代解包资源`（桌面）里 PVZ2 的数据全是 RTON：`PACKAGES/PLANTTYPES.RTON` 有阳光 / 冷却，
`PROPERTIES/RESOURCES.RTON` 有每个碎图在图集里的矩形（`ax/ay/aw/ah` + `parent` 图集 id）。
这两样都是「重写 pvz2 模组」的输入：没有矩形就切不出碎图，没有 PLANTTYPES 就没有官方数值。
本仓库**不在运行时**读 RTON —— 这里只是离线转换工具，产物进 `tmp/`。

用法
----
    python tools/rton2json.py <输入.RTON> [输出.json]
    python tools/rton2json.py <输入.RTON> --check-only     # 只解析、不写盘

    例：
    python tools/rton2json.py "../2代解包资源/PACKAGES/PLANTTYPES.RTON" tmp/rton/PLANTTYPES.json

格式口径（字节码表来自 RTON 社区逆向，本文件已用 COLORS.RTON / PLANTTYPES.RTON / RESOURCES.RTON 实测）
----
    "RTON" | version:u32le | <值> | "DONE"

    值 = 类型字节 + payload：
      0x00 false            0x01 true
      0x08 int8             0x09 int8 常量 0
      0x0a uint8            0x0b uint8 常量 0
      0x10 int16            0x11 int16 常量 0
      0x12 uint16           0x13 uint16 常量 0
      0x20 int32            0x21 int32 常量 0
      0x22 float32          0x23 float32 常量 0.0
      0x24 varint           0x25 -varint（负数）
      0x26 int32            0x27 int32 常量 0
      0x28 varint           0x2a int64（本仓素材里没出现，遇到就报错）
      0x42 float64
      0x81 非缓存字符串      0x90 缓存字符串（存进字符串表）  0x91 缓存字符串回引（varint 下标）
      0x92 同上（UTF-8）      0x93 同上（回引）
      0x85 对象              —— 键值对连续排布，遇 0xff 结束
      0x86 数组              —— 后面跟 0xfd + varint 元素数，元素读完后跟 0xfe

    ⚠️ 字符串长度也是 varint（不是 u8），长字符串会跨字节。
    ⚠️ `0x91` 回引的下标指向**同一次解析里出现过的缓存字符串顺序**（含键名），
       所以解析必须从头一次到底，不能跳段。
"""

from __future__ import annotations

import json
import struct
import sys

MAGIC = b"RTON"
END_MARK = b"DONE"


class RtonError(Exception):
    pass


class Reader:
    def __init__(self, blob: bytes):
        self.blob = blob
        self.off = 0
        self.strings: list[str] = []

    # ---------------------------------------------------------------- 基础读
    def take(self, count: int) -> bytes:
        if self.off + count > len(self.blob):
            raise RtonError("读到文件尾：需要 %d 字节，位置 %#x" % (count, self.off))
        chunk = self.blob[self.off:self.off + count]
        self.off += count
        return chunk

    def u8(self) -> int:
        return self.take(1)[0]

    def varint(self) -> int:
        """LEB128 无符号变长整数（RTON 的 varint / 字符串长度都用它）。"""
        result = 0
        shift = 0
        while True:
            byte = self.u8()
            result |= (byte & 0x7F) << shift
            if not byte & 0x80:
                return result
            shift += 7
            if shift > 63:
                raise RtonError("varint 过长（位置 %#x）" % self.off)

    # ---------------------------------------------------------------- 值
    def value(self) -> object:
        start = self.off
        code = self.u8()
        if code == 0x00:
            return False
        if code == 0x01:
            return True
        if code == 0x08:
            return struct.unpack("<b", self.take(1))[0]
        if code in (0x09, 0x0B, 0x11, 0x13, 0x21, 0x27, 0x23):
            return 0.0 if code == 0x23 else 0
        if code == 0x0A:
            return struct.unpack("<B", self.take(1))[0]
        if code == 0x10:
            return struct.unpack("<h", self.take(2))[0]
        if code == 0x12:
            return struct.unpack("<H", self.take(2))[0]
        if code in (0x20, 0x26):
            return struct.unpack("<i", self.take(4))[0]
        if code == 0x22:
            return struct.unpack("<f", self.take(4))[0]
        if code in (0x24, 0x28):
            return self.varint()
        if code == 0x25:
            return -self.varint()
        if code == 0x42:
            return struct.unpack("<d", self.take(8))[0]
        if code == 0x43:
            return 0.0
        if code == 0x2A:
            return struct.unpack("<q", self.take(8))[0]
        if code == 0x2B:
            return 0
        if code in (0x81, 0x90, 0x92):
            text = self.take(self.varint()).decode("utf-8", "replace")
            self.strings.append(text)
            return text
        if code == 0x82:
            ## UTF-8 字符串：先给「字符数」再给「字节数」，两个都是 varint
            self.varint()
            text = self.take(self.varint()).decode("utf-8", "replace")
            self.strings.append(text)
            return text
        if code == 0x83:
            return self._rtid()
        if code == 0x84:
            ## 「备注 + 真值」：先是一个字符串备注（如 `# [none, pea, ...]`），紧跟真值。
            ## 备注本身对玩法没意义，读完丢掉（`PLANTPROPERTIES.RTON` 里 300+ 处）。
            self.value()
            return self.value()
        if code in (0x91, 0x93):
            index = self.varint()
            if index >= len(self.strings):
                raise RtonError("字符串回引越界：下标 %d / 已收 %d（位置 %#x）"
                                % (index, len(self.strings), start))
            return self.strings[index]
        if code == 0x85:
            obj: dict = {}
            while True:
                if self.off >= len(self.blob):
                    raise RtonError("对象在文件尾没有 0xff 结束（起点 %#x）" % start)
                if self.blob[self.off] == 0xFF:
                    self.off += 1
                    return obj
                key = self.value()
                obj[str(key)] = self.value()
        if code == 0x86:
            marker = self.u8()
            if marker != 0xFD:
                raise RtonError("数组缺少 0xfd 标记（位置 %#x，读到 %#x）" % (start, marker))
            count = self.varint()
            items = [self.value() for _ in range(count)]
            if self.u8() != 0xFE:
                raise RtonError("数组缺少 0xfe 结束（起点 %#x）" % start)
            return items
        raise RtonError("未知类型字节 %#04x（位置 %#x）" % (code, start))

    # ---------------------------------------------------------------- RTID
    def _string_block(self) -> str:
        """RTID / 0x82 里那种「先字符数、再字节数」的字符串。"""
        self.varint()
        return self.take(self.varint()).decode("utf-8", "replace")

    def _rtid(self) -> str:
        """`0x83` 是 RTID（跨条目引用），按子类型区分——实测素材里子类型 3 最常见。"""
        subset = self.u8()
        if subset == 0x00:
            return "RTID()"
        if subset == 0x03:
            owner = self._string_block()
            target = self._string_block()
            return "RTID(%s@%s)" % (target, owner)
        if subset == 0x02:
            owner = self._string_block()
            high = self.varint()
            low = self.varint()
            ident = self.take(4).hex()
            return "RTID(%d.%d.%s@%s)" % (low, high, ident, owner)
        raise RtonError("未知 RTID 子类型 %#04x（位置 %#x）" % (subset, self.off))

    # ---------------------------------------------------------------- 整份
    def parse(self) -> object:
        if self.blob[:4] != MAGIC:
            raise RtonError("不是 RTON：头部 %r" % self.blob[:4])
        self.off = 4
        version = struct.unpack("<I", self.take(4))[0]
        if version != 1:
            print("  ⚠️ 版本号 %d（实测素材都是 1，按同一口径解析）" % version)
        ## 根对象**不带** 0x85 标记：键值对直接从这儿开始，遇 0xff 结束（实测全部素材一致）
        root: dict = {}
        while self.blob[self.off] != 0xFF:
            key = self.value()
            root[str(key)] = self.value()
        self.off += 1
        if self.blob[self.off:self.off + 4] != END_MARK:
            raise RtonError("结尾不是 DONE（位置 %#x，读到 %r）"
                            % (self.off, self.blob[self.off:self.off + 8]))
        self.off += 4
        if self.off != len(self.blob):
            print("  ⚠️ DONE 之后还剩 %d 字节" % (len(self.blob) - self.off))
        return root


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = [a for a in argv[1:] if not a.startswith("--")]
    check_only = "--check-only" in argv
    if not args:
        print(__doc__)
        return 1
    src = args[0]
    dst = args[1] if len(args) > 1 else None

    blob = open(src, "rb").read()
    print("RTON: %s（%d 字节）" % (src, len(blob)))
    try:
        root = Reader(blob).parse()
    except RtonError as error:
        print("  解析失败：%s" % error)
        return 1

    print("  解析成功，顶层键 %d 个：%s"
          % (len(root), list(root)[:8] if isinstance(root, dict) else type(root).__name__))
    text = json.dumps(root, ensure_ascii=False, indent=1)
    print("  JSON %d 字符" % len(text))
    if check_only or not dst:
        return 0
    import os
    os.makedirs(os.path.dirname(os.path.abspath(dst)), exist_ok=True)
    with open(dst, "w", encoding="utf-8") as handle:
        handle.write(text)
    print("  写出 %s" % dst)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
