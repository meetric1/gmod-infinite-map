AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= ""
ENT.PrintName		= ""
ENT.Author			= "Mee"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable		= false

if !InfMap then return end

if SERVER then return end	// clientside only entity

InfMap.uv_scale = 100
local function add_quad(tab, p1, p2, p3, p4, n1, n2)
	local tablen = #tab

	// first tri
	tab[tablen + 1] = {p1, 0, 			    0,	  		 	 n1}
	tab[tablen + 2] = {p2, InfMap.uv_scale, 0,    			 n1}
	tab[tablen + 3] = {p3, 0,	  			InfMap.uv_scale, n1}

	// second tri
	tab[tablen + 4] = {p3, 0, 	    		InfMap.uv_scale, n2}
	tab[tablen + 5] = {p2, InfMap.uv_scale, 0,  		     n2}
	tab[tablen + 6] = {p4, InfMap.uv_scale, InfMap.uv_scale, n2}
end

function ENT:GenerateMesh(heightFunction, chunk, time)	// pretty expensive function.. so we slowly generate data and then compile it into a mesh once we have it
	local megachunk_size = InfMap.megachunk_size
	self.CHUNK_MIN = 0
	self.CHUNK_MAX = 0

	self.TRIANGLES = {}
	self.COROUTINE = coroutine.create(function()
		coroutine.wait(time)
		for y = -megachunk_size, megachunk_size - 1 do
			for x = -megachunk_size, megachunk_size - 1 do
				local chunk_resolution = InfMap.chunk_resolution
				for i_y = 0, chunk_resolution - 1 do
					for i_x = 0, chunk_resolution - 1 do
						// chunk offset in world space
						local chunkoffsetx = chunk[1] + x
						local chunkoffsety = chunk[2] + y

						local i_x1 = (i_x    ) / chunk_resolution
						local i_y1 = (i_y    ) / chunk_resolution
						local i_x2 = (i_x + 1) / chunk_resolution
						local i_y2 = (i_y + 1) / chunk_resolution
						local min_pos_x = -InfMap.chunk_size + i_x1 * InfMap.chunk_size * 2
						local min_pos_y = -InfMap.chunk_size + i_y1 * InfMap.chunk_size * 2
						local max_pos_x = -InfMap.chunk_size + i_x2 * InfMap.chunk_size * 2
						local max_pos_y = -InfMap.chunk_size + i_y2 * InfMap.chunk_size * 2

						// the height of the vertex using the math function
						local vertexHeight1 = heightFunction(chunkoffsetx + i_x1, chunkoffsety + i_y1)
						local vertexHeight2 = heightFunction(chunkoffsetx + i_x1, chunkoffsety + i_y2)
						local vertexHeight3 = heightFunction(chunkoffsetx + i_x2, chunkoffsety + i_y1)
						local vertexHeight4 = heightFunction(chunkoffsetx + i_x2, chunkoffsety + i_y2)

						// vertex positions in local space
						local local_offset = InfMap.unlocalize_vector(Vector(InfMap.chunk_size, InfMap.chunk_size), Vector(x, y, 0))
						
						local vertexPos1 = Vector(min_pos_x, min_pos_y, vertexHeight1) + local_offset
						local vertexPos2 = Vector(min_pos_x, max_pos_y, vertexHeight2) + local_offset
						local vertexPos3 = Vector(max_pos_x, min_pos_y, vertexHeight3) + local_offset
						local vertexPos4 = Vector(max_pos_x, max_pos_y, vertexHeight4) + local_offset

						local normal1 = -(vertexPos1 - vertexPos2):Cross(vertexPos1 - vertexPos3)//:GetNormalized()
						local normal2 = -(vertexPos4 - vertexPos3):Cross(vertexPos4 - vertexPos2)//:GetNormalized()

						add_quad(self.TRIANGLES, vertexPos1, vertexPos2, vertexPos3, vertexPos4, normal1, normal2)
						self.CHUNK_MAX = math.max(self.CHUNK_MAX, math.max(math.max(vertexHeight1, vertexHeight2), math.max(vertexHeight3, vertexHeight4)))
						self.CHUNK_MIN = math.min(self.CHUNK_MIN, math.min(math.min(vertexHeight1, vertexHeight2), math.min(vertexHeight3, vertexHeight4)))
					end
				end
			end
			coroutine.yield()
		end
	end)
end

local default_mat = Material("models/wireframe")
function ENT:Think()
	local coro = self.COROUTINE
	if !coro then return end
	if coroutine.status(coro) == "suspended" then
		coroutine.resume(coro)
	else
		local mat = Matrix()
		mat:SetTranslation((self.CHUNK_OFFSET * InfMap.megachunk_size * 2 - LocalPlayer().CHUNK_OFFSET) * InfMap.chunk_size * 2)
		self.RENDER_MESH = {Mesh = Mesh(), Material = default_mat, Matrix = mat}

		local mesh = mesh
		mesh.Begin(self.RENDER_MESH.Mesh, MATERIAL_TRIANGLES, math.min(#self.TRIANGLES / 3, 2^15))
			for _, tri in ipairs(self.TRIANGLES) do
				mesh.Position(tri[1])
				mesh.TexCoord(0, tri[2], tri[3])
				mesh.Normal(tri[4])
				mesh.UserData(1, 1, 1, 1)
				mesh.AdvanceVertex()
			end
		mesh.End()
		table.Empty(self.TRIANGLES)
		self:SetRenderBoundsWS(-Vector(1, 1, 1) * 2^14, Vector(1, 1, 1) * 2^14)
		self.COROUTINE = nil
	end
end

// cursed localized renderbounds shit so clients dont get destroyed from massive render bounds
local sub_size = 2^14 - InfMap.chunk_size * 1.5	// how far out render bounds can be before outside of the map
function ENT:SetLocalRenderBounds(eyePos, size)
	local min, max = -size, size
	min[3] = self.CHUNK_MAX
	max[3] = self.CHUNK_MIN
	if max[3] - min[3] > 2^22 then return end	// hard cutoff because when render bounds gets too big it stops rendering, thanks source.
	local prop_dir = self.RENDER_MESH.Matrix:GetTranslation() - eyePos
	local shrunk = sub_size / prop_dir:Length()
	
	debugoverlay.Box(eyePos + prop_dir, min, max, 0, Color(255, 0, 255, 0))
	self:SetRenderBounds(eyePos + prop_dir * shrunk + min * shrunk, eyePos + prop_dir * shrunk + max * shrunk)
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

function ENT:OnRemove()
	if SERVER then return end
	table.Empty(self.TRIANGLES)
	self.TRIANGLES = nil
	if self.RENDER_MESH and IsValid(self.RENDER_MESH.Mesh) then
		self.RENDER_MESH.Mesh:Destroy()
	end
end