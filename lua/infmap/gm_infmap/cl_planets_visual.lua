// renders the spheres around the planets
local default_mat = Material("shadertest/seamless7")
InfMap.planet_render_distance = 3
hook.Add("PostDrawOpaqueRenderables", "infmap_planet_render", function()
	local client_offset = LocalPlayer().CHUNK_OFFSET
	if !client_offset then return end

	local prd = InfMap.planet_render_distance
	render.SetMaterial(default_mat)

	// reset lighting so planets dont do weird flashing shit
	render.SetLocalModelLights()
	render.SetModelLighting(1, 0.1, 0.1, 0.1)
    render.SetModelLighting(3, 0.1, 0.1, 0.1)
    render.SetModelLighting(5, 0.1, 0.1, 0.1)
	render.SetModelLighting(0, 1, 1, 1)
    render.SetModelLighting(2, 1, 1, 1)
    render.SetModelLighting(4, 1, 1, 1)

	local color = InfMap.unlocalize_vector(EyePos(), LocalPlayer().CHUNK_OFFSET)[3] / 1950000
	default_mat:SetFloat("$alpha", color)
	
	local _, megachunk = InfMap.localize_vector(client_offset, InfMap.planet_spacing * 0.5)
	for y = -prd, prd do
		for x = -prd, prd do
			local x = x + megachunk[1]
			local y = y + megachunk[2]

			local spacing = InfMap.planet_spacing / 2 - 1
			local random_x = math.floor(util.SharedRandom("X" .. x .. y, -spacing, spacing))
			local random_y = math.floor(util.SharedRandom("Y" .. x .. y, -spacing, spacing))
			local random_z = math.floor(util.SharedRandom("Z" .. x .. y, 0, 100))
			
			local planet_chunk = Vector(x * InfMap.planet_spacing + random_x, y * InfMap.planet_spacing + random_y, random_z + 125)
			//local planet_chunk = Vector(x * InfMap.planet_spacing, y * InfMap.planet_spacing, 125 + random_z)
			local final_offset = planet_chunk - client_offset

			local len = final_offset:LengthSqr()
			local planet_res = 5
			if len < 4 then
				planet_res = 50
			elseif len < 64 then
				planet_res = 10
			end
			
			render.DrawSphere(InfMap.unlocalize_vector(Vector(), final_offset), InfMap.chunk_size, planet_res, planet_res)
			//local bounds = Vector(InfMap.planet_spacing, InfMap.planet_spacing, 100) * InfMap.chunk_size
			//local db = Vector(x * InfMap.planet_spacing, y * InfMap.planet_spacing, 125 + 50) - client_offset
			//debugoverlay.Box(InfMap.unlocalize_vector(Vector(), db), -bounds, bounds, 0, Color(0, 255, 0, 0))
		end
	end
end)