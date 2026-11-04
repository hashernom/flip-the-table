--!strict
-- Lo que hay que deshacer de una vista al cruzar un `RemoteEvent`. Las propiedades son una tabla con
-- huecos, indexada por casilla, y Roblox convierte a texto los índices que no puede tratar como lista:
-- el motor y las reglas del cliente, en cambio, buscan por número. Se normaliza en la entrada, una sola
-- vez, para que nadie más tenga que saberlo.
local ViewWire = {}

function ViewWire.normalize(view: any): any
	if type(view) ~= "table" or type(view.properties) ~= "table" then
		return view
	end
	local properties: { [number]: any } = {}
	for key, property in view.properties do
		local index = tonumber(key)
		if index ~= nil then
			properties[index] = property
		end
	end
	view.properties = properties
	return view
end

return ViewWire
