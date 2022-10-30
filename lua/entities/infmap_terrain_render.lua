if game.GetMap() != "gm_infinite" then return end

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= ""
ENT.PrintName		= ""
ENT.Author			= "Mee"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable		= false

InfMap = InfMap or {}
InfMap.render_distance = 16

local uvscale = 300
local function add_quad(p1, p2, p3, p4, n1, n2)
	// first tri
	mesh.Position(p1)
	mesh.TexCoord(0, 0, 0)        // texture UV
	mesh.Normal(n1)
	mesh.UserData(1, 1, 1, 1)
	mesh.AdvanceVertex()

	mesh.Position(p2)
	mesh.TexCoord(0, uvscale, 0)
	mesh.Normal(n1)
	mesh.UserData(1, 1, 1, 1)
	mesh.AdvanceVertex()

	mesh.Position(p3)
	mesh.TexCoord(0, 0, uvscale)
	mesh.Normal(n1)
	mesh.UserData(1, 1, 1, 1)
	mesh.AdvanceVertex()

	// second tri
	mesh.Position(p3)
	mesh.TexCoord(0, 0, uvscale)
	mesh.Normal(n2)
	mesh.UserData(1, 1, 1, 1)
	mesh.AdvanceVertex()

	mesh.Position(p2)
	mesh.TexCoord(0, uvscale, 0)
	mesh.Normal(n2)
	mesh.UserData(1, 1, 1, 1)
	mesh.AdvanceVertex()

	mesh.Position(p4)
	mesh.TexCoord(0, uvscale, uvscale)
	mesh.Normal(n2)
	mesh.UserData(1, 1, 1, 1)
	mesh.AdvanceVertex()
end

local default_mat = Material("phoenix_storms/ps_grass")
function ENT:GenerateMesh(heightFunction, chunk, mat)
	if self.RENDER_MESH and IsValid(self.RENDER_MESH.Mesh) then
		self.RENDER_MESH.Mesh:Destroy()
		self.RENDER_MESH.Mesh = Mesh()
	else
		self.RENDER_MESH = {Mesh = Mesh(), Material = default_mat, Matrix = mat}
	end

    local mesh = mesh   // local lookup is faster than global
    local err, msg
	local render_distance = InfMap.render_distance
	local total_tris = (render_distance * 2 + 1) ^ 2
	
    mesh.Begin(self.RENDER_MESH.Mesh, MATERIAL_TRIANGLES, 2^13)  // 2 triangles per chunk
        err, msg = pcall(function()
			// no lod
			for y = -render_distance, render_distance - 1 do
				for x = -render_distance, render_distance - 1 do
					// chunk offset in world space
					local chunkoffsetx = chunk[1] + x
					local chunkoffsety = chunk[2] + y

					// the height of the vertex using the math function
					local vertexHeight1 = heightFunction(chunkoffsetx, 	   chunkoffsety    )
					local vertexHeight2 = heightFunction(chunkoffsetx, 	   chunkoffsety + 1)
					local vertexHeight3 = heightFunction(chunkoffsetx + 1, chunkoffsety    )
					local vertexHeight4 = heightFunction(chunkoffsetx + 1, chunkoffsety + 1)

					// vertex positions in local space
					local local_offset = InfMap.unlocalize_vector(Vector(InfMap.chunk_size, InfMap.chunk_size), Vector(x, y, 0))
					local vertexPos1 = Vector(-InfMap.chunk_size, -InfMap.chunk_size, vertexHeight1) + local_offset
					local vertexPos2 = Vector(-InfMap.chunk_size, InfMap.chunk_size, vertexHeight2) + local_offset
					local vertexPos3 = Vector(InfMap.chunk_size, -InfMap.chunk_size, vertexHeight3) + local_offset
					local vertexPos4 = Vector(InfMap.chunk_size, InfMap.chunk_size, vertexHeight4) + local_offset

					local normal1 = -(vertexPos1 - vertexPos2):Cross(vertexPos1 - vertexPos3)//:GetNormalized()
					local normal2 = -(vertexPos4 - vertexPos3):Cross(vertexPos4 - vertexPos2)//:GetNormalized()

					add_quad(vertexPos1, vertexPos2, vertexPos3, vertexPos4, normal1, normal2)
				end
			end

			// high lod
			/*
			local lod_table = {1.5, 2, 3, 6}
			for i = 1, #lod_table do
				local lod = lod_table[i]
				local lod_render_distance = lod * render_distance
				local lod_center = lod * render_distance * 0.5
				local cs = InfMap.chunk_size
				for y = -lod_render_distance, lod_render_distance - 1, lod do
					for x = -lod_render_distance, lod_render_distance - 1, lod do
						// if in middle chunk
						if !(x <= -lod_center or x >= lod_center or y <= -lod_center or y >= lod_center) then continue end

						// chunk offset in world space
						local chunkoffsetx = chunk[1] + x
						local chunkoffsety = chunk[2] + y

						// the height of the vertex using the math function
						local vertexHeight1 = heightFunction(chunkoffsetx, 	   chunkoffsety    )
						local vertexHeight2 = heightFunction(chunkoffsetx, 	   chunkoffsety + lod)
						local vertexHeight3 = heightFunction(chunkoffsetx + lod, chunkoffsety    )
						local vertexHeight4 = heightFunction(chunkoffsetx + lod, chunkoffsety + lod)

						// vertex positions in local space
						local local_offset = InfMap.unlocalize_vector(Vector(cs, cs), Vector(x, y, -chunk[3])) - Vector(0, 0, cs * lod)
						local vertexPos1 = Vector(-cs * lod, -cs * lod, vertexHeight1) + local_offset
						local vertexPos2 = Vector(-cs * lod, cs * lod, vertexHeight2) + local_offset
						local vertexPos3 = Vector(cs * lod, -cs * lod, vertexHeight3) + local_offset
						local vertexPos4 = Vector(cs * lod, cs * lod, vertexHeight4) + local_offset

						local normal1 = -(vertexPos1 - vertexPos2):Cross(vertexPos1 - vertexPos3)//:GetNormalized()
						local normal2 = -(vertexPos4 - vertexPos3):Cross(vertexPos4 - vertexPos2)//:GetNormalized()

						add_quad(vertexPos1, vertexPos2, vertexPos3, vertexPos4, normal1, normal2)
					end
				end
			end*/
        end)
    mesh.End()

    if !err then print(msg) end  // if there is an error, catch it and throw it outside of mesh.begin since you crash if mesh.end is not called
	local min = Vector(1, 1, 1) * -2^14
	local max = Vector(1, 1, 1) * 2^14
	self:SetRenderBounds(min, max)
end

function ENT:GetRenderMesh()
    if !self.RENDER_MESH then return end
    return self.RENDER_MESH
end

function ENT:Initialize()
    self:SetModel("models/Combine_Helicopter/helicopter_bomb01.mdl")
    self:SetSolid(SOLID_NONE)
    self:SetMoveType(MOVETYPE_NONE)
    self:DrawShadow(false)
end

if CLIENT then
	InfMap.client_chunks = InfMap.client_chunks or {}
	InfMap.client_meshes = InfMap.client_meshes or {}
	local last_big_chunk = Vector()
	local chunks_around_player = 2
    hook.Add("PropUpdateChunk", "infmap_terrain_init", function(ent, chunk, old_chunk)
        if ent == LocalPlayer() then
			local _, big_chunk = InfMap.localize_vector(chunk, InfMap.render_distance) big_chunk[3] = 0
			local chunk_res_scale = InfMap.chunk_size * 2 * InfMap.render_distance * 2
			local chunk_res_scale_2 = InfMap.chunk_size * InfMap.render_distance
			local offset = (chunk - big_chunk * InfMap.render_distance * 2) * InfMap.chunk_size * 2
			local delta_chunk = chunk - (old_chunk or chunk)
			for y = -chunks_around_player, chunks_around_player do
				InfMap.client_chunks[y] = InfMap.client_chunks[y] or {}
				InfMap.client_meshes[y] = InfMap.client_meshes[y] or {}
				for x = -chunks_around_player, chunks_around_player do
					// create chunk if it doesnt exist
					if !InfMap.client_chunks[y][x] then 
						local e = ents.CreateClientside("infmap_terrain_render")
						e:Spawn()
						e:GenerateMesh(InfMap.height_function, Vector(x, y, 0) * InfMap.render_distance * 2, Matrix())
						InfMap.client_chunks[y][x] = e
						InfMap.client_meshes[y][x] = e.RENDER_MESH.Mesh
					end

					local chunk_ent = InfMap.client_chunks[y][x]
					chunk_ent.RENDER_MESH.Matrix:SetTranslation(Vector(x, y) * chunk_res_scale - offset)

					if big_chunk != last_big_chunk then
						local dx = delta_chunk[1]	// calculus flashbacks
						local dy = delta_chunk[2]
						if InfMap.client_meshes[y + dy] and InfMap.client_meshes[y + dy][x + dx] then
							chunk_ent.RENDER_MESH.Mesh = InfMap.client_meshes[y + dy][x + dx]		//cant be directly set because it may be accessed again
						else
							chunk_ent.RENDER_MESH.Mesh = nil
						end
					end
				end
			end

			if last_big_chunk == big_chunk then return end

			// update meshes
			local i = 0
			for y = -chunks_around_player, chunks_around_player do
				for x = -chunks_around_player, chunks_around_player do
					if !IsValid(InfMap.client_chunks[y][x].RENDER_MESH.Mesh) then
						//i = i + 0.01
						local gen_x = x * InfMap.render_distance * 2 + big_chunk[1] * InfMap.render_distance * 2
						local gen_y = y * InfMap.render_distance * 2 + big_chunk[2] * InfMap.render_distance * 2
						//timer.Simple(i, function()
							InfMap.client_chunks[y][x]:GenerateMesh(InfMap.height_function, Vector(gen_x, gen_y, 0), InfMap.client_chunks[y][x].RENDER_MESH.Matrix)
							InfMap.client_meshes[y][x] = InfMap.client_chunks[y][x].RENDER_MESH.Mesh
						//end)
					end
					InfMap.client_meshes[y][x] = InfMap.client_chunks[y][x].RENDER_MESH.Mesh
				end
			end

			last_big_chunk = big_chunk
        end
    end)

	local size = 2^31
	local uvsize = size / 10000
	local min = -1000000
	local data = {
        {pos = Vector(size, size, min), normal = Vector(0, 0, 1), u = uvsize, v = 0, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
        {pos = Vector(size, -size, min), normal = Vector(0, 0, 1), u = uvsize, v = uvsize, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
        {pos = Vector(-size, -size, min), normal = Vector(0, 0, 1), u = 0, v = uvsize, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
        {pos = Vector(size, size, min), normal = Vector(0, 0, 1), u = uvsize, v = 0, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
        {pos = Vector(-size, -size, min), normal = Vector(0, 0, 1), u = 0, v = uvsize, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
        {pos = Vector(-size, size, min), normal = Vector(0, 0, 1), u = 0, v = 0, tangent = Vector(1, 0, 0), userdata = {1, 0, 0, -1}},
    }

	local big_plane = Mesh()
	big_plane:BuildFromTriangles(data)
	hook.Add("PostDraw2DSkyBox", "infmap_terrain_drawover", function()
		local mat = Matrix()
		local lpp = LocalPlayer():GetPos()
		mat:SetTranslation(-InfMap.unlocalize_vector(Vector(), Vector(0, 0, -10)))
		render.OverrideDepthEnable(true, false)
		render.SetMaterial(default_mat)
		cam.PushModelMatrix(mat)
		big_plane:Draw()
		cam.PopModelMatrix()
		render.OverrideDepthEnable(false, false)
	end)
end