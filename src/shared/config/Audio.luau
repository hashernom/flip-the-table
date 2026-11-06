--!strict
-- Música y efectos del juego. Cada pieza es un id de Roblox; mientras su pieza no esté generada,
-- comprobada en sus condiciones de uso comercial, registrada en `art/manifest.json` y aprobada, su id
-- queda vacío y no suena nada (Tarea 6 del plan 09). Ningún audio de la Toolbox entra aquí.

export type Piece = { id: string, volume: number, looped: boolean }

local function piece(volume: number, looped: boolean?): Piece
	return { id = "", volume = volume, looped = looped == true }
end

local Audio = {}

-- Techo de la suma de sonidos a la vez: con más, cada uno baja para que la mezcla no sature.
Audio.mixCeiling = 1.6

-- Volúmenes de partida de los dos canales que el jugador ajusta en Ajustes.
Audio.defaultMusic = 0.6
Audio.defaultEffects = 0.8

-- Segundos del fundido al cambiar de música.
Audio.musicFadeSec = 1.2

Audio.pieces = {
	["music.lobby"] = piece(0.5, true),
	["music.match"] = piece(0.45, true),
	["music.finalRounds"] = piece(0.55, true),
	["music.podium"] = piece(0.6, true),
	["ambience.city"] = piece(0.35, true),
	["ui.press"] = piece(0.5),
	["ui.open"] = piece(0.4),
	["ui.close"] = piece(0.35),
	["ui.confirm"] = piece(0.6),
	["ui.money"] = piece(0.5),
	["ui.card"] = piece(0.55),
} :: { [string]: Piece }

-- Sonido de cada evento de la mesa. La escena grande pone el suyo cuando llegue (plan 08); este es el
-- acuse que la interfaz da siempre.
Audio.eventSounds = {
	DiceRolled = "ui.press",
	PropertyBought = "ui.confirm",
	RentPaid = "ui.money",
	PassedStart = "ui.money",
	CardDrawn = "ui.card",
	CardPlayed = "ui.card",
	AuctionWon = "ui.confirm",
	TradeCompleted = "ui.confirm",
	PactFormed = "ui.confirm",
} :: { [string]: string }

return Audio
