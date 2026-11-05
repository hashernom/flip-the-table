# Prompt maestro: modelar todas las propiedades

Pega todo lo que hay debajo de la línea en una sesión nueva de Claude Code abierta en `D:\monopoly`. Antes, repasa la tabla de alturas de la sección 3: es una propuesta y el orquestador la toma como decisión tuya.

---

Eres el orquestador del modelado de las propiedades de Flip the Table, un juego de mesa para Roblox. Tu trabajo es dejar modeladas, subidas y vistas en el juego las 30 propiedades que faltan, una zona detrás de otra y sin pedir ayuda salvo en los casos de la sección 8.

**Tú no modelas.** Cada propiedad la modela un subagente nuevo con `model: "haiku"`. Tú le das el encargo, compruebas su resultado y decides. Nunca aceptes un informe sin comprobarlo: un intento anterior dio por buenos modelos con puertas de 3 studs frente a un avatar de 6 y hubo que tirarlos todos.

## 1. Lee esto antes de empezar

1. `CLAUDE.md` y `docs/instrucciones-de-sesion.md`.
2. `art/edificios/blueprint.md`, entero. Es la norma de este trabajo.
3. `art/edificios/aceptacion.md`.
4. `art/blender/buildings/cobre/barberia-morro.py`: la plantilla de script.
5. Mira con Read: `art/render/cobre/barberia-morro/barberia-morro-niveles.png`, `art/render/cobre/callejon-del-hojalatero/callejon-del-hojalatero-niveles.png`, `art/render/cine-lux-niveles.png`, y `art/render/ingame/cobre-nivel0.jpg` y `cobre-nivel5-mojon.jpg`. Ese es el nivel que se espera.

Después di en una frase qué vas a hacer y empieza.

## 2. Qué manda

1. **Lo que ya está en el juego** y `blueprint.md` mandan en medidas, técnica y flujo.
2. **Las fichas** de `art/edificios/zonas/` solo dan el concepto: qué negocio es, sus rasgos, su silueta y sus cinco añadidos. Si una ficha menciona plantas, alturas o medidas, ignóralo. Si pide «plantas altas», se resuelve en la altura de la tabla y con huecos propios del negocio, nunca con hileras de ventanitas.
3. **Referencias aprobadas:** Barbería Morro, Callejón del Hojalatero, Bodega La Reserva y Cine Lux. Excepción: el Hojalatero se pasa del límite delantero y lateral; no lo copies en eso.

## 3. Orden y alturas

Trabaja en este orden. La altura es la del **cuerpo**; el máximo es el del **nivel 5 completo**, que es el segundo argumento del comprobador.

| Orden | Zona | Carpeta | Propiedades | Cuerpo | Máx. nivel 5 |
| --- | --- | --- | --- | --- | --- |
| 1 | `02-cian` | `cian` | Pasaje Burbuja, Calle del Cable, Caldas | 14–18 | 34 |
| 2 | `03-magenta` | `magenta` | Centro Páez, Neo Mundo, Plaza del Neón | 15–20 | 34 |
| 3 | `04-naranja` | `naranja` | Mercado de la Séptima, llaneradas.com, Calle del Azafrán | 15–20 | 34 |
| 4 | `05-carmesi` | `carmesi` | Plaza del Jazz. **No toques Cine Lux ni Bodega** | 13–24 | 34 |
| 5 | `06-limon` | `limon` | Vereda La Mata, Villa Margarita, Panadería La Espiga | 16–22 | 34 |
| 6 | `07-esmeralda` | `esmeralda` | Muelle de los Pescadores, Astillero Neptuno, Acuario La Sirena | 13–20 | 34 |
| 7 | `08-violeta` | `violeta` | Versalles 1, Versalles 2 | 13–20 | 34 |
| 8 | `09-anil` | `anil` | Observatorio Cerro Azul, D.T, Torres de Aragón | 22–30 | 44 |
| 9 | `10-blanca` | `blanca` | Tajamar, Cacique, Monviso | 24–32 | 46 |
| 10 | `11-grafito` | `grafito` | Fundición Vulcano, Chatarrería El Imán, Estación de Metrolínea | 14–22 | 40 |
| 11 | `12-ocre` | `ocre` | Almacén El Ladrillo, Curtiembre Los Nogales, Fábrica de Ladrillos La Hormiga | 14–22 | 40 |

Dentro de esos márgenes, elige para cada propiedad una altura distinta de la de sus vecinas. La calle no debe parecer una fila de cajas iguales.

## 4. Ciclo de una zona

Empieza en la rama `plan-07-ciudad-y-fichas`, que parte de la rama donde quedó integrado el plan 06. Si la rama anterior no está integrada, para y pregunta.

Para cada zona:

1. **Modela de una en una.** Lanza un subagente por propiedad y espera a que acabe antes del siguiente: solo un agente usa Blender a la vez, y así cada uno puede ver a su vecino y distinguirse.
2. **Revisa cada propiedad** con la sección 6. Si falla, reenvía al mismo subagente con los problemas concretos, hasta 3 veces. Si sigue fallando, apúntala en el estado como `Pendiente del responsable` y sigue.
3. **Sube e integra** las propiedades aceptadas con la sección 7. Eso lo haces tú.
4. **Compruébalas en Studio** con la sección 7.
5. **Haz un commit local** con el mensaje `feat: propiedades de <zona>`, solo con los archivos de esa zona, sin push. Conserva sin añadir los `.blend`, que están ignorados.
6. **Actualiza** `art/edificios/estado-modelado.md`: una fila por propiedad con estado, altura, triángulos y capturas.
7. Pasa a la siguiente zona.

## 5. Encargo para cada subagente

Copia esto y rellena los corchetes. No lo resumas.

```text
Modela DESDE CERO la propiedad «[nombre exacto]» de Flip the Table, en D:\monopoly, por script de Blender sin interfaz.

Lee primero, en este orden: art/edificios/blueprint.md entero; la sección «## [nombre exacto]» de art/edificios/zonas/[archivo].md; y art/blender/buildings/cobre/barberia-morro.py. Mira con Read art/render/cobre/barberia-morro/barberia-morro-niveles.png y art/render/ingame/cobre-nivel0.jpg.

La ficha da solo el concepto, los rasgos y los cinco añadidos. Si trae medidas o número de plantas, no los uses. Manda el blueprint.

Parámetros:
- Script: art/blender/buildings/[carpeta]/[id].py, partiendo de la estructura de barberia-morro.py: mismas funciones de exportación, stats.json y renders, con helpers importados de art/blender/slice/build_cine_lux.py. Sustituye los builders y las constantes del edificio. Ajusta las rutas de salida.
- FBX y stats.json: art/blender/buildings/[carpeta]/[id]/.
- Renders: art/render/[carpeta]/[id]/[id]-niveles.png y [id]-comparacion.png.
- Prefijo de claves: [prefijo]_. Claves: [prefijo]_body_<material>, [prefijo]_addon<N>_<material>, sufijo _<color> si un material lleva dos colores, y [prefijo]_LOD1.
- Altura del cuerpo: [valor]. Altura máxima con el nivel 5: [valor].
- Vecinas de calle, de las que debe distinguirse por silueta: [nombres y una línea de cómo son].

Requisitos que no se negocian:
- Puerta de al menos 2,4 × 6,5, o portalón de unos 9 × 7,4: claramente más alta que una figura de 6.
- Rótulo con el nombre en letras 3D (`letters`), en placa, por encima de la puerta y del toldo, legible.
- Se reconoce el negocio sin leer el rótulo. Nada de hileras de ventanitas ni bloque de pisos con un local abajo.
- Cada FBX tiene una sola malla, con un material y un color.
- Hasta 3 000 triángulos en total. LOD1 por debajo del 50 %.
- Frente a -Y, origen en el centro de la base, z = 0 a ras de suelo. Nada delante de y = -10, ni a más de 18 del centro a lo ancho.
- Cuerpo más 5 añadidos que suman. Cada nivel se distingue de lejos. Nada flota.
- Sin neón, sin marcas, sin Monopoly, sin texto en la casilla ni anclajes.

Ejecuta el script con: D:\blender\blender.exe --background --factory-startup --python <script>
Después ejecuta: D:\blender\blender.exe --background --factory-startup --python art/generators/check_property.py -- art/blender/buildings/[carpeta]/[id] [altura máxima]
Debe acabar en CHECK OK. Copia su salida completa en tu informe.

Mira tus dos PNG con Read. Compara con la figura de 6. Corrige e itera hasta 3 veces. Si Blender da un aviso que no entiendes, investígalo: «No mesh data to join» no se ignora.

No hagas commits. No subas nada a Roblox. No abras Studio. No toques src/, tests/, docs/, art/manifest.json, art/asset-ids.json, las fichas ni otras propiedades.

Informe, en menos de 20 líneas: rutas, medidas por nivel, triángulos, lista de piezas (clave, material, RGB), salida de check_property y dudas. Nunca inventes un resultado: si algo falla 3 veces por lo mismo, para y cuéntalo.
```

## 6. Cómo revisas tú

**Comprobación medible.** Ejecuta tú mismo `check_property.py`, aunque el subagente diga que pasó. Sin `CHECK OK`, no se acepta.

**Comprobación visual.** Mira los dos PNG con Read, y responde a cada punto:

- [ ] ¿Qué negocio es, sin leer el rótulo? Si dudas, falla.
- [ ] ¿La puerta sobresale claramente de la figura de 6?
- [ ] ¿La escala se parece a la de las referencias aprobadas?
- [ ] ¿Se lee el rótulo?
- [ ] ¿Sus vecinas son distintas, en silueta y no solo en color?
- [ ] ¿Cada nivel cambia algo que se vea de lejos? ¿El 5 sigue siendo el mismo edificio?
- [ ] ¿Hay bandas negras, caras raras o piezas flotando?
- [ ] ¿Algo recuerda a una marca, a un casino o a Monopoly?

Devuelve problemas concretos, con la medida y el sitio, y nunca un «mejóralo».

## 7. Subir, integrar y ver en el juego

Solo con propiedades aceptadas. Sigue las fases C y D del blueprint.

1. **Subida**, una vez por FBX, sin el LOD:

   ```bash
   pwsh -NoProfile -File art/generators/upload_model.ps1 -Path <fbx> -Name <clave>
   ```

   Guarda cada `assetId` y comprueba que la moderación diga `Approved`. Si no, apúntalo y no integres esa propiedad.
2. **Registro:** añade `ArtAssets.properties["<nombre exacto de Strings>"]`, con `base` y cinco `addons`. El cristal lleva reflectancia 0,25. Añade cada id a `art/asset-ids.json` y una entrada al manifiesto, en categoría `Building`, con estado `InGame`, `triangles`, `lods`, `source`, `assetId` y `assetIds`. **Nunca pongas `Approved`.**
3. **Pruebas:** `lune run tests/run ArtAssets`, `lune run tests/run manifest`, `stylua` y `selene`. Si una prueba usa como «propiedad sin modelo» una que acabas de integrar, cámbiala por otra que siga sin modelo. No debilites pruebas.
4. **Studio.** Crea un archivo temporal `src/server/zz_vista_temporal.server.luau` con esto. **Nunca entra en un commit** y se borra al acabar la zona:

   ```lua
   --!nocheck
   -- TEMPORAL: lleva la partida a una casilla con un nivel, para mirarla en Studio.
   if not game:GetService("RunService"):IsStudio() then return end
   local Players = game:GetService("Players")
   local remotes = game:GetService("ReplicatedStorage"):WaitForChild("FlipTheTableRemotes")
   local MS = require("./match/MatchService")
   local MatchState = require("./match/MatchState")
   workspace:SetAttribute("Vista", "")
   workspace:GetAttributeChangedSignal("Vista"):Connect(function()
   	-- Formato "casilla,nivel"
   	local index, level = string.match(workspace:GetAttribute("Vista"), "(%d+),(%d+)")
   	local m = MS.current()
   	if not m or not index then return end
   	index, level = tonumber(index), tonumber(level)
   	if m.state.properties[index] then m.state.properties[index].level = level end
   	for _, sp in m.state.players do sp.position = index end
   	for _, sp in m.state.players do
   		local p = m.players[sp.id]
   		if p and p.Parent then
   			remotes.ResyncRequest:FireClient(p, MatchState.resync(m.matchState, m.state, sp.id, workspace:GetServerTimeNow()))
   		end
   	end
   end)
   ```

   Rojo lo sincroniza si `rojo serve` está en marcha. Inicia la prueba con computer-use, sin `open_application`. En la ventana principal: Test (139,25) → Start Test Session (178,41) → Server and Clients (390,91); espera 25 s; en el servidor: Test (417,72) → Add Clients (444,258); espera 28 s; en el cliente: Test (382,76) → Add Clients (411,263); espera 30 s. Para terminar: cliente, Test (382,76) → End Session (411,358). Los ids de Studio cambian en cada sesión: usa `list_roblox_studios`, `get_studio_state` y localiza el servidor con `execute_luau` en `datamodel_type: "Server"`. La tool `execute_luau` no puede disparar eventos de red ni hacer require del juego, por eso todo pasa por el atributo: `workspace:SetAttribute("Vista", "12,5")`.

   Para cada propiedad, mira el nivel 0 y el 5 con `zoom` en la región (245,170)–(1000,720) y `save_to_disk`. Copia las capturas a `art/render/ingame/<zona>-<id>-nivel<N>.jpg` y ponlas en `screenshots` del manifiesto. Compruébalo:

   - [ ] Sale el edificio real, sin bloque gris y sin avisos de `ArtLoader` en la consola.
   - [ ] A escala junto al taxi y su avatar.
   - [ ] La fachada da a la calle.
   - [ ] El nivel 5 no tapa la cámara.

   Si la cámara o el atributo no te dejan ver la casilla, no inventes el resultado: apúntalo en el estado y sigue. Si una superposición de NVIDIA bloquea los clics, pide al responsable que la cierre.

## 8. Cuándo parar y preguntar

- Antes de hacer push, merge o publicar en Roblox: nunca lo hagas por tu cuenta.
- Si falta la clave de `ROBLOX_OPENCLOUD_KEY` o Blender no se ejecuta.
- Si el blueprint y una referencia aprobada se contradicen.
- Si tres propiedades seguidas salen rechazadas por lo mismo: el problema está en el encargo, no en el subagente.
- Si una subida es rechazada por moderación.

En cualquier otro caso, sigue. Una propiedad atascada no para la zona, y una zona con algo pendiente no para la siguiente.

## 9. Lo que nunca haces

- Aprobar un asset o una puerta. Solo el responsable.
- Inventar resultados, capturas o medidas.
- Cambiar reglas del juego, `Strings`, nombres o las propiedades ya aprobadas.
- Implementar las mejoras sobre la isla: es otra tarea del plan 07, ya documentada en `art/edificios/niveles.md`.
- Usar assets de la Toolbox o elementos de marca de Monopoly.
- Dejar el archivo temporal en un commit.

## 10. Al terminar

1. Ejecuta `lune run tools/check` y arregla lo que falle por este trabajo.
2. Ejecuta una partida en Studio y mira la vista general: ¿la calle se ve variada, con barrios reconocibles?
3. Presenta al responsable `art/edificios/estado-modelado.md`, con las capturas y lo pendiente, para que apruebe zona por zona. Termina diciendo qué quedó hecho, qué se comprobó, qué falta y qué necesita de él.
