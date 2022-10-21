if game.GetMap() != "gm_infinite" then return end

AddCSLuaFile()

InfMap = InfMap or {}

function InfMap.in_chunk(pos, size) 
	local cs = size or InfMap.chunk_size
	return !(pos[1] <= -cs or pos[1] >= cs or pos[2] <= -cs or pos[2] >= cs or pos[3] <= -cs or pos[3] >= cs)
end

function InfMap.localize_vector(pos) 
	local cs = InfMap.chunk_size
	local cs_double = cs * 2

	local floor = math.floor
	local cox = floor((pos[1] + cs) / cs_double)
	local coy = floor((pos[2] + cs) / cs_double)
	local coz = floor((pos[3] + cs) / cs_double)
	local chunk_offset = Vector(cox, coy, coz)

	local chunk_size_vec = Vector(1, 1, 1) * cs

	// offset vector so coords are 0 to x*2 instead of -x to x
	pos = pos + chunk_size_vec

	// wrap coords
	pos[1] = pos[1] % cs_double
	pos[2] = pos[2] % cs_double
	pos[3] = pos[3] % cs_double

	// add back offset
	pos = pos - chunk_size_vec

	return pos, chunk_offset
end

function InfMap.unlocalize_vector(pos, chunk) 
	return (chunk or Vector()) * InfMap.chunk_size * 2 + pos
end

function InfMap.should_collide(ent1, ent2)
	local ent1_class = ent1:GetClass()
	local ent2_class = ent2:GetClass()

	if ent1_class == "infinite_chunk_terrain" then 
		if !ent2.CHUNK_OFFSET then return end
		if math.abs(ent2.CHUNK_OFFSET[1]) > 25 or math.abs(ent2.CHUNK_OFFSET[2]) > 25 or ent2.CHUNK_OFFSET[3] != 0 then
			return false
		end
	elseif ent2_class == "infinite_chunk_terrain" then
		if !ent1.CHUNK_OFFSET then return end
		if math.abs(ent1.CHUNK_OFFSET[1]) > 25 or math.abs(ent1.CHUNK_OFFSET[2]) > 25 or ent1.CHUNK_OFFSET[3] != 0 then
			return false
		end
	elseif ent1.CHUNK_OFFSET != ent2.CHUNK_OFFSET then return false end
end

local filter = {
	infinite_chunk_clone = true,
	physgun_beam = true,
	worldspawn = true,
	gmod_hands = true,
	info_particle_system = true,
	phys_spring = true,
	predicted_viewmodel = true,
	env_projectedtexture = true,
	keyframe_rope = true,
	hl2mp_ragdoll = true,
	env_skypaint = true,
	shadow_control = true,
	player_pickup = true,
	env_sun = true,
	info_player_start = true,
	scene_manager = true,
	ai_network = true,
	bodyque = true,
	gmod_gamerules = true,
	player_manager = true,
	soundent = true,
	env_flare = true,
	_firesmoke = true,
	func_brush = true,
	logic_auto = true,
	light_environment = true,
	env_laserdot = true,
	env_smokestack = true,
	env_rockettrail = true,
	rpg_missile = true,
	//gmod_safespace_interior = true,
	sizehandler = true,
}

function InfMap.filter_entities(e)
	if filter[e:GetClass()] then return true end
	if e:EntIndex() == 0 then return true end
	if SERVER and e:IsConstraint() then return true end
	//if !e.GetModelRenderBounds and !e:GetModelRenderBounds() then return true end

	return false
end

// code edited from starfallex
function InfMap.get_all_constrained(main_ent)
	local entity_lookup = {}
	local entity_table = {}
	local function recursive_find(ent)
		if entity_lookup[ent] then return end
		entity_lookup[ent] = true
		if ent:IsValid() then
			entity_table[#entity_table + 1] = ent
			local constraints = constraint.GetTable(ent)
			for k, v in pairs(constraints) do
				if v.Ent1 then recursive_find(v.Ent1) end
				if v.Ent2 then recursive_find(v.Ent2) end
			end

			local parent = ent:GetParent()
			if parent then recursive_find(parent) end
			for k, child in pairs(ent:GetChildren()) do
				if child:IsPlayer() then continue end
				recursive_find(child)
			end
		end
	end
	recursive_find(main_ent)

	return entity_table
end

local function constrained_invalid_filter(ent) 
	local phys_filter = false
	local phys = ent:GetPhysicsObject()
	if phys:IsValid() then
		phys_filter = !phys:IsMoveable()	// filter frozen props & 1 mass props
	end
	return InfMap.filter_entities(ent) or (!ent:IsSolid() and ent:GetNoDraw()) or ent:GetParent():IsValid() or phys_filter
end

function InfMap.constrained_status(ent) 
	if ent.CONSTRAINED_DATA then
		return ent.CONSTRAINED_MAIN
	end

	ent.CONSTRAINED_DATA = InfMap.get_all_constrained(ent)
	// first pass, these entities arent valid
	if constrained_invalid_filter(ent) then 
		ent.CONSTRAINED_MAIN = false
		return ent.CONSTRAINED_MAIN
	end
	local ent_index = ent:EntIndex()
	for _, constrained_ent in ipairs(ent.CONSTRAINED_DATA) do
		if constrained_ent:IsPlayerHolding() then	// if player is holding, instead of basing it off the index base it off of the object that is being held
			ent.CONSTRAINED_MAIN = constrained_ent == ent
			return ent.CONSTRAINED_MAIN
		end

		if constrained_ent:EntIndex() < ent_index and !constrained_invalid_filter(constrained_ent) then 
			ent.CONSTRAINED_MAIN = false
			return ent.CONSTRAINED_MAIN
		end
	end

	ent.CONSTRAINED_MAIN = true
	return ent.CONSTRAINED_MAIN
end

function InfMap.reset_constrained_data(ent)
	ent.CONSTRAINED_DATA = nil 
	ent.CONSTRAINED_MAIN = nil
end