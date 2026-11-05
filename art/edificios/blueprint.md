# Blueprint de propiedades

Cómo modelar cualquier propiedad para que entre bien en el juego a la primera. Está escrito para que lo siga un agente sin más contexto.

**La regla que evita casi todos los errores: la referencia es lo que ya está en el juego, no lo que dice un documento.** Si una ficha de zona contradice este documento, manda este. Las fichas sirven para el concepto (qué negocio es y qué lo hace reconocible). Sus medidas no se usan.

## 1. Referencias

| Propiedad | Script | Estado |
| --- | --- | --- |
| Bodega La Reserva | `art/blender/slice/build_slice_props.py` | En juego: referencia de escala |
| Cine Lux | `art/blender/slice/build_cine_lux.py` | En juego: referencia de escala |
| Barbería Morro | `art/blender/buildings/cobre/barberia-morro.py` | **Aprobada.** Plantilla de script y ejemplo de escala |
| Callejón del Hojalatero | `art/blender/buildings/cobre/callejon-del-hojalatero.py` | **Aprobado.** Ejemplo de silueta distinta. No copies sus vuelos: llega a `y = -12,7` y a 18,2 de ancho |

Copia de Barbería Morro la estructura del script. Sus claves con sufijo de color (`_rojo`) y su `stats.json` son el formato a seguir.

## 2. Medidas

Todo en studs: 1 unidad de Blender = 1 stud, con `unit_settings.system = "NONE"`.

| Qué | Valor | De dónde sale |
| --- | --- | --- |
| Solar | 36 × 22 | `CityLayout`, `build_cine_lux.py` |
| Huella | hasta 32 × 18, y debe llenar el solar como sus vecinos | Bodega y Cine Lux |
| Retranqueo | el origen del edificio va 2 hacia el fondo; lo aplica el juego | `ArtAssets.FRONT_OFFSET` |
| Vuelos delanteros (toldo, marquesina, poste) | hasta `y = -10` | Franja del marcador del nivel 5 |
| Avatar | 6 (4,9 de cuerpo y 5,6 con cabeza y accesorios) | `art/escala.md` |
| Planta | 7 | Cine Lux |
| Puerta normal | al menos 2,4 × 6,5 | Cine Lux |
| Portalón | unos 9 × 7,4 | Bodega |
| Marquesina o toldo | desde unos 6,1 hasta 9 de alto | Cine Lux 7,1; Bodega 8,9 |
| Rótulo | por encima de puerta y toldo; desde unos 8,3 de alto | Cine Lux 8,3 |
| Cuerpo | Bodega 13; Cine Lux 24 | Scripts |

**Altura por zona: pendiente de decidir.** Una zona barata debe quedar cerca de la Bodega: Cobre usa de 14 a 17. Las bandas de `README.md` (Centro 28–88, Zona Alta hasta 92) no están medidas. Por encima de unos 34 en total al nivel 5, consulta al responsable antes de modelar, porque no hay ningún edificio de referencia a esa altura.

Comprueba la escala siempre contra una figura de 6, nunca contra una tabla.

## 3. Sistema de coordenadas y origen

- El frente da a **-Y**, y la fachada queda en `y = -fondo / 2`.
- El origen está en el centro de la base, con `z = 0` a ras de suelo.
- Nada por debajo de `z = 0`.
- Exporta con las mismas opciones que `export` de `build_cine_lux.py`: `apply_scale_options="FBX_SCALE_UNITS"`, `axis_forward="Z"`, `axis_up="Y"`, `bake_anim=False`, `add_leaf_bones=False`.
- Todas las piezas comparten ese origen, sin desplazarlas por pieza.

## 4. Mallas y piezas

**`ArtLoader` solo toma la primera malla de cada asset.** Por eso cada FBX contiene exactamente **una malla, con un material y un color**. Un FBX por nivel con varias mallas se carga roto, sin avisar de lo que falta.

| Pieza | Clave |
| --- | --- |
| Cuerpo | `<prefijo>_body_<material>` |
| Añadido | `<prefijo>_addon<N>_<material>` |
| Mismo material con otro color | añade `_<color>` |
| LOD | `<prefijo>_LOD1` |

Las claves son únicas en todo el juego. El prefijo es corto y sin acentos (`morro`, `hojalatero`).

Agrupa con `by_material` de `build_slice_props.py`. Importa los helpers de `build_cine_lux.py` (`box`, `flat`, `textured`, `letters`, `perforate`, `count`, `lod_of`, `render`, `camera`); no los copies.

### Materiales

El FBX no aporta color ni textura: **el color y el material se ponen en `ArtAssets`**. Las texturas de Blender son solo para el render.

Materiales permitidos: `Brick`, `Limestone`, `Slate`, `Glass`, `Metal`, `Fabric`, `Wood`, `SmoothPlastic`, `Grass`.

| Uso | RGB | Material |
| --- | --- | --- |
| Ladrillo | 176, 102, 74 | `Brick` |
| Caliza | 210, 201, 180 | `Limestone` |
| Pizarra | 74, 78, 84 | `Slate` |
| Cristal, oscuro y opaco | 46, 74, 99 | `Glass`, reflectancia 0,25 |
| Rojo de lona | 196, 56, 43 | `Fabric` |
| Madera | 107, 74, 46 | `Wood` |
| Acero | 168, 174, 180 | `Metal` |
| Oro | 201, 162, 39 | `Metal` |
| Color de zona (el cobre, 201, 123, 58) | el de la zona | `Metal`, solo como acento |

Sin neón, sin negro ni blanco puros, y nada de cristal transparente: tras los cristales no hay interior.

### Presupuesto

- Objetivo: **hasta 3 000 triángulos** con el nivel 5 completo (Bodega 600, Cine Lux 3 042). El tope que comprueba `tools/manifest` es 10 000.
- LOD1: hasta el 50 % del total, y debe ser menor que el modelo.

## 5. Diseño

**El edificio es su negocio y se reconoce desde lejos sin leer el rótulo.**

Elige 2 o 3 rasgos propios del negocio a escala de edificio, por ejemplo poste de barbero y escaparates; portalón, chapa y chimenea. Luego comprueba:

- [ ] Sin hileras de ventanitas de pisos ni portales de viviendas.
- [ ] La silueta es distinta de la de sus dos vecinas. Si todas son cajas de ladrillo, cambia la cubierta o el volumen.
- [ ] El nombre va en una placa con letras 3D (`letters`), como «CINE LUX». La casilla del suelo la pinta el juego.
- [ ] Sin marcas ajenas, casino ni elementos de Monopoly.

**No modeles:**

- Marcadores de nivel: `CityLayout.levelMarkers` pone un mojón solo en el nivel 5.
- `SignAnchor` ni `PlaqueAnchor`: **no existen en el código del juego.**
- Texto con `SurfaceGui` ni placa de dueño.
- Calle, acera, árboles o farolas: solo pueden estar en la escena de render.

## 6. Niveles

Cuerpo más 5 añadidos que **se suman**. `ArtAssets.piecesFor` enciende todos hasta el nivel actual, así que un añadido nunca sustituye ni tapa mal al anterior.

| Nivel | Qué añade |
| --- | --- |
| 1 | Toldo o marquesina |
| 2 | Mejora de fachada |
| 3 | Algo que cambie la silueta, del propio negocio |
| 4 | Ampliación visible |
| 5 | Remate o torre con el rasgo del negocio en grande |

Cada nivel se distingue desde arriba y de lejos. Nada flota si faltan los niveles superiores.

## 7. Flujo

Con paradas. No pases a la siguiente fase sin completar la anterior.

### A. Modelar, sin tocar nada del juego

1. Lee las referencias y mira `art/render/cine-lux-niveles.png`.
2. Escribe el script en `art/blender/buildings/<zona>/<id>.py`.
3. Ejecútalo sin interfaz: `D:\blender\blender.exe --background --factory-startup --python <script>`. Solo un agente usa Blender a la vez.
4. Genera `stats.json` con triángulos por pieza y nivel, límites por nivel, y material y RGB de cada pieza.

### B. Revisar antes de gastar una subida

Genera dos imágenes en `art/render/<zona>/<id>/`: los 6 niveles, y el nivel 0 junto a una figura de 6 y bloques de 32 × 18 × 13 y 32 × 18 × 24. Míralas de verdad y comprueba:

- [ ] La puerta supera claramente a la figura.
- [ ] Se lee el negocio.
- [ ] No hay bandas negras ni caras raras. Si salen, investígalo; no las des por buenas.
- [ ] Límites dentro de la huella, y `y` mínima de -10 o mayor.
- [ ] Cada FBX tiene una sola malla.

Ejecuta el comprobador, que abre cada FBX y mide de verdad; debe acabar en `CHECK OK`:

```powershell
D:\blender\blender.exe --background --factory-startup --python art/generators/check_property.py -- <carpeta> <altura_max>
```

Comprueba que la exportación está limpia: un aviso de Blender como «No mesh data to join» se investiga, no se ignora.

**Enseña las imágenes al responsable antes de subir.**

### C. Subir e integrar

1. Sube cada FBX una vez:

   ```powershell
   pwsh -File art/generators/upload_model.ps1 -Path <fbx> -Name <clave>
   ```

   Necesita `ROBLOX_OPENCLOUD_KEY` y `ROBLOX_CREATOR_USER_ID`. Anota cada id al recibirlo. No subas versiones descartadas.
2. Añade la propiedad en `ArtAssets.properties`, con el nombre **exacto** de `Strings`: `base` con las piezas del cuerpo y `addons` con cinco listas.
3. Regístrala en `art/asset-ids.json` y en `art/manifest.json` con una sola entrada, categoría `Building`, `triangles`, `lods`, `source`, `assetId`, `assetIds` y estado `Draft`.
4. Si una prueba usa esa propiedad como ejemplo de «sin modelo» (como `tests/config/ArtAssets.spec.luau`), cámbiala a otra que siga sin modelo. No la debilites.
5. Ejecuta `lune run tests/run ArtAssets` y `lune run tests/run manifest`.

### D. Validar en Studio

Un render no aprueba nada.

- [ ] La propiedad aparece en su casilla, sin bloque gris y sin avisos de `ArtLoader`.
- [ ] Al lado de un avatar y un taxi, la escala es correcta.
- [ ] Se ve bien junto a sus vecinas de la calle.
- [ ] Los niveles 0 a 5 se encienden sin huecos, con los marcadores a la vista.
- [ ] Desde el plano `turn` de la casilla y de las dos vecinas, el nivel 5 no tapa la cámara.
- [ ] Capturas en el juego: calle, plano de turno y vista general.

Pasa el estado a `InGame` y presenta las capturas. **Solo el responsable aprueba: un agente nunca pone `Approved`.**

## 8. Errores que ya hemos pagado

| Error | Consecuencia | Cómo se evita |
| --- | --- | --- |
| Puerta de 3 con avatar de 6 | Edificio de juguete | Medir contra una figura de 6 |
| Tomar medidas de una ficha sin verificar (28 de masa en la zona más barata) | Más alto que el Cine Lux | Referencias en juego |
| Bloque de pisos con un local abajo | No se lee el negocio | Sección 5 |
| Las dos propiedades vecinas con la misma caja | No se distinguen | Silueta propia |
| Un FBX con varias mallas | `ArtLoader` carga solo una | Una malla por FBX |
| Modelar anclajes que nadie usa | Trabajo perdido | Mirar el código, no el documento |
| Modificar medidas en un documento después de exportar | Modelos obsoletos sin que nadie lo note | Comparar fechas; `stats.json` debe salir del script actual |
| Dar por terminado por el render | Sin saber cómo se ve en el juego | Fase D |
| Subir antes de revisar | Decenas de assets descartados | Fase B |

## 9. Encargo para otro agente

Copia esto y rellena los corchetes:

```text
Modela desde cero la propiedad «[nombre exacto de Strings]» de la zona [zona] en D:\monopoly.
Sigue art/edificios/blueprint.md al pie de la letra, y solo las fases A y B. Prefijo de claves: [prefijo].
Concepto: [qué negocio es y sus 2 o 3 rasgos]. Vecinas de calle: [nombres], de las que debe distinguirse.
Altura del cuerpo: [valor decidido por el responsable].
No toques src/, tests/, docs/, manifest ni asset-ids. No subas nada, no abras Studio y no hagas commit.
Informe: rutas, medidas, triángulos, lista de piezas (clave, material, RGB), avisos de Blender y dudas.
No inventes resultados: si algo falla 3 veces por lo mismo, para y cuéntalo.
```

La fase C y la D las hace quien orquesta, cuando el responsable haya visto los renders.
