if game.GetMap() != "gm_infinite" then return end

InfMap = InfMap or {}

// physgun, gravgun, and use support
local ply_objs = {}
local function pickup(ply, ent) ply_objs[ply] = ent end	// kind of cursed.. key = player, value = prop
local function drop(ply, ent) ply_objs[ply] = nil end	
hook.Add("OnPhysgunPickup", "infinite_detour", pickup)
hook.Add("PhysgunDrop", "infinte_detour", drop)

hook.Add("GravGunOnPickedUp", "infinite_detour", pickup)
hook.Add("GravGunOnDropped", "infinte_detour", drop)

hook.Add("OnPlayerPhysicsPickup", "infinite_detour", pickup)
hook.Add("OnPlayerPhysicsDrop", "infinte_detour", drop)

local class_filter = {
	prop_vehicle_jeep = true,
	player = true,
	prop_vehicle_prisoner_pod = true,
	//gmod_sent_vehicle_fphysics_base = true,
	prop_physics = true,
}

// setting position kills all velocity for some reason
local source_bounds = 2^14 - 64
local function unfucked_SetPos(ent, pos, filter)
	if ent:GetParent():IsValid() then return end	// parents are local, dont setpos.. lets hope the parent entity itself was also teleported
	
	// clamp position inside source bounds incase contraption is massive
	// helps things like simphys cars not fucking die
	pos[1] = math.Clamp(pos[1], -source_bounds, source_bounds)
	pos[2] = math.Clamp(pos[2], -source_bounds, source_bounds)
	pos[3] = math.Clamp(pos[3], -source_bounds, source_bounds)

	local vel = ent:GetVelocity()
	local phys = ent:GetPhysicsObject()
	if phys:IsValid() and !class_filter[ent:GetClass()] and !(ent:IsNPC() or ent:IsNextBot()) then 
		phys:SetVelocity(vel)	// ????????????????????
		phys:InfMap_SetPos(pos, true)
	else
		ent:InfMap_SetPos(pos)
		if phys:IsValid() then
			phys:SetVelocity(vel, true)
		else
			ent:SetVelocity(vel)
		end
	end
end

local function update_entity(ent, pos, chunk)
	// remove all clones since it has moved chunks, (so we can rebuild clones)
	if ent.CHUNK_CLONES then
		for _, e in pairs(ent.CHUNK_CLONES) do	// (ipairs doesnt work since index is sortof random)
			SafeRemoveEntity(e)
		end
		ent.CHUNK_CLONES = nil
	end

	if ent:IsPlayer() then
		// carried props are teleported to the next chunk
		local carry = ply_objs[ent]
		if carry and carry:IsValid() then
			// teleport entire contraption
			InfMap.constrained_status(carry)	// initialize constrained data
			for _, constrained_ent in ipairs(carry.CONSTRAINED_DATA) do	// includes itself
				if !constrained_ent:IsValid() or InfMap.filter_entities(constrained_ent) then continue end
				if constrained_ent != carry then
					constrained_ent:ForcePlayerDrop()
				end

				unfucked_SetPos(constrained_ent, pos + (constrained_ent:InfMap_GetPos() - ent:InfMap_GetPos()))
				hook.Run("PropUpdateChunk", constrained_ent, chunk)
			end
			InfMap.reset_constrained_data(carry)
		end
	end

	hook.Run("PropUpdateChunk", ent, chunk)
	unfucked_SetPos(ent, pos)
end

// which entities should be checked per frame
local all_ents = {}
timer.Create("infinite_chunkmove_update", 0.1, 0, function()
	all_ents = ents.GetAll()
	for i = #all_ents, 1, -1 do	// iterate downward
		// if invalid is true, then the entity should be removed from the table calculated per frame
		local ent = all_ents[i]
		local invalid = !ent.CHUNK_OFFSET
		invalid = invalid or InfMap.filter_entities(ent)
		invalid = invalid or (ent:GetPhysicsObject():IsValid() and !ent:GetPhysicsObject():IsMoveable())
		invalid = invalid or (ent:IsPlayer() and (!ent:Alive() or ent:InVehicle()))
		
		if invalid then
			table.remove(all_ents, i)	// remove invalid entity
		end

		// gravhull support
		local ship = ent.MyShip or ent.InShip
		if ship and ship:IsValid() then
			InfMap.gravhull_ents[ent] = ship
		else
			InfMap.gravhull_ents[ent] = nil
		end
	end
end)

// gravhull prop chunk updater
InfMap.gravhull_ents = {}
hook.Add("Think", "infinite_gravhull_update", function()
	for ent, ship in pairs(InfMap.gravhull_ents) do
		if !ent or !ent:IsValid() or !ship or !ship:IsValid() then
			InfMap.gravhull_ents[ent] = nil
			continue
		end
		if ship.CHUNK_OFFSET != ent.CHUNK_OFFSET then
			hook.Run("PropUpdateChunk", ent, ship.CHUNK_OFFSET)
		end
	end
end)

// object wrapping, if in next chunk, put in next chunk and do localization math
hook.Add("Think", "infinite_chunkmove", function()
	//if true then return end
	for _, main_ent in ipairs(all_ents) do
		if !main_ent or !main_ent:IsValid() then continue end
		if !main_ent.CHUNK_OFFSET then continue end
		
		if !InfMap.in_chunk(main_ent:InfMap_GetPos()) then
			if !InfMap.constrained_status(main_ent) then continue end
			if main_ent:IsPlayerHolding() then continue end	// physgun, gravgun, and use support

			local pos, offset = InfMap.localize_vector(main_ent:InfMap_GetPos())
			local final_chunk_offset = main_ent.CHUNK_OFFSET + offset
			local main_ent_pos = main_ent:InfMap_GetPos()
			local main_ents = table.Copy(main_ent.CONSTRAINED_DATA)
			for _, constrained_ent in ipairs(main_ents) do	// includes itself
				if !constrained_ent:IsValid() or InfMap.filter_entities(constrained_ent) then continue end
				if constrained_ent != main_ent then
					constrained_ent:ForcePlayerDrop()
				end
				//if constrained_ent.CHUNK_OFFSET != main_ent.CHUNK_OFFSET then continue end
				local delta_pos = pos + (constrained_ent:InfMap_GetPos() - main_ent_pos)
				update_entity(constrained_ent, delta_pos, final_chunk_offset)
			end
		else 
			InfMap.reset_constrained_data(main_ent)
		end
	end
end)

// self explainatory
local function intersect_box(min_a, max_a, min_b, max_b) 
	local x_check = max_b[1] < min_a[1] or min_b[1] > max_a[1]
	local y_check = max_b[2] < min_a[2] or min_b[2] > max_a[2]
	local z_check = max_b[3] < min_a[3] or min_b[3] > max_a[3]
	return !(x_check or y_check or z_check)
end

// collision with props crossing through chunk bounderies
local co = coroutine.create(function()
	while true do 
		local err, str = pcall(function()
		for _, ent in ipairs(ents.GetAll()) do
			if !ent or !ent:IsValid() then continue end
			if InfMap.filter_entities(ent) then continue end
			if ent:GetClass() == "infinite_chunk_terrain" then continue end

			/////////////////////////////////

			if !ent.CHUNK_OFFSET then continue end
			if !ent:IsSolid() then continue end
			if ent:GetParent():IsValid() then continue end

			//if ent:GetVelocity() == Vector() then continue end
			// player support
			if ent:IsPlayer() and (ent:GetMoveType() == MOVETYPE_NOCLIP or !ent:Alive() or ent:InVehicle()) then continue end

			// check all surrounding chunks with a fast check using radius instead of bounding box
			local bounding_radius = ent:BoundingRadius()	// no tiny props, too much computation
			if bounding_radius < 10 then continue end

			if !InfMap.in_chunk(ent:InfMap_GetPos(), InfMap.chunk_size - bounding_radius) then
				ent.CHUNK_CLONES = ent.CHUNK_CLONES or {}
				local i = 0
				local aabb_min, aabb_max = ent:WorldSpaceAABB()
				for z = -1, 1 do
					for y = -1, 1 do
						for x = -1, 1 do
							// never clone in the same chunk the object is already in
							if !(x != 0 or y != 0 or z != 0) then continue end	// same as 'x == 0 && y == 0 && z == 0'

							i = i + 1

							// if in chunk next to it, clone
							local chunk_pos = Vector(x, y, z) * InfMap.chunk_size * 2
							local chunk_min = chunk_pos - Vector(1, 1, 1) * InfMap.chunk_size
							local chunk_max = chunk_pos + Vector(1, 1, 1) * InfMap.chunk_size
							if intersect_box(aabb_min, aabb_max, chunk_min, chunk_max) then
								// dont clone 2 times
								if ent.CHUNK_CLONES[i] then continue end

								// clone object
								local e = ents.Create("infinite_chunk_clone")
								e:SetReferenceData(ent, ent.CHUNK_OFFSET + Vector(x, y, z))
								e:Spawn()
								ent.CHUNK_CLONES[i] = e
								//print("Cloned on", ent, Vector(x, y, z))
							else
								if !ent.CHUNK_CLONES[i] then continue end
								// remove cloned object if its moved out of chunk
								SafeRemoveEntity(ent.CHUNK_CLONES[i])
								ent.CHUNK_CLONES[i] = nil
							end
						end
					end
				end	
			else
				// outside of area for cloning to happen, remove all clones
				if ent.CHUNK_CLONES then
					for _, e in pairs(ent.CHUNK_CLONES) do
						SafeRemoveEntity(e)
					end
					ent.CHUNK_CLONES = nil
				end
			end
			coroutine.yield()
		end
		end)
		if !err then print(str) end
		coroutine.yield()
	end
end)

// cross chunk collision
hook.Add("Think", "infinite_ccc", function()
	coroutine.resume(co)
end)