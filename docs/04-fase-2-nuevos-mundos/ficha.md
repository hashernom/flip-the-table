# Ficha de fase 2: Nuevos mundos

**Convertir el juego en varios mundos, cada uno con su tema, sus reglas y sus escenas, y abrirlo a partys de 9 a 12.**

## Datos de la fase

| Campo | Valor |
| --- | --- |
| Puerta de entrada | Los grupos siguen pidiendo revancha |
| Puerta de salida | Los mapas nuevos traen de vuelta al grupo |
| Depende de | Fase 1 validada |
| Quién aprueba | El responsable del proyecto |

## Por qué ahora

Con la revancha asegurada, un mapa nuevo es la mejor razón para que un grupo vuelva otra semana. Por eso se añaden después de comprobar que el juego ya funciona con el contenido actual.

## Alcance

| Área | Qué incluye |
| --- | --- |
| Isla Pirata | La marea sube y deja sin servicio las casillas de la costa. Escena estrella: un kraken arrastra un barco a la bahía |
| Estación Espacial | Un fallo de gravedad invierte el sentido de la ruta. Escena estrella: una lluvia de meteoritos golpea los módulos |
| Marco de mapas | Cada mapa define tema, regla propia, mazo, escenas y música sin modificar el motor base |
| Partys de 9 a 12 | Una ciudad con más barrios y turnos más cortos |
| Elección de mapa | El anfitrión elige o el grupo vota |

## Fuera de alcance

Progresión, pase de temporada y torneos.

**Reino Embrujado** queda como candidato: los espectros son más fuertes de noche y un dragón incendia un barrio. Se construye solo si los datos de esta fase lo justifican.

## Módulos

| Módulo | Responsabilidad |
| --- | --- |
| `config/maps/*` | Definición de cada mapa |
| `rules/MapRules` | Punto de conexión de las reglas propias |
| `rules/maps/Tide`, `rules/maps/GravityFlip` | Reglas de cada mapa |
| `config/Boards` | Tamaños XL para 9 a 12 jugadores, por mapa |
| `server/lobby/MapVote` | Elegir o votar el mapa |
| `client/world/MapLoader` | Cargar solo el mapa elegido |
| `client/scenes/maps/*` | Escenas propias de cada mapa |

## Subfases

| N.º | Subfase | Resultado |
| --- | --- | --- |
| 2.1 | Marco de mapas | Metrópolis migrada, sin cambios de comportamiento |
| 2.2 | Partys de 9 a 12 | Motor, red y turnos preparados |
| 2.3 | Isla Pirata | Mapa completo y aprobado |
| 2.4 | Estación Espacial | Mapa completo y aprobado |
| 2.5 | Elección de mapa | Votación en el lobby |
| 2.6 | Validación | Puerta de salida medida |

## Criterios de aceptación de la fase

Valores provisionales; se confirman con los datos de la Fase 1.

- [ ] Los grupos que vuelven en un plazo de 7 días aumentan al menos 20 % respecto a antes de los mapas.
- [ ] Cada mapa nuevo representa al menos 25 % de las partidas 4 semanas después de salir.
- [ ] La partida de 12 jugadores dura de 25 a 35 minutos y mantiene 30 FPS o más en el móvil de referencia.
- [ ] En 12 jugadores, al menos 80 % de las encuestas no menciona aburrimiento por la espera.
- [ ] Metrópolis sigue pasando todas sus pruebas después de la migración.
- [ ] Todo asset nuevo cumple el estándar y está aprobado.

## Riesgos

| Riesgo | Control |
| --- | --- |
| Una regla propia desequilibra un mapa | Simulaciones por mapa y pruebas con amigos antes de la producción final |
| Con 12 jugadores, la espera se hace larga | Turnos más cortos, escenas más breves y más acciones fuera de turno |
| El coste de arte de cada mapa es alto | Primero la porción vertical de cada mapa; se aprueba antes de producir el resto |
| Cargar varios mapas pesa demasiado | Cargar solo el mapa elegido, en un lugar propio si hace falta |
