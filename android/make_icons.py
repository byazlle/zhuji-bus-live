import os, zlib, struct, math

def write_png(path, w, h, pixels):
    raw = b''
    for y in range(h):
        raw += b'\x00' + bytes(pixels[y * w * 4:(y + 1) * w * 4])
    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 9))
    png += chunk(b'IEND', b'')
    open(path, 'wb').write(png)

BLUE = (25, 118, 210)
DBLUE = (13, 71, 161)
WHITE = (255, 255, 255)
SKY = (187, 222, 251)

def rr(x, y, x0, y0, x1, y1, r):
    if x < x0 or x > x1 or y < y0 or y > y1:
        return False
    cx = min(max(x, x0 + r), x1 - r)
    cy = min(max(y, y0 + r), y1 - r)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r or (x0 + r <= x <= x1 - r) or (y0 + r <= y <= y1 - r)

def circle(x, y, cx, cy, r):
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r

def shade(u, v):
    """u,v in 0..1 -> rgba"""
    # 背景：竖向渐变 + 圆角（图标本体铺满，由启动器裁切）
    t = v
    bg = tuple(int(BLUE[i] + (DBLUE[i] - BLUE[i]) * t) for i in range(3))
    col = bg
    # 车身
    if rr(u, v, 0.20, 0.24, 0.80, 0.68, 0.07):
        col = WHITE
    # 车窗
    if 0.26 <= u <= 0.74 and 0.30 <= v <= 0.45:
        col = SKY
    if 0.26 <= u <= 0.74 and 0.48 <= v <= 0.53:
        col = SKY
    # 车灯
    if circle(u, v, 0.245, 0.585, 0.022) or circle(u, v, 0.755, 0.585, 0.022):
        col = (255, 213, 79)
    # 轮子
    if circle(u, v, 0.335, 0.72, 0.075) or circle(u, v, 0.665, 0.72, 0.075):
        col = DBLUE
    if circle(u, v, 0.335, 0.72, 0.035) or circle(u, v, 0.665, 0.72, 0.035):
        col = WHITE
    return col

def render(size, path):
    ss = 4
    W = size * ss
    px = bytearray(W * W * 4)
    for y in range(W):
        v = (y + 0.5) / W
        for x in range(W):
            u = (x + 0.5) / W
            r, g, b = shade(u, v)
            i = (y * W + x) * 4
            px[i] = r; px[i + 1] = g; px[i + 2] = b; px[i + 3] = 255
    # 降采样
    out = bytearray(size * size * 4)
    for y in range(size):
        for x in range(size):
            rs = gs = bs = 0
            for dy in range(ss):
                row = (y * ss + dy) * W
                for dx in range(ss):
                    i = (row + x * ss + dx) * 4
                    rs += px[i]; gs += px[i + 1]; bs += px[i + 2]
            n = ss * ss
            o = (y * size + x) * 4
            out[o] = rs // n; out[o + 1] = gs // n; out[o + 2] = bs // n; out[o + 3] = 255
    write_png(path, size, size, out)
    print('wrote', path, size)

base = os.path.dirname(os.path.abspath(__file__))
for folder, size in [('mipmap-mdpi', 48), ('mipmap-hdpi', 72), ('mipmap-xhdpi', 96),
                     ('mipmap-xxhdpi', 144), ('mipmap-xxxhdpi', 192)]:
    d = os.path.join(base, 'res', folder)
    os.makedirs(d, exist_ok=True)
    render(size, os.path.join(d, 'ic_launcher.png'))
