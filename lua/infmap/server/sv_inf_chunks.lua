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

// setting position kills all velocity for some reason
local source_bounds = 2^14 - 64
local function unfucked_SetPos(ent, pos, filter)
	if ent:GetParent():IsValid() then return end	// parents are local, dont setpos.. lets hope the parent entity itself was also teleported
	
	// clamp position inside source bounds incase contraption is massive
	// helps things like simphys cars not fucking die
	pos[1] = math.Clamp(pos[1], -source_bounds, source_bounds)
	pos[2] = math.Clamp(pos[2], -source_bounds, source_bounds)
	pos[3] = math.Clamp(pos[3], -source_bounds, source_bounds)

	ent:InfMap_SetPos(pos)
end

local function unfucked_SetVelAng(ent, vel, ang)
	local phys = ent:GetPhysicsObject()
	
	if phys:IsValid() then 
		if ang then phys:SetAngles(ang) end
		phys:SetVelocity(vel)
	else
		if ang then ent:SetAngles(ang) end
		ent:SetVelocity(vel)
	end

end

local function update_entity(ent, pos, chunk)
	if ent:IsPlayer() then
		// carried props are teleported to the next chunk
		local carry = ply_objs[ent]
		if IsValid(carry) then
			// teleport entire contraption
			InfMap.constrained_status(carry)	// initialize constrained data
			local ent_pos = ent:InfMap_GetPos()

			for _, constrained_ent in ipairs(carry.CONSTRAINED_DATA) do	// includes itself
				if !constrained_ent:IsValid() or InfMap.filter_entities(constrained_ent) then continue end
				if constrained_ent != carry then
					constrained_ent:ForcePlayerDrop()
				end

				local constrained_vel = constrained_ent:GetVelocity()
				local constrained_ang = constrained_ent:GetAngles()

				unfucked_SetPos(constrained_ent, pos + (constrained_ent:InfMap_GetPos() - ent_pos))
				unfucked_SetVelAng(constrained_ent, constrained_vel, constrained_ang)
				InfMap.prop_update_chunk(constrained_ent, chunk)
			end
			InfMap.reset_constrained_data(carry)
		end
	end

	InfMap.prop_update_chunk(ent, chunk)
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
		invalid = invalid or (IsValid(ent:GetPhysicsObject()) and !ent:GetPhysicsObject():IsMoveable())
		invalid = invalid or IsValid(ent:GetParent())
		invalid = invalid or ent:IsPlayer() and !ent:Alive()
		
		if invalid then
			table.remove(all_ents, i)	// remove invalid entity
		end

		// gravhull support
		local ship = ent.MyShip or ent.InShip
		if IsValid(ship) then
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
		if !IsValid(ent) or !IsValid(ship) then
			InfMap.gravhull_ents[ent] = nil
			continue
		end
		if ship.CHUNK_OFFSET != ent.CHUNK_OFFSET then
			InfMap.prop_update_chunk(ent, ship.CHUNK_OFFSET)
		end
	end
end)

// object wrapping, if in next chunk, put in next chunk and do localization math
hook.Add("Think", "infinite_chunkmove", function()
	for _, main_ent in ipairs(all_ents) do
		if !IsValid(main_ent) then continue end
		if !main_ent.CHUNK_OFFSET then continue end
		
		if !InfMap.in_chunk(main_ent:InfMap_GetPos()) then
			if !InfMap.constrained_status(main_ent) then continue end
			if main_ent:IsPlayerHolding() then continue end	// physgun, gravgun, and use support

			local pos, offset = InfMap.localize_vector(main_ent:InfMap_GetPos())
			local final_chunk_offset = main_ent.CHUNK_OFFSET + offset
			local main_ent_pos = main_ent:InfMap_GetPos()

			local constrained_vel = {}
			local constrained_ang = {}
			//grab ang+vel before teleport
			local main_vel = main_ent:GetVelocity()
			local main_ang = main_ent:GetAngles()

			for v, constrained_ent in ipairs(main_ent.CONSTRAINED_DATA) do
				constrained_vel[v] = constrained_ent:GetVelocity()
				constrained_ang[v] = constrained_ent:GetAngles()
			end

			for _, constrained_ent in ipairs(main_ent.CONSTRAINED_DATA) do	// includes itself
				if main_ent == constrained_ent then continue end
				if !constrained_ent:IsValid() or InfMap.filter_entities(constrained_ent) then continue end
				if constrained_ent != main_ent then
					constrained_ent:ForcePlayerDrop()
				end
				//if constrained_ent.CHUNK_OFFSET != main_ent.CHUNK_OFFSET then continue end
				local delta_pos = pos + (constrained_ent:InfMap_GetPos() - main_ent_pos)
				update_entity(constrained_ent, delta_pos, final_chunk_offset)
			end

			// update main ent
			update_entity(main_ent, pos, final_chunk_offset)

			// set vel+ang after teleport on constrained props
			for v, constrained_ent in ipairs(main_ent.CONSTRAINED_DATA) do
				unfucked_SetVelAng(constrained_ent,constrained_vel[v],constrained_ang[v])
			end
			//set vel+ang on main prop after teleport
			unfucked_SetVelAng(main_ent,main_vel,main_ang)

		else 
			InfMap.reset_constrained_data(main_ent)
		end
	end
end)

// collision with props crossing through chunk bounderies
local co = coroutine.create(function()
	while true do 
		local err, str = pcall(function()
		for _, ent in ipairs(ents.GetAll()) do
			if !IsValid(ent) then continue end
			if InfMap.filter_entities(ent) then continue end

			/////////////////////////////////

			if !ent.CHUNK_OFFSET then continue end
			if !ent:IsSolid() then continue end
			if IsValid(ent:GetParent()) then continue end

			//if ent:GetVelocity() == Vector() then continue end
			// player support
			if ent:IsPlayer() and (ent:GetMoveType() == MOVETYPE_NOCLIP or !ent:Alive()) then continue end

			// check all surrounding chunks with a fast check using radius instead of bounding box
			local bounding_radius = ent:BoundingRadius()	// no tiny props, too much computation
			if bounding_radius < 10 then continue end

			if !InfMap.in_chunk(ent:InfMap_GetPos(), InfMap.chunk_size - bounding_radius) then
				ent.CHUNK_CLONES = ent.CHUNK_CLONES or {}
				local i = 0
				local aabb_min, aabb_max = ent:InfMap_WorldSpaceAABB()
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
							//debugoverlay.Box(chunk_pos, chunk_min, chunk_max, 0.1, Color(255, 0, 255, 0))

							if InfMap.intersect_box(aabb_min, aabb_max, chunk_min, chunk_max) then
								// dont clone 2 times
								if IsValid(ent.CHUNK_CLONES[i]) then continue end

								// clone object
								local e = ents.Create("infmap_clone")
								e:SetReferenceData(ent, Vector(x, y, z))
								e:Spawn()
								ent.CHUNK_CLONES[i] = e
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
