// this file handles the collision for planets
local function v_tostring(v)    // how else would you store them?
	return v[1] .. "," .. v[2] .. "," .. v[3]
end

InfMap.planet_chunk_table = InfMap.planet_chunk_table or {}

local function try_invalid_chunk(chunk)
	if !chunk then return end
	local invalid = InfMap.planet_chunk_table[v_tostring(chunk)]
	for k, v in ipairs(ents.GetAll()) do
		if InfMap.filter_entities(v) or !v:IsSolid() then continue end
		if v.CHUNK_OFFSET == chunk then
			invalid = nil
		end
	end
	SafeRemoveEntity(invalid)
end

local function update_chunk(ent, chunk, oldchunk)
	if IsValid(ent) and !InfMap.filter_entities(ent) and ent:IsSolid() then
		// remove chunks that dont have anything in them
		try_invalid_chunk(oldchunk)

		// is entity even going into a planet chunk?
		local spacing = InfMap.planet_spacing / 2 - 1
		local _, megachunk = InfMap.localize_vector(chunk, InfMap.planet_spacing / 2)
		local planet_chunk, planet_radius, mat = InfMap.planet_info(megachunk[1], megachunk[2])
		
		// no planet here!
		if chunk != planet_chunk then return end

		// chunk already exists, dont make another
		if IsValid(InfMap.planet_chunk_table[v_tostring(chunk)]) then return end

		local e = ents.Create("infmap_planet")
		InfMap.prop_update_chunk(e, chunk)
		e:SetModel("models/props_c17/FurnitureCouch002a.mdl")
		e:SetPlanetRadius(planet_radius)
		if mat == 6 then 
			e:SetMaterial("phoenix_storms/ps_grass")
		else
			e:SetMaterial("shadertest/seamless" .. mat + 1)
		end
		e:Spawn()
		InfMap.planet_chunk_table[v_tostring(chunk)] = e
	end
end


// handles generating chunk collision
hook.Add("PropUpdateChunk", "infmap_infgen_planets", function(ent, chunk, oldchunk)
	update_chunk(ent, chunk, oldchunk)
end)