# Ficha de fase 1: Más partidas

**Dar más razones para volver a jugar con el mismo grupo: modo de equipos, más contenido, reglas de la casa y la primera tienda de cosméticos.**

## Datos de la fase

| Campo | Valor |
| --- | --- |
| Puerta de entrada | El MVP cumple sus objetivos (Puerta C) |
| Puerta de salida | Los grupos siguen pidiendo revancha |
| Depende de | MVP publicado y sus datos reales |
| Quién aprueba | El responsable del proyecto |

## Por qué ahora

El MVP demuestra que un grupo pide la revancha. Esta fase hace que esa revancha no se repita siempre igual y empieza a financiar el juego sin tocar la partida.

## Alcance

| Área | Qué incluye |
| --- | --- |
| Modo de equipos | 2 contra 2 o 4 contra 4, con dinero compartido y cartas de equipo |
| Más cartas | 10 cartas nuevas y 3 cartas de equipo (cantidad provisional) |
| Más perks y casillas | 4 perks y 2 casillas nuevas (cantidad provisional) |
| Más fichas | 8 fichas de edición especial, cosméticas |
| Reglas de la casa | El grupo decide rondas, cartas activas y nivel de caos |
| Tienda de cosméticos | Fichas, estelas, escenas de victoria, animaciones, emotes, reacciones y estilos de edificios |

## Fuera de alcance

Mapas nuevos, más de 8 jugadores, progresión entre partidas y pase de temporada.

## Módulos

| Módulo | Responsabilidad |
| --- | --- |
| `rules/Teams` | Equipos, dinero compartido y victoria por equipo |
| `config/GameModes` y `rules/HouseRules` | Modos y reglas de la casa |
| `config/Cards`, `config/Perks` y `config/Squares` | Contenido nuevo |
| `config/Catalog` | Catálogo de cosméticos, sin efecto en las reglas |
| `server/store/PurchaseService` | Compras idempotentes |
| `server/store/Inventory` | Cosméticos de cada jugador |
| `client/ui/Store`, `client/world/CosmeticApplier` | Tienda y aplicación visual |

## Subfases

| N.º | Subfase | Resultado |
| --- | --- | --- |
| 1.1 | Modo de equipos | Partidas por equipos, jugables y equilibradas |
| 1.2 | Contenido nuevo | Cartas, perks y casillas con escena propia |
| 1.3 | Reglas de la casa | Partidas configurables por el grupo |
| 1.4 | Inventario y tienda | Compras seguras de cosméticos |
| 1.5 | Producción de cosméticos | Primer catálogo aprobado |
| 1.6 | Validación | Puerta de salida medida |

## Criterios de aceptación de la fase

Valores provisionales; se confirman con los datos del MVP.

- [ ] Al menos 40 % de los grupos sigue jugando una segunda partida seguida, durante 4 semanas.
- [ ] Al menos 20 % de las partidas privadas usa equipos o reglas de la casa.
- [ ] El modo de equipos cumple la duración de 25 a 35 minutos.
- [ ] Ningún cosmético da ventaja, y una prueba automática lo comprueba.
- [ ] Ninguna compra es aleatoria; ninguna se pierde ni se cobra dos veces.
- [ ] Todo asset nuevo cumple el estándar y está aprobado.

## Riesgos

| Riesgo | Control |
| --- | --- |
| Dinero compartido y traición no combinan | Pactos limitados a equipos rivales y prueba temprana con amigos |
| Demasiadas opciones confunden | Reglas de la casa con ajustes preparados y valores por defecto |
| La tienda se percibe como pagar para ganar | Solo apariencia; las cartas y los perks nunca se venden |
| Normas sobre compras y menores | Revisar la documentación vigente antes de implementar |
