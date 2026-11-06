# Gera a estampa do barro dos cupinzeiros no Blender.
# Rode dentro do Blender 5.x (por exemplo pelo MCP do Blender ou no console Python):
#   import sys; sys.path.append(r"<pasta>/tools"); import blender_barro as b
#   b.build(); b.bake(PASTA_TEMP, 1024, 16); b.compose(PASTA_TEMP, "assets/textures/barro")
# O pedaço tem 1 x 1 m e se repete sem emenda nos dois sentidos: terra seca
# granulada, caneluras verticais da chuva, rachaduras finas e furinhos. O relevo
# vira uma malha de verdade no Blender, que é "assada" num plano: cor (com a
# altura no alfa) e relevo. Na imagem, X é em volta do cupinzeiro e Y é para cima.

import bpy, math, os, random
import numpy as np

W = 1.0         # lado do pedaço, em metros
N = 1024        # pontos do relevo por lado (1 mm cada)
HMAX = 0.04     # altura que vira branco na imagem de altura
SEED = 47


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


def fields():
    rng = np.random.default_rng(SEED)
    r = random.Random(SEED)
    px = W / N
    u = (np.arange(N) + 0.5) * px            # em volta do cupinzeiro
    v = (np.arange(N) + 0.5) * px            # para cima
    U, V = np.meshgrid(u, v)                 # linha = v, coluna = u

    # Calombos largos e casca granulada (as bolinhas de terra que os cupins colam).
    h = 0.010 + pnoise(rng, (N, N), 40) * 0.0030 + pnoise(rng, (N, N), 12) * 0.0012
    grain = pnoise(rng, (N, N), 2.5)
    h += np.clip(grain, 0, None) * 0.0009

    # Caneluras: sulcos verticais da chuva, que serpenteiam e somem aos poucos.
    flute = np.zeros((N, N))
    for k in range(22):
        u0 = r.uniform(0, W)
        width = r.uniform(0.007, 0.020)
        depth = r.uniform(0.005, 0.011)
        meander = pnoise(rng, (N, 1), 120)[:, 0] * 0.012 + pnoise(rng, (N, 1), 25)[:, 0] * 0.002
        du = np.mod(U - u0 - meander[:, None] + W / 2, W) - W / 2
        amp = smooth(-0.7, 0.5, pnoise(rng, (N, 1), 160)[:, 0])[:, None]
        g = np.exp(-(du / width) ** 2) * amp
        flute = np.maximum(flute, g * depth / 0.011)
        h -= g * depth

    # Rachaduras finas de terra seca.
    c = pnoise(rng, (N, N), 18)
    crack = np.exp(-(c / 0.07) ** 2) * smooth(0.0, 0.9, pnoise(rng, (N, N), 70))
    h -= crack * 0.0022

    # Furinhos, com a beirada um pouco levantada.
    hole = np.zeros((N, N))
    for i in range(110):
        cx, cy = r.uniform(0, W), r.uniform(0, W)
        rad = r.uniform(0.0015, 0.0045)
        dx = np.mod(U - cx + W / 2, W) - W / 2
        dy = np.mod(V - cy + W / 2, W) - W / 2
        d = np.sqrt(dx * dx + dy * dy)
        hole = np.maximum(hole, smooth(rad, rad * 0.55, d))
        h += 0.0012 * np.exp(-((d - rad * 1.35) / (rad * 0.45)) ** 2)
    h -= hole * 0.007

    # Cor (relativa: o tom geral vem do jogo).
    base = np.array(srgb(0.70, 0.50, 0.36)[:3])
    claro = np.array(srgb(0.82, 0.67, 0.52)[:3])
    fresca = np.array(srgb(0.64, 0.37, 0.24)[:3])
    col = np.broadcast_to(base, (N, N, 3)) * (1 + 0.07 * pnoise(rng, (N, N), 40))[..., None]
    # Partes altas desbotadas pelo sol, terra fresca (consertos) em manchas.
    hn = (h - h.mean()) / (h.std() + 1e-9)
    col = col + (claro - col) * np.clip(hn * 0.35, 0, 0.7)[..., None]
    fresh = smooth(1.2, 2.2, pnoise(rng, (N, N), 60)) * 0.3
    col = col + (fresca - col) * fresh[..., None]
    col *= (1 + 0.06 * np.clip(grain, -1, 1))[..., None]
    col *= (1 - 0.30 * flute - 0.5 * hole - 0.2 * crack)[..., None]
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
    mat = bpy.data.materials.get('barro') or bpy.data.materials.new('barro')
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
    bump.inputs['Distance'].default_value = 0.0004
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
    sc = bpy.data.scenes.get('barro') or bpy.data.scenes.new('barro')
    for o in list(sc.collection.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.window.scene = sc
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'GPU' if setup_gpu() != 'CPU' else 'CPU'
    if sc.world is None:
        sc.world = bpy.data.worlds.new('barro_mundo')
    sc.world.light_settings.distance = 0.012
    h, col = fields()
    h = h - h.min()
    me = grid('barro_relevo', h, col)
    me.materials.append(material())
    ob = bpy.data.objects.new('barro_relevo', me)
    sc.collection.objects.link(ob)
    np.save(os.path.join(bpy.app.tempdir, 'barro_h.npy'), h)
    return {'faces': len(me.polygons), 'h_min': float(h.min()), 'h_max': float(h.max())}


def bake(out_dir, res=1024, samples=16):
    sc = bpy.data.scenes['barro']
    bpy.context.window.scene = sc
    tgt = sc.objects.get('alvo_barro')
    if tgt is None:
        me = bpy.data.meshes.new('alvo_barro')
        me.from_pydata([(0, 0, 0), (W, 0, 0), (W, W, 0), (0, W, 0)], [], [(0, 1, 2, 3)])
        uv = me.uv_layers.new(name='UVMap')
        for i, c in enumerate(((0, 0), (1, 0), (1, 1), (0, 1))):
            uv.data[i].uv = c
        tgt = bpy.data.objects.new('alvo_barro', me)
        sc.collection.objects.link(tgt)
        tm = bpy.data.materials.new('alvo_barro_mat')
        tm.use_nodes = True
        me.materials.append(tm)
    tm = tgt.data.materials[0]
    img_node = next((n for n in tm.node_tree.nodes if n.type == 'TEX_IMAGE'), None) or tm.node_tree.nodes.new('ShaderNodeTexImage')
    tm.node_tree.nodes.active = img_node
    src = sc.objects['barro_relevo']
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
        name = 'barro_' + tag
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
    np.save(f'{out_dir}/barro_raw.npy', np.stack([res_d[k] for k in ('cor', 'relevo', 'ao', 'altura')]))
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
    cor, rel, ao, alt = np.load(f'{raw_dir}/barro_raw.npy')
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
    save_png(p[::2, ::2], f'{raw_dir}/barro_previa.png', False)
    return {'alb_media_srgb': to_srgb(alb.reshape(-1, 3).mean(0)).round(3).tolist()}
