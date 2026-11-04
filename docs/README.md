# Flip the Table: documentación

Punto de entrada a toda la documentación del proyecto: qué se construye y en qué orden. El motor, el servidor y un cliente gris ya existen (subfases 01 a 05, sin probar todavía con un grupo real); cada plan dice qué se comprobó de verdad.

## Cómo leer esto

1. **Ficha general:** [00-ficha/ficha-propuesta.md](00-ficha/ficha-propuesta.md). Qué es el juego. Si un plan la contradice, manda la ficha.
2. **Visión visual:** [art/vision-visual.md](../art/vision-visual.md). Cómo debe verse la ciudad, en palabras: léela antes de tocar arte, ciudad o escenas.
3. **Arquitectura:** [01-arquitectura/arquitectura.md](01-arquitectura/arquitectura.md). Stack, módulos y contratos que comparten todos los planes.
4. **Una carpeta por fase:** cada una tiene su ficha (qué y por qué) y su plan (cómo, tarea por tarea).
5. **Contenido del tablero:** [zonas, colores y propiedades](02-mvp/contenido-tablero.md). Nombres y precios de las 12 zonas y las 34 propiedades.

Cada tarea de cada plan indica sus módulos, sus interfaces, sus criterios de aceptación y sus pasos.

**Para ejecutar un plan:** empieza por las [instrucciones de sesión](instrucciones-de-sesion.md). Cada plan indica además su modo de ejecución recomendado, el motivo y sus instrucciones propias.

## Fases

| Fase | Objetivo | Se abre cuando | Ficha | Planes |
| --- | --- | --- | --- | --- |
| MVP | Una ciudad terminada para 2 a 8 amigos | Ficha aprobada | [ficha](02-mvp/ficha-mvp.md) | 10 subfases, abajo |
| Fase 1: Más partidas | Modo de equipos, más contenido y tienda de cosméticos | El MVP cumple sus objetivos | [ficha](03-fase-1-mas-partidas/ficha.md) | [plan](03-fase-1-mas-partidas/plan.md) |
| Fase 2: Nuevos mundos | Isla Pirata, Estación Espacial y partys de 9 a 12 | Los grupos siguen pidiendo revancha | [ficha](04-fase-2-nuevos-mundos/ficha.md) | [plan](04-fase-2-nuevos-mundos/plan.md) |
| Fase 3: Progresión | Niveles, misiones, colecciones y pase de temporada | Los mapas nuevos traen de vuelta al grupo | [ficha](05-fase-3-progresion/ficha.md) | [plan](05-fase-3-progresion/plan.md) |
| Fase 4: Comunidad | Temporadas, eventos, torneos y clips | La progresión aumenta el regreso de jugadores | [ficha](06-fase-4-comunidad/ficha.md) | [plan](06-fase-4-comunidad/plan.md) |

## Subfases del MVP

| N.º | Subfase | Resultado | Puerta al terminar |
| --- | --- | --- | --- |
| 01 | [Cimientos](02-mvp/plan-01-cimientos.md) | Repositorio, pruebas y datos base | |
| 02 | [Motor de reglas](02-mvp/plan-02-motor-de-reglas.md) | Partida base completa, sin Roblox | |
| 03 | [Dinámicas únicas](02-mvp/plan-03-dinamicas.md) | Cartas, perks, casillas, pactos y remontada | |
| 04 | [Red y partidas](02-mvp/plan-04-red-y-partidas.md) | Servidor, party, bots y revancha | |
| 05 | [Cliente jugable](02-mvp/plan-05-cliente-jugable.md) | Prototipo gris jugable con amigos | Puerta A aplazada hasta la alpha (ver abajo) |
| 06 | [Base de arte](02-mvp/plan-06-base-de-arte.md) | Tubería de assets y porción vertical | **Puerta B:** nivel visual aprobado y fluido en móvil |
| 07 | [Ciudad y fichas](02-mvp/plan-07-ciudad-y-fichas.md) | Metrópolis, 8 fichas y personajes | |
| 08 | [Escenas](02-mvp/plan-08-escenas.md) | Todas las escenas del juego | |
| 09 | [Interfaz, audio y aprendizaje](02-mvp/plan-09-interfaz-audio-aprendizaje.md) | Interfaz final, sonido y primera partida guiada | **Alpha** (provisional) y **Puerta A:** las reglas divierten |
| 10 | [Pruebas y lanzamiento](02-mvp/plan-10-pruebas-y-lanzamiento.md) | Criterios de salida cumplidos y juego publicado | **Puerta C:** abre la Fase 1 |

## Reglas de trabajo

- **Reglas antes que arte:** las subfases 01 a 05 prueban si el juego divierte con arte provisional, antes de producir los assets finales. **Excepción (2026-11-04):** por decisión del responsable, la Puerta A no se pasa sobre el prototipo gris sino sobre una alpha. Esta alpha es provisional, pendiente de confirmar: el juego con el resultado de las subfases 06 a 09, antes de la 10, en un lugar privado. Ver [puerta-a.md](02-mvp/resultados/puerta-a.md).
- **Las fases 1 a 4 son planes vivos:** sus datos de partida son provisionales. Antes de ejecutar una fase, se revisa su plan con lo aprendido en la anterior.
- **Aprobación humana:** cada asset y cada puerta requieren la aprobación del responsable del proyecto. Los agentes no pueden aprobarlos.
- **Antes de hacer push, merge o publicar:** los agentes se detienen y preguntan.

## Pendiente de decidir

- [ ] Nombre definitivo del juego y comprobación de disponibilidad. Flip the Table es provisional.
- [ ] Móvil de referencia para las pruebas de rendimiento. Debía elegirse en la subfase 05; debe elegirse antes de la Puerta B (subfase 06), que lo necesita para medir 30 FPS.
- [ ] Consulta legal sobre la marca antes de publicar. Se hace en la subfase 10.
