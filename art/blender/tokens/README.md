# Fichas (tokens)

Cómo se modela, se exporta y se comprueba una ficha de Flip the Table. La plantilla es
[`taxi.py`](taxi.py) y su salida [`taxi/`](taxi/). Este documento recoge lo que se averiguó al
validar el taxi en Studio el 2026-11-05, porque la tubería no lo dejaba escrito en ningún sitio.

## Medidas y presupuesto

- 1 unidad de Blender = 1 stud. El avatar mide 6.
- Presupuesto: **3 000 triángulos** por ficha; LOD1 de una sola malla y un material, **≤ 50 %**.
- Cada FBX: una malla, un material y un color.
- Ruedas y tapacubos: mallas aparte, origen en su eje, **≤ 120 triángulos** por rueda con su tapacubos.
- La placa del asiento va en su propia malla, casi blanca (`EDEAE3`), porque el juego la tiñe con el
  color del jugador. Nada encima de ella.

## Ejes, morro y asiento

Blender: morro en **-Y**, arriba **+Z**. Roblox: morro en **-Z**, arriba **+Y**. La conversión
empírica (medida cargando el taxi con `InsertService:LoadAsset`) es:

| Blender | Roblox | Qué es |
| --- | --- | --- |
| `x` | `-x` | ancho (**el eje X sale reflejado**) |
| `y` | `z` | largo; el morro -Y queda en -Z |
| `z` | `y` | alto |

El reflejo de X no se nota en el taxi (es simétrico), pero **sí cuenta en detalles asimétricos**
(escape de la moto, ventanilla del food truck): lo que se modela a -X aparece a +X en Roblox.

El taxi anterior (`art/blender/slice/build_slice_props.py`, `ArtAssets.taxi`) también se modeló con el
morro en -Y, así que los dos coinciden en -Z y el cambio de malla no gira la ficha.

El `seat` de `stats.json` está en coordenadas de Blender. En Roblox es `(x, z, y)`: el del taxi,
`[0, 0.8, 4.6]`, se lee `(0, 4.6, 0.8)`.

## Cómo llegan las mallas

Validado cargando las 15 mallas del taxi con `InsertService:LoadAsset` en Studio:

- **Carrocería y placa** llegan con el pivote en el centro de su caja y la posición relativa al
  origen de la ficha (el `(0,0,0)` del FBX). Roblox recentra la malla en su caja y deja la parte en
  el centro de esa caja dentro del espacio del modelo. Por eso `TokenRider` clona cada pieza con
  `mesh.CFrame = origen * source.CFrame` y queda alineada. Ejemplo: `taxi_body_taxi` mide
  `6.4 × 3.6 × 11.8` y llega en `(0, 2.7, 0.1)`.
- **Ruedas y tapacubos** llevan el origen en el eje y **la traslación del eje dentro del FBX**: el
  objeto se coloca en su eje antes de exportar. Llegan ya en su sitio y giran alrededor de X de
  Roblox (`giro: "X"`). Ejemplo: `taxi_wheel_fl` mide `0.8 × 2 × 2` y llega en `(±2.65, 1, -3.4)`.

**Trampa que costó encontrar:** si las ruedas se exportan antes de poner su `location` en el eje,
las cuatro llegan a `(0,0,0)` y la ficha aparece sin ruedas, con las cuatro apiladas en el centro.
En `taxi.py`, el bloque «Las ruedas y los tapacubos se exportan con su origen en el eje…» tiene que
estar **antes** del bucle de exportación.

## Cómo se comprueba en Studio

1. En modo Edit, `InsertService:LoadAsset(id)` de cada FBX en una carpeta temporal.
2. Colocar cada pieza en su sitio: la carrocería y la placa con su `Position` tal cual; las ruedas y
   tapacubos, en su eje de `stats.json` convertido a Roblox.
3. Poner una figura de 6 studs al lado y mirar la ficha de frente y de tres cuartos.
4. Borrar la carpeta temporal.

La figura de 6 es la referencia de escala; el taxi mide 5,1 de alto y por eso la figura lo supera.

## Lo que ya está comprobado del taxi

- 15 piezas, 2 580 triángulos, LOD1 336 (13 %). Medidas 6,4 × 12,4 × 5,1, `min_z = 0`.
- Las ruedas tocan el suelo (eje a 1,0 con radio 1,0) y quedan dentro de los arcos.
- El morro queda en -Z y el `seat` en el techo, libre, a 4,6 de alto.

## Las ocho fichas en el juego

- `ArtAssets.tokens` guarda, por ficha, sus mallas, su placa y su `seat` ya en coordenadas de Roblox
  (`x`, alto, fondo). `ArtAssets.taxi` sigue siendo la lista del taxi para no romper lo anterior.
- `src/shared/config/Tokens.luau` reparte una ficha por asiento (1 taxi, 2 limusina, … 8 autobús)
  mientras no exista la pantalla de elección: así las ocho se ven sin tocar el lobby.
- `TokenRider` viste la ficha de cada asiento, tiñe su placa con el color del jugador y deja el
  asiento gris como anclaje invisible del avatar.
- Studio, 2026-11-05: las 123 mallas de las ocho fichas cargan con `InsertService:LoadAsset`; taxi,
  limusina, autobús y moto se montaron completos, con las ruedas en su eje y la placa en su sitio.

