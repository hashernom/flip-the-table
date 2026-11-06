--!strict
-- Música y efectos del cliente. Aplica `AudioRules`: cada efecto baja cuando suenan varios a la vez, la
-- música cambia con un fundido según el momento de la partida y cada canal tiene su volumen, que el
-- jugador ajusta en Ajustes. Una pieza sin id todavía (sin generar o sin aprobar) no suena: el director
-- no se inventa sonidos.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Audio = require("../../shared/config/Audio")
local AudioRules = require("./AudioRules")

export type MusicState = AudioRules.MusicState

local AudioDirector = {}

local folder: Folder? = nil
local musicVolume = Audio.defaultMusic
local effectsVolume = Audio.defaultEffects
local musicState: MusicState? = nil
local music: Sound? = nil
local musicId: string? = nil
local active: { Sound } = {}
local loops: { [string]: Sound? } = {}
local musicTween: Tween? = nil

local function container(): Folder
	local current = folder
	if current ~= nil and current.Parent ~= nil then
		return current
	end
	local made = Instance.new("Folder")
	made.Name = "FlipTheTableAudio"
	made.Parent = SoundService
	folder = made
	return made
end

local function sweep()
	local alive: { Sound } = {}
	for _, sound in active do
		if sound.Parent ~= nil and sound.IsPlaying then
			table.insert(alive, sound)
		end
	end
	active = alive
end

-- Efecto o ambiente. `opts.volume` multiplica el volumen propio de la pieza.
function AudioDirector.play(id: string, opts: { volume: number? }?)
	local spec = Audio.pieces[id]
	if spec == nil or spec.id == "" or effectsVolume <= 0 then
		return
	end
	sweep()
	-- Un ambiente en bucle no es un efecto: no cuenta para la mezcla y se para con `stop`.
	if spec.looped and loops[id] ~= nil then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = id
	sound.SoundId = spec.id
	sound.Looped = spec.looped
	local base = spec.volume * (if opts ~= nil and opts.volume ~= nil then opts.volume else 1)
	sound.Volume = AudioRules.volumeFor(base, effectsVolume, AudioRules.gainFor(#active + 1))
	sound.Parent = container()
	if spec.looped then
		loops[id] = sound
	else
		table.insert(active, sound)
	end
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
end

-- Para un ambiente en bucle.
function AudioDirector.stop(id: string)
	local sound = loops[id]
	loops[id] = nil
	if sound ~= nil then
		sound:Destroy()
	end
end

-- Sonido de un evento de la mesa, si tiene uno.
function AudioDirector.playEvent(eventType: string)
	local id = Audio.eventSounds[eventType]
	if id ~= nil then
		AudioDirector.play(id)
	end
end

local function fade(sound: Sound, volume: number, after: (() -> ())?)
	local info = TweenInfo.new(Audio.musicFadeSec, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local tween = TweenService:Create(sound, info, { Volume = volume })
	if sound == music then
		musicTween = tween
	end
	if after ~= nil then
		tween.Completed:Connect(after)
	end
	tween:Play()
end

local function musicTarget(spec: Audio.Piece): number
	return AudioRules.volumeFor(spec.volume, musicVolume, 1)
end

-- Cambia la música del momento con un fundido. La misma pieza no vuelve a empezar.
function AudioDirector.setMusicState(state: MusicState)
	musicState = state
	local id = AudioRules.musicFor(state)
	if id == musicId then
		return
	end
	musicId = id
	local previous = music
	music = nil
	if previous ~= nil then
		fade(previous, 0, function()
			previous:Destroy()
		end)
	end
	local spec = Audio.pieces[id]
	if spec == nil or spec.id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = id
	sound.SoundId = spec.id
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = container()
	sound:Play()
	music = sound
	fade(sound, musicTarget(spec))
end

function AudioDirector.musicState(): MusicState?
	return musicState
end

-- Volúmenes de los dos canales, de 0 a 1. La música se ajusta al momento; los efectos, desde el siguiente.
function AudioDirector.setVolumes(musicLevel: number, effectsLevel: number)
	musicVolume = math.clamp(musicLevel, 0, 1)
	effectsVolume = math.clamp(effectsLevel, 0, 1)
	local current = music
	local id = musicId
	if current ~= nil and id ~= nil then
		local spec = Audio.pieces[id]
		if spec ~= nil then
			-- Un fundido en curso pisaría el volumen nuevo: se corta antes de fijarlo.
			local running = musicTween
			if running ~= nil then
				running:Cancel()
				musicTween = nil
			end
			current.Volume = musicTarget(spec)
		end
	end
end

function AudioDirector.volumes(): (number, number)
	return musicVolume, effectsVolume
end

return AudioDirector
