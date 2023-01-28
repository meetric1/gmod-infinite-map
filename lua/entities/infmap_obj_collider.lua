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
    verts = verts or self.RENDER_MESH
    if !verts then return end
    self:PhysicsDestroy()
    self:PhysicsFromMesh(verts)

    local phys = self:GetPhysicsObject()
    phys:EnableMotion(false)
    phys:SetMass(50000)
    phys:AddGameFlag(FVPHYSICS_CONSTRAINT_STATIC)
    phys:AddGameFlag(FVPHYSICS_NO_SELF_COLLISIONS)
    self.RENDER_MESH = nil
end

InfMap.all_ents = InfMap.all_ents or {}

function ENT:TryOptimizeCollision()
    if SERVER then
        local co = InfMap.ezcoord(self.CHUNK_OFFSET)
        if !InfMap.all_ents[co] then return end
        self:SetNotSolid(table.Count(InfMap.all_ents[co]) < 1)
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
hook.Add("PropUpdateChunk", "infmap_obj_optimizecollision", function(ent, chunk, oldchunk)
    if SERVER then
        if InfMap.filter_entities(ent) then return end

        local chunk_str = InfMap.ezcoord(chunk)
        
        InfMap.all_ents[chunk_str] = InfMap.all_ents[chunk_str] or {}
        InfMap.all_ents[chunk_str][ent] = true
        if oldchunk then
            local oldchunk_str = InfMap.ezcoord(oldchunk)
            if InfMap.all_ents[oldchunk_str] then
                InfMap.all_ents[oldchunk_str][ent] = nil
            end
        end

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

if CLIENT then return end

hook.Add("EntityRemoved", "infmap_obj_optimizecollision", function(ent)
    local co = ent.CHUNK_OFFSET
    if !co then return end

    local ez = InfMap.ezcoord(co)
    if InfMap.all_ents[ez] then
        InfMap.all_ents[ez][ent] = nil
    end
end)