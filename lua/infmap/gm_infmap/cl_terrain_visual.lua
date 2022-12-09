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
				e.RENDER_MESH.Matrix:SetTranslation((e.CHUNK_OFFSET * InfMap.megachunk_size * 2 - chunk) * chunk_scale)
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
local size = 1000000000
local uvsize = 100000
local min = -100000
local big_plane = Mesh()
big_plane:BuildFromTriangles({
	{pos = Vector(size, size, min), normal = Vector(0, 0, 1), u = uvsize, v = 0, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
	{pos = Vector(size, -size, min), normal = Vector(0, 0, 1), u = uvsize, v = uvsize, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
	{pos = Vector(-size, -size, min), normal = Vector(0, 0, 1), u = 0, v = uvsize, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
	{pos = Vector(size, size, min), normal = Vector(0, 0, 1), u = uvsize, v = 0, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
	{pos = Vector(-size, -size, min), normal = Vector(0, 0, 1), u = 0, v = uvsize, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
	{pos = Vector(-size, size, min), normal = Vector(0, 0, 1), u = 0, v = 0, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
})

local render = render
local default_mat = Material(InfMap.terrain_material)
hook.Add("PostDraw2DSkyBox", "infmap_terrain_skybox", function()	//draw bigass plane
	render.OverrideDepthEnable(true, false)	// dont write to z buffer, this is in "skybox"
	render.SetMaterial(default_mat)
	render.ResetModelLighting(2, 2, 2)
	render.SetLocalModelLights()
	default_mat:SetFloat("$alpha", 1)	// make it visible
	local offset = Vector(LocalPlayer().CHUNK_OFFSET)
	offset[1] = offset[1] % 1000
	offset[2] = offset[2] % 1000
	local m = Matrix()
	m:SetTranslation(InfMap.unlocalize_vector(Vector(), -offset))
	cam.PushModelMatrix(m)
	big_plane:Draw()
	cam.PopModelMatrix()
	render.OverrideDepthEnable(false, false)
end)

// bigass plane part 2
local size = 10000000
local uvsize = 1
local min = 0

local cloud_plane = Mesh()
cloud_plane:BuildFromTriangles({
	{pos = Vector(size, size, min), normal = Vector(0, 0, 1), u = uvsize, v = 0, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
	{pos = Vector(size, -size, min), normal = Vector(0, 0, 1), u = uvsize, v = uvsize, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
	{pos = Vector(-size, -size, min), normal = Vector(0, 0, 1), u = 0, v = uvsize, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
	{pos = Vector(size, size, min), normal = Vector(0, 0, 1), u = uvsize, v = 0, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
	{pos = Vector(-size, -size, min), normal = Vector(0, 0, 1), u = 0, v = uvsize, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
	{pos = Vector(-size, size, min), normal = Vector(0, 0, 1), u = 0, v = 0, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
})

InfMap.cloud_rts = {}
InfMap.cloud_mats = {}

// coroutine so clouds dont rape fps when generating
local cloud_layers = 10
local cloud_coro = coroutine.create(function()
	for i = 1, cloud_layers do
		InfMap.cloud_rts[i] = GetRenderTarget("infmap_clouds" .. i, 512, 512)
		InfMap.cloud_mats[i] = CreateMaterial("infmap_clouds" .. i, "UnlitGeneric", {
			["$basetexture"] = InfMap.cloud_rts[i]:GetName(),
			["$model"] = "1",
			["$nocull"] = "1",
			["$translucent"] = "1",
		})
		render.ClearRenderTarget(InfMap.cloud_rts[i], Color(127, 127, 127, 0))
	end

	for y = 0, 511 do
		for i = 1, cloud_layers do
			render.PushRenderTarget(InfMap.cloud_rts[i]) cam.Start2D()
				for x = 0, 511 do
					local x1 = x// % (512 / 3)
					local y1 = y// % (512 / 3)
					local col = (InfMap.simplex.Noise3D(x1 / 30, y1 / 30, i / 50) - i * 0.015) * 1024 + (InfMap.simplex.Noise2D(x1 / 7, y1 / 7) + 1) * 128
					surface.SetDrawColor(255, 255, 255, col)
					surface.DrawRect(x, y, 1, 1)
				end
			cam.End2D() render.PopRenderTarget()
		end

		coroutine.yield()
	end
	//render.BlurRenderTarget(InfMap.cloud_rts[i], 1, 1, 1)
end)

hook.Add("PostDrawTranslucentRenderables", "infmap_clouds", function()
	local offset = Vector(LocalPlayer().CHUNK_OFFSET)	// copy vector, dont use original memory
	offset[1] = ((offset[1] + 166 + CurTime() * 0.5) % 332) - 166
	offset[2] = ((offset[2] + 166 + CurTime() * 0.5) % 332) - 166
	offset[3] = offset[3] - 10

	if coroutine.status(cloud_coro) == "suspended" then
		coroutine.resume(cloud_coro)
	end

	local m = Matrix()
	if offset[3] > 1 then
		for i = 0, cloud_layers - 1 do	// overlay 10 planes to give amazing 3d look
			render.SetMaterial(InfMap.cloud_mats[i + 1])
			m:SetTranslation(InfMap.unlocalize_vector(Vector(0, 0, i * 10000), -offset))
			cam.PushModelMatrix(m)
			cloud_plane:Draw()
			cam.PopModelMatrix()
		end
	else
		for i = cloud_layers - 1, 0, -1 do	// do same thing but render in reverse since we are under clouds
			render.SetMaterial(InfMap.cloud_mats[i + 1])
			m:SetTranslation(InfMap.unlocalize_vector(Vector(0, 0, i * 10000), -offset))
			cam.PushModelMatrix(m)
			cloud_plane:Draw()
			cam.PopModelMatrix()
		end
	end
end)

hook.Add("SetupWorldFog", "!infmap_fog", function()	// The Fog Is Coming
	local co = LocalPlayer().CHUNK_OFFSET
	if !co or co[3] > 14 then return end
	render.FogStart(500000)
	render.FogMaxDensity(math.min(0.5, 1.4 - co[3] * 0.1))
	render.FogColor(153, 178, 204)
	//render.FogColor(180, 190, 200)
	render.FogEnd(1000000)
	render.FogMode(MATERIAL_FOG_LINEAR)
	return true
end)
