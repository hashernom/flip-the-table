--!strict
-- Catálogo de las ocho fichas: el vehículo gigante que lleva el avatar de cada jugador por la ciudad.
-- Es datos puros: el cliente convierte `seatOffset` a `Vector3` al colocar el avatar.
--
-- `asset` es el prefijo de las mallas de `art/blender/tokens/<ficha>/`, con el que el cliente busca
-- sus piezas en `ArtAssets`. `seatOffset` es el punto donde va el avatar, en studs, con el convenio de
-- `art/blender/tokens/taxi/stats.json`: Blender con Z hacia arriba, origen en el centro de la base y
-- morro en -Y. Solo el taxi tiene ese stats.json; las otras siete usan el mismo valor provisional
-- hasta tener el suyo.
export type Vector3Like = { x: number, y: number, z: number }

export type Token = {
	id: string,
	asset: string,
	seatOffset: Vector3Like,
}

-- Asiento provisional de las fichas que aún no tienen su stats.json (solo el taxi lo tiene).
local PROVISIONAL_SEAT: Vector3Like = { x = 0, y = 0.8, z = 4.6 }

local Tokens = {}

Tokens.DEFAULT_ID = "taxi"

-- Movimiento de la ficha, en studs y segundos. Se ajusta a ojo, por eso vive aquí.
Tokens.motion = {
	-- Reposo: el vehículo respira con el motor al ralentí.
	idleAmplitude = 0.05,
	idlePeriodSec = 2.2,
	-- Marcha: un rebote por cada `rideBounceStuds` recorridos.
	rideBounce = 0.12,
	rideBounceStuds = 7,
	-- Celebración: un salto con una vuelta completa.
	celebrateSec = 1.2,
	celebrateHeight = 3,
	celebrateSpins = 1,
}

Tokens.all = {
	{ id = "taxi", asset = "taxi", seatOffset = { x = 0, y = 0.8, z = 4.6 } },
	{ id = "limusina", asset = "limo", seatOffset = PROVISIONAL_SEAT },
	{ id = "moto", asset = "moto", seatOffset = PROVISIONAL_SEAT },
	{ id = "deportivo", asset = "sport", seatOffset = PROVISIONAL_SEAT },
	{ id = "food-truck", asset = "food", seatOffset = PROVISIONAL_SEAT },
	{ id = "camion-helados", asset = "icecream", seatOffset = PROVISIONAL_SEAT },
	{ id = "grua", asset = "tow", seatOffset = PROVISIONAL_SEAT },
	{ id = "autobus", asset = "bus", seatOffset = PROVISIONAL_SEAT },
} :: { Token }

-- Ficha con ese id, o nil si no existe. Un id que llega de fuera nunca se da por bueno sin esto.
function Tokens.byId(id: string): Token?
	for _, token in Tokens.all do
		if token.id == id then
			return token
		end
	end
	return nil
end

return Tokens
