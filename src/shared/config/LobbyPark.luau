--!strict
-- Disposición del lobby provisional: un parque central pequeño rodeado de calle y edificios. En el centro,
-- una fuente; alrededor, mesas de juego con bancos de 4 a 8 puestos. Quien se sienta junto a otros en una
-- mesa entra en partida con ellos (`server/lobby/TableService`).
--
-- Solo datos y medidas en studs, sin `Instance`: `server/lobby/LobbyWorld` lo construye y las pruebas lo
-- comprueban con Lune. El suelo está en y = 0 y el parque, centrado en el origen.
local LobbyPark = {}

export type Table = {
	id: string,
	x: number,
	z: number,
	seats: number,
}

export type Building = {
	x: number,
	z: number,
	-- Giro en radianes: el edificio mira al parque.
	yaw: number,
	width: number,
	depth: number,
	height: number,
	color: string,
	-- Malla de `ArtAssets.street` que se intenta poner; si no carga, queda el edificio procedural.
	art: string?,
}

-- Medidas del parque y de lo que lo rodea.
LobbyPark.PARK_HALF = 70
LobbyPark.SIDEWALK = 8
LobbyPark.STREET = 26
LobbyPark.BUILDING_DEPTH = 26
LobbyPark.FOUNTAIN_RADIUS = 12

-- Radio del círculo de bancos de una mesa según sus puestos: los de 8 necesitan más sitio.
function LobbyPark.seatRadius(seats: number): number
	return 5 + seats * 0.55
end

-- Mesas de juego: dos de 4, dos de 6 y dos de 8, en corona alrededor de la fuente. El orden de la lista es
-- el de sus nombres («Mesa 1»…).
local TABLE_SEATS = { 4, 6, 8, 4, 6, 8 }
local TABLE_RING = 42

function LobbyPark.tables(): { Table }
	local list: { Table } = {}
	for i, seats in TABLE_SEATS do
		local angle = (i - 1) / #TABLE_SEATS * math.pi * 2 + math.pi / #TABLE_SEATS
		table.insert(list, {
			id = `Mesa{i}`,
			x = math.cos(angle) * TABLE_RING,
			z = math.sin(angle) * TABLE_RING,
			seats = seats,
		})
	end
	return list
end

-- Posición y orientación de cada puesto: en círculo, mirando al centro de la mesa.
function LobbyPark.seatsOf(tableData: Table): { { x: number, z: number, yaw: number } }
	local list = {}
	local radius = LobbyPark.seatRadius(tableData.seats)
	for i = 1, tableData.seats do
		local angle = (i - 1) / tableData.seats * math.pi * 2
		local x = tableData.x + math.cos(angle) * radius
		local z = tableData.z + math.sin(angle) * radius
		-- Mira hacia la mesa: el frente del asiento (-Z) apunta al centro.
		local yaw = math.atan2(x - tableData.x, z - tableData.z)
		table.insert(list, { x = x, z = z, yaw = yaw })
	end
	return list
end

-- Edificios de los cuatro lados, más allá de la calle, de alturas variadas. Deterministas: todos los
-- servidores del lobby son iguales.
local COLORS = { "#D8CBB0", "#B0664A", "#8E949A", "#C9A36B", "#6E7E8E", "#E5DCC6", "#9C5A44" }
local ART = { "centro-backdrop-a", "centro-backdrop-b", "zona-alta-backdrop-a", "zona-alta-backdrop-b" }
local PER_SIDE = 5

function LobbyPark.buildings(): { Building }
	local list: { Building } = {}
	local edge = LobbyPark.PARK_HALF + LobbyPark.SIDEWALK + LobbyPark.STREET + LobbyPark.BUILDING_DEPTH / 2
	local span = (LobbyPark.PARK_HALF + LobbyPark.SIDEWALK + LobbyPark.STREET) * 2
	local width = span / PER_SIDE
	local n = 0
	for side = 0, 3 do
		local yaw = side * math.pi / 2
		for i = 1, PER_SIDE do
			n += 1
			local along = -span / 2 + (i - 0.5) * width
			-- Lado 0 al norte (+Z), y luego girando.
			local x, z = along, edge
			local c, s = math.cos(yaw), math.sin(yaw)
			local rx, rz = x * c + z * s, -x * s + z * c
			local height = 22 + ((n * 37) % 5) * 9
			table.insert(list, {
				x = rx,
				z = rz,
				-- El frente (-Z local) mira al parque.
				yaw = yaw,
				width = width - 2,
				depth = LobbyPark.BUILDING_DEPTH,
				height = height,
				color = COLORS[(n - 1) % #COLORS + 1],
				art = if n % 3 == 0 then ART[(n // 3 - 1) % #ART + 1] else nil,
			})
		end
	end
	return list
end

-- Árboles del parque: en las cuatro esquinas y a lo largo del borde, sin pisar mesas ni la fuente.
function LobbyPark.trees(): { { x: number, z: number } }
	local list = {}
	local h = LobbyPark.PARK_HALF - 6
	for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		table.insert(list, { x = corner[1] * h, z = corner[2] * h })
		table.insert(list, { x = corner[1] * (h - 12), z = corner[2] * h })
		table.insert(list, { x = corner[1] * h, z = corner[2] * (h - 12) })
	end
	for i = -2, 2 do
		if i ~= 0 then
			table.insert(list, { x = i * 22, z = h })
			table.insert(list, { x = i * 22, z = -h })
			table.insert(list, { x = h, z = i * 22 })
			table.insert(list, { x = -h, z = i * 22 })
		end
	end
	return list
end

return LobbyPark
