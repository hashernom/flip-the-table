# Puerta B: referencia de calidad

> **Estado: aprobada por el responsable el 2026-11-05.** Se aprobó sabiendo que los puntos de abajo quedan sin medir o sin comprobar.

## Pregunta de la puerta

¿La porción vertical es la referencia de calidad con la que se hace la ciudad completa?

## Qué se presenta

| Pieza | Estado | Dónde verlo |
| --- | --- | --- |
| Calle con casillas de pintura, isla y esquinas | En el juego | `src/client/world/CityBuilder.luau` |
| Barbería Morro, Callejón del Hojalatero y mojón | Aprobados el 2026-11-05 | `art/render/ingame/` |
| Cine Lux y Bodega La Reserva | En el juego, sin aprobar en el manifiesto | `art/manifest.json` |
| Ficha taxi con avatar de pie | En el juego | Partida |
| Escena de arresto de 15 s, con vuelta al mapa | En el juego | Partida |
| Luz, sombras y sonido de ambiente | En el juego | Partida |
| Blueprint y prompt del modelado | Listos | `art/edificios/` |

## Criterios

| Criterio | Resultado |
| --- | --- |
| Cada asset cumple el estándar de la ficha | Solo revisados los tres aprobados |
| El responsable compara capturas y video en PC | Capturas revisadas durante la sesión; aprobada |
| 30 FPS o más con 8 fichas en PC | **Sin medir:** el responsable pidió omitirlo el 2026-11-05 |
| Aceptable con el nivel gráfico mínimo | **Sin comprobar** |
| Memoria del cliente registrada | **Sin medir:** mismo motivo |

## Sin comprobar o con riesgo

- **Carga en un lugar publicado:** no se ha probado, porque publicar lo decide el responsable.
- **Rendimiento:** pasa al plan 07, medido con la ciudad completa.
- **Audio de ProSoundEffects:** Roblox lo ofrece como audio gratuito de su biblioteca, pero no se localizó el texto exacto de su licencia. Hay que leer el acuerdo antes de publicar.
- **Consulta legal:** el marco de las casillas se inspira en un tablero de juego de mesa, y las casitas de la isla también. Hay que incluirlos.
- **Callejón del Hojalatero:** aprobado, pero `check_property.py` marca que su nivel 1 y siguientes llegan a `y = -12,7` y su nivel 4 a 18,2 del centro. Se puede quedar así o retocar.

## Decisión

Aprobada por Santiago el 2026-11-05. La porción es la referencia de calidad del plan 07.
