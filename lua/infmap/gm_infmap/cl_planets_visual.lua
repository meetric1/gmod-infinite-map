// renders the spheres around the planets
InfMap.planet_render_distance = 3

local default_mats = {
	Material("shadertest/seamless2"),
	Material("shadertest/seamless3"),
	Material("shadertest/seamless4"),
	Material("shadertest/seamless5"),
	Material("shadertest/seamless6"),
	Material("shadertest/seamless7"),
	Material("shadertest/seamless8"),
}

hook.Add("PostDrawOpaqueRenderables", "infmap_planet_render", function()
	local render = render
	local client_offset = LocalPlayer().CHUNK_OFFSET
	if !client_offset then return end

	local color = InfMap.unlocalize_vector(EyePos(), LocalPlayer().CHUNK_OFFSET)[3] / 1950000
	if color < 0.1 then return end

	// reset lighting so planets dont do weird flashing shit
	local amb = render.GetAmbientLightColor()
	render.SetLocalModelLights()
	render.SetModelLighting(1, amb[1], amb[2], amb[3])
    render.SetModelLighting(3, amb[1], amb[2], amb[3])
    render.SetModelLighting(5, amb[1], amb[2], amb[3])
	render.SetModelLighting(0, 2, 2, 2)
    render.SetModelLighting(2, 2, 2, 2)
    render.SetModelLighting(4, 2, 2, 2)

	local prd = InfMap.planet_render_distance
	local _, megachunk = InfMap.localize_vector(client_offset, InfMap.planet_spacing * 0.5)
	for y = -prd, prd do
		for x = -prd, prd do
			local x = x + megachunk[1]
			local y = y + megachunk[2]
			local pos, radius, mat = InfMap.planet_info(x, y)
			local final_offset = pos - client_offset

			local len = final_offset:LengthSqr()
			local planet_res = 5
			if len < 4 then
				planet_res = 50
			elseif len < 64 then
				planet_res = 10
			end
			
			// draw planet
			default_mats[mat]:SetFloat("$alpha", color)	// draw planets as transparent when going up
			render.SetMaterial(default_mats[mat])
			render.DrawSphere(InfMap.unlocalize_vector(Vector(), final_offset), radius, planet_res, planet_res)
		end
	end
end)