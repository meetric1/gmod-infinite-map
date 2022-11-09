AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= ""
ENT.PrintName		= ""
ENT.Author			= "Mee"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable		= false

// tris are in the format {{pos = value}, {pos = value2}}
local function split_convex(tris, plane_pos, plane_dir)
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

local bounds = 2^14
local max_radius = math.floor(math.sqrt(bounds^2 + bounds^2))
function ENT:BuildCollision(heightFunction)
    local chunk_offset = self.CHUNK_OFFSET or Vector()
    local x = chunk_offset[1]
    local y = chunk_offset[2]
    local z = chunk_offset[3]

    local offset_z = z * InfMap.chunk_size * 2

    local final_mesh = {}
    for y1 = -1, 0 do
        for x1 = -1, 0 do
            local chunk_resolution = InfMap.chunk_resolution
            for i_y = 0, chunk_resolution - 1 do
                for i_x = 0, chunk_resolution - 1 do
                    local size = InfMap.chunk_size
                    local i_x1 = (i_x    ) / chunk_resolution
                    local i_y1 = (i_y    ) / chunk_resolution
                    local i_x2 = (i_x + 1) / chunk_resolution
                    local i_y2 = (i_y + 1) / chunk_resolution
                    local min_pos_x = -InfMap.chunk_size + i_x1 * InfMap.chunk_size * 2
                    local min_pos_y = -InfMap.chunk_size + i_y1 * InfMap.chunk_size * 2
                    local max_pos_x = -InfMap.chunk_size + i_x2 * InfMap.chunk_size * 2
                    local max_pos_y = -InfMap.chunk_size + i_y2 * InfMap.chunk_size * 2

                    local offset = Vector(x1 * InfMap.chunk_size * 2 + InfMap.chunk_size, y1 * InfMap.chunk_size * 2 + InfMap.chunk_size, -offset_z)
                    local p1 = Vector(max_pos_x, max_pos_y, heightFunction(x + x1 + i_x2, y + y1 + i_y2)) + offset
                    local p2 = Vector(min_pos_x, max_pos_y, heightFunction(x + x1 + i_x1, y + y1 + i_y2)) + offset
                    local p3 = Vector(max_pos_x, min_pos_y, heightFunction(x + x1 + i_x2, y + y1 + i_y1)) + offset
                    local p4 = Vector(min_pos_x, min_pos_y, heightFunction(x + x1 + i_x1, y + y1 + i_y1)) + offset

                    table.Add(final_mesh, {
                        {pos = p1},
                        {pos = p2},
                        {pos = p3},

                        {pos = p2},
                        {pos = p3},
                        {pos = p4}
                    })
                end
            end
        end
    end

    final_mesh = split_convex(final_mesh, Vector(0, 0, bounds), Vector(0, 0, -1))
    final_mesh = split_convex(final_mesh, Vector(0, 0, -bounds), Vector(0, 0, 1))

    self:PhysicsDestroy()
	self:PhysicsFromMesh(final_mesh)
end


/****************** SERVER *********************/

function ENT:Initialize()
    if CLIENT and !self.CHUNK_OFFSET then 
        return 
    end

    self:SetModel("models/props_c17/FurnitureCouch002a.mdl")
    self:BuildCollision(InfMap.height_function)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:EnableCustomCollisions(true)
    self:DrawShadow(false)
    self:SetMaterial("NULL")
    self:AddSolidFlags(FSOLID_FORCE_WORLD_ALIGNED)
    self:AddFlags(FL_STATICPROP)
    self:AddFlags(FL_DONTTOUCH)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:SetMass(50000)  // max weight should help a bit with the physics solver
        phys:AddGameFlag(FVPHYSICS_CONSTRAINT_STATIC)
        phys:AddGameFlag(FVPHYSICS_NO_NPC_IMPACT_DMG)
        phys:AddGameFlag(FVPHYSICS_NO_SELF_COLLISIONS)
    elseif SERVER then
        SafeRemoveEntity(self)  // physics object doesnt exist (no points)
    end
end

hook.Add("PhysgunPickup", "infinite_chunkterrain_pickup", function(ply, ent)
    if (ent:IsValid() and ent:GetClass() == "infmap_terrain_collider") then 
        return false 
    end
end)

if CLIENT then 
    hook.Add("PropUpdateChunk", "infmap_terrain_update", function(ent, chunk, oldchunk)
        if ent:GetClass() == "infmap_terrain_collider" then
            ent.CHUNK_OFFSET = chunk
            if !ent.Initialize then
                timer.Create("tryinitialize"..ent:EntIndex(), 0, 100, function()
                    if ent.Initialize then
                        ent:Initialize()
                        timer.Remove("tryinitialize"..ent:EntIndex())
                    end
                end)
            else
                ent:Initialize()
            end
        end
    end)
    return 
end

local function v_tostring(v)
    return v[1] .. "," .. v[2] .. "," .. v[3]
end

InfMap.chunk_table = {}

local function resetAll()
    local e = ents.Create("prop_physics")
    e:SetPos(Vector(200, 200, -10))
    e:SetModel("models/hunter/blocks/cube8x8x025.mdl")
    e:SetMaterial("models/gibs/metalgibs/metal_gibs")
    e:Spawn()
    e:GetPhysicsObject():EnableMotion(false)
    constraint.Weld(e, game.GetWorld(), 0, 0, 0)

    local e = ents.Create("infmap_terrain_collider")
    InfMap.chunk_table[v_tostring(Vector())] = e
    InfMap.prop_update_chunk(e, Vector())
    e:Spawn()
end

hook.Add("PropUpdateChunk", "infmap_infgen_terrain", function(ent, chunk, old_chunk)
    timer.Simple(0, function()  // wait for entire contraption to teleport
        if IsValid(ent) and !(InfMap.filter_entities(ent) or InfMap.terrain_filter[ent:GetClass()]) then
            // remove chunks that dont have anything in them
            if old_chunk then
                local invalid = InfMap.chunk_table[v_tostring(old_chunk)]
                for k, v in ipairs(ents.GetAll()) do
                    if InfMap.filter_entities(v) or InfMap.terrain_filter[v:GetClass()] or v == ent then continue end
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

hook.Add("InitPostEntity", "infinite_terrain_init", function() timer.Simple(0, resetAll) end)
hook.Add("PostCleanupMap", "infmap_cleanup", resetAll)