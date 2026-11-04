# Ficha de fase: MVP

**Una sola ciudad, terminada al máximo nivel, para 2 a 8 amigos, que responde una pregunta: ¿un grupo de amigos pide la revancha al terminar?** Se recorta la variedad de contenido, nunca la calidad.

## Datos de la fase

| Campo | Valor |
| --- | --- |
| Puerta de entrada | Ficha general aprobada |
| Puerta de salida | Puerta C: todos los criterios de salida cumplidos |
| Fecha y presupuesto | Sin fijar; se publica cuando se cumple la lista |
| Quién aprueba | El responsable del proyecto |
| Probadores | Grupos de amigos primero; después, una prueba abierta pequeña |

## Alcance

| Área | Qué incluye | Subfases |
| --- | --- | --- |
| Mapa | Metrópolis, con 3 tamaños: 40, 48 y 56 casillas | 01, 05, 07 |
| Vistas | Cámara compartida de turno, minimapa y vista general en maqueta | 05, 07 |
| Reglas base | Dados, compra, renta, subasta, grupos, cinco pasos de construcción (tres casas, hotel y rascacielos), intercambios y bancarrota | 02 |
| Modos y final | Rondas, con últimas dos rondas de renta doble; Sin Fin en partidas privadas; podio en ambos | 02, 03, 04, 08, 09 |
| Cartas | 20 cartas, cada una con su escena; 5 legendarias con cinemática completa | 03, 08 |
| Perks | 12 perks, elegidos en 3 momentos de la partida | 03 |
| Casillas nuevas | Giro, Mercado Negro, Duelo, Portal, Cartelera de la Suerte y Tribunal, más la Zona Caliente | 03, 08 |
| Social | Pactos, traiciones, votos, emotes y premios del final | 03, 05, 09 |
| Remontada | Corona, Furia y Espectros | 03 |
| Fichas | Taxi, limusina, moto, deportivo, food truck, camión de helados, grúa y autobús | 07 |
| Personajes de escena | Policías, patrullas, multitud, obreros y grúas | 07 |
| Multijugador | Party privada con código, partidas públicas de 2 a 8 y revancha con un botón | 04 |
| Desconexiones | Un bot toma el turno de quien se va y el temporizador evita esperas | 04 |
| Dispositivos | PC y móvil, con interfaz propia para pantalla táctil | 05, 09 |
| Aprendizaje | Primera partida guiada con explicaciones cortas | 09 |
| Audio | Música del mapa, sonido de cada escena y ambiente de ciudad | 09 |

## Fuera de alcance

Un segundo mapa, modo de equipos, más de 8 jugadores, tienda, monetización, progresión entre partidas y movimiento libre por la ciudad.

## Subfases

| N.º | Subfase | Módulos principales | Depende de |
| --- | --- | --- | --- |
| 01 | [Cimientos](plan-01-cimientos.md) | Herramientas, `Rng`, `Types`, `config/Economy`, `config/Boards` | |
| 02 | [Motor de reglas](plan-02-motor-de-reglas.md) | `State`, `Board`, `Movement`, `Property`, `Auction`, `Building`, `Trade`, `Bankruptcy`, `Score`, `Turn`, `Engine`, `Bot` | 01 |
| 03 | [Dinámicas únicas](plan-03-dinamicas.md) | `Deck`, `Cards`, `Reaction`, `Perks`, `Squares`, `HotZone`, `Pact`, `Comeback`, `Awards` | 02 |
| 04 | [Red y partidas](plan-04-red-y-partidas.md) | `Protocol`, `View`, `MatchService`, `SceneClock`, `PresenceService`, `PartyService`, `PublicQueue`, `RematchService`, `Telemetry` | 03 |
| 05 | [Cliente jugable](plan-05-cliente-jugable.md) | `EventQueue`, `StateStore`, `CameraDirector`, `CityBuilder`, `TokenRider`, `Hud`, `SceneDirector` | 04 |
| 06 | [Base de arte](plan-06-base-de-arte.md) | Guía de estilo, tubería de Blender, `manifest`, porción vertical | 05 |
| 07 | [Ciudad y fichas](plan-07-ciudad-y-fichas.md) | Barrios, edificios, maqueta, 8 fichas, personajes | 06 |
| 08 | [Escenas](plan-08-escenas.md) | `SceneDirector` final y todas las escenas | 07 |
| 09 | [Interfaz, audio y aprendizaje](plan-09-interfaz-audio-aprendizaje.md) | `ui`, `AudioDirector`, `GuidedMatch`, `Lobby` | 05, 07 |
| 10 | [Pruebas y lanzamiento](plan-10-pruebas-y-lanzamiento.md) | Equilibrado, auditorías, cumplimiento, publicación | 08, 09 |

Las subfases 08 y 09 pueden avanzar en paralelo si no tocan los mismos archivos.

## Puertas

### Puerta A: las reglas divierten

Aplazada hasta tener una alpha, antes de la subfase 10 (decisión del responsable, 2026-11-04: «quiero omitir/modificar la puerta A. el mapa gris, poco detalle visual y seguramente bugs y mala gestion y diseño de HUD no deben ser pasados por encima por la puerta A. primero quiero tener una alpha, y luego testeo la puerta A»). Los criterios no cambian. Definición de alpha, provisional y pendiente de confirmar: el juego con el resultado de las subfases 06 a 09, en un lugar privado.

- [ ] 5 partidas completas de 4 a 8 jugadores con amigos, en PC y móvil.
- [ ] Turno medio de 20 s o menos, con las duraciones reales de escena.
- [ ] Al menos una vez, el grupo pidió la revancha sin que nadie lo sugiriera.
- [ ] Decisión escrita del responsable: seguir, ajustar reglas o replantear.

### Puerta B: nivel visual aprobado y fluido en móvil

Al terminar la subfase 06.

- [ ] El responsable aprueba la porción vertical como referencia de calidad.
- [ ] La porción se mantiene en 30 FPS o más en el móvil de referencia.

### Puerta C: abre la Fase 1

Al terminar la subfase 10: todos los criterios de salida.

## Criterios de salida

Propuesta inicial, medida en al menos 20 partidas con grupos de amigos y después en una prueba abierta pequeña.

- [ ] Al menos 70 % de las partidas iniciadas llegan al final.
- [ ] Al menos 40 % de los grupos juega una segunda partida seguida.
- [ ] Las partidas de 4 a 8 jugadores en modo Rondas duran de 25 a 35 minutos. Los objetivos se miden en ese modo.
- [ ] Quien lidera a mitad de partida gana como máximo 50 % de las veces.
- [ ] Ningún jugador dice haberse aburrido esperando, en al menos 80 % de las encuestas.
- [ ] La partida de 8 jugadores funciona fluida en un móvil de gama media (30 FPS o más en el móvil de referencia).
- [ ] Todos los assets publicados cumplen el estándar de calidad.

## Riesgos principales

| Riesgo | Control | Dónde se comprueba |
| --- | --- | --- |
| Turnos lentos | Duraciones máximas y medición con escenas provisionales | 05, 08, 10 |
| Rendimiento en móvil | Presupuestos de assets y pruebas desde la porción vertical | 06, 07, 10 |
| Huracán demasiado fuerte | Sin garantía ni límite por partida, en cualquier ronda y con compensación | 03, 10 |
| Avatares muy distintos | Pruebas con tamaños extremos | 07, 08 |
| Marca Monopoly | Identidad propia y consulta legal | 10 |
| Normas de azar de Roblox | Sin apuestas; revisión antes de publicar | 10 |

## Orden de recorte

Si hace falta recortar: el modo Sin Fin, fichas, escenas de cartas comunes, perks y los tableros de 56 y 48, en ese orden. La calidad de lo que queda no se recorta.
