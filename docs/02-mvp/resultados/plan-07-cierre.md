# Cierre de la subfase 07 (ciudad y fichas)

**Rama:** `plan-07-ciudad-y-fichas`. **Fecha:** 2026-11-05. **Estado:** código y arte integrados;
quedan las verificaciones que necesitan dos jugadores o el móvil, y la aprobación del responsable.

## Tareas del plan

| Tarea | Estado | Evidencia | Pendiente |
| --- | --- | --- | --- |
| 1. Trazado de barrios | A medias | Ciudad, puentes, mobiliario y las 34 propiedades; capturas de la porción vertical | Captura de la ruta completa en S/M/L y aprobación |
| 2. Propiedades por zona | Casi | 34 propiedades modeladas; 32 entradas de propiedad en el manifiesto, todas `Approved` o `InGame` | 13 capturas de propiedad y la prueba de cámara a nivel 5 |
| 3. Casillas especiales | Código hecho | 8 lugares, iconos re-subidos como imágenes y verificados; Zona Caliente con banda y contorno; capturas sintéticas; revisión aprobada | Captura real con 2 jugadores y aprobación |
| 4. Maqueta | Código hecho | Plinto, miniatura, tarjetas, marcadores y cámara; revisión aprobada; **apertura medida en 0,036 s** | Captura real con 2 jugadores y aprobación |
| 5. Ocho fichas | Código hecho | Elección con intercambio, animaciones y avatares extremos; revisión aprobada | Prueba en partida real y aprobación |
| 6. Actores de escena | Código hecho | `Actors.spawn/despawn/pose`, pool y 20 pruebas; revisión aprobada; **100 ciclos por tipo en Studio sin fallos** | Aprobación |
| 7. Rendimiento | Abierta | Check de partes temporales y manifiesto | Medición de 8 jugadores en móvil, omitida por el responsable; ver [rendimiento-ciudad.md](rendimiento-ciudad.md) |

## Lo que está verificado

- Las 8 fichas, las 8 casillas y los 5 actores cargan en Studio con `InsertService`.
- Los iconos se re-subieron como **imágenes** (los `Decal` anteriores no servían como `Texture`) y se
  verificaron en la ciudad: se ven las siluetas de Salida, Giro, Mercado, Duelo, Portal, Cartelera,
  Tribunal e Impuesto.
- El Portal y la grúa de obra corregida se subieron y están registrados.
- `tools/check` en verde sobre el árbol final (formato, lint, tipos, mapas, pruebas, motor puro, reloj y
  manifiesto).
- **Maqueta medida en Studio Play**: `ModelCity.show` tarda **0,036 s** la primera vez (ciudad ya
  construida) y **0,0001 s** al repetir; `focus` (200, 27,6, 200), `radius` 142, Zona Caliente `cobre`.
  Captura en `art/render/ingame/maqueta-ciudad.jpg`.
- Capturas en `art/render/ingame/`: `ciudad-turno.jpg` y `zonacaliente-ciudad.jpg` (ciudad real
  construida por `CityBuilder` con una vista sintética en Studio Play), además de fichas, casillas,
  avatares extremos y Zona Caliente. **No son de una partida de 2 jugadores**: eso sigue pendiente.
- **Actores, 100 ciclos por tipo** (Studio Play, Rojo sincronizado a esta rama): 8 tipos × 100
  `spawn`/`despawn`, **0 fallos**, 0 modelos activos al final, `Actors.clear()` deja 0 y el heap de
  Lua queda en 6,2 MB. Resultado del 2026-11-05.

## Lo que falta para la puerta

1. Partida de 2 jugadores en Studio: capturas de ciudad, fichas y casillas.
2. Medición de rendimiento en el móvil de referencia (omitida en esta sesión por decisión del
   responsable).
3. Aprobación del responsable por tarea; los assets siguen en `Draft` y nada se marcó `InGame` ni
   `Approved`.
4. Revisión final de la rama y decisión de merge.

## Cómo seguir

- Los commits están en la rama `plan-07-ciudad-y-fichas`; no hay merge a `main`.
- Para regenerar los paquetes de revisión y el estado del trabajo: `.superpowers/sdd/plan-07-ciudad-y-fichas/`.
- Para arte: `art/PIPELINE.md` y `art/blender/tokens/README.md`.
- Para el mapa de la ciudad: `src/shared/config/CityLayout.luau` y `src/client/world/CityBuilder.luau`.
