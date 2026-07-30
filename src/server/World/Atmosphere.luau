--!strict
-- Lighting, sky and colour grading.
--
-- Set from code so the look is versioned with the rest of the project rather than
-- living as unversioned Studio properties someone nudges by accident.
--
-- Target look: warm late-afternoon Konoha — low golden sun, hazy distance, strong
-- enough contrast that the red roofs pop against the greenery.

local Lighting = game:GetService("Lighting")

local Atmosphere = {}

function Atmosphere.start()
	-- Future is where the emissive windows and gate lanterns actually read. It
	-- costs more than Voxel; if the 1660 Super struggles, turn this down to
	-- ShadowMap first.
	--
	-- pcall'd because Lighting.Technology is not reliably scriptable — it's a place
	-- property, and assigning it can throw. Unguarded, that error would abort the
	-- whole Bootstrap script and the village would never get built. Set it by hand
	-- in Studio (Lighting → Technology) if this warns.
	local ok = pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	if not ok then
		warn("[Atmosphere] couldn't set Lighting.Technology — set it to Future manually in Studio")
	end

	Lighting.Ambient = Color3.fromRGB(70, 68, 78)
	Lighting.OutdoorAmbient = Color3.fromRGB(126, 122, 132)
	Lighting.Brightness = 2.4
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.ExposureCompensation = 0.16
	Lighting.GlobalShadows = true

	-- 16:20 — long shadows down the main street without going orange-sunset.
	Lighting.ClockTime = 16.35
	Lighting.GeographicLatitude = 34
	Lighting.ColorShift_Top = Color3.fromRGB(255, 238, 214)
	Lighting.ColorShift_Bottom = Color3.fromRGB(96, 104, 122)

	-- Clear out anything from a previous run so re-running doesn't stack effects.
	for _, child in Lighting:GetChildren() do
		if
			child:IsA("Atmosphere")
			or child:IsA("Sky")
			or child:IsA("BloomEffect")
			or child:IsA("SunRaysEffect")
			or child:IsA("ColorCorrectionEffect")
			or child:IsA("DepthOfFieldEffect")
		then
			child:Destroy()
		end
	end

	-- Haze. Density is what sells the scale of the Hokage Rock at 1000 studs out.
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.34
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(206, 200, 188)
	atmosphere.Decay = Color3.fromRGB(146, 152, 168)
	atmosphere.Glare = 0.28
	atmosphere.Haze = 1.7
	atmosphere.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 15
	sky.MoonAngularSize = 11
	sky.StarCount = 2800
	sky.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 26
	bloom.Threshold = 1.05
	bloom.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.09
	rays.Spread = 0.28
	rays.Parent = Lighting

	-- Slight warm push and a touch of saturation. Kept gentle — heavy grading is
	-- the fastest way to make a stylised palette look muddy.
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Brightness = 0.015
	grade.Contrast = 0.1
	grade.Saturation = 0.09
	grade.TintColor = Color3.fromRGB(255, 250, 242)
	grade.Parent = Lighting

	print("[Atmosphere] lighting applied")
end

return Atmosphere
