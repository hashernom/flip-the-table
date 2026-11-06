--!strict
-- Reglas de la primera partida guiada. Son puras: dicen qué consejo toca para un evento de la mesa o
-- para la decisión que le llega al jugador, y solo si no lo ha visto ya. El cliente decide cuándo
-- enseñarlo y nunca detiene la partida por ello.
local Types = require("../../shared/rules/Types")

type Event = Types.Event

local GuidedMatchRules = {}

-- Largo máximo de un consejo, en caracteres: una frase que se lee de un vistazo.
GuidedMatchRules.MAX_LENGTH = 140

-- Qué consejo da cada evento. Los `Decision:*` no son eventos del motor: los crea el cliente cuando
-- le llega una decisión, con `decisionEvent`, para explicarla justo antes de tomarla.
local TIPS: { [string]: string } = {
	["Decision:AwaitBuy"] = "buy",
	PropertyBought = "buy",
	RentPaid = "rent",
	CardDrawn = "cards",
	["Decision:PerkDraft"] = "perks",
	PerkDrafted = "perks",
	RoundStarted = "overview",
	PactFormed = "pacts",
	PactBroken = "pacts",
	["Decision:Tribunal"] = "tribunal",
	PlayerArrested = "tribunal",
	BankruptcyDeclared = "ghost",
	GhostActed = "ghost",
}

-- Los consejos, en el orden en que suelen aparecer en una partida.
local ORDER: { string } = { "perks", "buy", "rent", "cards", "overview", "pacts", "tribunal", "ghost" }

function GuidedMatchRules.allTips(): { string }
	return table.clone(ORDER)
end

-- Evento del cliente para una decisión que acaba de llegarle.
function GuidedMatchRules.decisionEvent(phase: string): Event
	return { type = `Decision:{phase}` }
end

-- Consejo nuevo para un evento, o nil si no enseña nada o ya se vio.
function GuidedMatchRules.tipFor(event: Event, seenTips: { [string]: boolean }): string?
	local tip = TIPS[event.type]
	if tip == nil or seenTips[tip] == true then
		return nil
	end
	return tip
end

-- Solo se guía a quien no ha terminado ninguna partida. Sin perfil todavía no se sabe, y no se guía:
-- es peor repetirle la guía a quien ya juega que callar un consejo a quien empieza.
function GuidedMatchRules.shouldGuide(completedMatches: number?): boolean
	return completedMatches ~= nil and completedMatches <= 0
end

return GuidedMatchRules
