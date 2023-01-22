AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "Other"
ENT.PrintName		= "Obj"
ENT.Author			= "Mee"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable		= false

if !InfMap then return end

function ENT:Initialize()
    if CLIENT then return end
    
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:EnableCustomCollisions(true)
    self:DrawShadow(false)
    self:SetNoDraw(true)
    self:AddSolidFlags(FSOLID_FORCE_WORLD_ALIGNED)
    self:AddFlags(FL_STATICPROP)
end

function ENT:UpdateCollision(verts)
    self:PhysicsFromMesh(verts)
    self:GetPhysicsObject():EnableMotion(false)
end

function ENT:TryOptimizeCollision()
    if SERVER then
        self:SetNotSolid(#InfMap.find_in_chunk(self.CHUNK_OFFSET) < 1)
    else
        self:SetNotSolid(LocalPlayer().CHUNK_OFFSET != self.CHUNK_OFFSET)
    end
end

function ENT:Think()
    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:EnableMotion(false)
        phys:SetMass(50000)  // max weight should help a bit with the physics solver
        phys:AddGameFlag(FVPHYSICS_CONSTRAINT_STATIC)
        phys:AddGameFlag(FVPHYSICS_NO_SELF_COLLISIONS)
    end

    self:TryOptimizeCollision()

    if SERVER then self:NextThink(CurTime() + 1)
    else self:SetNextClientThink(CurTime() + 1) end

    return true
end

// return data to table (these should never be removed! why is this called!)
function ENT:OnRemove()
    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        InfMap.parsed_collision_data[InfMap.ezcoord(self.CHUNK_OFFSET)] = phys:GetMesh()
    else
        print("Unable to retrieve collision data for chunk " .. InfMap.ezcoord(self.CHUNK_OFFSET))
    end
end

// physics solver optimization
hook.Add("PropUpdateChunk", "infmap_obj_optimizecollision", function(ent, chunk)
    if SERVER and InfMap.filter_entities(ent) then return end
    if CLIENT and ent != LocalPlayer() then return end

    for k, v in ipairs(ents.FindByClass("infmap_obj")) do
        v:TryOptimizeCollision()
    end
end)