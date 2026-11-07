--!strict
-- Nombres y colores de la ciudad. Es el contenido que hace reconocible cada casilla desde la
-- calle: nombre y color de la zona, nombre de cada propiedad y etiqueta de cada casilla especial.
-- La fuente de verdad es docs/02-mvp/contenido-tablero.md; aquí solo se copia para que el cliente
-- no dependa de un documento. Los colores son cadenas `#RRGGBB` porque `Color3` es de Roblox y esta
-- carpeta se analiza con la plataforma estándar; el cliente los convierte al construir.
local Cards = require("./Cards")
local Perks = require("./Perks")
local Types = require("../rules/Types")

type SquareKind = Types.SquareKind

export type Zone = {
	name: string,
	barrio: string,
	color: string,
	properties: number,
	-- Nombres de las propiedades en el orden de su zona. El ordinal de la casilla elige uno.
	names: { string },
}

local ZONES: { [string]: Zone } = {
	cobre = {
		name = "Callejón del Cobre",
		barrio = "Centro",
		color = "#C97B3A",
		properties = 2,
		names = { "Barbería Morro", "Callejón del Hojalatero" },
	},
	cian = {
		name = "Pasaje Cian",
		barrio = "Centro",
		color = "#22D3EE",
		properties = 3,
		names = { "Pasaje Burbuja", "Calle del Cable", "Caldas" },
	},
	magenta = {
		name = "Bulevar Magenta",
		barrio = "Centro",
		color = "#E85D9E",
		properties = 3,
		names = { "Centro Páez", "Neo Mundo", "Plaza del Neón" },
	},
	naranja = {
		name = "Feria Naranja",
		barrio = "Centro",
		color = "#F59E0B",
		properties = 3,
		names = { "Mercado de la Séptima", "llaneradas.com", "Calle del Azafrán" },
	},
	carmesi = {
		name = "Distrito Carmesí",
		barrio = "Centro",
		color = "#DC2626",
		properties = 3,
		names = { "Plaza del Jazz", "Cine Lux", "Bodega La Reserva" },
	},
	limon = {
		name = "Paseo Limón",
		barrio = "Centro",
		color = "#FACC15",
		properties = 3,
		names = { "Vereda La Mata", "Villa Margarita", "Panadería La Espiga" },
	},
	esmeralda = {
		name = "Dársena Esmeralda",
		barrio = "Puerto",
		color = "#10B981",
		properties = 3,
		names = { "Muelle de los Pescadores", "Astillero Neptuno", "Acuario La Sirena" },
	},
	violeta = {
		name = "Muelle Violeta",
		barrio = "Puerto",
		color = "#8B5CF6",
		properties = 2,
		names = { "Versalles 1", "Versalles 2" },
	},
	anil = {
		name = "Mirador Añil",
		barrio = "ZonaAlta",
		color = "#4F46E5",
		properties = 3,
		names = { "Observatorio Cerro Azul", "D.T", "Torres de Aragón" },
	},
	blanca = {
		name = "Cumbre Blanca",
		barrio = "ZonaAlta",
		color = "#E7E5E4",
		properties = 3,
		names = { "Tajamar", "Cacique", "Monviso" },
	},
	grafito = {
		name = "Distrito Grafito",
		barrio = "Industrial",
		color = "#64748B",
		properties = 3,
		names = { "Fundición Vulcano", "Chatarrería El Imán", "Estación de Metrolínea" },
	},
	ocre = {
		name = "Sector Ocre",
		barrio = "Industrial",
		color = "#A16207",
		properties = 3,
		names = { "Almacén El Ladrillo", "Curtiembre Los Nogales", "Fábrica de Ladrillos La Hormiga" },
	},
}

-- Etiqueta corta de cada tipo de casilla. Es lo que se lee en el rótulo de la calle y en la vista
-- general; el nombre largo de la casilla de propiedad sale de su zona.
local KINDS: { [SquareKind]: string } = {
	Start = "Salida",
	Property = "Propiedad",
	Spin = "Giro",
	Market = "Mercado Negro",
	Duel = "Duelo",
	Portal = "Portal",
	Billboard = "Cartelera",
	Tribunal = "Tribunal",
	Tax = "Impuesto",
}

-- Color de cada casilla especial, también en `#RRGGBB`. Las propiedades usan el color de su zona.
local KIND_COLORS: { [SquareKind]: string } = {
	Start = "#16A34A",
	Property = "#9CA3AF",
	Spin = "#0EA5E9",
	Market = "#7C3AED",
	Duel = "#EF4444",
	Portal = "#06B6D4",
	Billboard = "#EAB308",
	Tribunal = "#1D4ED8",
	Tax = "#B91C1C",
}

-- Premios del final y jugadas del Duelo, en español. Los ids son los del motor (Awards y Squares).
local AWARDS: { [string]: string } = {
	MostTreacherous = "Mayor Traidor",
	BestComeback = "Mejor Remontada",
	VictimOfTheNight = "Víctima de la Noche",
}

local DUEL_CHOICES: { [string]: string } = {
	Rock = "Piedra",
	Paper = "Papel",
	Scissors = "Tijera",
}

-- Efecto de cada carta, como lo dice la ficha. El nombre vive en `Cards`, junto a sus reglas.
local CARD_DESCRIPTIONS: { [string]: string } = {
	Hurricane = "Todas las propiedades vuelven al banco. Sus dueños cobran la mitad de su valor.",
	WorldFlip = "La ciudad gira en el aire y todas las fichas caen en casillas al azar.",
	Revolution = "Los dos jugadores más ricos intercambian efectivo con los dos más pobres.",
	Earthquake = "Todos los edificios de una zona bajan un nivel.",
	CrownStrike = "El líder pierde 25 % de su efectivo, repartido entre los demás.",
	Inflation = "Todas las rentas se duplican durante 2 rondas.",
	Strike = "Una zona no cobra renta durante 2 rondas.",
	BounceRent = "Reacción: la próxima renta que te cobren la paga otro jugador que elijas.",
	DeedThief = "Robas una propiedad sin edificios que no complete un grupo.",
	Backstab = "Rompes un pacto tuyo sin coste y te quedas con la garantía.",
	Demolition = "Un edificio rival baja un nivel.",
	Shield = "Reacción: anula la próxima carta que te apunte.",
	ExtraDie = "Tiras un dado adicional este turno.",
	Reverse = "Retrocedes lo que sacaste en vez de avanzar.",
	ForcedTip = "Cada rival te paga 50.",
	Discount = "Tu próxima compra cuesta la mitad.",
	Shove = "Mueves a un rival 3 casillas.",
	Fine = "Un rival paga 100 al banco.",
	Bribe = "Te libras de un castigo del Tribunal.",
	Spy = "Ves la mano de un rival.",
}

-- Textos de la interfaz. `{nombre}` se sustituye con los argumentos de `Strings.get`. Las claves de
-- cartas y perks se añaden abajo, desde sus catálogos.
local TEXTS: { [string]: string } = {
	["hud.round"] = "Ronda {current}/{max}",
	["hud.roundEndless"] = "Ronda {current}",
	["hud.yourTurn"] = "Tu turno",
	["hud.overview"] = "Vista general",
	["hud.overviewKey"] = "M",
	["hud.settings"] = "Ajustes",
	["hud.settingsKey"] = "K",
	["settings.title"] = "Ajustes",
	["settings.help"] = "Ajusta la música y los efectos por separado. Los atajos de teclado están abajo.",
	["settings.step1"] = "Arrastra o toca la barra para cambiar el volumen.",
	["settings.step2"] = "A cero, ese canal deja de sonar.",
	["settings.step3"] = "Los cambios valen desde ya y duran mientras juegues.",
	["settings.music"] = "Música",
	["settings.effects"] = "Efectos",
	["settings.percent"] = "{value} %",
	["settings.keys"] = "Atajos",
	["settings.key.Space"] = "Botón amarillo: tirar, comprar, terminar",
	["settings.key.N"] = "No comprar (sale a subasta)",
	["settings.key.M"] = "Vista general",
	["settings.key.T"] = "Tratos",
	["settings.key.P"] = "Pactos",
	["settings.key.K"] = "Ajustes",
	["settings.key.Esc"] = "Cerrar la ventana abierta",
	["settings.keyName.Space"] = "Espacio",
	["hud.botPlaying"] = "Un bot juega por ti",
	["hud.botHint"] = "Entró tras {count} plazos seguidos sin jugar. Pulsa Retomar para volver a mandar tú.",
	["hud.reclaim"] = "RETOMAR",
	["hud.emotes"] = "Emotes",
	["hud.seconds"] = "{seconds} s",
	["deed.price"] = "Precio",
	["deed.footer"] = "Escritura",
	["deed.fullZone"] = "Zona completa del dueño",
	["deed.hotZone"] = "Casilla en Zona Caliente",
	["deed.double"] = "×2",
	["action.buy"] = "Comprar",
	["action.roll"] = "Tirar",
	["action.move"] = "Mover",
	["action.endTurn"] = "Terminar",
	["action.bid"] = "Pujar {amount}",
	["panel.PerkDraft"] = "Elige un perk",
	["panel.Auction"] = "Subasta",
	["panel.Reaction"] = "¿Reaccionas?",
	["panel.Tribunal"] = "Vota el castigo",
	["panel.Duel"] = "Duelo",
	["panel.Market"] = "Mercado Negro",
	["panel.GhostTurn"] = "Turno de espectro",
	["panel.bidRange"] = "De {min} a {max}",
	["action.decline"] = "No comprar · Subasta",
	["action.confirm"] = "¿Confirmas?",
	["hud.tradeKey"] = "T",
	["hud.pactKey"] = "P",
	["sheet.close"] = "Cerrar",
	["board.howTo"] = "Cómo funciona",
	["lobby.title"] = "Flip the Table",
	["lobby.help"] = "Juega con tu grupo: crea una party y comparte el código, o entra con el código de un amigo.",
	["lobby.step1"] = "Crea una party o entra con el código que te pasen.",
	["lobby.step2"] = "El anfitrión elige el modo y pulsa Empezar.",
	["lobby.step3"] = "Sin grupo, entra en la cola pública y juega con otros.",
	["lobby.create"] = "Crear party",
	["lobby.createHelp"] = "Serás el anfitrión: eliges el modo y empiezas cuando esté el grupo.",
	["lobby.createButton"] = "CREAR",
	["lobby.join"] = "Unirme con un código",
	["lobby.joinHelp"] = "Escribe el código de {length} caracteres que te pasó el anfitrión.",
	["lobby.joinPlaceholder"] = "Código",
	["lobby.joinButton"] = "Unirme",
	["lobby.public"] = "Partida pública",
	["lobby.publicHelp"] = "Te sentamos con otros jugadores en cuanto haya mesa.",
	["lobby.publicButton"] = "Jugar en público",
	["lobby.yourParty"] = "Tu party",
	["lobby.shareCode"] = "Comparte este código con tu grupo para que entre.",
	-- Lobby provisional: el parque con mesas.
	["lobbyPark.hint"] = "Siéntate en una mesa con otros jugadores para empezar una partida",
	["lobbyPark.friends"] = "Crear o unirse a party",
	["lobbyPark.quick"] = "Partida rápida",
	["lobby.settings"] = "Configuración",
	["lobby.settings.on"] = "Sí",
	["lobby.settings.off"] = "No",
	["lobby.settings.reset"] = "Volver a la normal",
	["lobby.mode"] = "Modo",
	["lobby.mode.Rounds"] = "Rondas",
	["lobby.mode.Endless"] = "Sin Fin",
	["lobby.modeHelp.Rounds"] = "Termina al llegar a la última ronda: gana el mayor patrimonio.",
	["lobby.modeHelp.Endless"] = "No tiene límite de rondas: gana el último que no esté en bancarrota.",
	["lobby.start"] = "EMPEZAR",
	["lobby.guestWait"] = "Estás dentro. El anfitrión elige el modo y empieza la partida.",
	["lobby.queueWait"] = "Buscando mesa en la cola pública…",
	["lobby.leaveView"] = "Volver",
	["lobby.backToPark"] = "Volver al parque",
	["lobby.error"] = "Error",
	["lobby.idleNotice"] = "Crea una party o escribe un código para unirte.",
	["guide.title"] = "Primera partida",
	["guide.perks"] = "Un perk es una ventaja para toda la partida. Elige el que encaje con tu forma de jugar.",
	["guide.buy"] = "Si compras la casilla, cobrarás renta a quien caiga en ella. Si no, sale a subasta.",
	["guide.rent"] = "Caer en una propiedad ajena cuesta su renta. Con la zona entera o edificios, cobra más.",
	["guide.cards"] = "Tus cartas van abajo. Pasa el ratón por una para leerla y juégala en tu turno.",
	["guide.overview"] = "Pulsa M para ver la ciudad en maqueta: dueños, dinero y efectos de un vistazo.",
	["guide.pacts"] = "Un pacto exime de renta a dos socios unas rondas. Romperlo marca al Traidor.",
	["guide.tribunal"] = "En el Tribunal, el resto vota el castigo del acusado. Una carta de Soborno lo evita.",
	["guide.ghost"] = "En bancarrota no quedas fuera: como espectro sabotearás y podrás volver.",
	["option.price"] = "Por {price}",
	["option.fine"] = "Multa de {amount}",
	["option.skipTurn"] = "Pierde un turno",
	["option.payTo"] = "Paga {amount} a {name}",
	["option.haunt"] = "Embrujar",
	["option.sabotage"] = "Sabotear",
	["option.kind.Perk"] = "Perk",
	["option.kind.Card"] = "Carta",
	["option.kind.Vote"] = "Voto",
	["option.kind.Duel"] = "Duelo",
	["option.kind.Ghost"] = "Espectro",
	["option.kind.Other"] = "Opción",
	["city.mortgaged"] = "Hipotecada",
	-- Sello de la escena del Ladrón de Escrituras, sobre la propiedad robada.
	["scene.deedThief.stamp"] = "Robada por {name}",
	-- Carteles de las cartas comunes: quién juega y contra quién.
	["scene.common.shield"] = "{actor} bloquea {card}",
	["scene.common.extraDie"] = "{actor}: dado extra",
	["scene.common.reverse"] = "{actor}: marcha atrás",
	["scene.common.forcedTip"] = "Propina para {actor}",
	["scene.common.discount"] = "{actor}: descuento",
	["scene.common.shove"] = "{actor} empuja a {target}",
	["scene.common.fine"] = "Multa a {target}",
	["scene.common.bribe"] = "{actor} soborna al Tribunal",
	["scene.common.spy"] = "{actor} espía a {target}",
	-- Escenas de casillas.
	["scene.duel.vs"] = "VS",
	["scene.duel.prize"] = "+{amount}",
	["scene.duel.tie"] = "Empate",
	["scene.market.header"] = "{actor} compra en el Mercado Negro",
	["scene.spin.header"] = "{actor} roba una carta",
	["scene.tax.header"] = "Impuesto: -{amount}",
	-- Escenas de la partida.
	["scene.rent.header"] = "{actor} paga {amount} a {target}",
	["scene.build.up"] = "Nivel {level}",
	["scene.build.down"] = "Baja a nivel {level}",
	["scene.mortgage.on"] = "Hipotecada +{amount}",
	["scene.mortgage.off"] = "Deshipotecada -{amount}",
	["scene.auction.start"] = "Subasta",
	["scene.auction.noSale"] = "Sin venta",
	["scene.bankruptcy.header"] = "{actor} en bancarrota",
	["scene.pact.formed"] = "Pacto: {actor} y {target}",
	["scene.traitor.sign"] = "Traidor: {actor}",
	["scene.crown.header"] = "{target} lleva la corona",
	["scene.fury.header"] = "¡Furia de {actor}!",
	["scene.ghost.haunt"] = "{actor} embruja",
	["scene.ghost.sabotage"] = "{actor} sabotea",
	["scene.ghost.revive"] = "¡{actor} vuelve! +{cash}",
	["scene.start.bonus"] = "+{amount}",
	["scene.trade.header"] = "Trato: {actor} y {target}",
	["scene.hotZone.header"] = "Zona Caliente: {zone}",
	["scene.finalRounds.header"] = "Última Ronda",
	["scene.round.first"] = "¡Empieza la partida!",
	["scene.round.next"] = "Ronda {round}",
	["scene.podium.winner"] = "Gana {name}",
	["scene.buy.sold"] = "Comprada",
	["scene.tribunal.header"] = "Veredicto para {actor}",
	["scene.tribunal.fine"] = "Multa: -{fine}",
	["scene.tribunal.pay"] = "Paga {pay} a un jugador",
	["scene.tribunal.skip"] = "Pierde un turno",
	["scene.tribunal.bribed"] = "Soborno: se libra",
	["scene.pact.ended"] = "Pacto cumplido: {actor} y {target}",
	["scene.perk.header"] = "{actor}: {perk}",
	["scene.discard.header"] = "Mano llena: {actor} descarta",
	["scene.buy.mine"] = "¡Es de {name}!",
	-- Suma de la escena de los dados: «4 + 3 = 7».
	["scene.dice.total"] = "{dice} = {total}",
	["scene.strike.sign"] = "Cerrado por huelga",
	["scene.backstab.stamp"] = "Traidor",
	["scene.inflation.badge"] = "×{mult}",
	-- Cifras pintadas en cada casilla de propiedad, junto a su nombre.
	["city.price.buy"] = "Compra",
	["city.price.rent"] = "Renta",
	["city.price.rentHot"] = "Renta zona caliente",
	["city.price.unmortgage"] = "Deshipotecar",
	["manage.title"] = "Propiedades",
	["manage.key"] = "G",
	["manage.Build"] = "Construir · {amount}",
	["manage.SellBuilding"] = "Vender nivel · +{amount}",
	["manage.Mortgage"] = "Hipotecar · +{amount}",
	["manage.Unmortgage"] = "Levantar · {amount}",
	["manage.rent"] = "Renta {amount}",
	["manage.mortgaged"] = "Hipotecada: no cobra renta",
	["manage.notYourTurn"] = "Solo puedes gestionar en tu turno",
	["manage.none"] = "Todavía no tienes propiedades",
	["manage.count"] = "{at} de {total}",
	["manage.close"] = "Cerrar",
	["hotZone.tag"] = "Zona Caliente · renta ×{mult}",
	["portal.callout"] = "Portal → {square}",
	["billboard.title"] = "Cartelera",
	["billboard.subtitle"] = "La suerte del cartel",
	["billboard.bigPrize"] = "Premio mayor",
	["billboard.smallPrize"] = "Premio chico",
	["billboard.fine"] = "Multa",
	["billboard.card"] = "Carta",
	["billboard.nothing"] = "Nada",
	["billboard.cardDrawn"] = "Robas una carta",
	["billboard.nothingHappened"] = "No pasa nada",
	["hand.confirm"] = "Confirmar",
	["hand.chooseTarget"] = "Elige dónde jugarla",
	["hand.notNow"] = "Ahora no se puede jugar.",
	["option.trayHide"] = "Opciones · {count}",
	["option.trayShow"] = "Ver opciones · {count}",
	["option.chosen"] = "Elegida",
	["rematch.title"] = "¿Revancha?",
	["rematch.help"] = "Quienes voten que sí juegan otra partida juntos, sin volver al lobby.",
	["rematch.step1"] = "Vota Revancha o No, gracias.",
	["rematch.step2"] = "Cuando todos han votado, o pasan {seconds} s, se decide.",
	["rematch.step3"] = "Hacen falta al menos {min} jugadores que digan que sí.",
	["rematch.podium"] = "Clasificación",
	["rematch.winnerStamp"] = "Ganador",
	["rematch.worth"] = "Patrimonio {amount}",
	["rematch.awards"] = "Premios",
	["rematch.vote"] = "Votación",
	["rematch.open"] = "El grupo decide si juega otra.",
	["rematch.waiting"] = "Esperando al resto del grupo…",
	["rematch.declined"] = "Has dicho que no. Esperando al resto del grupo…",
	["rematch.yes"] = "REVANCHA",
	["rematch.no"] = "No, gracias",
	["pact.help"] = "Un pacto exime de renta a los dos socios durante las rondas que elijas. Romperlo te cuesta la garantía y la marca de Traidor.",
	["pact.step1"] = "Elige socio y cuántas rondas dura.",
	["pact.step2"] = "Si acepta, cada uno deja {deposit} de garantía.",
	["pact.step3"] = "Al terminar la recuperas. Si lo rompes, se la queda tu socio y llevas la marca de Traidor {rounds} rondas.",
	["pact.proposeTitle"] = "Proponer",
	["pact.partner"] = "Socio",
	["pact.length"] = "Duración",
	["pact.contract"] = "{name} y tú no se cobran renta durante {rounds}. Garantía: {deposit} cada uno.",
	["pact.pickPartner"] = "Elige un socio para ver el pacto.",
	["pact.noRivals"] = "No queda ningún rival activo con quien pactar.",
	["pact.listTitle"] = "Tus pactos",
	["pact.empty"] = "Todavía no tienes pactos ni propuestas.",
	["pact.offerLine"] = "{name} te propone un pacto de {rounds}.",
	["pact.activeLine"] = "Con {name}, hasta la ronda {round}.",
	["pact.breakWarning"] = "Si lo rompes, {name} se queda tu garantía y llevas la marca de Traidor.",
	["token.title"] = "Elige tu ficha",
	["token.help"] = "Cada jugador lleva una ficha distinta. Si eliges una que ya tiene otro jugador, se cambian las fichas.",
	["token.step1"] = "Toca la ficha que quieras.",
	["token.step2"] = "Si ya la tiene otro jugador, te la quedas y le das la tuya.",
	["token.step3"] = "Puedes cambiarla hasta que alguien salga de la Salida.",
	["token.free"] = "Libre",
	["token.mine"] = "Tuya",
	["token.takenBy"] = "De {name}",
	["token.swapHint"] = "Tócala para cambiarla",
	["token.notice"] = "Puedes cambiarla hasta que alguien salga de la Salida.",
	["token.ready"] = "LISTO",
	["board.hideHowTo"] = "Ocultar pasos",
	["trade.help"] = "Cambia dinero, propiedades o las dos cosas con otro jugador. Solo se cierra si los dos aceptan.",
	["trade.step1"] = "Elige con quién tratas.",
	["trade.step2"] = "Toca las escrituras y escribe el dinero de cada lado.",
	["trade.step3"] = "Envía. Si el otro acepta, el cambio no tiene vuelta atrás.",
	["trade.you"] = "{name} (tú)",
	["trade.giveHint"] = "Entregas: toca tus escrituras",
	["trade.wantHint"] = "Pides: toca las escrituras de {name}",
	["trade.noDeeds"] = "Sin escrituras que se puedan cambiar. Las que tienen edificios no entran en un trato.",
	["trade.cash"] = "Dinero",
	["trade.cashMax"] = "de {max}",
	["trade.stampGive"] = "Entregas",
	["trade.stampWant"] = "Pides",
	["trade.summaryGive"] = "Entregas",
	["trade.summaryGet"] = "Recibes",
	["trade.nothing"] = "Nada",
	["trade.plusCash"] = "{items} + {cash}",
	["trade.incomingTitle"] = "Trato de {name}",
	["trade.incomingHelp"] = "{name} te propone este cambio. Si aceptas, se hace al momento y no tiene vuelta atrás.",
	["trade.incomingStep1"] = "Mira lo que te da y lo que te pide.",
	["trade.incomingStep2"] = "Acepta o rechaza; los dos piden una segunda pulsación.",
	["trade.incomingStep3"] = "Si no respondes antes de que acabe su turno, la propuesta se anula.",
	["trade.theyGive"] = "Te da",
	["trade.theyWant"] = "Te pide",
	["trade.offerCount"] = "Propuesta {current} de {total}",
	["trade.next"] = "Siguiente",
	["sheet.closeKey"] = "Esc",
	["trade.title"] = "Tratos",
	["trade.pickRival"] = "Elige a quién proponer",
	["trade.giveCash"] = "Entregas {amount}",
	["trade.wantCash"] = "Pides {amount}",
	["trade.less"] = "Menos",
	["trade.more"] = "Más",
	["trade.giveSquares"] = "Tus casillas sin edificios: toca para entregar",
	["trade.wantSquares"] = "Casillas de {name} sin edificios: toca para pedir",
	["trade.proposing"] = "Propones: {offer}",
	["trade.pickCashOrSquares"] = "Elige dinero o casillas para proponer",
	["trade.send"] = "ENVIAR",
	["trade.onlyOnTurn"] = "Solo puedes proponer un trato en tu turno, antes de tirar o al final",
	["trade.incoming"] = "Te han propuesto",
	["trade.offerFrom"] = "De {name}: {offer}",
	["trade.accept"] = "ACEPTAR",
	["trade.reject"] = "Rechazar",
	["pact.title"] = "Pactos",
	["pact.pickRivalRounds"] = "Con quién y cuántas rondas (máximo {max})",
	["pact.rounds"] = "{count} rondas",
	["pact.oneRound"] = "1 ronda",
	["pact.send"] = "PROPONER",
	["pact.onlyOnTurn"] = "Solo puedes proponer un pacto en tu turno, antes de tirar o al final",
	["pact.incoming"] = "Te han propuesto",
	["pact.offerFrom"] = "Pacto de {name}: {rounds}",
	["pact.accept"] = "Aceptar",
	["pact.reject"] = "Rechazar",
	["pact.own"] = "Tus pactos",
	["pact.ownWith"] = "Con {name}, hasta la ronda {round}",
	["pact.break"] = "Romper pacto",
	["overview.title"] = "Vista general",
	["overview.showData"] = "Ver datos de la partida",
	["overview.hideData"] = "Ocultar datos",
	["overview.help"] = "Cada propiedad con dueño lleva su tarjeta sobre la maqueta. Pulsa M para volver.",
	["overview.owners"] = "Jugadores y dinero",
	["overview.effects"] = "Efectos activos",
	["overview.positions"] = "Posiciones",
	["overview.ownerLine"] = "{name}: {cash}",
	["overview.ownerLineStatus"] = "{name} ({status}): {cash}",
	["overview.property"] = "{square}: {owner}, {level}",
	["overview.hotZone"] = "Zona Caliente: {zone}",
	["overview.none"] = "Ninguno",
	["overview.position"] = "{name} · {square}",
	["rarity.Common"] = "Común",
	["rarity.Rare"] = "Rara",
	["rarity.Legendary"] = "Legendaria",
	["mark.crown"] = "Corona",
	["mark.traitor"] = "Traidor",
	["mark.fury"] = "Furia {current}/{max}",
	["mark.ghost"] = "Espectro",
	["mark.left"] = "Se fue",
	["mark.bot"] = "Bot",
	["mark.you"] = "Tú",
	["mark.cards"] = "{count} cartas",
	["mark.oneCard"] = "1 carta",
	["mark.skipTurn"] = "Pierde turno",
}

for _, card in Cards.all do
	local description = CARD_DESCRIPTIONS[card.id]
	if description == nil then
		error(`Strings: la carta {card.id} no tiene descripción`)
	end
	TEXTS[`card.{card.id}.name`] = card.name
	TEXTS[`card.{card.id}.description`] = description
end

for _, perk in Perks.all do
	TEXTS[`perk.{perk.id}.name`] = perk.name
	TEXTS[`perk.{perk.id}.description`] = perk.description
end

local Strings = {}

-- Texto de la interfaz. Una clave o un argumento que falte es un error: durante el desarrollo se ve
-- enseguida, y ningún jugador llega a leer una clave o una llave sin sustituir.
function Strings.get(key: string, args: { [string]: any }?): string
	local text = TEXTS[key]
	if text == nil then
		error(`Strings: la clave {key} no existe`, 2)
	end
	return (
		string.gsub(text, "{(%w+)}", function(name: string): string
			local value = if args ~= nil then args[name] else nil
			if value == nil then
				error(`Strings: la clave {key} necesita el argumento {name}`, 2)
			end
			return tostring(value)
		end)
	)
end

-- Título que anuncia un evento en pantalla. Corto: va en la voz grande. `TokenMoved` no lleva: el
-- recorrido se ve solo.
local EVENT_TITLES: { [string]: string } = {
	RoundStarted = "Nueva ronda",
	FinalRoundsStarted = "Última ronda",
	PerkDrafted = "Perk elegido",
	DiceRolled = "¡Dados!",
	TokenMoved = "",
	PassedStart = "Salida",
	PropertyBought = "¡Comprada!",
	RentPaid = "Renta",
	AuctionStarted = "Subasta",
	AuctionWon = "Subasta ganada",
	AuctionNoSale = "Sin ventas",
	BuildingChanged = "Obras",
	PropertyMortgaged = "Hipoteca",
	PropertyUnmortgaged = "Hipoteca levantada",
	TradeCompleted = "Trato cerrado",
	PlayerArrested = "¡Arrestado!",
	TribunalVerdict = "Veredicto",
	BankruptcyDeclared = "Bancarrota",
	GhostActed = "Espectro",
	GhostResurrected = "¡Resucita!",
	CardDrawn = "Carta robada",
	CardDiscarded = "Descarte",
	CardPlayed = "Carta jugada",
	CardBlocked = "¡Bloqueada!",
	HotZoneMoved = "Zona Caliente",
	BillboardResult = "Cartelera",
	DuelResolved = "Duelo",
	PortalUsed = "Portal",
	MarketBought = "Mercado Negro",
	PactFormed = "Pacto firmado",
	PactEnded = "Pacto terminado",
	PactBroken = "¡Traición!",
	CrownMoved = "Nueva Corona",
	FuryFilled = "¡Furia!",
	GameEnded = "Fin de la partida",
}

-- Mayúsculas del español. `string.upper` solo entiende ASCII y dejaría «MARíA JOSé».
local UPPER = {
	["á"] = "Á",
	["é"] = "É",
	["í"] = "Í",
	["ó"] = "Ó",
	["ú"] = "Ú",
	["ü"] = "Ü",
	["ñ"] = "Ñ",
}

function Strings.upper(text: string): string
	local out = string.upper(text)
	for lower: string, upper: string in pairs(UPPER) do
		out = (string.gsub(out, lower, upper))
	end
	return out
end

-- Título de un evento o de una carta jugada. Un id que no se conoce no enseña nada: nunca un nombre interno.
function Strings.eventTitle(id: string): string
	local title = EVENT_TITLES[id]
	if title ~= nil then
		return title
	end
	return TEXTS[`card.{id}.name`] or ""
end

-- Nombre del barrio, que es la agrupación de zonas que la ciudad muestra en la calle.
Strings.BARRIOS = {
	Centro = "Centro",
	Puerto = "Puerto",
	ZonaAlta = "Zona Alta",
	Industrial = "Industrial",
}

function Strings.zone(zoneId: string): Zone
	local zone = ZONES[zoneId]
	if zone == nil then
		error(`Strings: la zona {zoneId} no tiene nombre ni color`, 2)
	end
	return zone
end

-- Nombre de la enésima propiedad de una zona. El ordinal lo da el propio tablero: la primera
-- propiedad de la zona es la 1.
function Strings.property(zoneId: string, ordinal: number): string
	local zone = Strings.zone(zoneId)
	local name = zone.names[ordinal]
	if name == nil then
		error(`Strings: la zona {zoneId} no tiene una propiedad {ordinal}`, 2)
	end
	return name
end

function Strings.kind(kind: SquareKind): string
	local label = KINDS[kind]
	if label == nil then
		error(`Strings: el tipo de casilla {tostring(kind)} no tiene etiqueta`, 2)
	end
	return label
end

-- Color `#RRGGBB` de una casilla: el de su zona si es propiedad y el de su tipo si no.
function Strings.colorFor(square: Types.Square): string
	if square.kind == "Property" and square.zoneId ~= nil then
		return Strings.zone(square.zoneId :: string).color
	end
	local color = KIND_COLORS[square.kind]
	if color == nil then
		error(`Strings: el tipo de casilla {tostring(square.kind)} no tiene color`, 2)
	end
	return color
end

-- Rótulo de una casilla. `ordinal` es su número de propiedad dentro de la zona, que `CityLayout`
-- calcula; para las casillas especiales no hace falta.
function Strings.squareLabel(square: Types.Square, ordinal: number?): string
	if square.kind == "Property" then
		local zoneId = square.zoneId
		if zoneId == nil then
			return Strings.kind("Property")
		end
		local zone = Strings.zone(zoneId)
		local position = ordinal or 1
		-- El ordinal llega dado por quien recorre el tablero; si no, se usa el primero de la zona,
		-- que siempre existe y evita romper la etiqueta de la calle.
		if zone.names[position] == nil then
			position = 1
		end
		return zone.names[position]
	end
	return Strings.kind(square.kind)
end

-- Nombre de un premio del podio. Un id desconocido se devuelve tal cual: un premio nuevo sin nombre
-- debe verse feo, no romper la pantalla final.
function Strings.award(awardId: string): string
	return AWARDS[awardId] or awardId
end

-- Nombre de una jugada del Duelo (Piedra, Papel o Tijera).
function Strings.duelChoice(choiceId: string): string
	return DUEL_CHOICES[choiceId] or choiceId
end

-- Nombre del barrio para la interfaz. Un barrio desconocido devuelve su identificador: se prefiere
-- un rótulo feo a un error en mitad de una partida.
function Strings.barrio(barrioId: string): string
	return Strings.BARRIOS[barrioId] or barrioId
end

-- Nombre de un nivel de construcción, como lo dice `contenido-tablero.md`.
local BUILDING_LEVELS = { "Sin mejoras", "1 casa", "2 casas", "3 casas", "Hotel", "Rascacielos" }

function Strings.buildingLevel(level: number): string
	return BUILDING_LEVELS[level + 1] or `Nivel {level}`
end

return Strings
