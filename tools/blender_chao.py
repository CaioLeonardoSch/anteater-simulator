# Gera as estampas do chão do cerrado (solo de capim e terra das trilhas) no Blender.
# Rode dentro do Blender 5.x (por exemplo pelo MCP do Blender ou no console Python):
#   import sys; sys.path.append(r"<pasta>/tools"); import blender_chao as c
#   for k in ("solo", "terra"):
#       c.build(k); c.bake(k, PASTA_TEMP, 2048, 16); c.compose(k, PASTA_TEMP, DESTINO)
# DESTINO: assets/textures/chao (solo) e assets/textures/trilha (terra).
# Saída: cor.png (cor + altura no alfa), relevo.png (normal map) e aspereza.png.

"""Monta no Blender um pedaço de chão (2 x 2 m) que se repete sem emenda e assa
cor, relevo, aspereza e altura em imagens. Usado para o chão do cerrado."""
import bpy, bmesh, math, random, os
import numpy as np
from mathutils import Vector, Matrix

T = 2.0        # lado do pedaço, em metros
HMAX = 0.03    # altura que vira branco na imagem de altura


def srgb(r, g, b):
    return (r ** 2.2, g ** 2.2, b ** 2.2, 1.0)


# ------------------------------------------------------------------ cena

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


def new_scene(name):
    sc = bpy.data.scenes.get(name) or bpy.data.scenes.new(name)
    for o in list(sc.collection.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.window.scene = sc
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'GPU' if setup_gpu() != 'CPU' else 'CPU'
    if sc.world is None:
        sc.world = bpy.data.worlds.new(name + '_mundo')
    sc.world.light_settings.distance = 0.04
    return sc


def link(sc, ob):
    sc.collection.objects.link(ob)
    return ob


# ------------------------------------------------------------------ nós

class NB:
    """Atalhos para montar nós de material."""

    def __init__(self, mat):
        mat.use_nodes = True
        self.nt = mat.node_tree
        self.N = self.nt.nodes
        self.L = self.nt.links
        for n in list(self.N):
            self.N.remove(n)

    def node(self, t, **kw):
        n = self.N.new(t)
        for k, v in kw.items():
            setattr(n, k, v)
        return n

    def link(self, a, b):
        self.L.new(a, b)

    def put(self, sock, v):
        if v is None:
            return
        if isinstance(v, (int, float)):
            sock.default_value = v
        elif isinstance(v, tuple):
            sock.default_value = v
        else:
            self.L.new(v, sock)

    def m(self, op, a, b=None, c=None, clamp=False):
        n = self.node('ShaderNodeMath', operation=op, use_clamp=clamp)
        for i, v in enumerate((a, b, c)):
            self.put(n.inputs[i], v)
        return n.outputs[0]

    def smooth(self, e0, e1, x):
        n = self.node('ShaderNodeMapRange', interpolation_type='SMOOTHSTEP')
        self.put(n.inputs['Value'], x)
        n.inputs['From Min'].default_value = e0
        n.inputs['From Max'].default_value = e1
        return n.outputs['Result']

    def mixc(self, fac, a, b):
        n = self.node('ShaderNodeMix', data_type='RGBA', blend_type='MIX')
        self.put(n.inputs['Factor'], fac)
        self.put(n.inputs['A'], a)
        self.put(n.inputs['B'], b)
        return n.outputs['Result']

    def mulc(self, a, fac):
        n = self.node('ShaderNodeMix', data_type='RGBA', blend_type='MULTIPLY')
        n.inputs['Factor'].default_value = 1.0
        self.put(n.inputs['A'], a)
        g = self.node('ShaderNodeCombineXYZ')
        for i in range(3):
            self.put(g.inputs[i], fac)
        self.L.new(g.outputs[0], n.inputs['B'])
        return n.outputs['Result']

    def torus(self, warp=None, warp_amt=0.0):
        """Coordenadas 4D que dão a volta no pedaço: qualquer textura lida com
        elas se repete sem emenda a cada T metros."""
        geo = self.node('ShaderNodeNewGeometry')
        sep = self.node('ShaderNodeSeparateXYZ')
        self.link(geo.outputs['Position'], sep.inputs[0])
        a = self.m('MULTIPLY', sep.outputs[0], 2 * math.pi / T)
        b = self.m('MULTIPLY', sep.outputs[1], 2 * math.pi / T)
        vec = self.node('ShaderNodeCombineXYZ')
        self.put(vec.inputs[0], self.m('COSINE', a))
        self.put(vec.inputs[1], self.m('SINE', a))
        self.put(vec.inputs[2], self.m('COSINE', b))
        return vec.outputs[0], self.m('SINE', b)

    def noise(self, tc, scale, detail=3.0, rough=0.5, distort=0.0, offset=None):
        v, w = tc
        n = self.node('ShaderNodeTexNoise', noise_dimensions='4D')
        self.put(n.inputs['Vector'], v)
        self.put(n.inputs['W'], w if offset is None else self.m('ADD', w, offset))
        n.inputs['Scale'].default_value = scale
        n.inputs['Detail'].default_value = detail
        n.inputs['Roughness'].default_value = rough
        n.inputs['Distortion'].default_value = distort
        return n

    def voronoi(self, tc, scale, feature='F1', rand=1.0, vec=None):
        v, w = tc
        n = self.node('ShaderNodeTexVoronoi', voronoi_dimensions='4D', feature=feature)
        self.put(n.inputs['Vector'], v if vec is None else vec)
        self.put(n.inputs['W'], w)
        n.inputs['Scale'].default_value = scale
        n.inputs['Randomness'].default_value = rand
        return n

    def finish(self, color, rough, height_bump, bump_dist, height_emit, mat):
        """BSDF (com relevo) e um nó de emissão com a altura, para o assado da
        altura. Os dois ficam prontos; set_mode escolhe qual vai para a saída."""
        bsdf = self.node('ShaderNodeBsdfPrincipled', name='BSDF')
        self.put(bsdf.inputs['Base Color'], color)
        self.put(bsdf.inputs['Roughness'], rough)
        if height_bump is not None:
            bump = self.node('ShaderNodeBump')
            bump.inputs['Strength'].default_value = 1.0
            bump.inputs['Distance'].default_value = bump_dist
            self.put(bump.inputs['Height'], height_bump)
            self.link(bump.outputs['Normal'], bsdf.inputs['Normal'])
        em = self.node('ShaderNodeEmission', name='HEIGHT')
        em.inputs['Strength'].default_value = 1.0
        g = self.node('ShaderNodeCombineXYZ')
        for i in range(3):
            self.put(g.inputs[i], height_emit)
        self.link(g.outputs[0], em.inputs['Color'])
        out = self.node('ShaderNodeOutputMaterial')
        self.link(bsdf.outputs[0], out.inputs['Surface'])
        mat['chao'] = True


def set_mode(mode):
    for m in bpy.data.materials:
        if not m.get('chao'):
            continue
        nt = m.node_tree
        out = next(n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL')
        src = nt.nodes['BSDF' if mode == 'bsdf' else 'HEIGHT']
        for l in list(out.inputs['Surface'].links):
            nt.links.remove(l)
        nt.links.new(src.outputs[0], out.inputs['Surface'])


def z_height(nb):
    geo = nb.node('ShaderNodeNewGeometry')
    sep = nb.node('ShaderNodeSeparateXYZ')
    nb.link(geo.outputs['Position'], sep.inputs[0])
    return nb.m('DIVIDE', sep.outputs[2], HMAX, clamp=True)


def attr(nb, name):
    a = nb.node('ShaderNodeAttribute', attribute_name=name)
    return a.outputs['Fac']


def ramp(nb, fac, colors):
    r = nb.node('ShaderNodeValToRGB')
    nb.link(fac, r.inputs['Fac'])
    els = r.color_ramp.elements
    while len(els) < len(colors):
        els.new(0.5)
    for i, c in enumerate(colors):
        els[i].position = i / (len(colors) - 1)
        els[i].color = c
    return r.outputs['Color']


# ------------------------------------------------------------------ materiais

def mat_solo_capim():
    mat = bpy.data.materials.get('chao_solo') or bpy.data.materials.new('chao_solo')
    nb = NB(mat)
    tc = nb.torus()
    big = nb.noise(tc, 0.55, 3, 0.5).outputs['Fac']
    mid = nb.noise(tc, 2.2, 4, 0.55, offset=3.1).outputs['Fac']
    fine = nb.noise(tc, 9.0, 3, 0.6, offset=7.7).outputs['Fac']
    grit = nb.voronoi(tc, 24.0, rand=1.0)
    grit_h = nb.m('SUBTRACT', 1.0, nb.smooth(0.0, 0.32, grit.outputs['Distance']))
    grit_h = nb.m('MULTIPLY', grit_h, nb.smooth(0.35, 0.7, grit.outputs['Color'] if False else fine))
    # cor: manchas úmidas (escuras) e secas (claras), grãozinhos claros
    damp, base, dry = srgb(0.30, 0.25, 0.15), srgb(0.42, 0.35, 0.21), srgb(0.55, 0.47, 0.31)
    c = nb.mixc(nb.smooth(0.3, 0.7, big), damp, base)
    c = nb.mixc(nb.m('MULTIPLY', nb.smooth(0.5, 0.8, mid), 0.7), c, dry)
    c = nb.mulc(c, nb.m('ADD', 0.86, nb.m('MULTIPLY', fine, 0.28)))
    c = nb.mixc(nb.m('MULTIPLY', grit_h, 0.35), c, srgb(0.62, 0.55, 0.42))
    h = nb.m('ADD', nb.m('MULTIPLY', mid, 0.6), nb.m('MULTIPLY', grit_h, 0.4))
    rough = nb.m('ADD', 0.86, nb.m('MULTIPLY', big, 0.1))
    nb.finish(c, rough, h, 0.010, nb.m('MULTIPLY', h, 0.010 / HMAX), mat)
    return mat


def mat_terra_trilha():
    mat = bpy.data.materials.get('chao_terra') or bpy.data.materials.new('chao_terra')
    nb = NB(mat)
    tc = nb.torus()
    big = nb.noise(tc, 0.5, 3, 0.5).outputs['Fac']
    mid = nb.noise(tc, 2.0, 4, 0.55, offset=5.3).outputs['Fac']
    fine = nb.noise(tc, 10.0, 3, 0.6, offset=1.9).outputs['Fac']
    # coordenadas um pouco tortas para as rachaduras não ficarem retas demais
    warp = nb.noise(tc, 2.5, 2, 0.5, offset=9.0).outputs['Color']
    wv = nb.node('ShaderNodeVectorMath', operation='MULTIPLY_ADD')
    nb.link(warp, wv.inputs[0])
    wv.inputs[1].default_value = (0.18, 0.18, 0.18)
    nb.link(tc[0], wv.inputs[2])
    v1 = nb.voronoi(tc, 1.7, feature='DISTANCE_TO_EDGE', vec=wv.outputs[0])
    d1 = v1.outputs['Distance']
    v2 = nb.voronoi(tc, 4.2, feature='DISTANCE_TO_EDGE', vec=wv.outputs[0])
    d2 = v2.outputs['Distance']
    crack1 = nb.m('SUBTRACT', 1.0, nb.smooth(0.0, 0.035, d1))
    crack2 = nb.m('MULTIPLY', nb.m('SUBTRACT', 1.0, nb.smooth(0.0, 0.03, d2)), nb.smooth(0.45, 0.65, mid))
    crack = nb.m('MAXIMUM', crack1, nb.m('MULTIPLY', crack2, 0.7))
    # placas levemente abauladas, rachaduras afundadas, pisoteio nas manchas grandes
    plate = nb.smooth(0.0, 0.16, d1)
    h = nb.m('MULTIPLY', plate, 0.55)
    h = nb.m('SUBTRACT', h, nb.m('MULTIPLY', crack, 0.45))
    h = nb.m('ADD', h, nb.m('MULTIPLY', fine, 0.12))
    h = nb.m('ADD', h, nb.m('MULTIPLY', big, 0.35))
    h = nb.m('ADD', h, 0.45)
    base, light, dark = srgb(0.66, 0.38, 0.24), srgb(0.76, 0.50, 0.34), srgb(0.40, 0.21, 0.13)
    c = nb.mixc(nb.smooth(0.35, 0.75, big), base, light)
    c = nb.mulc(c, nb.m('ADD', 0.9, nb.m('MULTIPLY', fine, 0.2)))
    edge = nb.m('SUBTRACT', nb.smooth(0.02, 0.06, d1), nb.smooth(0.06, 0.12, d1))
    c = nb.mixc(nb.m('MULTIPLY', edge, 0.25), c, light)
    c = nb.mixc(nb.m('MULTIPLY', crack, 0.85), c, dark)
    rough = nb.m('ADD', 0.72, nb.m('MULTIPLY', crack, 0.2))
    rough = nb.m('ADD', rough, nb.m('MULTIPLY', nb.m('SUBTRACT', 1.0, big), 0.06))
    nb.finish(c, rough, h, 0.005, nb.m('MULTIPLY', h, 0.005 / HMAX), mat)
    return mat


def mat_cat(name, colors, rough=0.85, leaf=False, jitter=0.15):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    nb = NB(mat)
    c = ramp(nb, attr(nb, 'rnd'), colors)
    tex = nb.node('ShaderNodeTexNoise')
    tex.inputs['Scale'].default_value = 300.0
    tex.inputs['Detail'].default_value = 2.0
    c = nb.mulc(c, nb.m('ADD', 1.0 - jitter, nb.m('MULTIPLY', tex.outputs['Fac'], jitter * 2)))
    if leaf:
        ac = attr(nb, 'across')
        a = nb.m('ABSOLUTE', ac)
        rib = nb.m('SUBTRACT', 1.0, nb.smooth(0.0, 0.12, a))
        edge = nb.smooth(0.7, 1.0, a)
        c = nb.mulc(c, nb.m('SUBTRACT', 1.0, nb.m('ADD', nb.m('MULTIPLY', rib, 0.25), nb.m('MULTIPLY', edge, 0.2))))
    nb.finish(c, rough, None, 0, z_height(nb), mat)
    return mat


# ------------------------------------------------------------------ objetos espalhados

def periodic_density(rng, n_waves=6, max_f=3):
    """Função que se repete no pedaço, para agrupar as coisas em manchas."""
    waves = [(rng.randint(-max_f, max_f), rng.randint(-max_f, max_f), rng.uniform(0, 6.28), rng.uniform(0.5, 1))
             for _ in range(n_waves)]
    waves = [w for w in waves if w[0] or w[1]] or [(1, 0, 0, 1)]

    def f(x, y):
        s = sum(a * math.sin(2 * math.pi * (fx * x + fy * y) / T + ph) for fx, fy, ph, a in waves)
        return 0.5 + 0.5 * s / sum(w[3] for w in waves)
    return f


def sample_points(rng, n, dens=None, power=2.0):
    pts = []
    while len(pts) < n:
        x, y = rng.uniform(0, T), rng.uniform(0, T)
        if dens is None or rng.random() < dens(x, y) ** power:
            pts.append((x, y))
    return pts


class Builder:
    def __init__(self, name):
        self.bm = bmesh.new()
        self.name = name
        self.rnd = self.bm.verts.layers.float.new('rnd')
        self.across = self.bm.verts.layers.float.new('across')

    def add(self, verts, faces, x, y, rot, rad, rv, across=None):
        """Põe a peça em (x, y) e cópias deslocadas de T quando encosta na borda."""
        R = Matrix.Rotation(rot, 3, 'Z')
        for dx in (-T, 0, T):
            for dy in (-T, 0, T):
                cx, cy = x + dx, y + dy
                if cx < -rad or cx > T + rad or cy < -rad or cy > T + rad:
                    continue
                vs = []
                for i, v in enumerate(verts):
                    p = R @ Vector(v)
                    bv = self.bm.verts.new((p.x + cx, p.y + cy, p.z))
                    bv[self.rnd] = rv
                    if across is not None:
                        bv[self.across] = across[i]
                    vs.append(bv)
                for f in faces:
                    try:
                        self.bm.faces.new([vs[i] for i in f])
                    except ValueError:
                        pass

    def finish(self, sc, mat, smooth=True):
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for p in me.polygons:
            p.use_smooth = smooth
        me.materials.append(mat)
        ob = bpy.data.objects.new(self.name, me)
        return link(sc, ob)


_ico_cache = {}


def ico(sub=2):
    if sub not in _ico_cache:
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
        verts = [tuple(v.co) for v in bm.verts]
        idx = {v: i for i, v in enumerate(bm.verts)}
        faces = [[idx[v] for v in f.verts] for f in bm.faces]
        bm.free()
        _ico_cache[sub] = (verts, faces)
    return _ico_cache[sub]


def lump(rng, sx, sy, sz, jitter, sink):
    verts, faces = ico(2)
    # deformação suave: soma de umas ondas aleatórias na esfera
    waves = [(Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))).normalized(), rng.uniform(1.5, 3.5), rng.uniform(0, 6.28)) for _ in range(4)]
    out = []
    for v in verts:
        p = Vector(v)
        k = 1.0 + jitter * sum(math.sin(d.dot(p) * f + ph) for d, f, ph in waves) / 4
        out.append((p.x * sx * k, p.y * sy * k, p.z * sz * k + sz * sink))
    return out, faces


def leaf_shape(rng, length, width, curl, n_len=9, n_w=5):
    verts, across, faces = [], [], []
    for i in range(n_len):
        t = i / (n_len - 1)
        w = width * (math.sin(math.pi * t) ** 0.7) * (1.0 - 0.25 * t)
        y = (t - 0.5) * length
        for j in range(n_w):
            s = j / (n_w - 1) * 2 - 1
            x = s * max(w, width * 0.02)
            z = curl * width * s * s + 0.15 * length * (t - 0.5) ** 2 * rng.uniform(0, 1)
            verts.append((x, y, z))
            across.append(s)
    for i in range(n_len - 1):
        for j in range(n_w - 1):
            a = i * n_w + j
            faces.append([a, a + 1, a + n_w + 1, a + n_w])
    return verts, faces, across


def blade_shape(rng, length, width, n_len=10):
    bend = rng.uniform(-0.25, 0.25) * length
    sag = rng.uniform(0, 0.004)
    verts, faces = [], []
    for i in range(n_len):
        t = i / (n_len - 1)
        y = (t - 0.5) * length
        x0 = bend * (t - 0.5) ** 2 * 4
        w = width * (1.0 - 0.6 * t)
        z = sag * (1 - ((t - 0.5) * 2) ** 2)
        verts += [(x0 - w, y, z), (x0, y, z + w * 0.5), (x0 + w, y, z)]
    for i in range(n_len - 1):
        a = i * 3
        faces += [[a, a + 1, a + 4, a + 3], [a + 1, a + 2, a + 5, a + 4]]
    return verts, faces


def twig_shape(rng, length, radius, n_len=8, n_r=6):
    bend = rng.uniform(-0.15, 0.15) * length
    verts, faces = [], []
    for i in range(n_len):
        t = i / (n_len - 1)
        y = (t - 0.5) * length
        x0 = bend * (t - 0.5) ** 2 * 4
        r = radius * (1.0 - 0.3 * t)
        for j in range(n_r):
            a = 2 * math.pi * j / n_r
            verts.append((x0 + math.cos(a) * r, y, radius + math.sin(a) * r))
    for i in range(n_len - 1):
        for j in range(n_r):
            a, b = i * n_r + j, i * n_r + (j + 1) % n_r
            faces.append([a, a + n_r, b + n_r, b])
    return verts, faces


def scatter(sc, prefix, seed, counts, palettes):
    rng = random.Random(seed)
    dens = periodic_density(rng)
    dens2 = periodic_density(rng, max_f=4)
    obs = []
    if counts.get('torrao'):
        b = Builder(prefix + '_torroes')
        for x, y in sample_points(rng, counts['torrao'], dens, 1.5):
            r = rng.uniform(0.008, 0.026)
            v, f = lump(rng, r * rng.uniform(1.0, 1.4), r, r * rng.uniform(0.45, 0.7), 0.3, -0.15)
            b.add(v, f, x, y, rng.uniform(0, 6.28), r * 1.6, rng.random())
        obs.append(b.finish(sc, mat_cat(prefix + '_torrao', palettes['torrao'], 0.92)))
    if counts.get('pedrinha'):
        b = Builder(prefix + '_pedrinhas')
        for x, y in sample_points(rng, counts['pedrinha'], dens2, 1.0):
            r = rng.uniform(0.005, 0.011) if rng.random() < 0.8 else rng.uniform(0.011, 0.02)
            v, f = lump(rng, r * rng.uniform(1.0, 1.5), r, r * rng.uniform(0.5, 0.8), 0.12, 0.1)
            b.add(v, f, x, y, rng.uniform(0, 6.28), r * 1.6, rng.random())
        obs.append(b.finish(sc, mat_cat(prefix + '_pedrinha', palettes['pedrinha'], 0.7, jitter=0.08)))
    if counts.get('folha'):
        b = Builder(prefix + '_folhas')
        for x, y in sample_points(rng, counts['folha'], dens, 2.5):
            L = rng.uniform(0.035, 0.075)
            v, f, ac = leaf_shape(rng, L, L * rng.uniform(0.18, 0.3), rng.uniform(0.1, 0.5))
            z0 = rng.uniform(0.002, 0.010)
            v = [(p[0], p[1], p[2] + z0) for p in v]
            b.add(v, f, x, y, rng.uniform(0, 6.28), L, rng.random(), ac)
        obs.append(b.finish(sc, mat_cat(prefix + '_folha', palettes['folha'], 0.8, leaf=True)))
    if counts.get('palha'):
        b = Builder(prefix + '_palhas')
        for x, y in sample_points(rng, counts['palha'], dens, 1.2):
            L = rng.uniform(0.06, 0.2)
            v, f = blade_shape(rng, L, rng.uniform(0.0022, 0.0035))
            z0 = rng.uniform(0.001, 0.014)
            v = [(p[0], p[1], p[2] + z0) for p in v]
            b.add(v, f, x, y, rng.uniform(0, 6.28), L, rng.random())
        obs.append(b.finish(sc, mat_cat(prefix + '_palha', palettes['palha'], 0.6, jitter=0.1)))
    if counts.get('graveto'):
        b = Builder(prefix + '_gravetos')
        for x, y in sample_points(rng, counts['graveto'], dens, 2.0):
            L = rng.uniform(0.05, 0.13)
            v, f = twig_shape(rng, L, rng.uniform(0.0018, 0.0035))
            b.add(v, f, x, y, rng.uniform(0, 6.28), L, rng.random())
        obs.append(b.finish(sc, mat_cat(prefix + '_graveto', palettes['graveto'], 0.85)))
    return obs


# ------------------------------------------------------------------ chão base e alvo

def plane(sc, name, size0, size1, z, mat=None):
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, z)) for x, y in ((size0, size0), (size1, size0), (size1, size1), (size0, size1))]
    f = bm.faces.new(vs)
    uv = bm.loops.layers.uv.new('UVMap')
    for loop, c in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        loop[uv].uv = c
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if mat:
        me.materials.append(mat)
    return link(sc, bpy.data.objects.new(name, me))


def build(kind):
    sc = new_scene('chao_' + kind)
    if kind == 'solo':
        ground = mat_solo_capim()
        pal = {
            'torrao': [srgb(0.30, 0.24, 0.14), srgb(0.40, 0.33, 0.20), srgb(0.50, 0.42, 0.27)],
            'pedrinha': [srgb(0.46, 0.40, 0.31), srgb(0.56, 0.50, 0.40), srgb(0.54, 0.42, 0.31)],
            'folha': [srgb(0.36, 0.26, 0.15), srgb(0.48, 0.36, 0.21), srgb(0.58, 0.48, 0.30)],
            'palha': [srgb(0.52, 0.43, 0.26), srgb(0.62, 0.52, 0.32), srgb(0.70, 0.60, 0.38)],
            'graveto': [srgb(0.24, 0.17, 0.11), srgb(0.36, 0.27, 0.18), srgb(0.46, 0.38, 0.28)],
        }
        counts = {'torrao': 300, 'pedrinha': 220, 'folha': 70, 'palha': 110, 'graveto': 14}
    else:
        ground = mat_terra_trilha()
        pal = {
            'torrao': [srgb(0.52, 0.29, 0.18), srgb(0.64, 0.37, 0.23), srgb(0.74, 0.47, 0.31)],
            'pedrinha': [srgb(0.58, 0.40, 0.29), srgb(0.66, 0.50, 0.38), srgb(0.62, 0.36, 0.24)],
            'folha': [srgb(0.44, 0.29, 0.15), srgb(0.60, 0.42, 0.22)],
            'palha': [srgb(0.70, 0.56, 0.32), srgb(0.82, 0.70, 0.46)],
        }
        counts = {'torrao': 120, 'pedrinha': 90, 'folha': 6, 'palha': 16}
    plane(sc, 'base', -0.3, T + 0.3, 0.0, ground)
    obs = scatter(sc, kind, 7 if kind == 'solo' else 13, counts, pal)
    tri = sum(len(o.data.polygons) for o in obs)
    return {'scene': sc.name, 'objects': [o.name for o in sc.objects], 'faces': tri}


def bake(kind, out_dir, res=1024, samples=24):
    sc = bpy.data.scenes['chao_' + kind]
    bpy.context.window.scene = sc
    tgt = sc.objects.get('alvo_' + kind) or plane(sc, 'alvo_' + kind, 0.0, T, 0.0)
    tm = bpy.data.materials.get('alvo_mat') or bpy.data.materials.new('alvo_mat')
    tm.use_nodes = True
    if not tgt.data.materials:
        tgt.data.materials.append(tm)
    img_node = next((n for n in tm.node_tree.nodes if n.type == 'TEX_IMAGE'), None) or tm.node_tree.nodes.new('ShaderNodeTexImage')
    tm.node_tree.nodes.active = img_node

    for o in sc.objects:
        o.select_set(o != tgt)
        o.hide_render = False
    tgt.select_set(True)
    bpy.context.view_layer.objects.active = tgt

    b = sc.render.bake
    b.use_selected_to_active = True
    b.cage_extrusion = 0.08
    b.max_ray_distance = 0.2
    b.margin = 0
    sc.cycles.samples = samples
    results = {}

    def run(tag, btype, **kw):
        name = f'{kind}_{tag}'
        img = bpy.data.images.get(name)
        if img and (img.size[0] != res):
            bpy.data.images.remove(img)
            img = None
        img = img or bpy.data.images.new(name, res, res, float_buffer=True, alpha=False)
        img.colorspace_settings.is_data = True
        img_node.image = img
        bpy.ops.object.bake(type=btype, **kw)
        a = np.empty(res * res * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        results[tag] = a.reshape(res, res, 4)

    set_mode('bsdf')
    b.use_pass_direct = False
    b.use_pass_indirect = False
    b.use_pass_color = True
    run('cor', 'DIFFUSE', pass_filter={'COLOR'})
    run('relevo', 'NORMAL', normal_space='TANGENT')
    run('aspereza', 'ROUGHNESS')
    run('ao', 'AO')
    set_mode('height')
    run('altura', 'EMIT')
    set_mode('bsdf')
    np.save(f'{out_dir}/{kind}_raw.npy', np.stack([results[k] for k in ('cor', 'relevo', 'aspereza', 'ao', 'altura')]))
    return {k: [float(v.min()), float(v.max()), float(v[..., :3].mean())] for k, v in results.items()}


# ------------------------------------------------------------------ saída

def to_srgb(x):
    x = np.clip(x, 0, 1)
    return np.where(x <= 0.0031308, x * 12.92, 1.055 * np.power(x, 1 / 2.4) - 0.055)


def save_png(arr, path, alpha=True):
    """arr: (h, w, 4) já codificado (0..1), linhas de baixo para cima (como no Blender)."""
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


def compose(kind, raw_dir, out_dir, ao_amt=0.55, sun=(0.55, 0.25, 0.8)):
    cor, rel, asp, ao, alt = np.load(f'{raw_dir}/{kind}_raw.npy')
    alb = cor[..., :3] * (1 - ao_amt + ao_amt * ao[..., :1])
    a = np.ones_like(cor)
    a[..., :3] = to_srgb(alb)
    a[..., 3] = np.clip(alt[..., 0], 0, 1)
    save_png(a, f'{out_dir}/cor.png', True)
    n = rel.copy(); n[..., 3] = 1
    save_png(n, f'{out_dir}/relevo.png', False)
    r = np.ones_like(cor); r[..., :3] = asp[..., :1]
    save_png(r, f'{out_dir}/aspereza.png', False)
    # prévia: cor | relevo | iluminada por um sol baixo
    nv = rel[..., :3] * 2 - 1
    s = np.array(sun); s = s / np.linalg.norm(s)
    lam = np.clip((nv * s).sum(-1, keepdims=True), 0, 1)
    lit = alb * (0.25 + 0.95 * lam) * 2.2
    p = np.ones((cor.shape[0], cor.shape[1] * 3, 4), np.float32)
    w = cor.shape[1]
    p[:, :w, :3] = to_srgb(alb * 2.2)
    p[:, w:2 * w, :3] = rel[..., :3]
    p[:, 2 * w:, :3] = to_srgb(lit)
    save_png(p, f'{raw_dir}/{kind}_previa.png', False)
    return {'alb_media_srgb': to_srgb(alb.reshape(-1, 3).mean(0)).round(3).tolist()}
