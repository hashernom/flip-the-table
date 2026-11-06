--!strict
-- Música y efectos del juego. Cada pieza es un id de Roblox; mientras su pieza no esté generada,
-- comprobada en sus condiciones de uso comercial, registrada en `art/manifest.json` y aprobada, su id
-- queda vacío y no suena nada (Tarea 6 del plan 09). Ningún audio de la Toolbox entra aquí.

-- `jitter`: cuánto puede variar el tono en cada reproducción (0,05 = ±5 %). Los efectos pequeños que se
-- repiten mucho (clics, dados, monedas) varían un poco para que no suenen a máquina.
export type Piece = { id: string, volume: number, looped: boolean, jitter: number }

local function piece(volume: number, looped: boolean?, jitter: number?): Piece
	return { id = "", volume = volume, looped = looped == true, jitter = jitter or 0 }
end

-- Efecto procedural: sintetizado desde cero por `art/audio/build_sfx.py`, sin muestras de terceros. El id
-- es el de su archivo `art/audio/sfx/*.wav` subido a Roblox (`art/audio/sfx/subida.json`, 2026-11-05).
local function sfx(assetId: string, volume: number, jitter: number): Piece
	local made = piece(volume, false, jitter)
	made.id = `rbxassetid://{assetId}`
	return made
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
	["ui.press"] = sfx("129073769594246", 0.5, 0.06),
	["ui.hover"] = sfx("98067518849423", 0.18, 0.08),
	["ui.open"] = sfx("76759140751793", 0.4, 0.02),
	["ui.close"] = sfx("72036430391388", 0.35, 0.02),
	["ui.confirm"] = sfx("126500973425436", 0.6, 0.02),
	["ui.deny"] = sfx("104352905708593", 0.5, 0.03),
	["ui.money"] = sfx("70780900394300", 0.5, 0.05),
	["ui.card"] = sfx("91229175349866", 0.55, 0.08),
	["ui.tick"] = sfx("138817054554732", 0.35, 0.03),
	["sfx.dice"] = sfx("100346351288250", 0.6, 0.07),
	["sfx.build"] = sfx("115356124495239", 0.6, 0.03),
	["sfx.demolish"] = sfx("83634681025357", 0.6, 0.04),
	["sfx.pactBreak"] = sfx("83259273157737", 0.55, 0.03),
	["sfx.chime"] = sfx("123837626897918", 0.45, 0.02),
} :: { [string]: Piece }

-- Archivo de cada efecto procedural en el repositorio, para subirlo y registrarlo en el manifiesto.
Audio.sfxFiles = {
	["ui.press"] = "art/audio/sfx/ui-press.wav",
	["ui.hover"] = "art/audio/sfx/ui-hover.wav",
	["ui.open"] = "art/audio/sfx/ui-open.wav",
	["ui.close"] = "art/audio/sfx/ui-close.wav",
	["ui.confirm"] = "art/audio/sfx/ui-confirm.wav",
	["ui.deny"] = "art/audio/sfx/ui-deny.wav",
	["ui.money"] = "art/audio/sfx/ui-money.wav",
	["ui.card"] = "art/audio/sfx/ui-card.wav",
	["ui.tick"] = "art/audio/sfx/ui-tick.wav",
	["sfx.dice"] = "art/audio/sfx/sfx-dice.wav",
	["sfx.build"] = "art/audio/sfx/sfx-build.wav",
	["sfx.demolish"] = "art/audio/sfx/sfx-demolish.wav",
	["sfx.pactBreak"] = "art/audio/sfx/sfx-pact-break.wav",
	["sfx.chime"] = "art/audio/sfx/sfx-chime.wav",
} :: { [string]: string }

-- Segundos mínimos entre dos sonidos de pasar el ratón: recorrer una lista no debe sonar a metralleta.
Audio.hoverCooldownSec = 0.06

-- Sonido de cada evento de la mesa. La escena grande pone el suyo cuando llegue (plan 08); este es el
-- acuse que la interfaz da siempre.
-- `BuildingChanged` no está aquí: suena a obra o a derribo según suba o baje (`AudioRules.soundForEvent`).
Audio.eventSounds = {
	DiceRolled = "sfx.dice",
	PropertyBought = "ui.confirm",
	RentPaid = "ui.money",
	PassedStart = "ui.money",
	MarketBought = "ui.money",
	CardDrawn = "ui.card",
	CardPlayed = "ui.card",
	CardDiscarded = "ui.card",
	CardBlocked = "ui.deny",
	PerkDrafted = "ui.confirm",
	AuctionStarted = "ui.open",
	AuctionWon = "ui.confirm",
	AuctionNoSale = "ui.close",
	TradeCompleted = "ui.confirm",
	PactFormed = "ui.confirm",
	PactBroken = "sfx.pactBreak",
	PactEnded = "ui.close",
	CrownMoved = "sfx.chime",
	FuryFilled = "sfx.chime",
	HotZoneMoved = "sfx.chime",
} :: { [string]: string }

Audio.buildUpSound = "sfx.build"
Audio.buildDownSound = "sfx.demolish"

return Audio
