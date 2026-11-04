# Auditoría de Flip the Table: primera pasada parcial

Commit auditado: `472e78c` (`main`). Fecha: 2026-11-04. **Esta auditoría quedó incompleta y hay que rehacerla entera.** Sus hallazgos son un punto de partida, no un veredicto.

## Razón de la auditoría

El responsable ha desarrollado el MVP hasta el plan 05, con parte importante del plan 06, y esos planes se daban por funcionales y verificados. Quiere comprobar, fase por fase, que todo está implementado según lo documentado y que funciona de verdad, con un informe final de todos los hallazgos. El motivo: ahora viene la parte visual, la más importante, y no quiere arrastrar bugs ni problemas de planes anteriores. Mientras tanto se quiere avanzar con el arte, terminar el plan 06 y seguir con los siguientes.

## Hallazgos

Cómo se comprobó cada uno: **ejecutado** (sonda con el código real), **búsqueda** o **lectura** (sin ejecutar). Nada se probó en Studio ni con dos clientes reales.

### Críticos

1. **Plan 05, subastas (ejecutado).** Con una puja alta de 200, el control ofrece de 10 a 210 y arranca en 10; «Pujar 10» se rechaza con «La puja debe superar la actual». Habría que pulsar `+` unas 20 veces en 15 s, cada vista nueva lo devuelve a 10 y no se puede pujar más de alta + 10. `src/client/ui/ActionMenuRules.luau:127`, `src/client/ui/ActionMenu.luau:131`. La spec no lo cubre.
2. **Plan 05, Duelo (ejecutado).** Tres botones idénticos «Elegir jugada», sin decir cuál es cuál; al elegir rival pasa lo mismo. `src/client/ui/ActionMenuRules.luau:55-77`.

Por estos dos, el criterio «jugar toda la partida solo con menús» (plan 05, línea 180) no se cumple.

### Importantes

3. **Plan 05, Mercado (ejecutado).** Botones idénticos «Comprar del mercado»: `labelFor` lee `action.index` y `MarketBuy` usa `cardId`. `ActionMenuRules.luau:61`.
4. **Plan 05, cartas con objetivo.** «Jugar carta: Fine» se repite por rival sin decir a quién apunta; Renta Rebotada igual, y «Repetir dado» no dice qué dado (ejecutado). Las cartas de zona y propiedad generan hasta 12 o 34 botones iguales (lectura).
5. **Planes 04 y 05, revancha (búsqueda).** El servidor la soporta (`src/server/match/RematchService.luau:174`), pero `rematch` y `revancha` no aparecen en `src/client`: no hay botón.
6. **Plan 05, ciudad (lectura).** `CityBuilder.setOwner` (`src/client/world/CityBuilder.luau:244`) no se llama desde ningún sitio y `src/client/world` no lee `level`. Dueños y edificios solo se ven como texto en `src/client/ui/Overview.luau:127`.
7. **Plan 04, teletransporte (lectura).** Al agotar los reintentos solo hay un `warn` (`src/server/lobby/Teleport.luau:45`), sin aviso ni vuelta al lobby, que el plan exige.
8. **Plan 03, espectros (lectura).** No pueden jugar sus cartas de sabotaje: `src/shared/rules/Cards.luau:654` exige estado Active y en `GhostTurn` solo se ofrecen Sabotage y Haunt (`src/shared/rules/Engine.luau:780-793`). Acumulan cartas sin efecto hasta resucitar.
9. **Plan 02, Sin Fin (ejecutado, solo con tiempo agotado).** Con 2 jugadores terminó en las rondas 1 048 a 2 664. Con 5, 2 de 3 partidas seguían en la ronda 20 000 aproximadamente a los 300 000 ticks. Con 8, 3 de 3 seguían en la ronda 12 000 aproximadamente. `tests/sim.spec.luau:56` y `:175` solo prueban este caso en Rondas, con una justificación de la fase 02 que no se revisó tras la fase 03.

### Sin confirmar (revisión de bajo nivel, por lectura)

10. **Plan 04.** Entre la reserva y el borrado de la party, un fallo del almacén podría dejar a alguien en una party borrada, sin aviso (`src/server/lobby/PartyService.luau:317-327`).
11. **Plan 04.** Los limitadores de peticiones no se purgan y no hay castigo por inundar (`src/shared/net/Protocol.luau:345-368`).

### Menores

12. El temporizador no se fija en la vista inicial ni en el resync, y lo calcula el cliente (`src/client/main.client.luau:344-349`, `:358-366`).
13. Revolución ordena por patrimonio pero intercambia efectivo (`src/shared/rules/Cards.luau:530`); la ficha dice «más ricos».
14. El plan 03 (línea 321) dice «sabotajes jugados»; el código cuenta los acumulados, como la ficha.
15. `status = "Left"` no se asigna nunca en `src/shared/rules` ni `src/server`: confirmar si es código muerto.
16. `BANK_SALE_DIVISOR` está fijo en `src/shared/rules/Bankruptcy.luau:17` y `Cards.luau:469`, fuera de config.
17. Sigue pendiente renombrar Apagón a Huelga (`docs/00-ficha/ficha-propuesta.md:350`).
18. `docs/README.md` aún dice que el juego no se ha construido, y `contenido-tablero.md` habla de «Metrópolis de Noche» cuando lo decidido es de día y sin neón.

### Del repositorio

19. **Git LFS a medias.** `.gitattributes` manda FBX y texturas a LFS, pero el historial los guarda como archivos normales. Cada worktree nuevo aparece con 52 archivos modificados sin que nadie los toque.
20. **`.claude/` no está en `.gitignore`.** Aparece sin seguimiento y podría colarse en un commit.

### Resultados positivos, sin dar por cerrados

- `lune run tools/check` pasó entero en `main` (8 min 15 s).
- Sonda hostil de 90 s: 495 partidas, 668 948 acciones legales aleatorias y 185 968 hostiles. Sin cierres inesperados, rechazos que alteren el estado, efectivo negativo o no entero, niveles fuera de rango ni dueños inactivos. Todas las partidas en Rondas terminaron.
- Por lectura coinciden con la documentación renta, escalera, bancarrota, subasta, movimiento, clasificación y permisos de `Engine`, y `Boards.luau` coincide con `contenido-tablero.md` en precios y número de casillas especiales.
- Por lectura, el manifiesto cubre los rechazos del plan 06, `src/` no tiene `rbxassetid` y la búsqueda no encontró claves en `art`, `tools` ni `src`.

## Qué implementar

1. **Menús del cliente:** corregir la puja (mínimo legal por defecto y posibilidad de subir más), y hacer que Duelo, Mercado, cartas con objetivo y repetir dado digan qué hace cada botón. Añadir pruebas con estados reales del motor.
2. **Botón de revancha** en el cliente.
3. **Dueños y edificios visibles en la ciudad:** conectar `setOwner` y dejar el enganche para `BuildingView.setLevel` del plan 06.
4. **Fallo de teletransporte:** avisar al jugador y devolverlo al lobby.
5. **Espectros:** decidir y aplicar cómo se usan las cartas de sabotaje.
6. **Sin Fin:** decidir cómo termina una partida sin acciones y añadir su prueba.
7. **Repositorio:** resolver LFS e ignorar `.claude/`.

### Decisiones del responsable

- ¿Escudo debe frenar Ladrón de Escrituras y Demolición? Hoy solo cubre cartas con objetivo jugador (`Cards.luau:718`), y la ficha dice «anula la próxima carta que te apunte».
- ¿Una sola resurrección por jugador? Está en `src/shared/rules/Comeback.luau:177-181` y la ficha no la menciona.
- La ventana de reacción solo se abre si el objetivo tiene la carta, lo que delata a toda la mesa que lleva Escudo o Renta Rebotada. Choca con la regla de que el juego sea impredecible.
- Definición de alpha para la Puerta A. La provisional es el resultado de los planes 06 a 09, en lugar privado y antes del plan 10.
- `docs/00-ficha/ficha-propuesta.md:257` dice «Las reglas se prueban primero en privado con arte provisional», y eso contradice el aplazamiento. Hay que corregir la ficha o revisar la decisión.

## Para la segunda pasada

**Rehacer completo:** nada de esta pasada sustituye a la auditoría real. Los hallazgos ejecutados deberían reproducirse; los de lectura hay que confirmarlos.

**Sin auditar:**
- Plan 01, omitido a propósito. Solo se leyeron por encima el arnés y el tablero. Falta probar con sondas que un fallo dé código de salida distinto de 0.
- Los 34 nombres de propiedades frente a `contenido-tablero.md`.
- Línea a línea: `Squares`, `Pact`, `Perks`, `Trade`, `Reaction`, `Bot` y `Deck`, sobre todo interacciones cruzadas entre cartas, pactos, perks y bancarrota. Comprobar cada carta, perk y casilla contra la ficha.
- Conservación del dinero evento a evento y nombres de campo reales en las acciones hostiles, porque la sonda usó una muestra.
- Fugas de información en los eventos reales, no solo en `View`.
- Plan 04: acciones sin `turnOnly`, casillas 187 y 205, y las líneas 147 y 170.
- Plan 05: fugas de conexiones entre partidas y revanchas, unirse tarde, y solapes de HUD. Revisar también la cobertura real de las specs del cliente.
- Plan 06: criterio por criterio, con sondas contra `tools/manifest.luau` y contrastando `art/PIPELINE.md` con la documentación oficial de Roblox. Revisar `tests/tools/manifest.spec.luau:139` («nunca aprobado»), que podría chocar con aprobar assets en la Puerta B.
- Transversal: de la ficha al código buscando promesas sin plan, de la arquitectura al código, números fuera de config y normas (sin apuestas, sin pago para ganar, sin marca de Monopoly).

**Pruebas en Studio (solo un agente a la vez), todas pendientes:**
- Test Server con 2 clientes: lotes con `seq` en orden y escenas con menos de 250 ms de diferencia.
- Cerrar un cliente a mitad de turno y comprobar que el bot sigue.
- Emotes visibles para todos.
- Móvil de pantalla pequeña sin solapes.
- Una partida completa con menús.
- Lugar privado con 2 cuentas: requiere permiso del responsable para publicar.

**Estado que se encuentra la siguiente sesión:**
- Puerta A: el responsable decidió aplazarla hasta tener una alpha. El cambio está en la rama `docs-puerta-a-tras-alpha`, commit `5e46c2b`, sin revisar ni integrar. No está aprobada.
- Rama `plan-06-base-de-arte`: igual que `main`, sin trabajo. La verificación de albedos no se hizo; es el punto 1 de «Lo que falta» en `art/ESTADO.md`. Comprobar si quedó un Model `AlbedoCheck` o cambios sin guardar en Studio.
- Quedan dos worktrees en `.claude/worktrees/` y la rama `worktree-agent-ad44be401466279cd`, todo limpiable.
- Móvil de referencia sin elegir: hace falta antes de la Puerta B.
- El plan 07 y siguientes no empiezan hasta aprobar la Puerta B, que depende del responsable.
- La suite tarda más de 8 minutos, sobre todo por las 14 000 partidas de `tests/sim.spec.luau`: filtrar por nombre al ejecutar pruebas.
