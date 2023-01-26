// useful functions used throughout the lua

function InfMap.in_chunk(pos, size) 
	local cs = size or InfMap.chunk_size
	return !(pos[1] <= -cs or pos[1] >= cs or pos[2] <= -cs or pos[2] >= cs or pos[3] <= -cs or pos[3] >= cs)
end

function InfMap.localize_vector(pos, size) 
	local cs = size or InfMap.chunk_size
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

// self explainatory
function InfMap.intersect_box(min_a, max_a, min_b, max_b) 
	local x_check = max_b[1] < min_a[1] or min_b[1] > max_a[1]
	local y_check = max_b[2] < min_a[2] or min_b[2] > max_a[2]
	local z_check = max_b[3] < min_a[3] or min_b[3] > max_a[3]
	return !(x_check or y_check or z_check)
end

// all the classes that are useless
InfMap.filter = InfMap.filter or {
	infmap_clone = true,
	infmap_obj_collider = true,
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
	gmod_safespace_interior = true,
	sizehandler = true,
	player_pickup = true,
	phys_spring = true,
	crossbow_bolt = true,
}

// classes that should not be picked up by physgun
InfMap.disable_pickup = InfMap.disable_pickup or {
	infmap_clone = true,
	infmap_obj_collider = true,
}

function InfMap.filter_entities(e)
	if InfMap.filter[e:GetClass()] then return true end
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

			//local parent = ent:GetParent()
			//if parent then recursive_find(parent) end
			//for k, child in pairs(ent:GetChildren()) do
			//	if child:IsPlayer() then continue end
			//	recursive_find(child)
			//end
		end
	end
	recursive_find(main_ent)

	return entity_table
end

// code edited from starfallex
function InfMap.get_all_parents(main_ent)
	local entity_lookup = {}
	local entity_table = {}
	local function recursive_find(ent)
		if entity_lookup[ent] then return end
		entity_lookup[ent] = true
		if ent:IsValid() then
			entity_table[#entity_table + 1] = ent
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
	if ent:IsPlayerHolding() then 
		return false 
	end
	local phys_filter = false
	local phys = ent:GetPhysicsObject()
	if phys:IsValid() then
		phys_filter = !phys:IsMoveable()	// filter frozen props
	end
	return InfMap.filter_entities(ent) or (!ent:IsSolid() and ent:GetNoDraw()) or ent:GetParent():IsValid() or phys_filter or (ent:IsWeapon() and ent:GetOwner():IsValid())
end

function InfMap.constrained_status(ent) 
	if ent.CONSTRAINED_MAIN != nil then
		return ent.CONSTRAINED_MAIN
	end

	// first pass, these entities arent valid
	if constrained_invalid_filter(ent) then 
		ent.CONSTRAINED_MAIN = false
		return ent.CONSTRAINED_MAIN
	end

	ent.CONSTRAINED_DATA = ent.CONSTRAINED_DATA or InfMap.get_all_constrained(ent)	// expensive function

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

		constrained_ent.CONSTRAINED_DATA = ent.CONSTRAINED_DATA
	end

	ent.CONSTRAINED_MAIN = true
	return ent.CONSTRAINED_MAIN
end

function InfMap.reset_constrained_data(ent)
	ent.CONSTRAINED_DATA = nil 
	ent.CONSTRAINED_MAIN = nil
end

function InfMap.ezcoord(chunk)
	return chunk[1] .. "," .. chunk[2] .. "," .. chunk[3]
end

// tris are in the format {{pos = value}, {pos = value2}}
function InfMap.split_convex(tris, plane_pos, plane_dir)
    if !tris then return {} end
    local plane_dir = plane_dir:GetNormalized()     // normalize plane direction
    local split_tris = {}
    local plane_points = {}
    // loop through all triangles in the mesh
    local util_IntersectRayWithPlane = util.IntersectRayWithPlane
    local table_insert = table.insert
    for i = 1, #tris, 3 do
        local pos1 = tris[i    ]
        local pos2 = tris[i + 1]
        local pos3 = tris[i + 2]
        if tris[i].pos then
            pos1 = tris[i    ].pos
            pos2 = tris[i + 1].pos
            pos3 = tris[i + 2].pos
        end

        // get points that are valid sides of the plane

        //if !pos1 or !pos2 or !pos3 then continue end      // just in case??

        local pos1_valid = (pos1 - plane_pos):Dot(plane_dir) > 0
        local pos2_valid = (pos2 - plane_pos):Dot(plane_dir) > 0
        local pos3_valid = (pos3 - plane_pos):Dot(plane_dir) > 0
        
        // if all points should be kept, add triangle
        if pos1_valid and pos2_valid and pos3_valid then 
            table_insert(split_tris, pos1)
            table_insert(split_tris, pos2)
            table_insert(split_tris, pos3)
            continue
        end
        
        // if none of the points should be kept, skip triangle
        if !pos1_valid and !pos2_valid and !pos3_valid then 
            continue 
        end
        
        local new_tris_index = 0    // optimization because table.insert is garbage
        local new_tris = {}
        
        // all possible states of the intersected triangle
        // extremely fast since a max of 4 if statments are required
        local point1
        local point2
        local is_flipped = false
        if pos1_valid then
            if pos2_valid then      //pos1 = valid, pos2 = valid, pos3 = invalid
                point1 = util_IntersectRayWithPlane(pos1, pos3 - pos1, plane_pos, plane_dir)
                point2 = util_IntersectRayWithPlane(pos2, pos3 - pos2, plane_pos, plane_dir)
                if !point1 then point1 = pos3 end
                if !point2 then point2 = pos3 end
                new_tris[new_tris_index + 1] = pos1
                new_tris[new_tris_index + 2] = pos2
                new_tris[new_tris_index + 3] = point1

                new_tris[new_tris_index + 4] = point2
                new_tris[new_tris_index + 5] = point1
                new_tris[new_tris_index + 6] = pos2
                new_tris_index = new_tris_index + 6
                is_flipped = true
            elseif pos3_valid then  // pos1 = valid, pos2 = invalid, pos3 = valid
                point1 = util_IntersectRayWithPlane(pos1, pos2 - pos1, plane_pos, plane_dir)
                point2 = util_IntersectRayWithPlane(pos3, pos2 - pos3, plane_pos, plane_dir)
                if !point1 then point1 = pos2 end
                if !point2 then point2 = pos2 end
                new_tris[new_tris_index + 1] = point1
                new_tris[new_tris_index + 2] = pos3
                new_tris[new_tris_index + 3] = pos1

                new_tris[new_tris_index + 4] = pos3
                new_tris[new_tris_index + 5] = point1
                new_tris[new_tris_index + 6] = point2
                new_tris_index = new_tris_index + 6
            else                    // pos1 = valid, pos2 = invalid, pos3 = invalid
                point1 = util_IntersectRayWithPlane(pos1, pos2 - pos1, plane_pos, plane_dir)
                point2 = util_IntersectRayWithPlane(pos1, pos3 - pos1, plane_pos, plane_dir)
                if !point1 then point1 = pos2 end
                if !point2 then point2 = pos3 end
                new_tris[new_tris_index + 1] = pos1
                new_tris[new_tris_index + 2] = point1
                new_tris[new_tris_index + 3] = point2
                new_tris_index = new_tris_index + 3
            end
        elseif pos2_valid then
            if pos3_valid then      // pos1 = invalid, pos2 = valid, pos3 = valid
                point1 = util_IntersectRayWithPlane(pos2, pos1 - pos2, plane_pos, plane_dir)
                point2 = util_IntersectRayWithPlane(pos3, pos1 - pos3, plane_pos, plane_dir)
                if !point1 then point1 = pos1 end
                if !point2 then point2 = pos1 end
                new_tris[new_tris_index + 1] = pos2
                new_tris[new_tris_index + 2] = pos3
                new_tris[new_tris_index + 3] = point1

                new_tris[new_tris_index + 4] = point2
                new_tris[new_tris_index + 5] = point1
                new_tris[new_tris_index + 6] = pos3
                new_tris_index = new_tris_index + 6
                is_flipped = true 
            else                    // pos1 = invalid, pos2 = valid, pos3 = invalid
                point1 = util_IntersectRayWithPlane(pos2, pos1 - pos2, plane_pos, plane_dir)
                point2 = util_IntersectRayWithPlane(pos2, pos3 - pos2, plane_pos, plane_dir)
                if !point1 then point1 = pos1 end
                if !point2 then point2 = pos3 end
                new_tris[new_tris_index + 1] = point2
                new_tris[new_tris_index + 2] = point1
                new_tris[new_tris_index + 3] = pos2
                new_tris_index = new_tris_index + 3
                is_flipped = true
            end
        else                       // pos1 = invalid, pos2 = invalid, pos3 = valid
            point1 = util_IntersectRayWithPlane(pos3, pos1 - pos3, plane_pos, plane_dir)
            point2 = util_IntersectRayWithPlane(pos3, pos2 - pos3, plane_pos, plane_dir)
            if !point1 then point1 = pos1 end
            if !point2 then point2 = pos2 end
            new_tris[new_tris_index + 1] = pos3
            new_tris[new_tris_index + 2] = point1
            new_tris[new_tris_index + 3] = point2
            new_tris_index = new_tris_index + 3
        end
    
        table.Add(split_tris, new_tris)
        if is_flipped then
            table_insert(plane_points, point1)
            table_insert(plane_points, point2)
        else
            table_insert(plane_points, point2)
            table_insert(plane_points, point1)
        end
    end
    
    // add triangles inside of the object
    // each 2 points is an edge, create a triangle between the egde and first point
    // start at index 4 since the first edge (1-2) cant exist since we are wrapping around the first point
    //for i = 4, #plane_points, 2 do
    //    table_insert(split_tris, plane_points[1    ])
    //    table_insert(split_tris, plane_points[i - 1])
    //    table_insert(split_tris, plane_points[i    ])
    //end

    return split_tris
end