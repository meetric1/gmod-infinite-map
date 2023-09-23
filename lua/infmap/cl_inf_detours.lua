// metatable fuckery
local EntityMT = FindMetaTable("Entity")
local PhysObjMT = FindMetaTable("PhysObj")

local clamp = math.Clamp
local function clamp_vector(pos, max)
	return Vector(clamp(pos[1], -max, max), clamp(pos[2], -max, max), clamp(pos[3], -max, max))
end

local function invalid_chunk(e1, e2)
	return !e1.CHUNK_OFFSET or !e2.CHUNK_OFFSET
end

EntityMT.InfMap_GetPos = EntityMT.InfMap_GetPos or EntityMT.GetPos
function EntityMT:GetPos()
	if invalid_chunk(self, LocalPlayer()) then return self:InfMap_GetPos(pos) end
	return InfMap.unlocalize_vector(self:InfMap_GetPos(), self.CHUNK_OFFSET - LocalPlayer().CHUNK_OFFSET)
end

// clamp setpos or it spams console
EntityMT.InfMap_SetPos = EntityMT.InfMap_SetPos or EntityMT.SetPos
function EntityMT:SetPos(pos)
	local pos = clamp_vector(pos, InfMap.source_bounds[1])
	return self:InfMap_SetPos(pos)
end

EntityMT.InfMap_LocalToWorld = EntityMT.InfMap_LocalToWorld or EntityMT.LocalToWorld
function EntityMT:LocalToWorld(pos)
	if invalid_chunk(self, LocalPlayer()) then return self:InfMap_LocalToWorld(pos) end
	return InfMap.unlocalize_vector(self:InfMap_LocalToWorld(pos), self.CHUNK_OFFSET - LocalPlayer().CHUNK_OFFSET)
end

EntityMT.InfMap_WorldSpaceCenter = EntityMT.InfMap_WorldSpaceCenter or EntityMT.WorldSpaceCenter
function EntityMT:WorldSpaceCenter()
	if invalid_chunk(self, LocalPlayer()) then return self:InfMap_WorldSpaceCenter() end
	return InfMap.unlocalize_vector(self:InfMap_WorldSpaceCenter(), self.CHUNK_OFFSET - LocalPlayer().CHUNK_OFFSET)
end

EntityMT.InfMap_WorldSpaceAABB = EntityMT.InfMap_WorldSpaceAABB or EntityMT.WorldSpaceAABB
function EntityMT:WorldSpaceAABB()
	local v1, v2 = self:InfMap_WorldSpaceAABB()
	if invalid_chunk(self, LocalPlayer()) then return v1, v2 end
	return InfMap.unlocalize_vector(v1, self.CHUNK_OFFSET - LocalPlayer().CHUNK_OFFSET), InfMap.unlocalize_vector(v2, self.CHUNK_OFFSET - LocalPlayer().CHUNK_OFFSET)
end

EntityMT.InfMap_GetBonePosition = EntityMT.InfMap_GetBonePosition or EntityMT.GetBonePosition
function EntityMT:GetBonePosition(index)
	local pos, ang = self:InfMap_GetBonePosition(index)
	if !pos or !ang then // bones are weird
		return pos, ang 
	end	

	if invalid_chunk(self, LocalPlayer()) then return pos, ang end
	pos = InfMap.unlocalize_vector(pos, self.CHUNK_OFFSET - LocalPlayer().CHUNK_OFFSET)
	return pos, ang
end

EntityMT.InfMap_SetRenderBounds = EntityMT.InfMap_SetRenderBounds or EntityMT.SetRenderBounds
function EntityMT:SetRenderBounds(min, max, add)
	if self.RENDER_BOUNDS then
		self.RENDER_BOUNDS = {min, max}
	end
	return self:InfMap_SetRenderBounds(min, max, add)
end

InfMap.FindInBox = InfMap.FindInBox or ents.FindInBox
function ents.FindInBox(v1, v2)
	local entlist = ents.GetAll()
	local results = {}
	for _, ent in ipairs(entlist) do
		if ent:WorldSpaceCenter():WithinAABox(v1,v2) then table.insert(results,ent) end
	end
	return results
end

InfMap.FindInSphere = InfMap.FindInSphere or ents.FindInSphere
function ents.FindInSphere(pos, radius)
	local entlist = ents.GetAll()
	local results = {}
	local radSqr = radius * radius
	for k, v in ipairs(entlist) do
		if v:WorldSpaceCenter():DistToSqr(pos) <= radSqr then table.insert(results,v) end
	end
	return results
end

InfMap.FindInCone = InfMap.FindInCone or ents.FindInCone
function ents.FindInCone(pos, normal, radius, angle_cos)
	// not sure why, but findincone uses a box instead of sphere
	local entlist = ents.FindInBox(pos - Vector(radius, radius, radius), pos + Vector(radius, radius, radius))
	local results = {}
	for k,v in ipairs(entlist) do
		local dot = normal:Dot((v:GetPos() - pos):GetNormalized())
		if dot >= angle_cos then table.insert(results, v) end
	end
	return results
end

// clamp setpos or it spams console
PhysObjMT.InfMap_SetPos = PhysObjMT.InfMap_SetPos or PhysObjMT.SetPos
function PhysObjMT:SetPos(pos)
	local pos = clamp_vector(pos, InfMap.source_bounds[1])
	return self:InfMap_SetPos(pos)
end

// traces shouldnt appear when shot from other chunks
hook.Add("EntityFireBullets", "infmap_detour", function(ent, data)
	if ent.CHUNK_OFFSET != LocalPlayer().CHUNK_OFFSET then
		data.Tracer = 0
		return true
	end
end)

// traceline
// faster lookup
local istable = istable
local IsEntity = IsEntity
local function modify_trace_data(orig_data, trace_func, extra)
	local data = {}
	for k, v in pairs(orig_data) do
		data[k] = v
	end
	local start_offset = LocalPlayer().CHUNK_OFFSET or Vector()
	// #2 create filter and only hit entities in your chunk
	local old_filter = data.filter
	if !old_filter then 
		data.filter = function(e) 
			return e.CHUNK_OFFSET == start_offset
		end
	elseif IsEntity(old_filter) then // rip efficiency
		data.filter = function(e)
			return e.CHUNK_OFFSET == start_offset and e != old_filter
		end 
	elseif istable(old_filter) then	
		data.filter = function(e)
			for i = 1, #old_filter do 
				if e == old_filter[i] then 
					return false
				end 
			end
			return e.CHUNK_OFFSET == start_offset
		end
	else // must be function
		data.filter = function(e)
			return old_filter(e) and e.CHUNK_OFFSET == start_offset
		end
	end
	local hit_data = trace_func(data, extra)
	local hit_ent = hit_data.Entity
	if IsValid(hit_ent) then
		if InfMap.disable_pickup[hit_ent:GetClass()] then
			hit_data.Entity = game.GetWorld()
			hit_data.HitWorld = true
			hit_data.NonHitWorld = false // what the fuck garry?
		end
	end
	return hit_data
end
// traceline
InfMap.TraceLine = InfMap.TraceLine or util.TraceLine
function util.TraceLine(data)
	return modify_trace_data(data, InfMap.TraceLine)
end
// hull traceline
InfMap.TraceHull = InfMap.TraceHull or util.TraceHull
function util.TraceHull(data)
	return modify_trace_data(data, InfMap.TraceHull)
end
// entity traceline
InfMap.TraceEntity = InfMap.TraceEntity or util.TraceEntity
function util.TraceEntity(data, ent)
	return modify_trace_data(data, InfMap.TraceEntity, ent)
end

// particle detour
net.Receive("infmap_particle", function()
	local name = net.ReadString()
	local pos = Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat())
	local ang = net.ReadAngle()
	local ent = net.ReadEntity()
	ParticleEffect(name, pos, ang, ent)
end)

// effects detour
local sqrdist = InfMap.chunk_size * InfMap.chunk_size * 8
net.Receive("infmap_effectdata", function()
	local effect = net.ReadString()
	local override = net.ReadBool()

	local effectdata = EffectData()
	effectdata:SetAngles(net.ReadAngle())
	effectdata:SetAttachment(net.ReadInt(32))
	effectdata:SetColor(net.ReadInt(32))
	effectdata:SetDamageType(net.ReadInt(32))
	effectdata:SetEntity(net.ReadEntity())
	effectdata:SetFlags(net.ReadInt(32))
	effectdata:SetHitBox(net.ReadInt(32))
	effectdata:SetMagnitude(net.ReadInt(32))
	effectdata:SetMaterialIndex(net.ReadInt(32))
	effectdata:SetNormal(net.ReadVector())
	effectdata:SetOrigin(effectdata:GetEntity():GetPos()+net.ReadVector())
	effectdata:SetRadius(net.ReadInt(32))
	effectdata:SetScale(net.ReadInt(32))
	effectdata:SetStart(net.ReadVector())
	effectdata:SetSurfaceProp(net.ReadInt(32))
	util.Effect(effect,effectdata,override)
end)
