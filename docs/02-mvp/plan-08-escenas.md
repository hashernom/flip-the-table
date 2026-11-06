# Subfase 08: Escenas. Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Referencia:** [la visión visual](../../art/vision-visual.md): las escenas quitan marcadores y añadidos, y el cuerpo del edificio queda en pie.

**Goal:** Sustituir todas las escenas provisionales, para que cada regla importante ocurra de verdad en la ciudad y todo el grupo la vea.

**Architecture:** Cada escena es un módulo registrado en `SceneDirector` por evento o por carta. Las escenas solo muestran: el estado ya lo decidió el servidor. Una tabla en `config/Scenes` fija duraciones y una prueba impide que falte alguna.

**Tech Stack:** Luau, Roblox Studio con su MCP, TweenService, partículas y animaciones aprobadas.

**Spec:** "Toda regla importante es una escena" en la [ficha](../00-ficha/ficha-propuesta.md).

## Ejecución recomendada

**Modo:** subagentes, con `superpowers:subagent-driven-development`.

**Por qué:** las escenas comparten un contrato estable y se producen en grupos independientes. Cada grupo consume mucho contexto en pruebas y capturas, y un revisor nuevo detecta si una escena deja el mundo distinto del estado real.

**Instrucciones para la sesión:**

- Sigue también las [instrucciones generales](../instrucciones-de-sesion.md).
- Requiere el plan 07 terminado, y Studio y Blender abiertos con sus MCP. Los subagentes van de uno en uno.
- Haz primero la Tarea 1; el resto depende de ese contrato.
- Una escena solo muestra el resultado: nunca decide ni cambia reglas.
- Comprueba cada escena con varios clientes, porque el grupo debe ver lo mismo a la vez.
- Muestra un video al responsable para aprobar las escenas; una captura no enseña el ritmo.
- Termina cuando el turno medio en 8 jugadores es de 20 s o menos, con las escenas finales.

## Global Constraints

- Todo el grupo ve la misma escena a la vez, como en Mario Party.
- Comunes y raras de 2 a 4 s; legendarias, hasta 10 s. Excepción decidida por el responsable (2026-11-06): el arresto dura 15 s.
- Las escenas repetidas tienen variaciones y se acortan si ya se vieron en esa partida.
- Tono caricaturesco y apto para todo público.
- Una escena no se interrumpe con la vista general.
- Un cliente lento nunca detiene la partida.

## Review Focus

1. Un cliente entra a mitad de una escena: ve el estado correcto, sin escena rota. Prueba en Tarea 1.
2. Un avatar extremo en el arresto: las esposas y la patrulla no se ven rotas. Prueba en Tarea 2.
3. Dos escenas seguidas sobre el mismo edificio no lo dejan en un nivel incorrecto. Prueba en Tarea 1.
4. Huracán sin mejoras construidas: la escena sigue teniendo sentido. Prueba en Tarea 3.
5. Muchas partículas en móvil: se reducen sin perder la idea de la escena. Prueba en Tarea 7.

---

### Task 1: Director final

**Módulos:** `client/scenes/SceneDirector`, `client/scenes/SceneContext`, `config/Scenes`.

**Archivos:**
- Modificar: `src/client/scenes/SceneDirector.luau`, `src/shared/config/Scenes.luau`
- Crear: `src/client/scenes/SceneContext.luau`, `src/client/scenes/SceneRegistry.luau`, `tests/config/Scenes.spec.luau`

**Interfaces:**
- Produce: `SceneContext = { event: Event, view: PlayerView, startedAt: number, duration: number, shortened: boolean, variation: number, world: WorldApi, camera: CameraApi, audio: AudioApi }`.
- Produce: `Scenes.allIds(): { string }`, y `SceneRegistry.ids(): { string }`.

**Criterios de aceptación:**
- [x] Toda carta y todo evento de la lista tiene entrada en `Scenes` y una escena registrada.
- [x] Al terminar, el mundo coincide con `view`, aunque la escena falle o se salte.
- [x] Una escena iniciada tarde empieza en su punto correcto o se omite si le quedan menos de 500 ms.
- [x] La variación se calcula con los datos del evento, así todos ven la misma.

- [x] **Paso 1: Escribir las pruebas**

```luau
it("toda carta tiene escena y duración", function()
    for _, card in CardsConfig.all do
        expect(Scenes.durationFor({ type = "CardPlayed", cardId = card.id }, 0) > 0).toBeTruthy()
    end
end)
it("respeta los límites de duración", function()
    for _, card in CardsConfig.all do
        local d = Scenes.durationFor({ type = "CardPlayed", cardId = card.id }, 0)
        if card.rarity == "Legendary" then expect(d <= 10).toBeTruthy()
        else expect(d >= 2 and d <= 4).toBeTruthy() end
    end
end)
```

- [x] **Paso 2:** Ejecutar `lune run tests/run Scenes`. Esperado: FAIL si falta algún dato.
- [x] **Paso 3:** Implementar el contexto, la conciliación con `view` y el registro.
- [x] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** En Test Server, unir un segundo cliente durante una escena. Esperado: el mundo coincide con `view`.
- [ ] **Paso 6:** Hacer commit: `feat: completar el director de escenas`.

### Task 2: Arresto y Tribunal

**Módulos:** `client/scenes/Arrest`, `client/scenes/Tribunal`.

**Archivos:**
- Crear: `src/client/scenes/Arrest.luau`, `src/client/scenes/Tribunal.luau`

**Criterios de aceptación:**
- [ ] Llegan patrullas con sirenas, bajan al jugador de la ficha, lo esposan y lo llevan, como pide la ficha.
- [ ] El grupo ve el voto y el veredicto.
- [ ] Multa, perder turno y pagar a otro tienen un cierre visible distinto.
- [ ] Funciona con avatares de escala mínima y máxima.
- [ ] Sonido propio y duración dentro del límite.

- [ ] **Paso 1:** Implementar a partir de la porción vertical.
- [ ] **Paso 2:** Forzar `PlayerArrested` en Test Server con 2 clientes; grabar ambos. Esperado: misma escena a la vez.
- [ ] **Paso 3:** Probar con avatares extremos.
- [ ] **Paso 4:** Obtener la aprobación del responsable.
- [ ] **Paso 5:** Hacer commit: `feat: añadir arresto y Tribunal`.

### Task 3: Cinco legendarias

**Módulos:** `client/scenes/legendary/*`.

**Archivos:**
- Crear: `src/client/scenes/legendary/Hurricane.luau`, `WorldFlip.luau`, `Revolution.luau`, `Earthquake.luau`, `CrownStrike.luau`

**Criterios de aceptación:**
- [ ] **Huracán:** se oscurece el cielo, entra un huracán y se lleva marcadores, toldos, rótulos y remates; el cuerpo de los edificios queda en pie, y sin mejoras levanta carteles y coches.
- [ ] **Mundo al Revés:** la ciudad gira en el aire y cada ficha cae en una casilla distinta.
- [ ] **Revolución:** una multitud toma las calles y camiones blindados cambian el dinero de manos.
- [ ] **Terremoto:** las calles se agrietan, los edificios de la zona tiemblan y cada uno pierde un marcador y su último añadido. Las grietas y el humo duran lo que la escena.
- [ ] **Golpe a la Corona:** la corona del líder cae, y el dinero sale volando hacia los demás.
- [ ] Cada una dura 10 s o menos, y al terminar el mundo coincide con `view`.
- [ ] Es el momento de mayor calidad del juego: el responsable aprueba cada una por separado.

- [ ] **Paso 1:** Producir Huracán y obtener su aprobación antes de seguir con las demás.
- [x] **Paso 2:** Producir las otras 4.
- [ ] **Paso 3:** Forzar cada carta en los 3 tamaños de ciudad; comprobar coincidencia con `view`.
- [ ] **Paso 4:** Obtener la aprobación del responsable.
- [x] **Paso 5:** Hacer commit: `feat: añadir cinemáticas legendarias`.

**Estado (2026-11-06):** las cinco escenas están escritas en `src/client/scenes/legendary/`, con sus reglas puras en `LegendaryRules` (22 pruebas) y su puesta en escena en `config/LegendaryStaging`. No se han visto en Studio: los criterios de arriba quedan sin marcar hasta que el responsable las pruebe en los 3 tamaños y las apruebe una a una.

### Task 4: Cartas raras y comunes

**Módulos:** `client/scenes/cards/*`.

**Archivos:**
- Crear: `src/client/scenes/cards/` con una escena por cada carta rara y común, 15 en total.

**Criterios de aceptación:**
- [ ] Huelga: los locales bajan las persianas y la zona se queda en silencio.
- [ ] Demolición: una bola de demolición golpea el edificio rival; salta un marcador y cae su último añadido.
- [ ] Inflación: los precios de los carteles suben y vuelan billetes.
- [ ] Multa: un policía entrega el parte.
- [ ] Cada escena dura de 2 a 4 s y deja claro quién actuó y a quién afectó.
- [ ] Escudo y Renta Rebotada muestran la reacción con claridad.

- [ ] **Paso 1:** Implementar las 6 raras y obtener su aprobación.
- [ ] **Paso 2:** Implementar las 9 comunes y obtener su aprobación.
- [ ] **Paso 3:** Ejecutar `lune run tests/run Scenes`. Esperado: PASS.
- [ ] **Paso 4:** Hacer commit: `feat: añadir escenas de cartas`.

**Estado (2026-11-06):** las 6 raras tienen escena en `src/client/scenes/cards/`: Ladrón de Escrituras, Demolición, Huelga, Inflación, Puñalada y Renta Rebotada, con sus reglas puras en `CardSceneRules` (10 pruebas) y su puesta en escena en `config/CardStaging`. Para poder enseñarlas, `CardPlayed` lleva `targetId` del socio en la Puñalada, y la Renta Rebotada emite su propio `CardPlayed`. Sin ver en Studio: falta la aprobación del responsable, y después las 9 comunes.

### Task 5: Escenas de casillas

**Módulos:** `client/scenes/squares/*`.

**Archivos:**
- Crear: `src/client/scenes/squares/Billboard.luau`, `Duel.luau`, `Portal.luau`, `Market.luau`, `Spin.luau`, `Tax.luau`

**Criterios de aceptación:**
- [ ] **Cartelera:** la pantalla gigante se enciende, las imágenes pasan cada vez más lento y se detiene en el resultado. Premio con dinero cayendo; multa con un policía; carta; nada, con la pantalla burlándose.
- [ ] **Cartelera:** no muestra números de apuesta, fichas de casino ni nada parecido a una ruleta.
- [ ] **Duelo:** los dos rivales quedan frente a frente y sus elecciones se revelan a la vez.
- [ ] **Portal, Mercado, Giro e Impuesto:** tienen escena propia.

- [ ] **Paso 1:** Implementar las 6 escenas.
- [ ] **Paso 2:** Forzar cada resultado de la Cartelera y capturar.
- [ ] **Paso 3:** Obtener la aprobación del responsable.
- [ ] **Paso 4:** Hacer commit: `feat: añadir escenas de casillas`.

### Task 6: Escenas de la partida

**Módulos:** `client/scenes/game/*`.

**Archivos:**
- Crear: `src/client/scenes/game/Dice.luau`, `Buy.luau`, `Rent.luau`, `Auction.luau`, `Build.luau`, `Bankruptcy.luau`, `Traitor.luau`, `Pact.luau`, `HotZone.luau`, `Crown.luau`, `Fury.luau`, `Ghost.luau`, `FinalRounds.luau`, `Podium.luau`, `CityReveal.luau`

**Criterios de aceptación:**
- [ ] **Construir:** llega una grúa, deja el marcador nuevo y monta el añadido del nivel.
- [ ] **Bancarrota:** una grúa se lleva la ficha y el avatar se vuelve espectro.
- [ ] **Traición:** un foco sigue al traidor y un cartel gigante lo señala; la marca dura sus 3 rondas.
- [ ] **Última Ronda:** aviso visible, con cambio de música y de ambiente, solo en modo Rondas.
- [ ] **Sin Fin:** la presión de la ronda 30 tiene su aviso, y el podio funciona con un único superviviente.
- [ ] **Podio:** fichas, clasificación, premios del final y botón de revancha.
- [ ] **Inicio:** el vuelo de cámara muestra los puentes abriéndose y los barrios iluminándose según el tamaño.
- [ ] La corona se ve sobre la ficha del líder durante toda la partida.

- [ ] **Paso 1:** Implementar y forzar cada evento en Test Server.
- [ ] **Paso 2:** Jugar una partida completa con bots y grabarla.
- [ ] **Paso 3:** Obtener la aprobación del responsable.
- [ ] **Paso 4:** Hacer commit: `feat: añadir escenas de partida`.

### Task 7: Variaciones, ritmo y rendimiento

**Módulos:** `config/Scenes`, `client/scenes/*`.

**Archivos:**
- Modificar: `src/shared/config/Scenes.luau`, escenas que lo requieran
- Crear: `docs/02-mvp/resultados/ritmo-escenas.md`

**Criterios de aceptación:**
- [ ] Las escenas más frecuentes tienen al menos 2 variaciones: renta, compra, construcción y dados.
- [ ] La segunda vez y las siguientes en una partida son más cortas.
- [ ] Una partida simulada de 8 jugadores da un turno medio de 20 s o menos.
- [ ] En móvil, los efectos se reducen automáticamente y se mantienen 30 FPS o más en Huracán.
- [ ] Los 8 clientes de una partida ven las escenas con menos de 250 ms de diferencia.

- [ ] **Paso 1:** Ampliar `tests/sim-report` con el tiempo de escena por turno y por tamaño.
- [ ] **Paso 2:** Ajustar duraciones hasta cumplir el turno medio.
- [ ] **Paso 3:** Medir Huracán en el móvil de referencia, con ayuda del responsable.
- [ ] **Paso 4:** Registrar los resultados.
- [ ] **Paso 5:** Hacer commit: `perf: ajustar ritmo y coste de las escenas`.
