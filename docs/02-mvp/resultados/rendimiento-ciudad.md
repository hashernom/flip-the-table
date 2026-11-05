# Rendimiento de la ciudad (plan 07, Tarea 7)

**Estado: medición pendiente.** El responsable decidió el 2026-11-05 no hacer la prueba de rendimiento
en esta sesión, así que el criterio «30 FPS o más en el móvil de referencia con 8 jugadores» sigue
abierto. Este documento deja el método y lo que sí se comprobó, para no confundir «no medido» con
«cumple».

## Lo que sí se comprobó

- `tools/manifest` rechaza un `Part` marcado como temporal (`SetAttribute("Temporary", true)`) y
  cualquier `rbxassetid://` de `src/` que no esté en el manifiesto. Tiene prueba de positivo y negativo.
- Presupuesto de las piezas nuevas: ninguna ficha pasa de 2 868 triángulos, ninguna casilla de 2 944 y
  ningún actor de 2 716; todos por debajo de los topes del manifiesto.
- La maqueta no se reconstruye por fotograma: el plinto y la miniatura se cachean, y la vista general
  solo se actualiza cuando cambia la vista o el modelo.

## Lo que falta medir

1. Partida de 8 jugadores en la ciudad de 56 casillas, en el móvil de referencia.
2. FPS sostenidos durante 60 s: media y percentil 5, con el peor caso (todos los edificios a nivel 5).
3. Memoria del cliente antes y después de abrir y cerrar la vista general cinco veces.
4. Tiempo de apertura de la maqueta (criterio: menos de 1 s).
5. Coste de la ciudad duplicada mientras la maqueta está abierta.

## Cómo medirlo

- Abrir la partida con 8 jugadores (servidor local o el móvil de referencia) en la ciudad L.
- Poner las 34 propiedades a nivel 5 con el script de Studio que ya usa la Tarea 2.
- Grabar con el MicroProfiler y anotar `FrameTime` medio y p95 durante 60 s, con la maqueta cerrada y
  abierta.
- Anotar `Stats.Memory` del cliente antes y después de cinco aperturas/cierres.
- Rellenar esta tabla y adjuntar la captura del MicroProfiler.

| Escenario | FPS medio | FPS p5 | Memoria | Notas |
| --- | --- | --- | --- | --- |
| Ciudad L, 8 jugadores, maqueta cerrada | pendiente | pendiente | pendiente | |
| Ciudad L, 8 jugadores, maqueta abierta | pendiente | pendiente | pendiente | |

Hasta que esta tabla esté llena, la Tarea 7 no se puede dar por cerrada.
