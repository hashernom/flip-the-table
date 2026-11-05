--!strict
-- Modelos reales de la ciudad (R-P50): qué mallas forman cada propiedad y cada marcador, y con qué
-- material va cada una. En Roblox cada malla lleva un solo material y las de Open Cloud llegan sin él.
-- Una propiedad que no está aquí se ve con el bloque gris de `BuildingView`.
export type Piece = {
	key: string,
	assetId: string,
	color: { number },
	material: string,
	reflectance: number?,
}

local BRICK = { 176, 102, 74 }
local STONE = { 210, 201, 180 }
local SLATE = { 74, 78, 84 }
local RED = { 196, 56, 43 }
-- Oscuro y opaco: tras estos cristales no hay interior, y con transparencia se veía el ladrillo.
local GLASS = { 46, 74, 99 }

local function piece(
	key: string,
	id: string,
	color: { number },
	material: string,
	reflectance: number?
): Piece
	return {
		key = key,
		assetId = `rbxassetid://{id}`,
		color = color,
		material = material,
		reflectance = reflectance,
	}
end

local ArtAssets = {}

ArtAssets.FOLDER = "ArtAssets"
ArtAssets.READY_ATTRIBUTE = "Ready"

-- Lo que el edificio se retrasa en el solar: delante van los marcadores.
ArtAssets.FRONT_OFFSET = 2

-- Por el nombre que da `Strings.squareLabel`. Los añadidos, en orden de nivel.
ArtAssets.properties = {
	["Barbería Morro"] = {
		base = {
			piece("morro_body_brick", "77687404212406", { 176, 102, 74 }, "Brick"),
			piece("morro_body_limestone", "90294882036572", { 210, 201, 180 }, "Limestone"),
			piece("morro_body_glass", "90016036285546", { 46, 74, 99 }, "Glass", 0.25),
			piece("morro_body_wood", "86762790820122", { 90, 58, 36 }, "Wood"),
			piece("morro_body_metal", "104187849650590", { 201, 123, 58 }, "Metal"),
			piece("morro_body_smoothplastic_rojo", "102968722848894", { 196, 56, 43 }, "SmoothPlastic"),
			piece("morro_body_smoothplastic_blanco", "70533860993853", { 244, 244, 244 }, "SmoothPlastic"),
			piece("morro_body_smoothplastic_azul", "84228989982027", { 31, 95, 168 }, "SmoothPlastic"),
		},
		addons = {
			{
				piece("morro_addon1_fabric_rojo", "71448421870290", { 196, 56, 43 }, "Fabric"),
				piece("morro_addon1_fabric_blanco", "125938412633087", { 237, 229, 211 }, "Fabric"),
			},
			{
				piece("morro_addon2_limestone", "80579561888910", { 210, 201, 180 }, "Limestone"),
				piece("morro_addon2_metal", "134944303681399", { 201, 123, 58 }, "Metal"),
			},
			{
				piece("morro_addon3_brick", "77262204816778", { 176, 102, 74 }, "Brick"),
				piece("morro_addon3_glass", "87112376275479", { 46, 74, 99 }, "Glass", 0.25),
				piece("morro_addon3_limestone", "102682037234585", { 210, 201, 180 }, "Limestone"),
				piece("morro_addon3_slate", "140041778014371", { 74, 78, 84 }, "Slate"),
			},
			{
				piece("morro_addon4_brick", "136311841525253", { 176, 102, 74 }, "Brick"),
				piece("morro_addon4_slate", "95966858726570", { 74, 78, 84 }, "Slate"),
				piece("morro_addon4_metal", "108128922169846", { 201, 123, 58 }, "Metal"),
			},
			{
				piece("morro_addon5_limestone", "77029163935374", { 210, 201, 180 }, "Limestone"),
				piece("morro_addon5_metal", "130478452546937", { 201, 123, 58 }, "Metal"),
				piece("morro_addon5_slate", "85180681296702", { 74, 78, 84 }, "Slate"),
				piece("morro_addon5_smoothplastic_rojo", "126537059961464", { 196, 56, 43 }, "SmoothPlastic"),
				piece(
					"morro_addon5_smoothplastic_blanco",
					"76295410495646",
					{ 244, 244, 244 },
					"SmoothPlastic"
				),
				piece("morro_addon5_smoothplastic_azul", "78179680628969", { 31, 95, 168 }, "SmoothPlastic"),
			},
		},
	},
	["Callejón del Hojalatero"] = {
		base = {
			piece("hojalatero_body_brick", "110298283108472", { 176, 102, 74 }, "Brick"),
			piece("hojalatero_body_metal_acero", "125062404313107", { 140, 147, 155 }, "Metal"),
			piece("hojalatero_body_limestone", "131044460322635", { 210, 201, 180 }, "Limestone"),
			piece("hojalatero_body_slate", "134510024436017", { 74, 78, 84 }, "Slate"),
			piece("hojalatero_body_glass", "99509032564806", { 46, 74, 99 }, "Glass", 0.25),
			piece("hojalatero_body_metal", "117609298853189", { 201, 123, 58 }, "Metal"),
		},
		addons = {
			{
				piece("hojalatero_addon1_metal_acero", "94305205888491", { 140, 147, 155 }, "Metal"),
				piece("hojalatero_addon1_metal", "95013079920418", { 201, 123, 58 }, "Metal"),
			},
			{
				piece("hojalatero_addon2_limestone", "71186078280001", { 210, 201, 180 }, "Limestone"),
				piece("hojalatero_addon2_metal", "137019038040819", { 201, 123, 58 }, "Metal"),
				piece("hojalatero_addon2_metal_acero", "137497003889383", { 140, 147, 155 }, "Metal"),
			},
			{
				piece("hojalatero_addon3_metal_acero", "119944946816926", { 140, 147, 155 }, "Metal"),
				piece("hojalatero_addon3_slate", "108673510245125", { 74, 78, 84 }, "Slate"),
				piece("hojalatero_addon3_glass", "84418752011765", { 46, 74, 99 }, "Glass", 0.25),
			},
			{
				piece("hojalatero_addon4_brick", "124885679134185", { 176, 102, 74 }, "Brick"),
				piece("hojalatero_addon4_slate", "128144436896056", { 74, 78, 84 }, "Slate"),
				piece("hojalatero_addon4_glass", "84370228051392", { 46, 74, 99 }, "Glass", 0.25),
			},
			{
				piece("hojalatero_addon5_metal_acero", "93423147782073", { 140, 147, 155 }, "Metal"),
				piece("hojalatero_addon5_metal", "112283163694632", { 201, 123, 58 }, "Metal"),
			},
		},
	},
	["Bodega La Reserva"] = {
		base = {
			piece("bodega_wall", "96062558131335", BRICK, "Brick"),
			piece("bodega_base_dark", "110655451780948", { 42, 46, 51 }, "SmoothPlastic"),
			piece("bodega_base_glass", "124003684147313", GLASS, "Glass", 0.25),
			piece("bodega_base_limestone", "133495296764917", STONE, "Limestone"),
			piece("bodega_base_slate", "78852868380933", SLATE, "Slate"),
			piece("bodega_base_wood", "79772933935225", { 107, 74, 46 }, "Wood"),
		},
		addons = {
			{
				piece("bodega_addon1_red", "84764259555291", RED, "Fabric"),
				piece("bodega_addon1_wood", "84438214828559", { 107, 74, 46 }, "Wood"),
			},
			{
				piece("bodega_addon2_cream", "131208136447470", { 237, 229, 211 }, "SmoothPlastic"),
				piece("bodega_addon2_steel", "126665734693506", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("bodega_addon3_brick", "98140695944670", BRICK, "Brick"),
				piece("bodega_addon3_glass", "114582864770259", GLASS, "Glass", 0.25),
				piece("bodega_addon3_limestone", "110033467388023", STONE, "Limestone"),
			},
			{
				piece("bodega_addon4_gold", "123392296280782", { 201, 162, 39 }, "Metal"),
				piece("bodega_addon4_steel", "125781446129874", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("bodega_addon5_gold", "119575846485110", { 201, 162, 39 }, "Metal"),
				piece("bodega_addon5_limestone", "83408336475066", STONE, "Limestone"),
				piece("bodega_addon5_steel", "117689058796300", { 168, 174, 180 }, "Metal"),
			},
		},
	},
	["Cine Lux"] = {
		base = {
			piece("cine-wall", "71336473679427", BRICK, "Brick"),
			piece("cine-trim", "77475477580156", STONE, "Limestone"),
			piece("cine-glass", "121921872087774", GLASS, "Glass", 0.25),
			piece("cine-roof", "114543760508825", SLATE, "Slate"),
			piece("cine-sign", "76583737990361", RED, "SmoothPlastic"),
		},
		addons = {
			{
				piece("cine-addon1-hedge", "122262308128677", { 75, 107, 58 }, "Grass"),
				piece("cine-addon1-limestone", "108306691423975", STONE, "Limestone"),
				piece("cine-addon1-red", "113491450572214", RED, "Fabric"),
			},
			{
				piece("cine-addon2-cream", "86646242275127", { 237, 229, 211 }, "SmoothPlastic"),
				piece("cine-addon2-limestone", "118332360564004", STONE, "Limestone"),
				piece("cine-addon2-red", "110049613209192", RED, "Fabric"),
			},
			{
				piece("cine-addon3-brick", "123554905698866", BRICK, "Brick"),
				piece("cine-addon3-glass", "84747055926971", GLASS, "Glass", 0.25),
				piece("cine-addon3-limestone", "96942026871016", STONE, "Limestone"),
			},
			{
				piece("cine-addon4-cream", "71012732247378", { 237, 229, 211 }, "SmoothPlastic"),
				piece("cine-addon4-gold", "123115517950109", { 201, 162, 39 }, "Metal"),
				piece("cine-addon4-red", "115619028441877", RED, "Fabric"),
				piece("cine-addon4-steel", "98250470333975", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("cine-addon5-cream", "135807504654840", { 237, 229, 211 }, "SmoothPlastic"),
				piece("cine-addon5-gold", "122258833131116", { 201, 162, 39 }, "Metal"),
				piece("cine-addon5-limestone", "97550408016054", STONE, "Limestone"),
				piece("cine-addon5-red", "100335150180826", RED, "Fabric"),
				piece("cine-addon5-steel", "88574969270990", { 168, 174, 180 }, "Metal"),
			},
		},
	},
	["Pasaje Burbuja"] = {
		base = {
			piece("burbuja_body_brick", "103391980797160", { 176, 102, 74 }, "Brick"),
			piece("burbuja_body_limestone", "94640944009712", { 210, 201, 180 }, "Limestone"),
			piece("burbuja_body_slate", "76961577340298", { 74, 78, 84 }, "Slate"),
			piece("burbuja_body_glass", "118832065874377", { 46, 74, 99 }, "Glass", 0.25),
			piece("burbuja_body_metal_acero", "129620634725709", { 140, 147, 155 }, "Metal"),
			piece("burbuja_body_metal", "80753143796400", { 201, 123, 58 }, "Metal"),
		},
		addons = {
			{
				piece("burbuja_addon1_fabric_crema", "139372678526042", { 237, 229, 211 }, "Fabric"),
				piece("burbuja_addon1_metal", "133336562643174", { 201, 123, 58 }, "Metal"),
				piece("burbuja_addon1_slate", "135553394452541", { 74, 78, 84 }, "Slate"),
				piece("burbuja_addon1_limestone", "79077726228557", { 210, 201, 180 }, "Limestone"),
			},
			{
				piece("burbuja_addon2_glass", "113766000018074", { 46, 74, 99 }, "Glass", 0.25),
				piece("burbuja_addon2_metal", "124635660403203", { 201, 123, 58 }, "Metal"),
				piece("burbuja_addon2_slate", "134793553165362", { 74, 78, 84 }, "Slate"),
				piece("burbuja_addon2_metal_acero", "97628699334830", { 140, 147, 155 }, "Metal"),
			},
			{
				piece("burbuja_addon3_wood", "119781983875673", { 90, 58, 36 }, "Wood"),
				piece("burbuja_addon3_metal", "129514834243812", { 201, 123, 58 }, "Metal"),
				piece("burbuja_addon3_fabric_crema", "125163776717825", { 237, 229, 211 }, "Fabric"),
				piece("burbuja_addon3_limestone", "109380948746059", { 210, 201, 180 }, "Limestone"),
				piece("burbuja_addon3_grass", "96041340998037", { 75, 107, 58 }, "Grass"),
			},
			{
				piece("burbuja_addon4_limestone", "70850086137837", { 210, 201, 180 }, "Limestone"),
				piece("burbuja_addon4_glass", "113687019359330", { 46, 74, 99 }, "Glass", 0.25),
				piece("burbuja_addon4_metal_acero", "140297038342450", { 140, 147, 155 }, "Metal"),
				piece("burbuja_addon4_slate", "137757204815976", { 74, 78, 84 }, "Slate"),
				piece("burbuja_addon4_metal", "70659656958884", { 201, 123, 58 }, "Metal"),
			},
			{
				piece("burbuja_addon5_limestone", "74142914829231", { 210, 201, 180 }, "Limestone"),
				piece("burbuja_addon5_metal", "106311885398454", { 201, 123, 58 }, "Metal"),
				piece("burbuja_addon5_glass", "120445958150394", { 46, 74, 99 }, "Glass", 0.25),
				piece("burbuja_addon5_metal_acero", "111462530021716", { 140, 147, 155 }, "Metal"),
			},
		},
	},
	["Caldas"] = {
		base = {
			piece("caldas_body_glass", "122965442068541", { 46, 74, 99 }, "Glass", 0.25),
			piece("caldas_body_metal_acero", "100010827705328", { 168, 174, 180 }, "Metal"),
			piece("caldas_body_limestone", "140559333995860", { 210, 201, 180 }, "Limestone"),
			piece("caldas_body_brick", "103566331614280", { 176, 102, 74 }, "Brick"),
			piece("caldas_body_slate", "101812546670031", { 74, 78, 84 }, "Slate"),
			piece("caldas_body_grass", "103596263200563", { 75, 107, 58 }, "Grass"),
		},
		addons = {
			{
				piece("caldas_addon1_limestone", "98770696390795", { 210, 201, 180 }, "Limestone"),
				piece("caldas_addon1_slate", "124924543460287", { 74, 78, 84 }, "Slate"),
			},
			{
				piece("caldas_addon2_glass", "124781700021160", { 46, 74, 99 }, "Glass", 0.25),
				piece("caldas_addon2_metal_acero", "135934058178386", { 168, 174, 180 }, "Metal"),
				piece("caldas_addon2_slate", "120071911720672", { 74, 78, 84 }, "Slate"),
			},
			{
				piece("caldas_addon3_brick", "122908062624730", { 176, 102, 74 }, "Brick"),
				piece("caldas_addon3_glass", "104580131110865", { 46, 74, 99 }, "Glass", 0.25),
				piece("caldas_addon3_metal_acero", "109496020004691", { 168, 174, 180 }, "Metal"),
				piece("caldas_addon3_limestone", "87891951561064", { 210, 201, 180 }, "Limestone"),
				piece("caldas_addon3_slate", "105992745898819", { 74, 78, 84 }, "Slate"),
				piece("caldas_addon3_metal_cobre", "122360766459525", { 201, 123, 58 }, "Metal"),
			},
			{
				piece("caldas_addon4_glass", "93687494051252", { 46, 74, 99 }, "Glass", 0.25),
				piece("caldas_addon4_metal_acero", "128258494680013", { 168, 174, 180 }, "Metal"),
				piece("caldas_addon4_limestone", "114940466686741", { 210, 201, 180 }, "Limestone"),
				piece("caldas_addon4_brick", "75016798845943", { 176, 102, 74 }, "Brick"),
				piece("caldas_addon4_slate", "101675218711204", { 74, 78, 84 }, "Slate"),
			},
			{
				piece("caldas_addon5_limestone", "74581702331384", { 210, 201, 180 }, "Limestone"),
				piece("caldas_addon5_brick", "135383786739610", { 176, 102, 74 }, "Brick"),
				piece("caldas_addon5_glass", "139531223933789", { 46, 74, 99 }, "Glass", 0.25),
				piece("caldas_addon5_metal_cobre", "85578283082041", { 201, 123, 58 }, "Metal"),
			},
		},
	},
	["Calle del Cable"] = {
		base = {
			piece("cable_body_limestone", "112094634818212", { 210, 201, 180 }, "Limestone"),
			piece("cable_body_slate", "112430344342632", { 74, 78, 84 }, "Slate"),
			piece("cable_body_glass", "140184159985921", { 46, 74, 99 }, "Glass", 0.25),
			piece("cable_body_metal_acero", "90602875068166", { 140, 147, 155 }, "Metal"),
		},
		addons = {
			{
				piece("cable_addon1_metal_acero", "123140265460024", { 140, 147, 155 }, "Metal"),
				piece("cable_addon1_metal", "135231395837361", { 201, 123, 58 }, "Metal"),
				piece("cable_addon1_limestone", "96488576600476", { 210, 201, 180 }, "Limestone"),
			},
			{
				piece("cable_addon2_limestone", "117906736019774", { 210, 201, 180 }, "Limestone"),
				piece("cable_addon2_glass", "120381510980226", { 46, 74, 99 }, "Glass", 0.25),
				piece("cable_addon2_metal_acero", "111252003971356", { 140, 147, 155 }, "Metal"),
			},
			{
				piece("cable_addon3_metal_acero", "99501668254030", { 140, 147, 155 }, "Metal"),
				piece("cable_addon3_limestone", "124024575235266", { 210, 201, 180 }, "Limestone"),
			},
			{
				piece("cable_addon4_limestone", "80092103262161", { 210, 201, 180 }, "Limestone"),
				piece("cable_addon4_brick", "83815705939833", { 176, 102, 74 }, "Brick"),
				piece("cable_addon4_slate", "74179072403937", { 74, 78, 84 }, "Slate"),
				piece("cable_addon4_glass", "113722543527276", { 46, 74, 99 }, "Glass", 0.25),
				piece("cable_addon4_metal_acero", "70586870413240", { 140, 147, 155 }, "Metal"),
			},
			{
				piece("cable_addon5_limestone", "73176870634841", { 210, 201, 180 }, "Limestone"),
				piece("cable_addon5_metal_acero", "88725532235926", { 140, 147, 155 }, "Metal"),
				piece("cable_addon5_metal", "95550716005110", { 201, 123, 58 }, "Metal"),
			},
		},
	},
} :: { [string]: { base: { Piece }, addons: { { Piece } } } }

-- El mojón del nivel máximo. Su anillo se tiñe con el color de la zona en `BuildingView`.
ArtAssets.mojon = {
	stone = piece("marker_mojon_stone", "77126348395639", STONE, "Limestone"),
	ring = piece("marker_mojon_ring", "72497880426898", { 201, 123, 58 }, "Metal"),
}

-- La ficha taxi: su origen es la base de la ficha.
ArtAssets.taxi = {
	piece("taxi_cream", "109034949932647", { 237, 229, 211 }, "SmoothPlastic"),
	piece("taxi_dark", "90234802967497", { 42, 46, 51 }, "SmoothPlastic"),
	piece("taxi_glass", "100862088195781", GLASS, "Glass", 0.25),
	piece("taxi_steel", "91742839184724", { 168, 174, 180 }, "Metal"),
	piece("taxi_taxi", "124072967548133", { 245, 197, 24 }, "SmoothPlastic"),
} :: { Piece }

-- Mobiliario de la calle, por el `kind` que da `CityLayout.dressingFor`. Su origen es el centro de la base.
ArtAssets.street = {
	Tree = {
		piece("tree_bark", "74174494792219", { 74, 58, 44 }, "Wood"),
		piece("tree_leaf", "78926284968999", { 75, 107, 58 }, "Grass"),
		piece("tree_limestone", "119620634089187", STONE, "Limestone"),
		piece("tree_soil", "135956577114680", { 47, 42, 37 }, "Ground"),
	},
	Lamp = {
		piece("lamp_iron", "120735512294385", { 35, 40, 43 }, "Metal"),
		piece("lamp_lamp", "138721299588070", { 237, 229, 211 }, "SmoothPlastic"),
	},
	Bench = {
		piece("bench_iron", "110425970866167", { 35, 40, 43 }, "Metal"),
		piece("bench_wood", "87236384992095", { 122, 84, 51 }, "Wood"),
	},
	Crosswalk = {
		piece("crosswalk_paint", "119936557977117", { 222, 216, 200 }, "Concrete"),
	},
	Car = {
		piece("car_carbody", "80791874972658", { 52, 70, 94 }, "SmoothPlastic"),
		piece("car_glass", "130598677913277", GLASS, "Glass", 0.25),
		piece("car_dark", "71989356457981", { 42, 46, 51 }, "SmoothPlastic"),
		piece("car_steel", "134654656395339", { 168, 174, 180 }, "Metal"),
	},
} :: { [string]: { Piece } }

-- Tráfico: la pieza que se pinta de cada color y los colores, apagados y sin amarillo para que ningún coche
-- se confunda con un taxi de jugador.
ArtAssets.CAR_BODY = "car_carbody"
ArtAssets.carColors = {
	{ 52, 70, 94 },
	{ 110, 44, 44 },
	{ 150, 152, 150 },
	{ 205, 198, 180 },
	{ 68, 84, 72 },
	{ 88, 76, 96 },
	{ 60, 62, 66 },
}

-- Escena de la detención (PlayerArrested). La patrulla y su gorra van en un solo grupo cada una; la
-- cárcel es solo decorado en la casilla Tribunal. Su origen es el centro de la base, como el resto.
ArtAssets.patrol = {
	piece("patrol_navy", "87297540770701", { 27, 42, 74 }, "SmoothPlastic"),
	piece("patrol_white", "131708362246640", { 242, 242, 240 }, "SmoothPlastic"),
	piece("patrol_glass", "95895884922053", GLASS, "Glass", 0.25),
	piece("patrol_dark", "86978947567351", { 42, 46, 51 }, "SmoothPlastic"),
	piece("patrol_steel", "99832846083028", { 168, 174, 180 }, "Metal"),
	piece("patrol_sirenred", "137084094157299", { 214, 40, 40 }, "Neon"),
	piece("patrol_sirenblue", "125618270831213", { 31, 95, 214 }, "Neon"),
} :: { Piece }

ArtAssets.officerCap = {
	piece("officer_cap", "132578753396779", { 27, 42, 74 }, "Fabric"),
	piece("officer_gold", "128223182550092", { 201, 162, 39 }, "Metal"),
} :: { Piece }

ArtAssets.jail = {
	piece("jail_brick", "106699809242825", { 94, 58, 46 }, "Brick"),
	piece("jail_limestone", "130650667629657", { 210, 201, 180 }, "Limestone"),
	piece("jail_glass", "71451720766435", GLASS, "Glass", 0.25),
	piece("jail_steel", "83918567997732", { 168, 174, 180 }, "Metal"),
	piece("jail_dark", "91188963144926", { 42, 46, 51 }, "SmoothPlastic"),
	piece("jail_sign", "112253702709622", RED, "SmoothPlastic"),
} :: { Piece }

-- Zonas con la calle ya ambientada: la de la porción vertical. El plan 07 añade las demás.
ArtAssets.dressedZones = { "carmesi" }

-- Pintura desgastada de las casillas: texturas en blanco, teñidas con el color de la zona.
ArtAssets.roadPaint = {
	"rbxassetid://140160880545159",
	"rbxassetid://74331201053532",
	"rbxassetid://110850833671447",
}
-- Las propiedades llevan además la isla donde irán sus mejoras, en el lado del edificio.
ArtAssets.roadPaintIsland = {
	"rbxassetid://140317100777072",
	"rbxassetid://136446359469385",
	"rbxassetid://95495357299466",
}
-- Mallas de una propiedad en un nivel, o nil si aún no tiene modelo real.
function ArtAssets.piecesFor(name: string, level: number): { Piece }?
	local property = ArtAssets.properties[name]
	if property == nil then
		return nil
	end
	local pieces = table.clone(property.base)
	for order = 1, math.min(level, #property.addons) do
		table.move(property.addons[order], 1, #property.addons[order], #pieces + 1, pieces)
	end
	return pieces
end

-- Todas las mallas: lo que el servidor tiene que cargar.
function ArtAssets.all(): { Piece }
	local pieces: { Piece } = {}
	for _, property in ArtAssets.properties do
		table.move(property.base, 1, #property.base, #pieces + 1, pieces)
		for _, addon in property.addons do
			table.move(addon, 1, #addon, #pieces + 1, pieces)
		end
	end
	table.move(ArtAssets.taxi, 1, #ArtAssets.taxi, #pieces + 1, pieces)
	for _, kind in ArtAssets.street do
		table.move(kind, 1, #kind, #pieces + 1, pieces)
	end
	table.insert(pieces, ArtAssets.mojon.stone)
	table.insert(pieces, ArtAssets.mojon.ring)
	table.move(ArtAssets.patrol, 1, #ArtAssets.patrol, #pieces + 1, pieces)
	table.move(ArtAssets.officerCap, 1, #ArtAssets.officerCap, #pieces + 1, pieces)
	table.move(ArtAssets.jail, 1, #ArtAssets.jail, #pieces + 1, pieces)
	return pieces
end

return ArtAssets
