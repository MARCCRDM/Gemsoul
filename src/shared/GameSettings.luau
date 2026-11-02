--[[
	A player's settings (the ⚙ in the top bar: Client.SettingsUI), saved with
	their profile (Server: "SaveSettings", PlayerData's profile.Settings) so
	they follow them to any server or device.

	  Music        0..1   the songs' loudness (Client.Music's sound group)
	  MusicOn      bool   music at all
	  Effects      0..1   menu and combat sounds' loudness
	  EffectsOn    bool   those sounds at all
	  Brightness   0..1   the picture: 0 darkest, 0.5 as made, 1 brightest

	Pure, for the server, the client and tests.

	  GameSettings.Defaults
	  GameSettings.clean(t) -> settings    any table (a save, a request) made
	                                       safe: known keys only, in range,
	                                       defaults for the rest
	  GameSettings.music(s) -> 0..1        what the music plays at
	  GameSettings.effects(s) -> 0..1      what the effects play at
	  GameSettings.brightness(s) -> number the picture's lift (a colour
	                                       grade's Brightness: -0.14..+0.14)
]]
local GameSettings = {}

GameSettings.Defaults = { Music = 1, MusicOn = true, Effects = 1, EffectsOn = true, Brightness = 0.5 }
GameSettings.BrightnessRange = 0.28 -- (the grade's Brightness from darkest to brightest)

local function level(v: any, default: number): number
	local n = tonumber(v)
	if n == nil or n ~= n then
		return default
	end
	return math.clamp(math.floor(n * 100 + 0.5) / 100, 0, 1)
end

function GameSettings.clean(t: any)
	t = if type(t) == "table" then t else {}
	local d = GameSettings.Defaults
	return {
		Music = level(t.Music, d.Music),
		MusicOn = if type(t.MusicOn) == "boolean" then t.MusicOn else d.MusicOn,
		Effects = level(t.Effects, d.Effects),
		EffectsOn = if type(t.EffectsOn) == "boolean" then t.EffectsOn else d.EffectsOn,
		Brightness = level(t.Brightness, d.Brightness),
	}
end

function GameSettings.music(s): number
	s = GameSettings.clean(s)
	return if s.MusicOn then s.Music else 0
end

function GameSettings.effects(s): number
	s = GameSettings.clean(s)
	return if s.EffectsOn then s.Effects else 0
end

function GameSettings.brightness(s): number
	s = GameSettings.clean(s)
	return (s.Brightness - 0.5) * GameSettings.BrightnessRange
end

return GameSettings
