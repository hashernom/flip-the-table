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
	["Neo Mundo"] = {
		base = {
			piece("neomundo_body_limestone", "86076701733749", { 210, 201, 180 }, "Limestone"),
			piece("neomundo_body_slate", "111219623442149", { 74, 78, 84 }, "Slate"),
			piece("neomundo_body_glass", "130126926231005", { 46, 74, 99 }, "Glass", 0.25),
			piece("neomundo_body_metal_acero", "99507851738342", { 168, 174, 180 }, "Metal"),
		},
		addons = {
			{
				piece("neomundo_addon1_metal_acero", "130833707934408", { 168, 174, 180 }, "Metal"),
				piece("neomundo_addon1_limestone", "79669579379401", { 210, 201, 180 }, "Limestone"),
				piece("neomundo_addon1_glass", "102521758884873", { 46, 74, 99 }, "Glass", 0.25),
			},
			{
				piece("neomundo_addon2_glass", "103274518476035", { 46, 74, 99 }, "Glass", 0.25),
				piece("neomundo_addon2_metal_acero", "92086157856579", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("neomundo_addon3_limestone", "78714009767749", { 210, 201, 180 }, "Limestone"),
				piece("neomundo_addon3_glass", "95118263387632", { 46, 74, 99 }, "Glass", 0.25),
				piece("neomundo_addon3_metal_acero", "84583415008560", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("neomundo_addon4_limestone", "89186602843119", { 210, 201, 180 }, "Limestone"),
				piece("neomundo_addon4_glass", "131252278037833", { 46, 74, 99 }, "Glass", 0.25),
				piece("neomundo_addon4_slate", "93344478073791", { 74, 78, 84 }, "Slate"),
				piece("neomundo_addon4_metal_acero", "103395579593604", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("neomundo_addon5_limestone", "108862046302221", { 210, 201, 180 }, "Limestone"),
				piece("neomundo_addon5_glass", "85394398292873", { 46, 74, 99 }, "Glass", 0.25),
				piece("neomundo_addon5_metal_oro", "85875072787087", { 201, 162, 39 }, "Metal"),
				piece("neomundo_addon5_metal_acero", "75037172955953", { 168, 174, 180 }, "Metal"),
			},
		},
	},
	["Centro Páez"] = {
		base = {
			piece("paez_body_limestone", "132821783960481", { 210, 201, 180 }, "Limestone"),
			piece("paez_body_glass", "94219728545150", { 46, 74, 99 }, "Glass", 0.25),
			piece("paez_body_metal_acero", "106977265224458", { 168, 174, 180 }, "Metal"),
			piece("paez_body_metal_cobre", "92174941008951", { 201, 123, 58 }, "Metal"),
			piece("paez_body_metal_oro", "104455951613215", { 201, 162, 39 }, "Metal"),
			piece("paez_body_slate", "134870318073642", { 74, 78, 84 }, "Slate"),
		},
		addons = {
			{
				piece("paez_addon1_metal_acero", "85494490897134", { 168, 174, 180 }, "Metal"),
				piece("paez_addon1_fabric_rojo", "127302039959262", { 196, 56, 43 }, "Fabric"),
				piece("paez_addon1_metal_magenta", "120825455136866", { 232, 93, 158 }, "Metal"),
			},
			{
				piece("paez_addon2_glass", "117156504956366", { 46, 74, 99 }, "Glass", 0.25),
				piece("paez_addon2_metal_acero", "110695045047139", { 168, 174, 180 }, "Metal"),
				piece("paez_addon2_limestone", "138745304525286", { 210, 201, 180 }, "Limestone"),
			},
			{
				piece("paez_addon3_limestone", "122568108582102", { 210, 201, 180 }, "Limestone"),
				piece("paez_addon3_metal_acero", "98843392000587", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("paez_addon4_limestone", "116305568096193", { 210, 201, 180 }, "Limestone"),
				piece("paez_addon4_glass", "119374241908207", { 46, 74, 99 }, "Glass", 0.25),
				piece("paez_addon4_metal_acero", "114250772741344", { 168, 174, 180 }, "Metal"),
				piece("paez_addon4_metal_cobre", "130735859461741", { 201, 123, 58 }, "Metal"),
			},
			{
				piece("paez_addon5_metal_cobre", "84750610147162", { 201, 123, 58 }, "Metal"),
				piece("paez_addon5_limestone", "77205482305082", { 210, 201, 180 }, "Limestone"),
			},
		},
	},
	["Plaza del Neón"] = {
		base = {
			piece("plazaneon_body_limestone", "109810562972669", { 210, 201, 180 }, "Limestone"),
			piece("plazaneon_body_glass", "97419427015404", { 46, 74, 99 }, "Glass", 0.25),
			piece("plazaneon_body_metal_acero", "123370943679532", { 168, 174, 180 }, "Metal"),
			piece("plazaneon_body_wood", "96096335238023", { 107, 74, 46 }, "Wood"),
			piece("plazaneon_body_slate", "105331868903093", { 74, 78, 84 }, "Slate"),
			piece("plazaneon_body_fabric_rojo", "138446669422556", { 196, 56, 43 }, "Fabric"),
		},
		addons = {
			{
				piece("plazaneon_addon1_fabric_rojo", "99097608118207", { 196, 56, 43 }, "Fabric"),
				piece("plazaneon_addon1_metal_magenta", "99389854636326", { 232, 93, 158 }, "Metal"),
				piece("plazaneon_addon1_metal_acero", "121761421980797", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("plazaneon_addon2_metal_acero", "82306427801752", { 168, 174, 180 }, "Metal"),
				piece("plazaneon_addon2_metal_magenta", "107353494732683", { 232, 93, 158 }, "Metal"),
				piece("plazaneon_addon2_limestone", "118313248793639", { 210, 201, 180 }, "Limestone"),
				piece("plazaneon_addon2_slate", "78270186219830", { 74, 78, 84 }, "Slate"),
			},
			{
				piece("plazaneon_addon3_slate", "118528556651634", { 74, 78, 84 }, "Slate"),
				piece("plazaneon_addon3_limestone", "105499535366180", { 210, 201, 180 }, "Limestone"),
				piece("plazaneon_addon3_metal_acero", "105150814865372", { 168, 174, 180 }, "Metal"),
				piece("plazaneon_addon3_metal_magenta", "128836883659155", { 232, 93, 158 }, "Metal"),
			},
			{
				piece("plazaneon_addon4_limestone", "116577150777063", { 210, 201, 180 }, "Limestone"),
				piece("plazaneon_addon4_glass", "105862400987249", { 46, 74, 99 }, "Glass", 0.25),
				piece("plazaneon_addon4_metal_acero", "123243249576000", { 168, 174, 180 }, "Metal"),
				piece("plazaneon_addon4_slate", "103095244608201", { 74, 78, 84 }, "Slate"),
				piece("plazaneon_addon4_metal_oro", "106098926854126", { 201, 162, 39 }, "Metal"),
			},
			{
				piece("plazaneon_addon5_limestone", "85719919806384", { 210, 201, 180 }, "Limestone"),
				piece("plazaneon_addon5_metal_acero", "120878106391291", { 168, 174, 180 }, "Metal"),
				piece("plazaneon_addon5_metal_oro", "131385565607475", { 201, 162, 39 }, "Metal"),
			},
		},
	},
	["Mercado de la Séptima"] = {
		base = {
			piece("mercado_body_limestone", "77471832714745", { 210, 201, 180 }, "Limestone"),
			piece("mercado_body_brick", "137006844915231", { 176, 102, 74 }, "Brick"),
			piece("mercado_body_slate", "136622029207832", { 74, 78, 84 }, "Slate"),
			piece("mercado_body_wood", "131311982670316", { 107, 74, 46 }, "Wood"),
			piece("mercado_body_glass", "119520924153027", { 46, 74, 99 }, "Glass", 0.25),
			piece("mercado_body_metal_acero", "104664109891974", { 168, 174, 180 }, "Metal"),
		},
		addons = {
			{
				piece("mercado_addon1_fabric_rojo", "122812051468101", { 196, 56, 43 }, "Fabric"),
				piece("mercado_addon1_wood", "83916935567879", { 107, 74, 46 }, "Wood"),
			},
			{
				piece("mercado_addon2_glass", "81105450440851", { 46, 74, 99 }, "Glass", 0.25),
				piece("mercado_addon2_limestone", "85145222835761", { 210, 201, 180 }, "Limestone"),
				piece("mercado_addon2_metal_acero", "95695111966899", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("mercado_addon3_limestone", "112432273273744", { 210, 201, 180 }, "Limestone"),
				piece("mercado_addon3_metal_naranja", "78132198744377", { 245, 158, 11 }, "Metal"),
				piece("mercado_addon3_glass", "109766746867033", { 46, 74, 99 }, "Glass", 0.25),
				piece("mercado_addon3_metal_acero", "108629379322945", { 168, 174, 180 }, "Metal"),
				piece("mercado_addon3_metal_oro", "115546801271105", { 201, 162, 39 }, "Metal"),
				piece("mercado_addon3_slate", "136367699387765", { 74, 78, 84 }, "Slate"),
			},
			{
				piece("mercado_addon4_brick", "109975518928155", { 176, 102, 74 }, "Brick"),
				piece("mercado_addon4_slate", "100364484689183", { 74, 78, 84 }, "Slate"),
				piece("mercado_addon4_limestone", "85583838116307", { 210, 201, 180 }, "Limestone"),
				piece("mercado_addon4_wood", "131957495311834", { 107, 74, 46 }, "Wood"),
				piece("mercado_addon4_metal_acero", "98845564068852", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("mercado_addon5_brick", "82849304132615", { 176, 102, 74 }, "Brick"),
				piece("mercado_addon5_limestone", "99048013177223", { 210, 201, 180 }, "Limestone"),
				piece("mercado_addon5_slate", "71279092049009", { 74, 78, 84 }, "Slate"),
				piece("mercado_addon5_metal_oro", "112426748312839", { 201, 162, 39 }, "Metal"),
				piece("mercado_addon5_glass", "131586654218098", { 46, 74, 99 }, "Glass", 0.25),
			},
		},
	},
	["llaneradas.com"] = {
		base = {
			piece("llaneradas_body_brick", "123897169745946", { 176, 102, 74 }, "Brick"),
			piece("llaneradas_body_slate", "131828391115375", { 74, 78, 84 }, "Slate"),
			piece("llaneradas_body_limestone", "89280355184234", { 210, 201, 180 }, "Limestone"),
			piece("llaneradas_body_wood", "77603557697254", { 107, 74, 46 }, "Wood"),
			piece("llaneradas_body_metal_acero", "130468251779472", { 168, 174, 180 }, "Metal"),
			piece("llaneradas_body_glass", "112107427982059", { 46, 74, 99 }, "Glass", 0.25),
		},
		addons = {
			{
				piece("llaneradas_addon1_wood", "99369335552054", { 107, 74, 46 }, "Wood"),
				piece("llaneradas_addon1_fabric_rojo", "77959320468794", { 196, 56, 43 }, "Fabric"),
			},
			{
				piece("llaneradas_addon2_limestone", "117882637087275", { 210, 201, 180 }, "Limestone"),
				piece("llaneradas_addon2_wood", "86314286769639", { 107, 74, 46 }, "Wood"),
			},
			{
				piece("llaneradas_addon3_brick", "125123145131525", { 176, 102, 74 }, "Brick"),
				piece("llaneradas_addon3_limestone", "110654565771166", { 210, 201, 180 }, "Limestone"),
				piece("llaneradas_addon3_metal_acero", "108923141374127", { 168, 174, 180 }, "Metal"),
				piece("llaneradas_addon3_wood", "128753075142042", { 107, 74, 46 }, "Wood"),
			},
			{
				piece("llaneradas_addon4_brick", "86476962455659", { 176, 102, 74 }, "Brick"),
				piece("llaneradas_addon4_glass", "110043906976731", { 46, 74, 99 }, "Glass", 0.25),
				piece("llaneradas_addon4_wood", "108026832709258", { 107, 74, 46 }, "Wood"),
				piece("llaneradas_addon4_limestone", "127093706308858", { 210, 201, 180 }, "Limestone"),
				piece("llaneradas_addon4_slate", "102699121901157", { 74, 78, 84 }, "Slate"),
			},
			{
				piece("llaneradas_addon5_brick", "86586809097039", { 176, 102, 74 }, "Brick"),
				piece("llaneradas_addon5_limestone", "125826402566245", { 210, 201, 180 }, "Limestone"),
				piece("llaneradas_addon5_metal_acero", "80032207687733", { 168, 174, 180 }, "Metal"),
				piece("llaneradas_addon5_metal_oro", "107665246412123", { 201, 162, 39 }, "Metal"),
			},
		},
	},
	["Calle del Azafrán"] = {
		base = {
			piece("azafran_body_brick", "123624330487661", { 176, 102, 74 }, "Brick"),
			piece("azafran_body_limestone", "71587529757545", { 210, 201, 180 }, "Limestone"),
			piece("azafran_body_slate", "124260390633490", { 74, 78, 84 }, "Slate"),
			piece("azafran_body_glass", "79621249259130", { 46, 74, 99 }, "Glass", 0.25),
			piece("azafran_body_wood", "119454273442182", { 107, 74, 46 }, "Wood"),
			piece("azafran_body_metal_acero", "97591832340356", { 168, 174, 180 }, "Metal"),
		},
		addons = {
			{
				piece("azafran_addon1_fabric_rojo", "129807180893598", { 196, 56, 43 }, "Fabric"),
				piece("azafran_addon1_wood", "96444822635125", { 107, 74, 46 }, "Wood"),
				piece("azafran_addon1_limestone", "107182728741522", { 210, 201, 180 }, "Limestone"),
			},
			{
				piece("azafran_addon2_wood", "81552343839720", { 107, 74, 46 }, "Wood"),
				piece("azafran_addon2_limestone", "99363072635858", { 210, 201, 180 }, "Limestone"),
			},
			{
				piece("azafran_addon3_brick", "101403010438182", { 176, 102, 74 }, "Brick"),
				piece("azafran_addon3_limestone", "110579261570994", { 210, 201, 180 }, "Limestone"),
				piece("azafran_addon3_metal_acero", "92860153760575", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("azafran_addon4_brick", "74534731874931", { 176, 102, 74 }, "Brick"),
				piece("azafran_addon4_wood", "133805355061496", { 107, 74, 46 }, "Wood"),
				piece("azafran_addon4_metal_acero", "111569453487548", { 168, 174, 180 }, "Metal"),
				piece("azafran_addon4_limestone", "119062961063989", { 210, 201, 180 }, "Limestone"),
				piece("azafran_addon4_slate", "100120291785769", { 74, 78, 84 }, "Slate"),
			},
			{
				piece("azafran_addon5_wood", "107944339946097", { 107, 74, 46 }, "Wood"),
				piece("azafran_addon5_limestone", "115647865106287", { 210, 201, 180 }, "Limestone"),
				piece("azafran_addon5_metal_oro", "138328505053018", { 201, 162, 39 }, "Metal"),
			},
		},
	},
	["Plaza del Jazz"] = {
		base = {
			piece("jazz_body_brick", "98441867480439", { 176, 102, 74 }, "Brick"),
			piece("jazz_body_limestone", "97434683895332", { 210, 201, 180 }, "Limestone"),
			piece("jazz_body_metal", "84237558852044", { 201, 123, 58 }, "Metal"),
			piece("jazz_body_slate", "135797905739561", { 74, 78, 84 }, "Slate"),
			piece("jazz_body_glass", "115823625283150", { 46, 74, 99 }, "Glass", 0.25),
			piece("jazz_body_wood", "125307180915586", { 107, 74, 46 }, "Wood"),
			piece("jazz_body_metal_acero", "131417758077939", { 168, 174, 180 }, "Metal"),
		},
		addons = {
			{
				piece("jazz_addon1_fabric_rojo", "86173757912531", { 196, 56, 43 }, "Fabric"),
				piece("jazz_addon1_metal", "74726670789219", { 201, 123, 58 }, "Metal"),
				piece("jazz_addon1_metal_acero", "87518798197751", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("jazz_addon2_wood", "94735711173236", { 107, 74, 46 }, "Wood"),
				piece("jazz_addon2_metal", "126119072611259", { 201, 123, 58 }, "Metal"),
			},
			{
				piece("jazz_addon3_metal_acero", "74840645122884", { 168, 174, 180 }, "Metal"),
				piece("jazz_addon3_metal", "133606293121018", { 201, 123, 58 }, "Metal"),
			},
			{
				piece("jazz_addon4_brick", "95774255129320", { 176, 102, 74 }, "Brick"),
				piece("jazz_addon4_limestone", "88463925977865", { 210, 201, 180 }, "Limestone"),
				piece("jazz_addon4_metal", "95348491904327", { 201, 123, 58 }, "Metal"),
				piece("jazz_addon4_glass", "76077228374431", { 46, 74, 99 }, "Glass", 0.25),
			},
			{
				piece("jazz_addon5_brick", "74217863468447", { 176, 102, 74 }, "Brick"),
				piece("jazz_addon5_metal", "105497783714788", { 201, 123, 58 }, "Metal"),
				piece("jazz_addon5_limestone", "109512584907406", { 210, 201, 180 }, "Limestone"),
			},
		},
	},
	["Vereda La Mata"] = {
		base = {
			piece("vereda_body_grass", "94314835860752", { 75, 107, 58 }, "Grass"),
			piece("vereda_body_limestone", "107319439555855", { 210, 201, 180 }, "Limestone"),
			piece("vereda_body_brick", "83627100670548", { 176, 102, 74 }, "Brick"),
			piece("vereda_body_wood", "105970296327242", { 90, 58, 36 }, "Wood"),
			piece("vereda_body_slate", "104788211747870", { 74, 78, 84 }, "Slate"),
			piece("vereda_body_glass", "98500855887566", { 46, 74, 99 }, "Glass", 0.25),
		},
		addons = {
			{
				piece("vereda_addon1_metal_acero", "116998854765615", { 168, 174, 180 }, "Metal"),
				piece("vereda_addon1_fabric_rojo", "130891097017823", { 196, 56, 43 }, "Fabric"),
			},
			{
				piece("vereda_addon2_grass", "87973149881999", { 75, 107, 58 }, "Grass"),
				piece("vereda_addon2_limestone", "124474878609158", { 210, 201, 180 }, "Limestone"),
			},
			{
				piece("vereda_addon3_wood", "78831408116439", { 90, 58, 36 }, "Wood"),
			},
			{
				piece("vereda_addon4_glass", "130469777855092", { 46, 74, 99 }, "Glass", 0.25),
				piece("vereda_addon4_wood", "79870982544750", { 90, 58, 36 }, "Wood"),
				piece("vereda_addon4_limestone", "83001867765391", { 210, 201, 180 }, "Limestone"),
				piece("vereda_addon4_brick", "134073251181753", { 176, 102, 74 }, "Brick"),
				piece("vereda_addon4_slate", "130572394313971", { 74, 78, 84 }, "Slate"),
			},
			{
				piece("vereda_addon5_limestone", "104395766581948", { 210, 201, 180 }, "Limestone"),
				piece("vereda_addon5_brick", "80235819400354", { 176, 102, 74 }, "Brick"),
				piece("vereda_addon5_metal_acero", "103206398921669", { 168, 174, 180 }, "Metal"),
				piece("vereda_addon5_metal_limon", "112534855996743", { 250, 204, 21 }, "Metal"),
				piece("vereda_addon5_metal_oro", "133705657313162", { 201, 162, 39 }, "Metal"),
			},
		},
	},
	["Villa Margarita"] = {
		base = {
			piece("villa_body_smoothplastic_azul", "138799697130954", { 53, 99, 140 }, "SmoothPlastic"),
			piece("villa_body_wood", "80323131862529", { 107, 74, 46 }, "Wood"),
			piece("villa_body_smoothplastic_blanco", "98114866961324", { 228, 223, 211 }, "SmoothPlastic"),
			piece("villa_body_limestone", "72928945988093", { 210, 201, 180 }, "Limestone"),
			piece("villa_body_glass", "111697135931168", { 46, 74, 99 }, "Glass", 0.25),
			piece("villa_body_slate", "96629276511209", { 74, 78, 84 }, "Slate"),
		},
		addons = {
			{
				piece("villa_addon1_limestone", "89198818986459", { 210, 201, 180 }, "Limestone"),
				piece("villa_addon1_wood", "104619538747454", { 107, 74, 46 }, "Wood"),
				piece("villa_addon1_fabric_rojo", "94712127900664", { 196, 56, 43 }, "Fabric"),
			},
			{
				piece("villa_addon2_grass_cesped", "75472727837399", { 110, 143, 78 }, "Grass"),
				piece("villa_addon2_grass_seto", "79050716968499", { 74, 107, 58 }, "Grass"),
				piece("villa_addon2_wood", "85649483772888", { 107, 74, 46 }, "Wood"),
			},
			{
				piece(
					"villa_addon3_smoothplastic_blanco",
					"128062842733399",
					{ 228, 223, 211 },
					"SmoothPlastic"
				),
				piece("villa_addon3_limestone", "104807723348858", { 210, 201, 180 }, "Limestone"),
				piece("villa_addon3_wood", "84928684189225", { 107, 74, 46 }, "Wood"),
			},
			{
				piece("villa_addon4_smoothplastic_azul", "102901783776263", { 53, 99, 140 }, "SmoothPlastic"),
				piece("villa_addon4_glass", "79212539839262", { 46, 74, 99 }, "Glass", 0.25),
				piece(
					"villa_addon4_smoothplastic_blanco",
					"72881864966099",
					{ 228, 223, 211 },
					"SmoothPlastic"
				),
				piece("villa_addon4_limestone", "114044409248981", { 210, 201, 180 }, "Limestone"),
				piece("villa_addon4_slate", "99350344031732", { 74, 78, 84 }, "Slate"),
			},
			{
				piece("villa_addon5_smoothplastic_azul", "140721797838083", { 53, 99, 140 }, "SmoothPlastic"),
				piece("villa_addon5_glass", "98202448183200", { 46, 74, 99 }, "Glass", 0.25),
				piece(
					"villa_addon5_smoothplastic_blanco",
					"126976054522481",
					{ 228, 223, 211 },
					"SmoothPlastic"
				),
				piece("villa_addon5_limestone", "130134222108364", { 210, 201, 180 }, "Limestone"),
				piece("villa_addon5_metal", "116211582840570", { 201, 123, 58 }, "Metal"),
			},
		},
	},
	["Panadería La Espiga"] = {
		base = {
			piece("espiga_body_brick", "83857237067402", { 176, 102, 74 }, "Brick"),
			piece("espiga_body_limestone", "86731299352641", { 210, 201, 180 }, "Limestone"),
			piece("espiga_body_wood", "75061150756774", { 90, 58, 36 }, "Wood"),
			piece("espiga_body_glass", "83561690480861", { 46, 74, 99 }, "Glass", 0.25),
			piece("espiga_body_metal_acero", "129498894064289", { 168, 174, 180 }, "Metal"),
			piece("espiga_body_slate", "72273289673155", { 74, 78, 84 }, "Slate"),
		},
		addons = {
			{
				piece("espiga_addon1_fabric_rojo", "80819796663870", { 196, 56, 43 }, "Fabric"),
				piece("espiga_addon1_metal_acero", "87464596660682", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("espiga_addon2_fabric_rojo", "123404630039180", { 196, 56, 43 }, "Fabric"),
				piece("espiga_addon2_wood", "138549751343452", { 90, 58, 36 }, "Wood"),
				piece("espiga_addon2_metal_acero", "113157966694137", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("espiga_addon3_brick", "135477692016467", { 176, 102, 74 }, "Brick"),
				piece("espiga_addon3_limestone", "129957927708691", { 210, 201, 180 }, "Limestone"),
				piece("espiga_addon3_metal_acero", "71284932654542", { 168, 174, 180 }, "Metal"),
				piece("espiga_addon3_metal_oro", "78763033075460", { 201, 162, 39 }, "Metal"),
			},
			{
				piece("espiga_addon4_glass", "70965937748053", { 46, 74, 99 }, "Glass", 0.25),
				piece("espiga_addon4_limestone", "82626645920473", { 210, 201, 180 }, "Limestone"),
				piece("espiga_addon4_wood", "80513704842202", { 90, 58, 36 }, "Wood"),
				piece("espiga_addon4_metal_acero", "71606215099055", { 168, 174, 180 }, "Metal"),
				piece("espiga_addon4_brick", "135367158769867", { 176, 102, 74 }, "Brick"),
				piece("espiga_addon4_slate", "82773924365953", { 74, 78, 84 }, "Slate"),
			},
			{
				piece("espiga_addon5_brick", "131125180353925", { 176, 102, 74 }, "Brick"),
				piece("espiga_addon5_limestone", "79626073814047", { 210, 201, 180 }, "Limestone"),
				piece("espiga_addon5_metal_acero", "126487036299234", { 168, 174, 180 }, "Metal"),
				piece("espiga_addon5_metal_limon", "97922521415715", { 250, 204, 21 }, "Metal"),
				piece("espiga_addon5_metal_oro", "70725600273805", { 201, 162, 39 }, "Metal"),
			},
		},
	},
	["Muelle de los Pescadores"] = {
		base = {
			piece("muelle_body_brick", "80486369165718", { 176, 102, 74 }, "Brick"),
			piece("muelle_body_limestone", "103978780906147", { 210, 201, 180 }, "Limestone"),
			piece("muelle_body_slate", "96731419968659", { 74, 78, 84 }, "Slate"),
			piece("muelle_body_wood", "137476619427301", { 107, 74, 46 }, "Wood"),
			piece("muelle_body_metal_acero", "131898389708094", { 168, 174, 180 }, "Metal"),
		},
		addons = {
			{
				piece("muelle_addon1_fabric_rojo", "85078728248054", { 196, 56, 43 }, "Fabric"),
				piece("muelle_addon1_metal_acero", "100470111488943", { 168, 174, 180 }, "Metal"),
				piece("muelle_addon1_wood", "97023886033429", { 107, 74, 46 }, "Wood"),
			},
			{
				piece("muelle_addon2_limestone", "77069725731775", { 210, 201, 180 }, "Limestone"),
				piece("muelle_addon2_slate", "76380117209283", { 74, 78, 84 }, "Slate"),
				piece("muelle_addon2_metal_acero", "91956996083042", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("muelle_addon3_slate", "138642333258284", { 74, 78, 84 }, "Slate"),
				piece("muelle_addon3_metal_acero", "133876536295487", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("muelle_addon4_limestone", "88274803086708", { 210, 201, 180 }, "Limestone"),
				piece("muelle_addon4_slate", "103038960597336", { 74, 78, 84 }, "Slate"),
				piece("muelle_addon4_metal_acero", "95997220268313", { 168, 174, 180 }, "Metal"),
				piece("muelle_addon4_glass", "118372469344164", { 46, 74, 99 }, "Glass", 0.25),
			},
			{
				piece("muelle_addon5_metal_acero", "129577521214676", { 168, 174, 180 }, "Metal"),
				piece("muelle_addon5_limestone", "78763495774305", { 210, 201, 180 }, "Limestone"),
				piece("muelle_addon5_metal_esmeralda", "89060101754325", { 16, 185, 129 }, "Metal"),
				piece("muelle_addon5_metal_oro", "91436282202079", { 201, 162, 39 }, "Metal"),
			},
		},
	},
	["Astillero Neptuno"] = {
		base = {
			piece("astillero_body_brick", "77317841801014", { 176, 102, 74 }, "Brick"),
			piece("astillero_body_limestone", "70771737178858", { 210, 201, 180 }, "Limestone"),
			piece("astillero_body_glass", "139080412419937", { 46, 74, 99 }, "Glass", 0.25),
			piece("astillero_body_metal_acero", "108223092379207", { 168, 174, 180 }, "Metal"),
			piece("astillero_body_slate", "84284130567232", { 74, 78, 84 }, "Slate"),
			piece("astillero_body_wood", "109411517409792", { 107, 74, 46 }, "Wood"),
			piece("astillero_body_metal_esmeralda", "139102702258924", { 16, 185, 129 }, "Metal"),
		},
		addons = {
			{
				piece("astillero_addon1_metal_acero", "83903329411799", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("astillero_addon2_metal_acero", "79832907933939", { 168, 174, 180 }, "Metal"),
				piece("astillero_addon2_wood", "108414822245421", { 107, 74, 46 }, "Wood"),
			},
			{
				piece("astillero_addon3_metal_acero", "87358403759690", { 168, 174, 180 }, "Metal"),
				piece("astillero_addon3_metal_esmeralda", "81808100130349", { 16, 185, 129 }, "Metal"),
				piece("astillero_addon3_glass", "82870304761927", { 46, 74, 99 }, "Glass", 0.25),
			},
			{
				piece("astillero_addon4_limestone", "92103148525308", { 210, 201, 180 }, "Limestone"),
				piece("astillero_addon4_slate", "122208975551435", { 74, 78, 84 }, "Slate"),
				piece("astillero_addon4_metal_acero", "88158410867775", { 168, 174, 180 }, "Metal"),
				piece("astillero_addon4_glass", "108563683771769", { 46, 74, 99 }, "Glass", 0.25),
			},
			{
				piece("astillero_addon5_metal_acero", "115594188882382", { 168, 174, 180 }, "Metal"),
				piece("astillero_addon5_metal_esmeralda", "81872110573930", { 16, 185, 129 }, "Metal"),
				piece("astillero_addon5_metal_oro", "86345238199135", { 201, 162, 39 }, "Metal"),
			},
		},
	},
	["Acuario La Sirena"] = {
		base = {
			piece("acuario_body_limestone", "117421869769509", { 210, 201, 180 }, "Limestone"),
			piece("acuario_body_metal_acero", "137409626272219", { 168, 174, 180 }, "Metal"),
			piece("acuario_body_wood", "84758901910357", { 107, 74, 46 }, "Wood"),
			piece("acuario_body_glass", "135620699955291", { 46, 74, 99 }, "Glass", 0.25),
			piece("acuario_body_slate", "110218372091276", { 74, 78, 84 }, "Slate"),
		},
		addons = {
			{
				piece("acuario_addon1_metal_acero", "95683019766736", { 168, 174, 180 }, "Metal"),
				piece("acuario_addon1_metal_esmeralda", "94918943644289", { 16, 185, 129 }, "Metal"),
			},
			{
				piece("acuario_addon2_metal_acero", "116021930232766", { 168, 174, 180 }, "Metal"),
				piece("acuario_addon2_glass", "102977045678298", { 46, 74, 99 }, "Glass", 0.25),
			},
			{
				piece("acuario_addon3_limestone", "72374126695064", { 210, 201, 180 }, "Limestone"),
				piece("acuario_addon3_glass", "91350302746031", { 46, 74, 99 }, "Glass", 0.25),
				piece("acuario_addon3_metal_acero", "76661624606727", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("acuario_addon4_limestone", "86871348217811", { 210, 201, 180 }, "Limestone"),
				piece("acuario_addon4_slate", "90894983316186", { 74, 78, 84 }, "Slate"),
				piece("acuario_addon4_glass", "92486048761523", { 46, 74, 99 }, "Glass", 0.25),
				piece("acuario_addon4_metal_acero", "95873083625048", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("acuario_addon5_limestone", "113156499098731", { 210, 201, 180 }, "Limestone"),
				piece("acuario_addon5_metal_esmeralda", "113150342575026", { 16, 185, 129 }, "Metal"),
				piece("acuario_addon5_glass", "100047430599618", { 46, 74, 99 }, "Glass", 0.25),
				piece("acuario_addon5_metal_acero", "131844599506598", { 168, 174, 180 }, "Metal"),
				piece("acuario_addon5_metal_oro", "92521203645660", { 201, 162, 39 }, "Metal"),
			},
		},
	},
	["Versalles 1"] = {
		base = {
			piece("versalles1_body_grass_cesped", "119628839796444", { 110, 143, 78 }, "Grass"),
			piece("versalles1_body_limestone", "88845007151307", { 210, 201, 180 }, "Limestone"),
			piece("versalles1_body_glass", "130780081411045", { 46, 74, 99 }, "Glass", 0.25),
			piece("versalles1_body_wood", "136879403292714", { 107, 74, 46 }, "Wood"),
			piece("versalles1_body_slate", "109324726711439", { 74, 78, 84 }, "Slate"),
		},
		addons = {
			{
				piece("versalles1_addon1_limestone", "121496367120219", { 210, 201, 180 }, "Limestone"),
				piece("versalles1_addon1_metal_acero", "130177484706325", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("versalles1_addon2_limestone", "94208386502553", { 210, 201, 180 }, "Limestone"),
				piece("versalles1_addon2_grass_seto", "128260466514409", { 74, 107, 58 }, "Grass"),
			},
			{
				piece("versalles1_addon3_limestone", "106403678356256", { 210, 201, 180 }, "Limestone"),
				piece("versalles1_addon3_wood", "129505733950564", { 107, 74, 46 }, "Wood"),
				piece("versalles1_addon3_glass", "116234463153851", { 46, 74, 99 }, "Glass", 0.25),
				piece("versalles1_addon3_slate", "96176932353280", { 74, 78, 84 }, "Slate"),
			},
			{
				piece("versalles1_addon4_limestone", "136806986180018", { 210, 201, 180 }, "Limestone"),
				piece("versalles1_addon4_wood", "131906589059302", { 107, 74, 46 }, "Wood"),
				piece("versalles1_addon4_fabric_rojo", "135828725082897", { 196, 56, 43 }, "Fabric"),
			},
			{
				piece("versalles1_addon5_limestone", "126111428942677", { 210, 201, 180 }, "Limestone"),
				piece("versalles1_addon5_wood", "78431462302768", { 107, 74, 46 }, "Wood"),
				piece("versalles1_addon5_metal_acero", "107354693874460", { 168, 174, 180 }, "Metal"),
				piece("versalles1_addon5_metal_oro", "82747391356886", { 201, 162, 39 }, "Metal"),
				piece("versalles1_addon5_metal_violeta", "87702461138752", { 139, 92, 246 }, "Metal"),
			},
		},
	},
	["Versalles 2"] = {
		base = {
			piece("versalles2_body_brick", "88634114086342", { 176, 102, 74 }, "Brick"),
			piece("versalles2_body_wood", "135314760042883", { 107, 74, 46 }, "Wood"),
			piece("versalles2_body_limestone", "79827843996412", { 210, 201, 180 }, "Limestone"),
			piece("versalles2_body_glass", "95314774292218", { 46, 74, 99 }, "Glass", 0.25),
			piece("versalles2_body_slate", "118759950407033", { 74, 78, 84 }, "Slate"),
		},
		addons = {
			{
				piece("versalles2_addon1_metal_acero", "78278577875201", { 168, 174, 180 }, "Metal"),
				piece("versalles2_addon1_limestone", "117077127816696", { 210, 201, 180 }, "Limestone"),
				piece("versalles2_addon1_wood", "123919362694705", { 107, 74, 46 }, "Wood"),
				piece("versalles2_addon1_fabric_rojo", "118023146014732", { 196, 56, 43 }, "Fabric"),
			},
			{
				piece("versalles2_addon2_grass_cesped", "96829496676068", { 110, 143, 78 }, "Grass"),
				piece("versalles2_addon2_limestone", "102731822738890", { 210, 201, 180 }, "Limestone"),
				piece("versalles2_addon2_grass_seto", "109828289123514", { 74, 107, 58 }, "Grass"),
			},
			{
				piece("versalles2_addon3_brick", "134462268710030", { 176, 102, 74 }, "Brick"),
				piece("versalles2_addon3_limestone", "109503639142464", { 210, 201, 180 }, "Limestone"),
				piece("versalles2_addon3_slate", "139545878301141", { 74, 78, 84 }, "Slate"),
			},
			{
				piece("versalles2_addon4_brick", "138965545927936", { 176, 102, 74 }, "Brick"),
				piece("versalles2_addon4_wood", "120271129609963", { 107, 74, 46 }, "Wood"),
				piece("versalles2_addon4_limestone", "111076796503987", { 210, 201, 180 }, "Limestone"),
				piece("versalles2_addon4_glass", "110641618679942", { 46, 74, 99 }, "Glass", 0.25),
				piece("versalles2_addon4_slate", "131944894756295", { 74, 78, 84 }, "Slate"),
			},
			{
				piece("versalles2_addon5_brick", "79447538381161", { 176, 102, 74 }, "Brick"),
				piece("versalles2_addon5_limestone", "132951269310420", { 210, 201, 180 }, "Limestone"),
				piece("versalles2_addon5_metal_acero", "106199794947120", { 168, 174, 180 }, "Metal"),
				piece("versalles2_addon5_metal_oro", "82857526353956", { 201, 162, 39 }, "Metal"),
				piece("versalles2_addon5_metal_violeta", "110745046223130", { 139, 92, 246 }, "Metal"),
			},
		},
	},
	["Observatorio Cerro Azul"] = {
		base = {
			piece("observatorio_body_limestone", "115710759941131", { 210, 201, 180 }, "Limestone"),
			piece("observatorio_body_slate", "78726837888791", { 74, 78, 84 }, "Slate"),
			piece("observatorio_body_glass", "116365858449410", { 46, 74, 99 }, "Glass", 0.25),
			piece("observatorio_body_metal_acero", "77189302094912", { 168, 174, 180 }, "Metal"),
		},
		addons = {
			{
				piece("observatorio_addon1_metal_acero", "80709612993123", { 168, 174, 180 }, "Metal"),
				piece("observatorio_addon1_metal_oro", "129381335565733", { 201, 162, 39 }, "Metal"),
			},
			{
				piece("observatorio_addon2_limestone", "93132071106618", { 210, 201, 180 }, "Limestone"),
				piece("observatorio_addon2_metal_acero", "105225056317674", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("observatorio_addon3_metal_acero", "103079307061228", { 168, 174, 180 }, "Metal"),
				piece("observatorio_addon3_metal_oro", "128970355469083", { 201, 162, 39 }, "Metal"),
			},
			{
				piece("observatorio_addon4_limestone", "97135860503753", { 210, 201, 180 }, "Limestone"),
				piece("observatorio_addon4_slate", "129776313049618", { 74, 78, 84 }, "Slate"),
				piece("observatorio_addon4_glass", "125039940162507", { 46, 74, 99 }, "Glass", 0.25),
			},
			{
				piece("observatorio_addon5_metal_acero", "71617354481173", { 168, 174, 180 }, "Metal"),
				piece("observatorio_addon5_limestone", "133018400776597", { 210, 201, 180 }, "Limestone"),
				piece("observatorio_addon5_metal_oro", "105891345207447", { 201, 162, 39 }, "Metal"),
			},
		},
	},
	["D.T"] = {
		base = {
			piece("dt_body_limestone", "124687125795797", { 210, 201, 180 }, "Limestone"),
			piece("dt_body_glass", "101732932096226", { 46, 74, 99 }, "Glass", 0.25),
			piece("dt_body_metal", "111370929697491", { 168, 174, 180 }, "Metal"),
		},
		addons = {
			{
				piece("dt_addon1_metal", "79953502763927", { 168, 174, 180 }, "Metal"),
				piece("dt_addon1_metal_anil", "115132331435916", { 79, 70, 229 }, "Metal"),
				piece("dt_addon1_glass", "111204261252160", { 46, 74, 99 }, "Glass", 0.25),
			},
			{
				piece("dt_addon2_metal", "110379514565057", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("dt_addon3_metal", "100998763617492", { 168, 174, 180 }, "Metal"),
				piece("dt_addon3_limestone", "110628858900809", { 210, 201, 180 }, "Limestone"),
			},
			{
				piece("dt_addon4_limestone", "74606516488374", { 210, 201, 180 }, "Limestone"),
				piece("dt_addon4_slate", "95149081102750", { 74, 78, 84 }, "Slate"),
				piece("dt_addon4_glass", "90521567255759", { 46, 74, 99 }, "Glass", 0.25),
				piece("dt_addon4_metal", "108129051602607", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("dt_addon5_metal", "120917599258100", { 168, 174, 180 }, "Metal"),
				piece("dt_addon5_metal_oro", "71903028716068", { 201, 162, 39 }, "Metal"),
			},
		},
	},
	["Torres de Aragón"] = {
		base = {
			piece("aragon_body_glass", "101916434742598", { 46, 74, 99 }, "Glass", 0.25),
			piece("aragon_body_grass", "132706101177556", { 75, 107, 58 }, "Grass"),
			piece("aragon_body_limestone", "114808485285190", { 210, 201, 180 }, "Limestone"),
			piece("aragon_body_metal_cobre", "122065316996231", { 201, 123, 58 }, "Metal"),
			piece("aragon_body_smoothplastic_azul", "103767754139071", { 31, 95, 168 }, "SmoothPlastic"),
			piece("aragon_body_slate", "119345582879055", { 74, 78, 84 }, "Slate"),
		},
		addons = {
			{
				piece("aragon_addon1_glass", "109628168586202", { 46, 74, 99 }, "Glass", 0.25),
				piece("aragon_addon1_limestone", "137920384265174", { 210, 201, 180 }, "Limestone"),
				piece("aragon_addon1_metal_acero", "81387146787352", { 168, 174, 180 }, "Metal"),
				piece("aragon_addon1_wood", "132929746607305", { 107, 74, 46 }, "Wood"),
			},
			{
				piece("aragon_addon2_grass", "130736858178091", { 75, 107, 58 }, "Grass"),
				piece("aragon_addon2_wood", "98684386313745", { 107, 74, 46 }, "Wood"),
			},
			{
				piece("aragon_addon3_limestone", "126333205886949", { 210, 201, 180 }, "Limestone"),
				piece("aragon_addon3_metal_acero", "81347675399441", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("aragon_addon4_glass", "113494244665255", { 46, 74, 99 }, "Glass", 0.25),
				piece("aragon_addon4_limestone", "97360546229261", { 210, 201, 180 }, "Limestone"),
				piece("aragon_addon4_smoothplastic_azul", "84568110446006", { 31, 95, 168 }, "SmoothPlastic"),
				piece("aragon_addon4_slate", "137798473098061", { 74, 78, 84 }, "Slate"),
			},
			{
				piece("aragon_addon5_limestone", "122797450642134", { 210, 201, 180 }, "Limestone"),
				piece("aragon_addon5_metal_acero", "131624785085157", { 168, 174, 180 }, "Metal"),
				piece("aragon_addon5_metal_cobre", "121046813122595", { 201, 123, 58 }, "Metal"),
				piece("aragon_addon5_smoothplastic_azul", "83242378758310", { 31, 95, 168 }, "SmoothPlastic"),
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
