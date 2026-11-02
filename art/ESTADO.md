# Estado del arte

Dónde está el arte de Metrópolis y por dónde seguir. Se actualiza al cerrar cada avance.

## Lo que ya existe y funciona

- **Banco de pruebas en Studio**: calle de 140 studs con dos hileras continuas de cinco edificios
  cada una, mobiliario, skyline y la ficha con su avatar. Scripts en `art/lookdev/`:
  `build_lookdev.lua` → `build_street.lua` → `build_facade.lua` / `place_facade.lua`.
- **Cuatro recetas de fachada** en blockout: piedra, balcones, toldos y ladrillo.
- **Fachada real en Blender** (`art/blender/facade/build_facade.py`): 2 074 triángulos, LOD de 790,
  huecos perforados con booleana, cornisa de tres cuerpos, sillería y escaparate.
- **Tubería de assets validada de punta a punta**: Blender → PBR → FBX → Open Cloud → Studio →
  manifiesto. `art/generators/upload_model.ps1` y `art/PIPELINE.md`.
- **Assets propios**: skybox en `art/skybox/`, cuatro sets CC0 en `art/textures/cc0/`, todos los
  ids en `art/asset-ids.json`.
- **Manifiesto con presupuestos** (`art/manifest.json` + `tools/manifest.luau`), comprobado por
  `lune run tools/check`.

## Decidido y no se reabre sin motivo

- Escala: ficha 9, calzada 34, acera 7, frente de solar 18, planta 7. Ver `art/escala.md`.
- Luz: día, `LightingStyle = Realistic`, `ClockTime` 9,4, `Ambient` 44/48/60. Ver `art/luz.md`.
- Manhattan de día con la Zona Alta de cristal y oro. **Sin neón nocturno.**
- **Sin NPCs**: la ciudad se lee como maqueta de lujo, que es la fantasía del juego.
- La ficha manda: `docs/00-ficha/ficha-propuesta.md`.

## Lo que falta

1. **Tres direcciones visuales** para que el responsable elija (subfase 06, Tarea 1, Paso 1). Es el
   siguiente paso y no está hecho.
2. La guía de estilo (`art/guia-de-estilo.md`), con paleta, tipografía, logo e intención de barrio.
3. Tres fachadas más, una por receta, para cerrar una hilera entera con mallas reales.
4. Puerto y Zona Alta: hoy solo existe el blockout de Centro.
5. Rendimiento en móvil: **aplazado por decisión del responsable**. No hay números y no se deben
   inventar.

## Errores ya pagados, para no repetirlos

- `Color3.fromRGB(1,1,1)` con `MaterialVariant` deja la pieza **negra**: el `ColorMap` multiplica y
  hay que usar `Color3.new(1,1,1)`.
- El skyline a más de 260 studs con tiras finas es **invisible**; y con barras gruesas parece un
  fluorescente. La forma correcta son columnas de tramos con hueco.
- `Lighting.Technology` no existe en luz unificada: el interruptor de las sombras es
  **`LightingStyle = Realistic`**. Sin eso, ninguna captura sirve para juzgar la luz.
- Open Cloud rechaza `application/octet-stream` para modelos: hay que mandar `model/fbx`.
- Las piezas insertadas desde Open Cloud llegan **desalineadas**: `PivotTo(CFrame.new())` en cada
  una antes de agrupar.
- La cámara de `screen_capture` va en sus propios parámetros, no en `Workspace.CurrentCamera`.

## Cómo retomar

1. `PRODUCT.md`, este archivo y `docs/00-ficha/ficha-propuesta.md`.
2. `art/luz.md` y `art/escala.md` para no repetir decisiones ya tomadas.
3. `art/PIPELINE.md` si hay que tocar assets.
4. El siguiente paso concreto está en «Lo que falta», punto 1.
