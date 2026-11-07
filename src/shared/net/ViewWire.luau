--!strict
-- Cómo cruza una vista un `RemoteEvent`. Las propiedades son una tabla con huecos, indexada por casilla
-- (en el tablero M faltan la 1, la 4, la 8…). Luau guarda parte de esas claves en el tramo de array, con
-- `nil` en medio, y el resto en el hash: es una tabla mixta, justo lo que Roblox no transmite entera, y
-- el cliente recibía menos propiedades de las que había (incidencia «propiedades sin dueño en el
-- cliente»). Por eso el servidor codifica las claves como texto, que viajan como un diccionario puro, y
-- el cliente las devuelve a número en la entrada, una sola vez, para que nadie más tenga que saberlo.
local ViewWire = {}

-- Servidor: copia superficial de la vista con las claves de `properties` en texto. No muta la vista
-- recibida. El resultado solo sirve para enviarse; las reglas siguen trabajando con números.
function ViewWire.encode(view: any): any
	if type(view) ~= "table" or type(view.properties) ~= "table" then
		return view
	end
	local wire = table.clone(view)
	local properties: { [string]: any } = {}
	for index, property in view.properties do
		properties[tostring(index)] = property
	end
	wire.properties = properties
	return wire
end

-- Cliente: devuelve a número las claves de `properties`. Acepta también claves numéricas, así que es
-- idempotente.
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
