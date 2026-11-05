# Cierre de la subfase 07 (ciudad y fichas)

**Rama:** `plan-07-ciudad-y-fichas`. **Fecha:** 2026-11-05. **Estado:** código y arte integrados;
quedan las verificaciones que necesitan dos jugadores o el móvil, y la aprobación del responsable.

## Tareas del plan

| Tarea | Estado | Evidencia | Pendiente |
| --- | --- | --- | --- |
| 1. Trazado de barrios | A medias | Ciudad, puentes, mobiliario y las 34 propiedades; capturas de la porción vertical | Captura de la ruta completa en S/M/L y aprobación |
| 2. Propiedades por zona | Casi | 34 propiedades modeladas; 32 entradas de propiedad en el manifiesto, todas `Approved` o `InGame` | 13 capturas de propiedad y la prueba de cámara a nivel 5 |
| 3. Casillas especiales | Código hecho | 8 lugares, iconos y capturas en Studio; Zona Caliente con banda y contorno; revisión de la tarea aprobada | Captura real con 2 jugadores y aprobación |
| 4. Maqueta | Código hecho | Plinto, miniatura, tarjetas, marcadores y cámara; revisión aprobada tras corregir la clave, el clon y el foco | Medir < 1 s y verla en Studio |
| 5. Ocho fichas | Código hecho | Elección con intercambio, animaciones y avatares extremos; revisión aprobada | Prueba en partida real y aprobación |
| 6. Actores de escena | Código hecho | `Actors.spawn/despawn/pose`, pool y 20 pruebas; revisión aprobada tras corregir los seis importantes | Prueba de 100 ciclos en Studio y aprobación |
| 7. Rendimiento | Abierta | Check de partes temporales y manifiesto | Medición de 8 jugadores en móvil, omitida por el responsable; ver [rendimiento-ciudad.md](rendimiento-ciudad.md) |

## Lo que está verificado

- Las 8 fichas, las 8 casillas y los 5 actores cargan en Studio con `InsertService`.
- Los iconos de las casillas se subieron con moderación `Approved` y se probó el `Decal`.
- El Portal y la grúa de obra corregida se subieron y están registrados.
- `tools/check` en verde sobre el árbol final (formato, lint, tipos, mapas, pruebas, motor puro, reloj y
  manifiesto).
- Capturas de apoyo en `art/render/ingame/`: fichas, casillas, avatares extremos y Zona Caliente.
  Las de partida real siguen pendientes porque la partida exige 2 jugadores.

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
