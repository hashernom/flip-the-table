"""Mojón: marcador de nivel máximo de las propiedades.

Bolardo bajo y grueso de calle: base ancha de caliza, fuste de 12 lados que se estrecha levemente, cúpula
baja y un anillo saliente hacia el tercio superior. Sin texto. Cada malla se hace por revolución de un
perfil (spin), así es estanca por construcción; el script lo comprueba (bordes abiertos y volumen con signo).

Medidas en studs: 1,6 de ancho y fondo, 3,2 de alto. Origen en el centro de la base, z = 0 a ras de suelo.
Frente hacia -Y (la figura es simétrica: el frente solo marca la orientación en la escena).

Salidas, en art/blender/slice/:
  marker_mojon_stone.fbx    caliza (una malla, un material)
  marker_mojon_ring.fbx     anillo (una malla; el juego lo tiñe con el color de la zona)
  marker_mojon_LOD1.fbx     versión reducida de las dos mallas
  marker-mojon-stats.json   triángulos, límites y comprobaciones

Y en art/render/: marker-mojon.png, solo para revisión técnica.

Uso: D:\\blender\\blender.exe --background --factory-startup --python art/blender/slice/build_marker_mojon.py
"""

import json
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_cine_lux import HERE, apply_modifiers, box, camera, count, export, flat, join, render, textured, uv_unwrap  # noqa: E402

SIDES = 12
LOD_RATIO = 0.4  # con 0,5 el LOD quedaba cerca del límite; 0,4 deja margen bajo el 50 %
TRIANGLE_BUDGET = 300
LOD_LIMIT = 0.5

# Perfil de la caliza, de (radio, altura). Empieza y acaba en el eje: la malla queda cerrada.
# Base 0-0,36 (radio 0,8 en el suelo), fuste que se estrecha de 0,56 a 0,46, cuello y cúpula baja hasta 3,2.
STONE_PROFILE = [
    (0.0, 0.0),
    (0.80, 0.0),
    (0.80, 0.26),
    (0.56, 0.36),
    (0.46, 2.60),
    (0.50, 2.75),
    (0.36, 3.02),
    (0.0, 3.20),
]

# Anillo saliente: perfil cerrado en forma de lente, a 2,26-2,50 (tercio superior, por encima de 2,13).
RING_PROFILE = [
    (0.44, 2.26),
    (0.60, 2.32),
    (0.66, 2.38),
    (0.60, 2.44),
    (0.44, 2.50),
]


def lathe(name, profile, mat, closed=False):
    """Revoluciona un perfil alrededor de Z en SIDES pasos. Recalcula normales para que apunten afuera."""
    bm = bmesh.new()
    verts = [bm.verts.new((r, 0.0, z)) for r, z in profile]
    pairs = [(i, i + 1) for i in range(len(verts) - 1)]
    if closed:
        pairs.append((len(verts) - 1, 0))
    edges = [bm.edges.new((verts[a], verts[b])) for a, b in pairs]
    bmesh.ops.spin(
        bm,
        geom=verts + edges,
        cent=(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        dvec=(0.0, 0.0, 0.0),
        angle=math.tau,
        steps=SIDES,
        use_merge=True,
    )
    # Los puntos del eje y la costura se repiten al girar: se funden para que la malla quede estanca.
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def audit(obj):
    """Bordes que no son de dos caras (0 en una malla cerrada) y volumen con signo (positivo si las normales miran afuera)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    open_edges = sum(1 for edge in bm.edges if not edge.is_manifold)
    volume = bm.calc_volume(signed=True)
    bm.free()
    return {"bordes_abiertos": open_edges, "volumen_con_signo": round(volume, 4), "normales_hacia_fuera": volume > 0}


def reduced(sources, name):
    """Versión reducida: cada malla se decima y luego se unen en una sola, como en build_cine_lux."""
    copies = []
    for source in sources:
        copy = source.copy()
        copy.data = source.data.copy()
        copy.name = f"{source.name}_copy"
        bpy.context.collection.objects.link(copy)
        decimate = copy.modifiers.new("Decimate", "DECIMATE")
        decimate.ratio = LOD_RATIO
        apply_modifiers(copy)
        copies.append(copy)
    return join(copies, name)


def stage(mats):
    """Suelo, sol y fondo: el mismo montaje que los renders de patrulla."""
    floor = box("floor", (40.0, 40.0, 0.2), (0, 0, -0.1), mats["floor"])
    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 4.2
    sun_data.angle = math.radians(1.0)
    sun = bpy.data.objects.new("sun", sun_data)
    bpy.context.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(90 - 34), 0, math.radians(-38))
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.68, 0.78, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    bpy.context.scene.world = world
    return floor


def extent(objs):
    points = [v.co for obj in objs for v in obj.data.vertices]
    lo = [min(p[i] for p in points) for i in range(3)]
    hi = [max(p[i] for p in points) for i in range(3)]
    return {"ancho_x": round(hi[0] - lo[0], 3), "fondo_y": round(hi[1] - lo[1], 3), "alto_z": round(hi[2] - lo[2], 3), "z_min": round(lo[2], 3), "z_max": round(hi[2], 3)}


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    scene.unit_settings.scale_length = 1.0

    mats = {
        "stone": textured("limestone", "concrete", "D2C9B4"),
        "copper": flat("cobre", "C97B3A", 0.45, 0.0),
        "floor": flat("floor", "A39C8E", 0.9),
        "avatar": flat("avatar_ref", "3A3F47", 0.8),
        "ref": flat("caja_ref", "8C929A", 0.7),
    }

    stone = lathe("marker_mojon_stone", STONE_PROFILE, mats["stone"])
    ring = lathe("marker_mojon_ring", RING_PROFILE, mats["copper"], closed=True)
    uv_unwrap(stone, 1.0)
    uv_unwrap(ring, 1.0)
    # Solo la caliza lleva textura; el anillo va plano porque el juego lo tiñe.
    meshes = [stone, ring]

    per_mesh = {obj.name: count(obj) for obj in meshes}
    total = sum(per_mesh.values())
    assert total <= TRIANGLE_BUDGET, f"el mojón supera el presupuesto: {total}"
    for obj in meshes:
        report = audit(obj)
        assert report["bordes_abiertos"] == 0, f"{obj.name} no es estanca"
        assert report["normales_hacia_fuera"], f"{obj.name} tiene caras invertidas"

    lod = reduced(meshes, "marker_mojon_LOD1")
    lod_total = count(lod)
    assert lod_total < total, f"el LOD no es menor: {lod_total} >= {total}"

    export(stone, "marker_mojon_stone.fbx")
    export(ring, "marker_mojon_ring.fbx")
    export(lod, "marker_mojon_LOD1.fbx")

    stats = {
        "marker_mojon_stone": {"triangulos": per_mesh["marker_mojon_stone"], "material": "caliza D2C9B4", **audit(stone)},
        "marker_mojon_ring": {"triangulos": per_mesh["marker_mojon_ring"], "material": "cobre C97B3A (plano, lo tiñe el juego)", **audit(ring)},
        "total_triangulos": total,
        "marker_mojon_LOD1": {"triangulos": lod_total, "fraccion_del_total": round(lod_total / total, 3), "mayor_que_el_50_por_ciento": lod_total / total >= LOD_LIMIT},
        "medidas": extent(meshes),
        "limites": {"triangulos_totales_max": TRIANGLE_BUDGET, "lod_max_fraccion": LOD_LIMIT, "sides": SIDES},
        "anillo_z": [min(z for _, z in RING_PROFILE), max(z for _, z in RING_PROFILE)],
    }
    with open(os.path.join(HERE, "marker-mojon-stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("MOJON_STATS", json.dumps(stats))

    # Revisión: el mojón (la LOD se oculta) junto a una figura de 6 de alto y una caja de 8x4x5.
    lod.hide_render = True
    lod.hide_viewport = True
    avatar = box("avatar_ref", (1.6, 1.2, 6.0), (-2.2, 0.0, 3.0), mats["avatar"])
    # Detrás del mojón y algo a la derecha: no tapa la pieza.
    reference = box("caja_ref", (8.0, 4.0, 5.0), (4.6, 2.0, 2.5), mats["ref"])
    stage(mats)

    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 960
    scene.view_settings.look = "AgX - Medium High Contrast"
    render(scene, camera("mojon", (-1.0, -16.0, 3.6), (1.3, 0.0, 2.4), 50), "marker-mojon.png")


if __name__ == "__main__":
    main()
