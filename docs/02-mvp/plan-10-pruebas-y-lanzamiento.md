# Subfase 10: Pruebas y lanzamiento. Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (recommended) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Comprobar todos los criterios de salida con jugadores reales, cumplir las normas y publicar el MVP.

**Architecture:** Las decisiones se toman con `tools/criteria-report`, las encuestas y el manifiesto. Los ajustes se hacen solo en `config`, salvo errores.

**Tech Stack:** Lune, MCP de Studio, Creator Hub.

**Spec:** "Cuándo está listo" y "Riesgos" en la [ficha](../00-ficha/ficha-propuesta.md).

## Ejecución recomendada

**Modo:** en la sesión, con `superpowers:executing-plans`.

**Por qué:** hay poco código y mucha coordinación: partidas con personas, datos, ajustes y decisiones del responsable. Esa conversación dura días, y una sola sesión conserva el hilo mejor que subagentes que empiezan de cero.

**Instrucciones para la sesión:**

- Sigue también las [instrucciones generales](../instrucciones-de-sesion.md).
- Requiere los planes 08 y 09 terminados.
- Es normal que esta sesión se pause y se retome: registra cada resultado en `docs/02-mvp/resultados/` al obtenerlo.
- Nunca completes un criterio sin datos reales ni estimes partidas o encuestas.
- Cambia un solo grupo de valores a la vez entre tandas de prueba, para saber qué causó cada mejora.
- La consulta legal y el cuestionario de madurez los hace el responsable; prepárale el material.
- Publicar solo con su aprobación por escrito. Termina con la Puerta C decidida.

## Global Constraints

- Mínimo 20 partidas con grupos de amigos y después una prueba abierta pequeña.
- Sin fecha ni presupuesto fijos: se publica cuando se cumple la lista.
- Clasificación objetivo: Minimal o Mild.
- Sin apuestas, sin estética de casino, sin objetos de pago al azar.
- Sin el nombre, logo, personajes ni diseño de tablero de Monopoly.
- Publicar requiere la aprobación explícita del responsable.

## Review Focus

1. Pocas partidas dan un resultado engañoso: el informe muestra el tamaño de la muestra. Prueba en Tarea 1.
2. Una carta destaca en las pruebas pero no en la simulación, o al revés: se registran ambas. Criterio en Tarea 2.
3. El Huracán se siente injusto: la encuesta pregunta por ello. Criterio en Tarea 2.
4. Una norma de Roblox cambió desde esta ficha: se revisa antes de publicar. Criterio en Tarea 5.
5. Un servidor público falla con muchos jugadores: hay plan para revertir. Criterio en Tarea 6.

---

### Task 1: Informe y encuesta

**Módulos:** `tools/criteria-report`.

**Archivos:**
- Modificar: `tools/criteria-report.luau`, `tests/tools/criteria-report.spec.luau`
- Crear: `docs/02-mvp/resultados/encuesta.md`

**Interfaces:**
- Produce: `CriteriaReport.compute(summaries: { Summary }, surveys: { Survey }): Report`.
- Produce: `Survey = { matchId: string, boredWaiting: boolean, wouldPlayAgain: boolean, funniest: string, unfair: string? }`.

**Criterios de aceptación:**
- [ ] Calcula los 5 criterios medibles y muestra el número de partidas de cada uno.
- [ ] Muestra "datos insuficientes" con menos de 20 partidas.
- [ ] Separa los resultados por tamaño de ciudad.
- [ ] La encuesta tiene 4 preguntas, se responde en menos de 1 minuto y no pide datos personales.

- [ ] **Paso 1: Escribir las pruebas**

```luau
it("avisa con pocas partidas", function()
    expect(CriteriaReport.compute(Fixtures.summaries(5), {}).status).toBe("InsufficientData")
end)
it("calcula la tasa de revancha", function()
    local r = CriteriaReport.compute(Fixtures.summaries(20, { rematch = 8 }), {})
    expect(r.rematchRate).toBe(0.4)
end)
```

- [ ] **Paso 2:** Ejecutar `lune run tests/run criteria-report`. Esperado: FAIL.
- [ ] **Paso 3:** Ampliar el informe y escribir la encuesta.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: completar informe de criterios`.

### Task 2: Partidas con amigos y equilibrado

**Módulos:** `config/*`, `tests/sim-report`.

**Archivos:**
- Modificar: `src/shared/config/*.luau`
- Crear: `docs/02-mvp/resultados/pruebas-amigos.md`

**Criterios de aceptación:**
- [ ] 20 partidas o más en modo Rondas, de 4 a 8 jugadores, repartidas entre los 3 tamaños.
- [ ] Al menos 2 partidas completas en modo Sin Fin, para comprobar que terminan y siguen divirtiendo.
- [ ] Se revisa con datos cada cuánto salen legendarias y si dos muy seguidas se sienten injustas.
- [ ] Se usa una versión privada con todo el arte final.
- [ ] Quien lidera a mitad de partida gana como máximo 50 % de las veces.
- [ ] Los 7 criterios de salida están medidos y documentados.
- [ ] Cada cambio de valores queda registrado con su motivo y con el resultado antes y después.
- [ ] Se comprueba con la encuesta que Huracán y las demás legendarias no se sienten como borrar la partida.

- [ ] **Paso 1:** Pedir permiso al responsable para la versión privada, y pedirle que reúna los grupos.
- [ ] **Paso 2:** Jugar la primera tanda de 10 partidas.
- [ ] **Paso 3:** Ejecutar `lune run tools/criteria-report`, `lune run tests/sim-report` y revisar las encuestas.
- [ ] **Paso 4:** Ajustar `config` y comprobar con `lune run tools/check`. Esperado: código 0.
- [ ] **Paso 5:** Jugar la segunda tanda y repetir hasta cumplir.
- [ ] **Paso 6:** Hacer commit: `balance: ajustar valores con pruebas reales`.

### Task 3: Auditoría de calidad

**Módulos:** `tools/manifest`.

**Archivos:**
- Crear: `docs/02-mvp/resultados/auditoria-assets.md`

**Criterios de aceptación:**
- [ ] El 100 % de los assets publicados tiene estado `Approved`.
- [ ] No queda ningún elemento gris, temporal o de la Toolbox.
- [ ] El responsable juega una partida completa y aprueba la calidad global.
- [ ] 30 FPS o más en el móvil de referencia, con 8 jugadores y Huracán.

- [ ] **Paso 1:** Ejecutar `lune run tools/manifest`. Esperado: sin problemas y 100 % aprobado.
- [ ] **Paso 2:** Medir el peor caso de rendimiento, con ayuda del responsable.
- [ ] **Paso 3:** Registrar los resultados y la aprobación.
- [ ] **Paso 4:** Hacer commit: `docs: registrar auditoría de assets`.

### Task 4: Nombre y revisión legal

**Módulos:** identidad del juego.

**Archivos:**
- Crear: `docs/02-mvp/resultados/revision-legal.md`

**Criterios de aceptación:**
- [ ] El responsable elige el nombre definitivo, tras comprobar que no choca con otros juegos o marcas.
- [ ] Un abogado revisa nombre, identidad y parecido con Monopoly. Los agentes no sustituyen esta consulta.
- [ ] No aparece el nombre, logo, personajes ni diseño de tablero de Monopoly, ni tampoco nombres de sus propiedades, en el juego ni en su descripción.
- [ ] Los assets generados con IA tienen condiciones de uso comercial compatibles.

- [ ] **Paso 1:** Preparar el resumen y las capturas para la consulta.
- [ ] **Paso 2:** El responsable hace la consulta y registra la conclusión.
- [ ] **Paso 3:** Aplicar los cambios necesarios y hacer commit: `docs: registrar revisión legal`.

### Task 5: Cumplimiento de Roblox

**Módulos:** configuración de la experiencia.

**Archivos:**
- Crear: `docs/02-mvp/resultados/cumplimiento-roblox.md`

**Criterios de aceptación:**
- [ ] Se vuelve a leer la [guía de experiencias](https://create.roblox.com/docs/production/promotion/experience-guidelines) vigente y se revisan los cambios.
- [ ] Ninguna mecánica pide arriesgar nada de valor en un juego de azar. Se revisan Cartelera, Duelo, Mercado Negro y Subasta.
- [ ] El responsable completa el cuestionario de madurez y cumplimiento, con la etiqueta objetivo Minimal o Mild.
- [ ] El juego funciona sin chat ni voz.
- [ ] No hay objetos de pago al azar; no hay compras en el MVP.

- [ ] **Paso 1:** Revisar cada casilla y carta con la guía; registrar las conclusiones.
- [ ] **Paso 2:** Si una mecánica no cumple, proponer el cambio al responsable.
- [ ] **Paso 3:** El responsable completa el cuestionario. Es una declaración suya, no de los agentes.
- [ ] **Paso 4:** Hacer commit: `docs: registrar cumplimiento de Roblox`.

### Task 6: Prueba abierta y publicación

**Módulos:** `server/lobby/PublicQueue`, `server/match/Telemetry`.

**Archivos:**
- Crear: `docs/02-mvp/resultados/puerta-c.md`, `docs/02-mvp/lanzamiento.md`

**Criterios de aceptación:**
- [ ] Prueba abierta pequeña, con acceso limitado, y con todos los criterios medidos de nuevo.
- [ ] `lanzamiento.md` incluye descripción, imágenes, plan para revertir y a quién avisar.
- [ ] Partidas públicas y privadas funcionan en la versión publicada.
- [ ] El responsable aprueba por escrito la Puerta C y la publicación.
- [ ] Antes de iniciar la Fase 1, se revisa su plan con estos resultados.

- [ ] **Paso 1:** Pedir permiso al responsable para abrir la prueba.
- [ ] **Paso 2:** Vigilar errores y resúmenes; corregir lo crítico.
- [ ] **Paso 3:** Ejecutar `lune run tools/criteria-report` y escribir `puerta-c.md`.
- [ ] **Paso 4:** Pedir al responsable la decisión de publicar; publicar solo con su aprobación.
- [ ] **Paso 5:** Hacer commit: `docs: registrar lanzamiento del MVP`.
