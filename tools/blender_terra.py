# Gera a estampa da terra fofa dos formigueiros de saúva no Blender.
# Rode dentro do Blender 5.x (por exemplo pelo MCP do Blender ou no console Python):
#   import sys; sys.path.append(r"<pasta>/tools"); import blender_terra as b
#   b.build(); b.bake(PASTA_TEMP, 1024, 16); b.compose(PASTA_TEMP, "assets/textures/terra")
# O pedaço tem 0,5 x 0,5 m e se repete sem emenda nos dois sentidos: milhares de
# grãozinhos de terra (as bolinhas que as saúvas trazem lá de baixo), em tons de
# vermelho, laranja e amarelado, torrões de grãos grudados e areia clara. O relevo
# vira uma malha de verdade no Blender, que é "assada" num plano: cor (com a
# altura no alfa) e relevo. A imagem é vista de cima.

import bpy, math, os, random
import numpy as np

W = 0.5         # lado do pedaço, em metros
N = 1024        # pontos do relevo por lado
HMAX = 0.02     # altura que vira branco na imagem de altura
SEED = 61


def srgb(r, g, b):
    return (r ** 2.2, g ** 2.2, b ** 2.2, 1.0)


# ------------------------------------------------------------------ relevo e cor (repetem sem emenda)

def pnoise(rng, shape, size_px, aniso=(1.0, 1.0)):
    """Ruído suave que se repete: ruído branco filtrado na frequência."""
    w = rng.standard_normal(shape)
    F = np.fft.fft2(w)
    ky = np.fft.fftfreq(shape[0])[:, None] * aniso[1]
    kx = np.fft.fftfreq(shape[1])[None, :] * aniso[0]
    k2 = (kx ** 2 + ky ** 2) * (size_px ** 2)
    out = np.real(np.fft.ifft2(F * np.exp(-k2 * 2.0)))
    out -= out.mean()
    return out / (out.std() + 1e-9)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def _splat(h, col, rng_pts, U, V, px):
    """Grãos redondos: cada um vira uma meia bolinha somada ao relevo (o mais
    alto fica por cima, e a cor vem dele)."""
    n = h.shape[0]
    for (cx, cy, rad, hgt, c) in rng_pts:
        rp = int(rad / px) + 2
        ix = int(cx / px)
        iy = int(cy / px)
        xs = np.arange(ix - rp, ix + rp + 1) % n
        ys = np.arange(iy - rp, iy + rp + 1) % n
        gx = (np.arange(ix - rp, ix + rp + 1) + 0.5) * px - cx
        gy = (np.arange(iy - rp, iy + rp + 1) + 0.5) * px - cy
        DX, DY = np.meshgrid(gx, gy)
        d2 = DX * DX + DY * DY
        top = hgt + np.sqrt(np.clip(rad * rad - d2, 0, None)) * 0.8
        top = np.where(d2 < rad * rad, top, -1.0)
        sub = h[np.ix_(ys, xs)]
        win = top > sub
        sub = np.where(win, top, sub)
        h[np.ix_(ys, xs)] = sub
        cs = col[np.ix_(ys, xs)]
        shade = (0.88 + 0.12 * np.sqrt(np.clip(1 - d2 / (rad * rad), 0, 1)))[..., None]
        cs = np.where(win[..., None], np.array(c)[None, None, :] * shade, cs)
        col[np.ix_(ys, xs)] = cs


def fields():
    rng = np.random.default_rng(SEED)
    r = random.Random(SEED)
    px = W / N
    u = (np.arange(N) + 0.5) * px
    v = (np.arange(N) + 0.5) * px
    U, V = np.meshgrid(u, v)

    # Chão de terra fofa por baixo (escuro, aparece entre os grãos).
    h = pnoise(rng, (N, N), 60) * 0.0004
    base = np.array(srgb(0.50, 0.30, 0.20)[:3])
    col = np.broadcast_to(base, (N, N, 3)).copy() * (1 + 0.08 * pnoise(rng, (N, N), 20))[..., None]
    swell = pnoise(rng, (N, N), 80)

    # Torrões: bolotas de grãos grudados, um pouco mais altas.
    pts = []
    tones = [srgb(0.72, 0.46, 0.30), srgb(0.66, 0.40, 0.26), srgb(0.78, 0.55, 0.38),
             srgb(0.60, 0.36, 0.24), srgb(0.84, 0.66, 0.48)]
    for _ in range(110):
        cx, cy = r.uniform(0, W), r.uniform(0, W)
        rad = r.uniform(0.006, 0.014)
        tone = np.array(r.choice(tones)[:3]) * r.uniform(0.9, 1.08)
        for _k in range(int(rad / 0.0016)):
            a = r.uniform(0, 2 * math.pi)
            d = rad * math.sqrt(r.random())
            gr = r.uniform(0.0015, 0.0028)
            pts.append(((cx + math.cos(a) * d) % W, (cy + math.sin(a) * d) % W, gr,
                        0.004 + (rad - d) * 0.5, tone * r.uniform(0.92, 1.06)))
    # Grãos soltos: as bolinhas de terra que as saúvas trazem lá de baixo.
    for _ in range(26000):
        cx, cy = r.uniform(0, W), r.uniform(0, W)
        gr = r.uniform(0.0012, 0.0028) * (1.3 if r.random() < 0.08 else 1.0)
        tone = np.array(r.choice(tones)[:3]) * r.uniform(0.88, 1.10)
        ix, iy = int(cx / px) % N, int(cy / px) % N
        pts.append((cx, cy, gr, 0.0012 + swell[iy, ix] * 0.0008, tone))
    r.shuffle(pts)
    _splat(h, col, pts, U, V, px)

    # Areia clarinha e pedrinhas brancas aqui e ali.
    for _ in range(260):
        cx, cy = r.uniform(0, W), r.uniform(0, W)
        gr = r.uniform(0.0006, 0.0012)
        pts2 = [(cx, cy, gr, float(h[int(cy / px) % N, int(cx / px) % N]) - gr * 0.3,
                 np.array(srgb(0.86, 0.80, 0.70)[:3]) * r.uniform(0.9, 1.05))]
        _splat(h, col, pts2, U, V, px)
    h += pnoise(rng, (N, N), 1.5) * 0.00012
    return h, np.clip(col, 0, 1)


# ------------------------------------------------------------------ Blender

def setup_gpu():
    prefs = bpy.context.preferences.addons['cycles'].preferences
    for t in ('OPTIX', 'CUDA'):
        try:
            prefs.compute_device_type = t
            prefs.get_devices()
            ok = False
            for d in prefs.devices:
                d.use = d.type == t
                ok = ok or d.use
            if ok:
                return t
        except Exception:
            pass
    return 'CPU'


def grid(name, h, col, margin=48):
    """Malha com o relevo, com uma borda repetida dos dois lados (para o assado
    nas bordas do pedaço ver a continuação certa)."""
    n = h.shape[0]
    m = n + 2 * margin
    idx = (np.arange(m) - margin) % n
    hh = h[np.ix_(idx, idx)]
    cc = col[np.ix_(idx, idx)]
    px = W / n
    xs = (np.arange(m) - margin + 0.5) * px
    X, Y = np.meshgrid(xs, xs)
    co = np.stack([X, Y, hh], -1).reshape(-1, 3).astype(np.float32)
    a = np.arange(m * m).reshape(m, m)
    q = np.stack([a[:-1, :-1], a[:-1, 1:], a[1:, 1:], a[1:, :-1]], -1).reshape(-1)
    me = bpy.data.meshes.get(name)
    if me:
        bpy.data.meshes.remove(me)
    me = bpy.data.meshes.new(name)
    me.vertices.add(m * m)
    me.vertices.foreach_set('co', co.ravel())
    nq = (m - 1) * (m - 1)
    me.loops.add(nq * 4)
    me.loops.foreach_set('vertex_index', q.astype(np.int32))
    me.polygons.add(nq)
    me.polygons.foreach_set('loop_start', (np.arange(nq) * 4).astype(np.int32))
    me.update()
    me.validate()
    attr = me.color_attributes.new('cor', 'FLOAT_COLOR', 'POINT')
    c4 = np.concatenate([cc.reshape(-1, 3), np.ones((m * m, 1))], 1).astype(np.float32)
    attr.data.foreach_set('color', c4.ravel())
    me.shade_smooth()
    return me


def material():
    mat = bpy.data.materials.get('terra') or bpy.data.materials.new('terra')
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    a = nt.nodes.new('ShaderNodeAttribute'); a.attribute_name = 'cor'
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled'); bsdf.name = 'BSDF'
    nt.links.new(a.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = 0.92
    # Grão fino de terra (pequeno demais para a malha).
    tc = nt.nodes.new('ShaderNodeTexCoord')
    nz = nt.nodes.new('ShaderNodeTexNoise')
    nz.inputs['Scale'].default_value = 900.0
    nz.inputs['Detail'].default_value = 2.0
    nt.links.new(tc.outputs['Object'], nz.inputs['Vector'])
    bump = nt.nodes.new('ShaderNodeBump')
    bump.inputs['Distance'].default_value = 0.0002
    bump.inputs['Strength'].default_value = 1.0
    nt.links.new(nz.outputs['Fac'], bump.inputs['Height'])
    nt.links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
    # Altura (para o assado da altura).
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    nt.links.new(geo.outputs['Position'], sep.inputs[0])
    dv = nt.nodes.new('ShaderNodeMath'); dv.operation = 'DIVIDE'; dv.use_clamp = True
    nt.links.new(sep.outputs[2], dv.inputs[0]); dv.inputs[1].default_value = HMAX
    em = nt.nodes.new('ShaderNodeEmission'); em.name = 'HEIGHT'
    nt.links.new(dv.outputs[0], em.inputs['Color'])
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    nt.links.new(bsdf.outputs[0], out.inputs['Surface'])
    return mat


def set_mode(mat, mode):
    nt = mat.node_tree
    out = next(n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL')
    for l in list(out.inputs['Surface'].links):
        nt.links.remove(l)
    nt.links.new(nt.nodes['BSDF' if mode == 'bsdf' else 'HEIGHT'].outputs[0], out.inputs['Surface'])


def build():
    sc = bpy.data.scenes.get('terra') or bpy.data.scenes.new('terra')
    for o in list(sc.collection.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.window.scene = sc
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'GPU' if setup_gpu() != 'CPU' else 'CPU'
    if sc.world is None:
        sc.world = bpy.data.worlds.new('terra_mundo')
    sc.world.light_settings.distance = 0.006
    h, col = fields()
    h = h - h.min()
    me = grid('terra_relevo', h, col)
    me.materials.append(material())
    ob = bpy.data.objects.new('terra_relevo', me)
    sc.collection.objects.link(ob)
    np.save(os.path.join(bpy.app.tempdir, 'terra_h.npy'), h)
    return {'faces': len(me.polygons), 'h_min': float(h.min()), 'h_max': float(h.max())}


def bake(out_dir, res=1024, samples=16):
    sc = bpy.data.scenes['terra']
    bpy.context.window.scene = sc
    tgt = sc.objects.get('alvo_terra')
    if tgt is None:
        me = bpy.data.meshes.new('alvo_terra')
        me.from_pydata([(0, 0, 0), (W, 0, 0), (W, W, 0), (0, W, 0)], [], [(0, 1, 2, 3)])
        uv = me.uv_layers.new(name='UVMap')
        for i, c in enumerate(((0, 0), (1, 0), (1, 1), (0, 1))):
            uv.data[i].uv = c
        tgt = bpy.data.objects.new('alvo_terra', me)
        sc.collection.objects.link(tgt)
        tm = bpy.data.materials.new('alvo_terra_mat')
        tm.use_nodes = True
        me.materials.append(tm)
    tm = tgt.data.materials[0]
    img_node = next((n for n in tm.node_tree.nodes if n.type == 'TEX_IMAGE'), None) or tm.node_tree.nodes.new('ShaderNodeTexImage')
    tm.node_tree.nodes.active = img_node
    src = sc.objects['terra_relevo']
    for o in sc.objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = tgt
    b = sc.render.bake
    b.use_selected_to_active = True
    b.cage_extrusion = 0.05
    b.max_ray_distance = 0.1
    b.margin = 0
    sc.cycles.samples = samples
    mat = src.data.materials[0]
    res_d = {}

    def run(tag, btype, **kw):
        name = 'terra_' + tag
        img = bpy.data.images.get(name)
        if img:
            bpy.data.images.remove(img)
        img = bpy.data.images.new(name, res, res, float_buffer=True, alpha=False)
        img.colorspace_settings.is_data = True
        img_node.image = img
        bpy.ops.object.bake(type=btype, **kw)
        a = np.empty(res * res * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        res_d[tag] = a.reshape(res, res, 4)

    set_mode(mat, 'bsdf')
    b.use_pass_direct = False
    b.use_pass_indirect = False
    b.use_pass_color = True
    run('cor', 'DIFFUSE', pass_filter={'COLOR'})
    run('relevo', 'NORMAL', normal_space='TANGENT')
    run('ao', 'AO')
    set_mode(mat, 'height')
    run('altura', 'EMIT')
    set_mode(mat, 'bsdf')
    np.save(f'{out_dir}/terra_raw.npy', np.stack([res_d[k] for k in ('cor', 'relevo', 'ao', 'altura')]))
    return {k: [float(v.min()), float(v.max())] for k, v in res_d.items()}


def to_srgb(x):
    x = np.clip(x, 0, 1)
    return np.where(x <= 0.0031308, x * 12.92, 1.055 * np.power(x, 1 / 2.4) - 0.055)


def save_png(arr, path, alpha=True):
    h, w = arr.shape[:2]
    name = '_out_' + os.path.basename(path)
    img = bpy.data.images.get(name)
    if img:
        bpy.data.images.remove(img)
    img = bpy.data.images.new(name, w, h, alpha=alpha)
    img.colorspace_settings.is_data = True
    img.pixels.foreach_set(np.ascontiguousarray(arr, dtype=np.float32).ravel())
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    bpy.data.images.remove(img)


def compose(raw_dir, out_dir, ao_amt=0.6, sun=(0.5, 0.35, 0.8)):
    os.makedirs(out_dir, exist_ok=True)
    cor, rel, ao, alt = np.load(f'{raw_dir}/terra_raw.npy')
    alb = cor[..., :3] * (1 - ao_amt + ao_amt * ao[..., :1])
    a = np.ones_like(cor)
    a[..., :3] = to_srgb(alb)
    a[..., 3] = np.clip(alt[..., 0], 0, 1)
    save_png(a, f'{out_dir}/cor.png', True)
    n = rel.copy(); n[..., 3] = 1
    save_png(n, f'{out_dir}/relevo.png', False)
    nv = rel[..., :3] * 2 - 1
    s = np.array(sun); s = s / np.linalg.norm(s)
    lam = np.clip((nv * s).sum(-1, keepdims=True), 0, 1)
    lit = alb * (0.25 + 0.95 * lam) * 1.6
    p = np.ones((cor.shape[0], cor.shape[1] * 2, 4), np.float32)
    w = cor.shape[1]
    p[:, :w, :3] = to_srgb(alb * 1.4)
    p[:, w:, :3] = to_srgb(lit)
    save_png(p[::2, ::2], f'{raw_dir}/terra_previa.png', False)
    return {'alb_media_srgb': to_srgb(alb.reshape(-1, 3).mean(0)).round(3).tolist()}
