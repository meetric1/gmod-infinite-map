AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "Other"
ENT.PrintName		= "Obj_c"
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

if CLIENT then
    function ENT:Think()
        self:TryOptimizeCollision()
        self:SetNextClientThink(CurTime() + 1)
        return true
    end
end

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
    if SERVER then
        if InfMap.filter_entities(ent) then return end
        for k, v in ipairs(ents.FindByClass("infmap_obj_collider")) do
            v:TryOptimizeCollision()
        end
    else
        if CLIENT and ent != LocalPlayer() then return end
        timer.Simple(0, function() // race CONDITION
            for k, v in ipairs(ents.FindByClass("infmap_obj_collider")) do
                if !v.TryOptimizeCollision then continue end    // wtf?
                v:TryOptimizeCollision()
            end
        end)
    end
end)