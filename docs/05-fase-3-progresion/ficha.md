# Ficha de fase 3: Progresión

**Dar a cada jugador y a cada grupo algo que crece entre partidas, sin cambiar lo que pasa dentro de ellas.**

## Datos de la fase

| Campo | Valor |
| --- | --- |
| Puerta de entrada | Los mapas nuevos traen de vuelta al grupo |
| Puerta de salida | La progresión aumenta el regreso de jugadores |
| Depende de | Fase 2 validada y tienda de la Fase 1 |
| Quién aprueba | El responsable del proyecto |

## Por qué ahora

Una progresión funciona cuando el juego ya apetece por sí mismo. Añadirla antes solo disimularía un problema de diversión.

## Alcance

| Área | Qué incluye |
| --- | --- |
| Niveles | Experiencia por jugar y un nivel visible |
| Misiones | Diarias y semanales, con misiones de grupo |
| Colecciones | Conjuntos de cosméticos que se completan jugando |
| Pase de temporada | Recompensas cosméticas ligadas a misiones de grupo |

## Regla principal

**El nivel nunca da ventaja.** Un jugador nuevo y uno veterano empiezan cada partida con lo mismo. Las recompensas son cosméticas; las cartas y los perks no se desbloquean ni se compran.

## Fuera de alcance

Torneos, temporadas competitivas y clips.

## Módulos

| Módulo | Responsabilidad |
| --- | --- |
| `server/profile/ProfileStore` | Datos persistentes por jugador |
| `shared/progression/Levels` | Experiencia y niveles |
| `shared/progression/Missions` | Progreso de misiones a partir de eventos |
| `shared/progression/Collections` | Conjuntos y recompensas |
| `shared/progression/SeasonPass` | Niveles del pase y recompensas |
| `client/ui/Progress` | Pantallas de progreso |
| `client/scenes/game/PostMatchRewards` | Recompensas tras el podio |

## Subfases

| N.º | Subfase | Resultado |
| --- | --- | --- |
| 3.1 | Perfil persistente | Datos seguros, también ante fallos |
| 3.2 | Niveles y misiones | Progreso a partir de eventos reales |
| 3.3 | Colecciones | Conjuntos y recompensas |
| 3.4 | Pase de temporada | Primer pase con cosméticos |
| 3.5 | Validación | Puerta de salida medida |

## Criterios de aceptación de la fase

Valores provisionales; se confirman con los datos de la Fase 2.

- [ ] La retención a 7 días aumenta al menos 15 % respecto a antes de la fase.
- [ ] Al menos 30 % de las partidas de grupo avanza una misión de grupo.
- [ ] La tasa de segunda partida no baja respecto a la Fase 2.
- [ ] Nada de la progresión cambia las reglas, y una prueba automática lo comprueba.
- [ ] Ningún progreso se pierde ante una caída del servidor durante las pruebas.
- [ ] Todo asset nuevo cumple el estándar y está aprobado.

## Riesgos

| Riesgo | Control |
| --- | --- |
| Las misiones empujan a jugar mal | Misiones que premian jugar y divertirse, no perjudicar al grupo |
| Pérdida de datos | Guardado con reintentos y sesión bloqueada; pruebas de fallo |
| Presión sobre menores | Sin cuentas regresivas agresivas; revisar las normas vigentes |
| El pase parece pagar para ganar | Solo cosméticos |
