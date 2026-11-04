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
- **Identidad visual elegida**: dirección A, *Señalética*. Tres direcciones comparadas en
  `art/identidad/tres-direcciones.md` (2026-11-02) y guía completa en `art/guia-de-estilo.md`.
- **Sistema de componentes**: escritura de propiedad A2, carta de giro con sellos por calidad y dorso
  único. Láminas en `art/identidad/direccion-a-componentes.png` y `direccion-a-giro.png`.
- **Tres conceptos de barrio aprobados** (2026-11-02): cortes a escala real de Centro, Puerto y Zona
  Alta en `art/identidad/concepto-*.png`.
- **Look versionado** (2026-11-04): `art/lookdev/look.luau` es la fuente de verdad de la luz, la
  atmósfera, el post-proceso, el cielo y los ocho materiales, y se aplica con un comando en Studio.
  `art/lookdev/look.json` es la foto del estado. Antes esto solo existía dentro del `.rbxl`, que no se
  versiona: la luz estaba a un archivo perdido de desaparecer.

## Resuelto después del 2026-11-02

- **La escalera de cinco pasos ya está alineada** en los tres sitios que no coincidían: la ficha dice
  «tres casas, hotel y rascacielos» (cinco pasos), `Economy.maxBuildingLevel = 5` con
  `buildingRentMultiplier = { 2, 3, 5, 8, 12 }`, y `Building` la aplica al comprobar el nivel máximo.
  El motor ya no está en tres niveles con `{ 3, 6, 10 }`.
- **El look salió del `.rbxl`**: ver `art/lookdev/look.luau`.
- **`asset-ids.json` completado** con los ids de `BrickDia`, `AsphaltDia` y los del ladrillo antiguo,
  que existían en el place sin documentar.

## Decidido y no se reabre sin motivo

- Escala: ficha 9, calzada 34, acera 7, frente de solar 18, planta 7. Ver `art/escala.md`.
- Luz: día, `LightingStyle = Realistic`, `ClockTime` 10,6, `Ambient` 58/62/74. Ver `art/luz.md` y
  `art/lookdev/look.luau`.
- Manhattan de día con la Zona Alta de cristal y oro. **Sin neón nocturno.**
- **Sin NPCs**: la ciudad se lee como maqueta de lujo, que es la fantasía del juego.
- Identidad **A · Señalética** y su paleta, tipografía y componentes: `art/guia-de-estilo.md`.
- La ficha manda: `docs/00-ficha/ficha-propuesta.md`.

## Lo que falta

1. Verificar los albedos de `art/guia-de-estilo.md` §2.2 en el juego, con la luz real, antes de
   modelar fachadas. Lo que hay aplicado hoy son texturas CC0, no los albedos de la guía.
2. Tres fachadas más, una por receta, para cerrar una hilera entera con mallas reales.
3. Puerto y Zona Alta: existen en concepto, no en el juego.
4. Rendimiento en móvil: **aplazado por decisión del responsable**. No hay números y no se deben
   inventar.
5. La porción vertical de la Puerta B: `src/client/world/BuildingView` no existe, la escalera visual
   de cinco pasos por solar tampoco, y la escena de arresto está a cero.

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
4. art/guia-de-estilo.md es la fuente de la identidad: paleta, tipografía, componentes y barrios.
5. Si el place se perdió o hay que montarlo en otro sitio: `art/lookdev/build_lookdev.lua` levanta la
   calle y `art/lookdev/look.luau` aplica la luz y los materiales. Con esos dos se reconstruye el banco
   de pruebas; el `.rbxl` no se versiona.
6. El siguiente paso concreto está en «Lo que falta», punto 1.
