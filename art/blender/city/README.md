# Barrios de Metrópolis

Cómo se produce la calle de cada barrio. Es la parte de arte de la Tarea 1 del plan 07: cada barrio
tiene su acera, su mobiliario y su fondo, y se distinguen **por la silueta**, no solo por el color
(`art/guia-de-estilo.md`, §7).

## Qué hay aquí

| Archivo | Qué es |
| --- | --- |
| `city_kit.py` | Utilidades comunes: lienzo a escala, cajas, cilindros, agrupado por material, LOD, exportación, estadísticas y láminas de revisión. |
| `centro.py` | El barrio de referencia: ladrillo y caliza, toldos, sombra dura. Su calle es la plantilla de las otras tres. |
| `puerto.py`, `zona-alta.py`, `industrial.py` | Los otros tres barrios. |
| `<barrio>.blend` | Escena de revisión. El `.blend` no es la fuente: lo es el guion. |
| `<barrio>-stats.json` | Triángulos y mallas de cada asset. De aquí sale el manifiesto. |
| `uploaded*.json` | Nombre de archivo → `assetId`. Uno por barrio, para que dos barrios se puedan subir a la vez. |
| `capture.project.json` | Paquete de módulos para probar el código en Studio sin montar el proyecto entero. |

## Cómo se genera

```powershell
blender --background --factory-startup --python art/blender/city/centro.py
```

Deja los FBX, el `.blend`, las estadísticas y dos láminas en `art/render/` (`centro-calle.png` y
`centro-manzana.png`). Las láminas son revisión técnica: la aprobación se hace en el juego.

## Reglas de modelado

Salen de `art/PIPELINE.md` y `art/escala.md`, y no admiten excepciones por barrio:

- **1 unidad de Blender = 1 stud.** El avatar mide 6 y la planta, 7.
- **Origen en el centro de la base**, a ras de suelo (`z = 0`). Un origen dentro del modelo lo hunde.
- **El frente mira a -Y.** En el juego, `CFrame.lookAt` gira la pieza hacia la calle con ese lado.
- **Una malla, un material.** Open Cloud no trae materiales: `by_material` separa por material y
  `art/generators/city_assets.py` le pone color y material a cada malla.
- **Presupuesto.** Mobiliario, 2 000 triángulos y LOD obligatorio; fondo de ciudad, 3 000 y sin LOD.
- **La acera mide 40 × 7**, una pieza por casilla, con el bordillo en -Y. La ciudad la pone 0,4 sobre
  el asfalto, así que la chapa empieza en la cara superior; el bordillo sí baja hasta el suelo.

Los **nombres de material** son el sufijo de la malla (`centro-walk_curb` → `curb`) y el generador
los traduce a color y material de Roblox. La lista está en `MATERIALS`, en
`art/generators/city_assets.py`: si un barrio necesita un material nuevo, se añade ahí antes de usarlo.

## De Blender a la ciudad

```powershell
# 1. Subir las mallas del barrio (reanudable: lo ya subido no se repite)
$env:ROBLOX_OPENCLOUD_KEY=[Environment]::GetEnvironmentVariable('ROBLOX_OPENCLOUD_KEY','User')
$env:ROBLOX_CREATOR_USER_ID=[Environment]::GetEnvironmentVariable('ROBLOX_CREATOR_USER_ID','User')
pwsh -File art/generators/upload_city.ps1 -Prefix centro -OutFile art/blender/city/uploaded-centro.json

# 2. Escribir las mallas en ArtAssets.luau y las entradas del manifiesto
python art/generators/city_assets.py centro
```

El segundo paso es idempotente: sustituye el bloque entre `@barrios:inicio` y `@barrios:fin` de
`ArtAssets.street`, y añade o actualiza las entradas del manifiesto **en `Draft`**. Aprobar un asset
no lo hace un guion.

## Dónde se usa

- `src/shared/config/Barrios.luau` — la identidad de cada barrio: acera, reglas de mobiliario, fondos
  y paso de cebra. Todo lo ajustable vive ahí.
- `src/shared/config/CityLayout.luau` — `dressingFor(sizeId, barrioId)`, `backdropsFor` y
  `barriosFor`: convierte esa identidad en posiciones.
- `src/client/world/StreetDressing.luau` — copia las mallas de cada pieza en su sitio.
- `src/client/world/CityBuilder.luau` — coloca el fondo de los barrios del tamaño, y lo recoloca
  (`refreshBackdrops`) cuando las mallas terminan de cargar.
