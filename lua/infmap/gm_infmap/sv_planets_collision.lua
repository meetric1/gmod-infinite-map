// this file handles the collision for planets
InfMap.planet_chunk_table = InfMap.planet_chunk_table or {}

local function try_invalid_chunk(chunk, filter)
	if !chunk then return end
	local invalid = InfMap.planet_chunk_table[InfMap.ezcoord(chunk)]
	for k, v in ipairs(ents.GetAll()) do
		if InfMap.filter_entities(v) or !v:IsSolid() or v == filter then continue end
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
		if IsValid(InfMap.planet_chunk_table[InfMap.ezcoord(chunk)]) then return end

		local e = ents.Create("infmap_planet")
		InfMap.prop_update_chunk(e, chunk)
		e:SetModel("models/props_c17/FurnitureCouch002a.mdl")
		e:SetPlanetRadius(planet_radius)
		e:SetMaterial(InfMap.planet_inside_materials[mat]:GetName())
		e:Spawn()
		InfMap.planet_chunk_table[InfMap.ezcoord(chunk)] = e
	end
end


// handles generating chunk collision
hook.Add("PropUpdateChunk", "infmap_infgen_planets", function(ent, chunk, oldchunk)
	update_chunk(ent, chunk, oldchunk)
end)

hook.Add("EntityRemoved", "infmap_infgen_planets", function(ent)
	try_invalid_chunk(ent.CHUNK_OFFSET, ent)
end)