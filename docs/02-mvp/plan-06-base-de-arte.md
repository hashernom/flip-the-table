# Subfase 06: Base de arte. Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (recommended) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fijar el nivel visual del juego con una porción vertical aprobada, que funcione fluida en móvil, antes de producir todos los assets.

**Architecture:** Fuentes en `art/` y un manifiesto que registra cada asset con su estado. Un script comprueba los presupuestos técnicos; la calidad la aprueba una persona dentro del juego.

**Tech Stack:** Blender con su MCP, generación con IA, FBX, Roblox Studio con su MCP, Lune.

**Spec:** "Estándar de calidad de assets" en la [ficha](../00-ficha/ficha-propuesta.md).

**Requisito previo:** la Puerta A está aprobada.

## Ejecución recomendada

**Modo:** en la sesión, con `superpowers:executing-plans`.

**Por qué:** aquí se define el gusto visual del juego en conversación con el responsable, y esa continuidad importa. Quien aprueba la calidad es el responsable, no un revisor de código, y las 3 tareas dependen muy de cerca unas de otras.

**Instrucciones para la sesión:**

- Sigue también las [instrucciones generales](../instrucciones-de-sesion.md).
- Requiere la Puerta A aprobada, y Blender y Studio abiertos con sus MCP.
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
4. Los materiales se ven bien con calidad gráfica alta pero se apagan con la mínima en móvil. Prueba en Tarea 3.
5. Un asset no tiene versión de menor detalle: la comprobación falla. Prueba en Tarea 2.

---

### Task 1: Guía de estilo

**Módulos:** `art/guia-de-estilo`.

**Archivos:**
- Crear: `art/guia-de-estilo.md`, `art/referencias/`

**Interfaces:**
- Produce: paleta, materiales, iluminación, proporciones, tipografía e intención de cada barrio. Todas las tareas de arte la consultan.

**Criterios de aceptación:**
- [ ] La identidad visual (logo y títulos, fuentes, colores y jerarquía) se desarrolla siguiendo la skill `impeccable`.
- [ ] Define la paleta de Metrópolis con luz de día, con sus valores de color: piedra caliza, ladrillo, cristal azul y oro.
- [ ] Define el tratamiento del título del juego, las fuentes y sus usos, y comprueba que existan o se puedan usar en Roblox.
- [ ] Define la biblioteca de materiales: asfalto seco, caliza, ladrillo, cristal, acero pulido, oro y agua.
- [ ] Define el aspecto de Centro, Puerto y Zona Alta, para que se distingan de un vistazo.
- [ ] Incluye la escala de las fichas respecto a calles y edificios.
- [ ] Aclara qué evitar: el logo, el personaje y el diseño de tablero del juego original, y símbolos de casino.
- [ ] Incluye 3 imágenes conceptuales de la ciudad, aprobadas por el responsable.

- [ ] **Paso 0:** Cargar la skill `impeccable` y seguirla en toda esta tarea.
- [ ] **Paso 1:** Generar 3 direcciones visuales, con títulos, fuentes y colores, y presentarlas al responsable.
- [ ] **Paso 2:** Escribir la guía con la dirección elegida.
- [ ] **Paso 3:** Hacer commit: `docs: añadir guía de estilo`.

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
- [ ] `PIPELINE.md` documenta exportación FBX, escala, nombres, mapas PBR, `SurfaceAppearance`, subida y revisión.
- [ ] Antes de escribirlo, se confirma en la documentación oficial cómo importar mallas y aplicar `SurfaceAppearance`.
- [ ] Ningún asset puede estar `Approved` sin `approvedBy` y capturas en el juego.
- [ ] Un asset fuera de presupuesto o sin versión de menor detalle falla.
- [ ] Un id de asset que no esté en el manifiesto no se puede referenciar desde `src/`.
- [ ] La revisión comprueba que un asset generado con IA no recuerde a marcas o personajes existentes.

- [ ] **Paso 1: Escribir las pruebas**

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

- [ ] **Paso 2:** Ejecutar `lune run tests/run manifest`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar `tools/manifest.luau` y añadirlo a `tools/check`.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir tubería y manifiesto de assets`.

### Task 3: Porción vertical y Puerta B

**Módulos:** `client/world/BuildingView`, `art/blender/slice`.

**Archivos:**
- Crear: `art/blender/slice/*.blend`, `src/client/world/BuildingView.luau`
- Crear: `docs/02-mvp/resultados/puerta-b.md`

**Interfaces:**
- Produce: `BuildingView.setLevel(index: number, level: number)`, usado luego por las escenas.

**Contenido de la porción:**

- Una calle con una zona: 3 solares con casa, edificio y rascacielos.
- La ficha taxi con un avatar montado.
- Luz de día, sombras duras, reflejos de cristal y sonido de ambiente.
- Vista desde primera persona, seguimiento y maqueta.
- La escena completa del arresto, con policías y patrulla.

**Criterios de aceptación:**
- [ ] Cada asset de la porción cumple las 6 condiciones del estándar de la ficha.
- [ ] El responsable compara capturas y video en PC y móvil, y aprueba la referencia de calidad.
- [ ] 30 FPS o más en el móvil de referencia, con 8 fichas en escena.
- [ ] Se ve aceptable con el nivel gráfico mínimo.
- [ ] La memoria del cliente queda registrada en `puerta-b.md` como presupuesto de la ciudad completa.

- [ ] **Paso 1:** Modelar y texturizar en Blender; registrar cada asset en el manifiesto como `Draft`.
- [ ] **Paso 2:** Importar a Studio, pasarlos a `InGame` y capturar con `screen_capture` desde cada cámara.
- [ ] **Paso 3:** Ejecutar `lune run tools/manifest`. Esperado: sin problemas.
- [ ] **Paso 4:** Medir FPS y memoria en el móvil de referencia con 8 fichas, con ayuda del responsable, y registrar los datos.
- [ ] **Paso 5:** Presentar capturas y datos al responsable. Si no aprueba, iterar sobre sus comentarios.
- [ ] **Paso 6:** Marcar los assets como `Approved` y escribir `puerta-b.md`.
- [ ] **Paso 7:** Hacer commit: `feat: aprobar porción vertical`.
