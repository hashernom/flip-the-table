# Ficha de fase 4: Comunidad

**Hacer que el juego viva fuera de cada partida: temporadas con novedades, eventos especiales, torneos entre grupos y clips para compartir.**

## Datos de la fase

| Campo | Valor |
| --- | --- |
| Puerta de entrada | La progresión aumenta el regreso de jugadores |
| Puerta de salida | Fase continua; se revisa cada temporada |
| Depende de | Fases 1 a 3 validadas |
| Quién aprueba | El responsable del proyecto |

## Por qué ahora

Con varios mapas y progresión, el juego puede sostener un calendario. Los clips y los torneos llevan a nuevos grupos, porque los momentos de traición y ruina son lo que más apetece enseñar.

## Alcance

| Área | Qué incluye |
| --- | --- |
| Temporadas | Calendario, novedades y pase por temporada |
| Eventos | Reglas o escenas especiales por tiempo limitado |
| Torneos entre grupos | Formato por rondas, con partidas privadas y resultados |
| Clips para compartir | Guardar los mejores momentos de cada partida |

## Fuera de alcance

Premios con valor real, ligas profesionales y contenido creado por jugadores. Se reconsideran con datos.

## Módulos

| Módulo | Responsabilidad |
| --- | --- |
| `config/LiveCalendar` | Temporadas y eventos programados |
| `rules/EventRules` | Reglas especiales de un evento |
| `server/tournament/Bracket` | Rondas y clasificación |
| `server/tournament/TournamentService` | Crear torneos y reunir a los grupos |
| `rules/Highlights` | Elegir los mejores momentos a partir de eventos |
| `client/ui/Highlights` | Revivir y compartir momentos |

## Subfases

| N.º | Subfase | Resultado |
| --- | --- | --- |
| 4.1 | Calendario en vivo | Temporadas y eventos sin publicar código |
| 4.2 | Eventos | Primer evento completo |
| 4.3 | Torneos entre grupos | Torneo de principio a fin |
| 4.4 | Clips | Mejores momentos para revivir y compartir |
| 4.5 | Operación | Rutina y métricas de cada temporada |

## Criterios de aceptación de la fase

Valores provisionales; se confirman con los datos de la Fase 3.

- [ ] Al menos 30 % de los jugadores activos juega durante un evento.
- [ ] Una nueva temporada aumenta las partidas diarias, comparando las 2 semanas anteriores y posteriores.
- [ ] Un torneo de 8 grupos termina sin intervención manual.
- [ ] Al menos 10 % de las partidas genera un momento que alguien guarda o comparte.
- [ ] Los clips no muestran nombres ocultos ni manos de otros jugadores.
- [ ] Todo asset nuevo cumple el estándar y está aprobado.

## Riesgos

| Riesgo | Control |
| --- | --- |
| Los torneos fomentan juego sucio | Abandonar cuenta como derrota, con bot en su lugar; sin premios con valor real |
| Trabajo constante | Eventos reutilizables y calendario de datos |
| Privacidad de los clips | Compartir siempre es una decisión del jugador; revisar las normas vigentes |
| Competición en un juego con azar alto | Torneos al mejor de varias partidas y puntos acumulados |
