# Plan 09: inventario de la interfaz

**El plan 9 no cierra mientras quede una fila sin hacer: ninguna parte de la interfaz se queda en gris.** Lo pidió el responsable el 2026-11-05. Cada fila necesita diseño, animación y función, y su casilla solo se marca con la aprobación del responsable, viéndola en el juego.

Las duraciones y curvas exactas se fijan al construir y viven en `config/Ui`. Las transiciones de interfaz son breves y nunca retrasan la partida.

## Superficies

| Superficie | Módulo | Estados que debe cubrir | Animación | Hecho |
| --- | --- | --- | --- | --- |
| Lobby | `LobbyMenu`, `LobbyScene` | Sin party, en party, anfitrión e invitado, en cola, cada error | Entrada de placas; código que se copia; jugador que entra o sale | [ ] |
| Elegir ficha | `LobbyMenu` | Libre, tuya, de otro. Con el nombre hasta tener imágenes (plan 7) | Selección y ficha ocupada | [ ] |
| Modo de partida | `LobbyMenu` | Rondas o Sin Fin, solo el anfitrión, con su frase | Cambio de selección | [ ] |
| Placas de la mesa | `Hud` | Con turno, activo, espectro, se fue, bot; Corona, Traidor, Furia, cartas, pierde turno | Paso de turno; marca que aparece o se va; orden que cambia | [ ] |
| Dinero | `Hud` | Sube, baja, sin cambio | Contador que rueda, con importe flotante de ganancia o pérdida | [ ] |
| Barra de ronda y plazo | `Hud` | Ronda, Última Ronda, Sin Fin, sin plazo, plazo que se agota | Línea que se consume; aviso al final | [ ] |
| Botón de acción | `ActionMenu` | Normal, encima, pulsado, deshabilitado, esperando respuesta | Pulsación y salida | [ ] |
| Tirar dados | `ActionMenu` | Tirar, repetir un dado, mover con lo sacado | Pulsación que da paso a la escena | [ ] |
| Comprar propiedad | `ActionMenu`, `Card` | Escritura, se puede pagar o no, Descuento | Sube la escritura; al comprar se sella y vuela a tus propiedades | [ ] |
| Subasta | `ActionMenu` | Sin pujas, puja propia, te superan, sin dinero, fin | Puja que entra; reloj de 15 s | [ ] |
| Construir | `ActionMenu` | Lista de casillas, coste, sin dinero, nivel máximo | Sube de nivel en la escritura | [ ] |
| Mano y cartas | `Card` | Dorso, abierta, jugable o no, elegir objetivo, mano llena, descartar | Robar, abrir, jugar y descartar | [ ] |
| Reacción | `ActionMenu` | Puede reaccionar, otro reacciona, ventana de 5 s | Entrada urgente; ventana que se cierra | [ ] |
| Perks | `ActionMenu` | Elegir 1 de 3, esperar a otros, perks visibles en la mesa | Reparto y elección | [ ] |
| Tratos | `TradeMenu` | Proponer, enviada, recibida, aceptada, rechazada, inválida | Abrir y cerrar; elementos que cruzan al aceptar | [ ] |
| Pactos | `PactMenu` | Proponer, recibido, activo, romper con segunda confirmación, roto | Abrir y cerrar; sello al firmar; marca de Traidor | [ ] |
| Tribunal | `ActionMenu` | Votar, acusado, Soborno, veredicto | Votos y veredicto | [ ] |
| Duelo | `ActionMenu` | Elegir rival, jugada secreta, esperar, empate, resultado | Revelación de jugadas | [ ] |
| Mercado Negro | `ActionMenu` | Tres cartas, precio, sin dinero, saltar | Reparto y compra | [ ] |
| Portal y Cartelera | `ActionMenu` | Elegir destino; resultado de la Cartelera | Selección y aviso de resultado | [ ] |
| Turno de espectro | `ActionMenu` | Sabotear, embrujar, progreso de resurrección | Progreso que se llena | [ ] |
| Minimapa | `MiniMap` | Color, dueño, nivel, fichas, turno, Zona Caliente, efectos | Ficha que avanza; cambio de dueño | [ ] |
| Detalle de casilla | `MiniMap` | Propiedad y especial, libre o con dueño, sin mover la cámara | Abrir y cerrar | [ ] |
| Menú del juego | `Overview` | Dueños, dinero, posiciones, efectos, rondas, sin escena en curso | Abrir y cerrar; datos que entran | [ ] |
| Ajustes | Nuevo | Música, efectos, atajos | Abrir, cerrar y deslizadores | [ ] |
| Emotes | `Hud` | Abierta, cerrada, burbuja propia y ajena, límite de frecuencia | Abrir; burbuja que sube y se va | [ ] |
| Avisos | `Hud` | Información, aviso, pérdida, acción rechazada, desconexión, bot al mando | Entrada y salida | [ ] |
| Eventos de la partida | `Hud`, `SceneDirector` | Título de cada evento, durante la escena la interfaz se reduce | Entrada y salida del título; interfaz que se aparta y vuelve | [ ] |
| Última Ronda | `Hud` | Aviso, renta doble visible | Entrada del aviso | [ ] |
| Podio y revancha | `RematchMenu` | Ganador, clasificación, premios, votar, esperar, cancelada | Entrada por puestos; premios; votos | [ ] |
| Primera partida guiada | `GuidedMatch` | Cada consejo una vez, sin detener ni obligar a cerrar | Entrada y salida | [ ] |

## Eventos del motor que la interfaz debe acusar

Ningún evento pasa sin respuesta visible. La escena grande es del plan 8; aquí se hace lo que la interfaz dice de él.

| Evento | Qué dice la interfaz | Hecho |
| --- | --- | --- |
| `RoundStarted`, `FinalRoundsStarted` | Ronda nueva; aviso de Última Ronda | [ ] |
| `PerkDrafted` | Perk nuevo en la placa | [ ] |
| `DiceRolled`, `TokenMoved`, `PassedStart`, `PortalUsed` | Dados, recorrido y cobro de la Salida | [ ] |
| `PropertyBought`, `AuctionStarted`, `AuctionWon`, `AuctionNoSale` | Sello de compra; subasta y su resultado | [ ] |
| `RentPaid` | Dinero que pasa de una placa a otra | [ ] |
| `BuildingChanged` | Nivel en minimapa y escritura | [ ] |
| `TradeCompleted`, `PactFormed`, `PactEnded`, `PactBroken` | Trato cerrado; pacto firmado, terminado o roto | [ ] |
| `PlayerArrested`, `TribunalVerdict` | Arresto y veredicto | [ ] |
| `BankruptcyDeclared`, `GhostActed`, `GhostResurrected` | Placa de espectro, acción y vuelta | [ ] |
| `CardDrawn`, `CardDiscarded`, `CardPlayed`, `CardBlocked` | Robo, descarte, carta en juego y bloqueo | [ ] |
| `HotZoneMoved`, `BillboardResult`, `DuelResolved`, `MarketBought` | Zona Caliente, resultado, duelo y compra | [ ] |
| `CrownMoved`, `FuryFilled` | La Corona cambia de placa; Furia llena | [ ] |
| `GameEnded` | Podio | [ ] |

## Lo que depende de otros planes

Queda preparado y nombrado, sin inventarlo. Cada punto se cierra cuando llegue lo que necesita:

- **Plan 7:** imágenes de las 8 fichas, iconos de casilla y maqueta de la vista general. Hasta entonces: el nombre de la ficha, el color de la casilla y la ciudad vista desde arriba.
- **Plan 8:** las escenas. La interfaz se aparta y acusa el evento sin depender de que la escena exista.

**Móvil:** aplazado por decisión del responsable. Nada de esto se da por probado en móvil.
