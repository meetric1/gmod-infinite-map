// metatable fuckery
local EntityMT = FindMetaTable("Entity")
local VehicleMT = FindMetaTable("Vehicle")
local PhysObjMT = FindMetaTable("PhysObj")
local PlayerMT = FindMetaTable("Player")
local NextBotMT = FindMetaTable("NextBot")
local CLuaLocomotionMT = FindMetaTable("CLuaLocomotion")
local CTakeDamageInfoMT = FindMetaTable("CTakeDamageInfo")

/*********** Entity Metatable *************/

EntityMT.InfMap_GetPos = EntityMT.InfMap_GetPos or EntityMT.GetPos
function EntityMT:GetPos()
	return InfMap.unlocalize_vector(self:InfMap_GetPos(), self.CHUNK_OFFSET)
end

EntityMT.InfMap_WorldSpaceCenter = EntityMT.InfMap_WorldSpaceCenter or EntityMT.WorldSpaceCenter
function EntityMT:WorldSpaceCenter()
	return InfMap.unlocalize_vector(self:InfMap_WorldSpaceCenter(), self.CHUNK_OFFSET)
end

EntityMT.InfMap_WorldSpaceAABB = EntityMT.InfMap_WorldSpaceAABB or EntityMT.WorldSpaceAABB
function EntityMT:WorldSpaceAABB()
	local v1, v2 = self:InfMap_WorldSpaceAABB()
	return InfMap.unlocalize_vector(v1, self.CHUNK_OFFSET), InfMap.unlocalize_vector(v2, self.CHUNK_OFFSET)
end

EntityMT.InfMap_SetPos = EntityMT.InfMap_SetPos or EntityMT.SetPos
function EntityMT:SetPos(pos)
	local chunk_pos, chunk_offset = InfMap.localize_vector(pos)
	if chunk_offset != self.CHUNK_OFFSET then
		InfMap.prop_update_chunk(self, chunk_offset)
	end
	return self:InfMap_SetPos(chunk_pos)
end

EntityMT.InfMap_LocalToWorld = EntityMT.InfMap_LocalToWorld or EntityMT.LocalToWorld
function EntityMT:LocalToWorld(pos)
	return InfMap.unlocalize_vector(self:InfMap_LocalToWorld(pos), self.CHUNK_OFFSET)
end

EntityMT.InfMap_WorldToLocal = EntityMT.InfMap_WorldToLocal or EntityMT.WorldToLocal
function EntityMT:WorldToLocal(pos)
	return self:InfMap_WorldToLocal(InfMap.unlocalize_vector(pos, -self.CHUNK_OFFSET))
end

EntityMT.InfMap_EyePos = EntityMT.InfMap_EyePos or EntityMT.EyePos
function EntityMT:EyePos()
	return InfMap.unlocalize_vector(self:InfMap_EyePos(), self.CHUNK_OFFSET)
end

EntityMT.InfMap_NearestPoint = EntityMT.InfMap_NearestPoint or EntityMT.NearestPoint
function EntityMT:NearestPoint(pos)
	// shouldnt really ever be outside the map
	local chunk_pos, chunk_offset = InfMap.localize_vector(pos)
	return InfMap.unlocalize_vector(self:InfMap_NearestPoint(chunk_pos), chunk_offset)
end

EntityMT.InfMap_GetAttachment = EntityMT.InfMap_GetAttachment or EntityMT.GetAttachment
function EntityMT:GetAttachment(num)
	local data = self:InfMap_GetAttachment(num)
	if !data or !data.Pos then return data end
	data.Pos = InfMap.unlocalize_vector(data.Pos, self.CHUNK_OFFSET)
	return data
end

local function unfuck_keyvalue(self, value)
	if !self:GetKeyValues()[value] then return end
	self:SetKeyValue(value, tostring(InfMap.unlocalize_vector(Vector(self:GetKeyValues()[value]), -self.CHUNK_OFFSET)))
end

EntityMT.InfMap_Spawn = EntityMT.InfMap_Spawn or EntityMT.Spawn
function EntityMT:Spawn()
	if self:IsConstraint() or self:GetClass() == "phys_spring" then	// elastic isnt considered a constraint..?
		unfuck_keyvalue(self, "attachpoint")
		unfuck_keyvalue(self, "springaxis")
		unfuck_keyvalue(self, "slideaxis")
		unfuck_keyvalue(self, "hingeaxis")
		unfuck_keyvalue(self, "axis")
		unfuck_keyvalue(self, "position2")
		self:SetPos(self:InfMap_GetPos())
	end
	return self:InfMap_Spawn()
end


/************ Physics Object Metatable **************/

PhysObjMT.InfMap_GetPos = PhysObjMT.InfMap_GetPos or PhysObjMT.GetPos
function PhysObjMT:GetPos()
	return InfMap.unlocalize_vector(self:InfMap_GetPos(), self:GetEntity().CHUNK_OFFSET)
end

PhysObjMT.InfMap_SetPos = PhysObjMT.InfMap_SetPos or PhysObjMT.SetPos
function PhysObjMT:SetPos(pos, teleport)
	local chunk_pos, chunk_offset = InfMap.localize_vector(pos)
	local ent = self:GetEntity()
	if chunk_offset != ent.CHUNK_OFFSET then
		InfMap.prop_update_chunk(ent, chunk_offset)
	end
	return self:InfMap_SetPos(chunk_pos, teleport)
end

PhysObjMT.InfMap_ApplyForceOffset = PhysObjMT.InfMap_ApplyForceOffset or PhysObjMT.ApplyForceOffset
function PhysObjMT:ApplyForceOffset(impulse, position)
	return self:InfMap_ApplyForceOffset(impulse, InfMap.unlocalize_vector(position, -self:GetEntity().CHUNK_OFFSET))
end

PhysObjMT.InfMap_LocalToWorld = PhysObjMT.InfMap_LocalToWorld or PhysObjMT.LocalToWorld
function PhysObjMT:LocalToWorld(pos)
	return InfMap.unlocalize_vector(self:InfMap_LocalToWorld(pos), self:GetEntity().CHUNK_OFFSET)
end

PhysObjMT.InfMap_CalculateVelocityOffset = PhysObjMT.InfMap_CalculateVelocityOffset or PhysObjMT.CalculateVelocityOffset
function PhysObjMT:CalculateVelocityOffset(impulse, position)
	return self:InfMap_CalculateVelocityOffset(impulse, InfMap.unlocalize_vector(position, -self:GetEntity().CHUNK_OFFSET))
end

PhysObjMT.InfMap_WorldToLocal = PhysObjMT.InfMap_WorldToLocal or PhysObjMT.WorldToLocal
function PhysObjMT:WorldToLocal(pos)
	return self:InfMap_WorldToLocal(pos - InfMap.unlocalize_vector(Vector(), self:GetEntity().CHUNK_OFFSET))
end


/*************** Vehicle Metatable *****************/

// causes stack overflow
//VehicleMT.InfMap_GetPos = VehicleMT.InfMap_GetPos or VehicleMT.GetPos
//function VehicleMT:GetPos()
//	return InfMap.unlocalize_vector(self:InfMap_GetPos(), self.CHUNK_OFFSET)
//end

VehicleMT.InfMap_SetPos = VehicleMT.InfMap_SetPos or VehicleMT.SetPos
function VehicleMT:SetPos(pos)
	local chunk_pos, chunk_offset = InfMap.localize_vector(pos)
	if chunk_offset != self.CHUNK_OFFSET then
		InfMap.prop_update_chunk(self, chunk_offset)
	end
	return self:InfMap_SetPos(chunk_pos)
end

VehicleMT.InfMap_LocalToWorld = VehicleMT.InfMap_LocalToWorld or VehicleMT.LocalToWorld
function VehicleMT:LocalToWorld(pos)
	return InfMap.unlocalize_vector(self:InfMap_LocalToWorld(pos), self.CHUNK_OFFSET)
end

VehicleMT.InfMap_WorldToLocal = VehicleMT.InfMap_WorldToLocal or VehicleMT.WorldToLocal
function VehicleMT:WorldToLocal(pos)
	return self:InfMap_WorldToLocal(pos - InfMap.unlocalize_vector(Vector(), self.CHUNK_OFFSET))
end

/**************** CTakeDamageInfo Metatable *****************/

CTakeDamageInfoMT.InfMap_GetDamagePosition = CTakeDamageInfoMT.InfMap_GetDamagePosition or CTakeDamageInfoMT.GetDamagePosition
function CTakeDamageInfoMT:GetDamagePosition()
	local inflictor = self:GetInflictor()
	if !IsValid(inflictor) then 
		inflictor = game.GetWorld()
	end
	return InfMap.unlocalize_vector(self:InfMap_GetDamagePosition(), inflictor.CHUNK_OFFSET)
end

/**************** Player Metatable *****************/

PlayerMT.InfMap_GetShootPos = PlayerMT.InfMap_GetShootPos or PlayerMT.GetShootPos
function PlayerMT:GetShootPos()
	return InfMap.unlocalize_vector(self:InfMap_GetShootPos(), self.CHUNK_OFFSET)
end

/**************** NextBot Metatable *****************/

NextBotMT.InfMap_GetRangeSquaredTo = NextBotMT.InfMap_GetRangeSquaredTo or NextBotMT.GetRangeSquaredTo
function NextBotMT:GetRangeSquaredTo(to)
	if isentity(to) then to = to:GetPos() end
	return self:GetPos():DistToSqr(to)
end

NextBotMT.InfMap_GetRangeTo = NextBotMT.InfMap_GetRangeTo or NextBotMT.GetRangeTo
function NextBotMT:GetRangeTo(to)
	return math.sqrt(self:GetRangeSquaredTo(to))
end

/*************** CLuaLocomotion Metatable *****************/

CLuaLocomotionMT.InfMap_Approach = CLuaLocomotionMT.InfMap_Approach or CLuaLocomotionMT.Approach
function CLuaLocomotionMT:Approach(goal, goalweight)
	local nb = self:GetNextBot()
	local dir = (goal - nb:GetPos()):GetNormalized()
	local pos = InfMap.localize_vector(nb:GetPos() + dir)
	return CLuaLocomotionMT.InfMap_Approach(self, pos, goalweight)
end

CLuaLocomotionMT.InfMap_FaceTowards = CLuaLocomotionMT.InfMap_FaceTowards or CLuaLocomotionMT.FaceTowards
function CLuaLocomotionMT:FaceTowards(goal)
	local nb = self:GetNextBot()
	local dir = (goal - nb:GetPos()):GetNormalized()
	local pos = InfMap.localize_vector(nb:GetPos() + dir)
	return CLuaLocomotionMT.InfMap_FaceTowards(self, pos)
end

/**************** Other Functions ********************/

// infinite map.. nothing can be outside the world!
function util.IsInWorld(pos)
	return true
end

// faster lookup
local istable = istable
local IsEntity = IsEntity
local function modify_trace_data(orig_data, trace_func, extra)
	local data = {}
	for k, v in pairs(orig_data) do
		data[k] = v
	end
	// #1 localize start and end position of trace
	local start_pos, start_offset = InfMap.localize_vector(data.start)

	data.start = start_pos
	data.endpos = data.endpos - InfMap.unlocalize_vector(Vector(), start_offset)
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

	// #3, unlocalize hit positions to designated chunks
	local hit_data = trace_func(data, extra)
	hit_data.HitPos = InfMap.unlocalize_vector(hit_data.HitPos, start_offset)
	hit_data.StartPos = InfMap.unlocalize_vector(hit_data.StartPos, start_offset)
	local hit_ent = hit_data.Entity
	if IsValid(hit_ent) then
		if hit_ent:GetClass() == "infmap_clone" and hit_data.REFERENCE_DATA then
			hit_data.Entity = hit_data.REFERENCE_DATA[1]
		elseif InfMap.disable_pickup[hit_ent:GetClass()] then
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
// no need to detour GetEyeTrace or util.GetPlayerTrace as it uses already detoured functions

// findinsphere
InfMap.FindInSphere = InfMap.FindInSphere or ents.FindInSphere
function ents.FindInSphere(pos, rad)
	local local_pos, local_chunk = InfMap.localize_vector(pos)
	local data = InfMap.FindInSphere(local_pos, rad)
	for i = #data, 1, -1 do
		if data[i].CHUNK_OFFSET != local_chunk then
			table.remove(data, i)
		end
	end
	return data
end

// wiremod internally clamps setpos, lets unclamp it...
hook.Add("Initialize", "infmap_wire_detour", function()
	if WireLib then	// wiremod unclamp
		function WireLib.clampPos(pos)
			return Vector(pos)
		end
	end

	if SF then	//starfall unclamp
		function SF.clampPos(pos) 
			return pos 
		end
	end

	InfMap.ShouldSaveEntity = InfMap.ShouldSaveEntity or gmsave.ShouldSaveEntity
	function gmsave.ShouldSaveEntity(ent, t)
		return InfMap.ShouldSaveEntity(ent, t) and !InfMap.filter[t.classname]
	end
end)
