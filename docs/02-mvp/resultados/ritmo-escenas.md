# Ritmo de las escenas (plan 08, Tarea 7)

**Fecha:** 2026-11-06. **Fuente:** `lune run tests/sim-report`: 700 partidas de bots, 50 semillas por número de jugadores y modo.

`Sim.play` suma los segundos de escena de cada evento con `Scenes.durationFor`, igual que el cliente. Las repeticiones de un mismo tipo se acortan, pero los dados nunca bajan de 1,4 s. No cuenta el tiempo de decisión: los bots juegan al instante. El turno real es la escena más lo que tarda cada persona en decidir, con el plazo de `Economy.seconds`.

## Segundos de escena por turno

| Jugadores | Escena por turno |
|---|---|
| 2 | 7,0 s |
| 3 | 6,4 s |
| 4 | 6,0 s |
| 5 | 5,4 s |
| 6 | 5,2 s |
| 7 | 4,9 s |
| 8 | 4,3 s |

| Tamaño | Modo Rondas | Modo Sin Fin |
|---|---|---|
| S (2 a 4) | 7,4 s | 6,1 s |
| M (5 y 6) | 6,9 s | 5,1 s |
| L (7 y 8) | 6,8 s | 4,4 s |

Con 8 jugadores, las escenas se llevan unos 4,3 s de cada turno. Para llegar al objetivo de 20 s de turno medio quedan unos 15 s de decisión.

## Variaciones

Variaciones, con la elección fijada por `Scenes.variationFor`: es igual para todo el grupo.

| Escena | Variación 1 | Variación 2 |
|---|---|---|
| Dados | Se lanzan desde la ficha | Caen del cielo |
| Renta | Las monedas vuelan al edificio | Un billete gigante cruza la calle |
| Construcción | Llega una grúa con gancho | El añadido cae del cielo y bota |
| Compra | Cartel «Comprada» | Cartel «¡Es de …!» con el color del asiento |

## Pendiente de medir con el responsable

- Diferencia entre los 8 clientes de una partida (objetivo: menos de 250 ms).
- FPS de Huracán en el móvil de referencia (objetivo: 30 o más). El trabajo de móvil está aplazado al final.
- Turno medio con personas reales, incluidas las decisiones.
