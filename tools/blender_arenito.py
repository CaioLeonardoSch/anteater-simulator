# Gera a estampa do arenito dos paredões no Blender.
# Rode dentro do Blender 5.x (por exemplo pelo MCP do Blender ou no console Python):
#   import sys; sys.path.append(r"<pasta>/tools"); import blender_arenito as a
#   a.build(); a.bake(PASTA_TEMP, 2048, 16); a.compose(PASTA_TEMP, "assets/textures/arenito")
# O pedaço tem 4 x 4 m e se repete sem emenda nos dois sentidos. O relevo (camadas,
# fendas, blocos, buraquinhos) vira uma malha de verdade no Blender, que é
# "assada" num plano: cor (com a altura no alfa) e relevo.
# Na imagem, X é o sentido ao longo da parede e Y é para cima.

import bpy, math, os, random
import numpy as np

W = 4.0         # lado do pedaço, em metros
N = 1024        # pontos do relevo por lado (4 mm cada)
HMAX = 0.20     # altura que vira branco na imagem de altura
SEED = 31


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
    u = (np.arange(N) + 0.5) * px            # ao longo da parede
    v = (np.arange(N) + 0.5) * px            # para cima
    U, V = np.meshgrid(u, v)                 # linha = v, coluna = u

    # Camadas: espessuras somando exatamente W.
    th = []
    while sum(th) < W:
        th.append(r.choice([r.uniform(0.05, 0.14), r.uniform(0.12, 0.30), r.uniform(0.12, 0.30), r.uniform(0.35, 0.6)]))
    th = np.array(th) * (W / sum(th))
    bounds = np.concatenate([[0.0], np.cumsum(th)])
    nl = len(th)
    hard = np.array([r.uniform(-1, 1) for _ in range(nl)])
    tone = np.array([r.uniform(-1, 1) for _ in range(nl)])
    warm = np.array([r.uniform(-1, 1) for _ in range(nl)])
    cross = np.array([r.random() < 0.45 and t > 0.18 for t in th])
    cross_slope = np.array([r.uniform(-0.35, 0.35) for _ in range(nl)])
    pitted = np.array([h < -0.2 and r.random() < 0.6 for h in hard])

    # Linhas das camadas um pouco onduladas.
    wav = pnoise(rng, (1, N), 60)[0] * 0.012 + pnoise(rng, (1, N), 8)[0] * 0.002
    Ve = np.mod(V + wav[None, :], W)
    L = np.clip(np.searchsorted(bounds, Ve, side='right') - 1, 0, nl - 1)
    f = (Ve - bounds[L]) / th[L]                      # 0..1 dentro da camada
    d_edge = np.minimum(Ve - bounds[L], bounds[L + 1] - Ve)   # metros até a linha da camada

    # Camadas duras saltam (beirada arredondada), moles ficam para dentro.
    hl = hard[L]
    bulge = smooth(0.0, 0.08, d_edge) * 0.04 * hl
    h = 0.03 + bulge
    # Linha entre camadas: um sulco fino.
    h -= 0.012 * np.exp(-(d_edge / 0.008) ** 2)
    # Listras finas inclinadas dentro das camadas grossas.
    lam = np.sin((Ve + U * cross_slope[L]) * 2 * math.pi / 0.025)
    h += np.where(cross[L], 0.0018 * lam, 0.0)
    # Grão e calombos.
    h += pnoise(rng, (N, N), 3) * 0.0012 + pnoise(rng, (N, N), 25) * 0.004 + pnoise(rng, (N, N), 90) * 0.008

    # Fendas verticais: cada uma corta algumas camadas, em degraus.
    crack = np.zeros((N, N))
    chip = np.zeros((N, N))
    n_joint = 9
    for j in range(n_joint):
        u0 = r.uniform(0, W)
        l0 = r.randrange(nl)
        span = r.randint(2, max(3, nl // 2))
        width = r.uniform(0.007, 0.018)
        for k in range(span):
            li = (l0 + k) % nl
            uj = u0 + r.uniform(-0.04, 0.04) * k
            mask = (L == li)
            du = np.mod(U - uj + W / 2, W) - W / 2
            du = du + pnoise(rng, (N, 1), 6)[:, 0][:, None] * 0.003
            c = np.exp(-(du / width) ** 2)
            ch = 1 - smooth(0.0, r.uniform(0.04, 0.10), np.abs(du))
            crack = np.where(mask, np.maximum(crack, c), crack)
            chip = np.where(mask, np.maximum(chip, ch), chip)
    h -= crack * 0.05 + chip * 0.018

    # Buraquinhos de erosão nas camadas moles.
    pits_n = pnoise(rng, (N, N), 6)
    pits = smooth(1.6, 2.4, pits_n) * pitted[L]
    h -= pits * 0.012

    # Cor (relativa: o tom geral vem do jogo).
    base = np.array(srgb(0.80, 0.60, 0.46)[:3])
    creme = np.array(srgb(0.88, 0.74, 0.58)[:3])
    ferro = np.array(srgb(0.70, 0.42, 0.30)[:3])
    t = tone[L][..., None]
    wm = warm[L][..., None]
    col = base * (1 + 0.22 * t)
    col = col + (creme - base) * np.clip(-wm, 0, 1) * 0.75 + (ferro - base) * np.clip(wm, 0, 1) * 0.7
    col *= (1 + 0.05 * pnoise(rng, (N, N), 40))[..., None]
    col *= (1 + 0.04 * np.where(cross[L], lam, 0))[..., None]
    # Beirada das camadas duras mais clara (gasta), sulcos e fendas mais escuros.
    rim = smooth(0.0, 0.02, d_edge) * (1 - smooth(0.02, 0.05, d_edge)) * np.clip(hl, 0, 1)
    col *= (1 + 0.10 * rim)[..., None]
    col *= (1 - 0.25 * crack - 0.12 * chip - 0.2 * pits)[..., None]
    # Manchinhas de ferro.
    spots = smooth(1.8, 2.6, pnoise(rng, (N, N), 4)) * 0.5
    col = col + (ferro - col) * spots[..., None] * 0.5
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
    mat = bpy.data.materials.get('arenito') or bpy.data.materials.new('arenito')
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    a = nt.nodes.new('ShaderNodeAttribute'); a.attribute_name = 'cor'
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled'); bsdf.name = 'BSDF'
    nt.links.new(a.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = 0.92
    # Grão fino de areia (pequeno demais para a malha).
    tc = nt.nodes.new('ShaderNodeTexCoord')
    nz = nt.nodes.new('ShaderNodeTexNoise')
    nz.inputs['Scale'].default_value = 900.0
    nz.inputs['Detail'].default_value = 2.0
    nt.links.new(tc.outputs['Object'], nz.inputs['Vector'])
    bump = nt.nodes.new('ShaderNodeBump')
    bump.inputs['Distance'].default_value = 0.0008
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
    sc = bpy.data.scenes.get('arenito') or bpy.data.scenes.new('arenito')
    for o in list(sc.collection.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.window.scene = sc
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'GPU' if setup_gpu() != 'CPU' else 'CPU'
    if sc.world is None:
        sc.world = bpy.data.worlds.new('arenito_mundo')
    sc.world.light_settings.distance = 0.06
    h, col = fields()
    h = h - h.min()
    me = grid('arenito_relevo', h, col)
    me.materials.append(material())
    ob = bpy.data.objects.new('arenito_relevo', me)
    sc.collection.objects.link(ob)
    np.save(os.path.join(bpy.app.tempdir, 'arenito_h.npy'), h)
    return {'faces': len(me.polygons), 'h_min': float(h.min()), 'h_max': float(h.max())}


def bake(out_dir, res=2048, samples=16):
    sc = bpy.data.scenes['arenito']
    bpy.context.window.scene = sc
    tgt = sc.objects.get('alvo_arenito')
    if tgt is None:
        me = bpy.data.meshes.new('alvo_arenito')
        me.from_pydata([(0, 0, 0), (W, 0, 0), (W, W, 0), (0, W, 0)], [], [(0, 1, 2, 3)])
        uv = me.uv_layers.new(name='UVMap')
        for i, c in enumerate(((0, 0), (1, 0), (1, 1), (0, 1))):
            uv.data[i].uv = c
        tgt = bpy.data.objects.new('alvo_arenito', me)
        sc.collection.objects.link(tgt)
        tm = bpy.data.materials.new('alvo_arenito_mat')
        tm.use_nodes = True
        me.materials.append(tm)
    tm = tgt.data.materials[0]
    img_node = next((n for n in tm.node_tree.nodes if n.type == 'TEX_IMAGE'), None) or tm.node_tree.nodes.new('ShaderNodeTexImage')
    tm.node_tree.nodes.active = img_node
    src = sc.objects['arenito_relevo']
    for o in sc.objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = tgt
    b = sc.render.bake
    b.use_selected_to_active = True
    b.cage_extrusion = 0.2
    b.max_ray_distance = 0.4
    b.margin = 0
    sc.cycles.samples = samples
    mat = src.data.materials[0]
    res_d = {}

    def run(tag, btype, **kw):
        name = 'arenito_' + tag
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
    np.save(f'{out_dir}/arenito_raw.npy', np.stack([res_d[k] for k in ('cor', 'relevo', 'ao', 'altura')]))
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
    cor, rel, ao, alt = np.load(f'{raw_dir}/arenito_raw.npy')
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
    save_png(p[::2, ::2], f'{raw_dir}/arenito_previa.png', False)
    return {'alb_media_srgb': to_srgb(alb.reshape(-1, 3).mean(0)).round(3).tolist()}
