# Tubería de assets

Cómo pasa un modelo de Blender al juego sin perder escala, nombres ni presupuestos. Este documento
es la parte técnica de la subfase 06; el gusto visual lo fija la guía de estilo.

**Estado:** los pasos de Blender y las reglas están comprobados contra la documentación oficial el
2026-11-02 y ejecutados por `art/blender/blockout/build_blockout.py`. La importación real en Studio
y las medidas en móvil siguen pendientes: necesitan tu cuenta y tu móvil de referencia.

## 1. Escala y unidades

La referencia es el avatar de Roblox: **6 studs de alto**, unos 1,70 m. Todo lo demás se mide
contra eso.

| Dónde | Ajuste | Valor |
| --- | --- | --- |
| Blender, propiedades de escena | Unit System | `None` |
| Blender, propiedades de escena | Rotation | `Degrees` |
| Blender, exportar FBX | Transform > Apply Scalings | `FBX Unit Scale` |
| Blender, exportar FBX | Forward / Up | `Z Forward` / `Y Up` |
| Blender, exportar FBX | Path Mode / Embed Textures | `Copy` / activado |
| Blender, exportar FBX | Add Leaf Bones / Bake Animation | desactivados |
| Studio, importar | World Forward / World Up | `Front` / `Top` |
| Studio, importar | Scale Unit | `Stud` |

Con `Unit System = None` y `FBX Unit Scale`, **1 unidad de Blender es 1 stud**. No se toca ninguna
escala a mano ni se aplica `0,01`: el modelo se modela a tamaño final desde el primer cubo.

`glTF` es la alternativa que Roblox documenta sin configuración de escala. Si en la primera
importación real el FBX sale mal, se cambia a glTF antes de investigar nada más.

**Origen del asset:** en el centro de su base y a ras de suelo. Un edificio con el origen dentro
del modelo aparece medio hundido en la ciudad.

## 2. Presupuestos

El límite duro de Roblox es de **20 000 triángulos por malla**. Los del juego son menores a
propósito, porque en pantalla hay una ciudad entera.

| Categoría | Id | Triángulos | Menor detalle |
| --- | --- | --- | --- |
| Edificio de la ruta | `Building` | 10 000 | Obligatoria |
| Ficha | `Token` | 8 000 | Obligatoria |
| Personaje de escena | `SceneCharacter` | 5 000 | Obligatoria |
| Objeto repetido | `RepeatedProp` | 2 000 | Obligatoria |
| Fondo de ciudad | `CityBackdrop` | 3 000 | Opcional |

Los valores viven en `tools/manifest.luau` y las pruebas los comprueban. Un asset por encima de su
presupuesto no pasa `lune run tools/check`.

## 3. Requisitos del modelo

Tomados de las especificaciones oficiales de mallas:

- Geometría **estanca**, sin agujeros ni caras invertidas.
- **Sin n-gons**: cuads siempre que se pueda.
- **Volumen**: nada de espesor cero.
- Una sola pista de animación por exportación; si hay varias, una exportación por animación.
- Mapas de normales en formato **OpenGL** (canal G sin invertir) y con **tangentes** en la malla:
  sin tangentes, el normal map no se aplica.
- Una malla, un material principal: cada material extra multiplica las llamadas de dibujado.

## 4. Materiales y `SurfaceAppearance`

`SurfaceAppearance` aplica mapas PBR sobre un `MeshPart`: `ColorMap` (albedo), `NormalMap`,
`RoughnessMap`, `MetalnessMap`, `EmissiveMask`, más `EmissiveStrength` y `EmissiveTint`.

**Aviso que condiciona la tubería:** casi todas esas propiedades son de **solo lectura para
scripts**. Los mapas se asignan al importar y se guardan en el asset; no se pueden cambiar en
tiempo de ejecución. Por eso los mapas entran en el FBX/textura desde el principio y no se ajustan
por código.

- `ColorMap` lleva la opacidad en el canal alfa; `AlphaMode` decide cómo se usa.
- `MetalnessMap` no hace nada con `Lighting.EnvironmentSpecularScale` a 0.
- `ResampleMode` a `Pixelated` solo para arte de píxeles; el resto, `Default`.

## 5. Nombres

- `id` en inglés y en minúsculas, con guiones: `taxi-token`, `city-backdrop`.
- El modelo y su versión reducida comparten nombre con sufijo: `<id>` y `<id>_LOD1`.
- El `id` del FBX, el del manifiesto y el que use `src/` son **el mismo texto**. Un id que no esté
  en el manifiesto no se puede referenciar desde `src/`.

## 6. Generar el blockout

El blockout es regenerable: la fuente es el guion, no el `.blend`.

```powershell
blender --background --factory-startup --python art/blender/blockout/build_blockout.py
```

Produce:

| Archivo | Para qué |
| --- | --- |
| `art/blender/blockout/blockout.blend` | Escena para abrir en Blender |
| `art/blender/blockout/blockout.fbx` | Escena entera, para la prueba de importación |
| `art/blender/blockout/assets/<id>.fbx` | Un asset por FBX, origen en la base |
| `art/blender/blockout/blockout-stats.json` | Triángulos, medidas y materiales reales |
| `art/render/blockout-*.png` | Vistas de escala (técnicas, no aprobación) |

Los triángulos del manifiesto salen de ahí, no se escriben a mano.

## 7. Importar y subir

### Por Open Cloud, sin clics

El camino que funciona y está probado el 2026-11-02 de punta a punta:

```powershell
$env:ROBLOX_OPENCLOUD_KEY   = "<clave con permiso de assets>"
$env:ROBLOX_CREATOR_USER_ID = "<tu id>"
pwsh -File art/generators/upload_model.ps1 -Path art/blender/facade/facade_wall.fbx -Name facade-wall
```

Devuelve el `assetId` y el estado de moderación. Después se inserta en Studio con
`insert_asset` o `InsertService:LoadAsset`, y se coloca agrupando las piezas con
`PivotTo(CFrame.new())` en cada una antes de mover el conjunto: **las piezas se insertan
desalineadas** porque cada modelo conserva su propio origen.

Tres cosas que cuestan una tarde si no se saben:

| Síntoma | Causa |
| --- | --- |
| 401 con `Authorization: Bearer` | La clave va en la cabecera **`x-api-key`** |
| 400 «not supported yet» con `assetType: Model` | El FBX debe ir con **`content-type: model/fbx`**, no `octet-stream` |
| 400 sin mensaje útil | El campo `request` debe ser su propia parte multipart con **`application/json`**; el `-Form` de PowerShell lo manda como texto |

**El modelo llega sin texturas.** Open Cloud no genera `SurfaceAppearance` desde el FBX
incrustado: el material se aplica después con `MaterialVariant` (§7.b).

### Con el importador de Studio

Si no hay clave a mano:

1. **File > Import** y elegir el `.fbx`.
2. En **File General**: *Import Only as a Model*, *Upload to Roblox* si el asset se va a reutilizar
   entre proyectos, creador correcto y *Insert Using Scene Position*.
3. En **File Transform**: *World Forward = Front*, *World Up = Top*.
4. En **File Geometry**: **Scale Unit = Stud**.
5. Importar y comprobar el tamaño contra una pieza de referencia.

### Texturas e imágenes

Las imágenes sí se pueden subir por el MCP de Studio, sirviendo la carpeta por HTTP local:

```powershell
python -m http.server 8801 --bind 0.0.0.0 --directory art
```

Los ids de la prueba están en `art/asset-ids.json`. Cada archivo subido es un asset de tu cuenta,
así que la subida sigue siendo tuya: un agente prepara y sirve, tú autorizas.

## 7.b Aplicar PBR sin mallas

`SurfaceAppearance` solo funciona en `MeshPart`. Para una `Part` normal —que es todo lo que hay
hasta que haya mallas de verdad— el camino es `MaterialVariant`:

1. Crear un `MaterialVariant` en `MaterialService` con `BaseMaterial`, `ColorMap`, `RoughnessMap` y
   `NormalMap`.
2. En la pieza: `Material` igual al `BaseMaterial` y `MaterialVariant` con el nombre del variant.

Comprobado en Studio el 2026-11-02 sobre las fachadas del look-dev. El mapa de normales tiene que
venir en formato OpenGL y la rugosidad en gris: un solo canal que sirva para cualquier lector.


## 8. Registro y aprobación

Cada asset es una entrada de `art/manifest.json`:

```json
{
  "id": "taxi-token",
  "category": "Token",
  "source": "art/blender/blockout/build_blockout.py",
  "triangles": 892,
  "lods": [446],
  "textures": 0,
  "status": "Draft",
  "screenshots": [],
  "generatedWith": "Blender 5.2, ..."
}
```

Estados: `Draft` → `InGame` (importado y colocado) → `Approved` (revisado en el juego).

`Manifest.validate` rechaza:

- un asset por encima del presupuesto de su categoría;
- un asset sin la versión de menor detalle que le toca;
- una versión de menor detalle que no reduce triángulos;
- `Approved` sin `approvedBy`;
- `Approved` sin capturas en el juego (una lista de textos vacíos no cuenta);
- categorías y estados desconocidos, e ids repetidos.

Las capturas se toman en el juego, con la iluminación y la cámara reales. Una imagen de Blender no
es una aprobación.

## 9. Lo que queda por comprobar

Esto es lo que este documento **no** puede afirmar todavía:

1. ~~Importar el FBX en Studio y medir el tamaño resultante contra una pieza de referencia.~~
   **Hecho:** `facade_wall`, `facade_trim` y `facade_glass` se subieron por Open Cloud y están
   colocados como `FacadeModel` en el banco de pruebas (`facade-reference`, `InGame` en el manifiesto).
2. Un asset con mapas PBR **por `SurfaceAppearance`** en una malla del juego. Lo que sí está probado
   son los `MaterialVariant` sobre piezas (§7.b), que es otro camino: los tres modelos de fachada
   siguen sin su `SurfaceAppearance` aplicado.
3. Intercambio de `_LOD1` en partida y su coste.
4. FPS y memoria en el móvil de referencia, con 8 fichas en escena (Puerta B).

## 10. Repositorio

Los binarios pesados van por **Git LFS** desde el 2026-11-04. `.gitattributes` manda a LFS los
`.blend`, los `.fbx`, y las texturas y capturas de `art/`. Los archivos que ya estaban en el historial
siguen siendo objetos normales: LFS solo se aplica de aquí en adelante. Convertir lo viejo exige
`git lfs migrate import`, que reescribe todos los commits y obliga a force-push, así que no se hace
sin decidirlo.

Quedan dos decisiones de este apartado, ninguna urgente mientras el blockout sea procedural:

- **Convertir el historial a LFS.** Hoy los binarios rondan los 22 MB, con tres `.fbx` de 2 a 3,3 MB.
  No es un problema todavía; lo será cuando haya una ciudad modelada.
- **Si el `.rbxl` entra al repositorio.** La luz y los materiales ya no dependen de él
  (`art/lookdev/look.luau` los reproduce) y la calle se vuelve a levantar con
  `art/lookdev/build_lookdev.lua`. Mientras esos dos scripts reconstruyan el place, guardar un `.rbxl`
  de decenas de megas no aporta.

Mientras el blockout sea procedural, lo que manda es el guion: los binarios se pueden borrar y
regenerar con un comando.
