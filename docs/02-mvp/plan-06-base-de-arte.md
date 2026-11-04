# Subfase 06: Base de arte. Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (recommended) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fijar el nivel visual del juego con una porción vertical aprobada, que funcione fluida en PC, antes de producir todos los assets. El móvil queda aplazado hasta tener el producto terminado en PC (decisión del responsable, 2026-11-04).

**Architecture:** Fuentes en `art/` y un manifiesto que registra cada asset con su estado. Un script comprueba los presupuestos técnicos; la calidad la aprueba una persona dentro del juego.

**Tech Stack:** Blender con su MCP, generación con IA, FBX, Roblox Studio con su MCP, Lune.

**Spec:** "Estándar de calidad de assets" en la [ficha](../00-ficha/ficha-propuesta.md).

**Requisito previo:** el plan 05 terminado, salvo la Puerta A (Tarea 6), aplazada hasta la alpha, y salvo lo que exige publicar (teletransporte, MemoryStore, lobby y vuelta al asiento), que sigue sin probar.

## Estado (2026-11-04): plan abierto

**La Tarea 3 y la Puerta B siguen abiertas.** La sesión del 2026-11-04 cambió la dirección visual, así que esta tarea hay que leerla con [la visión visual](../../art/vision-visual.md) al lado.

**Hecho:**
- Tareas 1 y 2.
- Menús y HUD del plan 05 (ver la [auditoría](../../auditoria/auditoria-2026-11-04-segunda-pasada.md)).
- Ciudad gris como calle de asfalto con casillas pintadas, edificio fijo por propiedad, marcadores y añadidos (R-P50).
- Cámara compartida de turno y minimapa, sin primera persona (R-P51).
- Primera propiedad modelada, el Cine Lux, y sus marcadores. Están en `Draft`: no se han subido ni visto en el juego.

**Siguiente, en este orden:**
1. **Probar la cámara en una partida real:** se ha visto un plano en un montaje de prueba, no moviéndose en partida.
2. **Terminar la vista general:** revisarla con la calle nueva, dejar que se gire a mano y añadir el dueño y el nivel sobre cada propiedad.
3. **Subir el Cine Lux y sus marcadores por Open Cloud** y verlos en el juego. Hace falta la clave de API del responsable, que pone en su entorno. Con eso se comprueba también la paleta de `art/guia-de-estilo.md` §10.
4. **Revisar el arte para la cámara aérea:** tejados con detalle y altura de la ficha.
5. **Completar la porción:** 2 o 3 propiedades con ambientación propia, la ficha taxi con avatar, luz, sonido de ambiente y la escena de arresto.
6. **Medir en PC y presentar la Puerta B.** Solo el responsable la aprueba.

**Decisión pendiente del responsable:** qué hacer con `tests/tools/manifest.spec.luau` («nunca aprobado»), que fallará al aprobar un asset.

## Ejecución recomendada

**Modo:** en la sesión, con `superpowers:executing-plans`.

**Por qué:** aquí se define el gusto visual del juego en conversación con el responsable, y esa continuidad importa. Quien aprueba la calidad es el responsable, no un revisor de código, y las 3 tareas dependen muy de cerca unas de otras.

**Instrucciones para la sesión:**

- Sigue también las [instrucciones generales](../instrucciones-de-sesion.md).
- Requiere el plan 05 terminado (la Puerta A ya no es requisito), y Blender y Studio abiertos con sus MCP.
- Muestra avances pronto: comparte capturas o imágenes al primer resultado, no solo al final.
- Comprueba en el juego y desde la cámara real; una imagen de Blender no sirve como aprobación.
- Anota en el manifiesto con qué herramienta se generó cada asset.
- Consulta las condiciones de uso comercial de cada herramienta de IA antes de usarla.
- Termina con la Puerta B aprobada: esta porción se convierte en la referencia del plan 07.

## Global Constraints

- Cada asset se diseña y se pule individualmente en Blender o una herramienta equivalente.
- Los agentes y la IA pueden crear assets; cada uno necesita la aprobación final del responsable.
- No se publican modelos de la Toolbox, piezas básicas de Roblox ni marcadores temporales.
- Identidad propia: nada que imite el juego original ni estética de casino.
- Límite de Roblox: 20 000 triángulos por malla.

## Review Focus

1. Se marca como aprobado un asset sin revisión en el juego: el manifiesto lo rechaza. Prueba en Tarea 2.
2. Un asset supera su presupuesto de triángulos: la comprobación falla y lo nombra. Prueba en Tarea 2.
3. Un asset generado con IA recuerda a una marca existente: la revisión lo detecta. Criterio en Tarea 2.
4. Los materiales se ven bien con calidad gráfica alta pero se apagan con la mínima. Prueba en Tarea 3.
5. Un asset no tiene versión de menor detalle: la comprobación falla. Prueba en Tarea 2.

---

### Task 1: Guía de estilo

**Módulos:** `art/guia-de-estilo`.

**Archivos:**
- Crear: `art/guia-de-estilo.md`. Las referencias acabaron en `art/identidad/`; `art/referencias/` no se creó.

**Interfaces:**
- Produce: paleta, materiales, iluminación, proporciones, tipografía e intención de cada barrio. Todas las tareas de arte la consultan.

**Criterios de aceptación:**
- [x] La identidad visual (logo y títulos, fuentes, colores y jerarquía) se desarrolla siguiendo la skill `impeccable`.
- [x] Define la paleta de Metrópolis con luz de día, con sus valores de color: piedra caliza, ladrillo, cristal azul y oro.
- [x] Define el tratamiento del título del juego, las fuentes y sus usos, y comprueba que existan o se puedan usar en Roblox.
- [x] Define la biblioteca de materiales: asfalto seco, caliza, ladrillo, cristal, acero pulido, oro y agua.
- [x] Define el aspecto de Centro, Puerto, Zona Alta e Industrial, para que se distingan de un vistazo.
- [x] Incluye la escala de las fichas respecto a calles y edificios.
- [x] Aclara qué evitar: el logo, el personaje y el diseño de tablero del juego original, y símbolos de casino.
- [x] Incluye 3 imágenes conceptuales de la ciudad, aprobadas por el responsable.

- [x] **Paso 0:** Cargar la skill `impeccable` y seguirla en toda esta tarea.
- [x] **Paso 1:** Generar 3 direcciones visuales, con títulos, fuentes y colores, y presentarlas al responsable.
- [x] **Paso 2:** Escribir la guía con la dirección elegida.
- [x] **Paso 3:** Hacer commit: `docs: añadir guía de estilo`.

**Sigue abierto de esta tarea:** comprobar la paleta de materiales con una captura real, con la luz de `art/luz.md` (`art/guia-de-estilo.md`, §10). Necesita Studio y se hace al empezar la Tarea 3.

### Task 2: Tubería y manifiesto

**Módulos:** `art/manifest.json`, `tools/manifest`.

**Archivos:**
- Crear: `art/manifest.json`, `art/PIPELINE.md`, `tools/manifest.luau`, `tests/tools/manifest.spec.luau`

**Interfaces:**
- Produce: `Manifest.validate(manifest): { string }`, que devuelve los problemas.
- Produce: entrada `{ id, category, source, triangles, lods: { number }, textures, assetId?, status: "Draft" | "InGame" | "Approved", approvedBy?, screenshots: { string }, generatedWith? }`.

**Presupuestos iniciales:**

| Categoría | Triángulos, máximo | Versión de menor detalle |
| --- | --- | --- |
| Edificio de la ruta | 10 000 | Obligatoria |
| Ficha | 8 000 | Obligatoria |
| Personaje de escena | 5 000 | Obligatoria |
| Objeto repetido | 2 000 | Obligatoria |
| Fondo de ciudad | 3 000 | Opcional |

**Criterios de aceptación:**
- [x] `PIPELINE.md` documenta exportación FBX, escala, nombres, mapas PBR, `SurfaceAppearance`, subida y revisión.
- [x] Antes de escribirlo, se confirma en la documentación oficial cómo importar mallas y aplicar `SurfaceAppearance`.
- [x] Ningún asset puede estar `Approved` sin `approvedBy` y capturas en el juego.
- [x] Un asset fuera de presupuesto o sin versión de menor detalle falla.
- [x] Un id de asset que no esté en el manifiesto no se puede referenciar desde `src/`.
- [x] La revisión comprueba que un asset generado con IA no recuerde a marcas o personajes existentes.

- [x] **Paso 1: Escribir las pruebas**

```luau
it("rechaza aprobar sin capturas", function()
    local problems = Manifest.validate({ assets = { { id = "taxi", category = "Token", triangles = 7000, lods = { 2000 }, status = "Approved", approvedBy = "x", screenshots = {} } } })
    expect(#problems).toBe(1)
end)
it("rechaza superar el presupuesto", function()
    local problems = Manifest.validate({ assets = { { id = "taxi", category = "Token", triangles = 9000, lods = { 2000 }, status = "Draft", screenshots = {} } } })
    expect(#problems).toBe(1)
end)
```

- [x] **Paso 2:** Ejecutar `lune run tests/run manifest`. Esperado: FAIL.
- [x] **Paso 3:** Implementar `tools/manifest.luau` y añadirlo a `tools/check`.
- [x] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [x] **Paso 5:** Hacer commit: `feat: añadir tubería y manifiesto de assets`.

### Task 3: Porción vertical y Puerta B

**Módulos:** `client/world/BuildingView`, `art/blender/slice`.

**Archivos:**
- Crear: `art/blender/slice/*.blend`, `src/client/world/BuildingView.luau`
- Crear: `docs/02-mvp/resultados/puerta-b.md`

**Interfaces:**
- Produce: `BuildingView.setLevel(index: number, level: number)`, usado luego por las escenas.

**Contenido de la porción:**

- Sigue [la visión visual](../../art/vision-visual.md): calle de asfalto, casillas pintadas, aceras y ambientación.
- Una calle con una zona: 2 o 3 propiedades, cada una con su edificio real, sus marcadores de mejora y los añadidos de sus cinco niveles (decisión del responsable, 2026-11-04).
- La ficha taxi con un avatar montado.
- Luz de día, sombras duras, reflejos de cristal y sonido de ambiente.
- Vista desde el plano del turno, el plano cercano del recorrido y la maqueta.
- La escena completa del arresto, con policías y patrulla.

**Criterios de aceptación:**
- [ ] Cada asset de la porción cumple las 6 condiciones del estándar de la ficha.
- [ ] El responsable compara capturas y video en PC, y aprueba la referencia de calidad.
- [ ] 30 FPS o más en el PC del responsable, con 8 fichas en escena.
- [ ] Se ve aceptable con el nivel gráfico mínimo.
- [ ] La memoria del cliente queda registrada en `puerta-b.md` como presupuesto de la ciudad completa.

- [ ] **Paso 1:** Modelar y texturizar en Blender; registrar cada asset en el manifiesto como `Draft`.
- [ ] **Paso 2:** Importar a Studio, pasarlos a `InGame` y capturar con `screen_capture` desde cada cámara.
- [ ] **Paso 3:** Ejecutar `lune run tools/check`. Esperado: «OK Manifiesto». `tools/manifest` es un módulo y no comprueba nada si se ejecuta solo.
- [ ] **Paso 4:** Medir FPS y memoria en PC con 8 fichas, con ayuda del responsable, y registrar los datos.
- [ ] **Paso 5:** Presentar capturas y datos al responsable. Si no aprueba, iterar sobre sus comentarios.
- [ ] **Paso 6:** Marcar los assets como `Approved` y escribir `puerta-b.md`.
- [ ] **Paso 7:** Hacer commit: `feat: aprobar porción vertical`.
