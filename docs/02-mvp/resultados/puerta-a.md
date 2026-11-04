# Puerta A: las reglas divierten

> **Estado: sin cerrar.** Esta puerta la decide el responsable con partidas reales. Un agente puede
> preparar el prototipo, medir y escribir lo que salga, pero no puede jugar ni decidir. Todo lo que
> hay debajo de «Datos pendientes» está vacío a propósito.

La Puerta A se abre al terminar la subfase 05, con arte gris y en un lugar privado. Responde una sola
pregunta: **¿un grupo de amigos pide la revancha al terminar?**

## Criterios

| Criterio | Cómo se mide | Estado |
| --- | --- | --- |
| El responsable elige el móvil de referencia | Una decisión escrita | **Pendiente** |
| 5 partidas completas de 4 a 8 jugadores con amigos, en PC y móvil | Registro de cada sesión | **Pendiente** |
| Turno medio de 20 s o menos, con las duraciones reales de escena | `lune run tools/criteria-report` sobre `telemetry/` | **Pendiente** (solo hay partidas simuladas) |
| Al menos una vez, el grupo pidió la revancha sin que nadie lo sugiriera | Se apunta en la sesión, sin preguntarlo | **Pendiente** |
| Decisión escrita del responsable: seguir, ajustar reglas o replantear | Este documento | **Pendiente** |

## Qué está listo

- El prototipo gris tiene menús para comprar, pujar, construir, cartas, perks, tratos, pactos, votos,
  duelos, mercado y turno de espectro, pero **todavía no se puede jugar de principio a fin**: la
  [segunda auditoría](../../../auditoria/auditoria-2026-11-04-segunda-pasada.md) encontró botones sin
  distinguir y puja rota (B4, B5, B6 y B8), pendientes del rediseño de la interfaz.
- Todo el grupo ve la misma escena, con las duraciones reales de `config/Scenes`, y una escena nunca
  se interrumpe con la vista general.
- Primera persona sobre la ficha, vista general con un botón, sin movimiento libre, emotes con botón.
- Cada partida deja un resumen en `telemetry/` (sin datos personales) y `tools/criteria-report` calcula
  los cuatro criterios medibles solo con partidas en modo Rondas.

## Qué falta antes de jugar

1. **Publicar el prototipo en un lugar privado.** El plan 04 dejó la publicación pendiente por
   decisión del responsable: `config/Places` vale `0` y sin lugar el lobby no teletransporta. Hace
   falta permiso explícito para publicar en **privado**.
2. **Elegir el móvil de referencia** para las pruebas de rendimiento y de pantalla táctil.
3. **Reunir los grupos.** Esta parte no la puede hacer un agente: hacen falta entre 4 y 8 personas por
   sesión y al menos 5 sesiones.
4. **Sondear sin preguntar.** El criterio de la revancha solo vale si nadie la sugiere; se apunta si
   ocurre, no se provoca.

## Cómo se mide

Tras cada sesión:

```text
lune run tools/criteria-report
```

Después, a cada jugador, tres preguntas y ninguna más:

1. ¿Qué fue lo más divertido?
2. ¿Cuándo te aburriste?
3. ¿Jugarías otra?

Y se apunta, sin adornos: jugadores, tamaño de tablero, duración, turno medio, si alguien propuso la
revancha por su cuenta y la respuesta textual a las tres preguntas.

## Datos de partidas simuladas (no cuentan para la puerta)

Hay resúmenes de partidas jugadas por bots en `telemetry/`. Sirven para comprobar que la tubería de
medición funciona y como referencia de equilibrio, **no** como resultado de la Puerta A. Con la
telemetría de ejemplo, el informe da:

- Partidas terminadas: 75 % (6 de 8 en modo Rondas).
- Segunda partida: 33,3 %.
- Duración media: 30,4 min en 5 partidas de 4 a 8 jugadores.
- Líder a mitad que acaba ganando: 40 % de 5 partidas con líder conocido.

Son cifras de bots. La ficha pide partidas de amigos.

## Decisión del responsable

**Sin escribir.** Cuando haya jugado los grupos, aquí va una de estas tres, con el motivo:

- [ ] Seguir: las reglas divierten y se pasa a la subfase 06 (base de arte).
- [ ] Ajustar reglas: se anota qué se cambia en `config` y se repite la prueba.
- [ ] Replantear: no divierte y se revisa el diseño antes de gastar en arte.

Sin esta decisión escrita no empieza el plan 06.
