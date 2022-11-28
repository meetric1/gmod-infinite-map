// this file controls visual chunkloading and rendering
InfMap.megachunk_size = 10
InfMap.render_distance = 2
InfMap.filter.infmap_terrain_render = true // dont pass in chunks
InfMap.terrain_material = "infmap/flatgrass"

// chunkloading
local last_mega_chunk
InfMap.client_chunks = InfMap.client_chunks or {}
hook.Add("PropUpdateChunk", "infmap_terrain_init", function(ent, chunk, old_chunk)
	if ent == LocalPlayer() and chunk[3] < 100 then
		local _, mega_chunk = InfMap.localize_vector(chunk, InfMap.megachunk_size) mega_chunk[3] = 0
		local chunk_res_scale = InfMap.chunk_size * 2 * InfMap.megachunk_size * 2
		local chunk_scale = InfMap.chunk_size * 2
		local delta_chunk = mega_chunk - (last_mega_chunk or mega_chunk)
		local chunk_alloc = table.Copy(InfMap.client_chunks)
		local time = 0
		for y = -InfMap.render_distance, InfMap.render_distance do
			InfMap.client_chunks[y] = InfMap.client_chunks[y] or {}
			for x = -InfMap.render_distance, InfMap.render_distance do
				// if the chunk the current xy chunk is going to go to is outside of the render distance remove it
				if math.abs(x - delta_chunk[1]) > InfMap.render_distance or math.abs(y - delta_chunk[2]) > InfMap.render_distance then
					SafeRemoveEntity(InfMap.client_chunks[y][x])
					InfMap.client_chunks[y][x] = nil
				end

				if chunk_alloc[y + delta_chunk[2]] and chunk_alloc[y + delta_chunk[2]][x + delta_chunk[1]] then
					InfMap.client_chunks[y][x] = chunk_alloc[y + delta_chunk[2]][x + delta_chunk[1]]
				else
					InfMap.client_chunks[y][x] = nil
				end
				// create chunk if it doesnt exist
				if !IsValid(InfMap.client_chunks[y][x]) then 
					local e = ents.CreateClientside("infmap_terrain_render")
					e:Spawn()
					e:SetMaterial(InfMap.terrain_material)
					e:GenerateMesh(InfMap.height_function, (Vector(x, y, 0) + mega_chunk) * InfMap.megachunk_size * 2, time)
					e.CHUNK_OFFSET = Vector(x, y, 0) + mega_chunk
					InfMap.client_chunks[y][x] = e
					time = time + 0.01
				end

				local e = InfMap.client_chunks[y][x]
				if !e.RENDER_MESH then continue end
				e.RENDER_MESH.Matrix:SetTranslation(e.CHUNK_OFFSET * chunk_res_scale - chunk * chunk_scale)
			end
		end

		last_mega_chunk = mega_chunk
	end
end)

// update renderbounds for these entities since they can appear outside of the source bounds
local chunksize = Vector(1, 1, 0) * InfMap.chunk_size * InfMap.megachunk_size * 2
hook.Add("RenderScene", "infmap_update_renderbounds", function(eyePos)
	local color = math.Clamp((1 - InfMap.unlocalize_vector(EyePos(), LocalPlayer().CHUNK_OFFSET)[3] / 1950000) * 512, 0, 255)
	for y = -InfMap.render_distance, InfMap.render_distance do
		if !InfMap.client_chunks[y] then continue end
		for x = -InfMap.render_distance, InfMap.render_distance do
			local chunk = InfMap.client_chunks[y][x]
			if !IsValid(chunk) or !chunk.RENDER_MESH then continue end

			// set transparency
			chunk:SetRenderMode(color < 255 and RENDERMODE_TRANSCOLOR or RENDERMODE_NORMAL)
			chunk:SetColor(Color(255, 255, 255, color))

			// update render bounds when visible
			if color > 0 then
				chunk:SetLocalRenderBounds(eyePos, chunksize)
			end
		end
	end
end)

// bigass plane
local size = 2^31
local uvsize = size / 10000
local min = -1000000

local big_plane = Mesh()
big_plane:BuildFromTriangles({
	{pos = Vector(size, size, min), normal = Vector(0, 0, 1), u = uvsize, v = 0, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
	{pos = Vector(size, -size, min), normal = Vector(0, 0, 1), u = uvsize, v = uvsize, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
	{pos = Vector(-size, -size, min), normal = Vector(0, 0, 1), u = 0, v = uvsize, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
	{pos = Vector(size, size, min), normal = Vector(0, 0, 1), u = uvsize, v = 0, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
	{pos = Vector(-size, -size, min), normal = Vector(0, 0, 1), u = 0, v = uvsize, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
	{pos = Vector(-size, size, min), normal = Vector(0, 0, 1), u = 0, v = 0, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
})

local default_mat = Material(InfMap.terrain_material)
local top = Material("infmap/cubemap_top")
local right = Material("infmap/cubemap_right")
local front = Material("infmap/cubemap_front")
local back = Material("infmap/cubemap_back")
local left = Material("infmap/cubemap_left")
local bottom = Material("infmap/cubemap_bottom")
local render = render
hook.Add("PostDraw2DSkyBox", "infmap_terrain_skybox", function()	//draw bigass plane
	render.OverrideDepthEnable(true, false)

	local color = InfMap.unlocalize_vector(EyePos(), LocalPlayer().CHUNK_OFFSET)[3] / 1950000
	local cs = 100//InfMap.chunk_size
	local cs_2 = cs * 2

	// set transparency
	top:SetFloat("$alpha", color)
	right:SetFloat("$alpha", color)
	front:SetFloat("$alpha", color)
	back:SetFloat("$alpha", color)
	left:SetFloat("$alpha", color)
	bottom:SetFloat("$alpha", color)

	render.SetMaterial(top)
	render.DrawQuadEasy(EyePos() + Vector(0, 0, cs), Vector(0, 0, -1), cs_2, cs_2)

	render.SetMaterial(right)
	render.DrawQuadEasy(EyePos() + Vector(0, cs, 0), Vector(0, -1, 0), cs_2, cs_2)

	render.SetMaterial(front)
	render.DrawQuadEasy(EyePos() + Vector(cs, 0, 0), Vector(-1, 0, 0), cs_2, cs_2)

	render.SetMaterial(back)
	render.DrawQuadEasy(EyePos() + Vector(-cs, 0, 0), Vector(1, 0, 0), cs_2, cs_2)

	render.SetMaterial(left)
	render.DrawQuadEasy(EyePos() + Vector(0, -cs, 0), Vector(0, 1, 0), cs_2, cs_2)

	render.SetMaterial(bottom)
	render.DrawQuadEasy(EyePos() + Vector(0, 0, -cs), Vector(0, 0, 1), cs_2, cs_2)

	render.SetMaterial(default_mat)
	render.ResetModelLighting(2, 2, 2)
	render.SetLocalModelLights()
	default_mat:SetFloat("$alpha", 1)	// make it visible
	big_plane:Draw()

	render.OverrideDepthEnable(false, false)
end)

hook.Add("SetupWorldFog", "!infmap_fog", function()	// The Fog Is Coming
	if !LocalPlayer().CHUNK_OFFSET then return end
	render.FogStart(500000)
	render.FogMaxDensity(1)
	render.FogColor(153, 178, 204)
	//render.FogColor(180, 190, 200)
	render.FogEnd(800000)
	render.FogMode(MATERIAL_FOG_LINEAR)
	//return true
end)