// metatable fuckery
local EntityMT = FindMetaTable("Entity")
local VehicleMT = FindMetaTable("Vehicle")
local PhysObjMT = FindMetaTable("PhysObj")
local PlayerMT = FindMetaTable("Player")
local NextBotMT = FindMetaTable("NextBot")
local CTakeDamageInfoMT = FindMetaTable("CTakeDamageInfo")

EntityMT.InfMap_GetPos = EntityMT.InfMap_GetPos or EntityMT.GetPos
function EntityMT:GetPos()
	if !self.CHUNK_OFFSET or !LocalPlayer().CHUNK_OFFSET then return self:InfMap_GetPos(pos) end
	return InfMap.unlocalize_vector(self:InfMap_GetPos(), self.CHUNK_OFFSET - LocalPlayer().CHUNK_OFFSET)
end

EntityMT.InfMap_LocalToWorld = EntityMT.InfMap_LocalToWorld or EntityMT.LocalToWorld
function EntityMT:LocalToWorld(pos)
	if !self.CHUNK_OFFSET or !LocalPlayer().CHUNK_OFFSET then return self:InfMap_LocalToWorld(pos) end
	return InfMap.unlocalize_vector(self:InfMap_LocalToWorld(pos), self.CHUNK_OFFSET - LocalPlayer().CHUNK_OFFSET)
end

local clamp = math.Clamp
local function clamp_vector(pos, max)
	return Vector(clamp(pos[1], -max, max), clamp(pos[2], -max, max), clamp(pos[3], -max, max))
end

EntityMT.InfMap_SetPos = EntityMT.InfMap_SetPos or EntityMT.SetPos
function EntityMT:SetPos(pos)
	local pos = clamp_vector(pos, 2^14)
	return self:InfMap_SetPos(pos)
end

// Find Functions
function InfMap.FindInBox(v1,v2)
	local entlist = ents.GetAll()
	local results = {}

	for i,ent in ipairs(entlist) do
		if ent:WorldSpaceCenter():WithinAABox(v1,v2) then table.insert(results,ent) end
	end

	return results
end
ents.FindInBox = InfMap.FindInBox

function InfMap.FindInSphere(pos,radius)
	local entlist = ents.GetAll()
	local results = {}

	local radSqr = radius ^ 2

	for k,v in ipairs(entlist) do
		if v:WorldSpaceCenter():DistToSqr(pos) <= radSqr then table.insert(results,v) end
	end

	return results
end
ents.FindInSphere = InfMap.FindInSphere

function InfMap.FindInCone(pos,normal,radius,angle_cos)
	// no clamp here because it already gets clamped above
	local entlist = ents.FindInSphere(pos,radius)
	local results = {}

	for k,v in ipairs(entlist) do
		local dot = normal:Dot((v:GetPos() - pos):GetNormalized())
		if dot >= angle_cos then table.insert(results,v) end
	end

	return results
end
ents.FindInCone = InfMap.FindInCone

// PhysObj

PhysObjMT.InfMap_SetPos = PhysObjMT.InfMap_SetPos or PhysObjMT.SetPos
function PhysObjMT:SetPos(pos)
	local pos = clamp_vector(pos, 2^14)
	return self:InfMap_SetPos(pos)
end


// traces shouldnt appear when shot from other chunks
hook.Add("EntityFireBullets", "infmap_detour", function(ent, data)
	if ent.CHUNK_OFFSET != LocalPlayer().CHUNK_OFFSET then
		data.Tracer = 0
		return true
	end
end)

/*********** Client Entity Metatable *************/

EntityMT.InfMap_SetRenderBounds = EntityMT.InfMap_SetRenderBounds or EntityMT.SetRenderBounds
function EntityMT:SetRenderBounds(min, max, add)
	if self.RENDER_BOUNDS then
		self.RENDER_BOUNDS = {min, max}
	end
	return self:InfMap_SetRenderBounds(min, max, add)
end

/*********** Client Other *************/

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