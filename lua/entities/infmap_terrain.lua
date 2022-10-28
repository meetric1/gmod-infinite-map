if game.GetMap() != "gm_infinite" then return end

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= ""
ENT.PrintName		= ""
ENT.Author			= "Mee"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable		= false

function ENT:BuildCollision(heightFunction)
    local chunk_offset = self.CHUNK_OFFSET or Vector()
    local x = chunk_offset[1]
    local y = chunk_offset[2]

    local p1 = Vector(InfMap.chunk_size, InfMap.chunk_size, heightFunction(x + 0.5, y + 0.5))
    local p2 = Vector(-InfMap.chunk_size, InfMap.chunk_size, heightFunction(x - 0.5, y + 0.5))
    local p3 = Vector(InfMap.chunk_size, -InfMap.chunk_size, heightFunction(x + 0.5, y - 0.5))
    local p4 = Vector(-InfMap.chunk_size, -InfMap.chunk_size, heightFunction(x - 0.5, y - 0.5))

    local finalMesh = {
        {pos = p1},
        {pos = p2},
        {pos = p3},
        {pos = p2},
        {pos = p3},
        {pos = p4}
    }

    self:PhysicsDestroy()
	self:PhysicsFromMesh(finalMesh)
end


function ENT:GetRenderMesh()
    if !self.RENDER_MESH then return end
    return self.RENDER_MESH
end

if CLIENT then
    //hook.Add("PropUpdateChunk", "infmap_terrain_init", function(ent, chunk)
    //    if ent:GetClass() == "infmap_terrain" then
    //        ent:ClientInitialize()
    //    end
    //end)
end

/****************** SERVER *********************/

function ENT:Initialize()
    //if CLIENT then return end

    self:SetModel("models/props_c17/FurnitureCouch002a.mdl")
    self:BuildCollision(InfMap.height_function)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:EnableCustomCollisions(true)
    self:GetPhysicsObject():EnableMotion(false)
    self:GetPhysicsObject():SetMass(50000)  // max weight, should help a bit with the physics solver
    self:DrawShadow(false)
    //self:SetMaterial("NULL")
end

hook.Add("PhysgunPickup", "infinite_chunkterrain_pickup", function(ply, ent)
    if (ent:IsValid() and ent:GetClass() == "infmap_terrain") then 
        return false 
    end
end)

if CLIENT then return end

local function resetAll()
    local e = ents.Create("prop_physics")
    e:SetPos(Vector(0, 0, -10))
    e:SetModel("models/hunter/blocks/cube8x8x025.mdl")
    e:SetMaterial("models/gibs/metalgibs/metal_gibs")
    e:Spawn()
    e:GetPhysicsObject():EnableMotion(false)
    constraint.Weld(e, game.GetWorld(), 0, 0, 0)

    local e = ents.Create("infmap_terrain_render")
    e:Spawn()

    //for y = -0, 0 do
    //    for x = -0, 0 do 
    //        local e = ents.Create("infmap_terrain")
    //        e:SetPos(Vector(x * InfMap.chunk_size * 2, y * InfMap.chunk_size * 2, 0))
    //        e:Spawn()
    //    end
    //end
end


hook.Add("InitPostEntity", "infinite_terrain_init", function() timer.Simple(0, resetAll) end)
hook.Add("PostCleanupMap", "infmap_cleanup", resetAll)