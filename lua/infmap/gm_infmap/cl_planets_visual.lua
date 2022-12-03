// renders the spheres around the planets
local atmosphere = Material("infmap/atmosphere")
hook.Add("PostDrawOpaqueRenderables", "infmap_planet_render", function()
	local render = render
	local client_offset = LocalPlayer().CHUNK_OFFSET
	if !client_offset then return end

	local color = InfMap.unlocalize_vector(EyePos(), LocalPlayer().CHUNK_OFFSET)[3] / 1950000
	if color < 0.1 then return end

	// reset lighting so planets dont do weird flashing shit
	local amb = render.GetAmbientLightColor() * 2
	render.SetLocalModelLights()
	render.SetModelLighting(1, amb[1], amb[2], amb[3])
    render.SetModelLighting(3, amb[1], amb[2], amb[3])
    render.SetModelLighting(5, 0, 0, 0)
	render.SetModelLighting(0, amb[1], amb[2], amb[3])
    render.SetModelLighting(2, amb[1], amb[2], amb[3])
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
			local texture = InfMap.planet_outside_materials[mat]
			texture:SetFloat("$alpha", color)	// draw planets as transparent when going up
			render.SetMaterial(texture)
			render.DrawSphere(InfMap.unlocalize_vector(Vector(), final_offset), radius, planet_res, planet_res)

			if len > 0 then continue end
			atmosphere:SetVector("$color", Vector(0.66, 0.86, 0.95))
			atmosphere:SetFloat("$alpha", 0.1)
			render.SetMaterial(atmosphere)
			render.DrawSphere(InfMap.unlocalize_vector(Vector(), final_offset), -radius, planet_res, planet_res)
		end
	end
end)