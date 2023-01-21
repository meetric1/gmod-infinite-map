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
    
    self:SetNoDraw(true)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:EnableCustomCollisions(true)
end

function ENT:UpdateCollision(verts)
    self:PhysicsFromMesh(verts)
    self:GetPhysicsObject():EnableMotion(false)
end

// return data to table (these should never be removed! why is this called!)
//function ENT:OnRemove()
//    local phys = self:GetPhysicsObject()
//    if phys:IsValid() then
//        InfMap.parsed_collision_data[InfMap.ezcoord(self.CHUNK_OFFSET)] = phys:GetMesh()
//    else
//        print("Unable to retrieve collision data for chunk " .. InfMap.ezcoord(self.CHUNK_OFFSET))
//    end
//end