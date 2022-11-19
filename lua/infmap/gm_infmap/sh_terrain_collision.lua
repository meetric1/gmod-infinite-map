// this file handles the collision for the terrain

InfMap.simplex = include("simplex.lua")
InfMap.chunk_resolution = 3
InfMap.filter.infmap_terrain_collider = true	// dont pass in chunks

local max = 2^28
local offset = 23.05
function InfMap.height_function(x, y) 
	//x = x + offset
    //local final = (InfMap.simplex.Noise3D(x / 15, y / 15, 0) * 150) * math.min(InfMap.simplex.Noise3D(x / 75, y / 75, 0) * 7500, 0) // small mountains
	//final = final + (InfMap.simplex.Noise3D(x / 75 + 1, y / 75, 150)) * 350000	// big mountains
	//x = x - offset
	local final = ((InfMap.simplex.Noise2D(x / 25 + 1, y / 25)) * 20) ^ 4// big mountains
	
	if (x >= 0) and (y > -0.5 and y < 0.5) then final = -15 end

	return math.Clamp(final, -max, 1000000)
end

// stops physgunning terrain because that would be absolute cancer
hook.Add("PhysgunPickup", "infinite_chunkterrain_pickup", function(ply, ent)
    if (ent:IsValid() and ent:GetClass() == "infmap_terrain_collider") then 
        return false 
    end
end)

if CLIENT then return end

local function v_tostring(v)    // m,k jcedrf k,m jdcrfv 
	return v[1] .. "," .. v[2] .. "," .. v[3]
end

InfMap.chunk_table = {}

local function resetAll()
	local e = ents.Create("prop_physics")
	e:InfMap_SetPos(Vector(0, 0, -10))
	e:SetModel("models/hunter/blocks/cube8x8x025.mdl")
	e:SetMaterial("models/gibs/metalgibs/metal_gibs")
	e:Spawn()
	e:GetPhysicsObject():EnableMotion(false)
	constraint.Weld(e, game.GetWorld(), 0, 0, 0)
	InfMap.prop_update_chunk(e, Vector())

	local e = ents.Create("infmap_terrain_collider")
	InfMap.chunk_table[v_tostring(Vector())] = e	// storing them in a table as a string because its easy :)))))
	InfMap.prop_update_chunk(e, Vector())
	e:Spawn()
end

// handles generating chunk collision
hook.Add("PropUpdateChunk", "infmap_infgen_terrain", function(ent, chunk, old_chunk)
	timer.Simple(0, function()  // wait for entire contraption to teleport
		if IsValid(ent) and !InfMap.filter_entities(ent) and ent:IsSolid() then
			// remove chunks that dont have anything in them
			if old_chunk then
				local invalid = InfMap.chunk_table[v_tostring(old_chunk)]
				for k, v in ipairs(ents.GetAll()) do
					if InfMap.filter_entities(v) or v == ent or !v:IsSolid() then continue end
					if v.CHUNK_OFFSET == old_chunk then
						invalid = nil
					end
				end
				SafeRemoveEntity(invalid)
			end

			// chunk already exists, dont make another
			if IsValid(InfMap.chunk_table[v_tostring(chunk)]) then return end

			local e = ents.Create("infmap_terrain_collider")
			InfMap.prop_update_chunk(e, chunk)
			e:Spawn()
			InfMap.chunk_table[v_tostring(chunk)] = e
		end
	end)
end)

hook.Add("InitPostEntity", "infmap_terrain_init", resetAll)
hook.Add("PostCleanupMap", "infmap_cleanup", resetAll)