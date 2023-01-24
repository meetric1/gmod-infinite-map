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
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:EnableCustomCollisions(true)
    self:DrawShadow(false)
    self:SetNoDraw(true)
    self:AddSolidFlags(FSOLID_FORCE_WORLD_ALIGNED)
    self:AddFlags(FL_STATICPROP)
    self:UpdateCollision()
end

function ENT:UpdateCollision(verts)
    local verts = verts or self.RENDER_MESH
    if !verts then return end    
    self:PhysicsFromMesh(verts)
    self:GetPhysicsObject():EnableMotion(false)
    if !self.RENDER_MESH then return end
    table.Empty(self.RENDER_MESH) self.RENDER_MESH = nil
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

// physics solver optimization
hook.Add("PropUpdateChunk", "infmap_obj_optimizecollision", function(ent, chunk)
    if SERVER then
        if InfMap.filter_entities(ent) then return end
        for k, v in ipairs(ents.FindByClass("infmap_obj_collider")) do
            v:TryOptimizeCollision()
        end
    else
        if ent != LocalPlayer() then return end
        for k, v in ipairs(ents.FindByClass("infmap_obj_collider")) do
            if !v.TryOptimizeCollision then continue end    // wtf?
            v:TryOptimizeCollision()
        end
    end
end)