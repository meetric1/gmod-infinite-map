AddCSLuaFile()

ENT.Type = "anim"
--ENT.Base = "base_gmodentity"

ENT.Category		= ""
ENT.PrintName		= ""
ENT.Author			= "Mee"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable		= false

if !InfMap then return end

local bounds = InfMap.source_bounds[1]
function ENT:BuildCollision(heightFunction)
    local chunk_offset = self.CHUNK_OFFSET
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

    final_mesh = InfMap.split_convex(final_mesh, Vector(0, 0, bounds), Vector(0, 0, -1))
    final_mesh = InfMap.split_convex(final_mesh, Vector(0, 0, -bounds), Vector(0, 0, 1))

    self:PhysicsDestroy()
	self:PhysicsFromMesh(final_mesh)
end


/****************** SERVER *********************/

function ENT:Initialize()
    if CLIENT and !self.CHUNK_OFFSET then 
        return 
    end

    self:BuildCollision(InfMap.height_function)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:EnableCustomCollisions(true)
    self:DrawShadow(false)
    self:SetRenderMode(RENDERMODE_NONE) // dont render, but do network
    self:AddSolidFlags(FSOLID_FORCE_WORLD_ALIGNED)
    self:AddFlags(FL_STATICPROP)
    //self:AddFlags(FL_DONTTOUCH)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:SetMass(50000)  // max weight should help a bit with the physics solver
        phys:AddGameFlag(FVPHYSICS_CONSTRAINT_STATIC)
        phys:AddGameFlag(FVPHYSICS_NO_SELF_COLLISIONS)
    elseif SERVER then
        SafeRemoveEntity(self)  // physics object doesnt exist (no points)
    end
end

if SERVER then return end

function ENT:Think()
    if !IsValid(self:GetPhysicsObject()) and self.CHUNK_OFFSET then
        print("Rebuilding Collisions for chunk ", self.CHUNK_OFFSET)
        self:Initialize()
    end
end
