# Prompt maestro: casillas especiales

Pega lo que hay debajo de la línea en una sesión nueva de Claude Code abierta en `D:\monopoly`, **cuando haya terminado el orquestador de las fichas**: comparten Studio, manifiesto y `asset-ids.json`. Antes, repasa la tabla de la sección 3: el orquestador la toma como decisión tuya.

---

Eres el orquestador de las casillas especiales de Flip the Table, un juego de mesa para Roblox (Tarea 3 del plan 07). Deja modelados, subidos y registrados los 8 lugares y sus 8 iconos, sin pedir ayuda salvo en los casos de la sección 8.

Tú no modelas: cada pieza la hace un subagente nuevo con `model: "haiku"`, un subagente por pieza. Tú encargas, compruebas y decides. No aceptes un informe sin mirar sus renders y su `stats.json`.

## 1. Lee antes de empezar

1. `CLAUDE.md`, `docs/instrucciones-de-sesion.md` y la Tarea 3 de `docs/02-mvp/plan-07-ciudad-y-fichas.md`.
2. `art/vision-visual.md`, `art/guia-de-estilo.md`, `art/PIPELINE.md` y `art/edificios/blueprint.md`.
3. `art/blender/buildings/cobre/barberia-morro.py`: plantilla de script.
4. `art/blender/slice/build_arrest_props.py` (`build_jail`): la cárcel actual.
5. `art/generators/road_paint.py`: cómo se genera la pintura de las casillas.
6. Mira con Read `art/render/cobre/barberia-morro/barberia-morro-niveles.png` y `art/render/ingame/cobre-nivel0.jpg`.

Di en una frase qué vas a hacer y empieza.

## 2. Qué hay ya en el código

La rama `plan-07-fichas-codigo` ya trae `src/client/world/SquareView.luau`, que coloca `ArtAssets.squares[<tipo>]` en el solar de cada casilla de ese tipo, con el origen y el retranqueo de las propiedades. Por eso **no tocas `src/`**: el registro en el código se hace después, en otra sesión. Tu entrega son las mallas, los ids y el manifiesto. El brillo de la Zona Caliente también queda fuera: es código y se ajusta a ojo.

## 3. Las piezas

Un lugar por **tipo**: el mismo modelo se repite en cada casilla de ese tipo, así que debe verse bien repetido. Son decorado sin niveles: un solo cuerpo, sin añadidos.

| Tipo (`SquareKind`) | id | prefijo | Altura máx. | Concepto: se reconoce sin leer el rótulo |
| --- | --- | --- | --- | --- |
| `Start` | salida | start | 22 | Cochera de salida: nave abierta con portalón y un pórtico de señalización sobre la entrada. Sin flechas ni textos de otro juego de mesa. |
| `Spin` | giro | spin | 14 | Kiosco de avisos: quiosco redondo con carteles «AVISO» en sus paredes, como la carta de giro de la guía. |
| `Market` | mercado-negro | market | 14 | Puesto de callejón: lona, cajas apiladas, persiana a medio bajar y un farol. Pícaro y apto para todo público. |
| `Duel` | duelo | duel | 16 | Plaza de duelo: dos podios enfrentados bajo un arco, con espacio libre entre ellos para dos avatares. |
| `Portal` | portal | portal | 18 | Boca de metro monumental: arco de piedra con escaleras que bajan y placa redonda. El interior es un plano oscuro. |
| `Billboard` | cartelera | billboard | 30 | Pantalla gigante de ciudad sobre una estructura de acero. La pantalla es una malla plana aparte (`billboard_screen`), para que la escena proyecte en ella. Sin aspecto de casino: sin luces de feria, monedas, cerezas ni ruleta. |
| `Tribunal` | tribunal | tribunal | 26 | Palacio de justicia con frontón, columnas y escalinata, junto a la comisaría. Ver la nota de abajo. |
| `Tax` | impuesto | tax | 16 | Aduana: caseta con barrera a rayas y ventanilla. |

**Nota del Tribunal.** La cárcel actual (`ArtAssets.jail`) ya está en ese solar y la escena de arresto entra por su puerta, así que no se mueve. Mide su caja antes de encargar el Tribunal y dile al subagente qué zona debe dejar libre. El Tribunal se apoya en ella y juntos deben leerse como un solo conjunto. Si no cabe en el solar de 36 × 22 sin tapar la puerta, para y pregunta.

**Iconos.** Un icono por tipo, pintado sobre el asfalto dentro del marco de la casilla. Señalética de la guía de estilo, silueta sólida de una tinta, sin texto. Lo genera un solo subagente con un script nuevo, `art/generators/road_icons.py`, a partir de `road_paint.py`: PNG en blanco sobre transparente con el mismo desgaste en `art/textures/casillas/iconos/<id>.png`, más una lámina `preview.png`. Se tiñen en el juego, como la pintura.

## 4. Encargo para cada subagente de lugar

Copia esto, rellena los corchetes y no lo resumas.

```text
Modela DESDE CERO el lugar «[tipo]» de Flip the Table, en D:\monopoly, por script de Blender en segundo plano.

Lee art/edificios/blueprint.md, art/guia-de-estilo.md y art/blender/buildings/cobre/barberia-morro.py. Mira con Read art/render/cobre/barberia-morro/barberia-morro-niveles.png. Usa la estructura técnica del script (helpers, exportación, stats y renders) y modela una forma propia, sin añadidos de nivel.

Concepto: [concepto]. Altura máxima: [altura]. Zona que debe quedar libre: [zona o «ninguna»].

Entrega:
- art/blender/squares/[id].py, ejecutable con: D:\blender\blender.exe --background --factory-startup --python art/blender/squares/[id].py
- art/blender/squares/[id]/: [prefijo]_<material>.fbx, [prefijo]_LOD1.fbx y stats.json con triángulos por pieza, total, LOD1 y medidas.
- art/render/squares/[id]/: [id]-frontal.png, [id]-aereo.png (cámara alta, como la del juego) y [id]-comparacion.png, junto a una figura de 6 studs.

No se negocia:
- Máximo 3 000 triángulos. LOD1 de una sola malla y un material, y como máximo la mitad. Cada FBX, una malla, un material y un color.
- Frente a -Y, origen en el centro de la base, z = 0 a ras de suelo. Huella hasta 32 × 18, con vuelos hasta y = -10. Puertas de al menos 2,4 × 6,5.
- Rótulo en letras 3D con el nombre de la casilla, legible desde la calle.
- Los tejados se ven desde la cámara del juego: necesitan detalle. Nada flota.
- Sin neón, sin marcas, sin nada de Monopoly ni de casino. Apto para todo público.

Mira tus PNG con Read, corrige y repite hasta 3 veces. No subas nada, no hagas commits, no abras Studio y no toques src/, tests/, docs/, art/manifest.json, art/asset-ids.json ni otras piezas.

Informe de menos de 20 líneas: rutas, medidas y triángulos reales, lista de piezas (clave, material, RGB) y dudas. Nunca inventes un resultado. Si algo falla 3 veces por lo mismo, para y cuéntalo.
```

Lanza los subagentes a la vez: usan Blender en segundo plano, en procesos independientes, y cada uno escribe solo en su carpeta. Empieza con el Tribunal solo si necesitas medir la cárcel primero. Studio lo usas solo tú, de una pieza en una.

## 5. Cómo revisas

Lee `stats.json` y comprueba medidas, triángulos y LOD1. Mira los PNG:

- [ ] ¿Qué lugar es, sin leer el rótulo? Si dudas, falla.
- [ ] ¿Se distingue de los otros 7 y de las propiedades vecinas?
- [ ] ¿La escala es creíble junto a la figura de 6?
- [ ] ¿Se ve bien desde arriba?
- [ ] ¿Hay piezas flotando, caras raras o bandas negras?
- [ ] ¿Recuerda a una marca, a un casino o a Monopoly?

Devuelve problemas concretos, con medida y sitio, nunca un «mejóralo». Hasta 3 vueltas con el mismo subagente; si sigue fallando, apúntalo como pendiente del responsable y sigue.

## 6. Subir y registrar (lo haces tú)

1. Sube cada FBX aceptado, sin el LOD. Lanza las subidas en segundo plano y exige moderación `Approved`. La clave ya está en el entorno; nunca la muestres:
   `pwsh -NoProfile -File art/generators/upload_model.ps1 -Path <fbx> -Name square-<clave>`
2. Guarda los ids en `art/blender/squares/<id>/subida.json`.
3. Sube los iconos como pide `art/PIPELINE.md` para las imágenes, igual que se subió la pintura (`ArtAssets.roadPaint`), y guarda sus ids en `art/textures/casillas/iconos/subida.json`.
4. Mira cada lugar en Studio en modo Edit: cárgalo con `InsertService:LoadAsset` en una carpeta temporal junto a una figura de 6, captura en `art/render/ingame/square-<id>.jpg` y borra la carpeta. Si no consigues capturarlo, dilo: no inventes el resultado.
5. Añade cada id a `art/asset-ids.json` y una entrada por lugar en `art/manifest.json`: id `square-<id>`, categoría `Building`, estado `Draft`, con `triangles`, `lods`, `source`, `assetId` y `assetIds`. Nunca pongas `InGame` ni `Approved`: aún no están en el juego.
6. Ejecuta `lune run tools/manifest` y haz un commit local por pieza: `feat: casilla <id>`. Sin push.

## 7. Fuera de este encargo

No toques `src/`. Se integra después: registro en `ArtAssets.squares`, iconos en `CityBuilder`, brillo de la Zona Caliente, capturas desde el plano del turno y desde la maqueta, y la aprobación del responsable.

## 8. Para y pregunta si

- Hay que hacer push, merge o publicar en Roblox: nunca lo hagas por tu cuenta.
- Falta la clave o Blender no arranca.
- El Tribunal no cabe junto a la cárcel.
- Tres piezas seguidas se rechazan por lo mismo: el problema está en el encargo.
- Moderación rechaza una subida.

En cualquier otro caso, sigue. Una pieza atascada no para a las demás.

## 9. Nunca

Aprobar un asset, inventar resultados, usar assets de la Toolbox o debilitar pruebas.

## 10. Al terminar

Presenta al responsable una tabla por pieza, con estado, triángulos, medidas, capturas y lo pendiente. Di qué quedó hecho, qué se comprobó y qué falta.
